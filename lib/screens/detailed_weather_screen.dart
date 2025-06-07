import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../weather_service.dart'; // WeatherService import (for icon URL)

class DetailedWeatherScreen extends StatelessWidget {
  final Map<String, dynamic> forecastData;

  const DetailedWeatherScreen({Key? key, required this.forecastData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Accessing forecast data based on WeatherAPI.com forecast.json response
    final forecastday = forecastData['forecast']?['forecastday'] as List<dynamic>?;
    final location = forecastData['location'];

    // You'll likely need a WeatherService instance to get icon URLs
    final weatherService = WeatherService();

    return Scaffold(
      appBar: AppBar(
        title: Text(location != null ? '${location['name']} 예보' : '상세 날씨 정보'),
        centerTitle: true,
      ),
      body: forecastday != null && forecastday.isNotEmpty
          ? ListView.builder(
              itemCount: forecastday.length,
              itemBuilder: (context, index) {
                final dayData = forecastday[index];
                final dateStr = dayData['date']; // Date string in 'yyyy-MM-dd' format
                final daySummary = dayData['day'];
                final hourlyData = dayData['hour'] as List<dynamic>?;

                if (dateStr == null || daySummary == null) return Container();

                final date = DateTime.parse(dateStr);

                // Extract daily summary info
                final maxTemp = daySummary['maxtemp_c']?.toStringAsFixed(1) ?? 'N/A';
                final minTemp = daySummary['mintemp_c']?.toStringAsFixed(1) ?? 'N/A';
                final avgTemp = daySummary['avgtemp_c']?.toStringAsFixed(1) ?? 'N/A';
                final dailyCondition = daySummary['condition'];
                final dailyDescription = dailyCondition?['text'] ?? '날씨 정보 없음';
                final dailyIconUrlPath = dailyCondition?['icon'];
                final dailyIconUrl = dailyIconUrlPath != null ? weatherService.getWeatherIconUrl(dailyIconUrlPath) : null;


                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Daily Summary
                        Text(
                          DateFormat('yyyy년 M월 d일 EEEE', 'ko_KR').format(date),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (dailyIconUrl != null)
                              Image.network(dailyIconUrl, width: 50, height: 50),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dailyDescription,
                                  style: const TextStyle(fontSize: 16),
                                ),
                                Text('평균: ${avgTemp}°C'),
                                Text('최고: ${maxTemp}°C / 최저: ${minTemp}°C'),
                              ],
                            ),
                          ],
                        ),
                        const Divider(height: 24),

                        // Hourly Forecast (if available)
                        if (hourlyData != null && hourlyData.isNotEmpty) ...[
                          const Text('시간별 예보:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 100, // Adjust height as needed
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: hourlyData.length,
                              itemBuilder: (context, hourIndex) {
                                final hourData = hourlyData[hourIndex];
                                final hourTimeStr = hourData['time']; // Time string in 'yyyy-MM-dd HH:mm' format
                                final hourTemp = hourData['temp_c']?.toStringAsFixed(0) ?? 'N/A';
                                final hourCondition = hourData['condition'];
                                final hourIconUrlPath = hourCondition?['icon'];
                                final hourIconUrl = hourIconUrlPath != null ? weatherService.getWeatherIconUrl(hourIconUrlPath) : null;

                                if (hourTimeStr == null) return Container();

                                final hourDateTime = DateTime.parse(hourTimeStr);

                                return Container(
                                  width: 70, // Adjust card width as needed
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(DateFormat('HH:mm').format(hourDateTime)),
                                      if (hourIconUrl != null)
                                        Image.network(hourIconUrl, width: 30, height: 30),
                                      Text('${hourTemp}°C'),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            )
          : const Center(child: Text('예보 정보를 불러오지 못했습니다.')),
    );
  }
}