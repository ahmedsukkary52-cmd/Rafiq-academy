import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/network/network_info.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import 'student_recitation_page.dart';

enum MushafMode { reading, recitation }

class ReciterInfo {
  final String id;
  final String name;
  final String subDirectory;

  const ReciterInfo({
    required this.id,
    required this.name,
    required this.subDirectory,
  });
}

class SurahMeta {
  final int number;
  final String name;
  final String juz;
  final String type;
  final int versesCount;

  const SurahMeta({
    required this.number,
    required this.name,
    required this.juz,
    required this.type,
    required this.versesCount,
  });
}

class AyahModel {
  final int number;
  final int numberInSurah;
  final String text;
  final int page;
  final int surahNumber;

  const AyahModel({
    required this.number,
    required this.numberInSurah,
    required this.text,
    required this.page,
    required this.surahNumber,
  });

  factory AyahModel.fromJson(Map<String, dynamic> json, int surahNumber) {
    return AyahModel(
      number: json['number'] as int,
      numberInSurah: json['numberInSurah'] as int,
      text: json['text'] as String,
      page: json['page'] as int,
      surahNumber: surahNumber,
    );
  }
}

class StudentMushafPage extends StatefulWidget {
  final int surahNumber;
  final MushafMode initialMode;
  final bool isFreeMode;

  const StudentMushafPage({
    super.key,
    this.surahNumber = 67,
    this.initialMode = MushafMode.reading,
    this.isFreeMode = false,
  });

  @override
  State<StudentMushafPage> createState() => _StudentMushafPageState();
}

