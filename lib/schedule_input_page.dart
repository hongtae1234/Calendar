import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'database_helper.dart'; // DatabaseHelper import

// Define a callback type for event actions
typedef EventActionCallback = Future<void> Function(
  String action,
  String? eventId,
  String? text,
  DateTime? startDate,
  DateTime? endDate,
  Color? color,
  Map<String, dynamic>? recurrence,
);

class ScheduleInputModal extends StatefulWidget {
  final DateTime selectedDate;
  final Map<String, Map<String, dynamic>> eventDetails;
  final Map<DateTime, List<String>> events;
  final List<Color> colorOptions;
  final EventActionCallback onEventAction;
  final DatabaseHelper dbHelper;

  // Constructor for new event
  const ScheduleInputModal({
    Key? key,
    required this.selectedDate,
    required this.eventDetails,
    required this.events,
    required this.colorOptions,
    required this.onEventAction,
    required this.dbHelper,
  }) : super(key: key);

  @override
  _ScheduleInputModalState createState() => _ScheduleInputModalState();
}

class _ScheduleInputModalState extends State<ScheduleInputModal> {
  // State variables for new event
  late DateTime _startDateTime;
  late DateTime _endDateTime;
  late TextEditingController _newEventController;
  late Color _selectedColor;
  Map<String, dynamic>? _recurrenceSettings;
  List<bool> _selectedWeekDays = List.filled(7, false);
  DateTime? _recurrenceEndDate;

  // State variables for editing existing event
  bool _isEditing = false;
  String? _editingEventId;
  late TextEditingController _editingEventController;
  DateTime? _editingStartDateTime;
  DateTime? _editingEndDateTime;
  Color? _editingSelectedColor;
  Map<String, dynamic>? _editingRecurrenceSettings;
  List<bool> _editingSelectedWeekDays = List.filled(7, false);
  DateTime? _editingRecurrenceEndDate;

  final List<String> _recurrenceTypes = ['none', 'daily', 'weekly', 'monthly', 'yearly'];
  final List<String> _weekDays = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  void initState() {
    super.initState();
    _startDateTime = widget.selectedDate;
    _endDateTime = widget.selectedDate;
    _newEventController = TextEditingController();
    _selectedColor = widget.colorOptions[0];
    _editingEventController = TextEditingController();

    // Find and populate event details if editing an existing event
    final eventsOnSelectedDate = widget.events[widget.selectedDate] ?? [];
    if (eventsOnSelectedDate.isNotEmpty) {
      final firstEventId = eventsOnSelectedDate.first;
      final eventData = widget.eventDetails[firstEventId];
      if (eventData != null) {
        _isEditing = true;
        _editingEventId = firstEventId;
        _editingEventController.text = eventData['text'] as String;
        _editingStartDateTime = eventData['startDate'] as DateTime;
        _editingEndDateTime = eventData['endDate'] as DateTime;
        _editingSelectedColor = eventData['color'] as Color;
        _editingRecurrenceSettings = eventData['recurrence'] as Map<String, dynamic>?;
        _editingRecurrenceEndDate = _editingRecurrenceSettings?['end_date'] != null
            ? DateTime.tryParse(_editingRecurrenceSettings!['end_date'] as String)
            : null;
        if (_editingRecurrenceSettings?['weekDays'] != null) {
          _editingSelectedWeekDays = List<bool>.generate(7, (index) =>
              (_editingRecurrenceSettings!['weekDays'] as List<dynamic>).contains(index));
        }
      }
    }
  }

  @override
  void dispose() {
    _newEventController.dispose();
    _editingEventController.dispose();
    super.dispose();
  }

