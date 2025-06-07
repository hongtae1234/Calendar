import 'package:flutter/material.dart';

enum EventRepeatType {
  none('없음'),
  daily('매일'),
  weekly('매주'),
  monthly('매월'),
  yearly('매년');

  final String label;
  const EventRepeatType(this.label);

  static EventRepeatType fromString(String type) {
    return EventRepeatType.values.firstWhere(
      (e) => e.name == type,
      orElse: () => EventRepeatType.none,
    );
  }
}

enum EventCategory {
  study('공부', Colors.blue),
  work('업무', Colors.green),
  personal('개인', Colors.purple),
  meeting('회의', Colors.orange),
  exercise('운동', Colors.teal),
  etc('기타', Colors.grey);

  final String label;
  final Color color;
  const EventCategory(this.label, this.color);

  static EventCategory fromString(String category) {
    return EventCategory.values.firstWhere(
      (e) => e.name == category,
      orElse: () => EventCategory.etc,
    );
  }
}

class Event {
  final String id;
  String title;
  String? description;
  DateTime startDate;
  DateTime endDate;
  EventCategory category;
  EventRepeatType repeatType;
  DateTime? recurrenceEndDate;
  List<int>? recurrenceWeekDays;
  bool hasNotification;

  Event({
    required this.id,
    required this.title,
    this.description,
    required this.startDate,
    required this.endDate,
    this.category = EventCategory.etc,
    this.repeatType = EventRepeatType.none,
    this.recurrenceEndDate,
    this.recurrenceWeekDays,
    this.hasNotification = false,
  });

  // Convert Event object to a Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'category': category.name,
      'repeat_type': repeatType.name,
      'recurrence_end_date': recurrenceEndDate?.toIso8601String(),
      'recurrence_week_days': recurrenceWeekDays != null ? recurrenceWeekDays!.join(',') : null,
      'has_notification': hasNotification ? 1 : 0,
    };
  }

  // Create Event object from a Map (from database)
  factory Event.fromMap(Map<String, dynamic> map) {
    return Event(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      startDate: DateTime.parse(map['start_date'] as String),
      endDate: DateTime.parse(map['end_date'] as String),
      category: EventCategory.fromString(map['category'] as String),
      repeatType: EventRepeatType.fromString(map['repeat_type'] as String),
      recurrenceEndDate: map['recurrence_end_date'] != null
          ? DateTime.parse(map['recurrence_end_date'] as String)
          : null,
      recurrenceWeekDays: map['recurrence_week_days'] != null
          ? (map['recurrence_week_days'] as String).split(',').map(int.parse).toList()
          : null,
      hasNotification: (map['has_notification'] as int) == 1,
    );
  }
} 