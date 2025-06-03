import 'package:flutter/material.dart';

class ScheduleInputPage extends StatefulWidget {
  final String? initialText;
  final Color? initialColor;
  final DateTime? initialStart;
  final DateTime? initialEnd;

  const ScheduleInputPage({Key? key, this.initialText, this.initialColor, this.initialStart, this.initialEnd}) : super(key: key);

  @override
  State<ScheduleInputPage> createState() => _ScheduleInputPageState();
}

class _ScheduleInputPageState extends State<ScheduleInputPage> {
  late TextEditingController _controller;
  late Color selectedColor;
  late DateTime startDateTime;
  late DateTime endDateTime;

  final List<Color> colorOptions = [
    Colors.blue.withOpacity(0.2),
    Colors.red.withOpacity(0.2),
    Colors.green.withOpacity(0.2),
    Colors.orange.withOpacity(0.2),
    Colors.purple.withOpacity(0.2),
    Colors.teal.withOpacity(0.2),
  ];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText ?? '');
    selectedColor = widget.initialColor ?? Colors.blue.withOpacity(0.2);
    startDateTime = widget.initialStart ?? DateTime.now();
    endDateTime = widget.initialEnd ?? DateTime.now();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('새 일정 입력')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(hintText: '일정 입력'),
              onSubmitted: (value) => Navigator.pop(context, {
                'text': value,
                'color': selectedColor,
                'start': startDateTime,
                'end': endDateTime,
              }),
            ),
            SizedBox(height: 20),
            Text('색상 선택:'),
            Row(
              children: colorOptions.map((color) {
                return GestureDetector(
                  onTap: () => setState(() => selectedColor = color),
                  child: Container(
                    width: 30,
                    height: 30,
                    margin: EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selectedColor == color ? Colors.black : Colors.grey.shade300,
                        width: selectedColor == color ? 2 : 1,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Text('시작: '),
                TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: startDateTime,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() => startDateTime = picked);
                    }
                  },
                  child: Text('${startDateTime.year}-${startDateTime.month}-${startDateTime.day}'),
                ),
                SizedBox(width: 16),
                Text('종료: '),
                TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: endDateTime,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() => endDateTime = picked);
                    }
                  },
                  child: Text('${endDateTime.year}-${endDateTime.month}-${endDateTime.day}'),
                ),
              ],
            ),
            Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('취소'),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, {
                      'text': _controller.text,
                      'color': selectedColor,
                      'start': startDateTime,
                      'end': endDateTime,
                    });
                  },
                  child: Text('저장'),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
} 