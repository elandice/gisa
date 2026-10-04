import 'package:flutter_test/flutter_test.dart';
import 'package:gisa/models.dart';

const exactQuestion = Question(
  id: 'keyword-001',
  categoryId: 'keyword',
  number: 1,
  title: '회귀 테스트',
  prompt: '변경 후 기존 기능을 확인하는 테스트는?',
  answer: '회귀 테스트',
  aliases: ['Regression Test', '회귀테스트'],
  explanation: '변경이 기존 기능에 영향을 주었는지 확인합니다.',
);

const manualQuestion = Question(
  id: 'sql-001',
  categoryId: 'sql',
  number: 1,
  title: '조회문 작성',
  prompt: '모든 행을 조회하는 SQL을 작성하세요.',
  answer: 'SELECT * FROM student;',
  explanation: '별표는 모든 컬럼을 뜻합니다.',
  grading: 'manual',
);

void main() {
  test('aliases accept case and full-width typing variations', () {
    expect(exactQuestion.grade('  ＲＥＧＲＥＳＳＩＯＮ　ＴＥＳＴ  '), isTrue);
    expect(exactQuestion.grade('regression\n\t test'), isTrue);
    expect(exactQuestion.grade('회귀테스트'), isTrue);
    expect(exactQuestion.grade('regressiontest'), isFalse);
    expect(exactQuestion.grade(''), isFalse);
  });

  test('whitespace normalization preserves output token boundaries', () {
    const question = Question(
      id: 'control-001',
      categoryId: 'control',
      number: 1,
      title: '출력',
      prompt: '출력 결과는?',
      answer: '10 20 30',
      explanation: '',
    );
    expect(question.grade('10\n20   30'), isTrue);
    expect(question.grade('102030'), isFalse);
    expect(normalizeAnswer('[ 1, 2 ]'), '[1,2]');
  });

  test('manual answers are never automatically accepted or rejected', () {
    expect(manualQuestion.grade('SELECT * FROM student;'), isNull);
    expect(manualQuestion.grade('다른 표현의 SQL'), isNull);
    expect(manualQuestion.grade(''), isNull);
  });

  test('question source and grading survive JSON round trip', () {
    final original = Question.fromJson({
      ...manualQuestion.toJson(),
      'source': '정보처리기사실기_02_SQL17문제.pdf',
      'sourcePages': [1, 2],
      'promptAsset': 'assets/pages/sql-01.webp',
    });
    final restored = Question.fromJson(original.toJson());
    expect(restored.isManual, isTrue);
    expect(restored.sourcePages, [1, 2]);
    expect(restored.promptAsset, 'assets/pages/sql-01.webp');
  });

  test('exam result retains pending manual grades and real duration', () {
    final started = DateTime(2026, 10, 4, 12);
    final result = ExamResult(
      id: 'exam-1',
      startedAt: started,
      finishedAt: started.add(const Duration(seconds: 90)),
      results: [
        QuestionResult(
          questionId: exactQuestion.id,
          userAnswer: '회귀 테스트',
          isCorrect: true,
          answeredAt: started,
        ),
        QuestionResult(
          questionId: manualQuestion.id,
          userAnswer: 'SELECT * FROM student;',
          isCorrect: null,
          answeredAt: started,
        ),
      ],
    );
    final restored = ExamResult.fromJson(result.toJson());
    expect(restored.total, 2);
    expect(restored.correctCount, 1);
    expect(restored.pendingCount, 1);
    expect(restored.fullyGraded, isFalse);
    expect(restored.score, 50);
    expect(restored.durationSeconds, 90);
    final graded = restored.withGrade(manualQuestion.id, true);
    expect(graded.score, 100);
    expect(graded.pendingCount, 0);
    expect(restored.pendingCount, 1);
  });

  test('exam remaining time never becomes negative', () {
    final started = DateTime(2026, 10, 4, 12);
    final session = ExamSession(
      id: 'exam',
      questions: [exactQuestion],
      startedAt: started,
      durationMinutes: 1,
    );
    expect(
      session.remainingAt(started.add(const Duration(seconds: 10))).inSeconds,
      50,
    );
    expect(
      session.remainingSecondsAt(
        started.add(const Duration(milliseconds: 59500)),
      ),
      1,
    );
    expect(
      session.remainingSecondsAt(started.add(const Duration(seconds: 60))),
      0,
    );
    expect(
      session.remainingAt(started.add(const Duration(minutes: 3))),
      Duration.zero,
    );
    session.finishedAt = started.add(const Duration(seconds: 20));
    expect(
      session.remainingAt(started.add(const Duration(seconds: 25))),
      Duration.zero,
    );
  });
}
