import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gisa/models.dart';
import 'package:gisa/study_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models_test.dart' show exactQuestion, manualQuestion;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences preferences;
  late StudyStore store;
  late DateTime now;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    now = DateTime(2026, 10, 4, 12);
    store = StudyStore(
      preferences: preferences,
      initialQuestions: [exactQuestion, manualQuestion],
      clock: () => now,
    );
    await store.load();
  });

  tearDown(() async {
    await store.flush();
    store.dispose();
  });

  test(
    'completion, bookmark, wrong answer and memo persist on reload',
    () async {
      store.toggleBookmark(exactQuestion.id);
      store.markCompleted(manualQuestion.id);
      store.recordPracticeAnswer(exactQuestion, '단위 테스트');
      store.updateWrongMemo(exactQuestion.id, '변경 후 기존 기능을 검증한다.');
      await store.flush();

      final restored = StudyStore(
        preferences: preferences,
        initialQuestions: [exactQuestion, manualQuestion],
      );
      await restored.load();
      expect(restored.ready, isTrue);
      expect(restored.isCompleted(manualQuestion.id), isTrue);
      expect(restored.isBookmarked(exactQuestion.id), isTrue);
      expect(restored.wrongFor(exactQuestion.id)!.userAnswer, '단위 테스트');
      expect(restored.wrongFor(exactQuestion.id)!.memo, '변경 후 기존 기능을 검증한다.');
      expect(restored.wrongFor(exactQuestion.id)!.lastAttemptAt, now);
      expect(restored.wrongFor(exactQuestion.id)!.wrongCount, 1);
      expect(restored.totalAttempts, 1);
      expect(restored.accuracy, 0);
      restored.dispose();
    },
  );

  test(
    'a correct retry resolves a wrong answer and a new error reopens it',
    () {
      store.recordPracticeAnswer(exactQuestion, '오답');
      store.updateWrongMemo(exactQuestion.id, '반복 학습');
      store.resolveWrong(exactQuestion.id);
      expect(store.unresolvedWrongCount, 0);
      store.recordPracticeAnswer(exactQuestion, '다시 오답');
      expect(store.wrongFor(exactQuestion.id)!.resolved, isFalse);
      expect(store.wrongFor(exactQuestion.id)!.count, 2);
      expect(store.wrongFor(exactQuestion.id)!.memo, '반복 학습');
      store.recordPracticeAnswer(exactQuestion, 'Regression Test');
      expect(store.unresolvedWrongCount, 0);
      expect(store.wrongFor(exactQuestion.id)!.count, 2);
      expect(store.completedCount, 1);
      expect(store.totalAttempts, 3);
      expect(store.correctAttempts, 1);
    },
  );

  test('descriptive practice waits for explicit grading', () {
    expect(
      store.recordPracticeAnswer(manualQuestion, 'select * from student'),
      isNull,
    );
    expect(store.wrongAnswers, isEmpty);
    expect(store.totalAttempts, 0);
    expect(
      store.recordPracticeAnswer(
        manualQuestion,
        'select * from student',
        manualCorrect: true,
      ),
      isTrue,
    );
    expect(store.totalAttempts, 1);
    expect(store.correctAttempts, 1);
  });

  test('exact flashcards honor explicit assessment without a typed answer', () {
    expect(
      store.recordPracticeAnswer(exactQuestion, '', manualCorrect: true),
      isTrue,
    );
    expect(store.completedCount, 1);
    expect(store.correctAttempts, 1);
    expect(store.wrongAnswers, isEmpty);
    expect(
      store.recordPracticeAnswer(exactQuestion, '', manualCorrect: false),
      isFalse,
    );
    expect(store.totalAttempts, 2);
    expect(store.wrongFor(exactQuestion.id)!.count, 1);
    expect(store.wrongFor(exactQuestion.id)!.userAnswer, '');
    expect(store.wrongFor(exactQuestion.id)!.resolved, isFalse);
  });

  test('practice overrides do not change automatic exact exam grading', () {
    store.startExam([exactQuestion]);
    store.answerExam(exactQuestion.id, '오답', manualCorrect: true);
    expect(store.finishExam()!.correctCount, 0);
    expect(store.wrongFor(exactQuestion.id)!.count, 1);
  });

  test('exam submission and manual grading are each counted once', () async {
    final session = store.startExam([
      exactQuestion,
      manualQuestion,
    ], durationMinutes: 10);
    store.answerExam(exactQuestion.id, '회귀테스트');
    store.answerExam(manualQuestion.id, 'select * from student');
    now = now.add(const Duration(seconds: 90));
    final result = store.finishExam()!;
    expect(result.correctCount, 1);
    expect(result.pendingCount, 1);
    expect(result.durationSeconds, 90);
    expect(store.totalAttempts, 1);
    expect(store.wrongAnswers, isEmpty);
    expect(store.finishExam()!.id, result.id);
    expect(store.totalAttempts, 1);
    expect(store.examHistory, hasLength(1));

    store.gradeExamQuestion(manualQuestion.id, false, examId: session.id);
    expect(store.examHistory.first.pendingCount, 0);
    expect(store.wrongFor(manualQuestion.id)!.count, 1);
    expect(store.totalAttempts, 2);
    store.gradeExamQuestion(manualQuestion.id, false, examId: session.id);
    store.gradeExamQuestion(manualQuestion.id, true, examId: session.id);
    expect(store.wrongFor(manualQuestion.id)!.count, 1);
    expect(store.totalAttempts, 2);
    expect(store.finishExam()!.score, 50);
    await store.flush();

    final restored = StudyStore(
      preferences: preferences,
      initialQuestions: [exactQuestion, manualQuestion],
    );
    await restored.load();
    expect(restored.examHistory.first.score, 50);
    expect(restored.examHistory.first.durationSeconds, 90);
    restored.finishExam();
    expect(restored.totalAttempts, 2);
    expect(restored.examHistory, hasLength(1));
    restored.dispose();
  });

  test('blank and unanswered exam items are incorrect rather than pending', () {
    store.startExam([exactQuestion, manualQuestion]);
    store.answerExam(manualQuestion.id, '  ');
    final result = store.finishExam()!;
    expect(result.pendingCount, 0);
    expect(result.incorrectCount, 2);
    expect(store.unresolvedWrongCount, 2);
    expect(store.totalAttempts, 2);
  });

  test('an unfinished exam survives reload without grading attempts', () async {
    store.startExam([exactQuestion, manualQuestion], durationMinutes: 15);
    store.answerExam(manualQuestion.id, 'select * from student');
    await store.flush();
    final restored = StudyStore(
      preferences: preferences,
      initialQuestions: [exactQuestion, manualQuestion],
    );
    await restored.load();
    expect(restored.activeExam!.durationMinutes, 15);
    expect(
      restored.activeExam!.answers[manualQuestion.id],
      'select * from student',
    );
    expect(restored.activeExam!.pendingCount, 1);
    expect(restored.totalAttempts, 0);
    expect(restored.examHistory, isEmpty);
    restored.dispose();
  });

  test(
    'restored expired exam rejects late edits and caps recorded duration',
    () async {
      final started = now;
      store.startExam([exactQuestion], durationMinutes: 1);
      store.answerExam(exactQuestion.id, '회귀테스트');
      await store.flush();
      now = started.add(const Duration(hours: 2));
      final restored = StudyStore(
        preferences: preferences,
        initialQuestions: [exactQuestion],
        clock: () => now,
      );
      await restored.load();
      restored.answerExam(exactQuestion.id, '단위 테스트');
      expect(restored.activeExam!.answers[exactQuestion.id], '회귀테스트');
      final result = restored.finishExam()!;
      expect(result.durationSeconds, 60);
      expect(result.finishedAt, started.add(const Duration(minutes: 1)));
      expect(result.correctCount, 1);
      restored.finishExam();
      expect(restored.totalAttempts, 1);
      await restored.flush();
      restored.dispose();
    },
  );

  test('clock moving backwards cannot produce negative exam duration', () {
    final started = now;
    store.startExam([exactQuestion]);
    now = now.subtract(const Duration(minutes: 5));
    final result = store.finishExam()!;
    expect(result.durationSeconds, 0);
    expect(result.finishedAt, started);
  });

  test('clock regression after an answer retains a valid exam chronology', () {
    final started = now;
    store.startExam([exactQuestion]);
    now = started.add(const Duration(seconds: 30));
    store.answerExam(exactQuestion.id, '회귀 테스트');
    now = started.subtract(const Duration(minutes: 5));
    final result = store.finishExam()!;
    expect(result.finishedAt, started.add(const Duration(seconds: 30)));
    expect(result.durationSeconds, 30);
    expect(result.correctCount, 1);
  });

  test('typing after a backward clock change clamps the answer timestamp', () {
    final started = now;
    store.startExam([exactQuestion]);
    now = now.subtract(const Duration(minutes: 5));
    store.answerExam(exactQuestion.id, '회귀 테스트');
    expect(
      store.activeExam!.answerResults[exactQuestion.id]!.answeredAt,
      started,
    );
    expect(store.examRemainingSeconds, 30 * 60);
    expect(store.finishExam()!.correctCount, 1);
  });

  test('exam timer uses the same injected clock as answer acceptance', () {
    store.startExam([exactQuestion], durationMinutes: 1);
    expect(store.examRemainingSeconds, 60);
    now = now.add(const Duration(seconds: 59, milliseconds: 1));
    expect(store.examRemainingSeconds, 1);
    now = now.add(const Duration(seconds: 1));
    expect(store.examRemainingSeconds, 0);
    store.answerExam(exactQuestion.id, '회귀 테스트');
    expect(store.activeExam!.answers, isEmpty);
  });

  test('an unfinished exam cannot be silently replaced', () {
    final first = store.startExam([exactQuestion]);
    store.answerExam(exactQuestion.id, '회귀 테스트');
    expect(() => store.startExam([manualQuestion]), throwsStateError);
    expect(store.activeExam, same(first));
    expect(store.activeExam!.answers[exactQuestion.id], '회귀 테스트');
    store.finishExam();
    expect(store.startExam([manualQuestion]).id, isNot(first.id));
  });

  test('manual grading after the exam deadline cannot alter a live answer', () {
    store.startExam([manualQuestion], durationMinutes: 1);
    store.answerExam(manualQuestion.id, 'SELECT * FROM student;');
    now = now.add(const Duration(minutes: 1));
    store.gradeExamQuestion(manualQuestion.id, true);
    expect(
      store.activeExam!.answerResults[manualQuestion.id]!.isCorrect,
      isNull,
    );
    final result = store.finishExam()!;
    expect(result.pendingCount, 1);
    store.gradeExamQuestion(manualQuestion.id, true, examId: result.id);
    expect(store.examHistory.single.correctCount, 1);
    expect(store.totalAttempts, 1);
  });

  test('grading and exams use the canonical question for a supplied ID', () {
    final altered = Question.fromJson({
      ...exactQuestion.toJson(),
      'answer': '조작한 정답',
      'prompt': '조작한 문제',
    });
    expect(store.recordPracticeAnswer(altered, '조작한 정답'), isFalse);
    final session = store.startExam([altered]);
    expect(session.questions.single, same(exactQuestion));
    store.answerExam(exactQuestion.id, '회귀 테스트');
    expect(store.finishExam()!.correctCount, 1);
  });

  test('malformed storage recovers and provides a visible warning', () async {
    await preferences.setString(StudyStore.storageKey, '{broken-json');
    final recovered = StudyStore(
      preferences: preferences,
      initialQuestions: [exactQuestion],
    );
    await recovered.load();
    expect(recovered.ready, isTrue);
    expect(recovered.loadError, isNull);
    expect(recovered.loadWarning, isNotNull);
    expect(recovered.completedCount, 0);
    expect(recovered.examHistory, isEmpty);
    recovered.toggleBookmark(exactQuestion.id);
    await recovered.flush();
    expect(
      preferences.getString(StudyStore.storageKey),
      contains('bookmarkedIds'),
    );
    recovered.dispose();
  });

  test(
    'a corrupt row preserves valid records and the raw recovery copy',
    () async {
      store.toggleBookmark(exactQuestion.id);
      store.markCompleted(manualQuestion.id);
      store.recordPracticeAnswer(exactQuestion, '단위 테스트');
      store.startExam([manualQuestion]);
      store.answerExam(manualQuestion.id, 'SELECT * FROM student;');
      store.finishExam();
      await store.flush();
      final snapshot =
          jsonDecode(preferences.getString(StudyStore.storageKey)!)
              as Map<String, dynamic>;
      (snapshot['completedIds'] as List).add(17);
      (snapshot['bookmarkedIds'] as List).add('removed-question');
      (snapshot['wrongAnswers'] as List).add({'questionId': exactQuestion.id});
      final history = snapshot['examHistory'] as List;
      history.add({
        ...(history.single as Map<String, dynamic>),
        'id': 'unknown-question-exam',
        'results': [
          {
            ...((history.single as Map)['results'] as List).single as Map,
            'questionId': 'removed-question',
          },
        ],
      });
      final raw = jsonEncode(snapshot);
      await preferences.setString(StudyStore.storageKey, raw);

      final recovered = StudyStore(
        preferences: preferences,
        initialQuestions: [exactQuestion, manualQuestion],
      );
      await recovered.load();
      expect(recovered.ready, isTrue);
      expect(recovered.loadWarning, isNotNull);
      expect(recovered.completedIds, {manualQuestion.id});
      expect(recovered.bookmarkedIds, {exactQuestion.id});
      expect(recovered.wrongAnswers.keys, [exactQuestion.id]);
      expect(recovered.examHistory, hasLength(1));
      expect(recovered.totalAttempts, 1);
      final backup = preferences.getString(StudyStore.recoveryStorageKey)!;
      expect((jsonDecode(backup) as Map)['snapshots'], [raw]);
      recovered.updateWrongMemo(exactQuestion.id, '복구 후 메모');
      await recovered.flush();
      expect(preferences.getString(StudyStore.recoveryStorageKey), backup);
      expect(preferences.getString(StudyStore.storageKey), contains('복구 후 메모'));
      recovered.dispose();
    },
  );

  test(
    'invalid restored exams are isolated without erasing bookmarks',
    () async {
      store.toggleBookmark(exactQuestion.id);
      store.startExam([exactQuestion]);
      await store.flush();
      final original =
          jsonDecode(preferences.getString(StudyStore.storageKey)!)
              as Map<String, dynamic>;
      final originalSession = original['activeExam'] as Map<String, dynamic>;
      for (final invalid in [
        {'questionIds': <String>[]},
        {
          'questionIds': [exactQuestion.id, exactQuestion.id],
        },
        {'durationMinutes': 0},
        {'durationMinutes': -30},
        {'startedAt': 'invalid-date'},
        {
          'finishedAt': now
              .subtract(const Duration(seconds: 1))
              .toIso8601String(),
        },
        {
          'answers': [
            {
              'questionId': manualQuestion.id,
              'userAnswer': 'outside this exam',
              'isCorrect': null,
              'answeredAt': now.toIso8601String(),
            },
          ],
        },
      ]) {
        await preferences.setString(
          StudyStore.storageKey,
          jsonEncode({
            ...original,
            'activeExam': {...originalSession, ...invalid},
          }),
        );
        final recovered = StudyStore(
          preferences: preferences,
          initialQuestions: [exactQuestion, manualQuestion],
        );
        await recovered.load();
        expect(recovered.ready, isTrue);
        expect(recovered.activeExam, isNull, reason: invalid.toString());
        expect(recovered.bookmarkedIds, {exactQuestion.id});
        expect(recovered.loadWarning, isNotNull);
        recovered.dispose();
      }
      expect(
        ((jsonDecode(preferences.getString(StudyStore.recoveryStorageKey)!)
                    as Map)['snapshots']
                as List)
            .length,
        7,
      );
    },
  );

  test(
    'storage initialization can be retried and blocks premature edits',
    () async {
      var fail = true;
      final persistent = StudyStore(
        initialQuestions: [exactQuestion],
        preferencesLoader: () async {
          if (fail) throw StateError('storage unavailable');
          return preferences;
        },
      );
      await persistent.load();
      expect(persistent.ready, isFalse);
      expect(persistent.loadError, contains('저장소'));
      expect(
        () => persistent.toggleBookmark(exactQuestion.id),
        throwsStateError,
      );
      expect(
        () => persistent.markCompleted(exactQuestion.id),
        throwsStateError,
      );
      expect(
        () => persistent.recordPracticeAnswer(exactQuestion, '회귀 테스트'),
        throwsStateError,
      );
      expect(
        () => persistent.updateWrongMemo(exactQuestion.id, '메모'),
        throwsStateError,
      );
      expect(() => persistent.resolveWrong(exactQuestion.id), throwsStateError);
      expect(() => persistent.startExam([exactQuestion]), throwsStateError);
      expect(
        () => persistent.answerExam(exactQuestion.id, '답안'),
        throwsStateError,
      );
      expect(() => persistent.finishExam(), throwsStateError);
      expect(
        () => persistent.gradeExamQuestion(exactQuestion.id, true),
        throwsStateError,
      );
      await expectLater(persistent.retrySave(), throwsStateError);
      expect(preferences.getString(StudyStore.storageKey), isNull);
      fail = false;
      await persistent.load();
      expect(persistent.ready, isTrue);
      expect(persistent.loadError, isNull);
      persistent.toggleBookmark(exactQuestion.id);
      await persistent.flush();
      expect(persistent.saveError, isNull);
      persistent.dispose();
    },
  );

  test('invalid learning data reports a distinct load failure', () async {
    final invalid = StudyStore(preferences: preferences, initialQuestions: []);
    await invalid.load();
    expect(invalid.ready, isFalse);
    expect(invalid.loadError, contains('학습 자료'));
    expect(() => invalid.startExam([exactQuestion]), throwsStateError);
    invalid.dispose();
  });

  test(
    'a storage read failure remains blocked until a successful retry',
    () async {
      final failing = _TogglePreferences()
        ..failReads = true
        ..failWrites = false;
      final persistent = StudyStore(
        preferences: failing,
        initialQuestions: [exactQuestion],
      );
      await persistent.load();
      expect(persistent.ready, isFalse);
      expect(persistent.loadError, contains('저장소'));
      expect(
        () => persistent.toggleBookmark(exactQuestion.id),
        throwsStateError,
      );
      failing.failReads = false;
      await persistent.load();
      expect(persistent.ready, isTrue);
      expect(persistent.loadError, isNull);
      persistent.dispose();
    },
  );

  test(
    'a stale restored active exam never repeats submitted attempts',
    () async {
      store.startExam([exactQuestion]);
      store.answerExam(exactQuestion.id, '회귀 테스트');
      store.finishExam();
      await store.flush();
      final snapshot =
          jsonDecode(preferences.getString(StudyStore.storageKey)!)
              as Map<String, dynamic>;
      (snapshot['activeExam'] as Map)['finishedAt'] = null;
      await preferences.setString(StudyStore.storageKey, jsonEncode(snapshot));
      final recovered = StudyStore(
        preferences: preferences,
        initialQuestions: [exactQuestion],
      );
      await recovered.load();
      expect(recovered.activeExam!.isFinished, isTrue);
      expect(recovered.loadWarning, isNotNull);
      expect(recovered.finishExam()!.correctCount, 1);
      expect(recovered.totalAttempts, 1);
      expect(recovered.examHistory, hasLength(1));
      recovered.dispose();
    },
  );

  test('invalid exams are rejected before mutating state', () {
    expect(() => store.startExam([]), throwsArgumentError);
    expect(
      () => store.startExam([exactQuestion], durationMinutes: 0),
      throwsArgumentError,
    );
    expect(
      () => store.startExam([exactQuestion, exactQuestion]),
      throwsArgumentError,
    );
    expect(
      () => store.startExam([
        exactQuestion,
      ], durationMinutes: 9223372036854775807),
      throwsArgumentError,
    );
    expect(store.activeExam, isNull);
    expect(store.examHistory, isEmpty);
  });

  test(
    'failed saves remain visible and the next successful save retains records',
    () async {
      final failing = _TogglePreferences();
      final persistent = StudyStore(
        preferences: failing,
        initialQuestions: [exactQuestion],
      );
      await persistent.load();
      persistent.recordPracticeAnswer(exactQuestion, '오답');
      await persistent.flush();
      expect(persistent.saveError, isNotNull);
      expect(persistent.wrongFor(exactQuestion.id)!.count, 1);

      failing.failWrites = false;
      persistent.toggleBookmark(exactQuestion.id);
      await persistent.flush();
      expect(persistent.saveError, isNull);
      final restored = StudyStore(
        preferences: failing,
        initialQuestions: [exactQuestion],
      );
      await restored.load();
      expect(restored.isBookmarked(exactQuestion.id), isTrue);
      expect(restored.wrongFor(exactQuestion.id)!.count, 1);
      restored.dispose();
      persistent.dispose();
    },
  );

  test(
    'failed save retries the current state without requiring a new edit',
    () async {
      final failing = _TogglePreferences();
      final persistent = StudyStore(
        preferences: failing,
        initialQuestions: [exactQuestion],
      );
      await persistent.load();
      persistent.toggleBookmark(exactQuestion.id);
      expect(persistent.saving, isTrue);
      await persistent.flush();
      expect(persistent.saving, isFalse);
      expect(persistent.saveError, isNotNull);
      failing.failWrites = false;
      await persistent.retrySave();
      expect(persistent.saveError, isNull);
      expect(persistent.saving, isFalse);
      expect(
        failing.getString(StudyStore.storageKey),
        contains(exactQuestion.id),
      );
      persistent.dispose();
    },
  );

  test(
    'failed recovery backup never overwrites the damaged original',
    () async {
      const raw = '{broken-original';
      final failing = _TogglePreferences()..seed(StudyStore.storageKey, raw);
      final persistent = StudyStore(
        preferences: failing,
        initialQuestions: [exactQuestion],
      );
      await persistent.load();
      expect(persistent.ready, isTrue);
      expect(persistent.saveError, isNotNull);
      expect(persistent.loadWarning, contains('보관에 실패'));
      persistent.toggleBookmark(exactQuestion.id);
      await persistent.flush();
      expect(failing.getString(StudyStore.storageKey), raw);
      expect(failing.getString(StudyStore.recoveryStorageKey), isNull);
      failing.failWrites = false;
      await persistent.retrySave();
      expect(persistent.saveError, isNull);
      expect(persistent.loadWarning, contains('보관했어요'));
      expect(
        failing.getString(StudyStore.storageKey),
        contains(exactQuestion.id),
      );
      expect(
        (jsonDecode(failing.getString(StudyStore.recoveryStorageKey)!)
            as Map)['snapshots'],
        [raw],
      );
      persistent.dispose();
    },
  );

  test(
    'recovery deduplicates originals and preserves an unreadable archive',
    () async {
      const raw = '{broken-original';
      await preferences.setString(StudyStore.storageKey, raw);
      for (var index = 0; index < 2; index++) {
        final recovered = StudyStore(
          preferences: preferences,
          initialQuestions: [exactQuestion],
        );
        await recovered.load();
        recovered.dispose();
      }
      expect(
        (jsonDecode(preferences.getString(StudyStore.recoveryStorageKey)!)
            as Map)['snapshots'],
        [raw],
      );
      const archive = '{broken-archive';
      await preferences.setString(StudyStore.recoveryStorageKey, archive);
      final recovered = StudyStore(
        preferences: preferences,
        initialQuestions: [exactQuestion],
      );
      await recovered.load();
      recovered.toggleBookmark(exactQuestion.id);
      await recovered.flush();
      expect(recovered.saveError, isNotNull);
      expect(preferences.getString(StudyStore.storageKey), raw);
      expect(preferences.getString(StudyStore.recoveryStorageKey), archive);
      recovered.dispose();
    },
  );

  test(
    'typing coalesces pending writes and flush retains the latest memo',
    () async {
      final blocked = _BlockingPreferences();
      final persistent = StudyStore(
        preferences: blocked,
        initialQuestions: [exactQuestion],
      );
      await persistent.load();
      persistent.recordPracticeAnswer(exactQuestion, '오답');
      await blocked.firstWriteStarted.future;
      for (var index = 0; index < 100; index++) {
        persistent.updateWrongMemo(exactQuestion.id, '메모 $index');
      }
      expect(blocked.writeCount, 1);
      expect(persistent.saving, isTrue);
      var flushed = false;
      final flush = persistent.flush().then((_) => flushed = true);
      await Future<void>.delayed(Duration.zero);
      expect(flushed, isFalse);
      blocked.releaseFirstWrite.complete();
      await flush;
      expect(blocked.writeCount, 2);
      expect(persistent.saving, isFalse);
      expect(persistent.saveError, isNull);
      final restored = StudyStore(
        preferences: blocked,
        initialQuestions: [exactQuestion],
      );
      await restored.load();
      expect(restored.wrongFor(exactQuestion.id)!.memo, '메모 99');
      expect(restored.totalAttempts, 1);
      restored.dispose();
      persistent.dispose();
    },
  );
}

class _TogglePreferences implements SharedPreferences {
  final Map<String, String> _strings = {};
  bool failWrites = true;
  bool failReads = false;

  void seed(String key, String value) => _strings[key] = value;

  @override
  String? getString(String key) {
    if (failReads) throw StateError('storage read unavailable');
    return _strings[key];
  }

  @override
  Future<bool> setString(String key, String value) async {
    if (failWrites) return false;
    _strings[key] = value;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _BlockingPreferences implements SharedPreferences {
  final Map<String, String> _strings = {};
  final firstWriteStarted = Completer<void>();
  final releaseFirstWrite = Completer<void>();
  int writeCount = 0;

  @override
  String? getString(String key) => _strings[key];

  @override
  Future<bool> setString(String key, String value) async {
    writeCount++;
    if (writeCount == 1) {
      firstWriteStarted.complete();
      await releaseFirstWrite.future;
    }
    _strings[key] = value;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
