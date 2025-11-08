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
    final meds = _medBox.values.toList();

    // optional: sort alphabetically by name or by scheduled time
    meds.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return meds;
  }

  Future<void> addMedication(Medication med) async {
    // 🧠 sanity check for specific forms (not required but good for safety)
    switch (med.form) {
      case MedicationForm.pill:
        assert(med.pillsPerStrip != null && med.pillsPerStrip! > 0,
        'pillsPerStrip must be set for pills');
        break;

      case MedicationForm.liquid:
        assert(med.bottleSizeMl != null && med.bottleSizeMl! > 0,
        'bottleSizeMl must be set for liquids');
        assert(med.mlPerDose != null && med.mlPerDose! > 0,
        'mlPerDose must be set for liquids');
        break;

      case MedicationForm.other:
      // no special validation for other types
        break;
    }

    await _medBox.put(med.id, med);
  }

  Future<void> updateMedication(Medication med) async {
    // Validate before updating
    switch (med.form) {
      case MedicationForm.pill:
        assert(med.pillsPerStrip != null && med.pillsPerStrip! > 0,
        'pillsPerStrip must be set for pills');
        break;

      case MedicationForm.liquid:
        assert(med.bottleSizeMl != null && med.bottleSizeMl! > 0,
        'bottleSizeMl must be set for liquids');
        assert(med.mlPerDose != null && med.mlPerDose! > 0,
        'mlPerDose must be set for liquids');
        break;

      case MedicationForm.other:
        break;
    }

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
    // ✅ Save log with form awareness
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

  // -------------------------
  // UTILITIES
  // -------------------------

  Future<Medication?> getMedicationById(int id) async {
    return _medBox.get(id);
  }

  Future<List<DoseLog>> getLogsForMedication(int medId) async {
    return _logBox.values.where((log) => log.medId == medId).toList();
  }

  /// Get logs for a medication within a date range
  Future<List<DoseLog>> getLogsForMedicationInRange(
      int medId,
      DateTime start,
      DateTime end,
      ) async {
    return _logBox.values
        .where((log) =>
    log.medId == medId &&
        log.takenAt.isAfter(start.subtract(const Duration(seconds: 1))) &&
        log.takenAt.isBefore(end.add(const Duration(seconds: 1))))
        .toList();
  }

  /// Calculate remaining stock for a medication based on its logs
  Future<double?> getRemainingStock(int medId) async {
    final med = await getMedicationById(medId);
    if (med == null) return null;

    final logs = await getLogsForMedication(medId);
    return med.calculateRemainingDoses(timesConsumed: logs.length);
  }

  Future<void> clearAll() async {
    await _medBox.clear();
    await _logBox.clear();
  }
}