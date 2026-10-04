import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gisa/main.dart';
import 'package:gisa/models.dart';
import 'package:gisa/study_store.dart';

const first = Question(
  id: 'keyword-001',
  categoryId: 'keyword',
  number: 1,
  title: '애자일',
  prompt: '변화하는 요구사항에 능동적으로 대응하는 개발 방법론을 쓰시오.',
  answer: '애자일',
  aliases: ['Agile'],
  explanation: '반복과 피드백을 통해 개발한다.',
);
const second = Question(
  id: 'keyword-002',
  categoryId: 'keyword',
  number: 2,
  title: '리팩토링',
  prompt: '프로그램 구조를 개선하는 목적을 서술하시오.',
  answer: '이해하고 수정하기 쉽게 한다.',
  explanation: '외부 동작을 보존한다.',
  grading: 'manual',
);
const third = Question(
  id: 'sql-001',
  categoryId: 'sql',
  number: 1,
  title: 'SQL 출력',
  prompt: '다음 SQL 결과를 쓰시오.\nSELECT COUNT(*) FROM 학생;',
  answer: '3',
  explanation: '세 행을 센다.',
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<StudyStore> makeStore() async {
    final store = StudyStore(initialQuestions: [first, second, third]);
    await store.load();
    return store;
  }

  Future<void> mount(
    WidgetTester tester,
    StudyStore store, {
    double width = 1440,
  }) async {
    tester.view.physicalSize = Size(width, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MyApp(store: store));
    await tester.pumpAndSettle();
  }

  testWidgets('All eight PDF datasets load exactly 193 unique questions', (
    tester,
  ) async {
    final store = StudyStore();
    await tester.runAsync(store.load);
    expect(store.loadError, isNull);
    expect(store.questions.length, 193);
    expect(store.questions.map((q) => q.id).toSet().length, 193);
    for (final category in categories) {
      expect(store.questionsFor(category.id).length, category.expectedCount);
    }
    store.dispose();
  });

  testWidgets(
    'Practice hides the title answer and records incorrect and correct review',
    (tester) async {
      final store = await makeStore();
      await mount(tester, store);
      await tester.tap(find.text('학습 시작하기'));
      await tester.pumpAndSettle();
      expect(find.text('Q01. 키워드 찾기 문제'), findsOneWidget);
      expect(find.text('애자일'), findsNothing);
      await tester.enterText(find.byType(TextField).last, '워터폴');
      await tester.tap(find.text('답안 확인'));
      await tester.pumpAndSettle();
      expect(store.unresolvedWrongCount, 1);
      expect(find.text('모범답안'), findsOneWidget);
      await tester.tap(find.text('오답노트').first);
      await tester.pumpAndSettle();
      expect(find.text('애자일'), findsOneWidget);
      await tester.tap(find.text('선택 과목 오답 다시 풀기'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Agile');
      await tester.tap(find.text('답안 확인'));
      await tester.pumpAndSettle();
      expect(store.unresolvedWrongCount, 0);
      expect(store.completedIds, contains(first.id));
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );

  testWidgets(
    'Removing a filtered bookmark resets answers and revealed state',
    (tester) async {
      final store = await makeStore();
      store.toggleBookmark(first.id);
      store.toggleBookmark(second.id);
      await mount(tester, store);
      await tester.tap(find.text('학습 시작하기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('북마크'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '워터폴');
      await tester.tap(find.text('정답 · 해설 보기'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('북마크 해제'));
      await tester.pumpAndSettle();
      expect(find.text('Q02. 키워드 찾기 문제'), findsOneWidget);
      expect(find.text('모범답안'), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField).last).controller!.text,
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );

  testWidgets(
    'Restored exam shows saved answer and submits automatic plus manual results',
    (tester) async {
      final store = await makeStore();
      store.startExam([first, second], durationMinutes: 30);
      store.answerExam(first.id, 'Agile');
      store.answerExam(second.id, '쉽게 이해하고 수정하기 위해');
      await store.flush();
      final restored = await makeStore();
      await mount(tester, restored);
      await tester.tap(find.text('모의시험').first);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField).last).controller!.text,
        'Agile',
      );
      expect(find.text('모범답안'), findsNothing);
      await tester.ensureVisible(find.text('시험 제출하기'));
      await tester.tap(find.text('시험 제출하기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('제출하기'));
      await tester.pumpAndSettle();
      expect(restored.examHistory.single.correctCount, 1);
      expect(restored.examHistory.single.pendingCount, 1);
      await tester.ensureVisible(find.text('정답으로 채점'));
      await tester.tap(find.text('정답으로 채점'));
      await tester.pumpAndSettle();
      expect(restored.examHistory.single.score, 100);
      expect(restored.examHistory.single.pendingCount, 0);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
      restored.dispose();
    },
  );

  for (final width in [320.0, 390.0]) {
    testWidgets('Learning and study remain usable at mobile width $width', (
      tester,
    ) async {
      final store = await makeStore();
      await mount(tester, store, width: width);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('학습 시작하기'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    });
  }
}
