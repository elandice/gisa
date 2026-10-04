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
    Future<SharedPreferences> Function()? preferencesLoader,
  }) : _preferences = preferences,
       _initialQuestions = initialQuestions,
       _clock = clock ?? DateTime.now,
       _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance;

  static const storageKey = 'gisa.study.v1';
  static const recoveryStorageKey = '$storageKey.recovery';

  SharedPreferences? _preferences;
  final List<Question>? _initialQuestions;
  final DateTime Function() _clock;
  final Future<SharedPreferences> Function() _preferencesLoader;
  List<Question> _questions = [];
  Map<String, Question> _questionsById = {};
  final Set<String> _completedIds = {};
  final Set<String> _bookmarkedIds = {};
  final Map<String, WrongAnswer> _wrongAnswers = {};
  final List<ExamResult> _examHistory = [];
  ExamSession? _activeExam;
  Future<void> _saveFuture = Future.value();
  bool _savePending = false;
  bool _saving = false;
  String? _recoverySnapshot;
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
  bool get saving => _saving;
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
  int get examRemainingSeconds =>
      _activeExam?.remainingSecondsAt(_clock()) ?? 0;
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
      if (_questions.isEmpty ||
          _questions.any((question) => question.id.isEmpty)) {
        throw const FormatException('학습 자료에 문제가 없습니다.');
      }
      if (_questionsById.length != _questions.length) {
        throw const FormatException('문제 번호가 중복되었습니다.');
      }
    } catch (_) {
      loadError = '학습 자료를 불러오지 못했어요. 다시 시도해 주세요.';
      loading = false;
      _notify();
      return;
    }
    try {
      _preferences ??= await _preferencesLoader();
      final saved = _preferences!.getString(storageKey);
      _resetRecords();
      if (saved != null) {
        var recovered = false;
        try {
          recovered = _restore(
            Map<String, dynamic>.from(jsonDecode(saved) as Map),
          );
        } catch (_) {
          _resetRecords();
          recovered = true;
        }
        if (recovered) {
          _recoverySnapshot = saved;
          try {
            await _preserveRecovery();
          } catch (_) {
            loadWarning = _recoveryFailureMessage;
            saveError = _saveFailureMessage;
          }
        }
      }
      _loaded = true;
    } catch (_) {
      loadError = '학습 기록 저장소를 열지 못했어요. 저장 공간과 브라우저 설정을 확인한 뒤 다시 시도해 주세요.';
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
    final canonical = _requireQuestion(question.id);
    final correct = manualCorrect ?? canonical.grade(userAnswer);
    if (correct == null) return null;
    _recordGrade(question.id, userAnswer, correct, _clock());
    _changed();
    return correct;
  }

  void resolveWrong(String id, {bool resolved = true}) {
    _requireLoaded();
    final wrong = _wrongAnswers[id];
    if (wrong == null || wrong.resolved == resolved) return;
    _wrongAnswers[id] = wrong.copyWith(resolved: resolved);
    _changed();
  }

  void updateWrongMemo(String id, String memo) {
    _requireLoaded();
    final wrong = _wrongAnswers[id];
    if (wrong == null || wrong.memo == memo) return;
    _wrongAnswers[id] = wrong.copyWith(memo: memo);
    _changed();
  }

  ExamSession startExam(List<Question> questions, {int durationMinutes = 30}) {
    _requireLoaded();
    if (_activeExam != null && !_activeExam!.isFinished) {
      throw StateError('진행 중인 시험을 먼저 제출해 주세요.');
    }
    if (questions.isEmpty) throw ArgumentError('시험에 출제할 문제가 필요합니다.');
    if (durationMinutes <= 0) throw ArgumentError('시험 시간은 1분 이상이어야 합니다.');
    if (questions.map((question) => question.id).toSet().length !=
        questions.length) {
      throw ArgumentError('같은 문제를 한 시험에 두 번 출제할 수 없습니다.');
    }
    final canonicalQuestions = questions
        .map((question) => _requireQuestion(question.id))
        .toList();
    final now = _clock();
    try {
      final duration = Duration(minutes: durationMinutes);
      if (duration.inMinutes != durationMinutes ||
          !now.add(duration).isAfter(now)) {
        throw const FormatException('시험 시간이 지원 범위를 벗어났습니다.');
      }
    } catch (_) {
      throw ArgumentError.value(
        durationMinutes,
        'durationMinutes',
        '지원하지 않는 시험 시간입니다.',
      );
    }
    final nextSerial = _serial + 1;
    final session = ExamSession(
      id: '${now.microsecondsSinceEpoch}-$nextSerial',
      questions: canonicalQuestions,
      startedAt: now,
      durationMinutes: durationMinutes,
    );
    _serial = nextSerial;
    _activeExam = session;
    _changed();
    return _activeExam!;
  }

  void answerExam(String questionId, String answer, {bool? manualCorrect}) {
    _requireLoaded();
    final session = _activeExam;
    if (session == null || session.isFinished) return;
    final current = _clock();
    if (!current.isBefore(session.deadline)) return;
    final now = current.isBefore(session.startedAt)
        ? session.startedAt
        : current;
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
    _requireLoaded();
    final session = _activeExam;
    if (session == null) return null;
    final previous = _examHistory.where((result) => result.id == session.id);
    if (previous.isNotEmpty) return previous.first;
    final current = _clock();
    var now = current.isAfter(session.deadline)
        ? session.deadline
        : current.isBefore(session.startedAt)
        ? session.startedAt
        : current;
    for (final answer in session.answerResults.values) {
      if (answer.answeredAt.isAfter(now)) now = answer.answeredAt;
    }
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
    _requireLoaded();
    final session = _activeExam;
    final targetId = examId ?? session?.id;
    if (targetId == null) return;
    if (session != null && session.id == targetId && !session.isFinished) {
      if (!_clock().isBefore(session.deadline)) return;
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
    _requireLoaded();
    final question = _questionsById[id];
    if (question == null) throw ArgumentError.value(id, 'id', '문제를 찾을 수 없습니다.');
    return question;
  }

  void _requireLoaded() {
    if (!_loaded) throw StateError('학습 자료와 기록을 먼저 불러와 주세요.');
    if (_disposed) throw StateError('종료한 학습 저장소는 수정할 수 없습니다.');
  }

  /// Invalid records are isolated; a single damaged row cannot erase other work.
  bool _restore(Map<String, dynamic> json) {
    if (json['version'] != 1) throw const FormatException('지원하지 않는 기록 형식');
    var recovered = false;

    List<dynamic> rows(String key) {
      final value = json[key];
      if (value is List) return value;
      recovered = true;
      return const [];
    }

    void restoreIds(String key, Set<String> target) {
      for (final id in rows(key)) {
        if (id is String && _questionsById.containsKey(id)) {
          target.add(id);
        } else {
          recovered = true;
        }
      }
    }

    restoreIds('completedIds', _completedIds);
    restoreIds('bookmarkedIds', _bookmarkedIds);
    for (final raw in rows('wrongAnswers')) {
      try {
        final wrong = WrongAnswer.fromJson(
          Map<String, dynamic>.from(raw as Map),
        );
        if (wrong.count < 1 ||
            !_questionsById.containsKey(wrong.questionId) ||
            _wrongAnswers.containsKey(wrong.questionId)) {
          throw const FormatException('잘못된 오답 기록');
        }
        _wrongAnswers[wrong.questionId] = wrong;
      } catch (_) {
        recovered = true;
      }
    }
    for (final raw in rows('examHistory')) {
      try {
        final exam = ExamResult.fromJson(Map<String, dynamic>.from(raw as Map));
        if (_examHistory.any((result) => result.id == exam.id) ||
            exam.results.any((answer) {
              final question = _questionsById[answer.questionId];
              return question == null ||
                  (!question.isManual && answer.isCorrect == null);
            })) {
          throw const FormatException('잘못된 시험 기록');
        }
        _examHistory.add(exam);
      } catch (_) {
        recovered = true;
      }
    }
    final total = json['totalAttempts'];
    final correct = json['correctAttempts'];
    if (total is int && total >= 0) {
      _totalAttempts = total;
    } else {
      recovered = true;
    }
    if (correct is int && correct >= 0 && correct <= _totalAttempts) {
      _correctAttempts = correct;
    } else {
      recovered = true;
    }
    final serial = json['serial'] ?? 0;
    if (serial is int && serial >= 0) {
      _serial = serial;
    } else {
      recovered = true;
    }
    if (json['activeExam'] != null) {
      try {
        final session = ExamSession.fromJson(
          Map<String, dynamic>.from(json['activeExam'] as Map),
          _questionsById,
        );
        final previous = _examHistory.where((exam) => exam.id == session.id);
        if (session.isFinished && previous.isEmpty) {
          throw const FormatException('제출된 시험 기록을 찾을 수 없습니다.');
        }
        if (previous.isNotEmpty) {
          final exam = previous.first;
          if (exam.startedAt != session.startedAt ||
              exam.finishedAt.isAfter(session.deadline) ||
              !listEquals(
                exam.results.map((answer) => answer.questionId).toList(),
                session.questions.map((question) => question.id).toList(),
              )) {
            throw const FormatException('진행 중인 시험과 제출된 기록이 일치하지 않습니다.');
          }
          if (session.finishedAt != exam.finishedAt) {
            session.finishedAt = exam.finishedAt;
            recovered = true;
          }
        }
        _activeExam = session;
      } catch (_) {
        recovered = true;
      }
    }
    return recovered;
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
    _scheduleSave();
    _notify();
  }

  static const _saveFailureMessage =
      '학습 기록을 저장하지 못했어요. 저장 공간과 브라우저 설정을 확인해 주세요.';
  static const _recoverySuccessMessage =
      '읽을 수 없는 기록은 제외하고 학습 기록을 복구했어요. 원본 기록은 별도로 보관했어요.';
  static const _recoveryFailureMessage =
      '원본 기록 보관에 실패해 새 기록을 저장할 수 없어요. 저장을 다시 시도해 주세요.';

  /// Keep every original recovery snapshot; never overwrite a damaged record
  /// until its original contents have been saved successfully in this archive.
  Future<void> _preserveRecovery() async {
    final raw = _recoverySnapshot;
    if (raw == null) return;
    final existing = _preferences!.getString(recoveryStorageKey);
    final List<String> snapshots;
    if (existing == null) {
      snapshots = [];
    } else {
      final archive = Map<String, dynamic>.from(jsonDecode(existing) as Map);
      if (archive['version'] != 1) {
        throw const FormatException('지원하지 않는 복구 기록 형식');
      }
      snapshots = List<String>.from(archive['snapshots'] as List);
    }
    if (!snapshots.contains(raw)) {
      snapshots.add(raw);
      final saved = await _preferences!.setString(
        recoveryStorageKey,
        jsonEncode({'version': 1, 'snapshots': snapshots}),
      );
      if (!saved) throw StateError('원본 기록 보관 실패');
    }
    _recoverySnapshot = null;
    loadWarning = _recoverySuccessMessage;
  }

  void _scheduleSave() {
    _savePending = true;
    if (_saving) return;
    _saving = true;
    _saveFuture = Future<void>.microtask(_drainSaves);
  }

  Future<void> _drainSaves() async {
    try {
      while (_savePending) {
        _savePending = false;
        // Encode when the next write begins. Typing during an in-flight write
        // replaces one pending state instead of queuing all older snapshots.
        try {
          final snapshot = jsonEncode(_snapshot());
          await _preserveRecovery();
          final saved = await _preferences!.setString(storageKey, snapshot);
          if (!saved) throw StateError('기록 저장 실패');
          if (saveError != null) {
            saveError = null;
            _notify();
          }
        } catch (_) {
          if (_recoverySnapshot != null) {
            loadWarning = _recoveryFailureMessage;
          }
          saveError = _saveFailureMessage;
          _notify();
        }
      }
    } finally {
      _saving = false;
      _notify();
    }
  }

  Future<void> flush() async {
    while (_saving) {
      await _saveFuture;
    }
  }

  /// Retries the current state, even when the learner has made no further edits.
  Future<void> retrySave() async {
    _requireLoaded();
    _scheduleSave();
    _notify();
    await flush();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
