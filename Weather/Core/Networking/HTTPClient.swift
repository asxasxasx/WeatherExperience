import Foundation

protocol HTTPClienting: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

struct URLSessionHTTPClient: HTTPClienting {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        return (data, http)
    }
}

enum NetworkError: Error, Equatable {
    case invalidURL
    case invalidResponse
    case http(statusCode: Int)
    case decoding
}

