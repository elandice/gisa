import 'dart:collection';

class StudyCategory {
  const StudyCategory(
    this.id,
    this.name,
    this.subtitle,
    this.assetFile,
    this.expectedCount,
  );

  final String id;
  final String name;
  final String subtitle;
  final String assetFile;
  final int expectedCount;

  String get title => name;
}

const categories = <StudyCategory>[
  StudyCategory('keyword', '키워드 찾기', '핵심 개념과 용어', 'keywords', 130),
  StudyCategory('sql', 'SQL', '데이터베이스 질의', 'sql', 17),
  StudyCategory('control', '제어문', 'C · 반복과 분기', 'control', 14),
  StudyCategory('pointer', '포인터', 'C · 주소와 메모리', 'pointers', 5),
  StudyCategory('struct', '구조체', 'C · 복합 자료형', 'structs', 3),
  StudyCategory('function', '사용자 정의 함수', 'C · 함수 실행 흐름', 'functions', 9),
  StudyCategory('java', 'JAVA 활용', '객체와 실행 결과', 'java', 9),
  StudyCategory('python', 'Python 활용', '자료형과 실행 결과', 'python', 6),
];

StudyCategory categoryById(String id) => categories.firstWhere(
  (category) => category.id == id,
  orElse: () => throw ArgumentError.value(id, 'id', '알 수 없는 학습 분류'),
);

/// Normalizes case-insensitive keyword and SQL-token typing variations.
/// Program output and source-code answers must use [normalizeProgramAnswer].
String normalizeAnswer(String value) {
  final fullWidthNormalized = String.fromCharCodes(
    value.runes.map((rune) {
      if (rune >= 0xff01 && rune <= 0xff5e) return rune - 0xfee0;
      if (rune == 0x3000 || rune == 0xa0) return 0x20;
      return rune;
    }),
  );
  return fullWidthNormalized
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAllMapped(
        RegExp(r'\s*([,;:()\[\]{}=+*/<>])\s*'),
        (match) => match[1]!,
      );
}

/// Keeps output case, punctuation, spaces and line boundaries significant.
/// The answer sheets omit final newlines and trailing spaces from print loops,
/// so those and whitespace outside the complete response are harmless.
String normalizeProgramAnswer(String value) => value
    .replaceAll('\r\n', '\n')
    .replaceAll('\r', '\n')
    .trim()
    .split('\n')
    .map((line) => line.replaceFirst(RegExp(r'[ \t]+$'), ''))
    .join('\n');

String _readId(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty || value.trim() != value) {
    throw FormatException('유효하지 않은 식별자: $key');
  }
  return value;
}

int _readPositiveInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int || value <= 0) {
    throw FormatException('양의 정수가 필요한 항목: $key');
  }
  return value;
}

/// DateTime.parse accepts overflowing calendar dates (for example February 30).
/// Reject those instead of silently moving saved answers to a different day.
DateTime _readDateTime(Map<String, dynamic> json, String key) {
  final value = json[key];
  final components = value is String
      ? RegExp(
          r'^([+-]?\d{4,6})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})'
          r'(?:\.\d{1,6})?(?:Z|[+-](\d{2}):(\d{2}))?$',
        ).firstMatch(value)
      : null;
  if (components == null) {
    throw FormatException('유효하지 않은 시각: $key');
  }
  final year = int.parse(components[1]!);
  final month = int.parse(components[2]!);
  final day = int.parse(components[3]!);
  final hour = int.parse(components[4]!);
  final minute = int.parse(components[5]!);
  final second = int.parse(components[6]!);
  final offsetHour = int.parse(components[7] ?? '0');
  final offsetMinute = int.parse(components[8] ?? '0');
  final leapYear = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);
  final monthDays = [
    31,
    leapYear ? 29 : 28,
    31,
    30,
    31,
    30,
    31,
    31,
    30,
    31,
    30,
    31,
  ];
  if (month < 1 ||
      month > 12 ||
      day < 1 ||
      day > monthDays[month - 1] ||
      hour > 23 ||
      minute > 59 ||
      second > 59 ||
      offsetHour > 23 ||
      offsetMinute > 59) {
    throw FormatException('유효하지 않은 시각: $key');
  }
  final parsed = DateTime.tryParse(value as String);
  if (parsed == null) throw FormatException('유효하지 않은 시각: $key');
  return parsed;
}

