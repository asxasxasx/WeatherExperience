import Foundation

struct WeatherScreenModel: Sendable, Equatable {
    let placeName: String
    let now: CurrentModel
    let hourly: [HourModel]
    let daily: [DayModel]
    let timezoneID: String
    let localTimeEpoch: Int
}

struct CurrentModel: Sendable, Equatable {
    let temperatureC: Double
    let feelsLikeC: Double
    let conditionText: String
    let conditionIconURL: URL?
    let windKph: Double
    let humidity: Int
    let uv: Double
    let isDay: Bool
}

struct HourModel: Sendable, Equatable, Hashable {
    let timeEpoch: Int
    let temperatureC: Double
    let conditionText: String
    let conditionIconURL: URL?
    let isDay: Bool
    let chanceOfRain: Int?
}

struct DayModel: Sendable, Equatable, Hashable {
    let dateEpoch: Int
    let minTempC: Double
    let maxTempC: Double
    let conditionText: String
    let conditionIconURL: URL?
    let chanceOfRain: Int?
}

