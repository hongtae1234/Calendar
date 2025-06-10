import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'database_helper.dart';
import 'holiday_helper.dart';
import 'services/transaction_service.dart';
import 'models/transaction.dart';
import 'screens/transaction_screen.dart';
import 'weather_service.dart'; // Import WeatherService
import 'screens/detailed_weather_screen.dart'; // Import DetailedWeatherScreen
import 'schedule_input_page.dart'; // Import ScheduleInputModal
import 'screens/settings_screen.dart'; // Import SettingsScreen
import 'services/auth_service.dart'; // Import AuthService
import 'screens/auth_check_screen.dart'; // Import AuthCheckScreen
import 'academic_schedule_helper.dart'; // Import AcademicScheduleHelper

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Ensure Flutter is initialized
  await AuthService.init(); // Initialize AuthService
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: const AuthCheckScreen(), // Set AuthCheckScreen as the home widget
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [
      Locale('ko', 'KR'),
    ],
  ));
}

class CalendarView extends StatefulWidget {
  @override
  _CalendarViewState createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  final DatabaseHelper dbHelper = DatabaseHelper.instance;
  DateTime currentMonth = DateTime.now();
  DateTime selectedDate = DateTime.now();
  Map<DateTime, List<String>> events = {};
  Map<String, Map<String, dynamic>> eventDetails = {};
  Color selectedColor = Colors.blue.withOpacity(0.2);

  final List<Color> colorOptions = [
    Colors.blue.withOpacity(0.2),
    Colors.red.withOpacity(0.2),
    Colors.green.withOpacity(0.2),
    Colors.orange.withOpacity(0.2),
    Colors.purple.withOpacity(0.2),
    Colors.teal.withOpacity(0.2),
  ];

  List<String> daysInWeek = ['일', '월', '화', '수', '목', '금', '토'];

  // Weather variables
  final WeatherService _weatherService = WeatherService(); // WeatherService instance
  Map<String, dynamic>? _currentWeather; // To store weather data
  String? _weatherIconUrl; // To store weather icon URL
  Map<String, dynamic>? _forecastWeather; // To store forecast weather data

