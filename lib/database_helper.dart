import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static const String _fileName = 'calendar_events.json';
  static const String _backupFileName = 'calendar_events_backup.json';
  
  // 웹 스토리지용 데이터
  static Map<String, dynamic> _webStorage = {};
  
  DatabaseHelper._init();

  Future<String> get _localPath async {
    if (kIsWeb) {
      return '';
    }
    try {
      final directory = await getApplicationDocumentsDirectory();
      // 디렉토리가 없으면 생성
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      return directory.path;
    } catch (e) {
      print('Error getting local path: $e');
      rethrow;
    }
  }

  Future<File> get _localFile async {
    try {
      final path = await _localPath;
      final file = File('$path/$_fileName');
      // 파일이 없으면 빈 배열로 초기화
      if (!await file.exists()) {
        await file.writeAsString('[]');
      }
      return file;
    } catch (e) {
      print('Error getting local file: $e');
      rethrow;
    }
  }

  Future<File> get _backupFile async {
    final path = await _localPath;
    final filePath = '$path/$_backupFileName';
    print('Backup File Path: $filePath'); // 백업 파일 경로 출력
    return File(filePath);
  }

  // 백업 파일 생성
  Future<void> _createBackup() async {
    try {
      final file = await _localFile;
      final backup = await _backupFile;
      if (await file.exists()) {
        await file.copy(backup.path);
      }
    } catch (e) {
      print('Error creating backup: $e');
    }
  }

  // 백업에서 복구
  Future<bool> _restoreFromBackup() async {
    try {
      final backup = await _backupFile;
      if (await backup.exists()) {
        final file = await _localFile;
        await backup.copy(file.path);
        return true;
      }
    } catch (e) {
      print('Error restoring from backup: $e');
    }
    return false;
  }

  // 데이터 유효성 검증
  bool _isValidEventData(String jsonStr) {
    try {
      final data = jsonDecode(jsonStr);
      if (data is! List) return false;
      return data.every((event) =>
          event is Map<String, dynamic> &&
          event.containsKey('id') &&
          event.containsKey('title') &&
          event.containsKey('start_date') &&
          event.containsKey('end_date') &&
          event.containsKey('color') &&
          (!event.containsKey('recurrence') || event['recurrence'] == null || (
            event['recurrence'] is Map<String, dynamic> &&
            event['recurrence'].containsKey('type') &&
            event['recurrence'].containsKey('interval') &&
            (event['recurrence']['end_date'] == null || event['recurrence']['end_date'] is String)
          ))
      );
    } catch (e) {
      return false;
    }
  }

  // 이벤트 저장
  Future<void> saveEvent(Map<String, dynamic> event) async {
    try {
      if (kIsWeb) {
        // 웹에서는 메모리에 저장
        final events = await loadEvents();
        events.removeWhere((e) => e['id'] == event['id']);
        events.add(event);
        _webStorage['events'] = events;
        return;
      }

      final file = await _localFile;
      print('Saving to file: ${file.path}'); // 저장 경로 출력
      
      final events = await loadEvents();
      events.removeWhere((e) => e['id'] == event['id']);
      
      if (!event.containsKey('id') || !event.containsKey('title') ||
          !event.containsKey('start_date') || !event.containsKey('end_date') ||
          !event.containsKey('color')) {
        throw Exception('Invalid event data: $event');
      }

      events.add(event);
      final eventsJson = jsonEncode(events);
      
      // 디렉토리가 없으면 생성
      final directory = await getApplicationDocumentsDirectory();
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      
      await file.writeAsString(eventsJson);
      print('Events saved successfully to: ${file.path}');
      
      // 백업 생성
      await _createBackup();
    } catch (e) {
      print('Error saving event: $e');
      print('Stack trace: ${StackTrace.current}');
      if (!kIsWeb) {
        if (await _restoreFromBackup()) {
          print('Successfully restored from backup after save failure');
        }
      }
      rethrow;
    }
  }

  // 모든 이벤트 로드
  Future<List<Map<String, dynamic>>> loadEvents() async {
    try {
      if (kIsWeb) {
        final events = _webStorage['events'] as List<dynamic>? ?? [];
        return events.cast<Map<String, dynamic>>();
      }

      final file = await _localFile;
      final contents = await file.readAsString();
      
      if (contents.isEmpty) {
        await file.writeAsString('[]');
        return [];
      }

      try {
        List<dynamic> eventsList = jsonDecode(contents);
        return eventsList.cast<Map<String, dynamic>>();
      } catch (e) {
        print('Error parsing JSON: $e');
        await file.writeAsString('[]');
        return [];
      }
    } catch (e) {
      print('Error loading events: $e');
      return [];
    }
  }

  // 이벤트 삭제
  Future<void> deleteEvent(String eventId) async {
    try {
      if (kIsWeb) {
        final events = await loadEvents();
        events.removeWhere((event) => event['id'] == eventId);
        _webStorage['events'] = events;
        return;
      }

      await _createBackup();
      final events = await loadEvents();
      events.removeWhere((event) => event['id'] == eventId);
      
      final file = File('${await _localPath}/$_fileName');
      final eventsJson = jsonEncode(events);
      await file.writeAsString(eventsJson);
      print('Event deleted successfully: $eventId');
    } catch (e) {
      print('Error deleting event: $e');
      if (!kIsWeb) {
        if (await _restoreFromBackup()) {
          print('Successfully restored from backup after delete failure');
        }
      }
      rethrow;
    }
  }

  // 모든 이벤트 삭제
  Future<void> clearAllEvents() async {
    try {
      await _createBackup(); // 삭제 전 백업 생성
      
      final file = await _localFile;
      if (await file.exists()) {
        await file.delete();
        print('All events cleared successfully');
      }
    } catch (e) {
      print('Error clearing events: $e');
      // 삭제 실패 시 백업에서 복구 시도
      if (await _restoreFromBackup()) {
        print('Successfully restored from backup after clear failure');
      }
      rethrow;
    }
  }
} 