class _StudentMushafPageState extends State<StudentMushafPage> {
  static const Map<int, SurahMeta> _surahCatalog = {
    1: SurahMeta(
      number: 1,
      name: 'الفاتحة',
      juz: 'الجزء الأول',
      type: 'مكية',
      versesCount: 7,
    ),
    2: SurahMeta(
      number: 2,
      name: 'البقرة',
      juz: 'الجزء الأول',
      type: 'مدنية',
      versesCount: 286,
    ),
    3: SurahMeta(
      number: 3,
      name: 'آل عمران',
      juz: 'الجزء الثالث',
      type: 'مدنية',
      versesCount: 200,
    ),
    4: SurahMeta(
      number: 4,
      name: 'النساء',
      juz: 'الجزء الرابع',
      type: 'مدنية',
      versesCount: 176,
    ),
    5: SurahMeta(
      number: 5,
      name: 'المائدة',
      juz: 'الجزء السادس',
      type: 'مدنية',
      versesCount: 120,
    ),
    6: SurahMeta(
      number: 6,
      name: 'الأنعام',
      juz: 'الجزء السابع',
      type: 'مكية',
      versesCount: 165,
    ),
    7: SurahMeta(
      number: 7,
      name: 'الأعراف',
      juz: 'الجزء الثامن',
      type: 'مكية',
      versesCount: 206,
    ),
    8: SurahMeta(
      number: 8,
      name: 'الأنفال',
      juz: 'الجزء العاشر',
      type: 'مدنية',
      versesCount: 75,
    ),
    9: SurahMeta(
      number: 9,
      name: 'التوبة',
      juz: 'الجزء العاشر',
      type: 'مدنية',
      versesCount: 129,
    ),
    10: SurahMeta(
      number: 10,
      name: 'يونس',
      juz: 'الجزء الحادي عشر',
      type: 'مكية',
      versesCount: 109,
    ),
    11: SurahMeta(
      number: 11,
      name: 'هود',
      juz: 'الجزء الثاني عشر',
      type: 'مكية',
      versesCount: 123,
    ),
    12: SurahMeta(
      number: 12,
      name: 'يوسف',
      juz: 'الجزء الثالث عشر',
      type: 'مكية',
      versesCount: 111,
    ),
    13: SurahMeta(
      number: 13,
      name: 'الرعد',
      juz: 'الجزء الرابع عشر',
      type: 'مدنية',
      versesCount: 43,
    ),
    14: SurahMeta(
      number: 14,
      name: 'إبراهيم',
      juz: 'الجزء الرابع عشر',
      type: 'مكية',
      versesCount: 52,
    ),
    15: SurahMeta(
      number: 15,
      name: 'الحجر',
      juz: 'الجزء الخامس عشر',
      type: 'مكية',
      versesCount: 99,
    ),
    16: SurahMeta(
      number: 16,
      name: 'النحل',
      juz: 'الجزء الخامس عشر',
      type: 'مكية',
      versesCount: 128,
    ),
    17: SurahMeta(
      number: 17,
      name: 'الإسراء',
      juz: 'الجزء السادس عشر',
      type: 'مكية',
      versesCount: 111,
    ),
    18: SurahMeta(
      number: 18,
      name: 'الكهف',
      juz: 'الجزء السادس عشر',
      type: 'مكية',
      versesCount: 110,
    ),
    19: SurahMeta(
      number: 19,
      name: 'مريم',
      juz: 'الجزء السابع عشر',
      type: 'مكية',
      versesCount: 98,
    ),
    20: SurahMeta(
      number: 20,
      name: 'طه',
      juz: 'الجزء السابع عشر',
      type: 'مكية',
      versesCount: 135,
    ),
    21: SurahMeta(
      number: 21,
      name: 'الأنبياء',
      juz: 'الجزء الثامن عشر',
      type: 'مكية',
      versesCount: 112,
    ),
    22: SurahMeta(
      number: 22,
      name: 'الحج',
      juz: 'الجزء الثامن عشر',
      type: 'مدنية',
      versesCount: 78,
    ),
    23: SurahMeta(
      number: 23,
      name: 'المؤمنون',
      juz: 'الجزء التاسع عشر',
      type: 'مكية',
      versesCount: 118,
    ),
    24: SurahMeta(
      number: 24,
      name: 'النور',
      juz: 'الجزء التاسع عشر',
      type: 'مدنية',
      versesCount: 64,
    ),
    25: SurahMeta(
      number: 25,
      name: 'الفرقان',
      juz: 'الجزء العشرون',
      type: 'مكية',
      versesCount: 77,
    ),
    26: SurahMeta(
      number: 26,
      name: 'الشعراء',
      juz: 'الجزء العشرون',
      type: 'مكية',
      versesCount: 227,
    ),
    27: SurahMeta(
      number: 27,
      name: 'النمل',
      juz: 'الجزء الحادي والعشرون',
      type: 'مكية',
      versesCount: 93,
    ),
    28: SurahMeta(
      number: 28,
      name: 'القصص',
      juz: 'الجزء الحادي والعشرون',
      type: 'مكية',
      versesCount: 88,
    ),
    29: SurahMeta(
      number: 29,
      name: 'العنكبوت',
      juz: 'الجزء الثاني والعشرون',
      type: 'مكية',
      versesCount: 69,
    ),
    30: SurahMeta(
      number: 30,
      name: 'الروم',
      juz: 'الجزء الثاني والعشرون',
      type: 'مكية',
      versesCount: 60,
    ),
    31: SurahMeta(
      number: 31,
      name: 'لقمان',
      juz: 'الجزء الثالث والعشرون',
      type: 'مكية',
      versesCount: 34,
    ),
    32: SurahMeta(
      number: 32,
      name: 'السجدة',
      juz: 'الجزء الثالث والعشرون',
      type: 'مكية',
      versesCount: 30,
    ),
    33: SurahMeta(
      number: 33,
      name: 'الأحزاب',
      juz: 'الجزء الثالث والعشرون',
      type: 'مدنية',
      versesCount: 73,
    ),
    34: SurahMeta(
      number: 34,
      name: 'سبأ',
      juz: 'الجزء الرابع والعشرون',
      type: 'مكية',
      versesCount: 54,
    ),
    35: SurahMeta(
      number: 35,
      name: 'فاطر',
      juz: 'الجزء الرابع والعشرون',
      type: 'مكية',
      versesCount: 45,
    ),
    36: SurahMeta(
      number: 36,
      name: 'يس',
      juz: 'الجزء الرابع والعشرون',
      type: 'مكية',
      versesCount: 83,
    ),
    37: SurahMeta(
      number: 37,
      name: 'الصافات',
      juz: 'الجزء الخامس والعشرون',
      type: 'مكية',
      versesCount: 182,
    ),
    38: SurahMeta(
      number: 38,
      name: 'ص',
      juz: 'الجزء الخامس والعشرون',
      type: 'مكية',
      versesCount: 88,
    ),
    39: SurahMeta(
      number: 39,
      name: 'الزمر',
      juz: 'الجزء السادس والعشرون',
      type: 'مكية',
      versesCount: 75,
    ),
    40: SurahMeta(
      number: 40,
      name: 'غافر',
      juz: 'الجزء السادس والعشرون',
      type: 'مكية',
      versesCount: 85,
    ),
    41: SurahMeta(
      number: 41,
      name: 'فصلت',
      juz: 'الجزء السابع والعشرون',
      type: 'مكية',
      versesCount: 54,
    ),
    42: SurahMeta(
      number: 42,
      name: 'الشورى',
      juz: 'الجزء السابع والعشرون',
      type: 'مكية',
      versesCount: 53,
    ),
    43: SurahMeta(
      number: 43,
      name: 'الزخرف',
      juz: 'الجزء الثامن والعشرون',
      type: 'مكية',
      versesCount: 89,
    ),
    44: SurahMeta(
      number: 44,
      name: 'الدخان',
      juz: 'الجزء الثامن والعشرون',
      type: 'مكية',
      versesCount: 59,
    ),
    45: SurahMeta(
      number: 45,
      name: 'الجاثية',
      juz: 'الجزء الثامن والعشرون',
      type: 'مكية',
      versesCount: 37,
    ),
    46: SurahMeta(
      number: 46,
      name: 'الأحقاف',
      juz: 'الجزء التاسع والعشرون',
      type: 'مكية',
      versesCount: 35,
    ),
    47: SurahMeta(
      number: 47,
      name: 'محمد',
      juz: 'الجزء التاسع والعشرون',
      type: 'مدنية',
      versesCount: 38,
    ),
    48: SurahMeta(
      number: 48,
      name: 'الفتح',
      juz: 'الجزء التاسع والعشرون',
      type: 'مدنية',
      versesCount: 29,
    ),
    49: SurahMeta(
      number: 49,
      name: 'الحجرات',
      juz: 'الجزء التاسع والعشرون',
      type: 'مدنية',
      versesCount: 18,
    ),
    50: SurahMeta(
      number: 50,
      name: 'ق',
      juz: 'الجزء التاسع والعشرون',
      type: 'مكية',
      versesCount: 45,
    ),
    51: SurahMeta(
      number: 51,
      name: 'الذاريات',
      juz: 'الجزء الثلاثون',
      type: 'مكية',
      versesCount: 60,
    ),
    52: SurahMeta(
      number: 52,
      name: 'الطور',
      juz: 'الجزء الثلاثون',
      type: 'مكية',
      versesCount: 49,
    ),
    53: SurahMeta(
      number: 53,
      name: 'النجم',
      juz: 'الجزء الثلاثون',
      type: 'مكية',
      versesCount: 62,
    ),
    54: SurahMeta(
      number: 54,
      name: 'القمر',
      juz: 'الجزء الثلاثون',
      type: 'مكية',
      versesCount: 55,
    ),
    55: SurahMeta(
      number: 55,
      name: 'الرحمن',
      juz: 'الجزء الثلاثون',
      type: 'مدنية',
      versesCount: 78,
    ),
    56: SurahMeta(
      number: 56,
      name: 'الواقعة',
      juz: 'الجزء الثلاثون',
      type: 'مكية',
      versesCount: 96,
    ),
    57: SurahMeta(
      number: 57,
      name: 'الحديد',
      juz: 'الجزء الثلاثون',
      type: 'مدنية',
      versesCount: 29,
    ),
    58: SurahMeta(
      number: 58,
      name: 'المجادلة',
      juz: 'الجزء الثلاثون',
      type: 'مدنية',
      versesCount: 22,
    ),
    59: SurahMeta(
      number: 59,
      name: 'الحشر',
      juz: 'الجزء الثلاثون',
      type: 'مدنية',
      versesCount: 24,
    ),
    60: SurahMeta(
      number: 60,
      name: 'الممتحنة',
      juz: 'الجزء الثلاثون',
      type: 'مدنية',
      versesCount: 13,
    ),
    61: SurahMeta(
      number: 61,
      name: 'الصف',
      juz: 'الجزء الثلاثون',
      type: 'مدنية',
      versesCount: 14,
    ),
    62: SurahMeta(
      number: 62,
      name: 'الجمعة',
      juz: 'الجزء الثلاثون',
      type: 'مدنية',
      versesCount: 11,
    ),
    63: SurahMeta(
      number: 63,
      name: 'المنافقون',
      juz: 'الجزء الثلاثون',
      type: 'مدنية',
      versesCount: 11,
    ),
    64: SurahMeta(
      number: 64,
      name: 'التغابن',
      juz: 'الجزء الثلاثون',
      type: 'مدنية',
      versesCount: 18,
    ),
    65: SurahMeta(
      number: 65,
      name: 'الطلاق',
      juz: 'الجزء الثلاثون',
      type: 'مدنية',
      versesCount: 12,
    ),
    66: SurahMeta(
      number: 66,
      name: 'التحريم',
      juz: 'الجزء الثلاثون',
      type: 'مدنية',
      versesCount: 12,
    ),
    67: SurahMeta(
      number: 67,
      name: 'الملك',
      juz: 'الجزء التاسع والعشرون',
      type: 'مكية',
      versesCount: 30,
    ),
    68: SurahMeta(
      number: 68,
      name: 'القلم',
      juz: 'الجزء التاسع والعشرون',
      type: 'مكية',
      versesCount: 52,
    ),
    69: SurahMeta(
      number: 69,
      name: 'الحاقة',
      juz: 'الجزء التاسع والعشرون',
      type: 'مكية',
      versesCount: 52,
    ),
    70: SurahMeta(
      number: 70,
      name: 'المعارج',
      juz: 'الجزء التاسع والعشرون',
      type: 'مكية',
      versesCount: 44,
    ),
    71: SurahMeta(
      number: 71,
      name: 'نوح',
      juz: 'الجزء التاسع والعشرون',
      type: 'مكية',
      versesCount: 28,
    ),
    72: SurahMeta(
      number: 72,
      name: 'الجن',
      juz: 'الجزء التاسع والعشرون',
      type: 'مكية',
      versesCount: 28,
    ),
    73: SurahMeta(
      number: 73,
      name: 'المزمل',
      juz: 'الجزء التاسع والعشرون',
      type: 'مكية',
      versesCount: 20,
    ),
    74: SurahMeta(
      number: 74,
      name: 'المدثر',
      juz: 'الجزء التاسع والعشرون',
      type: 'مكية',
      versesCount: 56,
    ),
    75: SurahMeta(
      number: 75,
      name: 'القيامة',
      juz: 'الجزء التاسع والعشرون',
      type: 'مكية',
      versesCount: 40,
    ),
    76: SurahMeta(
      number: 76,
      name: 'الإنسان',
      juz: 'الجزء الثلاثون',
      type: 'مدنية',
      versesCount: 31,
    ),
    77: SurahMeta(
      number: 77,
      name: 'المرسلات',
      juz: 'الجزء الثلاثون',
      type: 'مكية',
      versesCount: 50,
    ),
    78: SurahMeta(
      number: 78,
      name: 'النبأ',
      juz: 'الجزء الثلاثون',
      type: 'مكية',
      versesCount: 40,
    ),
    79: SurahMeta(
      number: 79,
      name: 'النازعات',
      juz: 'الجزء الثلاثون',
      type: 'مكية',
      versesCount: 46,
    ),
    80: SurahMeta(
      number: 80,
      name: 'عبس',
      juz: 'الجزء الثلاثون',
      type: 'مكية',
      versesCount: 42,
    ),
    81: SurahMeta(
      number: 81,
      name: 'التكوير',
      juz: 'الجزء الثلاثون',
      type: 'مكية',
      versesCount: 29,
    ),
    82: SurahMeta(
      number: 82,
      name: 'الانفطار',
      juz: 'الجزء الثلاثون',
      type: 'مكية',
      versesCount: 19,
    ),
    83: SurahMeta(
      number: 83,
      name: 'المطففين',
      juz: 'الجزء الثلاثون',
      type: 'مكية',
      versesCount: 36,
    ),
    84: SurahMeta(
      number: 84,
      name: 'الانشقاق',
      juz: 'الجزء الثلاثون',
      type: 'مكية',
      versesCount: 25,
    ),
    85: SurahMeta(
      number: 85,
      name: 'البروج',
      juz: 'الجزء الثلاثون',
      type: 'مكية',
      versesCount: 22,
    ),
    86: SurahMeta(
      number: 86,
      name: 'الطارق',
      juz: 'الجزء الثلاثون',
      type: 'مكية',
      versesCount: 17,
    ),
    87: SurahMeta(
      number: 87,
      name: 'الأعلى',
      juz: 'الجزء الثلاثون',
      type: 'مكية',
      versesCount: 19,
    ),
    88: SurahMeta(
      number: 88,
      name: 'الغاشية',
      juz: 'الجزء الثلاثون',
      type: 'مكية',
      versesCount: 26,
    ),
    89: SurahMeta(
      number: 89,
      name: 'الفجر',
      juz: 'الجزء الثلاثون',
      type: 'مكية',
      versesCount: 30,
    ),
    90: SurahMeta(
      number: 90,
      name: 'البلد',
      juz: 'الجزء الثلاثون',
      type: 'مكية',
      versesCount: 20,
    ),
    91: SurahMeta(
      number: 91,
      name: 'الشمس',
      juz: 'الجزء الثلاثون',
      type: 'مكية',
      versesCount: 15,
    ),
    92: SurahMeta(
      number: 92,
      name: 'الليل',
      juz: 'الجزء الثلاثون',
      type: 'مكية',
      versesCount: 21,
    ),
    93: SurahMeta(
      number: 93,
      name: 'الضحى',
      juz: 'الجزء الثلاثون',
      type: 'مكية',
      versesCount: 11,
    ),
    94: SurahMeta(
      number: 94,
      name: 'الشرح',
      juz: 'الجزء الثلاثون',
      type: 'مكية',
      versesCount: 8,
    ),
    95: SurahMeta(
      number: 95,
      name: 'التين',
      juz: 'الجزء الثلاثون',
      type: 'مكية',
      versesCount: 8,
    ),
    96: SurahMeta(
      number: 96,
      name: 'العلق',
      juz: 'الجزء الثلاثون',
      type: 'مكية',
      versesCount: 19,
    ),
    97: SurahMeta(
      number: 97,
      name: 'القدر',
      juz: 'الجزء الثلاثون',
      type: 'مكية',
      versesCount: 5,
    ),
    98: SurahMeta(
      number: 98,
      name: 'البينة',
      juz: 'الجزء الثلاثون',
      type: 'مدنية',
      versesCount: 8,
    ),
    99: SurahMeta(
      number: 99,
      name: 'الزلزلة',
      juz: 'الجزء الثلاثون',
      type: 'مدنية',
      versesCount: 8,
    ),
    100: SurahMeta(
      number: 100,
      name: 'العاديات',
      juz: 'الجزء الثلاثون',
      type: 'مكية',
      versesCount: 11,
    ),
    101: SurahMeta(
      number: 101,
      name: 'القارعة',
      juz: 'الجزء الثلاثون',
      type: 'مكية',
      versesCount: 11,
    ),
    102: SurahMeta(
      number: 102,
      name: 'التكاثر',
      juz: 'الجزء الثلاثون',
      type: 'مكية',
      versesCount: 8,
    ),
    103: SurahMeta(
      number: 103,
      name: 'العصر',
      juz: 'الجزء الثلاثون',
      type: 'مكية',
      versesCount: 3,
    ),
    104: SurahMeta(
      number: 104,
      name: 'الهمزة',
      juz: 'الجزء الثلاثون',
      type: 'مكية',
      versesCount: 9,
    ),
    105: SurahMeta(
      number: 105,
      name: 'الفيل',
      juz: 'الجزء الثلاثون',
      type: 'مكية',
      versesCount: 5,
    ),
    106: SurahMeta(
      number: 106,
      name: 'قريش',
      juz: 'الجزء الثلاثون',
      type: 'مكية',
      versesCount: 4,
    ),
    107: SurahMeta(
      number: 107,
      name: 'الماعون',
      juz: 'الجزء الثلاثون',
      type: 'مكية',
      versesCount: 7,
    ),
    108: SurahMeta(
      number: 108,
      name: 'الكوثر',
      juz: 'الجزء الثلاثون',
      type: 'مكية',
      versesCount: 3,
    ),
    109: SurahMeta(
      number: 109,
      name: 'الكافرون',
      juz: 'الجزء الثلاثون',
      type: 'مكية',
      versesCount: 6,
    ),
    110: SurahMeta(
      number: 110,
      name: 'النصر',
      juz: 'الجزء الثلاثون',
      type: 'مدنية',
      versesCount: 3,
    ),
    111: SurahMeta(
      number: 111,
      name: 'المسد',
      juz: 'الجزء الثلاثون',
      type: 'مكية',
      versesCount: 5,
    ),
    112: SurahMeta(
      number: 112,
      name: 'الإخلاص',
      juz: 'الجزء الثلاثون',
      type: 'مكية',
      versesCount: 4,
    ),
    113: SurahMeta(
      number: 113,
      name: 'الفلق',
      juz: 'الجزء الثلاثون',
      type: 'مكية',
      versesCount: 5,
    ),
    114: SurahMeta(
      number: 114,
      name: 'الناس',
      juz: 'الجزء الثلاثون',
      type: 'مكية',
      versesCount: 6,
    ),
  };

