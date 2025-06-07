import 'package:http/http.dart' as http;
import 'dart:convert';

class WeatherService {
  // User's API key
  final String apiKey = '220121a92172433f9aa134729250306'; // Replace with your actual API key if different

  // Location
  final String location = 'Gyeongsan'; // 경산시

  // Base URL for WeatherAPI.com Forecast API
  final String forecastBaseUrl = 'https://api.weatherapi.com/v1/forecast.json';
  // Base URL for WeatherAPI.com Current Weather API
  final String currentWeatherBaseUrl = 'https://api.weatherapi.com/v1/current.json';


  // Method to get current weather
  Future<Map<String, dynamic>?> getCurrentWeather() async {
    final url = Uri.parse(
        '$currentWeatherBaseUrl?key=$apiKey&q=$location&lang=ko'); // lang=ko for Korean

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        // Decode response body explicitly as UTF-8
        final String decodedBody = utf8.decode(response.bodyBytes);
        final data = json.decode(decodedBody);
        print('Current Weather API response: $data'); // Debug print

        // Extract necessary information based on WeatherAPI.com current weather response
        final currentWeatherData = data['current'];
        final weatherCondition = currentWeatherData['condition'];

        if (currentWeatherData != null && weatherCondition != null) {
           return {
            'description': weatherCondition['text'],
            'temperature': currentWeatherData['temp_c'],
            'iconCode': weatherCondition['icon'], // WeatherAPI provides full icon URL path
          };
        }
        return null;
      } else {
        print('Failed to load current weather data: ${response.statusCode}');
        print('Response body: ${response.body}');
        // Consider throwing an exception or returning null based on desired error handling
        return null;
      }
    } catch (e) {
      print('Error fetching current weather data: $e');
      return null;
    }
  }

  // Method to get forecast weather using WeatherAPI.com Forecast API
  Future<Map<String, dynamic>?> getForecastWeather() async {
     // We need to specify the number of days for the forecast.
     // Let's use 3 days as in your example endpoint.
    final url = Uri.parse(
        '$forecastBaseUrl?key=$apiKey&q=$location&days=3&lang=ko'); // lang=ko for Korean

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        // Decode response body explicitly as UTF-8
        final String decodedBody = utf8.decode(response.bodyBytes);
        final data = json.decode(decodedBody);
        print('Forecast Weather API response: $data'); // Debug print

        // Return the entire parsed data. DetailedWeatherScreen will process it.
        return data;

      } else {
        print('Failed to load forecast weather data: ${response.statusCode}');
        print('Response body: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error fetching forecast weather data: $e');
      return null;
    }
  }

  // 날씨 아이콘 URL 생성 (WeatherAPI provides full URL)
  String getWeatherIconUrl(String iconUrlPath) {
     // WeatherAPI provides the path starting with //cdn...
     // We need to prepend http: or https:
    if (iconUrlPath.startsWith('//')) {
      return 'http:$iconUrlPath';
    }
    return iconUrlPath; // Return as is if it's already a full URL
  }
} 