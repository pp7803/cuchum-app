import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/services/api_models.dart';
import '../../../core/services/user_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/trans/language_provider.dart';
import '../../../core/trans/operations_language.dart';
import '../../../core/utils/alert_utils.dart';
import '../widgets/operations_style.dart';

/// Checklist gắn với một chuyến cụ thể (từ màn chi tiết).
class DriverTripChecklistScreen extends StatefulWidget {
  const DriverTripChecklistScreen({super.key, required this.trip});

  final TripData trip;

  @override
  State<DriverTripChecklistScreen> createState() =>
      _DriverTripChecklistScreenState();
}

class _DriverTripChecklistScreenState extends State<DriverTripChecklistScreen> {
  bool _submitting = false;
  bool _tire = true;
  bool _light = true;
  bool _clean = true;
  bool _brake = true;
  bool _oil = true;
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final t = widget.trip;
    final lang = Provider.of<LanguageProvider>(context, listen: false).language;
    if (t.vehicleId == null || t.vehicleId!.isEmpty) {
      AlertUtils.error(context, OperationsLanguage.get('select_vehicle', lang));
      return;
    }
    if (!t.isEligibleForChecklist) {
      AlertUtils.error(
        context,
        OperationsLanguage.get('ops_no_trip_for_checklist', lang),
      );
      return;
    }
    setState(() => _submitting = true);
    final svc = Provider.of<UserService>(context, listen: false);
    final res = await svc.createChecklist(
      vehicleId: t.vehicleId!,
      tripId: t.id,
      tireCheck: _tire,
      lightCheck: _light,
      cleanCheck: _clean,
      brakeCheck: _brake,
      oilCheck: _oil,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
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

  Widget _switch(String label, bool v, void Function(bool) onChanged, Color fg) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: TextStyle(color: fg, fontSize: 14)),
      value: v,
      activeTrackColor: AppColors.primary.withValues(alpha: 0.35),
      activeThumbColor: AppColors.primary,
      onChanged: onChanged,
    );
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
                      OperationsLanguage.get('trip_action_checklist', lang),
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
                    if (!t.isEligibleForChecklist)
                      Text(
                        OperationsLanguage.get(
                          'ops_no_trip_for_checklist',
                          lang,
                        ),
                        style: const TextStyle(color: AppColors.warning),
                      )
                    else ...[
                      Text(
                        t.licensePlate ?? t.vehicleId ?? '',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: fg,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _switch(
                        OperationsLanguage.get('tire', lang),
                        _tire,
                        (v) => setState(() => _tire = v),
                        fg,
                      ),
                      _switch(
                        OperationsLanguage.get('lights', lang),
                        _light,
                        (v) => setState(() => _light = v),
                        fg,
                      ),
                      _switch(
                        OperationsLanguage.get('clean', lang),
                        _clean,
                        (v) => setState(() => _clean = v),
                        fg,
                      ),
                      _switch(
                        OperationsLanguage.get('brake', lang),
                        _brake,
                        (v) => setState(() => _brake = v),
                        fg,
                      ),
                      _switch(
                        OperationsLanguage.get('oil', lang),
                        _oil,
                        (v) => setState(() => _oil = v),
                        fg,
                      ),
                      TextField(
                        controller: _noteCtrl,
                        maxLines: 3,
                        style: TextStyle(color: fg),
                        decoration: OperationsStyle.inputDeco(
                          isDark,
                          labelText: OperationsLanguage.get('note', lang),
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        style: OperationsStyle.primaryFilled(isDark),
                        onPressed: (_submitting || !t.isEligibleForChecklist)
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
