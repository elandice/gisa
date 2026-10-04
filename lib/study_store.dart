import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class StudyStore extends ChangeNotifier {
  StudyStore({
    SharedPreferences? preferences,
    List<Question>? initialQuestions,
    DateTime Function()? clock,
  }) : _preferences = preferences,
       _initialQuestions = initialQuestions,
       _clock = clock ?? DateTime.now;

  static const storageKey = 'gisa.study.v1';

  SharedPreferences? _preferences;
  final List<Question>? _initialQuestions;
  final DateTime Function() _clock;
  List<Question> _questions = [];
  Map<String, Question> _questionsById = {};
  final Set<String> _completedIds = {};
  final Set<String> _bookmarkedIds = {};
  final Map<String, WrongAnswer> _wrongAnswers = {};
  final List<ExamResult> _examHistory = [];
  ExamSession? _activeExam;
  Future<void> _saveFuture = Future.value();
  bool _disposed = false;
  bool _loaded = false;
  int _serial = 0;
  int _totalAttempts = 0;
  int _correctAttempts = 0;

  bool loading = false;
  String? loadError;
  String? loadWarning;
  String? saveError;

  bool get ready => _loaded;
  String? get error => loadError;
  List<Question> get questions => List.unmodifiable(_questions);
  Set<String> get completedIds => UnmodifiableSetView(_completedIds);
  Set<String> get bookmarkedIds => UnmodifiableSetView(_bookmarkedIds);
  Map<String, WrongAnswer> get wrongAnswers => UnmodifiableMapView({
    for (final record in wrongAnswerList) record.questionId: record,
  });
  List<WrongAnswer> get wrongAnswerList {
    final records = _wrongAnswers.values.toList();
    records.sort((a, b) => b.lastAttemptAt.compareTo(a.lastAttemptAt));
    return List.unmodifiable(records);
  }

  List<ExamResult> get examHistory => List.unmodifiable(_examHistory);
  ExamSession? get activeExam => _activeExam;
  int get completedCount => _completedIds.length;
  int get bookmarkCount => _bookmarkedIds.length;
  int get unresolvedWrongCount =>
      _wrongAnswers.values.where((record) => !record.resolved).length;
  int get totalAttempts => _totalAttempts;
  int get correctAttempts => _correctAttempts;
  double get accuracy =>
      _totalAttempts == 0 ? 0 : _correctAttempts / _totalAttempts * 100;
  double get progress =>
      _questions.isEmpty ? 0 : _completedIds.length / _questions.length;

  Question? questionById(String id) => _questionsById[id];
  List<Question> questionsFor(String categoryId) =>
      _questions.where((q) => q.categoryId == categoryId).toList();
  bool isCompleted(String id) => _completedIds.contains(id);
  bool isBookmarked(String id) => _bookmarkedIds.contains(id);
  WrongAnswer? wrongFor(String id) => _wrongAnswers[id];

  Future<void> load() async {
    if (_loaded || loading) return;
    loading = true;
    loadError = null;
    loadWarning = null;
    _notify();
    try {
      _questions = _initialQuestions == null
          ? await _loadQuestions()
          : List.of(_initialQuestions);
      _questionsById = {
        for (final question in _questions) question.id: question,
      };
      if (_questionsById.length != _questions.length) {
        throw const FormatException('문제 번호가 중복되었습니다.');
      }
      _preferences ??= await SharedPreferences.getInstance();
      final saved = _preferences!.getString(storageKey);
      if (saved != null) {
        try {
          _restore(Map<String, dynamic>.from(jsonDecode(saved) as Map));
        } catch (_) {
          _resetRecords();
          loadWarning = '저장된 학습 기록을 읽을 수 없어 새 기록으로 시작했어요.';
        }
      }
      _loaded = true;
    } catch (_) {
      loadError = '학습 자료를 불러오지 못했어요. 다시 시도해 주세요.';
    } finally {
      loading = false;
      _notify();
    }
  }

  Future<List<Question>> _loadQuestions() async {
    final data = await Future.wait(
      categories.map((category) async {
        final raw = await rootBundle.loadString(
          'assets/data/${category.assetFile}.json',
        );
        final rows = jsonDecode(raw) as List;
        final questions = rows
            .map(
              (row) => Question.fromJson(Map<String, dynamic>.from(row as Map)),
            )
            .toList();
        if (questions.length != category.expectedCount ||
            questions.any((question) => question.categoryId != category.id)) {
          throw const FormatException('학습 자료의 문제 수 또는 분류가 일치하지 않습니다.');
        }
        return questions;
      }),
    );
    return data.expand((questions) => questions).toList();
  }

  void toggleBookmark(String id) {
    _requireQuestion(id);
    if (!_bookmarkedIds.remove(id)) _bookmarkedIds.add(id);
    _changed();
  }

  void markCompleted(String id, {bool completed = true}) {
    _requireQuestion(id);
    final changed = completed
        ? _completedIds.add(id)
        : _completedIds.remove(id);
    if (changed) _changed();
  }

  bool? recordPracticeAnswer(
    Question question,
    String userAnswer, {
    bool? manualCorrect,
  }) {
    _requireQuestion(question.id);
    final correct = manualCorrect ?? question.grade(userAnswer);
    if (correct == null) return null;
    _recordGrade(question.id, userAnswer, correct, _clock());
    _changed();
    return correct;
  }

  void resolveWrong(String id, {bool resolved = true}) {
    final wrong = _wrongAnswers[id];
    if (wrong == null || wrong.resolved == resolved) return;
    _wrongAnswers[id] = wrong.copyWith(resolved: resolved);
    _changed();
  }

  void updateWrongMemo(String id, String memo) {
    final wrong = _wrongAnswers[id];
    if (wrong == null || wrong.memo == memo) return;
    _wrongAnswers[id] = wrong.copyWith(memo: memo);
    _changed();
  }

  ExamSession startExam(List<Question> questions, {int durationMinutes = 30}) {
    if (questions.isEmpty) throw ArgumentError('시험에 출제할 문제가 필요합니다.');
    if (durationMinutes <= 0) throw ArgumentError('시험 시간은 1분 이상이어야 합니다.');
    if (questions.map((question) => question.id).toSet().length !=
        questions.length) {
      throw ArgumentError('같은 문제를 한 시험에 두 번 출제할 수 없습니다.');
    }
    for (final question in questions) {
      _requireQuestion(question.id);
    }
    final now = _clock();
    _activeExam = ExamSession(
      id: '${now.microsecondsSinceEpoch}-${++_serial}',
      questions: questions,
      startedAt: now,
      durationMinutes: durationMinutes,
    );
    _changed();
    return _activeExam!;
  }

  void answerExam(String questionId, String answer, {bool? manualCorrect}) {
    final session = _activeExam;
    if (session == null || session.isFinished) return;
    final now = _clock();
    if (!now.isBefore(session.deadline)) return;
    final question = session.questions.firstWhere(
      (question) => question.id == questionId,
    );
    session.setAnswer(
      QuestionResult(
        questionId: questionId,
        userAnswer: answer,
        isCorrect: question.isManual ? manualCorrect : question.grade(answer),
        answeredAt: now,
      ),
    );
    _changed();
  }

  /// Finalizing twice returns the same history entry without repeating attempts.
  ExamResult? finishExam() {
    final session = _activeExam;
    if (session == null) return null;
    final previous = _examHistory.where((result) => result.id == session.id);
    if (previous.isNotEmpty) return previous.first;
    final current = _clock();
    final now = current.isAfter(session.deadline)
        ? session.deadline
        : current.isBefore(session.startedAt)
        ? session.startedAt
        : current;
    final results = session.questions.map((question) {
      final answer = session.answerResults[question.id];
      // A blank response is unanswered, including on a manually graded item.
      if (answer == null || answer.userAnswer.trim().isEmpty) {
        return QuestionResult(
          questionId: question.id,
          userAnswer: '',
          isCorrect: false,
          answeredAt: now,
        );
      }
      return answer;
    }).toList();
    final result = ExamResult(
      id: session.id,
      startedAt: session.startedAt,
      finishedAt: now,
      results: results,
    );
    session.finishedAt = now;
    _examHistory.insert(0, result);
    for (final answer in results) {
      if (answer.isCorrect != null) {
        _recordGrade(
          answer.questionId,
          answer.userAnswer,
          answer.isCorrect!,
          answer.answeredAt,
        );
      }
    }
    _changed();
    return result;
  }

  /// Pending descriptive answers may be graded during or after the exam.
  /// A finalized grade can never inflate an attempt or wrong-answer counter.
  void gradeExamQuestion(String questionId, bool correct, {String? examId}) {
    final session = _activeExam;
    final targetId = examId ?? session?.id;
    if (targetId == null) return;
    if (session != null && session.id == targetId && !session.isFinished) {
      final question = session.questions.firstWhere(
        (question) => question.id == questionId,
      );
      if (!question.isManual) return;
      final answer = session.answerResults[questionId];
      if (answer == null) return;
      session.setAnswer(answer.withGrade(correct));
      _changed();
      return;
    }
    final index = _examHistory.indexWhere((result) => result.id == targetId);
    if (index < 0) return;
    final exam = _examHistory[index];
    final answers = exam.results.where(
      (answer) => answer.questionId == questionId,
    );
    if (answers.isEmpty || answers.first.isCorrect != null) return;
    final answer = answers.first;
    _examHistory[index] = exam.withGrade(questionId, correct);
    _recordGrade(questionId, answer.userAnswer, correct, _clock());
    _changed();
  }

  void _recordGrade(
    String questionId,
    String answer,
    bool correct,
    DateTime time,
  ) {
    _totalAttempts++;
    if (correct) {
      _correctAttempts++;
      _completedIds.add(questionId);
      final wrong = _wrongAnswers[questionId];
      if (wrong != null) {
        _wrongAnswers[questionId] = wrong.copyWith(resolved: true);
      }
      return;
    }
    final wrong = _wrongAnswers[questionId];
    _wrongAnswers[questionId] = WrongAnswer(
      questionId: questionId,
      userAnswer: answer,
      lastAttemptAt: time,
      count: (wrong?.count ?? 0) + 1,
      memo: wrong?.memo ?? '',
    );
  }

  Question _requireQuestion(String id) {
    final question = _questionsById[id];
    if (question == null) throw ArgumentError.value(id, 'id', '문제를 찾을 수 없습니다.');
    return question;
  }

  void _restore(Map<String, dynamic> json) {
    if (json['version'] != 1) throw const FormatException('지원하지 않는 기록 형식');
    _completedIds.addAll(
      List<String>.from(
        json['completedIds'] as List,
      ).where(_questionsById.containsKey),
    );
    _bookmarkedIds.addAll(
      List<String>.from(
        json['bookmarkedIds'] as List,
      ).where(_questionsById.containsKey),
    );
    for (final raw in json['wrongAnswers'] as List) {
      final wrong = WrongAnswer.fromJson(Map<String, dynamic>.from(raw as Map));
      if (wrong.count < 1) throw const FormatException('잘못된 오답 횟수');
      if (_questionsById.containsKey(wrong.questionId)) {
        _wrongAnswers[wrong.questionId] = wrong;
      }
    }
    for (final raw in json['examHistory'] as List) {
      final exam = ExamResult.fromJson(Map<String, dynamic>.from(raw as Map));
      if (_examHistory.any((result) => result.id == exam.id)) {
        throw const FormatException('중복된 시험 기록');
      }
      _examHistory.add(exam);
    }
    _totalAttempts = json['totalAttempts'] as int;
    _correctAttempts = json['correctAttempts'] as int;
    if (_totalAttempts < 0 ||
        _correctAttempts < 0 ||
        _correctAttempts > _totalAttempts) {
      throw const FormatException('잘못된 학습 통계');
    }
    _serial = json['serial'] as int? ?? 0;
    if (json['activeExam'] != null) {
      _activeExam = ExamSession.fromJson(
        Map<String, dynamic>.from(json['activeExam'] as Map),
        _questionsById,
      );
    }
  }

  void _resetRecords() {
    _completedIds.clear();
    _bookmarkedIds.clear();
    _wrongAnswers.clear();
    _examHistory.clear();
    _activeExam = null;
    _totalAttempts = 0;
    _correctAttempts = 0;
    _serial = 0;
  }

  Map<String, dynamic> _snapshot() => {
    'version': 1,
    'completedIds': _completedIds.toList(),
    'bookmarkedIds': _bookmarkedIds.toList(),
    'wrongAnswers': _wrongAnswers.values
        .map((wrong) => wrong.toJson())
        .toList(),
    'examHistory': _examHistory.map((exam) => exam.toJson()).toList(),
    'totalAttempts': _totalAttempts,
    'correctAttempts': _correctAttempts,
    'serial': _serial,
    'activeExam': _activeExam?.toJson(),
  };

  void _changed() {
    _notify();
    final snapshot = jsonEncode(_snapshot());
    // Serialize writes so a slower, older write cannot erase the latest answer.
    _saveFuture = _saveFuture.then((_) async {
      try {
        _preferences ??= await SharedPreferences.getInstance();
        final saved = await _preferences!.setString(storageKey, snapshot);
        if (!saved) throw StateError('기록 저장 실패');
        if (saveError != null) {
          saveError = null;
          _notify();
        }
      } catch (_) {
        saveError = '학습 기록을 저장하지 못했어요. 저장 공간과 브라우저 설정을 확인해 주세요.';
        _notify();
      }
    });
  }

  Future<void> flush() => _saveFuture;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
