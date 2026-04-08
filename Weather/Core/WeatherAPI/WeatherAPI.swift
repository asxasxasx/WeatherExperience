import Foundation

protocol WeatherAPIClienting: Sendable {
    func current(lat: Double, lon: Double) async throws -> WeatherCurrentResponseDTO
    func forecast(lat: Double, lon: Double, days: Int) async throws -> WeatherForecastResponseDTO
}

struct WeatherAPIClient: WeatherAPIClienting {
    private let http: any HTTPClienting
    private let json: JSONDecoder

    init(http: any HTTPClienting, json: JSONDecoder = .weatherAPI) {
        self.http = http
        self.json = json
    }

    func current(lat: Double, lon: Double) async throws -> WeatherCurrentResponseDTO {
        try await request(path: "/v1/current.json", lat: lat, lon: lon)
    }

    func forecast(lat: Double, lon: Double, days: Int) async throws -> WeatherForecastResponseDTO {
        try await request(path: "/v1/forecast.json", lat: lat, lon: lon, extraQuery: [URLQueryItem(name: "days", value: String(days))])
    }

    private func request<T: Decodable>(
        path: String,
        lat: Double,
        lon: Double,
        extraQuery: [URLQueryItem] = []
    ) async throws -> T {
        var components = URLComponents(url: AppConfig.weatherApiBaseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "key", value: AppConfig.weatherApiKey),
            URLQueryItem(name: "q", value: "\(lat),\(lon)")
        ] + extraQuery

        guard let url = components?.url else { throw NetworkError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15

        let (data, response) = try await http.data(for: request)
        guard (200..<300).contains(response.statusCode) else {
            throw NetworkError.http(statusCode: response.statusCode)
        }
        do {
            return try json.decode(T.self, from: data)
        } catch {
            throw NetworkError.decoding
        }
    }
}

extension JSONDecoder {
    static let weatherAPI: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .useDefaultKeys
        return d
    }()
}

