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
import 'services/auth_service.dart'; // Import AuthService
import 'screens/login_screen.dart'; // Import LoginScreen for navigation
import 'screens/settings_screen.dart'; // Import SettingsScreen
import 'screens/auth_check_screen.dart'; // Import AuthCheckScreen

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.init();
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: AuthCheckScreen(),
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
  late TextEditingController _eventController;

  // Add editing state variables
  bool _isEditing = false;
  String? _editingEventId;
  late TextEditingController _editingEventController;
  DateTime? _editingStartDateTime;
  DateTime? _editingEndDateTime;
  Color? _editingSelectedColor;
  Map<String, dynamic>? _editingRecurrenceSettings;
  List<bool> _editingSelectedWeekDays = List.filled(7, false);
  DateTime? _editingRecurrenceEndDate;

  final List<Color> colorOptions = [
    Colors.blue.withOpacity(0.2),
    Colors.red.withOpacity(0.2),
    Colors.green.withOpacity(0.2),
    Colors.orange.withOpacity(0.2),
    Colors.purple.withOpacity(0.2),
    Colors.teal.withOpacity(0.2),
  ];

  DateTime? _startDateTime;
  DateTime? _endDateTime;
  bool _selectingStart = true;

  List<String> daysInWeek = ['일', '월', '화', '수', '목', '금', '토'];

  // 반복 설정을 위한 변수들
  Map<String, dynamic>? _recurrenceSettings;
  final List<String> _recurrenceTypes = ['none', 'daily', 'weekly', 'monthly', 'yearly'];
  final List<String> _weekDays = ['월', '화', '수', '목', '금', '토', '일'];
  List<bool> _selectedWeekDays = List.filled(7, false);
  DateTime? _recurrenceEndDate;

  // Weather variables
  final WeatherService _weatherService = WeatherService(); // WeatherService instance
  Map<String, dynamic>? _currentWeather; // To store weather data
  String? _weatherIconUrl; // To store weather icon URL
  Map<String, dynamic>? _forecastWeather; // To store forecast weather data

  @override
  void initState() {
    super.initState();
    _eventController = TextEditingController();
    _editingEventController = TextEditingController();
    _initializeApp();
    _loadWeather(); // Load weather when the view initializes
  }

  @override
  void dispose() {
    _eventController.dispose();
    _editingEventController.dispose();
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
              DateTime iterationDate = DateTime(startDate.year, startDate.month, startDate.day); // 반복 시작 날짜는 이벤트의 시작 날짜 기준
              final DateTime maxRecurrenceEndDate = DateTime.now().add(Duration(days: 365 * 6)); // 최대 6년 반복 제한
              final DateTime effectiveRecurrenceEndDate = recurrenceEndDate != null && recurrenceEndDate.isBefore(maxRecurrenceEndDate)
                  ? DateTime(recurrenceEndDate.year, recurrenceEndDate.month, recurrenceEndDate.day) // 시간 정보 제외
                  : maxRecurrenceEndDate; // 반복 종료일이 없으면 최대 반복 제한일까지

              print('Starting recurrence iteration from ${iterationDate} to ${effectiveRecurrenceEndDate}');

              int safeguardCounter = 0; // 무한 루프 방지
              const int maxIterations = 365 * 6 + 31; // 최대 6년 + 여유

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
                  // 월간 반복: 이벤트 시작 날짜의 '일'과 현재 날짜의 '일'이 같으면 추가
                  // 또는 시작일이 말일인데 해당 월의 말일이 다르면 해당 월의 말일에 추가
                  if (iterationDate.day == startDate.day ||
                     (startDate.day > getDaysInMonth(iterationDate.year, iterationDate.month) && 
                      iterationDate.day == getDaysInMonth(iterationDate.year, iterationDate.month))) {
                    shouldAdd = true;
                  }
                  print('  Monthly check for day ${iterationDate.day} (start day ${startDate.day}), shouldAdd: $shouldAdd');
                } else if (type == 'yearly') {
                  // 연간 반복: 이벤트 시작 날짜의 '월'과 '일'이 현재 날짜와 같으면 추가
                  if (iterationDate.month == startDate.month && iterationDate.day == startDate.day) {
                    shouldAdd = true;
                  }
                   print('  Yearly check for ${iterationDate.month}-${iterationDate.day} (start ${startDate.month}-${startDate.day}), shouldAdd: $shouldAdd');
                }

                if (shouldAdd) {
                  final dateKey = DateTime(iterationDate.year, iterationDate.month, iterationDate.day);
                  // 이벤트의 전체 기간을 고려하여 해당 기간의 모든 날짜에 eventId 추가
                  DateTime currentEventDate = dateKey; // 현재 반복 인스턴스의 시작 날짜
                   final singleEventEndDate = DateTime(currentEventDate.year, currentEventDate.month, currentEventDate.day) // 현재 반복 인스턴스의 종료 날짜 (원래 이벤트 기간 적용)
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
                   // 주간 반복은 weekDays에 해당하는 날짜를 찾을 때까지 매일 1일씩 증가
                   iterationDate = iterationDate.add(Duration(days: 1));
                } else if (type == 'monthly') {
                   // 월간 반복: interval 만큼 월을 증가
                  final int nextMonth = iterationDate.month + interval;
                  final int nextYear = iterationDate.year + (nextMonth - 1) ~/ 12;
                  final int targetMonth = (nextMonth - 1) % 12 + 1;
                  final int daysInNextMonth = getDaysInMonth(nextYear, targetMonth);
                  final int targetDay = startDate.day < daysInNextMonth ? startDate.day : daysInNextMonth;
                  iterationDate = DateTime(nextYear, targetMonth, targetDay);
                } else if (type == 'yearly') {
                  // 연간 반복: interval 만큼 연을 증가
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
      print('__addEventToDate: Added $eventId to $dateKey. Current list: ${events[dateKey]}'); // Debug print
    }
     else {
       print('__addEventToDate: $eventId already exists for $dateKey'); // Debug print
     }
  }

  Future<void> _saveEvent(String text, DateTime startDate, DateTime endDate, Color color) async {
    print('=== Starting Event Save ===');
    print('Input validation:');
    print('Text: $text');
    print('Start Date: $startDate');
    print('End Date: $endDate');
    print('Color: $color');
    print('Recurrence Settings: $_recurrenceSettings');

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
      'recurrence': _recurrenceSettings,
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
        'recurrence': _recurrenceSettings,
      };
      
      // eventDetails 맵 업데이트
      eventDetails[eventId] = newEventDetailsEntry;
      print('eventDetails updated for $eventId: ${eventDetails[eventId]}');

      // events 맵 업데이트 (반복 이벤트 고려) - _addEventToDate 함수 사용
      if (_recurrenceSettings != null) {
        final type = _recurrenceSettings!['type'] as String?;
        final interval = _recurrenceSettings!['interval'] as int? ?? 1;
        final endDateStr = _recurrenceSettings!['end_date'] as String?;
        final recurrenceEndDate = endDateStr != null ? DateTime.tryParse(endDateStr) : null;
        final List<int>? weekDays = (_recurrenceSettings!['weekDays'] as List<dynamic>?)?.cast<int>();
        
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
               // 이벤트의 전체 기간을 고려하여 해당 기간의 모든 날짜에 eventId 추가
               DateTime currentEventDate = dateKey;
               final singleEventEndDate = DateTime(currentEventDate.year, currentEventDate.month, currentEventDate.day)
                                       .add(Duration(days: endDate.difference(startDate).inDays));

               print('  Adding event instance for $eventId from $currentEventDate to $singleEventEndDate');

               while(!currentEventDate.isAfter(singleEventEndDate)){
                  _addEventToDate(events, eventId, currentEventDate); // Use _addEventToDate
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
          _addEventToDate(events, eventId, iterDate); // Use _addEventToDate
          iterDate = iterDate.add(Duration(days: 1));
        }
      }

      _recurrenceSettings = null;

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
      print('Stack trace: ${StackTrace.current}');
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
      print('Stack trace: ${StackTrace.current}');
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

  // Modify _showDateTimePickerWithSetter to work with local modal state
  void _showDateTimePickerWithSetter({
    required StateSetter modalSetState,
    required DateTime? currentStartDateTime,
    required DateTime? currentEndDateTime,
    required Function(DateTime) onStartDateTimeChanged,
    required Function(DateTime) onEndDateTimeChanged,
  }) {
    bool _selectingStart = true;
    DateTime _tempStartDateTime = currentStartDateTime ?? DateTime.now();
    DateTime _tempEndDateTime = currentEndDateTime ?? DateTime.now();

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return SizedBox(
              height: 350,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => setStateDialog(() => _selectingStart = true),
                          child: Text(
                            '시작: ${DateFormat('M월 d일 E HH:mm', 'ko_KR').format(_tempStartDateTime)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _selectingStart ? Colors.blue : Colors.black,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setStateDialog(() => _selectingStart = false),
                          child: Text(
                            '종료: ${DateFormat('M월 d일 E HH:mm', 'ko_KR').format(_tempEndDateTime)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: !_selectingStart ? Colors.blue : Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.dateAndTime,
                      initialDateTime: _selectingStart ? _tempStartDateTime : _tempEndDateTime,
                      use24hFormat: true,
                      onDateTimeChanged: (DateTime newDateTime) {
                        setStateDialog(() {
                          if (_selectingStart) {
                            _tempStartDateTime = newDateTime;
                          } else {
                            _tempEndDateTime = newDateTime;
                          }
                        });
                      },
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      TextButton(onPressed: () => Navigator.pop(context), child: Text('취소')),
                      TextButton(
                        onPressed: () {
                          print('Time picker modal: Confirm pressed.');
                          print('Time picker modal: _tempStartDateTime = ${_tempStartDateTime}');
                          print('Time picker modal: _tempEndDateTime = ${_tempEndDateTime}');

                          onStartDateTimeChanged(_tempStartDateTime);
                          onEndDateTimeChanged(_tempEndDateTime);

                          modalSetState(() {});
                          Navigator.pop(context);
                        },
                        child: Text('확인'),
                      ),
                    ],
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 반복 설정 다이얼로그를 보여주는 메서드
  void _showRecurrenceDialog(BuildContext context, void Function(void Function()) setState) {
    String selectedType = _recurrenceSettings?['type'] ?? 'none';
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text('반복 설정'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      items: [
                        DropdownMenuItem(value: 'none', child: Text('반복 안 함')),
                        DropdownMenuItem(value: 'daily', child: Text('매일')),
                        DropdownMenuItem(value: 'weekly', child: Text('매주')),
                        DropdownMenuItem(value: 'monthly', child: Text('매월')),
                        DropdownMenuItem(value: 'yearly', child: Text('매년')),
                      ],
                      onChanged: (value) {
                        setStateDialog(() {
                          selectedType = value!;
                          if (value == 'none') {
                            _recurrenceSettings = null;
                          } else {
                            _recurrenceSettings = {
                              'type': value,
                              'interval': 1,
                              'end_date': _recurrenceEndDate?.toIso8601String(),
                            };
                          }
                        });
                      },
                    ),
                    if (selectedType == 'weekly') ...[
                      SizedBox(height: 16),
                      Text('반복할 요일 선택:', style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: List.generate(7, (index) {
                          return FilterChip(
                            label: Text(_weekDays[index]),
                            selected: _selectedWeekDays[index],
                            onSelected: (bool selected) {
                              setStateDialog(() {
                                _selectedWeekDays[index] = selected;
                                if (_recurrenceSettings != null) {
                                  if (_selectedWeekDays[index]) {
                                    if (_recurrenceSettings!['weekDays'] == null) {
                                      _recurrenceSettings!['weekDays'] = [];
                                    }
                                    if (!_recurrenceSettings!['weekDays'].contains(index)) {
                                      _recurrenceSettings!['weekDays'].add(index);
                                    }
                                  } else {
                                    _recurrenceSettings!['weekDays'].remove(index);
                                  }
                                   print('Recurrence Dialog: weekDays updated to ${_recurrenceSettings!['weekDays']}');
                                }
                              });
                            },
                          );
                        }),
                      ),
                    ],
                    if (selectedType != 'none') ...[
                      SizedBox(height: 16),
                      Text('반복 종료일:', style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _recurrenceEndDate ?? DateTime.now().add(Duration(days: 30)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(Duration(days: 365 * 5)),
                          );
                          if (picked != null) {
                            setStateDialog(() {
                              _recurrenceEndDate = picked;
                              if (_recurrenceSettings != null) {
                                _recurrenceSettings!['end_date'] = picked.toIso8601String();
                              }
                            });
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _recurrenceEndDate != null
                                ? DateFormat('yyyy년 M월 d일', 'ko_KR').format(_recurrenceEndDate!)
                                : '종료일 선택',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _recurrenceSettings = null;
                    _selectedWeekDays = List.filled(7, false);
                    _recurrenceEndDate = null;
                    Navigator.pop(context);
                  },
                  child: Text('취소'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {});
                    Navigator.pop(context);
                  },
                  child: Text('확인'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Modify _openScheduleInputPage to correctly use the updated _showDateTimePickerWithSetter
  void _openScheduleInputPage(DateTime date) {
    // Initialize new event state variables
    DateTime? _startDateTime = date;
    DateTime? _endDateTime = date;
    final TextEditingController _newEventController = TextEditingController();
    Color _selectedColor = colorOptions[0];

    // Reset editing state variables when opening for a new event
    if (!_isEditing) {
      _editingEventId = null;
      _editingEventController.clear();
      _editingStartDateTime = null;
      _editingEndDateTime = null;
      _editingSelectedColor = null;
      _editingRecurrenceSettings = null;
      _editingSelectedWeekDays = List.filled(7, false);
      _editingRecurrenceEndDate = null;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter modalSetState) {
            print('Event input modal: Building/Rebuilding.');
            print('Event input modal: _startDateTime = ${_startDateTime}');
            print('Event input modal: _endDateTime = ${_endDateTime}');
            print('Event input modal: _isEditing = ${_isEditing}');

            final List<String> eventsOnSelectedDate = events[date] ?? [];

            final currentEventController = _isEditing ? _editingEventController : _newEventController;
            DateTime? currentStartDateTime = _isEditing ? _editingStartDateTime : _startDateTime;
            DateTime? currentEndDateTime = _isEditing ? _editingEndDateTime : _endDateTime;
            Color currentColor = _isEditing ? (_editingSelectedColor ?? colorOptions[0]) : _selectedColor;
            Map<String, dynamic>? currentRecurrenceSettings = _isEditing ? _editingRecurrenceSettings : _recurrenceSettings;
            List<bool> currentSelectedWeekDays = _isEditing ? _editingSelectedWeekDays : _selectedWeekDays;
            DateTime? currentRecurrenceEndDate = _isEditing ? _editingRecurrenceEndDate : _recurrenceEndDate;

            String _transactionType = 'expense';
            int? _transactionAmount;
            String _transactionNote = '';

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('yyyy년 M월 d일 EEEE', 'ko_KR').format(date),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    if (!_isEditing) ...[
                      const Text('현재 일정:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (eventsOnSelectedDate.isEmpty)
                        const Text('해당 날짜에 일정이 없습니다.')
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: eventsOnSelectedDate.map((eventId) {
                            final event = eventDetails[eventId];
                            if (event == null) return Container();
                            return GestureDetector(
                              onTap: () {
                                modalSetState(() {
                                  print('Tapped on event for editing: $eventId');
                                  _editingEventId = eventId;
                                  _editingEventController.text = event['text'];
                                  _editingStartDateTime = event['startDate'];
                                  _editingEndDateTime = event['endDate'];
                                  _editingSelectedColor = event['color'];
                                  _isEditing = true;

                                  _editingRecurrenceSettings = event['recurrence'] != null ? Map<String, dynamic>.from(event['recurrence']) : null;
                                  _editingSelectedWeekDays = List.filled(7, false);
                                  if (_editingRecurrenceSettings != null && _editingRecurrenceSettings!['weekDays'] is List) {
                                    (_editingRecurrenceSettings!['weekDays'] as List).cast<int>().forEach((dayIndex) {
                                      if (dayIndex >= 0 && dayIndex < 7) {
                                        _editingSelectedWeekDays[dayIndex] = true;
                                      }
                                    });
                                  }
                                  final endDateStr = _editingRecurrenceSettings?['end_date'] as String?;
                                  _editingRecurrenceEndDate = endDateStr != null ? DateTime.tryParse(endDateStr) : null;

                                  print('Editing mode recurrence loaded: $_editingRecurrenceSettings');
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: event['color'] as Color,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text('${event['text']} (${DateFormat('HH:mm').format(event['startDate'])} - ${DateFormat('HH:mm').format(event['endDate'])})', style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis)),
                                    IconButton(
                                      icon: const Icon(Icons.delete, size: 18, color: Colors.grey),
                                      onPressed: () async {
                                        Navigator.pop(context);
                                        await _deleteEvent(eventId);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 16),
                    ],

                    Text(_isEditing ? '일정 수정' : '새 일정 입력', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: currentEventController,
                      decoration: const InputDecoration(
                        hintText: '일정 제목',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('색상:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: colorOptions.map((color) {
                        return GestureDetector(
                          onTap: () {
                            modalSetState(() {
                              if (_isEditing) {
                                _editingSelectedColor = color;
                              } else {
                                _selectedColor = color;
                              }
                            });
                          },
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: currentColor == color
                                  ? Border.all(color: Colors.blue, width: 2) : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        _showDateTimePickerWithSetter(
                          modalSetState: modalSetState,
                          currentStartDateTime: currentStartDateTime,
                          currentEndDateTime: currentEndDateTime,
                          onStartDateTimeChanged: (newDateTime) {
                            modalSetState(() {
                              if (_isEditing) {
                                _editingStartDateTime = newDateTime;
                              } else {
                                _startDateTime = newDateTime;
                              }
                            });
                          },
                          onEndDateTimeChanged: (newDateTime) {
                            modalSetState(() {
                              if (_isEditing) {
                                _editingEndDateTime = newDateTime;
                              } else {
                                _endDateTime = newDateTime;
                              }
                            });
                          },
                        );
                      },
                      child: Text(
                        '시간 설정: ${DateFormat('M월 d일 HH:mm', 'ko_KR').format(currentStartDateTime ?? date)} - ${DateFormat('M월 d일 HH:mm', 'ko_KR').format(currentEndDateTime ?? date)}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        if (_isEditing) {
                          _editingRecurrenceSettings = _editingRecurrenceSettings != null ? Map<String, dynamic>.from(_editingRecurrenceSettings!) : null;
                          _editingSelectedWeekDays = List.filled(7, false);
                          if (_editingRecurrenceSettings != null && _editingRecurrenceSettings!['weekDays'] is List) {
                            (_editingRecurrenceSettings!['weekDays'] as List).cast<int>().forEach((dayIndex) {
                              if (dayIndex >= 0 && dayIndex < 7) {
                                _editingSelectedWeekDays[dayIndex] = true;
                              }
                            });
                          }
                          final endDateStr = _editingRecurrenceSettings?['end_date'] as String?;
                          _editingRecurrenceEndDate = endDateStr != null ? DateTime.tryParse(endDateStr) : null;

                        } else {
                          _recurrenceSettings = null;
                          _selectedWeekDays = List.filled(7, false);
                          _recurrenceEndDate = null;
                        }

                        _showRecurrenceDialog(context, modalSetState);
                      },
                      child: const Text('반복 설정'),
                    ),
                    const SizedBox(height: 16),

                    const Text('가계부 입력', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('수입'),
                            value: 'income',
                            groupValue: _transactionType,
                            onChanged: (value) {
                              modalSetState(() {
                                _transactionType = value!;
                              });
                            },
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('지출'),
                            value: 'expense',
                            groupValue: _transactionType,
                            onChanged: (value) {
                              modalSetState(() {
                                _transactionType = value!;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                     TextField(
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: '금액 입력 (숫자만)',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onChanged: (value) {
                        _transactionAmount = int.tryParse(value);
                      },
                    ),
                    const SizedBox(height: 8),
                     TextField(
                      decoration: const InputDecoration(
                        hintText: '상세 내용 (선택 사항)',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onChanged: (value) {
                        _transactionNote = value;
                      },
                    ),

                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            _newEventController.dispose();
                            _editingEventController.dispose();
                            _isEditing = false;
                            Navigator.pop(context);
                          },
                          child: const Text('취소'),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            print('=== Save/Update Button Pressed ===');
                            final saveUpdateEventId = _isEditing ? _editingEventId : null;
                            final saveUpdateText = _isEditing ? _editingEventController.text.trim() : _newEventController.text.trim();
                            final saveUpdateStartDateTime = _isEditing ? _editingStartDateTime : _startDateTime;
                            final saveUpdateEndDateTime = _isEditing ? _editingEndDateTime : _endDateTime;
                            final saveUpdateColor = _isEditing ? (_editingSelectedColor ?? colorOptions[0]) : _selectedColor;
                            final saveUpdateRecurrenceSettings = _isEditing ? _editingRecurrenceSettings : _recurrenceSettings;

                            final saveUpdateTransactionAmount = _transactionAmount;
                            final saveUpdateTransactionType = _transactionType;
                            final saveUpdateTransactionNote = _transactionNote.trim();

                            print('Mode: ${_isEditing ? 'Editing' : 'New'}');
                            print('Event ID: $saveUpdateEventId');
                            print('Event Text: $saveUpdateText');
                            print('Start DateTime: $saveUpdateStartDateTime');
                            print('End DateTime: $saveUpdateEndDateTime');
                            print('Selected Color: $saveUpdateColor');
                            print('Recurrence Settings: $saveUpdateRecurrenceSettings');
                            print('Transaction Amount: $saveUpdateTransactionAmount');
                            print('Transaction Type: $saveUpdateTransactionType');
                            print('Transaction Note: $saveUpdateTransactionNote');

                            bool eventIsValid = saveUpdateText.isNotEmpty && saveUpdateStartDateTime != null && saveUpdateEndDateTime != null;
                            bool transactionIsValid = saveUpdateTransactionAmount != null && saveUpdateTransactionAmount > 0;

                            if (eventIsValid || transactionIsValid) {
                              print('Proceeding with save/update...');

                              String? transactionId;

                              if (transactionIsValid) {
                                try {
                                  final transactionService = TransactionService();
                                  final transactionDate = saveUpdateStartDateTime ?? date;
                                  final transactionType = saveUpdateTransactionType == 'income' ? TransactionType.income : TransactionType.expense;

                                  if (_isEditing && eventDetails.containsKey(saveUpdateEventId!) && eventDetails[saveUpdateEventId!]!['transactionId'] != null) {
                                     transactionId = eventDetails[saveUpdateEventId!]!['transactionId'];
                                     final existingTransaction = (await transactionService.getTransactions()).firstWhere((t) => t.id == transactionId);
                                     final updatedTransaction = Transaction(
                                        id: transactionId,
                                        title: saveUpdateText.isNotEmpty ? saveUpdateText : existingTransaction.title,
                                        amount: saveUpdateTransactionAmount!,
                                        date: transactionDate,
                                        type: transactionType,
                                        category: existingTransaction.category,
                                        note: saveUpdateTransactionNote.isNotEmpty ? saveUpdateTransactionNote : existingTransaction.note,
                                     );
                                     await transactionService.updateTransaction(updatedTransaction);
                                     print('Transaction updated with ID: $transactionId');

                                  } else {
                                     final newTransaction = Transaction(
                                        title: saveUpdateText.isNotEmpty ? saveUpdateText : '거래 ${DateFormat('yyyy-MM-dd').format(transactionDate)}',
                                        amount: saveUpdateTransactionAmount!,
                                        date: transactionDate,
                                        type: transactionType,
                                        category: transactionType == TransactionType.income ? TransactionCategory.other_income : TransactionCategory.other_expense,
                                        note: saveUpdateTransactionNote,
                                     );
                                     await transactionService.addTransaction(newTransaction);
                                     transactionId = newTransaction.id;
                                     print('New transaction saved with ID: $transactionId');
                                  }

                                } catch (e) {
                                  print('Error saving/updating transaction: $e');
                                }
                              }

                              if (eventIsValid) {
                                if (_isEditing && saveUpdateEventId != null) {
                                  await _updateEvent(
                                    saveUpdateEventId,
                                    saveUpdateText,
                                    saveUpdateStartDateTime!,
                                    saveUpdateEndDateTime!,
                                    saveUpdateColor,
                                    saveUpdateRecurrenceSettings,
                                  );
                                  if (transactionId != null) {
                                     eventDetails[saveUpdateEventId]!['transactionId'] = transactionId;
                                     print('Linked transaction ID $transactionId to event $saveUpdateEventId');
                                  }
                                  print('Event updated...');

                                } else {
                                   await _saveEvent(
                                    saveUpdateText,
                                    saveUpdateStartDateTime!,
                                    saveUpdateEndDateTime!,
                                    saveUpdateColor,
                                  );
                                   print('New event saved...');
                                }
                                print('Event save/update process finished.');
                              }

                              _newEventController.dispose();
                              _editingEventController.dispose();
                               _isEditing = false;
                              Navigator.pop(context);
                            } else {
                              print('Validation failed:');
                              print('Event valid: $eventIsValid');
                              print('Transaction valid: $transactionIsValid');
                            }
                          },
                          child: Text(_isEditing ? '수정' : '저장'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Map<String, int> _calculateEventPositions(DateTime month) {
    Map<String, int> positions = {};
    Map<DateTime, List<String>> sortedEvents = {};
    
    for (int day = 1; day <= getDaysInMonth(month.year, month.month); day++) {
      final date = DateTime(month.year, month.month, day);
      if (events[date] != null && events[date]!.isNotEmpty) {
        sortedEvents[date] = events[date]!;
      }
    }

    List<MapEntry<String, Map<String, dynamic>>> allEvents = [];
    sortedEvents.forEach((date, eventIds) {
      eventIds.forEach((eventId) {
        if (eventDetails[eventId] != null) {
          allEvents.add(MapEntry(eventId, eventDetails[eventId]!));
        }
      });
    });

    allEvents.sort((a, b) {
      DateTime aStart = a.value['startDate'];
      DateTime bStart = b.value['startDate'];
      if (aStart == bStart) {
        int aTime = int.parse(a.key.split('_').last);
        int bTime = int.parse(b.key.split('_').last);
        return aTime.compareTo(bTime);
      }
      return aStart.compareTo(bStart);
    });

    for (var event in allEvents) {
      String eventId = event.key;
      if (!positions.containsKey(eventId)) {
        DateTime startDate = event.value['startDate'];
        DateTime endDate = event.value['endDate'];
        
        Set<int> unavailablePositions = {};
        for (DateTime date = startDate; !date.isAfter(endDate); date = date.add(Duration(days: 1))) {
          final dayEvents = events[DateTime(date.year, date.month, date.day)] ?? [];
          for (String id in dayEvents) {
            if (positions.containsKey(id)) {
              unavailablePositions.add(positions[id]!);
            }
          }
        }

        int position = 0;
        while (unavailablePositions.contains(position)) {
          position++;
        }
        
        positions[eventId] = position;
      }
    }

    return positions;
  }

  Future<void> _loadWeather() async {
    try {
      print('Fetching weather data...');
      final weatherData = await _weatherService.getCurrentWeather();
      if (weatherData != null) {
        setState(() {
          _currentWeather = weatherData;
          _weatherIconUrl = _weatherService.getWeatherIconUrl(weatherData['iconCode']);
          print('Weather data fetched and state updated.');
          print('Temperature: ${_currentWeather!['temperature']}, Description: ${_currentWeather!['description']}');
        });
      } else {
        print('Failed to fetch weather data.');
      }
    } catch (e) {
      print('Error loading weather: $e');
    }
  }

  Future<void> _loadForecastWeather() async {
    print('flutter: _loadForecastWeather called.');
    try {
      final WeatherService weatherService = WeatherService();
      final forecastData = await weatherService.getForecastWeather();
      print('flutter: Forecast data fetched: ${forecastData != null}');

      if (forecastData != null) {
        _forecastWeather = forecastData;
        print('Forecast weather data fetched.');
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetailedWeatherScreen(forecastData: _forecastWeather!),
          ),
        );
      } else {
        print('flutter: Failed to load forecast data: forecastData is null');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load detailed weather data.'),
          ),
        );
      }
    } catch (e) {
      print('flutter: Error loading forecast weather: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading detailed weather data: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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

                bool hasRecurringEvent = cellEvents.any((eventId) {
                   final event = eventDetails[eventId];
                   return event != null && event['recurrence'] != null;
                });

                return GestureDetector(
                  onTap: () => _openScheduleInputPage(cellDate),
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
                                color: isHoliday ? Colors.red : (hasRecurringEvent ? Colors.purple : (isToday ? Colors.blue : Colors.black)),
                              ),
                            ),
                          ),
                        ),
                        if (holidayName != null)
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
    CalendarView(), // Your existing calendar view
    const TransactionScreen(), // Use the actual TransactionScreen, added const
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
      body: _screens[_selectedIndex], // Display the selected screen
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