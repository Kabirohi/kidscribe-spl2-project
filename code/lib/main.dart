import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'blocs/auth/auth_bloc.dart';
import 'firebase_options.dart';
import 'screens/auth_gate.dart';
import 'services/assignment_service.dart';
import 'services/auth_service.dart';
import 'services/badge_service.dart';
import 'services/custom_word_service.dart';
import 'services/family_service.dart';
import 'services/premium_service.dart';
import 'services/progress_service.dart';
import 'services/reminder_service.dart';
import 'services/report_service.dart';
import 'services/sync_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  // Firebase must be started before the app runs.
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Get the reminder system ready (SRS FR_15).
  await ReminderService.init();
  runApp(const KidScribeApp());
}

/// The root of the app.
///
/// KidScribe uses the BLoC architecture, which has three layers:
///
///   1. UI layer        - the screens in lib/screens. They only draw, and
///                        send events to a bloc.
///   2. Business layer  - the blocs and cubits in lib/blocs. All the rules
///                        and all the state live here.
///   3. Data layer      - the repositories in lib/services. They talk to
///                        SharedPreferences, Firebase and ML Kit.
///
/// Below we put the repositories and the app-wide AuthBloc above every
/// screen, so any screen can reach them.
class KidScribeApp extends StatelessWidget {
  const KidScribeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(create: (_) => AuthService()),
        RepositoryProvider(create: (_) => FamilyService()),
        RepositoryProvider(create: (_) => ProgressService()),
        RepositoryProvider(create: (_) => BadgeService()),
        RepositoryProvider(create: (_) => AssignmentService()),
        RepositoryProvider(create: (_) => ReportService()),
        RepositoryProvider(create: (_) => CustomWordService()),
        RepositoryProvider(create: (_) => PremiumService()),
        RepositoryProvider(create: (_) => SyncService()),
      ],
      child: MultiBlocProvider(
        providers: [
          // Login state is needed everywhere, so it lives at the top.
          BlocProvider(
            create: (ctx) =>
                AuthBloc(auth: ctx.read<AuthService>())..add(const AuthStarted()),
          ),
        ],
        child: MaterialApp(
          title: 'KidScribe',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: const AuthGate(),
        ),
      ),
    );
  }
}
