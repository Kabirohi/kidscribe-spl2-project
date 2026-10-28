import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../blocs/toys/toy_words_cubit.dart';
import '../services/badge_service.dart';
import '../services/custom_word_service.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';
import 'learn/badge_popup.dart';

/// Toy camera: turn a photo of the child's toy into a practice word
/// (SRS FR_16 / US_20). Made for the parent.
class ToyWordsScreen extends StatelessWidget {
  const ToyWordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => ToyWordsCubit(
        toys: ctx.read<CustomWordService>(),
        badges: ctx.read<BadgeService>(),
      )..load(),
      child: const _ToyView(),
    );
  }
}

class _ToyView extends StatefulWidget {
  const _ToyView();

  @override
  State<_ToyView> createState() => _ToyViewState();
}

class _ToyViewState extends State<_ToyView> {
  final _nameCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  /// Opening the camera is a screen job; the cubit gets only the photo.
  Future<void> _takePhoto(BuildContext context, ImageSource source) async {
    final cubit = context.read<ToyWordsCubit>();
    try {
      final shot = await ImagePicker().pickImage(
          source: source, maxWidth: 1600, imageQuality: 90);
      if (shot == null) return; // the parent closed the camera
      _nameCtrl.clear();
      await cubit.processPhoto(shot.path);
    } catch (_) {
      if (context.mounted) {
        showKidSnack(context, 'The camera could not be opened.',
            color: AppColors.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ToyWordsCubit, ToyWordsState>(
      listenWhen: (a, b) =>
          a.messageTick != b.messageTick ||
          (b.newBadges.isNotEmpty && a.newBadges != b.newBadges),
      listener: (context, s) async {
        final cubit = context.read<ToyWordsCubit>();
        if (s.message != null) {
          showKidSnack(context, s.message!,
              color: s.messageIsError ? AppColors.error : AppColors.success);
        }
        if (s.newBadges.isNotEmpty) {
          await showBadgePopup(context, s.newBadges);
          cubit.badgesShown();
        }
      },
      builder: (context, s) {
        return KidPage(
          child: Column(
            children: [
              const KidHeader('Toy Words'),
              Expanded(
                child: s.loading
                    ? const Center(child: CircularProgressIndicator())
                    : s.step == ToyStep.naming || s.step == ToyStep.saving
                        ? _naming(context, s)
                        : _list(context, s),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _list(BuildContext context, ToyWordsState s) {
    final cubit = context.read<ToyWordsCubit>();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        KidCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Take a photo of a toy your child loves',
                  style: kid(18, weight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(
                'The toy becomes a word your child can practice. Words about '
                'their own toys are more fun to write!',
                style: kid(14, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 14),
              if (s.step == ToyStep.checkingPhoto)
                Row(
                  children: [
                    const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5)),
                    const SizedBox(width: 12),
                    Text('Checking the photo...', style: kid(15)),
                  ],
                )
              else ...[
                KidButton(' Take a photo',
                    onPressed: () =>
                        _takePhoto(context, ImageSource.camera)),
                const SizedBox(height: 8),
                KidButton(' Choose from the gallery',
                    color: AppColors.secondary,
                    onPressed: () =>
                        _takePhoto(context, ImageSource.gallery)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text('Your toy words (${s.words.length})',
            style: kid(17, weight: FontWeight.w600)),
        const SizedBox(height: 10),
        if (s.words.isEmpty)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text('No toy words yet.',
                textAlign: TextAlign.center,
                style: kid(15, color: Colors.grey.shade600)),
          ),
        for (final w in s.words)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: KidCard(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(w.photoPath),
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 64,
                        height: 64,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.toys),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(w.word,
                        style: kid(22,
                            weight: FontWeight.bold,
                            color: AppColors.primary)),
                  ),
                  IconButton(
                    tooltip: 'Remove',
                    icon: const Icon(Icons.delete_outline,
                        color: AppColors.error),
                    onPressed: () => cubit.delete(w),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _naming(BuildContext context, ToyWordsState s) {
    final cubit = context.read<ToyWordsCubit>();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (s.photoPath != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.file(File(s.photoPath!),
                height: 240, fit: BoxFit.cover),
          ),
        const SizedBox(height: 14),
        Text('The photo is clear! What is the toy called?',
            style: kid(17, weight: FontWeight.w600)),
        if (s.suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('The tablet thinks it might be:',
              style: kid(14, color: Colors.grey.shade700)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final name in s.suggestions)
                ActionChip(
                  label: Text(name, style: kid(15)),
                  onPressed: () => _nameCtrl.text = name,
                ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _nameCtrl,
          textCapitalization: TextCapitalization.characters,
          style: kid(20, weight: FontWeight.bold),
          decoration: InputDecoration(
            labelText: 'Toy word (letters only, 2 to 8)',
            prefixIcon: const Icon(Icons.edit, color: AppColors.primary),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 16),
        KidButton('Add this word',
            busy: s.step == ToyStep.saving,
            onPressed: () => cubit.saveWord(_nameCtrl.text)),
        const SizedBox(height: 8),
        TextButton(
          onPressed: cubit.cancelNaming,
          child: Text('Cancel', style: kid(16, color: Colors.grey.shade700)),
        ),
      ],
    );
  }
}
