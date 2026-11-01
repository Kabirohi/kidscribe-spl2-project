import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/reminder/reminder_cubit.dart';
import '../services/assignment_service.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';

/// Where a parent turns the daily practice reminder on or off and picks
/// the time (SRS FR_15 / US_19). It can also send an alert when a task
/// is waiting.
class ReminderScreen extends StatelessWidget {
  const ReminderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) =>
          ReminderCubit(assignments: ctx.read<AssignmentService>())..load(),
      child: BlocConsumer<ReminderCubit, ReminderState>(
        listenWhen: (a, b) => a.messageTick != b.messageTick,
        listener: (context, s) => showKidSnack(context, s.message ?? '',
            color: s.messageIsError ? AppColors.error : AppColors.purple),
        builder: (context, s) {
          final cubit = context.read<ReminderCubit>();
          final time = TimeOfDay(hour: s.hour, minute: s.minute);
          return KidPage(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const KidHeader('Reminders'),
                Expanded(
                  child: s.loading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView(
                          padding: const EdgeInsets.all(20),
                          children: [
                            _card([
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                activeThumbColor: AppColors.primary,
                                title: Text('Daily practice reminder',
                                    style: kid(17, weight: FontWeight.w600)),
                                subtitle: Text(
                                  'The tablet reminds your child to practice every day.',
                                  style: kid(13, color: Colors.grey.shade600),
                                ),
                                value: s.on,
                                onChanged: (v) => cubit.apply(
                                    on: v, timeText: time.format(context)),
                              ),
                              const Divider(),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                enabled: s.on,
                                leading: const Icon(Icons.access_time,
                                    color: AppColors.secondary),
                                title: Text('Reminder time', style: kid(16)),
                                subtitle: Text(time.format(context),
                                    style: kid(15,
                                        weight: FontWeight.w600,
                                        color: AppColors.primary)),
                                trailing: const Icon(Icons.edit, size: 20),
                                onTap: !s.on
                                    ? null
                                    : () async {
                                        final picked = await showTimePicker(
                                            context: context,
                                            initialTime: time);
                                        if (picked != null && context.mounted) {
                                          cubit.apply(
                                              hour: picked.hour,
                                              minute: picked.minute,
                                              timeText: picked.format(context));
                                        }
                                      },
                              ),
                            ]),
                            const SizedBox(height: 16),
                            _card([
                              Row(
                                children: [
                                  const Icon(Icons.assignment_late,
                                      color: AppColors.purple),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      s.waiting == 0
                                          ? 'No task is waiting right now.'
                                          : '${s.waiting} task${s.waiting == 1 ? ' is' : 's are'} waiting.',
                                      style: kid(16),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                height: 46,
                                child: ElevatedButton.icon(
                                  onPressed: s.waiting == 0
                                      ? null
                                      : cubit.remindAboutTasks,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.purple,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14)),
                                  ),
                                  icon: const Icon(Icons.notifications_active),
                                  label: Text('Remind about waiting tasks',
                                      style: kid(15, color: Colors.white)),
                                ),
                              ),
                            ]),
                            const SizedBox(height: 16),
                            TextButton.icon(
                              onPressed: cubit.showSample,
                              icon: const Icon(Icons.visibility),
                              label: Text('Show me what it looks like',
                                  style: kid(15, color: AppColors.purple)),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _card(List<Widget> children) => KidCard(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );
}
