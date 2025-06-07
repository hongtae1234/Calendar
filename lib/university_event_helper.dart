import 'package:flutter/material.dart';

class UniversityEventHelper {
  // Example structure to hold university events by year
  // Key: Year (int), Value: List of Maps, where each Map is {'date': DateTime, 'name': String}
  static Map<int, List<Map<String, dynamic>>> _yearlyUniversityEvents = {};

  // Method to add university events for a specific year
  static void addEventsForYear(int year, List<Map<String, dynamic>> events) {
    _yearlyUniversityEvents[year] = events;
  }

  // Method to get university events for a specific date
  static List<Map<String, dynamic>> getEventsForDate(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final yearEvents = _yearlyUniversityEvents[date.year] ?? [];
    
    return yearEvents.where((event) {
      final eventDate = event['date'] as DateTime;
      return eventDate.year == normalizedDate.year &&
             eventDate.month == normalizedDate.month &&
             eventDate.day == normalizedDate.day;
    }).toList();
  }

  // Method to check if a date has any university events
  static bool isUniversityEvent(DateTime date) {
    return getEventsForDate(date).isNotEmpty;
  }

  // Method to get the names of university events for a date (can be multiple)
  static List<String> getUniversityEventNames(DateTime date) {
     return getEventsForDate(date).map((event) => event['name'] as String).toList();
  }
} 