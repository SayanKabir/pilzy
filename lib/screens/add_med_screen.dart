import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pilzy/constants/constants.dart';
import '../models/medication.dart';
import '../blocs/medication_bloc.dart';
import '../blocs/medication_event.dart';

class AddMedScreen extends StatefulWidget {
  const AddMedScreen({super.key});

  @override
  State<AddMedScreen> createState() => _AddMedScreenState();
}

class _AddMedScreenState extends State<AddMedScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _dosageCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _pillsPerStripCtrl = TextEditingController();
  final _bottleSizeCtrl = TextEditingController();
  final _mlPerDoseCtrl = TextEditingController();

  TimeOfDay _time = TimeOfDay.now();
  MedicationForm _selectedForm = MedicationForm.pill;

  @override
  void dispose() {
    for (var ctrl in [_nameCtrl, _dosageCtrl, _notesCtrl, _pillsPerStripCtrl, _bottleSizeCtrl, _mlPerDoseCtrl]) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _validateAndSubmit() {
    if (!_formKey.currentState!.validate()) return;

    final id = DateTime.now().millisecondsSinceEpoch.remainder(100000);
    final now = DateTime.now();
    final medTime = DateTime(now.year, now.month, now.day, _time.hour, _time.minute);

    int? pillsPerStrip;
    double? bottleSizeMl;
    double? mlPerDose;

    if (_selectedForm == MedicationForm.pill) {
      pillsPerStrip = int.tryParse(_pillsPerStripCtrl.text.trim());
    } else if (_selectedForm == MedicationForm.liquid) {
      bottleSizeMl = double.tryParse(_bottleSizeCtrl.text.trim());
      mlPerDose = double.tryParse(_mlPerDoseCtrl.text.trim());
    }

    final med = Medication(
      id: id,
      name: _nameCtrl.text.trim(),
      dosage: _dosageCtrl.text.trim(),
      scheduledTime: medTime,
      form: _selectedForm,
      pillsPerStrip: pillsPerStrip,
      bottleSizeMl: bottleSizeMl,
      mlPerDose: mlPerDose,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );

    context.read<MedicationBloc>().add(AddMedicationEvent(med));
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyConstants.mintColor,
      appBar: AppBar(
        title: Text('New Medication',
            style: TextStyle(color: MyConstants.charcoalColor, fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: MyConstants.charcoalColor, size: 22),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                padding: const EdgeInsets.all(24),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  // 3D Glass Gradient matching your summary header
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.4),
                      Colors.white.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    )
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildInputField(_nameCtrl, "Medication Name", Icons.medication),
                      const SizedBox(height: 12),
                      _buildInputField(_dosageCtrl, "Dosage (e.g., 50mg)", Icons.straighten),
                      const SizedBox(height: 20),

                      _buildFormDropdown(),
                      const SizedBox(height: 12),

                      if (_selectedForm == MedicationForm.pill) ...[
                        _buildInputField(_pillsPerStripCtrl, "Pills per Strip", Icons.apps, isNumber: true),
                        const SizedBox(height: 12),
                      ],

                      if (_selectedForm == MedicationForm.liquid) ...[
                        _buildInputField(_bottleSizeCtrl, "Bottle Size (ml)", Icons.opacity, isNumber: true),
                        const SizedBox(height: 12),
                        _buildInputField(_mlPerDoseCtrl, "ml per Dose", Icons.colorize, isNumber: true),
                        const SizedBox(height: 12),
                      ],

                      _buildInputField(_notesCtrl, "Special Instructions", Icons.notes, maxLines: 2),
                      const SizedBox(height: 20),
                      _buildTimePickerRow(),
                      const SizedBox(height: 30),
                      _buildAddButton(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Refined Input Field with an "Inset" glass feel
  Widget _buildInputField(TextEditingController ctrl, String label, IconData icon,
      {bool isNumber = false, int maxLines = 1}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      cursorColor: MyConstants.tealColor,
      style: TextStyle(color: MyConstants.charcoalColor, fontSize: 16, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        hintText: label,
        prefixIcon: Icon(icon, color: MyConstants.charcoalColor.withOpacity(0.4), size: 20),
        hintStyle: TextStyle(color: MyConstants.charcoalColor.withOpacity(0.4), fontWeight: FontWeight.w600),
        filled: true,
        fillColor: Colors.white.withOpacity(0.2),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.3), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: MyConstants.tealColor.withOpacity(0.5), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.redAccent.withOpacity(0.5), width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.redAccent, width: 2),
        ),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return "Required";
        if (isNumber && double.tryParse(v.trim()) == null) return "Invalid number";
        return null;
      },
    );
  }

  Widget _buildFormDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text('FORM TYPE',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: MyConstants.charcoalColor.withOpacity(0.5), letterSpacing: 1.2)),
        ),
        GestureDetector(
          onTap: () => _showCupertinoSheet(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: MyConstants.tealColor.withOpacity(0.8),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(color: MyConstants.tealColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedForm.name.toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 1),
                ),
                const Icon(Icons.unfold_more, color: Colors.white, size: 20),
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
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 250,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: CupertinoPicker(
            itemExtent: 45,
            scrollController: FixedExtentScrollController(initialItem: MedicationForm.values.indexOf(_selectedForm)),
            onSelectedItemChanged: (index) => setState(() => _selectedForm = MedicationForm.values[index]),
            children: MedicationForm.values.map((form) => Center(
              child: Text(form.name.toUpperCase(),
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: MyConstants.charcoalColor)),
            )).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildTimePickerRow() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MyConstants.charcoalColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton.icon(
            onPressed: () async {
              final t = await showTimePicker(context: context, initialTime: _time);
              if (t != null) setState(() => _time = t);
            },
            icon: const Icon(Icons.access_time_filled, color: Colors.orangeAccent),
            label: Text('SET TIME', style: TextStyle(color: MyConstants.charcoalColor, fontWeight: FontWeight.w800)),
          ),
          Text(_time.format(context),
              style: TextStyle(color: MyConstants.tealColor, fontSize: 22, fontWeight: FontWeight.w900)),
        ],
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
          BoxShadow(color: MyConstants.tealColor.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: MyConstants.tealColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
        ),
        onPressed: _validateAndSubmit,
        child: const Text('SAVE MEDICATION', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.5)),
      ),
    );
  }
}