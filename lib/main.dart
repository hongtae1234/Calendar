import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'database_helper.dart';
import 'holiday_helper.dart';

void main() {
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: CalendarApp(),
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

class CalendarApp extends StatefulWidget {
  @override
  _CalendarAppState createState() => _CalendarAppState();
}

class _CalendarAppState extends State<CalendarApp> {
  final DatabaseHelper dbHelper = DatabaseHelper.instance;
  DateTime currentMonth = DateTime.now();
  DateTime selectedDate = DateTime.now();
  Map<DateTime, List<String>> events = {};
  Map<String, Map<String, dynamic>> eventDetails = {};
  Color selectedColor = Colors.blue.withOpacity(0.2);
  late TextEditingController _eventController;

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

  @override
  void initState() {
    super.initState();
    _eventController = TextEditingController();
    _initializeApp();
  }

  @override
  void dispose() {
    _eventController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    await _loadEvents();
  }

  Future<void> _loadEvents() async {
    try {
      final loadedEvents = await dbHelper.loadEvents();
      if (loadedEvents.isEmpty) {
        setState(() {
          events = {};
          eventDetails = {};
        });
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
            final type = recurrence['type'] as String;
            final endDateStr = recurrence['end_date'] as String?;
            final recurrenceEndDate = endDateStr != null ? DateTime.parse(endDateStr) : null;
            
            DateTime iterDate = DateTime(startDate.year, startDate.month, startDate.day);
            final duration = endDate.difference(startDate);

            while (recurrenceEndDate == null || !iterDate.isAfter(recurrenceEndDate)) {
              if (type == 'daily') {
                _addEventToDate(newEvents, eventId, iterDate);
                iterDate = iterDate.add(Duration(days: 1));
              } else if (type == 'weekly') {
                final weekDays = (recurrence['weekDays'] as List<dynamic>?)?.cast<int>();
                if (weekDays != null && weekDays.contains(iterDate.weekday)) {
                  _addEventToDate(newEvents, eventId, iterDate);
                }
                iterDate = iterDate.add(Duration(days: 1));
              } else if (type == 'monthly') {
                _addEventToDate(newEvents, eventId, iterDate);
                iterDate = DateTime(iterDate.year, iterDate.month + 1, iterDate.day);
              } else if (type == 'yearly') {
                _addEventToDate(newEvents, eventId, iterDate);
                iterDate = DateTime(iterDate.year + 1, iterDate.month, iterDate.day);
              }

              // 너무 많은 반복을 방지하기 위한 안전장치
              if (iterDate.isAfter(DateTime.now().add(Duration(days: 365 * 5)))) {
                break;
              }
            }
          } else {
            // 반복이 아닌 일반 일정 처리
            DateTime iterDate = DateTime(startDate.year, startDate.month, startDate.day);
            final endDateOnly = DateTime(endDate.year, endDate.month, endDate.day);

            while (!iterDate.isAfter(endDateOnly)) {
              _addEventToDate(newEvents, eventId, iterDate);
              iterDate = iterDate.add(Duration(days: 1));
            }
          }
        } catch (e) {
          print('Error processing event: $e');
          print('Event data: $event');
        }
      }

      setState(() {
        events = newEvents;
        eventDetails = newEventDetails;
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
    }
  }

  Future<void> _saveEvent(String text, DateTime startDate, DateTime endDate, Color color) async {
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
      await dbHelper.saveEvent(eventData);
      await _loadEvents();
    } catch (e) {
      print('Error saving event: $e');
      print('Event data: $eventData');
    }
  }

  Future<void> _updateEvent(String eventId, String text, DateTime startDate, DateTime endDate, Color color) async {
    final eventData = {
      'id': eventId,
      'title': text,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'color': color.value,
    };

    try {
      await dbHelper.saveEvent(eventData);
      await _loadEvents();
    } catch (e) {
      print('Error updating event: $e');
    }
  }

  Future<void> _deleteEvent(String eventId) async {
    try {
      await dbHelper.deleteEvent(eventId);
      await _loadEvents();
    } catch (e) {
      print('Error deleting event: $e');
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
    DateTime _tempStartDateTime = currentStartDateTime ?? DateTime.now(); // Change to non-nullable DateTime
    DateTime _tempEndDateTime = currentEndDateTime ?? DateTime.now();     // Change to non-nullable DateTime

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return SizedBox(
              height: 350, // Increase height slightly to accommodate expanded options
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
                            // Use the non-nullable variable directly
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
                            // Use the non-nullable variable directly
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
                      initialDateTime: _selectingStart ? _tempStartDateTime : _tempEndDateTime, // Now non-nullable
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
                          print('Time picker modal: Confirm pressed.'); // Debug print
                          print('Time picker modal: _tempStartDateTime = ${_tempStartDateTime}'); // Debug print
                          print('Time picker modal: _tempEndDateTime = ${_tempEndDateTime}'); // Debug print

                          // Pass the non-nullable values
                          onStartDateTimeChanged(_tempStartDateTime);
                          onEndDateTimeChanged(_tempEndDateTime);

                          modalSetState(() {}); // Update the main modal UI
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
                                  _recurrenceSettings!['weekDays'] = 
                                    List.generate(7, (i) => _selectedWeekDays[i] ? i + 1 : null)
                                        .where((day) => day != null)
                                        .toList();
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
    DateTime? _startDateTime = date;
    DateTime? _endDateTime = date;
    final TextEditingController _newEventController = TextEditingController();
    Color _selectedColor = colorOptions[0];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows the modal to take up more height
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter modalSetState) {
            print('Event input modal: Building/Rebuilding.'); // Debug print
            print('Event input modal: _startDateTime = ${_startDateTime}'); // Debug print
            print('Event input modal: _endDateTime = ${_endDateTime}'); // Debug print

            // Get events for the selected date
            final List<String> eventsOnSelectedDate = events[date] ?? [];

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
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 16),
                    Text('현재 일정:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    // Display existing events
                    if (eventsOnSelectedDate.isEmpty)
                      Text('해당 날짜에 일정이 없습니다.')
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: eventsOnSelectedDate.map((eventId) {
                          final event = eventDetails[eventId];
                          if (event == null) return Container();
                          return Padding(
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
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${event['text']} (${DateFormat('HH:mm').format(event['startDate'])} - ${DateFormat('HH:mm').format(event['endDate'])})',
                                    style: TextStyle(fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete, size: 18, color: Colors.grey),
                                  onPressed: () async {
                                    // TODO: Implement delete confirmation
                                    Navigator.pop(context); // Close modal
                                    await _deleteEvent(eventId);
                                  },
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    SizedBox(height: 16),
                    Text('새 일정 입력', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    TextField(
                      controller: _newEventController,
                      decoration: InputDecoration(
                        hintText: '새 일정 입력',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text('색상:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: colorOptions.map((color) {
                        return GestureDetector(
                          onTap: () {
                            modalSetState(() {
                              _selectedColor = color;
                            });
                          },
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: _selectedColor == color
                                  ? Border.all(color: Colors.blue, width: 2)
                                  : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 16),
                    // TODO: Add date and time picker
                    TextButton(
                      onPressed: () {
                        _showDateTimePickerWithSetter(
                          modalSetState: modalSetState,
                          currentStartDateTime: _startDateTime,
                          currentEndDateTime: _endDateTime,
                          onStartDateTimeChanged: (newDateTime) {
                            _startDateTime = newDateTime;
                          },
                          onEndDateTimeChanged: (newDateTime) {
                            _endDateTime = newDateTime;
                          },
                        );
                      },
                      child: Text(
                        '시간 설정: ${DateFormat('M월 d일 HH:mm', 'ko_KR').format(_startDateTime ?? date)} - ${DateFormat('M월 d일 HH:mm', 'ko_KR').format(_endDateTime ?? date)}',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            _newEventController.dispose();
                            Navigator.pop(context);
                          },
                          child: Text('취소'),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            if (_newEventController.text.trim().isNotEmpty && _startDateTime != null && _endDateTime != null) {
                              await _saveEvent(
                                _newEventController.text.trim(),
                                _startDateTime!,
                                _endDateTime!,
                                _selectedColor,
                              );
                              _newEventController.dispose();
                              Navigator.pop(context);
                            }
                          },
                          child: Text('저장'),
                        ),
                      ],
                    ),
                    SizedBox(height: 16), // Add some bottom padding
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 이벤트의 수직 위치를 계산하는 메서드
  Map<String, int> _calculateEventPositions(DateTime month) {
    Map<String, int> positions = {};
    Map<DateTime, List<String>> sortedEvents = {};
    
    // 해당 월의 모든 날짜에 대한 이벤트를 수집
    for (int day = 1; day <= getDaysInMonth(month.year, month.month); day++) {
      final date = DateTime(month.year, month.month, day);
      if (events[date] != null && events[date]!.isNotEmpty) {
        sortedEvents[date] = events[date]!;
      }
    }

    // 모든 이벤트를 시작 날짜 기준으로 정렬
    List<MapEntry<String, Map<String, dynamic>>> allEvents = [];
    sortedEvents.forEach((date, eventIds) {
      eventIds.forEach((eventId) {
        if (eventDetails[eventId] != null) {
          allEvents.add(MapEntry(eventId, eventDetails[eventId]!));
        }
      });
    });

    // 시작 날짜를 기준으로 정렬
    allEvents.sort((a, b) {
      DateTime aStart = a.value['startDate'];
      DateTime bStart = b.value['startDate'];
      if (aStart == bStart) {
        // 시작 날짜가 같으면 생성 시간으로 정렬
        int aTime = int.parse(a.key.split('_').last);
        int bTime = int.parse(b.key.split('_').last);
        return aTime.compareTo(bTime);
      }
      return aStart.compareTo(bStart);
    });

    // 위치 할당
    for (var event in allEvents) {
      String eventId = event.key;
      if (!positions.containsKey(eventId)) {
        DateTime startDate = event.value['startDate'];
        DateTime endDate = event.value['endDate'];
        
        // 이벤트 기간 동안 사용된 위치 확인
        Set<int> unavailablePositions = {};
        for (DateTime date = startDate; !date.isAfter(endDate); date = date.add(Duration(days: 1))) {
          final dayEvents = events[DateTime(date.year, date.month, date.day)] ?? [];
          for (String id in dayEvents) {
            if (positions.containsKey(id)) {
              unavailablePositions.add(positions[id]!);
            }
          }
        }

        // 사용 가능한 가장 낮은 위치 찾기
        int position = 0;
        while (unavailablePositions.contains(position)) {
          position++;
        }
        
        positions[eventId] = position;
      }
    }

    return positions;
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
                bool isHoliday = HolidayHelper.isHoliday(cellDate);
                String? holidayName = HolidayHelper.getHolidayName(cellDate);

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
                                color: isHoliday ? Colors.red : (isToday ? Colors.blue : Colors.black),
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
                                    if (event == null) return Container();

                                    final startDate = event['startDate'] as DateTime;
                                    final endDate = event['endDate'] as DateTime;
                                    final text = event['text'] as String;
                                    final color = event['color'] as Color;
                                    final position = eventPositions[eventId] ?? 0;

                                    bool isStartDay = isSameDate(cellDate, startDate);
                                    bool isEndDay = isSameDate(cellDate, endDate);

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
                                            left: Radius.circular(isStartDay ? 4 : 0),
                                            right: Radius.circular(isEndDay ? 4 : 0),
                                          ),
                                        ),
                                        child: isStartDay
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


