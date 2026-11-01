import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/words/word_list_cubit.dart';
import '../../data/word_list.dart';
import '../../services/custom_word_service.dart';
import '../../services/progress_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import 'word_practice_screen.dart';
import '../../widgets/art.dart';

/// Stage 3: the word gallery (SRS FR_8 / US_11), plus the child's own
/// toy words added with the toy camera (SRS FR_16).
class WordListScreen extends StatelessWidget {
  const WordListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => WordListCubit(
        progress: ctx.read<ProgressService>(),
        toys: ctx.read<CustomWordService>(),
      )..load(),
      child: const _WordListView(),
    );
  }
}

class _WordListView extends StatelessWidget {
  const _WordListView();

  static const _cardColors = [
    AppColors.primary,
    AppColors.secondary,
    AppColors.purple,
    Color(0xFFF59E0B),
  ];

  void _open(BuildContext context, List<PracticeWord> words, int i) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => WordPracticeScreen(wordIndex: i, words: words)),
    ).then((_) {
      if (context.mounted) context.read<WordListCubit>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final columns = width > 900 ? 5 : width > 600 ? 4 : 3;

    return BlocBuilder<WordListCubit, WordListState>(
      builder: (context, s) {
        final toyPractice = [for (final t in s.toyWords) t.asPracticeWord];
        return KidPage(
          child: Column(
            children: [
              KidHeader('Stage 3: Words', actions: [
                KidHeaderPill('${s.commonDone}/${practiceWords.length}'),
              ]),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                    'Write each word letter by letter — the robot checks '
                    'every one!',
                    style: kid(14)),
              ),
              Expanded(
                child: s.loading
                    ? const Center(child: CircularProgressIndicator())
                    : CustomScrollView(
                        slivers: [
                          if (s.toyWords.isNotEmpty) ...[
                            SliverToBoxAdapter(
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 16, 20, 4),
                                child: Text('My toy words',
                                    style: kid(17, weight: FontWeight.bold)),
                              ),
                            ),
                            SliverPadding(
                              padding: const EdgeInsets.all(20),
                              sliver: SliverGrid.count(
                                crossAxisCount: columns,
                                mainAxisSpacing: 14,
                                crossAxisSpacing: 14,
                                childAspectRatio: 0.95,
                                children: [
                                  for (var i = 0; i < s.toyWords.length; i++)
                                    _toyCard(context, s, toyPractice, i),
                                ],
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 0, 20, 0),
                                child: Text('Common words',
                                    style: kid(17, weight: FontWeight.bold)),
                              ),
                            ),
                          ],
                          SliverPadding(
                            padding: const EdgeInsets.all(20),
                            sliver: SliverGrid.count(
                              crossAxisCount: columns,
                              mainAxisSpacing: 14,
                              crossAxisSpacing: 14,
                              childAspectRatio: 0.95,
                              children: [
                                for (var i = 0; i < practiceWords.length; i++)
                                  _wordCard(context, s, i),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _wordCard(BuildContext context, WordListState s, int i) {
    final w = practiceWords[i];
    final done = s.done.contains(w.word);
    final color = _cardColors[i % _cardColors.length];
    return GestureDetector(
      onTap: () => _open(context, practiceWords, i),
      child: _tile(
        top: KidEmoji(w.emoji, size: 46),
        word: w.word,
        done: done,
        color: color,
      ),
    );
  }

  Widget _toyCard(BuildContext context, WordListState s,
      List<PracticeWord> toyPractice, int i) {
    final t = s.toyWords[i];
    return GestureDetector(
      onTap: () => _open(context, toyPractice, i),
      child: _tile(
        top: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(File(t.photoPath),
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const KidArt('teddy_bear', size: 46)),
        ),
        word: t.word,
        done: s.done.contains(t.word),
        color: AppColors.purple,
      ),
    );
  }

  Widget _tile({
    required Widget top,
    required String word,
    required bool done,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: done ? color : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: done ? color : AppColors.line, width: 2),
        boxShadow: [
          BoxShadow(
            color: done ? AppColors.ledge(color) : AppColors.line,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          top,
          const SizedBox(height: 6),
          Text(word,
              style: kid(17,
                  weight: FontWeight.bold,
                  color: done ? Colors.white : AppColors.textDark)),
          const SizedBox(height: 4),
          Text(done ? '✓ done' : '${word.length} letters',
              style: kid(12,
                  color: done ? Colors.white : Colors.grey.shade600)),
        ],
      ),
    );
  }
}
