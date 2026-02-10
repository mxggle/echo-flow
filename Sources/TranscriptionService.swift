import Foundation
@preconcurrency import AVFoundation

/// Unified AI transcription service that calls provider-specific REST APIs.
@MainActor
class TranscriptionService: ObservableObject {
    @Published var status: TranscriptionStatus = .idle

    // MARK: - Public API

    /// Transcribe an audio file using the specified provider.
    /// Returns an array of Sentence objects on success.
    func transcribe(
        audioURL: URL,
        provider: TranscriptionProvider,
        apiKey: String,
        model: String,
        language: String
    ) async throws -> [Sentence] {
        guard !apiKey.isEmpty else {
            throw TranscriptionError.missingAPIKey
        }

        status = .transcribing

        // Preprocess audio: Convert to 16kHz Mono AAC to fix timestamp drift
        let processedURL = try await convertAudioForTranscription(url: audioURL)
        defer {
            try? FileManager.default.removeItem(at: processedURL)
        }

        do {
            let sentences: [Sentence]
            switch provider {
            case .openAI:
                sentences = try await transcribeWithOpenAI(
                    audioURL: processedURL, apiKey: apiKey, model: model, language: language
                )
            case .gemini:
                sentences = try await transcribeWithGemini(
                    audioURL: processedURL, apiKey: apiKey, model: model, language: language
                )
            case .grok:
                sentences = try await transcribeWithGrok(
                    audioURL: processedURL, apiKey: apiKey, model: model, language: language
                )
            }
            status = .completed
            return sentences
        } catch {
            status = .failed(error.localizedDescription)
            throw error
        }
    }

    // MARK: - Audio Preprocessing

