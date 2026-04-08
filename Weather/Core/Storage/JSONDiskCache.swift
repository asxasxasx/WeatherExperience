import Foundation

protocol WeatherDayCaching: AnyObject {
    func load(key: String) -> WeatherForecastResponseDTO?
    func save(_ value: WeatherForecastResponseDTO, key: String)
    func invalidate(key: String)
}

final class JSONDiskCache: WeatherDayCaching {
    private let directory: URL
    private let io = DispatchQueue(label: "weather.cache.disk", qos: .utility)
    private let encoder = JSONEncoder()

    init(directoryName: String = "weather-cache") {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.directory = base.appendingPathComponent(directoryName, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func load(key: String) -> WeatherForecastResponseDTO? {
        let url = fileURL(for: key)
        return io.sync {
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? JSONDecoder.weatherAPI.decode(WeatherForecastResponseDTO.self, from: data)
        }
    }

    func save(_ value: WeatherForecastResponseDTO, key: String) {
        let url = fileURL(for: key)
        io.async {
            guard let data = try? self.encoder.encode(value) else { return }
            try? data.write(to: url, options: [.atomic])
        }
    }

    func invalidate(key: String) {
        let url = fileURL(for: key)
        io.async {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func fileURL(for key: String) -> URL {
        directory.appendingPathComponent(key.sha256Base64URLSafe, isDirectory: false).appendingPathExtension("json")
    }
}

import CryptoKit

private extension String {
    var sha256Base64URLSafe: String {
        let digest = SHA256.hash(data: Data(utf8))
        let b64 = Data(digest).base64EncodedString()
        return b64
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

