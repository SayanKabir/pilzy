import 'dart:ui';
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
  final _doseCtrl = TextEditingController();
  final _stripSizeCtrl = TextEditingController();
  TimeOfDay _time = TimeOfDay.now();

  String? _nameError;
  String? _doseError;
  String? _stripError;

  void _validateFields() {
    setState(() {
      _nameError = _nameCtrl.text.trim().isEmpty ? "Required" : null;
      _doseError = _doseCtrl.text.trim().isEmpty ? "Required" : null;
      if (_stripSizeCtrl.text.trim().isEmpty) {
        _stripError = "Required";
      } else if (int.tryParse(_stripSizeCtrl.text.trim()) == null ||
          int.parse(_stripSizeCtrl.text.trim()) <= 0) {
        _stripError = "Enter a valid number";
      } else {
        _stripError = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyConstants.mintColor,
      appBar: AppBar(
        title: const Text('add medication'),
        backgroundColor: MyConstants.mintColor,
        centerTitle: false,
        leadingWidth: 30,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
            size: 22,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildInputField(
                    controller: _nameCtrl,
                    label: "Name",
                    errorText: _nameError,
                    keyboardType: TextInputType.name,
                  ),
                  const SizedBox(height: 10),
          
                  _buildInputField(
                    controller: _doseCtrl,
                    label: "Dose (e.g., 50 mg)",
                    errorText: _doseError,
                  ),
                  const SizedBox(height: 10),
          
                  _buildInputField(
                    controller: _stripSizeCtrl,
                    label: "Strip Size (e.g., 10, 15)",
                    errorText: _stripError,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 14),
          
                  // Time Picker Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () async {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: _time,
                          );
                          if (t != null) {
                            setState(() => _time = t);
                          }
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              decoration: BoxDecoration(
                                color: MyConstants.tealColor.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
                              ),
                              child: const Text(
                                'Pick Reminder Time',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _time.format(context),
                        style: TextStyle(
                          color: MyConstants.charcoalColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
          
                  // Add Medication Button
                  SizedBox(
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
                      onPressed: () {
                        _validateFields();
                        if (_nameError != null || _doseError != null || _stripError != null) return;
          
                        final id = DateTime.now().millisecondsSinceEpoch.remainder(100000);
                        final now = DateTime.now();
                        final medTime = DateTime(now.year, now.month, now.day, _time.hour, _time.minute);
          
                        final med = Medication(
                          id: id,
                          name: _nameCtrl.text.trim(),
                          dose: _doseCtrl.text.trim(),
                          time: medTime,
                          stripSize: int.parse(_stripSizeCtrl.text.trim()),
                        );
          
                        context.read<MedicationBloc>().add(AddMedicationEvent(med));
                        Navigator.of(context).pop(true);
                      },
                      child: const Text(
                        'Add',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds a single input + error chip underneath
  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String? errorText,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 60,
          child: TextFormField(
            controller: controller,
            cursorColor: MyConstants.tealColor,
            keyboardType: keyboardType,
            decoration: _inputDecoration(label),
            style: _inputTextStyle(),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 6),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 16, color: Colors.redAccent),
                      const SizedBox(width: 6),
                      Text(
                        errorText,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// InputDecoration Helper
  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: MyConstants.charcoalColor.withValues(alpha: 0.7), fontSize: 18),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: MyConstants.charcoalColor.withValues(alpha: 0.6), width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: MyConstants.charcoalColor.withValues(alpha: 0.6), width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: MyConstants.tealColor, width: 2.5),
      ),
    );
  }

  TextStyle _inputTextStyle() {
    return TextStyle(
      color: MyConstants.charcoalColor,
      fontSize: 20,
      fontWeight: FontWeight.w600,
    );
  }
}
