# WeatherExperience

## Project Description

This is an iOS weather application built using Swift that follows the MVVM architecture pattern. The app provides real-time weather information with current conditions, hourly forecasts, and 3-day weather predictions.

### Key Features

- 📍 **Automatic Location Detection** - Uses CoreLocation to determine user's location
- 📊 **Current Weather** - Displays temperature, feels-like temperature, wind speed, humidity, and UV index
- ⏱️ **Hourly Forecast** - Shows weather conditions for each hour with weather icons
- 📅 **3-Day Forecast** - Min/max temperatures and chance of rain for upcoming days
- 💾 **Smart Caching** - Caches daily forecasts to reduce network requests
- 🖼️ **Image Caching** - Efficiently caches weather condition icons

## 🛠 Tech Stack

### Frontend
- **Swift** - Primary language
- **UIKit** - User interface framework with UICollectionView, UIStackView, Auto Layout
- **URLSession** - Network requests with async/await support
- **CoreLocation** - User location services

### Architecture & Patterns
- **MVVM** - Model-View-ViewModel pattern for state management
- **Repository Pattern** - Abstracts data access layer
- **Dependency Injection** - Loose coupling between components
- **Protocol-Oriented Programming** - Uses protocols for flexibility and testability

### Core Components

| Component | Purpose |
|-----------|---------|
| **WeatherViewController** | Main UI controller with collection view |
| **WeatherViewModel** | State management and business logic |
| **WeatherRepository** | Data loading from API and cache |
| **HTTPClient** | URLSession wrapper for network requests |
| **ImageLoader** | Weather icon caching and loading |
| **LocationService** | User location requests |

## 📁 Project Structure

```
Weather/
├── App/
│   ├── AppDelegate.swift
│   └── SceneDelegate.swift
├── Core/
│   ├── Networking/
│   │   └── HTTPClient.swift
│   └── WeatherAPI/
│       └── DTO.swift
├── Features/
│   └── Weather/
│       ├── WeatherRepository.swift
│       ├── WeatherViewModel.swift
│       ├── WeatherModels.swift
│       └── UI/
│           ├── ImageLoader.swift
│           └── Cells/
│               ├── CurrentWeatherCell.swift
│               └── HourlyWeatherCell.swift
└── Weather.xcodeproj/
```

## 🔌 API Integration

The app integrates with a weather API through Data Transfer Objects (DTOs):

- **WeatherCurrentResponseDTO** - Current weather data
- **WeatherForecastResponseDTO** - Multi-day forecast data
- Nested DTOs for location, conditions, hourly, and daily forecasts

## ⚡ Technical Highlights

✅ **Modern Concurrency** - Uses async/await for clean asynchronous code  
✅ **Efficient Caching** - NSCache for images, custom caching for forecasts  
✅ **Error Handling** - Comprehensive error handling with user-friendly messages  
✅ **Thread Safety** - Sendable types ensure thread-safe data models  
✅ **UI Polish** - UIBlurEffect and smooth animations for modern appearance  
✅ **Performance** - Optimized network requests and intelligent caching strategy

## 📋 Requirements

- iOS 14+
- Xcode 14+
- Swift 5.9+

## 📝 License

MIT