import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'design.dart';
import 'models.dart';
import 'study_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.store});
  final StudyStore? store;
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final StudyStore store = widget.store ?? StudyStore();
  bool ready = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await store.load();
    if (mounted) setState(() => ready = true);
  }

  @override
  void dispose() {
    if (widget.store == null) store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '차곡 · 정보처리기사 실기',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: canvasColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accentColor,
        surface: canvasColor,
      ),
      fontFamily: 'NotoSansKR',
      textTheme: ThemeData.light().textTheme.apply(
        fontFamily: 'NotoSansKR',
        bodyColor: inkColor,
        displayColor: inkColor,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFE5EBF2),
        hintStyle: const TextStyle(color: mutedColor, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 17,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDCE3ED)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: accentColor),
        ),
      ),
      dividerColor: const Color(0xFFD8DFE9),
      chipTheme: ChipThemeData(
        backgroundColor: canvasColor,
        selectedColor: accentColor.withValues(alpha: .12),
        side: const BorderSide(color: Color(0xFFD4DBE6)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      ),
    ),
    home: !ready
        ? const Scaffold(body: Center(child: CircularProgressIndicator()))
        : store.questions.isEmpty
        ? Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_rounded,
                      size: 48,
                      color: mutedColor,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      '문제를 불러오지 못했어요.',
                      style: TextStyle(fontSize: 22),
                    ),
                    const SizedBox(height: 10),
                    Text(store.loadError ?? '앱을 다시 시작해주세요.'),
                    const SizedBox(height: 20),
                    SoftButton(
                      label: '다시 불러오기',
                      onPressed: () {
                        setState(() => ready = false);
                        _load();
                      },
                    ),
                  ],
                ),
              ),
            ),
          )
        : Workspace(store: store),
  );
}