class Question {
  const Question({
    required this.id,
    required this.categoryId,
    required this.number,
    required this.title,
    required this.prompt,
    required this.answer,
    required this.explanation,
    this.code,
    this.aliases = const [],
    this.grading = 'exact',
    this.source = '',
    this.sourcePages = const [],
    this.promptAsset,
  });

  final String id;
  final String categoryId;
  final int number;
  final String title;
  final String prompt;
  final String? code;
  final String answer;
  final String explanation;
  final List<String> aliases;
  final String grading;
  final String source;
  final List<int> sourcePages;
  final String? promptAsset;

  bool get isManual => grading == 'manual';
  StudyCategory get category => categoryById(categoryId);

  /// Descriptive answers deliberately require the learner's explicit judgment.
  bool? grade(String response) {
    if (isManual) return null;
    final normalize = categoryId == 'keyword' || categoryId == 'sql'
        ? normalizeAnswer
        : normalizeProgramAnswer;
    final normalized = normalize(response);
    if (normalized.isEmpty) return false;
    return [
      answer,
      ...aliases,
    ].any((accepted) => normalize(accepted) == normalized);
  }

  factory Question.fromJson(Map<String, dynamic> json) {
    final grading = json['grading'] as String? ?? 'exact';
    if (grading != 'exact' && grading != 'manual') {
      throw const FormatException('지원하지 않는 채점 방식');
    }
    final categoryId = json['categoryId'] as String;
    categoryById(categoryId);
    return Question(
      id: _readId(json, 'id'),
      categoryId: categoryId,
      number: _readPositiveInt(json, 'number'),
      title: json['title'] as String,
      prompt: json['prompt'] as String,
      code: json['code'] as String?,
      answer: json['answer'] as String,
      explanation: json['explanation'] as String,
      aliases: List<String>.from(json['aliases'] as List? ?? const []),
      grading: grading,
      source: json['source'] as String? ?? '',
      sourcePages: List<int>.from(json['sourcePages'] as List? ?? const []),
      promptAsset: json['promptAsset'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'categoryId': categoryId,
    'number': number,
    'title': title,
    'prompt': prompt,
    if (code != null) 'code': code,
    'answer': answer,
    'explanation': explanation,
    'aliases': aliases,
    'grading': grading,
    'source': source,
    'sourcePages': sourcePages,
    if (promptAsset != null) 'promptAsset': promptAsset,
  };
}

class WrongAnswer {
  const WrongAnswer({
    required this.questionId,
    required this.userAnswer,
    required this.lastAttemptAt,
    this.count = 1,
    this.memo = '',
    this.resolved = false,
  });

  final String questionId;
  final String userAnswer;
  final DateTime lastAttemptAt;
  final int count;
  final String memo;
  final bool resolved;

  int get wrongCount => count;

  WrongAnswer copyWith({
    String? userAnswer,
    DateTime? lastAttemptAt,
    int? count,
    String? memo,
    bool? resolved,
  }) => WrongAnswer(
    questionId: questionId,
    userAnswer: userAnswer ?? this.userAnswer,
    lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
    count: count ?? this.count,
    memo: memo ?? this.memo,
    resolved: resolved ?? this.resolved,
  );

  factory WrongAnswer.fromJson(Map<String, dynamic> json) => WrongAnswer(
    questionId: _readId(json, 'questionId'),
    userAnswer: json['userAnswer'] as String,
    lastAttemptAt: _readDateTime(json, 'lastAttemptAt'),
    count: _readPositiveInt(json, 'count'),
    memo: json['memo'] as String? ?? '',
    resolved: json['resolved'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'questionId': questionId,
    'userAnswer': userAnswer,
    'lastAttemptAt': lastAttemptAt.toIso8601String(),
    'count': count,
    'memo': memo,
    'resolved': resolved,
  };
}

class QuestionResult {
  const QuestionResult({
    required this.questionId,
    required this.userAnswer,
    required this.isCorrect,
    required this.answeredAt,
  });

  final String questionId;
  final String userAnswer;
  final bool? isCorrect;
  final DateTime answeredAt;

  bool? get correct => isCorrect;

  bool get pendingManual => isCorrect == null;

  QuestionResult withGrade(bool correct) => QuestionResult(
    questionId: questionId,
    userAnswer: userAnswer,
    isCorrect: correct,
    answeredAt: answeredAt,
  );

  factory QuestionResult.fromJson(Map<String, dynamic> json) => QuestionResult(
    questionId: _readId(json, 'questionId'),
    userAnswer: json['userAnswer'] as String,
    isCorrect: json['isCorrect'] as bool?,
    answeredAt: _readDateTime(json, 'answeredAt'),
  );

  Map<String, dynamic> toJson() => {
    'questionId': questionId,
    'userAnswer': userAnswer,
    'isCorrect': isCorrect,
    'answeredAt': answeredAt.toIso8601String(),
  };
}

class ExamSession {
  ExamSession({
    required this.id,
    required List<Question> questions,
    required this.startedAt,
    required this.durationMinutes,
    Map<String, QuestionResult> answers = const {},
    this.finishedAt,
  }) : questions = List.unmodifiable(questions),
       _answers = Map.of(answers);

  final String id;
  final List<Question> questions;
  final DateTime startedAt;
  final int durationMinutes;
  final Map<String, QuestionResult> _answers;
  DateTime? finishedAt;

  UnmodifiableMapView<String, QuestionResult> get answerResults =>
      UnmodifiableMapView(_answers);
  Map<String, String> get answers => Map.unmodifiable({
    for (final result in _answers.values) result.questionId: result.userAnswer,
  });
  Map<String, bool> get manualGrades => Map.unmodifiable({
    for (final result in _answers.values)
      if (result.isCorrect != null &&
          questions.any((q) => q.id == result.questionId && q.isManual))
        result.questionId: result.isCorrect!,
  });
  bool get isFinished => finishedAt != null;
  int get answeredCount => _answers.length;
  int get pendingCount => _answers.values.where((a) => a.pendingManual).length;

  DateTime get deadline => startedAt.add(Duration(minutes: durationMinutes));
  int get remainingSeconds => remainingSecondsAt(DateTime.now());
  int remainingSecondsAt(DateTime now) {
    final microseconds = remainingAt(now).inMicroseconds;
    return (microseconds + Duration.microsecondsPerSecond - 1) ~/
        Duration.microsecondsPerSecond;
  }

  Duration remainingAt(DateTime now) {
    if (isFinished) return Duration.zero;
    if (now.isBefore(startedAt)) return Duration(minutes: durationMinutes);
    final remaining = deadline.difference(now);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  void setAnswer(QuestionResult result) {
    if (isFinished) throw StateError('제출한 시험의 답안은 수정할 수 없습니다.');
    if (!questions.any((question) => question.id == result.questionId)) {
      throw ArgumentError.value(
        result.questionId,
        'questionId',
        '출제하지 않은 문제입니다.',
      );
    }
    if (result.answeredAt.isBefore(startedAt) ||
        result.answeredAt.isAfter(deadline)) {
      throw ArgumentError.value(
        result.answeredAt,
        'answeredAt',
        '시험 시간 밖의 답안입니다.',
      );
    }
    _answers[result.questionId] = result;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'questionIds': questions.map((q) => q.id).toList(),
    'startedAt': startedAt.toIso8601String(),
    'durationMinutes': durationMinutes,
    'answers': _answers.values.map((a) => a.toJson()).toList(),
    'finishedAt': finishedAt?.toIso8601String(),
  };

  factory ExamSession.fromJson(
    Map<String, dynamic> json,
    Map<String, Question> questions,
  ) {
    final ids = List<String>.from(json['questionIds'] as List);
    if (ids.isEmpty || ids.toSet().length != ids.length) {
      throw const FormatException('시험 문제는 비어 있거나 중복될 수 없습니다.');
    }
    if (ids.any(
      (id) => !questions.containsKey(id) || questions[id]!.id != id,
    )) {
      throw const FormatException('시험 문제를 찾을 수 없습니다.');
    }
    final answers = (json['answers'] as List)
        .map(
          (answer) =>
              QuestionResult.fromJson(Map<String, dynamic>.from(answer as Map)),
        )
        .toList();
    if (answers.map((answer) => answer.questionId).toSet().length !=
            answers.length ||
        answers.any((answer) => !ids.contains(answer.questionId))) {
      throw const FormatException('시험 답안이 중복되었거나 출제 문제와 일치하지 않습니다.');
    }
    final startedAt = _readDateTime(json, 'startedAt');
    final durationMinutes = _readPositiveInt(json, 'durationMinutes');
    final duration = Duration(minutes: durationMinutes);
    if (duration.inMinutes != durationMinutes) {
      throw const FormatException('유효하지 않은 시험 시간');
    }
    DateTime deadline;
    try {
      deadline = startedAt.add(duration);
    } on ArgumentError {
      throw const FormatException('유효하지 않은 시험 시간');
    }
    if (!deadline.isAfter(startedAt)) {
      throw const FormatException('유효하지 않은 시험 시간');
    }
    final finishedAt = json['finishedAt'] == null
        ? null
        : _readDateTime(json, 'finishedAt');
    if (finishedAt != null &&
        (finishedAt.isBefore(startedAt) || finishedAt.isAfter(deadline))) {
      throw const FormatException('시험 종료 시각이 시험 시간 밖에 있습니다.');
    }
    final lastAnswerAt = finishedAt ?? deadline;
    if (answers.any(
      (answer) =>
          answer.answeredAt.isBefore(startedAt) ||
          answer.answeredAt.isAfter(lastAnswerAt) ||
          (!questions[answer.questionId]!.isManual && answer.pendingManual),
    )) {
      throw const FormatException('시험 답안의 시각 또는 채점 상태가 유효하지 않습니다.');
    }
    return ExamSession(
      id: _readId(json, 'id'),
      questions: ids.map((id) => questions[id]!).toList(),
      startedAt: startedAt,
      durationMinutes: durationMinutes,
      answers: {for (final answer in answers) answer.questionId: answer},
      finishedAt: finishedAt,
    );
  }
}

class ExamResult {
  ExamResult({
    required this.id,
    required this.startedAt,
    required this.finishedAt,
    required List<QuestionResult> results,
  }) : results = List.unmodifiable(results);

  final String id;
  final DateTime startedAt;
  final DateTime finishedAt;
  final List<QuestionResult> results;

  List<QuestionResult> get questionResults => results;
  int get total => questionCount;

  int get questionCount => results.length;
  int get correctCount =>
      results.where((result) => result.isCorrect == true).length;
  int get incorrectCount =>
      results.where((result) => result.isCorrect == false).length;
  int get pendingCount =>
      results.where((result) => result.pendingManual).length;
  bool get fullyGraded => pendingCount == 0;
  double get score =>
      questionCount == 0 ? 0 : correctCount / questionCount * 100;
  Duration get duration => finishedAt.difference(startedAt);
  int get durationSeconds => duration.inSeconds;

  ExamResult withGrade(String questionId, bool correct) => ExamResult(
    id: id,
    startedAt: startedAt,
    finishedAt: finishedAt,
    results: results
        .map(
          (result) => result.questionId == questionId
              ? result.withGrade(correct)
              : result,
        )
        .toList(),
  );

  factory ExamResult.fromJson(Map<String, dynamic> json) {
    final startedAt = _readDateTime(json, 'startedAt');
    final finishedAt = _readDateTime(json, 'finishedAt');
    final results = (json['results'] as List)
        .map(
          (result) =>
              QuestionResult.fromJson(Map<String, dynamic>.from(result as Map)),
        )
        .toList();
    if (results.isEmpty ||
        results.map((result) => result.questionId).toSet().length !=
            results.length) {
      throw const FormatException('시험 결과는 비어 있거나 중복될 수 없습니다.');
    }
    if (finishedAt.isBefore(startedAt) ||
        results.any(
          (result) =>
              result.answeredAt.isBefore(startedAt) ||
              result.answeredAt.isAfter(finishedAt),
        )) {
      throw const FormatException('시험 결과의 시각이 유효하지 않습니다.');
    }
    return ExamResult(
      id: _readId(json, 'id'),
      startedAt: startedAt,
      finishedAt: finishedAt,
      results: results,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'startedAt': startedAt.toIso8601String(),
    'finishedAt': finishedAt.toIso8601String(),
    'results': results.map((result) => result.toJson()).toList(),
  };
}
