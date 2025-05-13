import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

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
  DateTime currentMonth = DateTime.now();
  DateTime selectedDate = DateTime.now();
  Map<DateTime, List<String>> events = {};
  Map<DateTime, List<Map<String, dynamic>>> eventTimes = {};

  TextEditingController _eventController = TextEditingController();
  DateTime? _startDateTime;
  DateTime? _endDateTime;
  bool _selectingStart = true;

  List<String> daysInWeek = ['일', '월', '화', '수', '목', '금', '토'];

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

  void _showDateTimePickerWithSetter(void Function(void Function()) externalSetState) {
    DateTime initialDate = DateTime.now();
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, modalSetState) {
            return SizedBox(
              height: 300,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => modalSetState(() => _selectingStart = true),
                          child: Text(
                            '시작: ${_startDateTime != null ? DateFormat('M월 d일 E HH:mm', 'ko_KR').format(_startDateTime!) : '-'}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _selectingStart ? Colors.blue : Colors.black,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => modalSetState(() => _selectingStart = false),
                          child: Text(
                            '종료: ${_endDateTime != null ? DateFormat('M월 d일 E HH:mm', 'ko_KR').format(_endDateTime!) : '-'}',
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
                      initialDateTime: initialDate,
                      onDateTimeChanged: (DateTime newDateTime) {
                        modalSetState(() {
                          if (_selectingStart) {
                            _startDateTime = newDateTime;
                          } else {
                            _endDateTime = newDateTime;
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
                          externalSetState(() {});
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

  void _showEventDialog(DateTime date) {
    _eventController.text = '';
    _startDateTime = null;
    _endDateTime = null;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Center(
              child: AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                contentPadding: const EdgeInsets.all(20),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(DateFormat('yyyy년 M월 d일', 'ko_KR').format(date), style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 10),
                    TextField(
                      controller: _eventController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(hintText: '새 일정 입력'),
                    ),
                    SizedBox(height: 12),
                    TextButton(
                      onPressed: () => _showDateTimePickerWithSetter(setState),
                      child: Text("시간 설정"),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('취소'),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              if (events.containsKey(date)) {
                                events.remove(date);
                                eventTimes.remove(date);
                              }
                            });
                            Navigator.pop(context);
                          },
                          child: Text('삭제', style: TextStyle(color: Colors.redAccent)),
                        ),
                        TextButton(
                          onPressed: () {
                            final text = _eventController.text.trim();
                            if (text.isNotEmpty && _startDateTime != null && _endDateTime != null) {
                              DateTime iterDate = DateTime(_startDateTime!.year, _startDateTime!.month, _startDateTime!.day);
                              DateTime endDateOnly = DateTime(_endDateTime!.year, _endDateTime!.month, _endDateTime!.day);

                              while (!iterDate.isAfter(endDateOnly)) {
                                events.putIfAbsent(iterDate, () => []);
                                if (isSameDate(iterDate, _startDateTime!)) {
                                  if (!events[iterDate]!.contains(text)) {
                                    events[iterDate]!.add(text);
                                  }
                                }

                                eventTimes.putIfAbsent(iterDate, () => []);
                                eventTimes[iterDate]!.add({
                                  'start': isSameDate(iterDate, _startDateTime!) ? _startDateTime : null,
                                  'end': isSameDate(iterDate, endDateOnly) ? _endDateTime : null,
                                });

                                iterDate = iterDate.add(Duration(days: 1));
                              }

                              Navigator.pop(context);
                              setState(() {});
                            }
                          },
                          child: Text('확인'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ))
                .toList(),
          ),
          Expanded(
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
              itemCount: getDaysInMonth(currentMonth.year, currentMonth.month) + getStartDay(currentMonth.year, currentMonth.month),
              itemBuilder: (context, index) {
                int startDay = getStartDay(currentMonth.year, currentMonth.month);
                int totalDays = getDaysInMonth(currentMonth.year, currentMonth.month);

                if (index < startDay) return Container();
                int day = index - startDay + 1;
                DateTime cellDate = DateTime(currentMonth.year, currentMonth.month, day);
                bool isToday = isSameDate(cellDate, DateTime.now());
                final cellEvents = events[cellDate] ?? [];

                return GestureDetector(
                  onTap: () => _showEventDialog(cellDate),
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$day',
                          style: TextStyle(
                            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                            color: isToday ? Colors.white : Colors.black,
                            backgroundColor: isToday ? Colors.blue : Colors.transparent,
                          ),
                        ),
                        if (cellEvents.isNotEmpty)
                          Container(
                            margin: EdgeInsets.only(top: 2),
                            padding: EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.lightBlue.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              cellEvents.first,
                              style: TextStyle(fontSize: 10, color: Colors.black),
                              overflow: TextOverflow.ellipsis,
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
