import Foundation
import CoreLocation

@MainActor
final class WeatherViewModel {
    enum State: Equatable {
        case loading
        case failed(message: String)
        case content(WeatherScreenModel)
    }

    private let location: any LocationServicing
    private let repository: any WeatherRepositorying

    private(set) var state: State = .loading {
        didSet { onStateChange?(state) }
    }

    var onStateChange: ((State) -> Void)?

    init(location: any LocationServicing, repository: any WeatherRepositorying) {
        self.location = location
        self.repository = repository
    }

    func onAppear() {
        Task { await reload() }
    }

    func retry() {
        Task { await reload() }
    }

    private func reload() async {
        state = .loading
        let coordinate = await location.requestLocation()
        do {
            let model = try await repository.loadWeather(for: coordinate)
            state = .content(model)
        } catch {
            state = .failed(message: Self.userMessage(for: error))
        }
    }

    private static func userMessage(for error: Error) -> String {
        if let e = error as? NetworkError {
            switch e {
            case .invalidURL, .invalidResponse:
                return "Некорректный ответ сервера"
            case .http:
                return "Сервер временно недоступен"
            case .decoding:
                return "Не удалось обработать данные"
            }
        }
        return "Что-то пошло не так"
    }
}