  static const List<ReciterInfo> _reciters = [
    ReciterInfo(
      id: 'minshawi',
      name: 'المنشاوي',
      subDirectory: 'Minshawy_Murattal_128kbps',
    ),
    ReciterInfo(id: 'husary', name: 'الحصري', subDirectory: 'Husary_128kbps'),
    ReciterInfo(
      id: 'basit',
      name: 'عبد الباسط',
      subDirectory: 'Abdul_Basit_Murattal_128kbps',
    ),
    ReciterInfo(id: 'afasy', name: 'العفاسي', subDirectory: 'Alafasy_128kbps'),
    ReciterInfo(
      id: 'ajmi',
      name: 'العجمي',
      subDirectory: 'Ahmad_Al_Ajmi_64kbps',
    ),
    ReciterInfo(
      id: 'muaiqly',
      name: 'المعيقلي',
      subDirectory: 'Maher_AlMuaiqly_128kbps',
    ),
  ];

  static final String _bismillahText = String.fromCharCodes([
    0x0628,
    0x0650,
    0x0633,
    0x0652,
    0x0645,
    0x0650,
    0x0020,
    0x0671,
    0x0644,
    0x0644,
    0x0651,
    0x064e,
    0x0647,
    0x0650,
    0x0020,
    0x0671,
    0x0644,
    0x0631,
    0x0651,
    0x064e,
    0x062d,
    0x0652,
    0x0645,
    0x064e,
    0x0670,
    0x0646,
    0x0650,
    0x0020,
    0x0671,
    0x0644,
    0x0631,
    0x0651,
    0x064e,
    0x062d,
    0x0650,
    0x064a,
    0x0645,
    0x0650,
  ]);

