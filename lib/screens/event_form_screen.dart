import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_app/models/event.dart';
import 'package:my_app/services/event_service.dart';

class EventFormScreen extends StatefulWidget {
  final DateTime selectedDate;
  final Event? event;

  const EventFormScreen({
    super.key,
    required this.selectedDate,
    this.event,
  });

  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late DateTime _startDate;
  late DateTime _endDate;
  late EventCategory _selectedCategory;
  late EventRepeatType _selectedRepeatType;
  late DateTime? _recurrenceEndDate;
  late List<bool> _selectedWeekDays;
  late bool _hasNotification;

  final EventService _eventService = EventService();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.event?.title);
    _descriptionController = TextEditingController(text: widget.event?.description);
    _startDate = widget.event?.startDate ?? DateTime(widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day, 9, 0);
    _endDate = widget.event?.endDate ?? DateTime(widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day, 10, 0);
    _selectedCategory = widget.event?.category ?? EventCategory.etc;
    _selectedRepeatType = widget.event?.repeatType ?? EventRepeatType.none;
    _recurrenceEndDate = widget.event?.recurrenceEndDate;
    _selectedWeekDays = List.from(widget.event?.recurrenceWeekDays?.map((e) => true) ?? List.filled(7, false));
    _hasNotification = widget.event?.hasNotification ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime(BuildContext context, bool isStart) async {
    final date = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(isStart ? _startDate : _endDate),
    );
    if (time == null) return;

    setState(() {
      if (isStart) {
        _startDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
        if (_startDate.isAfter(_endDate)) {
          _endDate = _startDate.add(const Duration(hours: 1));
        }
      } else {
        _endDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
        if (_endDate.isBefore(_startDate)) {
          _startDate = _endDate.subtract(const Duration(hours: 1));
        }
      }
    });
  }

  void _saveEvent() async {
    if (_formKey.currentState!.validate()) {
      final newEvent = Event(
        id: widget.event?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text,
        description: _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
        startDate: _startDate,
        endDate: _endDate,
        category: _selectedCategory,
        repeatType: _selectedRepeatType,
        recurrenceEndDate: _recurrenceEndDate,
        recurrenceWeekDays: _selectedRepeatType == EventRepeatType.weekly && _selectedWeekDays.any((element) => element)
            ? List.generate(7, (index) => _selectedWeekDays[index] ? index : -1).where((element) => element != -1).toList()
            : null,
        hasNotification: _hasNotification,
      );

      if (widget.event == null) {
        await _eventService.saveEvent(newEvent);
      } else {
        await _eventService.updateEvent(newEvent);
      }
      if (mounted) {
        Navigator.of(context).pop(true); // Indicate success
      }
    }
  }

  void _deleteEvent() async {
    if (widget.event != null) {
      await _eventService.deleteEvent(widget.event!.id);
      if (mounted) {
        Navigator.of(context).pop(true); // Indicate success
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.event == null ? '일정 추가' : '일정 수정'),
        actions: [
          if (widget.event != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('일정 삭제'),
                    content: const Text('이 일정을 삭제하시겠습니까?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('취소'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('삭제', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  _deleteEvent();
                }
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: '제목',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '제목을 입력해주세요';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: '설명 (선택 사항)',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16.0),
              ListTile(
                leading: const Icon(Icons.event),
                title: const Text('시작 날짜 및 시간'),
                subtitle: Text(DateFormat('yyyy년 MM월 dd일 HH:mm').format(_startDate)),
                onTap: () => _pickDateTime(context, true),
              ),
              ListTile(
                leading: const Icon(Icons.event_note),
                title: const Text('종료 날짜 및 시간'),
                subtitle: Text(DateFormat('yyyy년 MM월 dd일 HH:mm').format(_endDate)),
                onTap: () => _pickDateTime(context, false),
              ),
              const SizedBox(height: 16.0),
              DropdownButtonFormField<EventCategory>(
                decoration: const InputDecoration(
                  labelText: '카테고리',
                  border: OutlineInputBorder(),
                ),
                value: _selectedCategory,
                onChanged: (EventCategory? newValue) {
                  setState(() {
                    _selectedCategory = newValue!;
                  });
                },
                items: EventCategory.values.map((category) {
                  return DropdownMenuItem<EventCategory>(
                    value: category,
                    child: Row(
                      children: [
                        Icon(Icons.circle, color: category.color, size: 16),
                        const SizedBox(width: 8),
                        Text(category.label),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16.0),
              DropdownButtonFormField<EventRepeatType>(
                decoration: const InputDecoration(
                  labelText: '반복',
                  border: OutlineInputBorder(),
                ),
                value: _selectedRepeatType,
                onChanged: (EventRepeatType? newValue) {
                  setState(() {
                    _selectedRepeatType = newValue!;
                    if (_selectedRepeatType == EventRepeatType.none) {
                      _recurrenceEndDate = null;
                      _selectedWeekDays = List.filled(7, false);
                    }
                  });
                },
                items: EventRepeatType.values.map((type) {
                  return DropdownMenuItem<EventRepeatType>(
                    value: type,
                    child: Text(type.label),
                  );
                }).toList(),
              ),
              if (_selectedRepeatType != EventRepeatType.none) ...[
                const SizedBox(height: 16.0),
                ListTile(
                  leading: const Icon(Icons.date_range),
                  title: const Text('반복 종료 날짜 (선택 사항)'),
                  subtitle: Text(
                    _recurrenceEndDate == null
                        ? '설정 안됨'
                        : DateFormat('yyyy년 MM월 dd일').format(_recurrenceEndDate!),
                  ),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _recurrenceEndDate ?? DateTime.now(),
                      firstDate: _startDate.add(const Duration(days: 1)),
                      lastDate: DateTime(2100),
                    );
                    if (date != null) {
                      setState(() {
                        _recurrenceEndDate = date;
                      });
                    }
                  },
                ),
              ],
              if (_selectedRepeatType == EventRepeatType.weekly) ...[
                const SizedBox(height: 16.0),
                const Text('반복 요일 선택', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Wrap(
                  spacing: 8.0,
                  children: List.generate(7, (index) {
                    final String weekdayName;
                    switch (index) {
                      case 0: weekdayName = '월'; break;
                      case 1: weekdayName = '화'; break;
                      case 2: weekdayName = '수'; break;
                      case 3: weekdayName = '목'; break;
                      case 4: weekdayName = '금'; break;
                      case 5: weekdayName = '토'; break;
                      case 6: weekdayName = '일'; break;
                      default: weekdayName = '';
                    }
                    return FilterChip(
                      label: Text(weekdayName),
                      selected: _selectedWeekDays[index],
                      onSelected: (selected) {
                        setState(() {
                          _selectedWeekDays[index] = selected;
                        });
                      },
                    );
                  }),
                ),
              ],
              const SizedBox(height: 16.0),
              Row(
                children: [
                  Checkbox(
                    value: _hasNotification,
                    onChanged: (bool? newValue) {
                      setState(() {
                        _hasNotification = newValue ?? false;
                      });
                    },
                  ),
                  const Text('알림 설정'),
                ],
              ),
              const SizedBox(height: 24.0),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveEvent,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                  child: Text(widget.event == null ? '일정 추가' : '일정 저장'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 