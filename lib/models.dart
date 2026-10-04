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

/// Normalizes typing variations without merging distinct output tokens.
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
    final normalized = normalizeAnswer(response);
    if (normalized.isEmpty) return false;
    return [
      answer,
      ...aliases,
    ].any((accepted) => normalizeAnswer(accepted) == normalized);
  }

  factory Question.fromJson(Map<String, dynamic> json) {
    final grading = json['grading'] as String? ?? 'exact';
    if (grading != 'exact' && grading != 'manual') {
      throw const FormatException('지원하지 않는 채점 방식');
    }
    final categoryId = json['categoryId'] as String;
    categoryById(categoryId);
    return Question(
      id: json['id'] as String,
      categoryId: categoryId,
      number: json['number'] as int,
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
    questionId: json['questionId'] as String,
    userAnswer: json['userAnswer'] as String,
    lastAttemptAt: DateTime.parse(json['lastAttemptAt'] as String),
    count: json['count'] as int,
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
    questionId: json['questionId'] as String,
    userAnswer: json['userAnswer'] as String,
    isCorrect: json['isCorrect'] as bool?,
    answeredAt: DateTime.parse(json['answeredAt'] as String),
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
    final remaining = deadline.difference(now);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  void setAnswer(QuestionResult result) {
    if (isFinished) throw StateError('제출한 시험의 답안은 수정할 수 없습니다.');
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
    if (ids.any((id) => !questions.containsKey(id))) {
      throw const FormatException('시험 문제를 찾을 수 없습니다.');
    }
    final answers = (json['answers'] as List).map(
      (answer) =>
          QuestionResult.fromJson(Map<String, dynamic>.from(answer as Map)),
    );
    return ExamSession(
      id: json['id'] as String,
      questions: ids.map((id) => questions[id]!).toList(),
      startedAt: DateTime.parse(json['startedAt'] as String),
      durationMinutes: json['durationMinutes'] as int,
      answers: {for (final answer in answers) answer.questionId: answer},
      finishedAt: json['finishedAt'] == null
          ? null
          : DateTime.parse(json['finishedAt'] as String),
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

  factory ExamResult.fromJson(Map<String, dynamic> json) => ExamResult(
    id: json['id'] as String,
    startedAt: DateTime.parse(json['startedAt'] as String),
    finishedAt: DateTime.parse(json['finishedAt'] as String),
    results: (json['results'] as List)
        .map(
          (result) =>
              QuestionResult.fromJson(Map<String, dynamic>.from(result as Map)),
        )
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'startedAt': startedAt.toIso8601String(),
    'finishedAt': finishedAt.toIso8601String(),
    'results': results.map((result) => result.toJson()).toList(),
  };
}
