import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/classes/classes_cubit.dart';
import '../data/trace_templates.dart';
import '../data/word_list.dart';
import '../models/profile_models.dart';
import '../services/family_service.dart';
import '../services/progress_service.dart';
import '../services/report_service.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';
import 'assign/manage_learner_screen.dart';

/// Teacher's classes (SRS US_7): create a class, open it to add or
/// remove students. Every student shows in the class list.
class ClassesScreen extends StatelessWidget {
  const ClassesScreen({super.key});

  static const _classColors = [
    AppColors.secondary,
    AppColors.purple,
    AppColors.primary,
    Color(0xFFF59E0B),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => ClassesCubit(family: ctx.read<FamilyService>())..load(),
      child: BlocConsumer<ClassesCubit, ClassesState>(
        listenWhen: (a, b) => b.message != null && a.message != b.message,
        listener: (context, s) => showKidSnack(context, s.message!.text,
            color: s.message!.isError ? AppColors.error : AppColors.purple),
        builder: (context, s) {
          final cubit = context.read<ClassesCubit>();
          return KidPage(
            floatingActionButton: FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              onPressed: () => showNameDialog(
                context,
                title: 'Create Class',
                label: 'Class name (e.g. Class A)',
                icon: Icons.school,
                buttonText: 'Create',
                onSave: cubit.create,
              ),
              icon: const Icon(Icons.add),
              label: Text('Create Class',
                  style: kid(16, weight: FontWeight.w600, color: Colors.white)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const KidHeader('My Classes'),
                Expanded(
                  child: s.loading
                      ? const Center(child: CircularProgressIndicator())
                      : s.classes.isEmpty
                          ? const KidEmpty(Icons.school,
                              'No classes yet. Tap "Create Class"!')
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 90),
                              itemCount: s.classes.length,
                              itemBuilder: (context, i) => _classTile(
                                  context,
                                  s.classes[i],
                                  _classColors[i % _classColors.length]),
                            ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _classTile(BuildContext context, SchoolClass c, Color color) {
    final cubit = context.read<ClassesCubit>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: KidCard(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ClassDetailScreen(classId: c.id)),
        ).then((_) => cubit.load()),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: const Icon(Icons.school, size: 26, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.name, style: kid(18, weight: FontWeight.w600)),
                  Text(
                      '${c.students.length} student${c.students.length == 1 ? '' : 's'}',
                      style: kid(14, color: Colors.grey.shade600)),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Delete class',
              icon: const Icon(Icons.delete_outline,
                  size: 22, color: AppColors.error),
              onPressed: () => showConfirmDialog(
                context,
                title: 'Delete ${c.name}?',
                text: 'The class and its student list will be removed.',
                onYes: () => cubit.delete(c),
              ),
            ),
            Icon(Icons.chevron_right, size: 28, color: color),
          ],
        ),
      ),
    );
  }
}