  int getDaysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  bool isSameDate(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  // Modify _showDateTimePickerWithSetter to work with local modal state
  void _showDateTimePickerWithSetter({
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
                          onStartDateTimeChanged(_tempStartDateTime);
                          onEndDateTimeChanged(_tempEndDateTime);
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
  void _showRecurrenceDialog(BuildContext context) {
    String selectedType = (_isEditing ? _editingRecurrenceSettings : _recurrenceSettings)?['type'] ?? 'none';
    List<bool> currentSelectedWeekDays = _isEditing ? _editingSelectedWeekDays : _selectedWeekDays;
    DateTime? currentRecurrenceEndDate = _isEditing ? _editingRecurrenceEndDate : _recurrenceEndDate;

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
                          setState(() { // Update main modal state
                            if (_isEditing) {
                              if (value == 'none') {
                                _editingRecurrenceSettings = null;
                              } else {
                                _editingRecurrenceSettings = {
                                  'type': value,
                                  'interval': 1,
                                  'end_date': _editingRecurrenceEndDate?.toIso8601String(),
                                };
                              }
                            } else {
                              if (value == 'none') {
                                _recurrenceSettings = null;
                              } else {
                                _recurrenceSettings = {
                                  'type': value,
                                  'interval': 1,
                                  'end_date': _recurrenceEndDate?.toIso8601String(),
                                };
                              }
                            }
                          });
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
                            selected: currentSelectedWeekDays[index],
                            onSelected: (bool selected) {
                              setStateDialog(() {
                                currentSelectedWeekDays[index] = selected;
                                setState(() { // Update main modal state
                                  if (_isEditing) {
                                    if (_editingRecurrenceSettings != null) {
                                      if (selected) {
                                        if (_editingRecurrenceSettings!['weekDays'] == null) {
                                          _editingRecurrenceSettings!['weekDays'] = [];
                                        }
                                        if (!_editingRecurrenceSettings!['weekDays'].contains(index)) {
                                          _editingRecurrenceSettings!['weekDays'].add(index);
                                        }
                                      } else {
                                        _editingRecurrenceSettings!['weekDays'].remove(index);
                                      }
                                    }
                                  } else {
                                    if (_recurrenceSettings != null) {
                                      if (selected) {
                                        if (_recurrenceSettings!['weekDays'] == null) {
                                          _recurrenceSettings!['weekDays'] = [];
                                        }
                                        if (!_recurrenceSettings!['weekDays'].contains(index)) {
                                          _recurrenceSettings!['weekDays'].add(index);
                                        }
                                      } else {
                                        _recurrenceSettings!['weekDays'].remove(index);
                                      }
                                    }
                                  }
                                });
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
                            initialDate: currentRecurrenceEndDate ?? DateTime.now().add(Duration(days: 30)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(Duration(days: 365 * 5)),
                          );
                          if (picked != null) {
                            setStateDialog(() {
                              setState(() { // Update main modal state
                                if (_isEditing) {
                                  _editingRecurrenceEndDate = picked;
                                  if (_editingRecurrenceSettings != null) {
                                    _editingRecurrenceSettings!['end_date'] = picked.toIso8601String();
                                  }
                                } else {
                                  _recurrenceEndDate = picked;
                                  if (_recurrenceSettings != null) {
                                    _recurrenceSettings!['end_date'] = picked.toIso8601String();
                                  }
                                }
                              });
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
                            currentRecurrenceEndDate != null
                                ? DateFormat('yyyy년 M월 d일', 'ko_KR').format(currentRecurrenceEndDate)
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
                    setState(() { // Update main modal state
                      if (_isEditing) {
                        _editingRecurrenceSettings = null;
                        _editingSelectedWeekDays = List.filled(7, false);
                        _editingRecurrenceEndDate = null;
                      } else {
                        _recurrenceSettings = null;
                        _selectedWeekDays = List.filled(7, false);
                        _recurrenceEndDate = null;
                      }
                    });
                    Navigator.pop(context);
                  },
                  child: Text('취소'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // State already updated by setStateDialog and inner setState
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

  @override
  Widget build(BuildContext context) {
    // Determine which controller and date/time variables to use based on mode
    final currentEventController = _isEditing ? _editingEventController : _newEventController;
    DateTime? currentStartDateTime = _isEditing ? _editingStartDateTime : _startDateTime;
    DateTime? currentEndDateTime = _isEditing ? _editingEndDateTime : _endDateTime;
    Color currentColor = _isEditing ? (_editingSelectedColor ?? widget.colorOptions[0]) : _selectedColor;

    // Get events for the selected date
    final List<String> eventsOnSelectedDate = widget.events[widget.selectedDate] ?? [];

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
              DateFormat('yyyy년 M월 d일 EEEE', 'ko_KR').format(widget.selectedDate),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (_isEditing) ...[
              const Text('현재 일정:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Expanded( // Make ListView take available height
                child: ListView.builder(
                  itemCount: eventsOnSelectedDate.length,
                  itemBuilder: (context, index) {
                    final eventId = eventsOnSelectedDate[index];
                    final event = widget.eventDetails[eventId];
                    if (event == null) return Container();

                    final eventText = event['text'] as String;
                    final eventColor = event['color'] as Color;
                    final eventStartDate = event['startDate'] as DateTime;
                    final eventEndDate = event['endDate'] as DateTime;
                    final eventRecurrence = event['recurrence'] as Map<String, dynamic>?;
                    final eventTransactionId = event['transactionId'] as String?;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: Icon(Icons.circle, color: eventColor, size: 16),
                        title: Text(
                          eventText,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${DateFormat('HH:mm').format(eventStartDate)} - ${DateFormat('HH:mm').format(eventEndDate)}' +
                              (eventRecurrence != null ? ' (반복)' : ''),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              onPressed: () {
                                setState(() {
                                  _isEditing = true;
                                  _editingEventId = eventId;
                                  _editingEventController.text = eventText;
                                  _editingStartDateTime = eventStartDate;
                                  _editingEndDateTime = eventEndDate;
                                  _editingSelectedColor = eventColor;
                                  _editingRecurrenceSettings = eventRecurrence;
                                  _editingRecurrenceEndDate = eventRecurrence?['end_date'] != null
                                      ? DateTime.tryParse(eventRecurrence!['end_date'] as String)
                                      : null;
                                  if (eventRecurrence?['weekDays'] != null) {
                                    _editingSelectedWeekDays = List<bool>.generate(7, (idx) =>
                                        (eventRecurrence!['weekDays'] as List<dynamic>).contains(idx));
                                  } else {
                                    _editingSelectedWeekDays = List.filled(7, false);
                                  }
                                });
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                              onPressed: () async {
                                Navigator.pop(context); // Close the modal first
                                await widget.onEventAction('delete', eventId, null, null, null, null, null);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              const Text('새 일정 입력:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ] else ...[
              const Text('현재 일정:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (eventsOnSelectedDate.isEmpty)
                const Text('해당 날짜에 일정이 없습니다.')
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: eventsOnSelectedDate.length,
                    itemBuilder: (context, index) {
                      final eventId = eventsOnSelectedDate[index];
                      final event = widget.eventDetails[eventId];
                      if (event == null) return Container();

                      final eventText = event['text'] as String;
                      final eventColor = event['color'] as Color;
                      final eventStartDate = event['startDate'] as DateTime;
                      final eventEndDate = event['endDate'] as DateTime;
                      final eventRecurrence = event['recurrence'] as Map<String, dynamic>?;
                      final eventTransactionId = event['transactionId'] as String?;

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: Icon(Icons.circle, color: eventColor, size: 16),
                          title: Text(
                            eventText,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${DateFormat('HH:mm').format(eventStartDate)} - ${DateFormat('HH:mm').format(eventEndDate)}' +
                                (eventRecurrence != null ? ' (반복)' : ''),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                onPressed: () {
                                  setState(() {
                                    _isEditing = true;
                                    _editingEventId = eventId;
                                    _editingEventController.text = eventText;
                                    _editingStartDateTime = eventStartDate;
                                    _editingEndDateTime = eventEndDate;
                                    _editingSelectedColor = eventColor;
                                    _editingRecurrenceSettings = eventRecurrence;
                                    _editingRecurrenceEndDate = eventRecurrence?['end_date'] != null
                                        ? DateTime.tryParse(eventRecurrence!['end_date'] as String)
                                        : null;
                                    if (eventRecurrence?['weekDays'] != null) {
                                      _editingSelectedWeekDays = List<bool>.generate(7, (idx) =>
                                          (eventRecurrence!['weekDays'] as List<dynamic>).contains(idx));
                                    } else {
                                      _editingSelectedWeekDays = List.filled(7, false);
                                    }
                                  });
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                                onPressed: () async {
                                  Navigator.pop(context); // Close the modal first
                                  await widget.onEventAction('delete', eventId, null, null, null, null, null);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),
              const Text('새 일정 입력:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
            TextField(
              controller: currentEventController,
              decoration: const InputDecoration(
                labelText: '일정 제목',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text('색상:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: widget.colorOptions.map((color) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
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
                      border: Border.all(
                        color: (
                            _isEditing && _editingSelectedColor == color
                                || !_isEditing && _selectedColor == color
                        ) ? Colors.blue : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                _showDateTimePickerWithSetter(
                  currentStartDateTime: currentStartDateTime,
                  currentEndDateTime: currentEndDateTime,
                  onStartDateTimeChanged: (newDateTime) {
                    setState(() {
                      if (_isEditing) {
                        _editingStartDateTime = newDateTime;
                      } else {
                        _startDateTime = newDateTime;
                      }
                    });
                  },
                  onEndDateTimeChanged: (newDateTime) {
                    setState(() {
                      if (_isEditing) {
                        _editingEndDateTime = newDateTime;
                      } else {
                        _endDateTime = newDateTime;
                      }
                    });
                  },
                );
              },
              child: AbsorbPointer(
                child: Text(
                  '시간 설정: ${DateFormat('M월 d일 HH:mm', 'ko_KR').format(currentStartDateTime ?? widget.selectedDate)} - ${DateFormat('M월 d일 HH:mm', 'ko_KR').format(currentEndDateTime ?? widget.selectedDate)}',
                  style: const TextStyle(color: Colors.blue),
                ),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => _showRecurrenceDialog(context),
              child: AbsorbPointer(
                child: Text(
                  '반복 설정: ' + (
                      (_isEditing ? _editingRecurrenceSettings : _recurrenceSettings)?['type'] == 'none' || (_isEditing ? _editingRecurrenceSettings : _recurrenceSettings) == null
                          ? '반복 안 함'
                          : _recurrenceTypes.firstWhere((type) => type == (_isEditing ? _editingRecurrenceSettings : _recurrenceSettings)?['type'], orElse: () => 'none')
                  ),
                  style: const TextStyle(color: Colors.blue),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('취소'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    final saveUpdateEventId = _isEditing ? _editingEventId : null;
                    final saveUpdateText = _isEditing ? _editingEventController.text.trim() : _newEventController.text.trim();
                    final saveUpdateStartDateTime = _isEditing ? _editingStartDateTime : _startDateTime;
                    final saveUpdateEndDateTime = _isEditing ? _editingEndDateTime : _endDateTime;
                    final saveUpdateColor = _isEditing ? (_editingSelectedColor ?? widget.colorOptions[0]) : _selectedColor;
                    final saveUpdateRecurrenceSettings = _isEditing ? _editingRecurrenceSettings : _recurrenceSettings;

                    print('Mode: ${_isEditing ? 'Editing' : 'New'}');
                    print('Event ID: $saveUpdateEventId');
                    print('Event Text: $saveUpdateText');
                    print('Start DateTime: $saveUpdateStartDateTime');
                    print('End DateTime: $saveUpdateEndDateTime');
                    print('Selected Color: $saveUpdateColor');
                    print('Recurrence Settings: $saveUpdateRecurrenceSettings');

                    bool eventIsValid = saveUpdateText.isNotEmpty && saveUpdateStartDateTime != null && saveUpdateEndDateTime != null;

                    if (eventIsValid) {
                      print('Proceeding with event save/update...');

                      if (_isEditing && saveUpdateEventId != null) {
                        // 기존 이벤트 업데이트 로직
                        await widget.onEventAction(
                          'update', // actionType
                          saveUpdateEventId,
                          saveUpdateText,
                          saveUpdateStartDateTime,
                          saveUpdateEndDateTime,
                          saveUpdateColor,
                          saveUpdateRecurrenceSettings,
                        );
                        print('Event updated...');
                      } else {
                        // 새 이벤트 저장 로직
                        await widget.onEventAction(
                          'save', // actionType
                          null, // eventId (새 이벤트이므로 null)
                          saveUpdateText,
                          saveUpdateStartDateTime,
                          saveUpdateEndDateTime,
                          saveUpdateColor,
                          saveUpdateRecurrenceSettings,
                        );
                         print('New event saved...');
                      }
                      print('Event save/update process finished.');

                      _newEventController.dispose();
                      _editingEventController.dispose();
                       _isEditing = false;
                      Navigator.pop(context);
                    } else {
                      print('Validation failed:');
                      print('Event valid: $eventIsValid');
                    }
                  },
                  child: Text(_isEditing ? '수정' : '저장'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
} 