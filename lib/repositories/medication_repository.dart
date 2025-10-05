import 'package:hive/hive.dart';
import '../models/medication.dart';
import '../models/dose_log.dart';

class MedicationRepository {
  late Box<Medication> _medBox;
  late Box<DoseLog> _logBox;

  Future<void> init() async {
    _medBox = await Hive.openBox<Medication>('medications');
    _logBox = await Hive.openBox<DoseLog>('dose_logs');
  }

  // -------------------------
  // MEDICATION CRUD
  // -------------------------

  Future<List<Medication>> getMedications() async {
    return _medBox.values.toList();
  }

  Future<void> addMedication(Medication med) async {
    await _medBox.put(med.id, med);
  }

  Future<void> removeMedication(int id) async {
    await _medBox.delete(id);

    // also remove logs tied to this medication
    final logsToRemove = _logBox.values
        .where((log) => log.medId == id)
        .map((log) => log.key)
        .toList();
    await _logBox.deleteAll(logsToRemove);
  }

  // -------------------------
  // DOSE LOGS
  // -------------------------

  Future<void> markTaken(DoseLog log) async {
    await _logBox.add(log);
  }

  Future<Map<int, List<DoseLog>>> getDoseLogs() async {
    final Map<int, List<DoseLog>> groupedLogs = {};
    for (var log in _logBox.values) {
      groupedLogs.putIfAbsent(log.medId, () => []);
      groupedLogs[log.medId]!.add(log);
    }
    return groupedLogs;
  }

  // CLEAR (for debugging)

  Future<void> clearAll() async {
    await _medBox.clear();
    await _logBox.clear();
  }
}
