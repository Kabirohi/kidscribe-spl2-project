import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../blocs/children/children_cubit.dart';
import '../models/profile_models.dart';
import '../services/family_service.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';
import 'assign/manage_learner_screen.dart';

/// Parent's child profiles (SRS FR_3 / US_6).
/// All the rules live in ChildrenCubit; this screen only draws.
class ChildrenScreen extends StatelessWidget {
  const ChildrenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) =>
          ChildrenCubit(family: ctx.read<FamilyService>())..load(),
      child: const _ChildrenView(),
    );
  }
}

class _ChildrenView extends StatelessWidget {
  const _ChildrenView();

  static const _avatarColors = [
    AppColors.primary,
    AppColors.secondary,
    AppColors.purple,
    Color(0xFFF59E0B),
  ];

  void _snack(BuildContext context, String msg, bool isError) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 16)),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// Add (child == null) or edit an existing profile.
  void _showChildDialog(BuildContext context, {ChildProfile? child}) {
    final cubit = context.read<ChildrenCubit>();
    final nameCtrl = TextEditingController(text: child?.name ?? '');
    final ageCtrl =
        TextEditingController(text: child == null ? '' : '${child.age}');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          child == null ? 'Add Child' : 'Edit ${child.name}',
          style: GoogleFonts.nunito(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.primary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                labelText: "Child's name",
                prefixIcon:
                    const Icon(Icons.child_care, color: AppColors.primary),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ageCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                labelText: 'Age',
                prefixIcon: const Icon(Icons.cake, color: AppColors.primary),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.nunito(
                    fontSize: 16, color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final age = int.tryParse(ageCtrl.text.trim()) ?? 0;
              // The cubit checks the rules and reports back.
              await cubit.saveChild(id: child?.id, name: name, age: age);
              if (!ctx.mounted) return;
              if (!cubit.state.messageIsError) Navigator.pop(ctx);
            },
            child: Text('Save', style: GoogleFonts.nunito(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, ChildProfile child) {
    final cubit = context.read<ChildrenCubit>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Remove ${child.name}?',
            style:
                GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.bold)),
        content: Text('The profile will be removed from this device.',
            style: GoogleFonts.nunito(fontSize: 15)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.nunito(fontSize: 16)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white),
            onPressed: () async {
              await cubit.deleteChild(child);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
            },
            child: Text('Remove', style: GoogleFonts.nunito(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ChildrenCubit, ChildrenState>(
      listenWhen: (a, b) => b.message != null && a.message != b.message,
      listener: (context, state) {
        _snack(context, state.message!, state.messageIsError);
        context.read<ChildrenCubit>().clearMessage();
      },
      builder: (context, state) {
        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: const StadiumBorder(),
            onPressed: () => _showChildDialog(context),
            icon: const Icon(Icons.add_rounded, size: 26),
            label: Text('Add Child',
                style: GoogleFonts.nunito(
                    fontSize: 17, fontWeight: FontWeight.w900)),
          ),
          body: Container(
            decoration: const BoxDecoration(gradient: AppColors.bgGradient),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const KidHeader('My Children'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Tap a child to make them the learner — each child keeps '
                      'their own progress!',
                      style: GoogleFonts.nunito(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (state.loading)
                    const Expanded(
                        child: Center(child: CircularProgressIndicator()))
                  else if (state.children.isEmpty)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.child_care,
                                size: 72, color: AppColors.purple),
                            const SizedBox(height: 12),
                            Text('No children yet — tap "Add Child"!',
                                style: GoogleFonts.nunito(
                                    fontSize: 17, color: AppColors.textDark)),
                          ],
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 90),
                        itemCount: state.children.length,
                        itemBuilder: (context, i) =>
                            _childCard(context, state, i),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _childCard(BuildContext context, ChildrenState state, int i) {
    final child = state.children[i];
    final active = child.id == state.activeId;
    final color = _avatarColors[i % _avatarColors.length];
    final family = context.read<FamilyService>();

    return GestureDetector(
      onTap: () => context.read<ChildrenCubit>().setActive(child),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
              color: active ? AppColors.primary : AppColors.line, width: 2),
          boxShadow: [
            BoxShadow(
              color: active ? AppColors.primary.withValues(alpha: 0.35) : AppColors.line,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: color,
              child: Text(
                child.name.isEmpty ? '?' : child.name[0].toUpperCase(),
                style: GoogleFonts.nunito(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(child.name,
                            style: GoogleFonts.nunito(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            )),
                      ),
                      if (active) ...[
                        const SizedBox(width: 8),
                        const KidTag('Learning now', solid: true),
                      ],
                    ],
                  ),
                  Text('Age ${child.age}',
                      style: GoogleFonts.nunito(
                          fontSize: 14, color: Colors.grey.shade600)),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Challenges and feedback',
              icon: const Icon(Icons.assignment,
                  size: 22, color: AppColors.purple),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ManageLearnerScreen(
                      scope: family.childScope(child.id),
                      learnerName: child.name,
                      fromRole: 'Parent',
                    ),
                  ),
                ).then((_) {
                  if (context.mounted) context.read<ChildrenCubit>().load();
                });
              },
            ),
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit,
                  size: 22, color: AppColors.secondary),
              onPressed: () => _showChildDialog(context, child: child),
            ),
            IconButton(
              tooltip: 'Remove',
              icon: const Icon(Icons.delete_outline,
                  size: 22, color: AppColors.error),
              onPressed: () => _confirmDelete(context, child),
            ),
          ],
        ),
      ),
    );
  }
}
