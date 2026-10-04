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

  test('output grading preserves spaces and line boundaries', () {
    const question = Question(
      id: 'control-001',
      categoryId: 'control',
      number: 1,
      title: '출력',
      prompt: '출력 결과는?',
      answer: '10 20 30',
      explanation: '',
    );
    expect(question.grade('  10 20 30  '), isTrue);
    expect(question.grade('10\n20 30'), isFalse);
    expect(question.grade('10  20 30'), isFalse);
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
      session.remainingAt(started.subtract(const Duration(minutes: 3))),
      const Duration(minutes: 1),
    );
    expect(
      session.remainingSecondsAt(started.subtract(const Duration(minutes: 3))),
      60,
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

  group('saved exam validation', () {
    final started = DateTime(2026, 10, 4, 12);
    final catalog = {
      exactQuestion.id: exactQuestion,
      manualQuestion.id: manualQuestion,
    };

    Map<String, dynamic> answerJson({
      String? questionId,
      DateTime? answeredAt,
      bool? isCorrect = true,
    }) => QuestionResult(
      questionId: questionId ?? exactQuestion.id,
      userAnswer: '회귀 테스트',
      isCorrect: isCorrect,
      answeredAt: answeredAt ?? started,
    ).toJson();

    Map<String, dynamic> sessionJson() => {
      'id': 'exam-1',
      'questionIds': [exactQuestion.id, manualQuestion.id],
      'startedAt': started.toIso8601String(),
      'durationMinutes': 1,
      'answers': [answerJson()],
      'finishedAt': null,
    };

    Map<String, dynamic> resultJson() => {
      'id': 'exam-1',
      'startedAt': started.toIso8601String(),
      'finishedAt': started.add(const Duration(seconds: 30)).toIso8601String(),
      'results': [answerJson()],
    };

    test('valid active and finished sessions retain every answer', () {
      final active = ExamSession.fromJson(sessionJson(), catalog);
      expect(active.answeredCount, 1);
      final finished = ExamSession.fromJson({
        ...sessionJson(),
        'finishedAt': started
            .add(const Duration(seconds: 30))
            .toIso8601String(),
      }, catalog);
      expect(finished.isFinished, isTrue);
      expect(finished.answerResults.keys, [exactQuestion.id]);
    });

    test('session rejects empty, duplicate, and unknown question lists', () {
      for (final ids in <List<String>>[
        [],
        [exactQuestion.id, exactQuestion.id],
        ['missing'],
      ]) {
        expect(
          () => ExamSession.fromJson({
            ...sessionJson(),
            'questionIds': ids,
          }, catalog),
          throwsFormatException,
        );
      }
    });

    test('session rejects duplicate and unassigned answers', () {
      for (final answers in [
        [answerJson(), answerJson()],
        [answerJson(questionId: 'missing')],
      ]) {
        expect(
          () => ExamSession.fromJson({
            ...sessionJson(),
            'answers': answers,
          }, catalog),
          throwsFormatException,
        );
      }
    });

    test('session requires a positive duration and nonempty identity', () {
      for (final duration in [0, -1, (1 << 62) + 1]) {
        expect(
          () => ExamSession.fromJson({
            ...sessionJson(),
            'durationMinutes': duration,
          }, catalog),
          throwsFormatException,
        );
      }
      expect(
        () => ExamSession.fromJson({...sessionJson(), 'id': ''}, catalog),
        throwsFormatException,
      );
    });

    test('session rejects answers outside its time window', () {
      for (final answeredAt in [
        started.subtract(const Duration(seconds: 1)),
        started.add(const Duration(seconds: 61)),
      ]) {
        expect(
          () => ExamSession.fromJson({
            ...sessionJson(),
            'answers': [answerJson(answeredAt: answeredAt)],
          }, catalog),
          throwsFormatException,
        );
      }
      expect(
        () => ExamSession.fromJson({
          ...sessionJson(),
          'answers': [
            answerJson(answeredAt: started.add(const Duration(seconds: 30))),
          ],
          'finishedAt': started
              .add(const Duration(seconds: 20))
              .toIso8601String(),
        }, catalog),
        throwsFormatException,
      );
    });

    test('session rejects invalid finish time and pending automatic grade', () {
      for (final finishedAt in [
        started.subtract(const Duration(seconds: 1)),
        started.add(const Duration(seconds: 61)),
      ]) {
        expect(
          () => ExamSession.fromJson({
            ...sessionJson(),
            'finishedAt': finishedAt.toIso8601String(),
          }, catalog),
          throwsFormatException,
        );
      }
      expect(
        () => ExamSession.fromJson({
          ...sessionJson(),
          'answers': [answerJson(isCorrect: null)],
        }, catalog),
        throwsFormatException,
      );
      expect(
        ExamSession.fromJson({
          ...sessionJson(),
          'answers': [
            answerJson(questionId: manualQuestion.id, isCorrect: null),
          ],
        }, catalog).pendingCount,
        1,
      );
    });

    test(
      'setAnswer rejects a question from outside the exam and invalid time',
      () {
        final session = ExamSession.fromJson(sessionJson(), catalog);
        for (final answer in [
          answerJson(questionId: 'missing'),
          answerJson(answeredAt: started.subtract(const Duration(seconds: 1))),
        ]) {
          expect(
            () => session.setAnswer(QuestionResult.fromJson(answer)),
            throwsArgumentError,
          );
        }
        expect(session.answeredCount, 1);
      },
    );

    test(
      'exam history rejects empty, duplicate, and chronologically invalid results',
      () {
        for (final results in [
          <Map<String, dynamic>>[],
          [answerJson(), answerJson()],
          [
            answerJson(
              answeredAt: started.subtract(const Duration(seconds: 1)),
            ),
          ],
          [answerJson(answeredAt: started.add(const Duration(seconds: 31)))],
        ]) {
          expect(
            () => ExamResult.fromJson({...resultJson(), 'results': results}),
            throwsFormatException,
          );
        }
        expect(
          () => ExamResult.fromJson({
            ...resultJson(),
            'finishedAt': started
                .subtract(const Duration(seconds: 1))
                .toIso8601String(),
          }),
          throwsFormatException,
        );
        expect(
          () => ExamResult.fromJson({...resultJson(), 'id': '   '}),
          throwsFormatException,
        );
      },
    );

    test('calendar overflow and malformed date fields are rejected', () {
      for (final value in [
        '2026-02-30T12:00:00.000',
        '2026-13-01T12:00:00.000',
        '2026-10-04T24:00:00.000',
        '2026-10-04T12:60:00.000',
        '2026-10-04T12:00:60.000',
        '2026-10-04T12:00:00+24:00',
        'bad date',
      ]) {
        expect(
          () => QuestionResult.fromJson({...answerJson(), 'answeredAt': value}),
          throwsFormatException,
        );
      }
      final valid = QuestionResult.fromJson({
        ...answerJson(),
        'answeredAt': '2024-02-29T12:00:00.123456+09:00',
      });
      expect(valid.answeredAt, DateTime.utc(2024, 2, 29, 3, 0, 0, 123, 456));
    });

    test(
      'wrong answer records require a valid question and positive count',
      () {
        final wrong = WrongAnswer(
          questionId: exactQuestion.id,
          userAnswer: '틀린 답',
          lastAttemptAt: started,
        ).toJson();
        for (final count in [0, -1]) {
          expect(
            () => WrongAnswer.fromJson({...wrong, 'count': count}),
            throwsFormatException,
          );
        }
        expect(
          () => WrongAnswer.fromJson({...wrong, 'questionId': ''}),
          throwsFormatException,
        );
        expect(WrongAnswer.fromJson(wrong).count, 1);
      },
    );
  });
}
