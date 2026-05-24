import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../l10n/app_localizations.dart';
import '../models/app_models.dart';
import '../theme/app_theme.dart';

class AddLabTestDialog extends StatefulWidget {
  final void Function(LabTest, {Uint8List? fileBytes, String? pickedFileName}) onAdd;
  const AddLabTestDialog({super.key, required this.onAdd});

  @override
  State<AddLabTestDialog> createState() => _AddLabTestDialogState();
}

class _AddLabTestDialogState extends State<AddLabTestDialog> {
  final _nameCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _doctorCtrl = TextEditingController();
  bool _showSuccess = false;

  String? _pickedFileName;
  Uint8List? _pickedFileBytes;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _pickedFileName = result.files.first.name;
        _pickedFileBytes = result.files.first.bytes;
      });
    }
  }

  void _submit() {
    if (_nameCtrl.text.isEmpty || _dateCtrl.text.isEmpty || _doctorCtrl.text.isEmpty) return;
    final fileName = _pickedFileName ?? '${_nameCtrl.text.replaceAll(' ', '_')}.pdf';
    widget.onAdd(
      LabTest(name: _nameCtrl.text, date: _dateCtrl.text, doctor: _doctorCtrl.text, fileName: fileName),
      fileBytes: _pickedFileBytes,
      pickedFileName: _pickedFileName,
    );
    // Close the dialog immediately — no success popup.
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1976D2), Color(0xFF0D47A1)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
              child: Row(
                children: [
                  Expanded(child: Text(AppLocalizations.of(context).t('dlg_add_lab_title'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 17))),
                  GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, color: Colors.white)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _field(AppLocalizations.of(context).t('dlg_lab_name_label'),
                      _nameCtrl, AppLocalizations.of(context).t('dlg_lab_name_hint')),
                  const SizedBox(height: 14),
                  _datePickerField(
                      AppLocalizations.of(context).t('dlg_lab_date_label'), _dateCtrl),
                  const SizedBox(height: 14),
                  _field(AppLocalizations.of(context).t('dlg_lab_ordered_by'),
                      _doctorCtrl, AppLocalizations.of(context).t('dlg_lab_doctor_name_hint')),
                  const SizedBox(height: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppLocalizations.of(context).t('dlg_lab_upload_label'),
                          style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textPrimary(context),
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: _pickFile,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceAlt(context),
                            border: Border.all(
                                color: _pickedFileName != null
                                    ? const Color(0xFF2563EB)
                                    : AppColors.border(context)),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _pickedFileName != null ? Icons.check_circle : Icons.upload_file,
                                color: AppColors.accent(context),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _pickedFileName ?? AppLocalizations.of(context).t('dlg_lab_choose_file'),
                                  style: TextStyle(
                                    color: _pickedFileName != null
                                        ? AppColors.textPrimary(context)
                                        : AppColors.textMuted(context),
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (_pickedFileName != null)
                                GestureDetector(
                                  onTap: () => setState(() { _pickedFileName = null; _pickedFileBytes = null; }),
                                  child: Icon(Icons.close,
                                      size: 18,
                                      color: AppColors.textMuted(context)),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(AppLocalizations.of(context).t('dlg_lab_add_btn'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _datePickerField(String label, TextEditingController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: AppColors.textPrimary(context), fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          readOnly: true,
          style: TextStyle(color: AppColors.textPrimary(context)),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
            );
            if (picked != null) {
              ctrl.text = DateFormat('MMMM d, yyyy').format(picked);
            }
          },
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context).t('dlg_tap_to_select_date'),
            hintStyle: TextStyle(color: AppColors.textMuted(context)),
            suffixIcon: Icon(Icons.calendar_today, size: 18, color: AppColors.textSecondary(context)),
            filled: true, fillColor: AppColors.surfaceAlt(context),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.border(context))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.border(context))),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _field(String label, TextEditingController ctrl, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: AppColors.textPrimary(context), fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          style: TextStyle(color: AppColors.textPrimary(context)),
          decoration: InputDecoration(
            hintText: hint, hintStyle: TextStyle(color: AppColors.textMuted(context)), filled: true, fillColor: AppColors.surfaceAlt(context),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.border(context))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.border(context))),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ],
    );
  }
}