    /// Convert audio to 16kHz Mono AAC.
    /// This fixes the "stretched timestamps" issue common with Whisper/Gemini
    /// when handling 44.1kHz/48kHz input.
    private func convertAudioForTranscription(url: URL) async throws -> URL {
        let asset = AVAsset(url: url)
        
        // Verify track exists
        guard let track = try await asset.loadTracks(withMediaType: .audio).first else {
            throw TranscriptionError.invalidResponse // reusing error, or make new one
        }

        let tempDir = FileManager.default.temporaryDirectory
        let outputURL = tempDir.appendingPathComponent(UUID().uuidString + ".m4a")

        // Reader: Decode to 16kHz PCM
        // We let AVAssetReader handle the resampling from 44.1/48k -> 16k
        _ = try await track.load(.formatDescriptions)
        
        let readerSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]
        
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: readerSettings)
        reader.add(output)
        
        // Writer: Encode to 16kHz AAC
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .m4a)
        
        let writerSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 32000 // 32 kbps is sufficient for 16kHz mono speech
        ]
        
        let input = AVAssetWriterInput(mediaType: .audio, outputSettings: writerSettings)
        writer.add(input)
        
        // Start processing
        guard reader.startReading() else {
            throw TranscriptionError.uploadFailed
        }
        guard writer.startWriting() else {
            throw TranscriptionError.uploadFailed
        }
        writer.startSession(atSourceTime: .zero)
        
        let queue = DispatchQueue(label: "audio.conversion.queue")
        
        return try await withCheckedThrowingContinuation { continuation in
            input.requestMediaDataWhenReady(on: queue) {
                while input.isReadyForMoreMediaData {
                    if let buffer = output.copyNextSampleBuffer() {
                        input.append(buffer)
                    } else {
                        input.markAsFinished()
                        writer.finishWriting {
                            if writer.status == .completed {
                                continuation.resume(returning: outputURL)
                            } else {
                                continuation.resume(throwing: writer.error ?? TranscriptionError.uploadFailed)
                            }
                        }
                        break
                    }
                }
            }
        }
    }


    // MARK: - OpenAI Whisper

    private func transcribeWithOpenAI(
        audioURL: URL,
        apiKey: String,
        model: String,
        language: String
    ) async throws -> [Sentence] {
        let url = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
        let audioData = try Data(contentsOf: audioURL)
        let boundary = UUID().uuidString

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        // model
        body.appendMultipart(boundary: boundary, name: "model", value: model)
        // language
        if !language.isEmpty {
            body.appendMultipart(boundary: boundary, name: "language", value: language)
        }
        // response_format — verbose_json gives segment-level timestamps
        body.appendMultipart(boundary: boundary, name: "response_format", value: "verbose_json")
        // timestamp granularities
        body.appendMultipart(boundary: boundary, name: "timestamp_granularities[]", value: "segment")
        // file
        body.appendMultipartFile(
            boundary: boundary, name: "file",
            filename: audioURL.lastPathComponent,
            mimeType: mimeType(for: audioURL),
            data: audioData
        )
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response, data: data)

        return try parseOpenAIResponse(data)
    }

    private func parseOpenAIResponse(_ data: Data) throws -> [Sentence] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let segments = json["segments"] as? [[String: Any]]
        else {
            // Fallback: try to get plain text
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let text = json["text"] as? String {
                return [Sentence(id: 1, startTime: 0, endTime: 0, text: text)]
            }
            throw TranscriptionError.invalidResponse
        }

        return segments.enumerated().map { idx, seg in
            Sentence(
                id: idx + 1,
                startTime: seg["start"] as? Double ?? 0,
                endTime: seg["end"] as? Double ?? 0,
                text: (seg["text"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
    }

    // MARK: - Google Gemini

    private func transcribeWithGemini(
        audioURL: URL,
        apiKey: String,
        model: String,
        language: String
    ) async throws -> [Sentence] {
        let audioData = try Data(contentsOf: audioURL)
        let mime = mimeType(for: audioURL)

        // Step 1: Upload file to Gemini File API
        let fileURI = try await uploadToGeminiFileAPI(
            audioData: audioData, mimeType: mime, fileName: audioURL.lastPathComponent, apiKey: apiKey
        )

        // Step 2: Generate content with transcription prompt
        let languageHint = language.isEmpty ? "auto-detect" : language
        let prompt = """
        Transcribe this audio file. Language: \(languageHint).
        Return the transcription as a JSON array of objects with keys "id" (integer starting from 1), "start" (seconds as float), "end" (seconds as float), and "text" (string).
        Return ONLY the JSON array, no other text or markdown formatting.
        """

        let generateURL = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)")!

        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["file_data": ["mime_type": mime, "file_uri": fileURI]],
                        ["text": prompt]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.1,
                "responseMimeType": "application/json"
            ]
        ]

        var request = URLRequest(url: generateURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response, data: data)

        return try parseGeminiResponse(data)
    }

    private func uploadToGeminiFileAPI(
        audioData: Data, mimeType: String, fileName: String, apiKey: String
    ) async throws -> String {
        // Use the resumable upload flow
        let uploadURL = URL(string: "https://generativelanguage.googleapis.com/upload/v1beta/files?key=\(apiKey)")!

        let metadata: [String: Any] = ["file": ["display_name": fileName]]
        let metadataJSON = try JSONSerialization.data(withJSONObject: metadata)

        // Start resumable upload
        var initRequest = URLRequest(url: uploadURL)
        initRequest.httpMethod = "POST"
        initRequest.setValue("resumable", forHTTPHeaderField: "X-Goog-Upload-Protocol")
        initRequest.setValue("start", forHTTPHeaderField: "X-Goog-Upload-Command")
        initRequest.setValue(mimeType, forHTTPHeaderField: "X-Goog-Upload-Header-Content-Type")
        initRequest.setValue("\(audioData.count)", forHTTPHeaderField: "X-Goog-Upload-Header-Content-Length")
        initRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        initRequest.httpBody = metadataJSON

        let (_, initResponse) = try await URLSession.shared.data(for: initRequest)
        guard let httpResponse = initResponse as? HTTPURLResponse,
              let resumableURL = httpResponse.value(forHTTPHeaderField: "X-Goog-Upload-URL")
        else {
            throw TranscriptionError.uploadFailed
        }

        // Upload the actual bytes
        var uploadRequest = URLRequest(url: URL(string: resumableURL)!)
        uploadRequest.httpMethod = "POST"
        uploadRequest.setValue("upload, finalize", forHTTPHeaderField: "X-Goog-Upload-Command")
        uploadRequest.setValue("0", forHTTPHeaderField: "X-Goog-Upload-Offset")
        uploadRequest.setValue(mimeType, forHTTPHeaderField: "Content-Type")
        uploadRequest.httpBody = audioData

        let (uploadData, uploadResponse) = try await URLSession.shared.data(for: uploadRequest)
        try validateHTTPResponse(uploadResponse, data: uploadData)

        guard let json = try JSONSerialization.jsonObject(with: uploadData) as? [String: Any],
              let file = json["file"] as? [String: Any],
              let uri = file["uri"] as? String
        else {
            throw TranscriptionError.uploadFailed
        }

        // Poll until the file is ACTIVE
        let fileName = file["name"] as? String ?? ""
        try await waitForFileActive(fileName: fileName, apiKey: apiKey)

        return uri
    }

    private func waitForFileActive(fileName: String, apiKey: String) async throws {
        let statusURL = URL(string: "https://generativelanguage.googleapis.com/v1beta/\(fileName)?key=\(apiKey)")!

        for _ in 0..<30 {
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            var req = URLRequest(url: statusURL)
            req.httpMethod = "GET"
            let (data, _) = try await URLSession.shared.data(for: req)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let state = json["state"] as? String, state == "ACTIVE" {
                return
            }
        }
        throw TranscriptionError.uploadFailed
    }

    private func parseGeminiResponse(_ data: Data) throws -> [Sentence] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String
        else {
            throw TranscriptionError.invalidResponse
        }

        // Parse the JSON array from the text
        guard let jsonData = text.data(using: .utf8),
              let segments = try JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]]
        else {
            // If we got plain text, return as single sentence
            return [Sentence(id: 1, startTime: 0, endTime: 0, text: text)]
        }

        return segments.enumerated().map { idx, seg in
            Sentence(
                id: seg["id"] as? Int ?? (idx + 1),
                startTime: (seg["start"] as? Double) ?? 0,
                endTime: (seg["end"] as? Double) ?? 0,
                text: (seg["text"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
    }

    // MARK: - xAI Grok

    private func transcribeWithGrok(
        audioURL: URL,
        apiKey: String,
        model: String,
        language: String
    ) async throws -> [Sentence] {
        // xAI uses an OpenAI-compatible endpoint
        let url = URL(string: "https://api.x.ai/v1/audio/transcriptions")!
        let audioData = try Data(contentsOf: audioURL)
        let boundary = UUID().uuidString

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.appendMultipart(boundary: boundary, name: "model", value: model)
        if !language.isEmpty {
            body.appendMultipart(boundary: boundary, name: "language", value: language)
        }
        body.appendMultipart(boundary: boundary, name: "response_format", value: "verbose_json")
        body.appendMultipart(boundary: boundary, name: "timestamp_granularities[]", value: "segment")
        body.appendMultipartFile(
            boundary: boundary, name: "file",
            filename: audioURL.lastPathComponent,
            mimeType: mimeType(for: audioURL),
            data: audioData
        )
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response, data: data)

        // Same response format as OpenAI
        return try parseOpenAIResponse(data)
    }

    // MARK: - Helpers

    private func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "mp3":  return "audio/mpeg"
        case "m4a":  return "audio/mp4"
        case "wav":  return "audio/wav"
        case "ogg":  return "audio/ogg"
        case "flac": return "audio/flac"
        case "webm": return "audio/webm"
        default:     return "audio/mpeg"
        }
    }

    private func validateHTTPResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw TranscriptionError.networkError("Invalid response")
        }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            // Try to extract a readable error message from JSON
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw TranscriptionError.apiError(http.statusCode, message)
            }
            throw TranscriptionError.apiError(http.statusCode, body)
        }
    }
}

// MARK: - Errors

enum TranscriptionError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case uploadFailed
    case networkError(String)
    case apiError(Int, String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "API key is missing. Please set it in Settings → AI Services."
        case .invalidResponse:
            return "Could not parse the transcription response."
        case .uploadFailed:
            return "Failed to upload audio file to the provider."
        case .networkError(let msg):
            return "Network error: \(msg)"
        case .apiError(let code, let msg):
            return "API error (\(code)): \(msg)"
        }
    }
}

// MARK: - Data Helpers

extension Data {
    mutating func appendMultipart(boundary: String, name: String, value: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        append("\(value)\r\n".data(using: .utf8)!)
    }

    mutating func appendMultipartFile(boundary: String, name: String, filename: String, mimeType: String, data: Data) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        append(data)
        append("\r\n".data(using: .utf8)!)
    }
}
