import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AcademicScheduleHelper {
  static final Map<int, Map<String, String>> _yearlyAcademicSchedules = {
    2024: {
      "0101": "신정 (학사 일정)", // 공휴일과 겹치는 예시
      "0302": "입학식",
      "0304": "1학기 개강",
      "0505": "어린이날 (학사 일정)", // 공휴일과 겹치는 예시
      "0515": "교내 축제",
      "0620": "1학기 기말고사",
      "0628": "1학기 종강",
      "0826": "2학기 개강",
      "1225": "성탄절 (학사 일정)", // 공휴일과 겹치는 예시
    },
    2025: {
      "0101": "대학신정",
      "0108": "대학겨울 계절수업 종강",
      "0122": "대학장바구니 수강신청 시작",
      "0124": "대학장바구니 수강신청 종료",
      "0128": "대학설 연휴 시작",
      "0130": "대학설 연휴 종료",
      "0203": "대학복학 신청 시작",
      "0228": "대학휴학 신청 종료",
      "0210": "대학수강신청 시작",
      "0213": "대학수강신청 종료",
      "0217": "대학휴학 신청 시작",
      "0219": "대학재학생 등록 시작",
      "0221": "대학학위수여일",
      "0225": "대학신입생 입학식",
      "0226": "대학신입생 수강신청 종료",
      "0301": "대학삼일절",
      "0303": "대학대체공휴일(자율 보강)",
      "0304": "대학제1학기 개강",
      "0306": "대학제1학기 수강변경(정정)기간 시작",
      "0310": "대학제1학기 수강변경(정정)기간 종료",
      "0318": "대학제1학기 수강포기 신청기간 시작",
      "0320": "대학제1학기 수강포기 신청기간 종료",
      "0407": "대학제1학기 수업일수 1/3선",
      "0414": "대학제1학기 부복수 전공 신청기간 시작",
      "0418": "대학제1학기 부복수 전공 신청기간 종료",
      "0421": "대학여름 계절수업 희망수강신청기간 시작",
      "0425": "대학여름 계절수업 희망수강신청기간 종료",
      "0422": "대학제1학기 중간시험기간 시작",
      "0428": "대학제1학기 중간시험기간 종료",
      "0424": "대학제1학기 수업일수 1/2선",
      "0501": "대학개교69주년 기념일(자율 보강)",
      "0505": "대학어린이날, 부처님 오신날(자율 보강)",
      "0506": "대학대체공휴일(자율 보강)",
      "0512": "대학제1학기 수업일수 2/3선",
      "0519": "대학여름 계절수업 수강신청 시작",
      "0523": "대학여름 계절수업 수강신청 종료",
      "0530": "대학제1학기 학교현장실습 종료",
      "0603": "대학제21대 대통령 선거일 임시공휴일(자율 보강)",
      "0606": "대학현충일(자율 보강)",
      "0610": "대학제1학기 기말시험 시작",
      "0616": "대학제1학기 기말시험 종료",
      "0617": "대학여름방학",
      "0618": "대학여름 계절수업 개강",
      "0623": "대학제1학기 성적입력 마감",
      "0624": "대학제1학기 성적이의신청 시작",
      "0626": "대학제1학기 성적이의신청 종료",
      "0627": "대학제1학기 최종성적 확정",
      "0708": "대학여름 계절수업 종강",
      "0730": "대학제2학기 장바구니 수강신청 시작",
      "0801": "대학2025학년도 제2학기 복학 신청 시작",
      "0811": "대학2025학년도 제2학기 수강신청 시작",
      "0814": "대학2025학년도 제2학기 수강신청 종료",
      "0815": "대학광복절",
      "0822": "대학2024학년도 후기 학위수여일",
      "0825": "대학2025학년도 제2학기 재학생 등록 시작",
      "0827": "대학2025학년도 제2학기 재학생 등록 종료",
      "0829": "대학2025학년도 제2학기 복학 신청 종료",
      "0901": "대학제2학기 개강",
      "0903": "대학제2학기 수강변경 시작",
      "0905": "대학제2학기 수강변경 종료",
      "0915": "대학제2학기 수강포기 신청기간 시작",
      "0917": "대학제2학기 수강포기 신청기간 종료",
      "1003": "대학개천절(자율 보강), 제2학기 수업일수 1/3선",
      "1006": "대학추석 연휴 시작(자율 보강)",
      "1007": "대학추석 연휴 종료(자율 보강)",
      "1008": "대학대체공휴일(자율 보강)",
      "1009": "대학한글날(자율 보강)",
      "1013": "대학제2학기 학교현장실습 시작",
      "1017": "대학제2학기 부복수 전공 신청 종료",
      "1020": "대학제2학기 중간시험 시작",
      "1022": "대학제2학기 수업일수 1/2선",
      "1024": "대학겨울 계절수업 희망수강신청 종료",
      "1025": "대학제2학기 중간시험 종료",
      "1107": "대학제2학기 수업일수 2/3선",
      "1117": "대학겨울 계절수업 수강신청 시작",
      "1121": "대학겨울 계절수업 수강신청 종료",
      "1208": "대학제2학기 기말시험 시작",
      "1213": "대학제2학기 기말시험 종료",
      "1215": "대학겨울방학",
      "1216": "대학겨울 계절수업 개강",
      "1222": "대학제2학기 성적입력 마감",
      "1223": "대학제2학기 성적이의신청 시작",
      "1225": "대학크리스마스",
      "1226": "대학제2학기 성적이의신청 종료",
      "1229": "대학제2학기 최종성적 확정"
    },
    // 다른 연도의 학사 일정을 여기에 추가할 수 있습니다.
  };

  static String? getAcademicScheduleName(DateTime date) {
    int year = date.year;
    String dateStr = '${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';

    final schedulesForYear = _yearlyAcademicSchedules[year] ?? {};
    if (schedulesForYear.containsKey(dateStr)) {
      final name = schedulesForYear[dateStr];
      print('Checking date: ${DateFormat('yyyy-MM-dd').format(date)}, Found academic schedule: $name');
      return name;
    }
    print('Checking date: ${DateFormat('yyyy-MM-dd').format(date)}, No academic schedule found.');
    return null;
  }

  static Color getAcademicScheduleColor() {
    return Colors.green; // 학사 일정을 위한 초록색
  }
} 