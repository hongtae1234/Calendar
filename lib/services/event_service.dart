import 'package:my_app/database_helper.dart';
import 'package:my_app/models/event.dart';

class EventService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<void> saveEvent(Event event) async {
    await _dbHelper.saveEvent(event.toMap());
  }

  Future<List<Event>> getEvents() async {
    final List<Map<String, dynamic>> maps = await _dbHelper.loadEvents();
    return List.generate(maps.length, (i) {
      return Event.fromMap(maps[i]);
    });
  }

  Future<List<Event>> getEventsForDate(DateTime date) async {
    final allEvents = await getEvents();
    return allEvents.where((event) {
      final normalizedStartDate = DateTime(event.startDate.year, event.startDate.month, event.startDate.day);
      final normalizedEndDate = DateTime(event.endDate.year, event.endDate.month, event.endDate.day);
      final normalizedDate = DateTime(date.year, date.month, date.day);

      // Check for recurring events
      if (event.repeatType != EventRepeatType.none) {
        // For simplicity, we'll only check the start date for now.
        // A more robust solution would involve generating occurrences based on recurrence rules.
        // This is a placeholder for future complex recurrence logic.
        return (normalizedDate.isAtSameMomentAs(normalizedStartDate) ||
                normalizedDate.isAfter(normalizedStartDate)) &&
                (normalizedDate.isAtSameMomentAs(normalizedEndDate) ||
                normalizedDate.isBefore(normalizedEndDate));
      } else {
        return (normalizedDate.isAtSameMomentAs(normalizedStartDate) ||
                normalizedDate.isAfter(normalizedStartDate)) &&
                (normalizedDate.isAtSameMomentAs(normalizedEndDate) ||
                normalizedDate.isBefore(normalizedEndDate));
      }
    }).toList();
  }

  Future<void> updateEvent(Event event) async {
    await _dbHelper.updateEvent(event.toMap());
  }

  Future<void> deleteEvent(String id) async {
    await _dbHelper.deleteEvent(id);
  }
} 