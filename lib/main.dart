import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

// 📂 Core Imports
import 'repositories/medication_repository.dart';
import 'blocs/medication_bloc.dart';
import 'blocs/medication_event.dart';
import 'screens/home_screen.dart';
import 'models/medication.dart';
import 'models/dose_log.dart';
import 'services/notification_service.dart';
import 'services/settings_service.dart';
import 'constants/constants.dart';

// ─────────────────────────────────────────────────────────────
// PERMISSIONS & TIMEZONE CONFIG
// ─────────────────────────────────────────────────────────────

Future<void> _requestNotificationPermission() async {
  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }
}

Future<void> _configureLocalTimeZone() async {
  tzdata.initializeTimeZones();
  // Using generic Local for better global support, or set specific if needed
  try {
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
  } catch (e) {
    debugPrint("Failed to set location, using local default: $e");
  }
}

// ─────────────────────────────────────────────────────────────
// HIVE INITIALIZATION & ADAPTERS
// ─────────────────────────────────────────────────────────────

Future<void> _initHive() async {
  await Hive.initFlutter();

  // Register all type adapters
  // Ensure these TypeIDs match exactly what is in your model files
  if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(MedicationFormAdapter());
  if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(MedicationAdapter());
  if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(DoseLogAdapter());
  if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(FrequencyTypeAdapter());
}

// ─────────────────────────────────────────────────────────────
// ENTRY POINT
// ─────────────────────────────────────────────────────────────

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Core Config
  await _configureLocalTimeZone();
  await _initHive();

  // 2. Load User Settings First (Critical for Notifications)
  await SettingsService().init();

  // 3. Initialize Repositories
  final repo = MedicationRepository();
  await repo.init();

  // 4. Notification Service Setup
  final notificationService = NotificationService();
  await notificationService.init();
  await _requestNotificationPermission();

  // 5. Android Exact Alarm Permission Check (API 31+)
  final hasAlarmPermission = await notificationService.hasExactAlarmPermission();
  if (!hasAlarmPermission) {
    await notificationService.requestExactAlarmPermission();
  }

  // 🔄 SAFETY NET: Reschedule all alarms on app launch
  // This ensures alarms persist even if the OS wiped them during a reboot/update
  if (repo.box.isNotEmpty) {
    await notificationService.rescheduleAll(repo.box.values.toList());
  }

  // 6. UI Polish (Portrait Lock & Edge-to-Edge)
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: MyConstants.mintColor,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  runApp(MyApp(
    repository: repo,
    notificationService: notificationService,
  ));
}

class MyApp extends StatelessWidget {
  final MedicationRepository repository;
  final NotificationService notificationService;

  const MyApp({
    super.key,
    required this.repository,
    required this.notificationService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: repository),
        RepositoryProvider.value(value: notificationService),
      ],
      child: BlocProvider(
        create: (context) => MedicationBloc(
          repository: repository,
          notificationService: notificationService,
        )..add(LoadMedications()),
        child: MaterialApp(
          title: 'Pilzy',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            primaryColor: MyConstants.tealColor,
            scaffoldBackgroundColor: MyConstants.mintColor,
            useMaterial3: true,
            fontFamily: 'Nunito', // Ensure this font is in pubspec.yaml
            colorScheme: ColorScheme.fromSwatch(
              primarySwatch: Colors.teal,
              accentColor: MyConstants.tealColor,
              backgroundColor: MyConstants.mintColor,
            ),
          ),
          home: const HomeScreen(),
        ),
      ),
    );
  }
}