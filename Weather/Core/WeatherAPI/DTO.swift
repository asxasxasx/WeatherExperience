import Foundation

struct WeatherCurrentResponseDTO: Codable, Sendable {
    let location: LocationDTO
    let current: CurrentDTO
}

struct WeatherForecastResponseDTO: Codable, Sendable {
    let location: LocationDTO
    let current: CurrentDTO?
    let forecast: ForecastDTO
}

struct LocationDTO: Codable, Sendable {
    let name: String
    let region: String
    let country: String
    let lat: Double
    let lon: Double
    let tz_id: String
    let localtime_epoch: Int
    let localtime: String
}

struct CurrentDTO: Codable, Sendable {
    let last_updated_epoch: Int
    let temp_c: Double
    let is_day: Int
    let condition: ConditionDTO
    let wind_kph: Double
    let wind_dir: String
    let pressure_mb: Double
    let precip_mm: Double
    let humidity: Int
    let cloud: Int
    let feelslike_c: Double
    let uv: Double
}

struct ConditionDTO: Codable, Sendable {
    let text: String
    let icon: String
    let code: Int
}

struct ForecastDTO: Codable, Sendable {
    let forecastday: [ForecastDayDTO]
}

struct ForecastDayDTO: Codable, Sendable {
    let date: String
    let date_epoch: Int
    let day: DayDTO
    let hour: [HourDTO]
}

struct DayDTO: Codable, Sendable {
    let maxtemp_c: Double
    let mintemp_c: Double
    let avgtemp_c: Double
    let condition: ConditionDTO
    let daily_chance_of_rain: Int?
}

struct HourDTO: Codable, Sendable {
    let time_epoch: Int
    let time: String
    let temp_c: Double
    let is_day: Int
    let condition: ConditionDTO
    let chance_of_rain: Int?
}