  static const String _lastFreeSurahKey = 'last_free_mushaf_surah';

  static const List<String> _allSurahNames = [
    'الفاتحة',
    'البقرة',
    'آل عمران',
    'النساء',
    'المائدة',
    'الأنعام',
    'الأعراف',
    'الأنفال',
    'التوبة',
    'يونس',
    'هود',
    'يوسف',
    'الرعد',
    'إبراهيم',
    'الحجر',
    'النحل',
    'الإسراء',
    'الكهف',
    'مريم',
    'طه',
    'الأنبياء',
    'الحج',
    'المؤمنون',
    'النور',
    'الفرقان',
    'الشعراء',
    'النمل',
    'القصص',
    'العنكبوت',
    'الروم',
    'لقمان',
    'السجدة',
    'الأحزاب',
    'سبأ',
    'فاطر',
    'يس',
    'الصافات',
    'ص',
    'الزمر',
    'غافر',
    'فصلت',
    'الشورى',
    'الزخرف',
    'الدخان',
    'الجاثية',
    'الأحقاف',
    'محمد',
    'الفتح',
    'الحجرات',
    'ق',
    'الذاريات',
    'الطور',
    'النجم',
    'القمر',
    'الرحمن',
    'الواقعة',
    'الحديد',
    'المجادلة',
    'الحشر',
    'الممتحنة',
    'الصف',
    'الجمعة',
    'المنافقون',
    'التغابن',
    'الطلاق',
    'التحريم',
    'الملك',
    'القلم',
    'الحاقة',
    'المعارج',
    'نوح',
    'الجن',
    'المزمل',
    'المدثر',
    'القيامة',
    'الإنسان',
    'المرسلات',
    'النبأ',
    'النازعات',
    'عبس',
    'التكوير',
    'الانفطار',
    'المطففين',
    'الانشقاق',
    'البروج',
    'الطارق',
    'الأعلى',
    'الغاشية',
    'الفجر',
    'البلد',
    'الشمس',
    'الليل',
    'الضحى',
    'الشرح',
    'التين',
    'العلق',
    'القدر',
    'البينة',
    'الزلزلة',
    'العاديات',
    'القارعة',
    'التكاثر',
    'العصر',
    'الهمزة',
    'الفيل',
    'قريش',
    'الماعون',
    'الكوثر',
    'الكافرون',
    'النصر',
    'المسد',
    'الإخلاص',
    'الفلق',
    'الناس',
  ];

  late MushafMode _mode;
  int _currentPage = 1; // Current page number
  late final PageController _pageController; // Controller for PageView
  final Map<int, int> _surahStartPage = {}; // Map surah number to first page

  bool _isDarkMode = false;
  bool _showBottomPanel = false;
  double _fontSize = 22;
  double _playbackSpeed = 1;
  bool _isLooping = false;
  bool _isMuted = false;

  bool _isLoadingData = true;
  String _errorLoading = '';
  final List<AyahModel> _ayahs = [];
  List<List<AyahModel>> _groupedByPage =
      []; // Each element is ayahs for one Quran page
  int _selectedAyahIndex = 0;
  bool _audioPrepared = false;

  late AudioPlayer _audioPlayer;
  bool _isPlayingAudio = false;
  Duration _audioPosition = Duration.zero;
  Duration _audioDuration = Duration.zero;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<PlayerState>? _playerStateSub;

  late AudioRecorder _audioRecorder;
  bool _isRecording = false;
  String? _recordedFilePath;
  int _recordDurationSeconds = 0;
  Timer? _recordTimer;
  bool _hasRecorded = false;
  bool _isPlayingRecording = false;
  late AudioPlayer _recordingPlayer;
  Duration _recordPosition = Duration.zero;
  Duration _recordDuration = Duration.zero;

  ReciterInfo _selectedReciter = _reciters.first;

  final List<TapGestureRecognizer> _ayahRecognizers = [];
  SurahMeta? _dynamicMeta;

