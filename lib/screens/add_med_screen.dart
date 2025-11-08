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

  // Controllers
  final _nameCtrl = TextEditingController();
  final _dosageCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  // Form-specific controllers
  final _pillsPerStripCtrl = TextEditingController();
  final _bottleSizeCtrl = TextEditingController();
  final _mlPerDoseCtrl = TextEditingController();

  TimeOfDay _time = TimeOfDay.now();
  MedicationForm _selectedForm = MedicationForm.pill;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dosageCtrl.dispose();
    _notesCtrl.dispose();
    _pillsPerStripCtrl.dispose();
    _bottleSizeCtrl.dispose();
    _mlPerDoseCtrl.dispose();
    super.dispose();
  }

  void _validateAndSubmit() {
    if (!_formKey.currentState!.validate()) return;

    final id = DateTime.now().millisecondsSinceEpoch.remainder(100000);
    final now = DateTime.now();
    final medTime = DateTime(now.year, now.month, now.day, _time.hour, _time.minute);

    // Parse form-specific fields
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
        title: const Text('Add Medication'),
        backgroundColor: MyConstants.mintColor,
        leadingWidth: 30,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 22),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildInputField(_nameCtrl, "Medication Name", validator: (v) {
                    if (v == null || v.trim().isEmpty) return "Required";
                    return null;
                  }),
                  const SizedBox(height: 10),
                  _buildInputField(_dosageCtrl, "Dosage (e.g., 50mg)", validator: (v) {
                    if (v == null || v.trim().isEmpty) return "Required";
                    return null;
                  }),
                  const SizedBox(height: 10),
                  _buildFormDropdown(),
                  const SizedBox(height: 10),

                  // Form-specific fields
                  if (_selectedForm == MedicationForm.pill) ...[
                    _buildInputField(_pillsPerStripCtrl, "Pills per Strip",
                        isNumber: true,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return "Required for pills";
                          if (int.tryParse(v.trim()) == null) return "Must be a number";
                          return null;
                        }),
                    const SizedBox(height: 10),
                  ],

                  if (_selectedForm == MedicationForm.liquid) ...[
                    _buildInputField(_bottleSizeCtrl, "Bottle Size (ml)",
                        isNumber: true,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return "Required for liquids";
                          if (double.tryParse(v.trim()) == null) return "Must be a number";
                          return null;
                        }),
                    const SizedBox(height: 10),
                    _buildInputField(_mlPerDoseCtrl, "ml per Dose",
                        isNumber: true,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return "Required for liquids";
                          if (double.tryParse(v.trim()) == null) return "Must be a number";
                          return null;
                        }),
                    const SizedBox(height: 10),
                  ],

                  _buildInputField(_notesCtrl, "Doctor's special instructions",
                      maxLines: 2),
                  const SizedBox(height: 14),
                  _buildTimePickerRow(),
                  const SizedBox(height: 22),
                  _buildAddButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(TextEditingController ctrl, String label,
      {bool isNumber = false, int maxLines = 1, String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      validator: validator,
      cursorColor: MyConstants.tealColor,
      style: TextStyle(
        color: MyConstants.charcoalColor,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: label,
        hintStyle: TextStyle(color: MyConstants.charcoalColor.withOpacity(0.6)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.8),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: MyConstants.charcoalColor.withOpacity(0.6), width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: MyConstants.tealColor, width: 2.5),
        ),
      ),
    );
  }

  Widget _buildFormDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Medication Form',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: MyConstants.charcoalColor,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            await showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              builder: (_) => Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: CupertinoPicker(
                      backgroundColor: Colors.white70,
                      itemExtent: 40,
                      scrollController: FixedExtentScrollController(
                        initialItem: MedicationForm.values.indexOf(_selectedForm),
                      ),
                      onSelectedItemChanged: (index) {
                        setState(() => _selectedForm = MedicationForm.values[index]);
                      },
                      children: MedicationForm.values
                          .map((form) => Center(
                        child: Text(
                          form.name[0].toUpperCase() + form.name.substring(1),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                            color: MyConstants.charcoalColor,
                          ),
                        ),
                      ))
                          .toList(),
                    ),
                  ),
                ),
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: MyConstants.tealColor.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedForm.name[0].toUpperCase() + _selectedForm.name.substring(1),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimePickerRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () async {
            final t = await showTimePicker(context: context, initialTime: _time);
            if (t != null) setState(() => _time = t);
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: MyConstants.tealColor.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
                ),
                child: const Text(
                  'Pick Reminder Time',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 20),
        Text(
          _time.format(context),
          style: TextStyle(color: MyConstants.charcoalColor, fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildAddButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: TextButton(
        style: TextButton.styleFrom(
          backgroundColor: MyConstants.yellowColor,
          foregroundColor: MyConstants.charcoalColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
            side: BorderSide(color: MyConstants.charcoalColor, width: 2),
          ),
        ),
        onPressed: _validateAndSubmit,
        child: const Text('Add', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20)),
      ),
    );
  }
}