class Workspace extends StatefulWidget {
  const Workspace({super.key, required this.store});
  final StudyStore store;
  @override
  State<Workspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends State<Workspace> {
  int page = 0;
  String? studyCategory;
  List<Question>? reviewQuestions;
  String? initialQuestionId;
  int studyKey = 0;
  void openStudy({
    String? category,
    List<Question>? questions,
    String? questionId,
  }) {
    setState(() {
      studyCategory = category;
      reviewQuestions = questions;
      initialQuestionId = questionId;
      studyKey++;
      page = 1;
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1000;
        final store = widget.store;
        final screens = [
          LearningHome(
            store: store,
            openStudy: openStudy,
            openExam: () => setState(() => page = 2),
            openWrong: () => setState(() => page = 3),
          ),
          StudyScreen(
            key: ValueKey(studyKey),
            store: store,
            initialCategory: studyCategory,
            reviewQuestions: reviewQuestions,
            initialQuestionId: initialQuestionId,
          ),
          ExamScreen(store: store),
          WrongScreen(store: store, openStudy: openStudy),
        ];
        return Scaffold(
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  backgroundColor: canvasColor,
                  elevation: 0,
                  selectedIndex: page,
                  onDestinationSelected: (index) =>
                      setState(() => page = index),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.grid_view_rounded),
                      label: '학습 홈',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.auto_stories_outlined),
                      label: '학습하기',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.timer_outlined),
                      label: '모의시험',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.edit_note_rounded),
                      label: '오답노트',
                    ),
                  ],
                ),
          body: SafeArea(
            child: Row(
              children: [
                if (wide) SizedBox(width: 230, child: _sidebar(store)),
                Expanded(
                  child: Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          wide ? 38 : 20,
                          20,
                          wide ? 38 : 20,
                          18,
                        ),
                        child: Row(
                          children: [
                            if (!wide) ...[
                              const BrandMark(size: 32),
                              const SizedBox(width: 10),
                              const Text(
                                '차곡',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            if (wide || constraints.maxWidth >= 390)
                              Text(
                                wide ? '나의 학습 공간' : '정보처리기사 실기',
                                style: const TextStyle(
                                  color: mutedColor,
                                  fontSize: 12,
                                ),
                              ),
                            const Spacer(),
                            const Icon(
                              Icons.circle,
                              size: 6,
                              color: greenColor,
                            ),
                            const SizedBox(width: 7),
                            const Text(
                              '기기에 자동 저장',
                              style: TextStyle(color: mutedColor, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      if (store.saveError != null ||
                          store.loadError != null ||
                          store.loadWarning != null)
                        Container(
                          width: double.infinity,
                          color: const Color(0xFFF2E2DE),
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            store.saveError ??
                                store.loadError ??
                                store.loadWarning!,
                            style: const TextStyle(
                              color: redColor,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      Expanded(
                        child: IndexedStack(index: page, children: screens),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
  Widget _sidebar(StudyStore store) => Container(
    decoration: const BoxDecoration(
      border: Border(right: BorderSide(color: Color(0xFFDCE3EC))),
    ),
    padding: const EdgeInsets.fromLTRB(22, 34, 22, 26),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            BrandMark(),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '차곡',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
                Text(
                  '한 문제씩, 단단하게',
                  style: TextStyle(fontSize: 10, color: mutedColor),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 48),
        const Padding(
          padding: EdgeInsets.only(left: 14, bottom: 14),
          child: Text(
            'MY WORKSPACE',
            style: TextStyle(
              fontSize: 9,
              color: mutedColor,
              letterSpacing: 1.8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        for (final (index, icon, label) in [
          (0, Icons.grid_view_rounded, '학습 홈'),
          (1, Icons.auto_stories_outlined, '학습하기'),
          (2, Icons.timer_outlined, '모의시험'),
          (3, Icons.edit_note_rounded, '오답노트'),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(15),
              onTap: () => setState(() => page = index),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: page == index
                      ? const Color(0xFFE3E5F1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: page == index
                      ? [
                          BoxShadow(
                            color: const Color(
                              0xFFC8D0E0,
                            ).withValues(alpha: .5),
                            offset: const Offset(2, 2),
                            blurRadius: 5,
                            spreadRadius: -2,
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      size: 20,
                      color: page == index ? accentColor : mutedColor,
                    ),
                    const SizedBox(width: 13),
                    Text(
                      label,
                      style: TextStyle(
                        color: page == index ? accentColor : mutedColor,
                        fontSize: 13,
                        fontWeight: page == index
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    if (index == 3 &&
                        store.wrongAnswers.values.any((e) => !e.resolved)) ...[
                      const Spacer(),
                      Tag(
                        '${store.wrongAnswers.values.where((e) => !e.resolved).length}',
                        color: redColor,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        const Spacer(),
        SoftCard(
          padding: const EdgeInsets.all(17),
          radius: 17,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.layers_outlined, size: 18, color: accentColor),
                  SizedBox(width: 8),
                  Text(
                    '나의 문제집',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '8개 과목 · ${store.questions.length}문제',
                style: const TextStyle(fontSize: 12, color: mutedColor),
              ),
              const SizedBox(height: 13),
              ProgressTrack(store.completedIds.length / store.questions.length),
              const SizedBox(height: 8),
              Text(
                '${store.completedIds.length}문제 학습 완료',
                style: const TextStyle(color: mutedColor, fontSize: 10),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Center(
          child: Text(
            '작은 반복이 만드는 큰 변화',
            style: TextStyle(color: mutedColor, fontSize: 10),
          ),
        ),
      ],
    ),
  );
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 43});
  final double size;
  @override
  Widget build(BuildContext context) => SoftCard(
    padding: EdgeInsets.zero,
    radius: size / 3,
    color: const Color(0xFFE5E5F2),
    child: SizedBox(
      width: size,
      height: size,
      child: Icon(Icons.layers_rounded, size: size * .6, color: accentColor),
    ),
  );
}

typedef OpenStudy =
    void Function({
      String? category,
      List<Question>? questions,
      String? questionId,
    });

class LearningHome extends StatelessWidget {
  const LearningHome({
    super.key,
    required this.store,
    required this.openStudy,
    required this.openExam,
    required this.openWrong,
  });
  final StudyStore store;
  final OpenStudy openStudy;
  final VoidCallback openExam, openWrong;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 650;
      final done = store.completedIds.length;
      final total = store.questions.length;
      final wrong = store.wrongAnswers.values.where((e) => !e.resolved).length;
      final next = store.questions.firstWhere(
        (q) => !store.completedIds.contains(q.id),
        orElse: () => store.questions.first,
      );
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          compact ? 20 : 38,
          12,
          compact ? 20 : 38,
          36,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'A LITTLE EVERY DAY',
              style: TextStyle(
                fontSize: 10,
                color: accentColor,
                letterSpacing: 2,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 13),
            const Text(
              '오늘도 한 걸음 더.',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.6,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '배우고, 풀고, 다시 기억하기. 나만의 속도로 실기를 준비해요.',
              style: TextStyle(color: mutedColor, fontSize: 13, height: 1.6),
            ),
            const SizedBox(height: 28),
            SoftCard(
              padding: EdgeInsets.all(compact ? 22 : 28),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Tag('오늘의 학습'),
                        const SizedBox(height: 16),
                        Text(
                          done == 0 ? '첫 문제부터 차곡차곡' : '배움을 이어갈 시간',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.7,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${categoryName(next.categoryId)} · ${next.number.toString().padLeft(2, '0')}번부터 시작해요.',
                          style: const TextStyle(
                            color: mutedColor,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 22),
                        SoftButton(
                          label: done == 0 ? '학습 시작하기' : '이어서 학습하기',
                          icon: Icons.arrow_forward_rounded,
                          primary: true,
                          onPressed: () => openStudy(
                            category: next.categoryId,
                            questionId: next.id,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(width: 24),
                    SizedBox(
                      width: 140,
                      height: 140,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SoftCard(
                            radius: 80,
                            padding: EdgeInsets.zero,
                            child: const SizedBox(width: 140, height: 140),
                          ),
                          SizedBox(
                            width: 118,
                            height: 118,
                            child: CircularProgressIndicator(
                              value: done / total,
                              strokeWidth: 8,
                              strokeCap: StrokeCap.round,
                              color: accentColor,
                              backgroundColor: const Color(0xFFDCE2EC),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${(done / total * 100).round()}%',
                                style: const TextStyle(
                                  fontSize: 27,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Text(
                                '전체 학습률',
                                style: TextStyle(
                                  color: mutedColor,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 25),
            Row(
              children: [
                Expanded(
                  child: _stat(
                    Icons.check_circle_outline_rounded,
                    greenColor,
                    '$done',
                    '학습한 문제',
                    compact,
                  ),
                ),
                SizedBox(width: compact ? 12 : 20),
                Expanded(
                  child: _stat(
                    Icons.edit_note_rounded,
                    redColor,
                    '$wrong',
                    '복습할 오답',
                    compact,
                    openWrong,
                  ),
                ),
                SizedBox(width: compact ? 12 : 20),
                Expanded(
                  child: _stat(
                    Icons.timer_outlined,
                    accentColor,
                    '${store.examHistory.length}',
                    '완료한 시험',
                    compact,
                    openExam,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 34),
            Row(
              children: [
                const Text(
                  '과목별 학습',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.5,
                  ),
                ),
                const Spacer(),
                Text(
                  '8개 과목  /  $total문제',
                  style: const TextStyle(color: mutedColor, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '필요한 과목을 골라 한 문제씩 익혀보세요.',
              style: TextStyle(color: mutedColor, fontSize: 12),
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, c) {
                final columns = c.maxWidth > 1050
                    ? 4
                    : c.maxWidth > 570
                    ? 3
                    : 2;
                return Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  children: [
                    for (final cat in categories)
                      SizedBox(
                        width: (c.maxWidth - (columns - 1) * 20) / columns,
                        child: _category(cat),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 30),
            Wrap(
              spacing: 20,
              runSpacing: 16,
              children: [
                SoftButton(
                  label: '실전 감각을 위한 모의시험',
                  icon: Icons.timer_outlined,
                  onPressed: openExam,
                ),
                SoftButton(
                  label: '오답을 다시 내 것으로',
                  icon: Icons.edit_note_rounded,
                  onPressed: openWrong,
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
  Widget _stat(
    IconData icon,
    Color color,
    String value,
    String label,
    bool compact, [
    VoidCallback? onTap,
  ]) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(20),
    child: SoftCard(
      radius: 20,
      padding: EdgeInsets.all(compact ? 14 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: compact ? 22 : 27,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Text(
            label,
            style: TextStyle(color: mutedColor, fontSize: compact ? 10 : 12),
          ),
        ],
      ),
    ),
  );
  Widget _category(StudyCategory cat) {
    final questions = store.questions
        .where((q) => q.categoryId == cat.id)
        .toList();
    final learned = questions
        .where((q) => store.completedIds.contains(q.id))
        .length;
    final color = categoryColor(cat.id);
    return InkWell(
      onTap: () => openStudy(category: cat.id),
      borderRadius: BorderRadius.circular(23),
      child: SoftCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .09),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(categoryIcon(cat.id), color: color, size: 22),
                ),
                const Spacer(),
                const Icon(
                  Icons.arrow_outward_rounded,
                  color: mutedColor,
                  size: 16,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              cat.name,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 5),
            Text(
              cat.subtitle,
              style: const TextStyle(color: mutedColor, fontSize: 10),
            ),
            const SizedBox(height: 18),
            ProgressTrack(
              questions.isEmpty ? 0 : learned / questions.length,
              color: color,
            ),
            const SizedBox(height: 10),
            Text(
              '$learned / ${questions.length}문제',
              style: const TextStyle(color: mutedColor, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

String categoryName(String id) => categories.firstWhere((c) => c.id == id).name;

class QuestionBody extends StatelessWidget {
  const QuestionBody({super.key, required this.question});
  final Question question;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      PromptText(question.prompt, sql: question.categoryId == 'sql'),
      if (question.promptAsset != null) ...[
        const SizedBox(height: 20),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(
            question.promptAsset!,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stack) => const Text(
              '도표를 불러올 수 없어요. 앱을 다시 시작해주세요.',
              style: TextStyle(color: redColor),
            ),
          ),
        ),
      ],
      if ((question.code ?? '').isNotEmpty) ...[
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFDFE6EF),
            borderRadius: BorderRadius.circular(15),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SelectableText(
              question.code!,
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontFamilyFallback: ['NotoSansKR'],
                fontSize: 13,
                height: 1.7,
                color: Color(0xFF3C4961),
              ),
            ),
          ),
        ),
      ],
    ],
  );
}

class PromptText extends StatelessWidget {
  const PromptText(this.text, {super.key, this.sql = false});
  final String text;
  final bool sql;
  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    final blocks = <({bool code, String text})>[];
    bool sqlActive = false;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final startsSql =
          sql &&
          RegExp(
            r'^[①②③④⑤\s]*(SELECT|CREATE|INSERT|UPDATE|DELETE|ALTER|DROP|GRANT|REVOKE|FROM|WHERE|GROUP BY|ORDER BY|HAVING)\b',
            caseSensitive: false,
          ).hasMatch(line);
      if (startsSql) sqlActive = true;
      final table =
          RegExp(r'\S\s{2,}\S').hasMatch(line) ||
          (i + 1 < lines.length &&
              RegExp(r'^\d+\s+\S+\s+\S+').hasMatch(lines[i + 1])) ||
          RegExp(r'^\d+\s+\S+\s+\S+').hasMatch(line);
      final code = line.trim().isNotEmpty && (sqlActive || table);
      if (blocks.isNotEmpty && blocks.last.code == code) {
        final previous = blocks.removeLast();
        blocks.add((code: code, text: '${previous.text}\n$line'));
      } else {
        blocks.add((code: code, text: line));
      }
      if (line.trim().endsWith(';') || line.trim().isEmpty) sqlActive = false;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final block in blocks)
          if (block.text.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: block.code
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(17),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDFE6EF),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SelectableText(
                          block.text.trim(),
                          style: const TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontFamilyFallback: ['NotoSansKR'],
                            fontSize: 13,
                            height: 1.8,
                          ),
                        ),
                      ),
                    )
                  : SelectableText(
                      block.text.trim(),
                      style: const TextStyle(fontSize: 15, height: 1.9),
                    ),
            ),
      ],
    );
  }
}

class AnswerBody extends StatelessWidget {
  const AnswerBody({super.key, required this.question});
  final Question question;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: const Color(0xFFE0EAE8),
      borderRadius: BorderRadius.circular(17),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 18,
              color: greenColor,
            ),
            SizedBox(width: 8),
            Text(
              '모범답안',
              style: TextStyle(
                color: greenColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SelectableText(
          question.answer,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            height: 1.8,
          ),
        ),
        if (question.explanation.isNotEmpty) ...[
          const SizedBox(height: 18),
          const Text(
            '풀이 · 기억할 포인트',
            style: TextStyle(
              color: greenColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            question.explanation,
            style: const TextStyle(fontSize: 13, height: 1.85),
          ),
        ],
      ],
    ),
  );
}

class SourceLabel extends StatelessWidget {
  const SourceLabel(this.question, {super.key});
  final Question question;
  @override
  Widget build(BuildContext context) => Text(
    '출처: ${question.source} · ${question.sourcePages.join(', ')}쪽',
    style: const TextStyle(color: mutedColor, fontSize: 10, height: 1.6),
  );
}

class StudyScreen extends StatefulWidget {
  const StudyScreen({
    super.key,
    required this.store,
    this.initialCategory,
    this.reviewQuestions,
    this.initialQuestionId,
  });
  final StudyStore store;
  final String? initialCategory, initialQuestionId;
  final List<Question>? reviewQuestions;
  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  late String category = widget.initialCategory ?? 'keyword';
  String search = '';
  bool bookmarksOnly = false;
  int index = 0;
  bool reveal = false;
  bool recorded = false;
  bool? correct;
  String? inputError;
  final answerController = TextEditingController();
  @override
  void initState() {
    super.initState();
    if (widget.initialQuestionId != null) {
      index = filtered
          .indexWhere((q) => q.id == widget.initialQuestionId)
          .clamp(0, max(0, filtered.length - 1));
    }
  }

  @override
  void dispose() {
    answerController.dispose();
    super.dispose();
  }

  List<Question> get filtered =>
      (widget.reviewQuestions ?? widget.store.questions)
          .where(
            (q) =>
                (widget.reviewQuestions != null ||
                    category == 'all' ||
                    q.categoryId == category) &&
                (!bookmarksOnly || widget.store.bookmarkedIds.contains(q.id)) &&
                (search.isEmpty ||
                    '${q.title} ${q.prompt} ${q.code}'.toLowerCase().contains(
                      search.toLowerCase(),
                    )),
          )
          .toList();
  void changeQuestion(int next) => setState(() {
    index = next;
    reveal = false;
    recorded = false;
    correct = null;
    inputError = null;
    answerController.clear();
  });
  Future<void> check(Question question, {bool? manual}) async {
    if (recorded) return;
    if (manual == null && answerController.text.trim().isEmpty) {
      setState(() => inputError = '답안을 입력하거나 아래에서 정답을 펼쳐보세요.');
      return;
    }
    final grade = widget.store.recordPracticeAnswer(
      question,
      answerController.text,
      manualCorrect: manual,
    );
    if (!mounted) return;
    setState(() {
      reveal = true;
      correct = grade;
      recorded = grade != null;
      inputError = null;
    });
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 880;
      final questions = filtered;
      final current = questions.isEmpty
          ? null
          : questions[index.clamp(0, questions.length - 1)];
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(wide ? 38 : 20, 10, wide ? 38 : 20, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(
              widget.reviewQuestions != null ? '오답 다시 풀기' : '한 문제씩, 차곡차곡',
              subtitle: widget.reviewQuestions != null
                  ? '다시 풀고 맞힌 문제는 복습 완료로 기록돼요.'
                  : '먼저 떠올려보고, 정답과 해설로 기억을 단단하게 만들어보세요.',
            ),
            const SizedBox(height: 25),
            if (widget.reviewQuestions == null)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final cat in categories)
                    ChoiceChip(
                      label: Text(
                        cat.name,
                        style: const TextStyle(fontSize: 12),
                      ),
                      selected: category == cat.id,
                      onSelected: (_) {
                        category = cat.id;
                        changeQuestion(0);
                      },
                    ),
                ],
              ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (v) {
                      search = v;
                      changeQuestion(0);
                    },
                    decoration: const InputDecoration(
                      hintText: '문제나 키워드 검색',
                      prefixIcon: Icon(Icons.search_rounded, size: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilterChip(
                  label: const Text('북마크', style: TextStyle(fontSize: 12)),
                  avatar: const Icon(Icons.bookmark_outline_rounded, size: 17),
                  selected: bookmarksOnly,
                  onSelected: (v) {
                    bookmarksOnly = v;
                    changeQuestion(0);
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (current == null)
              const Padding(
                padding: EdgeInsets.all(35),
                child: Center(
                  child: Text(
                    '조건에 맞는 문제가 없어요.',
                    style: TextStyle(color: mutedColor),
                  ),
                ),
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (wide) ...[
                    SizedBox(
                      width: 225,
                      child: SoftCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '문제 목록  ${questions.length}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 15),
                            SizedBox(
                              height: 430,
                              child: ListView.builder(
                                itemCount: questions.length,
                                itemBuilder: (context, i) {
                                  final q = questions[i];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 5),
                                    child: ListTile(
                                      dense: true,
                                      selected: q.id == current.id,
                                      selectedColor: accentColor,
                                      selectedTileColor: accentColor.withValues(
                                        alpha: .09,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 9,
                                          ),
                                      leading: Text(
                                        q.number.toString().padLeft(2, '0'),
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      title: Text(
                                        q.prompt.replaceAll('\n', ' '),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      trailing:
                                          widget.store.completedIds.contains(
                                            q.id,
                                          )
                                          ? const Icon(
                                              Icons.check_rounded,
                                              color: greenColor,
                                              size: 15,
                                            )
                                          : null,
                                      onTap: () => changeQuestion(i),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                  ],
                  Expanded(
                    child: SoftCard(
                      padding: EdgeInsets.all(wide ? 28 : 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Wrap(
                                  spacing: 9,
                                  runSpacing: 8,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Tag(
                                      categoryName(current.categoryId),
                                      color: categoryColor(current.categoryId),
                                    ),
                                    Text(
                                      '${index.clamp(0, questions.length - 1) + 1} / ${questions.length}',
                                      style: const TextStyle(
                                        color: mutedColor,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip:
                                    widget.store.bookmarkedIds.contains(
                                      current.id,
                                    )
                                    ? '북마크 해제'
                                    : '북마크 저장',
                                onPressed: () {
                                  widget.store.toggleBookmark(current.id);
                                  if (bookmarksOnly) {
                                    changeQuestion(
                                      index.clamp(
                                        0,
                                        max(0, filtered.length - 1),
                                      ),
                                    );
                                  }
                                },
                                icon: Icon(
                                  widget.store.bookmarkedIds.contains(
                                        current.id,
                                      )
                                      ? Icons.bookmark_rounded
                                      : Icons.bookmark_outline_rounded,
                                  color: accentColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Q${current.number.toString().padLeft(2, '0')}. ${reveal ? current.title : '${categoryName(current.categoryId)} 문제'}',
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 22),
                          QuestionBody(question: current),
                          const SizedBox(height: 24),
                          TextField(
                            controller: answerController,
                            minLines: 2,
                            maxLines: 8,
                            readOnly: recorded,
                            decoration: InputDecoration(
                              hintText: current.isManual
                                  ? '서술형 답안이나 SQL을 입력해보세요.'
                                  : '기억나는 답을 적어보세요.',
                              errorText: inputError,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              SoftButton(
                                label: '답안 확인',
                                icon: Icons.check_rounded,
                                primary: true,
                                onPressed: recorded
                                    ? null
                                    : () => check(current),
                              ),
                              SoftButton(
                                label: reveal ? '정답 접기' : '정답 · 해설 보기',
                                icon: reveal
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                onPressed: () =>
                                    setState(() => reveal = !reveal),
                              ),
                            ],
                          ),
                          if (recorded) ...[
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Icon(
                                  correct == true
                                      ? Icons.check_circle_rounded
                                      : Icons.replay_rounded,
                                  color: correct == true
                                      ? greenColor
                                      : redColor,
                                  size: 19,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    correct == true
                                        ? '잘했어요! 학습 완료로 기록했어요.'
                                        : '오답노트에 저장했어요. 다시 보면 더 오래 기억해요.',
                                    style: TextStyle(
                                      color: correct == true
                                          ? greenColor
                                          : redColor,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (reveal) ...[
                            const SizedBox(height: 24),
                            AnswerBody(question: current),
                            if (!recorded) ...[
                              const SizedBox(height: 16),
                              Text(
                                current.isManual
                                    ? '모범답안과 비교한 뒤 직접 채점해주세요.'
                                    : '정답을 확인했어요. 이해한 정도를 기록해보세요.',
                                style: const TextStyle(
                                  color: mutedColor,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  SoftButton(
                                    label: '맞혔어요',
                                    icon: Icons.check_rounded,
                                    color: greenColor,
                                    onPressed: () =>
                                        check(current, manual: true),
                                  ),
                                  SoftButton(
                                    label: '다시 볼게요',
                                    icon: Icons.replay_rounded,
                                    color: redColor,
                                    onPressed: () =>
                                        check(current, manual: false),
                                  ),
                                ],
                              ),
                            ],
                          ],
                          const SizedBox(height: 25),
                          SourceLabel(current),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              SoftButton(
                                label: '이전',
                                small: true,
                                icon: Icons.chevron_left_rounded,
                                onPressed: index > 0
                                    ? () => changeQuestion(index - 1)
                                    : null,
                              ),
                              const Spacer(),
                              SoftButton(
                                label: '다음 문제',
                                small: true,
                                icon: Icons.chevron_right_rounded,
                                onPressed: index < questions.length - 1
                                    ? () => changeQuestion(index + 1)
                                    : null,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      );
    },
  );
}

class ExamScreen extends StatefulWidget {
  const ExamScreen({super.key, required this.store});
  final StudyStore store;
  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> {
  final selected = categories.map((c) => c.id).toSet();
  int count = 20, minutes = 30, index = 0;
  ExamResult? result;
  Timer? timer;
  final answerController = TextEditingController();
  @override
  void initState() {
    super.initState();
    final restored = widget.store.activeExam;
    if (restored != null && !restored.isFinished) {
      answerController.text =
          restored.answers[restored.questions.first.id] ?? '';
    }
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final exam = widget.store.activeExam;
      if (exam != null && !exam.isFinished) {
        if (exam.remainingSeconds <= 0) {
          if (submitting) Navigator.of(context).pop(false);
          submitting = false;
          submit(confirm: false);
        } else if (mounted) {
          setState(() {});
        }
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    answerController.dispose();
    super.dispose();
  }

  List<Question> get pool => widget.store.questions
      .where((q) => selected.contains(q.categoryId))
      .toList();
  void start() {
    final questions = pool..shuffle(Random());
    if (questions.isEmpty) return;
    widget.store.startExam(
      questions.take(min(count, questions.length)).toList(),
      durationMinutes: minutes,
    );
    setState(() {
      index = 0;
      result = null;
      answerController.clear();
    });
  }

  void goto(int next) {
    final exam = widget.store.activeExam!;
    setState(() {
      index = next;
      answerController.text = exam.answers[exam.questions[index].id] ?? '';
    });
  }

  bool submitting = false;
  Future<void> submit({bool confirm = true}) async {
    if (submitting) return;
    final exam = widget.store.activeExam;
    if (exam == null || exam.isFinished) return;
    submitting = true;
    if (confirm) {
      final remaining = exam.questions
          .where((q) => (exam.answers[q.id] ?? '').trim().isEmpty)
          .length;
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: canvasColor,
          title: const Text('시험을 제출할까요?'),
          content: Text(
            remaining > 0
                ? '아직 $remaining문제에 답하지 않았어요. 제출 후 정답과 해설을 확인할 수 있어요.'
                : '모든 답안을 작성했어요. 결과를 확인해보세요.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('계속 풀기'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('제출하기'),
            ),
          ],
        ),
      );
      if (accepted != true) {
        submitting = false;
        return;
      }
    }
    final finished = widget.store.finishExam();
    submitting = false;
    if (!mounted) return;
    setState(() => result = finished);
  }

  @override
  Widget build(BuildContext context) {
    if (result != null) {
      final updated =
          widget.store.examHistory
              .where((r) => r.id == result!.id)
              .firstOrNull ??
          result!;
      return ExamResults(
        store: widget.store,
        result: updated,
        onBack: () => setState(() => result = null),
      );
    }
    final exam = widget.store.activeExam;
    if (exam != null && !exam.isFinished) return _active(exam);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle(
                '실전처럼 풀어보기',
                subtitle: '원하는 과목과 문제 수를 선택하세요. 시험 중에는 정답이 숨겨져요.',
              ),
              const SizedBox(height: 28),
              SoftCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '01  출제 과목',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '여러 과목을 함께 선택할 수 있어요.',
                      style: TextStyle(color: mutedColor, fontSize: 12),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final cat in categories)
                          FilterChip(
                            label: Text(
                              '${cat.name}  ${widget.store.questions.where((q) => q.categoryId == cat.id).length}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            selected: selected.contains(cat.id),
                            onSelected: (v) => setState(() {
                              if (v) {
                                selected.add(cat.id);
                              } else {
                                selected.remove(cat.id);
                              }
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      '02  문제 수',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final n in [10, 20, 30, 50, 193])
                          ChoiceChip(
                            label: Text(n == 193 ? '전체 문제' : '$n문제'),
                            selected: count == n,
                            onSelected: (_) => setState(() => count = n),
                          ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      '03  제한 시간',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final n in [10, 20, 30, 60, 150])
                          ChoiceChip(
                            label: Text('$n분'),
                            selected: minutes == n,
                            onSelected: (_) => setState(() => minutes = n),
                          ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(17),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE4E6F0),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Text(
                        pool.isEmpty
                            ? '출제 과목을 하나 이상 선택해주세요.'
                            : '${min(count, pool.length)}문제 · $minutes분 · 과목 내 무작위 출제\n서술형과 SQL 작성 문제는 제출 후 모범답안을 보고 직접 채점해요.',
                        style: const TextStyle(
                          color: mutedColor,
                          fontSize: 12,
                          height: 1.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),
                    SoftButton(
                      label: '시험 시작하기',
                      primary: true,
                      icon: Icons.play_arrow_rounded,
                      onPressed: pool.isEmpty ? null : start,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                '지난 시험 기록',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              if (widget.store.examHistory.isEmpty)
                const SoftCard(
                  child: Row(
                    children: [
                      Icon(Icons.history_rounded, color: mutedColor),
                      SizedBox(width: 15),
                      Expanded(
                        child: Text(
                          '첫 시험을 완료하면 기록이 여기에 쌓여요.',
                          style: TextStyle(color: mutedColor, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              for (final r in widget.store.examHistory.take(10))
                Padding(
                  padding: const EdgeInsets.only(bottom: 13),
                  child: InkWell(
                    onTap: () => setState(() => result = r),
                    borderRadius: BorderRadius.circular(20),
                    child: SoftCard(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.assignment_outlined,
                            color: accentColor,
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${dateLabel(r.startedAt)} · ${r.total}문제',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  r.pendingCount > 0
                                      ? '${r.pendingCount}문제 직접 채점이 필요해요'
                                      : '정답 ${r.correctCount} · 오답 ${r.incorrectCount}',
                                  style: const TextStyle(
                                    color: mutedColor,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${r.score.round()}점',
                            style: const TextStyle(
                              color: accentColor,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: mutedColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _active(ExamSession exam) {
    index = index.clamp(0, exam.questions.length - 1);
    final question = exam.questions[index];
    final seconds = exam.remainingSeconds;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(
                '모의시험',
                subtitle:
                    '${exam.questions.length}문제 중 ${exam.answers.values.where((a) => a.trim().isNotEmpty).length}문제 답안 작성',
                trailing: Tag(
                  '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}',
                  color: seconds < 120 ? redColor : accentColor,
                ),
              ),
              const SizedBox(height: 22),
              ProgressTrack((index + 1) / exam.questions.length),
              const SizedBox(height: 22),
              SoftCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Tag(categoryName(question.categoryId)),
                        const Spacer(),
                        Text(
                          '${index + 1} / ${exam.questions.length}',
                          style: const TextStyle(
                            color: mutedColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Text(
                      '문제 ${index + 1}',
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 20),
                    QuestionBody(question: question),
                    const SizedBox(height: 25),
                    TextField(
                      controller: answerController,
                      minLines: 3,
                      maxLines: 10,
                      onChanged: (v) => widget.store.answerExam(question.id, v),
                      decoration: const InputDecoration(
                        hintText: '답안을 입력하세요. 이동해도 작성한 내용은 유지돼요.',
                      ),
                    ),
                    const SizedBox(height: 23),
                    Row(
                      children: [
                        SoftButton(
                          label: '이전 문제',
                          small: true,
                          onPressed: index == 0 ? null : () => goto(index - 1),
                        ),
                        const Spacer(),
                        SoftButton(
                          label: '다음 문제',
                          small: true,
                          primary: true,
                          onPressed: index == exam.questions.length - 1
                              ? null
                              : () => goto(index + 1),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),
              const Text(
                '문제 이동',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
              const SizedBox(height: 13),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < exam.questions.length; i++)
                    Tooltip(
                      message:
                          (exam.answers[exam.questions[i].id] ?? '')
                              .trim()
                              .isEmpty
                          ? '미응답'
                          : '답안 작성',
                      child: InkWell(
                        onTap: () => goto(i),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 38,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: i == index
                                ? accentColor
                                : (exam.answers[exam.questions[i].id] ?? '')
                                      .trim()
                                      .isNotEmpty
                                ? const Color(0xFFDCE8E3)
                                : const Color(0xFFE2E7EF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white),
                          ),
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              color: i == index ? Colors.white : inkColor,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 25),
              SoftButton(
                label: '시험 제출하기',
                primary: true,
                icon: Icons.task_alt_rounded,
                onPressed: submitting ? null : () => submit(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ExamResults extends StatelessWidget {
  const ExamResults({
    super.key,
    required this.store,
    required this.result,
    required this.onBack,
  });
  final StudyStore store;
  final ExamResult result;
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(
              '한 번 더 성장했어요',
              subtitle:
                  '${dateLabel(result.startedAt)} · ${result.total}문제 · ${(result.durationSeconds / 60).ceil()}분 소요',
            ),
            const SizedBox(height: 26),
            SoftCard(
              child: Column(
                children: [
                  Text(
                    result.pendingCount > 0 ? '직접 채점 진행 중' : '시험 결과',
                    style: const TextStyle(color: mutedColor, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${result.score.round()}점',
                    style: const TextStyle(
                      fontSize: 46,
                      fontWeight: FontWeight.w800,
                      color: accentColor,
                      letterSpacing: -2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      Tag('정답 ${result.correctCount}', color: greenColor),
                      Tag('오답 ${result.incorrectCount}', color: redColor),
                      if (result.pendingCount > 0)
                        Tag('채점 대기 ${result.pendingCount}'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    result.pendingCount > 0
                        ? '아래 문제를 직접 채점하면 최종 점수와 오답노트가 갱신돼요.'
                        : '틀린 문제는 오답노트에 자동 저장했어요.',
                    style: const TextStyle(color: mutedColor, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),
            SoftButton(
              label: '시험 설정으로 돌아가기',
              icon: Icons.arrow_back_rounded,
              onPressed: onBack,
            ),
            const SizedBox(height: 25),
            for (var i = 0; i < result.questionResults.length; i++)
              _resultItem(result.questionResults[i], i),
          ],
        ),
      ),
    ),
  );
  Widget _resultItem(QuestionResult entry, int index) {
    final question = store.questions.firstWhere(
      (q) => q.id == entry.questionId,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: SoftCard(
        padding: const EdgeInsets.all(18),
        child: ExpansionTile(
          initiallyExpanded: entry.correct == null,
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(top: 14),
          shape: const Border(),
          collapsedShape: const Border(),
          leading: Icon(
            entry.correct == null
                ? Icons.rate_review_outlined
                : entry.correct!
                ? Icons.check_circle_outline_rounded
                : Icons.cancel_outlined,
            color: entry.correct == null
                ? accentColor
                : entry.correct!
                ? greenColor
                : redColor,
          ),
          title: Text(
            '${index + 1}. ${question.title}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            '${categoryName(question.categoryId)} · ${entry.correct == null
                ? '직접 채점 필요'
                : entry.correct!
                ? '정답'
                : '오답'}',
            style: const TextStyle(fontSize: 11, color: mutedColor),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  QuestionBody(question: question),
                  const SizedBox(height: 20),
                  const Text(
                    '나의 답안',
                    style: TextStyle(color: mutedColor, fontSize: 11),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    entry.userAnswer.trim().isEmpty
                        ? '(미응답)'
                        : entry.userAnswer,
                    style: const TextStyle(fontSize: 14, height: 1.8),
                  ),
                  const SizedBox(height: 20),
                  AnswerBody(question: question),
                  if (entry.correct == null) ...[
                    const SizedBox(height: 18),
                    const Text(
                      '핵심 내용이 맞는지 모범답안과 비교해주세요.',
                      style: TextStyle(color: mutedColor, fontSize: 12),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SoftButton(
                          label: '정답으로 채점',
                          color: greenColor,
                          icon: Icons.check_rounded,
                          onPressed: () => store.gradeExamQuestion(
                            question.id,
                            true,
                            examId: result.id,
                          ),
                        ),
                        SoftButton(
                          label: '오답으로 채점',
                          color: redColor,
                          icon: Icons.close_rounded,
                          onPressed: () => store.gradeExamQuestion(
                            question.id,
                            false,
                            examId: result.id,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  SourceLabel(question),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WrongScreen extends StatefulWidget {
  const WrongScreen({super.key, required this.store, required this.openStudy});
  final StudyStore store;
  final OpenStudy openStudy;
  @override
  State<WrongScreen> createState() => _WrongScreenState();
}

class _WrongScreenState extends State<WrongScreen> {
  bool showResolved = false;
  String category = 'all';
  @override
  Widget build(BuildContext context) {
    final records =
        widget.store.wrongAnswers.values
            .where(
              (r) =>
                  r.resolved == showResolved &&
                  (category == 'all' ||
                      widget.store.questions.any(
                        (q) => q.id == r.questionId && q.categoryId == category,
                      )),
            )
            .toList()
          ..sort((a, b) => b.lastAttemptAt.compareTo(a.lastAttemptAt));
    final questions = records
        .map(
          (r) => widget.store.questions.firstWhere((q) => q.id == r.questionId),
        )
        .toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle(
                '다시 보면, 내 것이 돼요',
                subtitle: '틀린 문제를 모아두고, 이유를 적고, 다시 풀어보세요.',
              ),
              const SizedBox(height: 26),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ChoiceChip(
                    label: Text(
                      '복습할 문제 ${widget.store.wrongAnswers.values.where((r) => !r.resolved).length}',
                    ),
                    selected: !showResolved,
                    onSelected: (_) => setState(() => showResolved = false),
                  ),
                  ChoiceChip(
                    label: Text(
                      '복습 완료 ${widget.store.wrongAnswers.values.where((r) => r.resolved).length}',
                    ),
                    selected: showResolved,
                    onSelected: (_) => setState(() => showResolved = true),
                  ),
                  SoftButton(
                    label: '선택 과목 오답 다시 풀기',
                    small: true,
                    primary: true,
                    icon: Icons.replay_rounded,
                    onPressed: questions.isEmpty
                        ? null
                        : () => widget.openStudy(questions: questions),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('전체', style: TextStyle(fontSize: 11)),
                    selected: category == 'all',
                    onSelected: (_) => setState(() => category = 'all'),
                  ),
                  for (final cat in categories)
                    ChoiceChip(
                      label: Text(
                        cat.name,
                        style: const TextStyle(fontSize: 11),
                      ),
                      selected: category == cat.id,
                      onSelected: (_) => setState(() => category = cat.id),
                    ),
                ],
              ),
              const SizedBox(height: 25),
              if (records.isEmpty)
                SoftCard(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 35),
                      child: Column(
                        children: [
                          Icon(
                            showResolved
                                ? Icons.task_alt_rounded
                                : Icons.auto_stories_rounded,
                            size: 45,
                            color: accentColor,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            showResolved
                                ? '아직 복습 완료한 문제가 없어요.'
                                : '아직 쌓인 오답이 없어요.',
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            '학습하거나 시험을 풀면 틀린 문제가 여기에 저장돼요.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: mutedColor,
                              fontSize: 12,
                              height: 1.7,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              for (final record in records)
                WrongCard(
                  key: ValueKey(record.questionId),
                  store: widget.store,
                  record: record,
                  question: widget.store.questions.firstWhere(
                    (q) => q.id == record.questionId,
                  ),
                  onRetry: () => widget.openStudy(
                    questions: questions,
                    questionId: record.questionId,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class WrongCard extends StatefulWidget {
  const WrongCard({
    super.key,
    required this.store,
    required this.record,
    required this.question,
    required this.onRetry,
  });
  final StudyStore store;
  final WrongAnswer record;
  final Question question;
  final VoidCallback onRetry;
  @override
  State<WrongCard> createState() => _WrongCardState();
}

class _WrongCardState extends State<WrongCard> {
  late final memo = TextEditingController(text: widget.record.memo);
  bool saved = false;
  @override
  void dispose() {
    memo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: SoftCard(
      padding: const EdgeInsets.all(20),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 20),
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: categoryColor(
              widget.question.categoryId,
            ).withValues(alpha: .09),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            categoryIcon(widget.question.categoryId),
            color: categoryColor(widget.question.categoryId),
            size: 23,
          ),
        ),
        title: Text(
          widget.question.title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Text(
            '${categoryName(widget.question.categoryId)} · ${widget.question.number}번 · 오답 ${widget.record.wrongCount}회',
            style: const TextStyle(color: mutedColor, fontSize: 11),
          ),
        ),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              QuestionBody(question: widget.question),
              const SizedBox(height: 20),
              const Text(
                '마지막 오답',
                style: TextStyle(
                  color: redColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              SelectableText(
                widget.record.userAnswer.trim().isEmpty
                    ? '(미응답 / 다시 볼 문제)'
                    : widget.record.userAnswer,
                style: const TextStyle(fontSize: 14, height: 1.8),
              ),
              const SizedBox(height: 20),
              AnswerBody(question: widget.question),
              const SizedBox(height: 23),
              const Text(
                '나의 기억 메모',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: memo,
                minLines: 2,
                maxLines: 5,
                onChanged: (_) => setState(() => saved = false),
                decoration: const InputDecoration(
                  hintText: '헷갈린 이유나 기억할 단서를 적어보세요.',
                ),
              ),
              const SizedBox(height: 15),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SoftButton(
                    label: saved ? '메모 저장됨' : '메모 저장',
                    small: true,
                    icon: Icons.save_outlined,
                    onPressed: () {
                      widget.store.updateWrongMemo(
                        widget.record.questionId,
                        memo.text,
                      );
                      setState(() => saved = true);
                    },
                  ),
                  SoftButton(
                    label: '다시 풀기',
                    small: true,
                    primary: true,
                    icon: Icons.replay_rounded,
                    onPressed: widget.onRetry,
                  ),
                  SoftButton(
                    label: widget.record.resolved ? '복습할 문제로 이동' : '복습 완료',
                    small: true,
                    color: greenColor,
                    icon: Icons.task_alt_rounded,
                    onPressed: () => widget.store.resolveWrong(
                      widget.record.questionId,
                      resolved: !widget.record.resolved,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SourceLabel(widget.question),
            ],
          ),
        ],
      ),
    ),
  );
}

String dateLabel(DateTime date) =>
    '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