  @override
  void initState() {
    super.initState();
    _initializeApp();
    _loadWeather(); // Load weather when the view initializes
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _initializeApp() async {
    await _loadEvents();
  }

  Future<void> _loadEvents() async {
    try {
      print('=== Loading Events ===');
      final loadedEvents = await dbHelper.loadEvents();
      print('Loaded ${loadedEvents.length} events from database.');
      print('Raw loaded events: $loadedEvents');

      if (loadedEvents.isEmpty) {
        setState(() {
          events = {};
          eventDetails = {};
        });
        print('No events loaded, events and eventDetails maps cleared.');
        return;
      }
      
      Map<DateTime, List<String>> newEvents = {};
      Map<String, Map<String, dynamic>> newEventDetails = {};

      for (final event in loadedEvents) {
        try {
          final startDate = DateTime.parse(event['start_date'] as String);
          final endDate = DateTime.parse(event['end_date'] as String);
          final eventId = event['id'] as String;
          final title = event['title'] as String;
          final color = event['color'] as int;
          final recurrence = event['recurrence'] as Map<String, dynamic>?;
          
          print('Processing event: $eventId');
          print('Start Date: $startDate');
          print('End Date: $endDate');
          print('Recurrence: $recurrence');
          
          // 이벤트 상세 정보 저장
          newEventDetails[eventId] = {
            'text': title,
            'color': Color(color),
            'startDate': startDate,
            'endDate': endDate,
            'recurrence': recurrence,
            'transactionId': event['transactionId'], // Load transaction ID
          };

          // 반복 일정 처리
          if (recurrence != null) {
            final type = recurrence['type'] as String?;
            final interval = recurrence['interval'] as int? ?? 1;
            final endDateStr = recurrence['end_date'] as String?;
            final recurrenceEndDate = endDateStr != null ? DateTime.tryParse(endDateStr) : null;
            final List<int>? weekDays = (recurrence['weekDays'] as List<dynamic>?)?.cast<int>();

            print('Recurrence Type: $type, Interval: $interval, Recurrence End Date: $recurrenceEndDate, Week Days: $weekDays');

            if (type != null) {
              DateTime iterationDate = DateTime(startDate.year, startDate.month, startDate.day);
              final DateTime maxRecurrenceEndDate = DateTime.now().add(Duration(days: 365 * 6));
              final DateTime effectiveRecurrenceEndDate = recurrenceEndDate != null && recurrenceEndDate.isBefore(maxRecurrenceEndDate)
                  ? DateTime(recurrenceEndDate.year, recurrenceEndDate.month, recurrenceEndDate.day)
                  : maxRecurrenceEndDate;
              print('Starting recurrence iteration from ${iterationDate} to ${effectiveRecurrenceEndDate}');

              int safeguardCounter = 0;
              const int maxIterations = 365 * 6 + 31;

              while (!iterationDate.isAfter(effectiveRecurrenceEndDate) && safeguardCounter < maxIterations) {
                bool shouldAdd = false;
                print('Checking iteration date: ${iterationDate}');

                if (type == 'daily') {
                  shouldAdd = true;
                  print('  Daily recurrence: shouldAdd = true');
                } else if (type == 'weekly') {
                  if (weekDays != null && weekDays.contains(iterationDate.weekday - 1)) {
                    shouldAdd = true;
                  }
                   print('  Weekly check for weekday ${iterationDate.weekday} (target: $weekDays), shouldAdd: $shouldAdd');
                } else if (type == 'monthly') {
                  if (iterationDate.day == startDate.day ||
                     (startDate.day > getDaysInMonth(iterationDate.year, iterationDate.month) && 
                      iterationDate.day == getDaysInMonth(iterationDate.year, iterationDate.month))) {
                    shouldAdd = true;
                  }
                  print('  Monthly check for day ${iterationDate.day} (start day ${startDate.day}), shouldAdd: $shouldAdd');
                } else if (type == 'yearly') {
                  if (iterationDate.month == startDate.month && iterationDate.day == startDate.day) {
                    shouldAdd = true;
                  }
                   print('  Yearly check for ${iterationDate.month}-${iterationDate.day} (start ${startDate.month}-${startDate.day}), shouldAdd: $shouldAdd');
                }

                if (shouldAdd) {
                  final dateKey = DateTime(iterationDate.year, iterationDate.month, iterationDate.day);
                  DateTime currentEventDate = dateKey;
                   final singleEventEndDate = DateTime(currentEventDate.year, currentEventDate.month, currentEventDate.day)
                                           .add(Duration(days: endDate.difference(startDate).inDays));
                   print('  Adding event instance for $eventId from $currentEventDate to $singleEventEndDate');

                   while(!currentEventDate.isAfter(singleEventEndDate)){
                      final eventDateKey = DateTime(currentEventDate.year, currentEventDate.month, currentEventDate.day);
                      if (!newEvents.containsKey(eventDateKey)) {
                        newEvents[eventDateKey] = [];
                      }
                      if (!newEvents[eventDateKey]!.contains(eventId)) {
                        newEvents[eventDateKey]!.add(eventId);
                        print('    Added $eventId to date $eventDateKey');
                      }
                       currentEventDate = currentEventDate.add(Duration(days: 1));
                   }
                }

                // 다음 반복 날짜 계산 및 safeguard 증가
                if (type == 'daily') {
                  iterationDate = iterationDate.add(Duration(days: interval));
                } else if (type == 'weekly') {
                   iterationDate = iterationDate.add(Duration(days: 1));
                } else if (type == 'monthly') {
                  final int nextMonth = iterationDate.month + interval;
                  final int nextYear = iterationDate.year + (nextMonth - 1) ~/ 12;
                  final int targetMonth = (nextMonth - 1) % 12 + 1;
                  final int daysInNextMonth = getDaysInMonth(nextYear, targetMonth);
                  final int targetDay = startDate.day < daysInNextMonth ? startDate.day : daysInNextMonth;
                  iterationDate = DateTime(nextYear, targetMonth, targetDay);
                } else if (type == 'yearly') {
                  iterationDate = DateTime(iterationDate.year + interval, iterationDate.month, iterationDate.day);
                }
                safeguardCounter++;
              }
              if(safeguardCounter >= maxIterations) {
                print('Warning: Recurrence iteration limit reached for event $eventId');
              }
            }
          } else {
            // 반복이 아닌 일반 일정 처리
            DateTime iterDate = DateTime(startDate.year, startDate.month, startDate.day);
            final endDateOnly = DateTime(endDate.year, endDate.month, endDate.day);

            print('Processing single event: $eventId from $iterDate to $endDateOnly');

            while (!iterDate.isAfter(endDateOnly)) {
              final dateKey = DateTime(iterDate.year, iterDate.month, iterDate.day);
               if (!newEvents.containsKey(dateKey)) {
                newEvents[dateKey] = [];
              }
              if (!newEvents[dateKey]!.contains(eventId)) {
                newEvents[dateKey]!.add(eventId);
                print('Added single event $eventId to date $dateKey');
              }
              iterDate = iterDate.add(Duration(days: 1));
            }
          }
        } catch (e) {
          print('Error processing event: $e');
          print('Event data: $event');
          print('Stack trace: ${StackTrace.current}');
        }
      }

      setState(() {
        events = newEvents;
        eventDetails = newEventDetails;
      });

      print('=== Events Loading Complete ===');
      print('Total events in map: ${events.length}');
      print('Total event details: ${eventDetails.length}');
      print('Events map sample:');
      events.forEach((date, eventIds) {
        print('Date: $date');
        print('Event IDs: $eventIds');
        eventIds.forEach((id) {
          print('Event details for $id: ${eventDetails[id]}');
        });
      });

    } catch (e) {
      print('Error loading events: $e');
      print('Stack trace: ${e.toString()}');
    }
  }

  void _addEventToDate(Map<DateTime, List<String>> events, String eventId, DateTime date) {
    final dateKey = DateTime(date.year, date.month, date.day);
    if (!events.containsKey(dateKey)) {
      events[dateKey] = [];
    }
    if (!events[dateKey]!.contains(eventId)) {
      events[dateKey]!.add(eventId);
      print('__addEventToDate: Added $eventId to $dateKey. Current list: ${events[dateKey]}');
    }
     else {
       print('__addEventToDate: $eventId already exists for $dateKey');
     }
  }

  Future<void> _saveEvent(String text, DateTime startDate, DateTime endDate, Color color, [Map<String, dynamic>? recurrenceSettings]) async {
    print('=== Starting Event Save ===');
    print('Input validation:');
    print('Text: $text');
    print('Start Date: $startDate');
    print('End Date: $endDate');
    print('Color: $color');
    print('Recurrence Settings: $recurrenceSettings');

    if (text.isEmpty) {
      print('Error: Event text is empty');
      return;
    }

    if (startDate == null || endDate == null) {
      print('Error: Start date or end date is null');
      return;
    }

    if (startDate.isAfter(endDate)) {
      print('Error: Start date is after end date');
      return;
    }

    final eventId = '${text}_${DateTime.now().millisecondsSinceEpoch}';
    final eventData = {
      'id': eventId,
      'title': text,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'color': color.value,
      'recurrence': recurrenceSettings,
    };

    try {
      print('=== Saving Event ===');
      print('Event ID: $eventId');
      print('Event Data: $eventData');
      
      await dbHelper.saveEvent(eventData);
      print('Event saved successfully to database.');
      
      // 저장된 이벤트를 현재 상태에 추가
      final newEventDetailsEntry = {
        'text': text,
        'color': color,
        'startDate': startDate,
        'endDate': endDate,
        'recurrence': recurrenceSettings,
      };
      
      // eventDetails 맵 업데이트
      eventDetails[eventId] = newEventDetailsEntry;
      print('eventDetails updated for $eventId: ${eventDetails[eventId]}');

      // events 맵 업데이트 (반복 이벤트 고려) - _addEventToDate 함수 사용
      if (recurrenceSettings != null) {
        final type = recurrenceSettings['type'] as String?;
        final interval = recurrenceSettings['interval'] as int? ?? 1;
        final endDateStr = recurrenceSettings['end_date'] as String?;
        final recurrenceEndDate = endDateStr != null ? DateTime.tryParse(endDateStr) : null;
        final List<int>? weekDays = (recurrenceSettings['weekDays'] as List<dynamic>?)?.cast<int>();
        
        print('Updating events map for recurring event $eventId using _addEventToDate');
        print('Recurrence Type: $type, Interval: $interval, Recurrence End Date: $recurrenceEndDate, Week Days: $weekDays');

        if (type != null) {
          DateTime iterationDate = DateTime(startDate.year, startDate.month, startDate.day);
          final DateTime maxRecurrenceEndDate = DateTime.now().add(Duration(days: 365 * 6));
          final DateTime effectiveRecurrenceEndDate = recurrenceEndDate != null && recurrenceEndDate.isBefore(maxRecurrenceEndDate)
              ? DateTime(recurrenceEndDate.year, recurrenceEndDate.month, recurrenceEndDate.day)
              : maxRecurrenceEndDate;
              
          print('Starting recurrence instance generation from ${iterationDate} to ${effectiveRecurrenceEndDate}');

          int safeguardCounter = 0;
          const int maxIterations = 365 * 6 + 31;

          while (!iterationDate.isAfter(effectiveRecurrenceEndDate) && safeguardCounter < maxIterations) {
            bool shouldAdd = false;
            
            if (type == 'daily') {
              shouldAdd = true;
            } else if (type == 'weekly') {
              if (weekDays != null && weekDays.contains(iterationDate.weekday -1)) {
                shouldAdd = true;
              }
            } else if (type == 'monthly') {
              if (iterationDate.day == startDate.day ||
                 (startDate.day > getDaysInMonth(iterationDate.year, iterationDate.month) && 
                  iterationDate.day == getDaysInMonth(iterationDate.year, iterationDate.month))) {
                shouldAdd = true;
              }
            } else if (type == 'yearly') {
              if (iterationDate.month == startDate.month && iterationDate.day == startDate.day) {
                shouldAdd = true;
              }
            }

            if (shouldAdd) {
               final dateKey = DateTime(iterationDate.year, iterationDate.month, iterationDate.day);
               DateTime currentEventDate = dateKey;
               final singleEventEndDate = DateTime(currentEventDate.year, currentEventDate.month, currentEventDate.day)
                                       .add(Duration(days: endDate.difference(startDate).inDays));

               print('  Adding event instance for $eventId from $currentEventDate to $singleEventEndDate');

               while(!currentEventDate.isAfter(singleEventEndDate)){
                  _addEventToDate(events, eventId, currentEventDate);
                  currentEventDate = currentEventDate.add(Duration(days: 1));
               }
            }

            // 다음 반복 날짜 계산
            if (type == 'daily') {
              iterationDate = iterationDate.add(Duration(days: interval));
            } else if (type == 'weekly') {
              iterationDate = iterationDate.add(Duration(days: 1));
            } else if (type == 'monthly') {
              final int nextMonth = iterationDate.month + interval;
              final int nextYear = iterationDate.year + (nextMonth - 1) ~/ 12;
              final int targetMonth = (nextMonth - 1) % 12 + 1;
              final int daysInNextMonth = getDaysInMonth(nextYear, targetMonth);
              final int targetDay = startDate.day < daysInNextMonth ? startDate.day : daysInNextMonth;
              iterationDate = DateTime(nextYear, targetMonth, targetDay);
            } else if (type == 'yearly') {
              iterationDate = DateTime(iterationDate.year + interval, iterationDate.month, iterationDate.day);
            }
            safeguardCounter++;
          }
           if(safeguardCounter >= maxIterations) {
            print('Warning: Recurrence instance generation limit reached for event $eventId in _saveEvent');
          }
        }
      } else {
        // 반복이 아닌 일반 일정 처리 - _addEventToDate 함수 사용
        DateTime iterDate = DateTime(startDate.year, startDate.month, startDate.day);
        final endDateOnly = DateTime(endDate.year, endDate.month, endDate.day);

        print('Updating events map for single event $eventId from $iterDate to $endDateOnly using _addEventToDate');

        while (!iterDate.isAfter(endDateOnly)) {
          _addEventToDate(events, eventId, iterDate);
          iterDate = iterDate.add(Duration(days: 1));
        }
      }

      setState(() {
        print('setState called after event save');
      });
      print('setState completed');
      
      print('=== Final State After Save Update ===');
      print('Events map size: ${events.length}');
      print('Event details map size: ${eventDetails.length}');
      print('Events map sample:');
      events.forEach((date, eventIds) {
        print('Date: $date');
        print('Event IDs: $eventIds');
        eventIds.forEach((id) {
          print('Event details for $id: ${eventDetails[id]}');
        });
      });

    } catch (e) {
      print('Error saving event: $e');
      print('Event data: $eventData');
      print('Stack trace: ${e.toString()}');
    }
  }

  Future<void> _updateEvent(String eventId, String text, DateTime startDate, DateTime endDate, Color color, Map<String, dynamic>? recurrenceSettings) async {
    print('=== Starting Event Update ===');
    print('Event ID: $eventId');
    print('Text: $text');
    print('Start Date: $startDate');
    print('End Date: $endDate');
    print('Color: $color');
    print('Recurrence Settings: $recurrenceSettings');

    final eventData = {
      'id': eventId,
      'title': text,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'color': color.value,
      'recurrence': recurrenceSettings,
    };

    try {
      print('Updating event in database...');
      await dbHelper.saveEvent(eventData);
      print('Event $eventId updated successfully in database.');

      print('Reloading events after update...');
      await _loadEvents();
      print('Events reloaded after update.');

      setState(() {
        print('setState called after event update');
      });

    } catch (e) {
      print('Error updating event $eventId: $e');
      print('Event data: $eventData');
      print('Stack trace: ${StackTrace.current}');
    }
  }

  Future<void> _deleteEvent(String eventId) async {
    try {
      print('=== Starting Event Delete ===');
      print('Attempting to delete event with ID: $eventId');

      await dbHelper.deleteEvent(eventId);
      print('Event $eventId deleted successfully from database.');
      
      print('Reloading events after deletion...');
      await _loadEvents();
      print('Events reloaded after deletion.');

      setState(() {
        print('setState called after event deletion');
      });

    } catch (e) {
      print('Error deleting event $eventId: $e');
      print('Stack trace: ${e.toString()}');
    }
  }

  void goToPrevMonth() {
    setState(() {
      currentMonth = DateTime(currentMonth.year, currentMonth.month - 1);
    });
  }

  void goToNextMonth() {
    setState(() {
      currentMonth = DateTime(currentMonth.year, currentMonth.month + 1);
    });
  }

  int getDaysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  int getStartDay(int year, int month) {
    return DateTime(year, month, 1).weekday % 7;
  }

  bool isSameDate(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  Future<void> _handleEventAction(
    String action,
    String? eventId,
    String? text,
    DateTime? startDate,
    DateTime? endDate,
    Color? color,
    Map<String, dynamic>? recurrence,
  ) async {
    if (action == 'save') {
      await _saveEvent(text!, startDate!, endDate!, color!);
    } else if (action == 'update') {
      if (eventId == null || text == null || startDate == null || endDate == null || color == null) {
        print('Error: Missing parameters for update action.');
        return;
      }
      await _updateEvent(eventId, text, startDate, endDate, color, recurrence);
    } else if (action == 'delete') {
      if (eventId == null) {
        print('Error: Missing eventId for delete action.');
        return;
      }
      await _deleteEvent(eventId);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 현재 월의 이벤트 위치 계산
    final eventPositions = _calculateEventPositions(currentMonth);
    
    return Scaffold(
      backgroundColor: Color(0xFFFDF6E4),
      appBar: AppBar(
        backgroundColor: Color(0xFFFDF6E4),
        elevation: 0,
        centerTitle: true,
        title: Text(
          DateFormat('yyyy년 M월', 'ko_KR').format(currentMonth),
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(Icons.chevron_left, color: Colors.black),
          onPressed: goToPrevMonth,
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.chevron_right, color: Colors.black),
            onPressed: goToNextMonth,
          ),
        ],
      ),
      body: Column(
        children: [
          // Display Weather Info
          if (_currentWeather != null)
            GestureDetector(
              onTap: _loadForecastWeather,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_weatherIconUrl != null)
                      Image.network(_weatherIconUrl!, width: 40, height: 40),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_currentWeather!['description']}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${_currentWeather!['temperature'].toStringAsFixed(1)}°C',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: daysInWeek
                .map((day) => Expanded(
                      child: Center(
                        child: Text(
                          day,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: day == '일' ? Colors.red : Colors.black,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          Expanded(
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1.0,
                mainAxisSpacing: 2.0,
                crossAxisSpacing: 2.0,
              ),
              itemCount: getDaysInMonth(currentMonth.year, currentMonth.month) + getStartDay(currentMonth.year, currentMonth.month),
              itemBuilder: (context, index) {
                int startDay = getStartDay(currentMonth.year, currentMonth.month);
                int totalDays = getDaysInMonth(currentMonth.year, currentMonth.month);

                if (index < startDay) return Container();
                int day = index - startDay + 1;
                DateTime cellDate = DateTime(currentMonth.year, currentMonth.month, day);
                bool isToday = isSameDate(cellDate, DateTime.now());
                final cellEvents = events[cellDate] ?? [];
                
                print('=== Cell Date: $cellDate ===');
                print('Events for this date: $cellEvents');
                if (cellEvents.isNotEmpty) {
                  print('Event details:');
                  for (var eventId in cellEvents) {
                    print('Event ID: $eventId');
                    print('Event Details: ${eventDetails[eventId]}');
                  }
                }

                bool isHoliday = HolidayHelper.isHoliday(cellDate);
                String? holidayName = HolidayHelper.getHolidayName(cellDate);

                String? academicScheduleName = AcademicScheduleHelper.getAcademicScheduleName(cellDate);
                print('Debug: cellDate: $cellDate, academicScheduleName: $academicScheduleName'); // 디버그용 출력

                bool hasRecurringEvent = cellEvents.any((eventId) {
                   final event = eventDetails[eventId];
                   return event != null && event['recurrence'] != null;
                });

                return GestureDetector(
                  onTap: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (BuildContext context) {
                      return ScheduleInputModal(
                        selectedDate: cellDate,
                        events: events,
                        eventDetails: eventDetails,
                        colorOptions: colorOptions,
                        dbHelper: dbHelper,
                        onEventAction: (action, eventId, text, startDate, endDate, color, recurrenceSettings) async {
                           if (action == 'save') {
                             await _saveEvent(text!, startDate!, endDate!, color!, recurrenceSettings);
                           } else if (action == 'update') {
                             await _updateEvent(eventId!, text!, startDate!, endDate!, color!, recurrenceSettings);
                           } else if (action == 'delete') {
                             await _deleteEvent(eventId!);
                           }
                        },
                      );
                    },
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: isSameDate(cellDate, selectedDate) ? Colors.blue.withOpacity(0.1) : null,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$day',
                              style: TextStyle(
                                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                color: isHoliday
                                    ? Colors.red
                                    : (academicScheduleName != null
                                        ? AcademicScheduleHelper.getAcademicScheduleColor() // 학사 일정 색상
                                        : (hasRecurringEvent ? Colors.purple : (isToday ? Colors.blue : Colors.black))),
                              ),
                            ),
                          ),
                        ),
                        if (holidayName != null) // 공휴일 우선 표시
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Text(
                              holidayName,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.red,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          )
                        else if (academicScheduleName != null) // 공휴일이 아니면 학사 일정 표시
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Text(
                              academicScheduleName,
                              style: TextStyle(
                                fontSize: 10,
                                color: AcademicScheduleHelper.getAcademicScheduleColor(), // 학사 일정 색상
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        Expanded(
                          child: cellEvents.isEmpty
                              ? Container()
                              : Stack(
                                  children: cellEvents.map((eventId) {
                                    final event = eventDetails[eventId];
                                    if (event == null) {
                                      print('Warning: Event details not found for ID: $eventId');
                                      return Container();
                                    }

                                    final startDate = event['startDate'] as DateTime;
                                    final endDate = event['endDate'] as DateTime;
                                    final text = event['text'] as String;
                                    final color = event['color'] as Color;
                                    final position = eventPositions[eventId] ?? 0;

                                    print('Rendering event: $text');
                                    print('Start Date: $startDate');
                                    print('End Date: $endDate');
                                    print('Position: $position');

                                    // Check if cellDate is the start day or within the event duration
                                    bool isEventDay = (isSameDate(cellDate, startDate) || 
                                                       (cellDate.isAfter(startDate) && !cellDate.isAfter(endDate)));

                                    return Positioned(
                                      top: position * 18.0,
                                      left: 0,
                                      right: 0,
                                      child: Container(
                                        height: 16,
                                        margin: EdgeInsets.symmetric(vertical: 1),
                                        decoration: BoxDecoration(
                                          color: color,
                                          borderRadius: BorderRadius.horizontal(
                                            left: Radius.circular(isSameDate(cellDate, startDate) ? 4 : 0),
                                            right: Radius.circular(isSameDate(cellDate, endDate) ? 4 : 0),
                                          ),
                                        ),
                                        child: (
                                           event['recurrence'] == null
                                           ? isSameDate(cellDate, startDate)
                                           : true
                                        )
                                          ? Padding(
                                              padding: EdgeInsets.symmetric(horizontal: 4),
                                              child: Text(
                                                text,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.black87,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            )
                                          : null,
                                      ),
                                    );
                                  }).toList(),
                                ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }

  Future<void> _loadWeather() async {
    try {
      final weather = await _weatherService.getCurrentWeather();
      setState(() {
        _currentWeather = weather;
        if (weather != null) {
          _weatherIconUrl = weather['iconUrl'] as String?;
        }
      });
    } catch (e) {
      print('Error loading weather: $e');
    }
  }

  Future<void> _loadForecastWeather() async {
    try {
      final forecast = await _weatherService.getForecastWeather();
      setState(() {
        _forecastWeather = forecast;
      });
      // Show detailed weather screen
      if (mounted && _forecastWeather != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetailedWeatherScreen(
              forecastData: _forecastWeather!,
            ),
          ),
        );
      }
    } catch (e) {
      print('Error loading forecast weather: $e');
    }
  }

  Map<String, int> _calculateEventPositions(DateTime month) {
    Map<String, int> positions = {};
    Map<DateTime, List<String>> monthEvents = {};
    
    // 해당 월의 이벤트만 필터링
    events.forEach((date, eventIds) {
      if (date.year == month.year && date.month == month.month) {
        monthEvents[date] = eventIds;
      }
    });

    // 각 날짜별로 이벤트 위치 계산
    monthEvents.forEach((date, eventIds) {
      for (int i = 0; i < eventIds.length; i++) {
        positions[eventIds[i]] = i;
      }
    });

    return positions;
  }
}

// New MainScreen widget to manage BottomNavigationBar
class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // List of screens for each tab
  final List<Widget> _screens = [
    CalendarView(),
    const TransactionScreen(),
    const SettingsScreen(), // Add SettingsScreen
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: '캘린더',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: '가계부',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: '설정',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        onTap: _onItemTapped,
      ),
    );
  }
}


