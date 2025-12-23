import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'repositories/medication_repository.dart';
import 'blocs/medication_bloc.dart';
import 'blocs/medication_event.dart';
import 'screens/home_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'models/medication.dart';
import 'models/dose_log.dart';
import 'services/notification_service.dart';

Future<void> _requestNotificationPermission() async {
  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }
}

Future<void> _configureLocalTimeZone() async {
  tzdata.initializeTimeZones();

  // Hardcode Asia/Kolkata timezone
  const String timeZone = 'Asia/Kolkata';
  tz.setLocalLocation(tz.getLocation(timeZone));
  debugPrint('Timezone set to: $timeZone');
}

Future<void> _initHive() async {
  await Hive.initFlutter();

  // Register MedicationForm enum adapter
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(MedicationFormAdapter());
  }

  // Register Medication adapter
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(MedicationAdapter());
  }

  // Register DoseLog adapter
  if (!Hive.isAdapterRegistered(2)) {
    Hive.registerAdapter(DoseLogAdapter());
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Request notification permission
  await _requestNotificationPermission();

  // Setup timezone
  await _configureLocalTimeZone();

  // Initialize Hive
  await _initHive();

  // Initialize repository
  final repo = MedicationRepository();
  await repo.init();

  // Initialize NotificationService
  final notificationService = NotificationService();
  await notificationService.init();

  // 🔹 Only request if not already granted
  final hasAlarmPermission = await notificationService.hasExactAlarmPermission();
  if (!hasAlarmPermission) {
    await notificationService.requestExactAlarmPermission();
  }

  runApp(MyApp(
    repository: repo,
    notificationService: notificationService,
  ));
}

class MyApp extends StatelessWidget {
  final MedicationRepository repository;
  final NotificationService notificationService;

  const MyApp({
    Key? key,
    required this.repository,
    required this.notificationService,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider.value(
      value: repository,
      child: BlocProvider(
        create: (context) => MedicationBloc(
          repository: repository,
          notificationService: notificationService, // Pass the service here
        )..add(LoadMedications()),
        child: MaterialApp(
          title: 'Pilzy - Medication Reminder',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(primarySwatch: Colors.blue),
          home: const HomeScreen(),
        ),
      ),
    );
  }
}