/// One class = the TEACHER DASHBOARD (SRS US_7 + US_22 + US_24):
/// the student list with live progress, "needs help" / "not started"
/// markers, classroom practice mode, and per-student report export.
class ClassDetailScreen extends StatelessWidget {
  final String classId;
  const ClassDetailScreen({super.key, required this.classId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => ClassDetailCubit(
        classId: classId,
        family: ctx.read<FamilyService>(),
        progress: ctx.read<ProgressService>(),
        reports: ctx.read<ReportService>(),
      )..load(),
      child: MultiBlocListener(
        listeners: [
          BlocListener<ClassDetailCubit, ClassDetailState>(
            listenWhen: (a, b) => b.message != null && a.message != b.message,
            listener: (context, s) => showKidSnack(context, s.message!.text,
                color:
                    s.message!.isError ? AppColors.error : AppColors.purple),
          ),
          BlocListener<ClassDetailCubit, ClassDetailState>(
            listenWhen: (a, b) => a.reportTick != b.reportTick,
            listener: (context, s) => showReportDialog(
                context, s.reportPath ?? '', s.reportText ?? ''),
          ),
        ],
        child: BlocBuilder<ClassDetailCubit, ClassDetailState>(
          builder: (context, s) {
            final cubit = context.read<ClassDetailCubit>();
            final c = s.schoolClass;
            return KidPage(
              floatingActionButton: c == null
                  ? null
                  : FloatingActionButton.extended(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      onPressed: () => showNameDialog(
                        context,
                        title: 'Add Student',
                        label: "Student's name",
                        icon: Icons.person,
                        buttonText: 'Add',
                        onSave: cubit.addStudent,
                      ),
                      icon: const Icon(Icons.person_add),
                      label: Text('Add Student',
                          style: kid(16,
                              weight: FontWeight.w600, color: Colors.white)),
                    ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  KidHeader(c?.name ?? 'Class'),
                  Expanded(
                    child: s.loading
                        ? const Center(child: CircularProgressIndicator())
                        : c == null
                            ? Center(
                                child: Text('Class not found', style: kid(17)))
                            : c.students.isEmpty
                                ? const KidEmpty(Icons.groups,
                                    'No students yet. Tap "Add Student"!')
                                : ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(
                                        20, 8, 20, 90),
                                    itemCount: c.students.length,
                                    itemBuilder: (context, i) => _studentTile(
                                        context, s, c.students[i]),
                                  ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _studentTile(BuildContext context, ClassDetailState s, String name) {
    final cubit = context.read<ClassDetailCubit>();
    final summary = s.summaries[name];
    final (status, statusColor) = switch (s.statusFor(name)) {
      StudentStatus.notStarted => ('not started', Colors.grey),
      StudentStatus.needsHelp => ('needs help', AppColors.error),
      StudentStatus.onTrack => ('on track', AppColors.success),
    };
    final isPracticing = s.activeScope == cubit.scopeOf(name);
    final days = summary?.lastPractice == null
        ? null
        : DateTime.now().difference(summary!.lastPractice!).inDays;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: KidCard(
        padding: const EdgeInsets.all(14),
        borderColor: isPracticing ? AppColors.primary : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.secondary,
                  child: Text(name[0].toUpperCase(),
                      style: kid(16,
                          weight: FontWeight.bold, color: Colors.white)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(isPracticing ? '$name  practicing' : name,
                      style: kid(16, weight: FontWeight.w600)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(status,
                      style: kid(12,
                          weight: FontWeight.w600, color: statusColor)),
                ),
              ],
            ),
            if (summary != null && summary.hasActivity) ...[
              const SizedBox(height: 8),
              Text(
                'Strokes ${summary.strokesDone}/${stage1Items.length}  ·  '
                'Letters ${summary.lettersDone}/${allLetterItems.length}  ·  '
                'Words ${summary.wordsDone}/${practiceWords.length}'
                '${days == null ? '' : days == 0 ? '  ·  practiced today' : '  ·  $days day${days == 1 ? '' : 's'} ago'}',
                style: kid(13, color: Colors.grey.shade600),
              ),
            ],
            const SizedBox(height: 6),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () => cubit.togglePractice(name),
                  icon: Icon(
                      isPracticing ? Icons.stop_circle : Icons.play_circle,
                      size: 20),
                  label: Text(isPracticing ? 'Stop' : 'Practice',
                      style: kid(14,
                          color: isPracticing
                              ? AppColors.error
                              : AppColors.secondary)),
                  style: TextButton.styleFrom(
                      foregroundColor: isPracticing
                          ? AppColors.error
                          : AppColors.secondary),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ManageLearnerScreen(
                        scope: cubit.scopeOf(name),
                        learnerName: name,
                        fromRole: 'Teacher',
                      ),
                    ),
                  ).then((_) => cubit.load()),
                  icon: const Icon(Icons.assignment, size: 20),
                  label: Text('Tasks',
                      style: kid(14, color: AppColors.primary)),
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary),
                ),
                TextButton.icon(
                  onPressed: () => cubit.exportReport(name),
                  icon: const Icon(Icons.download, size: 20),
                  label:
                      Text('Report', style: kid(14, color: AppColors.purple)),
                  style:
                      TextButton.styleFrom(foregroundColor: AppColors.purple),
                ),
                IconButton(
                  tooltip: 'Remove from class',
                  icon: const Icon(Icons.person_remove,
                      size: 22, color: AppColors.error),
                  onPressed: () => showConfirmDialog(
                    context,
                    title: 'Remove $name?',
                    text: '$name will leave ${s.schoolClass?.name ?? 'the class'}.',
                    yesText: 'Remove',
                    onYes: () => cubit.removeStudent(name),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
