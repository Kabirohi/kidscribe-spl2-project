import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/sentence/sentence_list_cubit.dart';
import '../../data/sentence_list.dart';
import '../../services/progress_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/art.dart';
import '../../widgets/common.dart';
import 'sentence_practice_screen.dart';

/// Stage 4 menu: the 12 sentences, in order (SRS FR_9).
class SentenceListScreen extends StatelessWidget {
  const SentenceListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) =>
          SentenceListCubit(progress: ctx.read<ProgressService>())..load(),
      child: BlocBuilder<SentenceListCubit, SentenceListState>(
        builder: (context, s) {
          return KidPage(
            child: Column(
              children: [
                const KidHeader('Stage 4: Sentences'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Put the word cards in the right order. Start big, end '
                    'with a dot!',
                    style: kid(14),
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: s.loading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: practiceSentences.length,
                          itemBuilder: (context, i) {
                            final sen = practiceSentences[i];
                            final done = s.done.contains(sen.id);
                            final open = s.isOpen(i);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Opacity(
                                opacity: open ? 1 : 0.5,
                                child: KidCard(
                                  borderColor:
                                      done ? AppColors.success : null,
                                  onTap: () {
                                    if (!open) {
                                      showKidSnack(context,
                                          'Finish the sentence before it first!');
                                      return;
                                    }
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            SentencePracticeScreen(
                                                startIndex: i),
                                      ),
                                    ).then((_) {
                                      if (context.mounted) {
                                        context
                                            .read<SentenceListCubit>()
                                            .load();
                                      }
                                    });
                                  },
                                  child: Row(
                                    children: [
                                      KidEmoji(sen.emoji, size: 48),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text('Sentence ${i + 1}',
                                                style: kid(17,
                                                    weight: FontWeight.bold)),
                                            Text(
                                              done
                                                  ? sen.text
                                                  : '${sen.words.length} words',
                                              style: kid(14,
                                                  color: Colors.grey.shade600),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        done
                                            ? Icons.check_circle
                                            : open
                                                ? Icons.chevron_right
                                                : Icons.lock,
                                        color: done
                                            ? AppColors.success
                                            : AppColors.primary,
                                        size: 30,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
