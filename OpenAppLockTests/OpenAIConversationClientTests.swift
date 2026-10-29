import Foundation
import Testing
import Synchronization
@testable import OpenAppLock

@MainActor
@Suite("OpenAI conversation transport", .serialized)
struct OpenAIConversationClientTests {
    @Test("Uses strict JSON output, explicit history and no remote response storage")
    func requestContract() async throws {
        let session = makeSession()
        ConversationURLProtocol.handler = { request in
            #expect(request.url?.absoluteString == "https://api.openai.com/v1/responses")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-only")
            let body = try #require(request.httpBody)
            let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
            #expect(json["store"] as? Bool == false)
            #expect(json["model"] as? String == "gpt-5.4-mini")
            #expect((json["reasoning"] as? [String: String])?["effort"] == "medium")
            let text = try #require(json["text"] as? [String: Any])
            let format = try #require(text["format"] as? [String: Any])
            #expect(format["strict"] as? Bool == true)
            let schema = try #require(format["schema"] as? [String: Any])
            #expect(Set(schema["required"] as? [String] ?? []) == ["reply", "decision", "unlock_minutes", "wait_minutes", "pause_seconds", "block_minutes"])
            let properties = try #require(schema["properties"] as? [String: Any])
            let decision = try #require(properties["decision"] as? [String: Any])
            #expect((decision["enum"] as? [String])?.contains("pause") == true)
            #expect((decision["enum"] as? [String])?.contains("deny") == true)
            #expect(String(decoding: body, as: UTF8.self).contains("previous reason"))
            return (200, Self.response(text: #"{"reply":"What task?","decision":"ask","unlock_minutes":null}"#))
        }
        let result = try await OpenAIConversationClient(session: session).respond(to: context, apiKey: "test-only")
        #expect(result.decision == .ask)
    }

    @Test("Refusal, incomplete response, HTTP failures and invalid decisions never approve", arguments: ["refusal", "incomplete", "http", "duration"])
    func rejectsInvalid(kind: String) async throws {
        ConversationURLProtocol.handler = { _ in
            switch kind {
            case "http": return (429, Data())
            case "refusal": return (200, Self.response(text: "", type: "refusal"))
            case "incomplete": return (200, Self.response(text: "", status: "incomplete"))
            default: return (200, Self.response(text: #"{"reply":"Yes","decision":"approve","unlock_minutes":99}"#))
            }
        }
        await #expect(throws: (any Error).self) {
            try await OpenAIConversationClient(session: makeSession()).respond(to: context, apiKey: "test-only")
        }
    }

    @Test("HTTP errors retain safe diagnostic codes without key or body leakage")
    func safeHTTPDiagnostics() async throws {
        let lines = Mutex<[String]>([])
        let diagnostics = ConversationDiagnostics(enabled: true) { line in lines.withLock { $0.append(line) } }
        ConversationURLProtocol.handler = { _ in
            (401, Data(#"{"error":{"code":"invalid_api_key","type":"invalid_request_error","message":"Incorrect API key: secret-test-value"}}"#.utf8))
        }
        do {
            _ = try await OpenAIConversationClient(session: makeSession(), diagnostics: diagnostics).respond(to: context, apiKey: "secret-test-value")
            Issue.record("Expected HTTP failure")
        } catch let error as ConversationClientError {
            #expect(error == .http(status: 401, code: "invalid_api_key"))
        }
        let output = lines.withLock { $0.joined(separator: "\n") }
        #expect(output.contains("///CONVO-LOG"))
        #expect(output.contains("request.start"))
        #expect(output.contains("status=401"))
        #expect(output.contains("invalid_api_key"))
        #expect(!output.contains("secret-test-value"))
        #expect(!output.contains("previous reason"))
    }

    @Test("Diagnostic switch suppresses all events")
    func diagnosticsDisabled() {
        let lines = Mutex<[String]>([])
        ConversationDiagnostics(enabled: false) { line in lines.withLock { $0.append(line) } }.log("request.start")
        #expect(lines.withLock { $0.isEmpty })
    }

    private var context: ConversationContext {
        .init(goals: ["Focus"], appNickname: "App", memory: "previous reason", recentMessages: [], currentTime: .now)
    }
    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ConversationURLProtocol.self]
        return URLSession(configuration: configuration)
    }
    nonisolated private static func response(text: String, type: String = "output_text", status: String = "completed") -> Data {
        try! JSONSerialization.data(withJSONObject: ["status": status,
            "output": [["type": "message", "content": [["type": type, "text": text]]]]])
    }
}

private final class ConversationURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (Int, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            var request = request
            if request.httpBody == nil, let stream = request.httpBodyStream {
                stream.open(); defer { stream.close() }
                var data = Data(), buffer = [UInt8](repeating: 0, count: 4096)
                while stream.hasBytesAvailable {
                    let count = stream.read(&buffer, maxLength: buffer.count)
                    guard count > 0 else { break }
                    data.append(buffer, count: count)
                }
                request.httpBody = data
            }
            guard let handler = Self.handler else { throw URLError(.unknown) }
            let (status, data) = try handler(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}
