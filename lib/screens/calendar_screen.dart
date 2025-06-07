import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/event_service.dart';
import '../models/event.dart';
import 'login_screen.dart';
import 'event_form_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime currentDate = DateTime.now();
  final List<String> weekdays = ['일', '월', '화', '수', '목', '금', '토'];
  String? username;
  Map<DateTime, List<Event>> _events = {};

  @override
  void initState() {
    super.initState();
    // username = AuthService.getCurrentUsername(); // Temporarily commented out for web debugging
    // _loadEvents(); // Temporarily commented out for web debugging
  }

  Future<void> _loadEvents() async {
    final eventService = EventService();
    final events = await eventService.getEvents();
    final eventsByDate = <DateTime, List<Event>>{};
    
    // 현재 표시된 달의 모든 날짜에 대해 이벤트를 로드
    final daysInMonth = DateTime(currentDate.year, currentDate.month + 1, 0).day;
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(currentDate.year, currentDate.month, day);
      final eventsForDate = await eventService.getEventsForDate(date);
      if (eventsForDate.isNotEmpty) {
        eventsByDate[date] = eventsForDate;
      }
    }

    setState(() {
      _events = eventsByDate;
    });
  }

  Future<bool> _onWillPop() async {
    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('앱 종료'),
        content: const Text('정말 앱을 종료하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(true);
              SystemNavigator.pop();
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('종료'),
          ),
        ],
      ),
    );
    return shouldPop ?? false;
  }

  void _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃 하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );

    if (shouldLogout == true && mounted) {
      await AuthService.logout();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        ),
      );
    }
  }

  void _previousMonth() {
    setState(() {
      currentDate = DateTime(currentDate.year, currentDate.month - 1);
      _loadEvents();
    });
  }

  void _nextMonth() {
    setState(() {
      currentDate = DateTime(currentDate.year, currentDate.month + 1);
      _loadEvents();
    });
  }

  Future<void> _showEventDetails(DateTime date, Event event) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(event.title),
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () async {
                    Navigator.pop(context);
                    final updated = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EventFormScreen(
                          selectedDate: date,
                          event: event,
                        ),
                      ),
                    );
                    if (updated == true) {
                      _loadEvents();
                    }
                  },
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.circle, color: event.category.color, size: 16),
                      const SizedBox(width: 8),
                      Text(event.category.label),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (event.description != null) ...[
                    Text(event.description!),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    '시작: ${event.startDate.year}년 ${event.startDate.month}월 ${event.startDate.day}일 ${TimeOfDay.fromDateTime(event.startDate).format(context)}',
                  ),
                  Text(
                    '종료: ${event.endDate.year}년 ${event.endDate.month}월 ${event.endDate.day}일 ${TimeOfDay.fromDateTime(event.endDate).format(context)}',
                  ),
                  if (event.repeatType != EventRepeatType.none) ...[
                    const SizedBox(height: 8),
                    Text('반복: ${event.repeatType.label}'),
                  ],
                  if (event.hasNotification) ...[
                    const SizedBox(height: 8),
                    const Row(
                      children: [
                        Icon(Icons.notifications_active, size: 16),
                        SizedBox(width: 8),
                        Text('알림 설정됨'),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      _loadEvents();
    }
  }

  List<Widget> _buildCalendarDays() {
    List<Widget> days = [];
    final daysInMonth = DateTime(currentDate.year, currentDate.month + 1, 0).day;
    final firstDayOfMonth = DateTime(currentDate.year, currentDate.month, 1);
    final firstWeekday = firstDayOfMonth.weekday;

    // 이전 달의 날짜들을 채움
    for (int i = 0; i < firstWeekday % 7; i++) {
      days.add(const SizedBox());
    }

    // 현재 달의 날짜들을 채움
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(currentDate.year, currentDate.month, day);
      final isToday = DateTime.now().year == date.year &&
          DateTime.now().month == date.month &&
          DateTime.now().day == day;
      final events = _events[date] ?? [];

      days.add(
        GestureDetector(
          onTap: () async {
            if (events.isNotEmpty) {
              if (events.length == 1) {
                await _showEventDetails(date, events.first);
              } else {
                await showModalBottomSheet(
                  context: context,
                  builder: (context) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppBar(
                        title: Text('${date.month}월 ${date.day}일 일정'),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: events.length,
                          itemBuilder: (context, index) {
                            final event = events[index];
                            return ListTile(
                              leading: Icon(
                                Icons.circle,
                                color: event.category.color,
                                size: 16,
                              ),
                              title: Text(event.title),
                              subtitle: Text(
                                '${TimeOfDay.fromDateTime(event.startDate).format(context)} - ${TimeOfDay.fromDateTime(event.endDate).format(context)}',
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                _showEventDetails(date, event);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              }
            } else {
              final added = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (context) => EventFormScreen(selectedDate: date),
                ),
              );
              if (added == true) {
                _loadEvents();
              }
            }
          },
          child: Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isToday ? Theme.of(context).primaryColor.withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isToday
                  ? Border.all(color: Theme.of(context).primaryColor, width: 2)
                  : null,
            ),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: Text(
                      day.toString(),
                      style: TextStyle(
                        color: isToday
                            ? Theme.of(context).primaryColor
                            : (date.weekday == DateTime.sunday)
                                ? Colors.red
                                : (date.weekday == DateTime.saturday)
                                    ? Colors.blue
                                    : Colors.black87,
                        fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
                if (events.isNotEmpty)
                  Container(
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: events.first.category.color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return days;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black54),
            onPressed: () => _onWillPop(),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.black54),
                onPressed: _previousMonth,
              ),
              Text(
                '${currentDate.year}년 ${currentDate.month}월',
                style: const TextStyle(fontSize: 20),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.black54),
                onPressed: _nextMonth,
              ),
            ],
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            PopupMenuButton(
              icon: Icon(
                Icons.account_circle,
                color: Theme.of(context).primaryColor,
                size: 28,
              ),
              itemBuilder: (context) => [
                PopupMenuItem(
                  child: Text('${username ?? "사용자"}님 환영합니다'),
                  enabled: false,
                ),
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Colors.red),
                      SizedBox(width: 8),
                      Text('로그아웃', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'logout') {
                  _handleLogout();
                }
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: weekdays
                    .map(
                      (day) => Expanded(
                        child: Center(
                          child: Text(
                            day,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: day == '일'
                                  ? Colors.red[300]
                                  : day == '토'
                                      ? Colors.blue[300]
                                      : Colors.black54,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            Expanded(
              child: GridView.count(
                crossAxisCount: 7,
                children: _buildCalendarDays(),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            final added = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (context) => EventFormScreen(
                  selectedDate: DateTime.now(),
                ),
              ),
            );
            if (added == true) {
              _loadEvents();
            }
          },
          icon: const Icon(Icons.add),
          label: const Text('일정 추가'),
        ),
      ),
    );
  }
} 