  SurahMeta get _meta {
    if (_groupedByPage.isEmpty) {
      return _surahCatalog[1]!;
    }
    final currentPageAyahs =
        _groupedByPage[_pageController.hasClients
            ? _pageController.page?.round() ?? 0
            : 0];
    final firstAyah = currentPageAyahs.first;
    // Find surah number for this ayah
    int? currentSurahNumber;
    for (final entry in _surahStartPage.entries) {
      if (entry.value <= firstAyah.page) {
        currentSurahNumber = entry.key;
      }
    }
    currentSurahNumber ??= 1;
    return _surahCatalog[currentSurahNumber]!;
  }

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _pageController = PageController(
      initialPage: 0,
    ); // Page indices start at 0, pages start at 1
    _audioPlayer = AudioPlayer();
    _recordingPlayer = AudioPlayer();
    _audioRecorder = AudioRecorder();
    _setupAudioListeners();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _loadSurahData();
  }

  void _setupAudioListeners() {
    _positionSub = _audioPlayer.positionStream.listen((pos) {
      if (mounted) setState(() => _audioPosition = pos);
    });
    _durationSub = _audioPlayer.durationStream.listen((dur) {
      if (mounted) setState(() => _audioDuration = dur ?? Duration.zero);
    });
    _playerStateSub = _audioPlayer.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() => _isPlayingAudio = state.playing);
      if (state.processingState == ProcessingState.completed) {
        _onAyahCompleted();
      }
    });

    _recordingPlayer.positionStream.listen((pos) {
      if (mounted) setState(() => _recordPosition = pos);
    });
    _recordingPlayer.durationStream.listen((dur) {
      if (mounted) setState(() => _recordDuration = dur ?? Duration.zero);
    });
    _recordingPlayer.playerStateStream.listen((state) {
      if (mounted) setState(() => _isPlayingRecording = state.playing);
    });
  }

  Future<void> _loadSurahData() async {
    setState(() {
      _isLoadingData = true;
      _errorLoading = '';
      _selectedAyahIndex = 0;
      _audioPrepared = false;
    });

    const cacheKey = 'cached_entire_quran';
    const lastPageKey = 'last_mushaf_page';
    final prefs = await SharedPreferences.getInstance();
    String? responseBody;

    // Try to load from cache first
    if (prefs.containsKey(cacheKey)) {
      responseBody = prefs.getString(cacheKey);
    }

    // If no cache, fetch from API
    if (responseBody == null) {
      try {
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 30);
        final request = await client.getUrl(
          Uri.parse('https://api.alquran.cloud/v1/quran/quran-uthmani'),
        );
        final response = await request.close();

        if (response.statusCode == 200) {
          responseBody = await response.transform(utf8.decoder).join();
          await prefs.setString(cacheKey, responseBody);
        } else {
          throw HttpException('HTTP ${response.statusCode}');
        }
        client.close();
      } catch (e) {
        debugPrint('Quran API error: $e');
        if (mounted) {
          setState(() {
            _errorLoading = 'تعذر تحميل المصحف. يرجى المحاولة مجدداً.';
            _isLoadingData = false;
          });
        }
        return;
      }
    }

    _parseSurahResponse(responseBody);
    if (mounted) setState(() => _isLoadingData = false);

    // Navigate to correct page (يحترم isFreeMode + surah من الـ route)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      int targetPage;
      if (!widget.isFreeMode &&
          _surahStartPage.containsKey(widget.surahNumber)) {
        targetPage = _surahStartPage[widget.surahNumber]!;
      } else if (prefs.containsKey(lastPageKey)) {
        targetPage = prefs.getInt(lastPageKey) ?? 1;
      } else {
        targetPage = 1;
      }
      _jumpToPage(targetPage);
    });
  }

  Future<void> _saveLastPage(int page) async {
    const lastPageKey = 'last_mushaf_page';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(lastPageKey, page);
  }

  void _parseSurahResponse(String jsonBody) {
    final decoded = json.decode(jsonBody) as Map<String, dynamic>;
    final data = decoded['data'] as Map<String, dynamic>;
    final surahsList = data['surahs'] as List<dynamic>;

    // Clear previous data
    _ayahs.clear();
    _surahStartPage.clear();

    // Iterate all surahs
    for (final surahJson in surahsList) {
      final surahMap = surahJson as Map<String, dynamic>;
      final surahNum = surahMap['number'] as int;
      final ayahsList = surahMap['ayahs'] as List<dynamic>;

      // Process ayahs of this surah
      for (var i = 0; i < ayahsList.length; i++) {
        final ayahJson = ayahsList[i] as Map<String, dynamic>;
        final ayah = AyahModel.fromJson(ayahJson, surahNum);
        _ayahs.add(ayah);

        // Record start page of this surah
        if (i == 0) {
          _surahStartPage[surahNum] = ayah.page;
        }
      }
    }

    // Group ALL ayahs by page
    final Map<int, List<AyahModel>> pageMap = {};
    for (final ayah in _ayahs) {
      if (pageMap.containsKey(ayah.page)) {
        pageMap[ayah.page]!.add(ayah);
      } else {
        pageMap[ayah.page] = [ayah];
      }
    }

    // Convert to ordered list of pages (1-604)
    final sortedPages = pageMap.keys.toList()..sort();
    _groupedByPage = sortedPages.map((page) => pageMap[page]!).toList();

    // Set initial meta to first surah
    _dynamicMeta = SurahMeta(
      number: 1,
      name: _allSurahNames.first,
      juz: '',
      type: 'مكية',
      versesCount: 7,
    );

    _rebuildAyahRecognizers();
  }

  void _rebuildAyahRecognizers() {
    for (final r in _ayahRecognizers) {
      r.dispose();
    }
    _ayahRecognizers.clear();
    for (var i = 0; i < _ayahs.length; i++) {
      final recognizer = TapGestureRecognizer();
      final index = i;
      recognizer.onTap = () => _selectAyah(index);
      _ayahRecognizers.add(recognizer);
    }
  }

  String _getAyahDisplayText(AyahModel ayah) {
    if (ayah.numberInSurah != 1) {
      return ayah.text;
    }
    // Don't remove Bismillah from Surah Al-Fatiha!
    if (ayah.surahNumber == 1) {
      return ayah.text;
    }
    var text = ayah.text;
    debugPrint('=== Original Ayah Text (length:${text.length}): "$text" ===');

    // Build Bismillah from the EXACT character codes from your log!
    final bismillah = String.fromCharCodes([
      0x0628,
      0x0650,
      0x0633,
      0x0652,
      0x0645,
      0x0650,
      0x0020,
      0x0671,
      0x0644,
      0x0644,
      0x0651,
      0x064e,
      0x0647,
      0x0650,
      0x0020,
      0x0671,
      0x0644,
      0x0631,
      0x0651,
      0x064e,
      0x062d,
      0x0652,
      0x0645,
      0x064e,
      0x0670,
      0x0646,
      0x0650,
      0x0020,
      0x0671,
      0x0644,
      0x0631,
      0x0651,
      0x064e,
      0x062d,
      0x0650,
      0x064a,
      0x0645,
      0x0650,
    ]);

    debugPrint(
      '=== Built Bismillah (length:${bismillah.length}): "$bismillah" ===',
    );

    // Try to remove it
    if (text.startsWith(bismillah)) {
      text = text.substring(bismillah.length).trim();
      debugPrint('=== After Bismillah Removal: "$text" ===');
    } else {
      final trimmedText = text.trimLeft();
      if (trimmedText.startsWith(bismillah)) {
        text = trimmedText.substring(bismillah.length).trim();
        debugPrint('=== After Bismillah Removal (trimmed): "$text" ===');
      } else {
        debugPrint('=== Still no match! ===');
      }
    }
    return text;
  }

  void _jumpToPage(int pageNumber) {
    // Find page index in _groupedByPage
    final pageIndex = _groupedByPage.indexWhere(
      (page) => page.first.page == pageNumber,
    );
    if (pageIndex == -1) return;
    _pageController.jumpToPage(pageIndex);
  }

  void _jumpToSurah(int surahNumber) {
    final startPage = _surahStartPage[surahNumber];
    if (startPage == null) return;
    // Find page index in _groupedByPage
    final pageIndex = _groupedByPage.indexWhere(
      (page) => page.first.page == startPage,
    );
    if (pageIndex == -1) return;
    Navigator.pop(context);
    _pageController.animateToPage(
      pageIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _showSurahPicker() {
    final surfaceColor = _isDarkMode ? AppColors.darkCard : Colors.white;
    final textColor = _isDarkMode ? Colors.white : AppColors.textPrimary;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (context, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textHint.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(Icons.menu_book_rounded, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Text(
                    'اختر سورة',
                    style: TextStyle(
                      fontFamily: 'NotoNaskhArabic',
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: _surahCatalog.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final number = index + 1;
                  final surah = _surahCatalog[number]!;
                  return ListTile(
                    onTap: () => _jumpToSurah(number),
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          _toArabicDigits(number),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      surah.name,
                      style: TextStyle(
                        fontFamily: 'NotoNaskhArabic',
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    subtitle: Text(
                      surah.type,
                      style: const TextStyle(
                        fontFamily: 'NotoNaskhArabic',
                        fontSize: 12,
                        color: AppColors.textHint,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSurahActionsMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _isDarkMode ? AppColors.darkCard : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.favorite_border, color: AppColors.textHint),
              title: const Text(
                'إضافة للمفضلة',
                style: TextStyle(fontFamily: 'NotoNaskhArabic'),
              ),
              trailing: Text(
                'Coming Soon',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textHint,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.bookmark_border, color: AppColors.textHint),
              title: const Text(
                'حفظ إشارة مرجعية',
                style: TextStyle(fontFamily: 'NotoNaskhArabic'),
              ),
              trailing: Text(
                'Coming Soon',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textHint,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.share_outlined, color: AppColors.textHint),
              title: const Text(
                'مشاركة السورة',
                style: TextStyle(fontFamily: 'NotoNaskhArabic'),
              ),
              trailing: Text(
                'Coming Soon',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textHint,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.settings_outlined,
                color: AppColors.primary,
              ),
              title: const Text(
                'إعدادات القراءة',
                style: TextStyle(fontFamily: 'NotoNaskhArabic'),
              ),
              onTap: () {
                Navigator.pop(context);
                _showFontSizeSheet(
                  _isDarkMode ? AppColors.darkCard : Colors.white,
                  _isDarkMode ? Colors.white : AppColors.textPrimary,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _ensureNetworkForAudio() async {
    final connected = await sl<NetworkInfo>().isConnected;
    if (!connected && mounted) {
      AppSnackBar.showInfo(context, 'تشغيل الصوت يتطلب اتصالاً بالإنترنت');
    }
    return connected;
  }

  String _getAudioUrlForAyah(AyahModel ayah) {
    final surahStr = ayah.surahNumber.toString().padLeft(3, '0');
    final ayahStr = ayah.numberInSurah.toString().padLeft(3, '0');
    return 'https://everyayah.com/data/${_selectedReciter.subDirectory}/$surahStr$ayahStr.mp3';
  }

  Future<void> _prepareAudioForCurrentAyah() async {
    if (_ayahs.isEmpty) return;
    if (!await sl<NetworkInfo>().isConnected) return;
    final ayah = _ayahs[_selectedAyahIndex];
    final url = _getAudioUrlForAyah(ayah);
    try {
      await _audioPlayer.setSpeed(_playbackSpeed);
      await _audioPlayer.setVolume(_isMuted ? 0 : 1);
      await _audioPlayer.setUrl(url);
      if (mounted) setState(() => _audioPrepared = true);
    } catch (e) {
      debugPrint('Prepare audio error: $e');
    }
  }

  Future<void> _playCurrentAyah() async {
    if (_ayahs.isEmpty) return;
    if (!await _ensureNetworkForAudio()) return;

    try {
      if (!_audioPrepared ||
          _audioPlayer.processingState == ProcessingState.idle) {
        await _prepareAudioForCurrentAyah();
      }
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('Play audio error: $e');
      if (mounted) {
        AppSnackBar.showError(
          context,
          'تعذر تشغيل صوت الآية، تحقق من الاتصال بالإنترنت',
        );
      }
    }
  }

  void _onAyahCompleted() {
    if (_isLooping) {
      _playCurrentAyah();
    } else if (_selectedAyahIndex < _ayahs.length - 1) {
      setState(() {
        _selectedAyahIndex++;
        _audioPrepared = false;
      });
      _playCurrentAyah();
    } else {
      setState(() => _isPlayingAudio = false);
    }
  }

  void _selectAyah(int index) {
    setState(() {
      _selectedAyahIndex = index;
      _audioPrepared = false;
      _showBottomPanel = true;
    });
    _prepareAudioForCurrentAyah();
  }

  void _togglePlayPause() async {
    if (_isPlayingAudio) {
      await _audioPlayer.pause();
      return;
    }
    if (!_audioPrepared ||
        _audioPlayer.processingState == ProcessingState.idle) {
      await _playCurrentAyah();
    } else {
      if (!await _ensureNetworkForAudio()) return;
      await _audioPlayer.play();
    }
  }

  void _skipNext() {
    if (_selectedAyahIndex < _ayahs.length - 1) {
      setState(() {
        _selectedAyahIndex++;
        _audioPrepared = false;
      });
      _playCurrentAyah();
    }
  }

  void _skipPrevious() {
    if (_selectedAyahIndex > 0) {
      setState(() {
        _selectedAyahIndex--;
        _audioPrepared = false;
      });
      _playCurrentAyah();
    }
  }

  void _cyclePlaybackSpeed() {
    const speeds = [1.0, 1.25, 1.5, 2.0];
    final idx = speeds.indexOf(_playbackSpeed);
    final newSpeed = speeds[(idx + 1) % speeds.length];
    setState(() => _playbackSpeed = newSpeed);
    _audioPlayer.setSpeed(newSpeed);
  }

  void _onScreenTap() {
    setState(() => _showBottomPanel = !_showBottomPanel);
  }

  void _onReciterSelected(ReciterInfo reciter) {
    setState(() {
      _selectedReciter = reciter;
      _audioPrepared = false;
    });
    if (_isPlayingAudio) {
      _playCurrentAyah();
    } else {
      _prepareAudioForCurrentAyah();
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final tempDir = await getTemporaryDirectory();
        final currentAyah = _ayahs[_selectedAyahIndex];
        final path =
            '${tempDir.path}/recitation_${currentAyah.surahNumber}_${_selectedAyahIndex + 1}_${DateTime.now().millisecondsSinceEpoch}.m4a';

        setState(() {
          _recordedFilePath = path;
          _isRecording = true;
          _recordDurationSeconds = 0;
          _hasRecorded = false;
        });

        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );

        _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) {
            setState(() => _recordDurationSeconds++);
          }
        });
      }
    } catch (e) {
      debugPrint('Recording start error: $e');
      if (mounted) {
        AppSnackBar.showError(context, 'فشل بدء تسجيل الصوت');
      }
    }
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    final path = await _audioRecorder.stop();
    setState(() {
      _isRecording = false;
      _recordedFilePath = path;
      _hasRecorded = path != null;
    });
    if (path != null) {
      await _recordingPlayer.setFilePath(path);
    }
  }

  void _togglePlayRecording() {
    if (_isPlayingRecording) {
      _recordingPlayer.pause();
    } else {
      _recordingPlayer.play();
    }
  }

  void _submitRecitation() {
    if (_recordedFilePath == null) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إرسال التسميع', textAlign: TextAlign.right),
        content: const Text(
          'رفع التسجيل غير متاح حالياً حتى يتم تفعيل خدمة رفع الملفات.',
          textAlign: TextAlign.right,
          style: TextStyle(fontFamily: 'NotoNaskhArabic'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(duration.inMinutes)}:${twoDigits(duration.inSeconds.remainder(60))}';
  }

  String _formatRecordTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _toArabicDigits(int n) {
    const digits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return n.toString().split('').map((c) => digits[int.parse(c)]).join();
  }

  String _inlineVerseMarker(int n) => '\uFD3F${_toArabicDigits(n)}\uFD3E';

  @override
  void dispose() {
    _pageController.dispose();
    for (final r in _ayahRecognizers) {
      r.dispose();
    }
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playerStateSub?.cancel();
    _audioPlayer.dispose();
    _recordingPlayer.dispose();
    _audioRecorder.dispose();
    _recordTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = _isDarkMode ? AppColors.darkCard : Colors.white;
    final textColor = _isDarkMode ? Colors.white : AppColors.textPrimary;
    final iconColor = _isDarkMode ? Colors.white70 : AppColors.textSecondary;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: surfaceColor,
        appBar: AppBar(
          backgroundColor: _isDarkMode ? AppColors.darkCard : AppColors.primary,
          elevation: 0,
          leading: Navigator.canPop(context)
              ? IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                )
              : null,
          title: Text(
            '${_meta.name} - صفحة ${_toArabicDigits(_currentPage)}',
            style: GoogleFonts.amiri(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.menu_book_rounded, color: Colors.white),
              onPressed: _showSurahPicker,
            ),
            IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onPressed: _showSurahActionsMenu,
            ),
            IconButton(
              icon: Icon(
                _isDarkMode
                    ? Icons.wb_sunny_outlined
                    : Icons.nightlight_round_outlined,
                color: Colors.white,
              ),
              onPressed: () => setState(() => _isDarkMode = !_isDarkMode),
            ),
          ],
        ),
        body: Column(
          children: [
            _ModeSelector(
              mode: _mode,
              isDarkMode: _isDarkMode,
              onReadingTap: () => setState(() => _mode = MushafMode.reading),
              onRecitationTap: () {
                debugPrint('Recitation tapped! Navigating...');
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StudentRecitationPage(
                      surahName: _meta.name,
                      pageNumber: _currentPage,
                    ),
                  ),
                );
              },
            ),
            Expanded(
              child: GestureDetector(
                onTap: _onScreenTap,
                behavior: HitTestBehavior.translucent,
                child: _buildAyahsBody(textColor, iconColor),
              ),
            ),
            if (_showBottomPanel)
              AnimatedSlide(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOut,
                offset: Offset.zero,
                child: _mode == MushafMode.recitation
                    ? _buildRecordingPanel(surfaceColor, textColor)
                    : _buildPlaybackPanel(surfaceColor, textColor, iconColor),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAyahsBody(Color textColor, Color iconColor) {
    if (_isLoadingData) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_errorLoading.isNotEmpty && _ayahs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 48, color: iconColor),
              const SizedBox(height: 12),
              Text(
                _errorLoading,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'NotoNaskhArabic',
                  color: iconColor,
                ),
              ),
              const SizedBox(height: 16),
              AppButton(label: 'إعادة المحاولة', onPressed: _loadSurahData),
            ],
          ),
        ),
      );
    }

    if (_groupedByPage.isEmpty) {
      return const SizedBox.shrink();
    }

    return PageView.builder(
      controller: _pageController,
      physics: const PageScrollPhysics(),
      // Real page turning feel
      itemCount: _groupedByPage.length,
      onPageChanged: (pageIndex) {
        final pageNumber = _groupedByPage[pageIndex].first.page;
        setState(() {
          _currentPage = pageNumber;
        });
        _saveLastPage(pageNumber);
      },
      itemBuilder: (context, pageIndex) {
        final pageAyahs = _groupedByPage[pageIndex];
        final pageNumber = pageAyahs.first.page;
        return _MushafPageFrame(
          isDarkMode: _isDarkMode,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Ayahs
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: _buildMushafFlowText(textColor, pageAyahs),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMushafFlowText(Color textColor, List<AyahModel> pageAyahs) {
    final highlightBg = _isDarkMode
        ? AppColors.primary.withOpacity(0.22)
        : const Color(0xFFE8F5E9);

    final baseStyle = GoogleFonts.amiri(
      fontSize: _fontSize,
      height: 1.6,
      letterSpacing: 0,
      color: textColor,
      fontWeight: FontWeight.w500,
    );

    final children = <Widget>[];
    final allSpans = <InlineSpan>[];

    for (final ayah in pageAyahs) {
      // If this is the first ayah of a surah, add surah header and maybe Bismillah
      if (ayah.numberInSurah == 1) {
        // First, add any previous spans as a RichText
        if (allSpans.isNotEmpty) {
          children.add(
            RichText(
              text: TextSpan(style: baseStyle, children: List.from(allSpans)),
              textAlign: TextAlign.justify,
              textDirection: TextDirection.rtl,
              textHeightBehavior: const TextHeightBehavior(
                applyHeightToFirstAscent: false,
                applyHeightToLastDescent: false,
              ),
            ),
          );
          allSpans.clear();
        }

        final surahNum = ayah.surahNumber;
        final surahName = _allSurahNames[surahNum - 1];
        final surahMeta = _surahCatalog[surahNum]!;
        children.add(
          _TraditionalSurahHeader(
            surahName: surahName,
            surahNumber: surahNum,
            surahType: surahMeta.type,
            isDarkMode: _isDarkMode,
          ),
        );

        // Show standalone Bismillah if not surah 1 or 9
        if (surahNum != 1 && surahNum != 9) {
          children.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _bismillahText,
                textAlign: TextAlign.center,
                style: GoogleFonts.amiri(
                  fontSize: _fontSize,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A5C4B),
                  height: 1.8,
                ),
              ),
            ),
          );
        }
      }

      // Build the ayah text
      final originalIndex = _ayahs.indexWhere((a) => a.number == ayah.number);
      final isSelected = originalIndex == _selectedAyahIndex;
      final displayText = _getAyahDisplayText(ayah);

      allSpans.add(
        TextSpan(
          text: ' $displayText ',
          style: baseStyle.copyWith(
            color: isSelected ? const Color(0xFF1A5C4B) : textColor,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            backgroundColor: isSelected ? highlightBg : null,
          ),
          recognizer: _ayahRecognizers.length > originalIndex
              ? _ayahRecognizers[originalIndex]
              : null,
        ),
      );
      allSpans.add(
        TextSpan(
          text: _inlineVerseMarker(ayah.numberInSurah),
          style: baseStyle.copyWith(
            fontSize: _fontSize * 0.72,
            color: isSelected ? AppColors.primary : const Color(0xFF3D8B7A),
            fontWeight: FontWeight.bold,
            backgroundColor: isSelected ? highlightBg : null,
          ),
          recognizer: _ayahRecognizers.length > originalIndex
              ? _ayahRecognizers[originalIndex]
              : null,
        ),
      );
    }

    // Add remaining spans
    if (allSpans.isNotEmpty) {
      children.add(
        RichText(
          text: TextSpan(style: baseStyle, children: List.from(allSpans)),
          textAlign: TextAlign.justify,
          textDirection: TextDirection.rtl,
          textHeightBehavior: const TextHeightBehavior(
            applyHeightToFirstAscent: false,
            applyHeightToLastDescent: false,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget _buildPlaybackPanel(
    Color surfaceColor,
    Color textColor,
    Color iconColor,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _reciters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final reciter = _reciters[index];
                  final selected = reciter.id == _selectedReciter.id;
                  return GestureDetector(
                    onTap: () => _onReciterSelected(reciter),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary
                            : (_isDarkMode
                                  ? Colors.white10
                                  : AppColors.surfaceGrey),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        reciter.name,
                        style: TextStyle(
                          fontFamily: 'NotoNaskhArabic',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: selected ? Colors.white : textColor,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  _formatDuration(_audioPosition),
                  style: TextStyle(fontSize: 11, color: iconColor),
                ),
                Expanded(
                  child: Slider(
                    activeColor: AppColors.primary,
                    inactiveColor: _isDarkMode
                        ? Colors.white10
                        : Colors.black.withOpacity(0.06),
                    value: _audioPosition.inMilliseconds
                        .clamp(
                          0,
                          _audioDuration.inMilliseconds > 0
                              ? _audioDuration.inMilliseconds
                              : 1,
                        )
                        .toDouble(),
                    max: _audioDuration.inMilliseconds > 0
                        ? _audioDuration.inMilliseconds.toDouble()
                        : 1,
                    onChanged: (val) {
                      _audioPlayer.seek(Duration(milliseconds: val.toInt()));
                    },
                  ),
                ),
                Text(
                  _formatDuration(_audioDuration),
                  style: TextStyle(fontSize: 11, color: iconColor),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(
                    _isLooping ? Icons.repeat_one : Icons.repeat,
                    color: _isLooping ? AppColors.primary : iconColor,
                  ),
                  onPressed: () => setState(() => _isLooping = !_isLooping),
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next),
                  color: textColor,
                  iconSize: 28,
                  onPressed: _skipPrevious,
                ),
                Container(
                  width: 58,
                  height: 58,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      _isPlayingAudio ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                    ),
                    iconSize: 32,
                    onPressed: _togglePlayPause,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.skip_previous),
                  color: textColor,
                  iconSize: 28,
                  onPressed: _skipNext,
                ),
                IconButton(
                  icon: Icon(
                    _isMuted ? Icons.volume_off : Icons.volume_up,
                    color: _isMuted ? AppColors.error : iconColor,
                  ),
                  onPressed: () {
                    setState(() => _isMuted = !_isMuted);
                    _audioPlayer.setVolume(_isMuted ? 0 : 1);
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _OptionTextButton(
                  icon: Icons.repeat,
                  label:
                      'x${_playbackSpeed == 1 ? 1 : _playbackSpeed.toString().replaceAll('.0', '')}',
                  onTap: _cyclePlaybackSpeed,
                ),
                const SizedBox(width: 24),
                _OptionTextButton(
                  icon: Icons.text_fields,
                  label: 'حجم الخط',
                  onTap: () => _showFontSizeSheet(surfaceColor, textColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showFontSizeSheet(Color surfaceColor, Color textColor) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'حجم خط المصحف',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'NotoNaskhArabic',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(Icons.font_download_outlined, size: 14),
                  Expanded(
                    child: Slider(
                      activeColor: AppColors.primary,
                      value: _fontSize,
                      min: 16,
                      max: 36,
                      onChanged: (val) {
                        setModalState(() => _fontSize = val);
                        setState(() => _fontSize = val);
                      },
                    ),
                  ),
                  const Icon(Icons.font_download, size: 24),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecordingPanel(Color surfaceColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'وضع التسميع — ${_meta.name} · الآية ${_selectedAyahIndex + 1}',
              style: const TextStyle(
                fontFamily: 'NotoNaskhArabic',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            if (_isRecording) ...[
              const Text(
                'جاري تسجيل صوتك الآن...',
                style: TextStyle(
                  color: AppColors.error,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _formatRecordTime(_recordDurationSeconds),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _stopRecording,
                child: Container(
                  width: 74,
                  height: 74,
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.stop, color: Colors.white, size: 36),
                ),
              ),
            ] else if (_hasRecorded) ...[
              const Text(
                'تلاوتك المسجلة:',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _isPlayingRecording ? Icons.pause : Icons.play_arrow,
                    ),
                    onPressed: _togglePlayRecording,
                  ),
                  Expanded(
                    child: Slider(
                      activeColor: AppColors.primary,
                      value: _recordPosition.inMilliseconds
                          .clamp(
                            0,
                            _recordDuration.inMilliseconds > 0
                                ? _recordDuration.inMilliseconds
                                : 1,
                          )
                          .toDouble(),
                      max: _recordDuration.inMilliseconds > 0
                          ? _recordDuration.inMilliseconds.toDouble()
                          : 1,
                      onChanged: (val) {
                        _recordingPlayer.seek(
                          Duration(milliseconds: val.toInt()),
                        );
                      },
                    ),
                  ),
                  Text(
                    _formatDuration(_recordDuration),
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'إرسال التسميع للمعلمة',
                      onPressed: _submitRecitation,
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 16,
                      ),
                    ),
                    onPressed: _startRecording,
                    child: const Text(
                      'إعادة التسجيل',
                      style: TextStyle(fontFamily: 'NotoNaskhArabic'),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const Text(
                'انقر للبدء بتسجيل تلاوتك للآية المحددة:',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _startRecording,
                child: Container(
                  width: 74,
                  height: 74,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mic, color: Colors.white, size: 36),
                ),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  final MushafMode mode;
  final bool isDarkMode;
  final VoidCallback onReadingTap;
  final VoidCallback onRecitationTap;

  const _ModeSelector({
    required this.mode,
    required this.isDarkMode,
    required this.onReadingTap,
    required this.onRecitationTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDarkMode ? AppColors.darkCard : AppColors.primary;
    return Container(
      color: bg,
      padding: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            _ModeTabButton(
              label: 'قراءة',
              icon: Icons.menu_book_outlined,
              selected: mode == MushafMode.reading,
              onTap: onReadingTap,
            ),
            _ModeTabButton(
              label: 'تسميع',
              icon: Icons.mic_none_rounded,
              selected: mode == MushafMode.recitation,
              onTap: onRecitationTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeTabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ModeTabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? AppColors.primary : Colors.white,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'NotoNaskhArabic',
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                  color: selected ? AppColors.primary : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SurahHeader extends StatelessWidget {
  final SurahMeta meta;
  final bool isDarkMode;
  final String Function(int) toArabicDigits;
  final VoidCallback onMoreTap;

  const _SurahHeader({
    required this.meta,
    required this.isDarkMode,
    required this.toArabicDigits,
    required this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    final headerBg = isDarkMode ? AppColors.darkCard : const Color(0xFFF2E8C9);
    final primaryTextColor = isDarkMode ? Colors.white : AppColors.textPrimary;
    final secondaryTextColor = isDarkMode
        ? Colors.white60
        : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: headerBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDarkMode ? Colors.white10 : const Color(0xFFE2D6AC),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (meta.juz.isNotEmpty)
                  Text(
                    meta.juz,
                    style: TextStyle(fontSize: 11, color: secondaryTextColor),
                  ),
                const SizedBox(height: 2),
                Text(
                  'سورة ${meta.name}',
                  style: GoogleFonts.amiri(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: primaryTextColor,
                  ),
                ),
                Text(
                  meta.type.isNotEmpty
                      ? '${meta.type} · ${toArabicDigits(meta.versesCount)} آية'
                      : '${toArabicDigits(meta.versesCount)} آية',
                  style: TextStyle(fontSize: 11, color: secondaryTextColor),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onMoreTap,
            icon: Icon(Icons.more_horiz_rounded, color: secondaryTextColor),
            tooltip: 'المزيد',
          ),
        ],
      ),
    );
  }
}

class _FreeMushafSurahBar extends StatelessWidget {
  final int selectedSurah;
  final bool isDarkMode;
  final ScrollController scrollController;
  final ValueChanged<int> onSurahSelected;

  const _FreeMushafSurahBar({
    required this.selectedSurah,
    required this.isDarkMode,
    required this.scrollController,
    required this.onSurahSelected,
  });

  static const List<String> _names = _StudentMushafPageState._allSurahNames;

  @override
  Widget build(BuildContext context) {
    final bg = isDarkMode ? AppColors.darkCard : const Color(0xFF1A3D36);

    return Container(
      color: bg,
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: SizedBox(
        height: 44,
        child: ListView.separated(
          controller: scrollController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: _names.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (context, index) {
            final number = index + 1;
            final selected = number == selectedSurah;
            return GestureDetector(
              onTap: () => onSurahSelected(number),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary
                      : Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected
                        ? AppColors.primary
                        : Colors.white.withOpacity(0.2),
                  ),
                ),
                child: Text(
                  _names[index],
                  style: TextStyle(
                    fontFamily: 'NotoNaskhArabic',
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                    color: Colors.white.withOpacity(selected ? 1 : 0.85),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MushafPageFrame extends StatelessWidget {
  final bool isDarkMode;
  final Widget child;

  const _MushafPageFrame({required this.isDarkMode, required this.child});

  @override
  Widget build(BuildContext context) {
    final pageColor = isDarkMode
        ? const Color(0xFF2A2A2A)
        : const Color(0xFFF5F0E1); // Traditional Mushaf paper color
    final borderColor = isDarkMode
        ? Colors.white24
        : const Color(0xFF2D6B4F).withOpacity(0.6);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: pageColor,
        border: Border.all(color: borderColor, width: 2.5),
        // Ornate border all around
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _OrnateSurahBanner extends StatelessWidget {
  final String name;
  final int verseCount;
  final String Function(int) toArabicDigits;

  const _OrnateSurahBanner({
    required this.name,
    required this.verseCount,
    required this.toArabicDigits,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFD4AF37), // Gold color
            Color(0xFFB8954F),
            Color(0xFFD4AF37),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF8B6914), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB8954F).withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Decorative elements
          Positioned(
            left: 0,
            right: 0,
            top: 6,
            child: Container(height: 2, color: const Color(0xFF8B6914)),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 6,
            child: Container(height: 2, color: const Color(0xFF8B6914)),
          ),
          // Surah name
          Text(
            '﷽ سورة $name ﷽',
            textAlign: TextAlign.center,
            style: GoogleFonts.amiri(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF3D2E10),
              height: 1.4,
            ),
          ),
          // Side decorations
          Positioned(
            left: 12,
            child: _BannerDot(label: toArabicDigits(verseCount)),
          ),
          Positioned(
            right: 12,
            child: _BannerDot(label: toArabicDigits(verseCount)),
          ),
        ],
      ),
    );
  }
}

class _BannerDot extends StatelessWidget {
  final String label;

  const _BannerDot({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFFAF6EB),
        border: Border.all(color: const Color(0xFFB8954F)),
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: Color(0xFF3D2E10),
          ),
        ),
      ),
    );
  }
}

class _TraditionalSurahHeader extends StatelessWidget {
  final String surahName;
  final int surahNumber;
  final String surahType;
  final bool isDarkMode;

  const _TraditionalSurahHeader({
    required this.surahName,
    required this.surahNumber,
    required this.surahType,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDarkMode ? Colors.white : const Color(0xFF1A5C4B);
    final borderColor = isDarkMode ? Colors.white38 : const Color(0xFF2D6B4F);
    final bgColor = isDarkMode
        ? const Color(0xFF3A3A3A)
        : const Color(0xFFFFF8E1);

    String toArabicDigits(int n) {
      const digits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
      return n.toString().split('').map((c) => digits[int.parse(c)]).join();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Column(
          children: [
            const SizedBox(height: 4),
            Text(
              'سورة $surahName',
              style: GoogleFonts.amiri(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${toArabicDigits(surahNumber)} - $surahType',
              style: GoogleFonts.amiri(
                fontSize: 16,
                color: textColor.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionTextButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _OptionTextButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'NotoNaskhArabic',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
