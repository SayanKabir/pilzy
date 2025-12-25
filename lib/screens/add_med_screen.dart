import 'dart:ui';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:pilzy/constants/constants.dart';
import '../models/medication.dart';
import '../blocs/medication_bloc.dart';
import '../blocs/medication_event.dart';
import '../services/settings_service.dart';

class AddMedScreen extends StatefulWidget {
  const AddMedScreen({super.key});

  @override
  State<AddMedScreen> createState() => _AddMedScreenState();
}

class _AddMedScreenState extends State<AddMedScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameCtrl = TextEditingController();
  final _dosageCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _pillsPerStripCtrl = TextEditingController();
  final _bottleSizeCtrl = TextEditingController();
  final _mlPerDoseCtrl = TextEditingController();

  // Schedule State
  List<TimeOfDay> _selectedTimes = [const TimeOfDay(hour: 9, minute: 0)];
  MedicationForm _selectedForm = MedicationForm.pill;
  FrequencyType _selectedFreq = FrequencyType.daily;
  int _interval = 1;

  // ✨ Smart Features State
  bool _bedtimeProtection = true;

  // 📅 Date Range State
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _isChronic = true;

  @override
  void dispose() {
    for (var ctrl in [
      _nameCtrl,
      _dosageCtrl,
      _notesCtrl,
      _pillsPerStripCtrl,
      _bottleSizeCtrl,
      _mlPerDoseCtrl,
    ]) {
      ctrl.dispose();
    }
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // 🧠 LOGIC HELPERS
  // ─────────────────────────────────────────────────────────────

  void _applySmartSpacing(int count) {
    if (_selectedFreq != FrequencyType.daily) return;
    TimeOfDay baseTime =
        _selectedTimes.isNotEmpty
            ? _selectedTimes[0]
            : const TimeOfDay(hour: 9, minute: 0);
    List<TimeOfDay> newTimes = [baseTime];
    if (count > 1) {
      int gapHours = (24 / count).floor();
      for (int i = 1; i < count; i++) {
        int nextHour = (baseTime.hour + (gapHours * i)) % 24;
        if (_bedtimeProtection && (nextHour >= 23 || nextHour < 6))
          nextHour = 6;
        newTimes.add(TimeOfDay(hour: nextHour, minute: baseTime.minute));
      }
    }
    setState(() {
      _selectedTimes = newTimes;
      _interval = count;
    });
  }

  String? _getGapWarning(int index) {
    if (index == 0 || _selectedTimes.length <= 1) return null;
    final current =
        _selectedTimes[index].hour * 60 + _selectedTimes[index].minute;
    final previous =
        _selectedTimes[index - 1].hour * 60 + _selectedTimes[index - 1].minute;
    if ((current - previous).abs() < 120)
      return "Doses are very close (< 2hrs)";
    return null;
  }

  void _validateAndSubmit() {
    if (!_formKey.currentState!.validate()) return;
    final now = DateTime.now();
    final random = Random();

    for (var time in _selectedTimes) {
      final uniqueId = int.parse(
        "${now.millisecondsSinceEpoch.remainder(100000)}${random.nextInt(9000) + 1000}",
      );
      final med = Medication(
        id: uniqueId,
        name: _nameCtrl.text.trim(),
        dosage: _dosageCtrl.text.trim(),
        scheduledTime: DateTime(
          _startDate.year,
          _startDate.month,
          _startDate.day,
          time.hour,
          time.minute,
        ),
        startDate: _startDate,
        endDate: _isChronic ? null : _endDate,
        form: _selectedForm,
        frequencyType: _selectedFreq,
        frequencyInterval: _selectedFreq == FrequencyType.daily ? 1 : _interval,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        pillsPerStrip:
            _selectedForm == MedicationForm.pill
                ? int.tryParse(_pillsPerStripCtrl.text)
                : null,
        bottleSizeMl:
            _selectedForm == MedicationForm.liquid
                ? double.tryParse(_bottleSizeCtrl.text)
                : null,
        mlPerDose:
            _selectedForm == MedicationForm.liquid
                ? double.tryParse(_mlPerDoseCtrl.text)
                : null,
      );
      context.read<MedicationBloc>().add(AddMedicationEvent(med));
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyConstants.mintColor,
      appBar: AppBar(
        title: Text(
          'New Medication',
          style: TextStyle(
            color: MyConstants.charcoalColor,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: MyConstants.charcoalColor,
            size: 22,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.4),
                            Colors.white.withValues(alpha: 0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            _buildInputField(
                              _nameCtrl,
                              "Medication Name",
                              Icons.medication,
                            ),
                            const SizedBox(height: 12),
                            _buildInputField(
                              _dosageCtrl,
                              "Dosage (e.g., 500mg)",
                              Icons.straighten,
                            ),
                            const SizedBox(height: 20),
                            _buildFormDropdown(),
                            const SizedBox(height: 20),

                            // 🧪 LIQUID INVENTORY FIELDS
                            if (_selectedForm == MedicationForm.liquid) ...[
                              _buildSectionLabel("Liquid Inventory"),
                              _buildInputField(
                                _bottleSizeCtrl,
                                "Total Bottle Size (ml)",
                                Icons.opacity,
                                isNumber: true,
                              ),
                              const SizedBox(height: 12),
                              _buildInputField(
                                _mlPerDoseCtrl,
                                "Volume per Dose (ml)",
                                Icons.colorize,
                                isNumber: true,
                              ),
                              const SizedBox(height: 20),
                            ],

                            // 💊 PILL INVENTORY FIELDS
                            if (_selectedForm == MedicationForm.pill) ...[
                              _buildSectionLabel("Pill Inventory"),
                              _buildInputField(
                                _pillsPerStripCtrl,
                                "Pills per Strip",
                                Icons.apps,
                                isNumber: true,
                              ),
                              const SizedBox(height: 20),
                            ],

                            _buildFrequencyHub(),
                            const SizedBox(height: 20),
                            _buildDateRangeSection(),
                            const SizedBox(height: 20),
                            _buildInputField(
                              _notesCtrl,
                              "Special Instructions",
                              Icons.notes,
                              maxLines: 2,
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildSectionLabel(
                                  _selectedFreq == FrequencyType.daily
                                      ? "Smart Schedule"
                                      : "Dose Time",
                                ),
                                if (_selectedFreq == FrequencyType.daily)
                                  _buildBedtimeToggle(),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...List.generate(
                              _selectedTimes.length,
                              (index) => _buildTimePickerRow(index),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: _buildAddButton(),
            ),
          ],
        ),
      ),
    );
  }

  // (Remainder of the helper widgets like _buildDateRangeSection, _buildTimePickerRow,
  // _buildFrequencyHub, etc. remain unchanged from your provided source)

  Widget _buildDateRangeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel("Course Duration"),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              _buildDatePickerRow(
                "Starts",
                _startDate,
                (date) => setState(() => _startDate = date),
              ),
              const Divider(color: Colors.white12, height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Continuous?",
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: MyConstants.charcoalColor,
                    ),
                  ),
                  CupertinoSwitch(
                    activeColor: MyConstants.tealColor,
                    value: _isChronic,
                    onChanged: (v) => setState(() => _isChronic = v),
                  ),
                ],
              ),
              if (!_isChronic) ...[
                const SizedBox(height: 12),
                _buildDatePickerRow(
                  "Ends",
                  _endDate ?? DateTime.now().add(const Duration(days: 7)),
                  (date) => setState(() => _endDate = date),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDatePickerRow(
    String label,
    DateTime date,
    Function(DateTime) onPick,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: MyConstants.charcoalColor.withValues(alpha: 0.6),
          ),
        ),
        GestureDetector(
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: date,
              firstDate: DateTime(2024),
              lastDate: DateTime(2030),
              builder:
                  (context, child) => Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: ColorScheme.light(
                        primary: MyConstants.tealColor,
                      ),
                    ),
                    child: child!,
                  ),
            );
            if (d != null) onPick(d);
          },
          child: Text(
            DateFormat('MMM dd, yyyy').format(date),
            style: TextStyle(
              color: MyConstants.tealColor,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimePickerRow(int index) {
    final warning = _getGapWarning(index);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  warning != null
                      ? Colors.orangeAccent.withValues(alpha: 0.1)
                      : MyConstants.charcoalColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color:
                    warning != null
                        ? Colors.orangeAccent.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: _selectedTimes[index],
                    );
                    if (t != null) {
                      setState(() => _selectedTimes[index] = t);
                      if (index == 0 && _selectedFreq == FrequencyType.daily)
                        _applySmartSpacing(_interval);
                    }
                  },
                  icon: Icon(
                    Icons.access_time_filled,
                    color: Colors.orangeAccent,
                  ),
                  label: Text(
                    'DOSE ${index + 1}',
                    style: TextStyle(
                      color: MyConstants.charcoalColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  _selectedTimes[index].format(context),
                  style: TextStyle(
                    color: MyConstants.tealColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          if (warning != null)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 4),
              child: Text(
                warning,
                style: const TextStyle(
                  color: Colors.orangeAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBedtimeToggle() {
    return GestureDetector(
      onTap: () {
        SettingsService().vibrate(HapticFeedbackType.light);
        setState(() => _bedtimeProtection = !_bedtimeProtection);
        _applySmartSpacing(_interval);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color:
              _bedtimeProtection
                  ? Colors.orangeAccent.withValues(alpha: 0.1)
                  : Colors.white10,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                _bedtimeProtection
                    ? Colors.orangeAccent.withValues(alpha: 0.3)
                    : Colors.white10,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.nights_stay_rounded,
              size: 14,
              color: _bedtimeProtection ? Colors.orangeAccent : Colors.grey,
            ),
            const SizedBox(width: 4),
            Text(
              "SLEEP MODE",
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w900,
                color: _bedtimeProtection ? Colors.orangeAccent : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrequencyHub() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel("Frequency Pattern"),
        Row(
          children:
              FrequencyType.values.map((type) {
                bool isSelected = _selectedFreq == type;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      SettingsService().vibrate(HapticFeedbackType.selection);
                      setState(() {
                        _selectedFreq = type;
                        _interval = 1;
                        _selectedTimes = [const TimeOfDay(hour: 9, minute: 0)];
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? MyConstants.tealColor
                                : Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          type.name.toUpperCase(),
                          style: TextStyle(
                            color:
                                isSelected
                                    ? Colors.white
                                    : MyConstants.charcoalColor.withValues(
                                      alpha: 0.5,
                                    ),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
        ),
        const SizedBox(height: 12),
        _buildIntervalPicker(),
      ],
    );
  }

  Widget _buildIntervalPicker() {
    String label =
        _selectedFreq == FrequencyType.daily
            ? "Times per day"
            : _selectedFreq == FrequencyType.everyXDays
            ? "Every X days"
            : "Every X weeks";
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: MyConstants.charcoalColor,
            ),
          ),
          Row(
            children: [
              _counterBtn(Icons.remove, () {
                if (_interval > 1) _applySmartSpacing(_interval - 1);
              }),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  "$_interval",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: MyConstants.tealColor,
                  ),
                ),
              ),
              _counterBtn(Icons.add, () {
                if (_interval < 6) _applySmartSpacing(_interval + 1);
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: MyConstants.charcoalColor.withValues(alpha: 0.5),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildInputField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    bool isNumber = false,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      style: TextStyle(
        color: MyConstants.charcoalColor,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        hintText: label,
        prefixIcon: Icon(
          icon,
          color: MyConstants.charcoalColor.withValues(alpha: 0.4),
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.2),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: MyConstants.tealColor, width: 2),
        ),
      ),
      validator: (v) => (v == null || v.isEmpty) ? "Required" : null,
    );
  }

  Widget _buildFormDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel("Form Type"),
        GestureDetector(
          onTap: () => _showCupertinoSheet(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: MyConstants.tealColor.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedForm.name.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Icon(Icons.unfold_more, color: Colors.white),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showCupertinoSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (_) => Container(
            height: 250,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: CupertinoPicker(
              itemExtent: 45,
              onSelectedItemChanged:
                  (i) =>
                      setState(() => _selectedForm = MedicationForm.values[i]),
              children:
                  MedicationForm.values
                      .map((f) => Center(child: Text(f.name.toUpperCase())))
                      .toList(),
            ),
          ),
    );
  }

  Widget _counterBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        SettingsService().vibrate(HapticFeedbackType.light);
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: MyConstants.tealColor.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: MyConstants.tealColor),
      ),
    );
  }

  Widget _buildAddButton() {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: MyConstants.tealColor.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: MyConstants.tealColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        onPressed: _validateAndSubmit,
        child: const Text(
          'SAVE MEDICATION',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}
