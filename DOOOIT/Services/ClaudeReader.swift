import Foundation
import UIKit

/// 문제 사진을 DOOOIT 서버(server/ 폴더의 Cloudflare Worker)로 보내 Claude가 직접 읽게 함.
/// 서버 주소와 앱 키는 빌드 설정 DOOOIT_READER_URL / DOOOIT_READER_KEY로 넣고,
/// 비어 있으면 이 기능은 숨겨지고 기기 안 방식만 사용합니다.
enum ClaudeReader {
    struct Result: Decodable {
        let title: String
        let text: String
        let answer: String
    }

    enum ReaderError: LocalizedError {
        case notConfigured
        case badImage
        case server(Int)

        var errorDescription: String? {
            switch self {
            case .notConfigured: return "Claude 읽기 서버가 아직 연결되지 않았어요."
            case .badImage: return "사진을 보낼 수 없어요. 다른 사진으로 시도해주세요."
            case .server(let code):
                switch code {
                case 401: return "서버 앱 키가 맞지 않아요. 설정을 확인해주세요."
                case 422: return "Claude가 이 사진을 읽지 않았어요. 문제 부분만 다시 골라주세요."
                case 429: return "요청이 많아요. 잠시 후 다시 시도해주세요."
                default: return "서버에서 문제를 읽지 못했어요. (코드 \(code))"
                }
            }
        }
    }

    static var endpoint: URL? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "DOOOITReaderURL") as? String,
              value.hasPrefix("https://") else { return nil }
        return URL(string: value)
    }

    static var appKey: String {
        (Bundle.main.object(forInfoDictionaryKey: "DOOOITReaderKey") as? String) ?? ""
    }

    static var isConfigured: Bool {
        endpoint != nil && !appKey.isEmpty && !appKey.hasPrefix("$(")
    }

    static func read(_ image: UIImage) async throws -> Result {
        guard let endpoint, isConfigured else { throw ReaderError.notConfigured }
        guard let jpeg = image.jpegForStorage(maxDimension: 1568, quality: 0.85) else { throw ReaderError.badImage }

        var request = URLRequest(url: endpoint.appendingPathComponent("read-problem"))
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(appKey, forHTTPHeaderField: "x-dooit-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "image": jpeg.base64EncodedString(),
            "mediaType": "image/jpeg"
        ])

        let (body, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw ReaderError.server(status) }
        return try JSONDecoder().decode(Result.self, from: body)
    }
}
