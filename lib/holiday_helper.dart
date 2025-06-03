import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Import Intl package for date formatting

class HolidayHelper {
  // 연도별 공휴일 데이터
  static final Map<int, Map<String, String>> _yearlyHolidays = {
    2022: {
      "0101": "신정",
      "0301": "삼일절",
      "0505": "어린이날",
      "0606": "현충일",
      "0815": "광복절",
      "1003": "개천절",
      "1009": "한글날",
      "1225": "성탄절",
      "0309": "제20대 대통령선거",
      "0601": "지방선거"
    },
    2023: {
      '0101': '신정',
      '0301': '삼일절',
      '0505': '어린이날',
      '0606': '현충일',
      '0815': '광복절',
      '1003': '개천절',
      '1009': '한글날',
      '1225': '성탄절',
    },
    2024: {
      "0101": "신정",
      "0301": "삼일절",
      "0401": "제22대 국회의원선거",
      "0505": "어린이날",
      "0606": "현충일",
      "0815": "광복절",
      "1003": "개천절",
      "1009": "한글날",
      "1225": "성탄절"
    },
    2025: {
      "0101": "신정",
      "0301": "삼일절",
      "0505": "어린이날 및 부처님오신날",
      "0506": "대체공휴일",
      "0603": "21대 대통령선거",
      "0606": "현충일",
      "0815": "광복절",
      "1003": "개천절",
      "1009": "한글날",
      "1225": "성탄절"
    },
     2026: {
      "0101": "신정",
      "0301": "삼일절",
      "0302": "삼일절 대체공휴일",
      "0501": "근로자의 날",
      "0505": "어린이날",
      "0606": "현충일",
      "0815": "광복절",
      "0817": "광복절 대체공휴일",
      "1003": "개천절",
      "1005": "개천절 대체공휴일",
      "1009": "한글날",
      "1225": "성탄절"
    }
  };

  // 음력 공휴일 (매년 날짜가 변동됨)
  static final Map<int, Map<String, String>> _yearlyLunarHolidays = {
    2022: {
      "0131": "설날 연휴",
      "0201": "설날",
      "0202": "설날 연휴",
      "0203": "설날 대체공휴일",
      "0508": "부처님오신날",
      "0909": "추석 연휴",
      "0910": "추석",
      "0911": "추석 연휴",
      "0912": "추석 대체공휴일"
    },
     2023: {
      '0121': '설날 연휴',
      '0122': '설날',
      '0123': '설날 연휴',
      '0124': '설날 대체공휴일',
      '0527': '부처님오신날',
      '0529': '부처님오신날 대체공휴일',
      '0928': '추석 연휴',
      '0929': '추석',
      '0930': '추석 연휴',
    },
    2024: {
      "0209": "설날 연휴",
      "0210": "설날",
      "0211": "설날 연휴",
      "0212": "설날 대체공휴일",
      "0515": "부처님오신날",
      "0516": "부처님오신날 대체공휴일",
      "0916": "추석 연휴",
      "0917": "추석",
      "0918": "추석 연휴"
    },
    2025: {
      "0128": "설날 연휴",
      "0129": "설날",
      "0130": "설날 연휴",
      "0131": "설날 대체공휴일",
      "0505": "부처님오신날 (양력과 동일)",
      "1006": "추석 연휴",
      "1007": "추석",
      "1008": "추석 연휴"
    },
    2026: {
      "0216": "설날 연휴",
      "0217": "설날",
      "0218": "설날 연휴",
      "0524": "부처님오신날",
      "0525": "부처님오신날 대체공휴일",
      "0924": "추석 연휴",
      "0925": "추석",
      "0926": "추석 연휴"
    }
  };

  static bool isHoliday(DateTime date) {
    return getHolidayName(date) != null;
  }

  static String? getHolidayName(DateTime date) {
    int year = date.year;
    String dateStr = '${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';

    // 해당 연도의 양력 공휴일 데이터 가져오기 (없으면 빈 맵 사용)
    final holidaysForYear = _yearlyHolidays[year] ?? {};
    if (holidaysForYear.containsKey(dateStr)) {
      final name = holidaysForYear[dateStr];
      print('Checking date: ${DateFormat('yyyy-MM-dd').format(date)}, Found holiday (solar): $name'); // Debug print
      return name; // Return directly if found in solar
    }

    // 해당 연도의 음력 공휴일 데이터 가져오기 (없으면 빈 맵 사용)
    final lunarHolidaysForYear = _yearlyLunarHolidays[year] ?? {};
    if (lunarHolidaysForYear.containsKey(dateStr)) {
      final name = lunarHolidaysForYear[dateStr];
      print('Checking date: ${DateFormat('yyyy-MM-dd').format(date)}, Found holiday (lunar): $name'); // Debug print
      return name; // Return directly if found in lunar
    }

    // 해당 연도에 공휴일 데이터가 없으면 null 반환
    print('Checking date: ${DateFormat('yyyy-MM-dd').format(date)}, No holiday found.'); // Debug print
    return null;
  }

  static Color getHolidayColor() {
    return Colors.red.withOpacity(0.2);
  }
} 