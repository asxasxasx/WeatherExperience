import Foundation
import CoreLocation

protocol WeatherRepositorying {
    func loadWeather(for coordinate: CLLocationCoordinate2D) async throws -> WeatherScreenModel
}

struct WeatherRepository: WeatherRepositorying {
    private let api: any WeatherAPIClienting
    private let cache: any WeatherDayCaching

    init(
        api: any WeatherAPIClienting,
        cache: any WeatherDayCaching
    ) {
        self.api = api
        self.cache = cache
    }

    func loadWeather(for coordinate: CLLocationCoordinate2D) async throws -> WeatherScreenModel {
        let lat = coordinate.latitude
        let lon = coordinate.longitude

        let forecastDTO = try await loadForecastCachedOrRemote(lat: lat, lon: lon)
        guard let current = forecastDTO.current else {
            let currentDTO = try await api.current(lat: lat, lon: lon)
            return map(forecast: forecastDTO, current: currentDTO.current, location: currentDTO.location)
        }

        return map(forecast: forecastDTO, current: current, location: forecastDTO.location)
    }

    private func loadForecastCachedOrRemote(lat: Double, lon: Double) async throws -> WeatherForecastResponseDTO {
        let dayKey = cacheKey(lat: lat, lon: lon, date: Date())
        if let cached = cache.load(key: dayKey) { return cached }

        let remote = try await api.forecast(lat: lat, lon: lon, days: 3)
        cache.save(remote, key: dayKey)
        return remote
    }

    private func cacheKey(lat: Double, lon: Double, date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"

        let day = formatter.string(from: date)
        return "forecast:\(day):\(String(format: "%.4f", lat)):\(String(format: "%.4f", lon))"
    }

    private func map(forecast: WeatherForecastResponseDTO, current: CurrentDTO, location: LocationDTO) -> WeatherScreenModel {
        let iconNow = iconURL(from: current.condition.icon)

        let now = CurrentModel(
            temperatureC: current.temp_c,
            feelsLikeC: current.feelslike_c,
            conditionText: current.condition.text,
            conditionIconURL: iconNow,
            windKph: current.wind_kph,
            humidity: current.humidity,
            uv: current.uv,
            isDay: current.is_day == 1
        )

        let hourly = buildHourly(forecast: forecast)
        let daily = forecast.forecast.forecastday.prefix(3).map { day in
            DayModel(
                dateEpoch: day.date_epoch,
                minTempC: day.day.mintemp_c,
                maxTempC: day.day.maxtemp_c,
                conditionText: day.day.condition.text,
                conditionIconURL: iconURL(from: day.day.condition.icon),
                chanceOfRain: day.day.daily_chance_of_rain
            )
        }

        return WeatherScreenModel(
            placeName: [location.name, location.region].filter { !$0.isEmpty }.joined(separator: ", "),
            now: now,
            hourly: hourly,
            daily: daily,
            timezoneID: location.tz_id,
            localTimeEpoch: location.localtime_epoch
        )
    }

    private func buildHourly(forecast: WeatherForecastResponseDTO) -> [HourModel] {
        let days = forecast.forecast.forecastday
        guard !days.isEmpty else { return [] }

        let nowEpoch = forecast.location.localtime_epoch
        let todayHours = days[0].hour.filter { $0.time_epoch >= nowEpoch }
        let nextDayHours = (days.count > 1) ? days[1].hour : []

        return (todayHours + nextDayHours).map { h in
            HourModel(
                timeEpoch: h.time_epoch,
                temperatureC: h.temp_c,
                conditionText: h.condition.text,
                conditionIconURL: iconURL(from: h.condition.icon),
                isDay: h.is_day == 1,
                chanceOfRain: h.chance_of_rain
            )
        }
    }

    private func iconURL(from raw: String) -> URL? {
        let cleaned: String
        if raw.hasPrefix("//") { cleaned = "https:" + raw }
        else { cleaned = raw }
        return URL(string: cleaned)
    }
}

