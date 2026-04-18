import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/services/api_models.dart';
import '../../../core/services/user_service.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/trans/language_provider.dart';
import '../../../core/trans/operations_language.dart';
import '../../../core/utils/alert_utils.dart';
import '../widgets/operations_style.dart';

/// Báo cáo xăng gắn chuyến (thời điểm mua do BE tự ghi nhận).
class DriverTripFuelScreen extends StatefulWidget {
  const DriverTripFuelScreen({super.key, required this.trip});

  final TripData trip;

  @override
  State<DriverTripFuelScreen> createState() => _DriverTripFuelScreenState();
}

class _DriverTripFuelScreenState extends State<DriverTripFuelScreen> {
  bool _submitting = false;
  final _costCtrl = TextEditingController();
  String? _receiptPath;

  @override
  void dispose() {
    _costCtrl.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickReceipt() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x == null) return;
    setState(() => _receiptPath = x.path);
  }

  Future<void> _submit() async {
    final t = widget.trip;
    final lang = Provider.of<LanguageProvider>(context, listen: false).language;
    if (t.vehicleId == null || t.vehicleId!.isEmpty) {
      AlertUtils.error(context, OperationsLanguage.get('select_vehicle', lang));
      return;
    }
    if (!t.canLinkFuelReport) {
      AlertUtils.error(context, OperationsLanguage.get('error', lang));
      return;
    }
    if (!t.canAddTripLinkedFuelReport) {
      AlertUtils.error(
        context,
        OperationsLanguage.get('fuel_report_window_hint', lang),
      );
      return;
    }
    if (_receiptPath == null) {
      AlertUtils.error(context, OperationsLanguage.get('receipt_photo', lang));
      return;
    }
    final cost = double.tryParse(_costCtrl.text.replaceAll(',', '').trim());
    if (cost == null || cost <= 0) {
      AlertUtils.error(context, OperationsLanguage.get('total_cost', lang));
      return;
    }

    setState(() => _submitting = true);
    final svc = Provider.of<UserService>(context, listen: false);
    final up = await svc.uploadFile(_receiptPath!, folder: 'fuel-reports');
    if (!up.success || up.data == null) {
      if (mounted) {
        setState(() => _submitting = false);
        AlertUtils.error(context, up.displayMessage);
      }
      return;
    }

    final res = await svc.createFuelReport(
      vehicleId: t.vehicleId!,
      tripId: t.id,
      reportDate: _fmtDate(DateTime.now()),
      totalCost: cost,
      receiptImageUrl: up.data!.fileUrl,
    );

    if (!mounted) return;
    setState(() => _submitting = false);
    if (res.success) {
      AlertUtils.success(context, OperationsLanguage.get('success', lang));
      Navigator.pop(context);
    } else {
      AlertUtils.error(context, res.displayMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context).language;
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final fg = OperationsStyle.fg(isDark);
    final t = widget.trip;

    return Scaffold(
      backgroundColor: OperationsStyle.bg(isDark),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back_rounded, color: fg),
                  ),
                  Expanded(
                    child: Text(
                      OperationsLanguage.get('trip_action_fuel', lang),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: fg,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      t.licensePlate ?? t.vehicleId ?? '',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: fg,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      OperationsLanguage.get('fuel_report_window_hint', lang),
                      style: TextStyle(
                        fontSize: 12,
                        color: OperationsStyle.fgMuted(isDark),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _costCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: fg),
                      decoration: OperationsStyle.inputDeco(
                        isDark,
                        labelText: OperationsLanguage.get('total_cost', lang),
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _pickReceipt,
                      icon: const Icon(Icons.receipt_long, size: 18),
                      label: Text(
                        OperationsLanguage.get('receipt_photo', lang),
                      ),
                    ),
                    if (_receiptPath != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _receiptPath!.split('/').last,
                          style: TextStyle(
                            fontSize: 12,
                            color: OperationsStyle.fgMuted(isDark),
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    FilledButton(
                      style: OperationsStyle.primaryFilled(isDark),
                      onPressed:
                          (_submitting ||
                              !t.canLinkFuelReport ||
                              !t.canAddTripLinkedFuelReport)
                          ? null
                          : _submit,
                      child: _submitting
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(OperationsLanguage.get('submit', lang)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
