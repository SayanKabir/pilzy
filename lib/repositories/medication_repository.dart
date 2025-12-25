import 'package:hive/hive.dart';
import '../models/medication.dart';
import '../models/dose_log.dart';

class MedicationRepository {
  late Box<Medication> _medBox;
  late Box<DoseLog> _logBox;

  // ✨ NEW: Public getter to access the box (Required for main.dart rescheduling)
  Box<Medication> get box => _medBox;

  /// Initializes the local storage by opening the required Hive boxes.
  Future<void> init() async {
    _medBox = await Hive.openBox<Medication>('medications');
    _logBox = await Hive.openBox<DoseLog>('dose_logs');
  }

  // ─────────────────────────────────────────────────────────────
  // VALIDATION LOGIC
  // ─────────────────────────────────────────────────────────────

  /// Internal helper to ensure medication data meets all medical and logic constraints.
  void _validateMedication(Medication med) {
    // 1. Form-specific validation
    if (med.form == MedicationForm.pill) {
      assert(med.pillsPerStrip != null && med.pillsPerStrip! > 0,
      'Pills per strip must be a positive integer');
    } else if (med.form == MedicationForm.liquid) {
      assert(med.bottleSizeMl != null && med.bottleSizeMl! > 0,
      'Bottle size (ml) must be positive');
      assert(med.mlPerDose != null && med.mlPerDose! > 0,
      'ml per dose must be positive');
    }

    // 2. Frequency-specific validation
    assert(med.frequencyInterval > 0,
    'The frequency interval must be at least 1 (e.g., Every 1 Day)');
    // Removed timesPerDay assertion if it's not being used in your logic or allow it if calculated
    // assert(med.timesPerDay > 0, 'Times per day must be at least 1');

    // 3. ✨ Date range validation
    if (med.endDate != null) {
      assert(med.endDate!.isAfter(med.startDate),
      'End date must be after the start date');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // CRUD OPERATIONS
  // ─────────────────────────────────────────────────────────────

  /// Validates and adds a new medication to the database.
  Future<void> addMedication(Medication med) async {
    _validateMedication(med);
    await _medBox.put(med.id, med);
  }

  /// Validates and updates an existing medication entry (e.g., Soft Expiry/Continuous).
  Future<void> updateMedication(Medication med) async {
    _validateMedication(med);
    await _medBox.put(med.id, med);
  }

  /// Retrieves all medications, sorted alphabetically by name.
  Future<List<Medication>> getMedications() async {
    final meds = _medBox.values.toList();
    meds.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return meds;
  }

  /// Removes a medication and all its associated dose logs to keep the DB clean.
  Future<void> removeMedication(int id) async {
    await _medBox.delete(id);
    await deleteLogsForMedication(id); // Use the helper for clean deletion
  }

  // ─────────────────────────────────────────────────────────────
  // DOSE LOGGING & INVENTORY UTILITIES
  // ─────────────────────────────────────────────────────────────

  /// Records a new dose as taken at a specific timestamp.
  Future<void> markTaken(DoseLog log) async {
    await _logBox.add(log);
  }

  /// ✨ NEW: Bulk deletes logs for a specific medication (Used for Restock).
  Future<void> deleteLogsForMedication(int medId) async {
    final keysToRemove = _logBox.values
        .where((log) => log.medId == medId)
        .map((l) => l.key)
        .toList();

    if (keysToRemove.isNotEmpty) {
      await _logBox.deleteAll(keysToRemove);
    }
  }

  /// Returns a map grouping all DoseLogs by their respective medication IDs.
  Future<Map<int, List<DoseLog>>> getDoseLogs() async {
    final Map<int, List<DoseLog>> grouped = {};
    for (var log in _logBox.values) {
      grouped.putIfAbsent(log.medId, () => []);
      grouped[log.medId]!.add(log);
    }
    return grouped;
  }

  /// Calculates real-time remaining stock for a specific medication.
  Future<double?> getRemainingStock(int medId) async {
    final med = _medBox.get(medId);
    if (med == null) return null;

    final logs = _logBox.values.where((log) => log.medId == medId).toList();
    return med.calculateRemainingDoses(timesConsumed: logs.length);
  }
}