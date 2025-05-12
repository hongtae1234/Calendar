import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/cupertino.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR', null);

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
  Map<DateTime, List<TimeOfDay>> eventTimes = {};

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

  void _showCentralEventDialog(DateTime date) {
    TextEditingController controller = TextEditingController();
    TimeOfDay? selectedTime;

    showDialog(
      context: context,
      builder: (context) {
        return Center(
          child: SingleChildScrollView(
            child: AlertDialog(
              title: Text(DateFormat('yyyy년 M월 d일', 'ko_KR').format(date)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...events[date]?.asMap().entries.map((entry) {
                    final index = entry.key;
                    final event = entry.value;
                    final time = eventTimes[date]?[index];
                    return ListTile(
                      title: Text('${time?.format(context) ?? ''} $event'),
                      trailing: IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            events[date]!.removeAt(index);
                            eventTimes[date]?.removeAt(index);
                            if (events[date]!.isEmpty) events.remove(date);
                          });
                          Navigator.pop(context);
                          _showCentralEventDialog(date);
                        },
                      ),
                    );
                  }) ?? [Text('일정이 없습니다.', style: TextStyle(color: Colors.grey))],
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(hintText: '새 일정 입력'),
                  ),
                  SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {
                      showCupertinoModalPopup(
                        context: context,
                        builder: (BuildContext context) {
                          return Container(
                            height: 250,
                            color: Colors.white,
                            child: CupertinoDatePicker(
                              mode: CupertinoDatePickerMode.time,
                              initialDateTime: DateTime(date.year, date.month, date.day, 12, 0),
                              use24hFormat: true,
                              onDateTimeChanged: (DateTime picked) {
                                selectedTime = TimeOfDay(hour: picked.hour, minute: picked.minute);
                              },
                            ),
                          );
                        },
                      );
                    },
                    child: Text('시간 설정 (iOS 스타일)'),
                  ),
                  SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {
                      String newEvent = controller.text.trim();
                      if (newEvent.isNotEmpty) {
                        setState(() {
                          events.putIfAbsent(date, () => []);
                          eventTimes.putIfAbsent(date, () => []);
                          events[date]!.add(newEvent);
                          eventTimes[date]!.add(selectedTime ?? TimeOfDay.now());
                        });
                      }
                      Navigator.pop(context);
                    },
                    child: Text('일정 추가'),
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEventList() {
    List<String> dayEvents = events[selectedDate] ?? [];
    List<TimeOfDay> times = eventTimes[selectedDate] ?? [];

    if (dayEvents.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text('이날의 일정이 없습니다', style: TextStyle(color: Colors.grey)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(dayEvents.length, (index) => Text('• ${times[index].format(context)} ${dayEvents[index]}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int year = currentMonth.year;
    final int month = currentMonth.month;
    final int daysInMonth = getDaysInMonth(year, month);
    final int startDay = getStartDay(year, month);

    DateTime today = DateTime.now();
    DateTime firstDayThisMonth = DateTime(year, month, 1);
    DateTime firstVisibleDate = firstDayThisMonth.subtract(Duration(days: startDay));

    int totalCells = startDay + daysInMonth;
    int rowCount = (totalCells / 7).ceil();
    int totalVisibleDays = rowCount * 7;

    List<Widget> calendarCells = [];
    for (int i = 0; i < totalVisibleDays; i++) {
      DateTime cellDate = firstVisibleDate.add(Duration(days: i));
      bool isToday = cellDate.year == today.year && cellDate.month == today.month && cellDate.day == today.day;
      bool isCurrentMonth = cellDate.month == month;

      List<String> cellEvents = events[cellDate] ?? [];

      calendarCells.add(
        GestureDetector(
          onTap: () {
            setState(() => selectedDate = cellDate);
            _showCentralEventDialog(cellDate);
          },
          child: Container(
            margin: const EdgeInsets.all(1),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.all(6),
                  decoration: isToday ? BoxDecoration(color: Colors.blue, shape: BoxShape.circle) : null,
                  child: Text(
                    '${cellDate.day}',
                    style: TextStyle(
                      color: isCurrentMonth ? (isToday ? Colors.white : Colors.black87) : Colors.grey,
                      fontWeight: isCurrentMonth ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                if (cellEvents.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                    child: Text(
                      cellEvents.take(5).join('\n'),
                      style: TextStyle(fontSize: 9, color: Colors.red),
                      textAlign: TextAlign.center,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Color(0xFFFAF3DD),
      appBar: AppBar(
        backgroundColor: Color(0xFFFAF3DD),
        elevation: 0,
        title: Text('${year}년 ${month}월', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
        centerTitle: true,
        leading: IconButton(icon: Icon(Icons.chevron_left, color: Colors.black87), onPressed: goToPrevMonth),
        actions: [
          IconButton(icon: Icon(Icons.chevron_right, color: Colors.black87), onPressed: goToNextMonth),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('M월 d일 EEEE', 'ko_KR').format(selectedDate),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 6),
            _buildEventList(),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: daysInWeek.map((day) => Expanded(child: Center(child: Text(day)))).toList(),
            ),
            SizedBox(height: 8),
            Expanded(
              child: GridView.count(
                crossAxisCount: 7,
                children: calendarCells,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
