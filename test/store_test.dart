import 'package:flutter_test/flutter_test.dart';
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
}

class _TogglePreferences implements SharedPreferences {
  final Map<String, String> _strings = {};
  bool failWrites = true;

  @override
  String? getString(String key) => _strings[key];

  @override
  Future<bool> setString(String key, String value) async {
    if (failWrites) return false;
    _strings[key] = value;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
