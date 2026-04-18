import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/services/api_models.dart';
import '../../../core/services/location_permission_service.dart';
import '../../../core/services/user_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/trans/language_provider.dart';
import '../../../core/trans/operations_language.dart';
import '../../../core/utils/alert_utils.dart';
import '../widgets/operations_style.dart';

class DriverTripIncidentScreen extends StatefulWidget {
  const DriverTripIncidentScreen({super.key, required this.trip});

  final TripData trip;

  @override
  State<DriverTripIncidentScreen> createState() =>
      _DriverTripIncidentScreenState();
}

class _DriverTripIncidentScreenState extends State<DriverTripIncidentScreen> {
  bool _submitting = false;
  String _type = 'TRAFFIC_TICKET';
  String? _imagePath;
  final _descriptionCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
  }

  Future<void> _requestLocationPermission() async {
    await LocationPermissionService.ensureLocationPermission();
  }

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x == null) return;
    setState(() => _imagePath = x.path);
  }

  Future<void> _submit() async {
    final lang = Provider.of<LanguageProvider>(context, listen: false).language;
    final trip = widget.trip;
    final vehicleId = trip.vehicleId;
    if (vehicleId == null || vehicleId.isEmpty) {
      AlertUtils.error(context, OperationsLanguage.get('select_vehicle', lang));
      return;
    }

    setState(() => _submitting = true);
    final svc = Provider.of<UserService>(context, listen: false);

    String? imageUrl;
    if (_imagePath != null) {
      final up = await svc.uploadFile(_imagePath!, folder: 'incidents');
      if (!up.success || up.data == null) {
        if (mounted) {
          setState(() => _submitting = false);
          AlertUtils.error(context, up.displayMessage);
        }
        return;
      }
      imageUrl = up.data!.fileUrl;
    }

    final desc = _descriptionCtrl.text.trim();
    final res = await svc.createIncident(
      vehicleId: vehicleId,
      type: _type,
      tripId: trip.id,
      description: desc.isEmpty ? null : desc,
      imageUrl: imageUrl,
    );

    if (!mounted) return;
    setState(() => _submitting = false);
    if (res.success) {
      AlertUtils.success(context, OperationsLanguage.get('success', lang));
      Navigator.pop(context, true);
    } else {
      AlertUtils.error(context, res.displayMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context).language;
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final fg = OperationsStyle.fg(isDark);
    final options = [
      _IncidentTypeOption(
        code: 'ACCIDENT',
        label: OperationsLanguage.get('incident_type_accident', lang),
      ),
      _IncidentTypeOption(
        code: 'BREAKDOWN',
        label: OperationsLanguage.get('incident_type_breakdown', lang),
      ),
      _IncidentTypeOption(
        code: 'TRAFFIC_TICKET',
        label: OperationsLanguage.get('incident_type_traffic_ticket', lang),
      ),
    ];

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
                      OperationsLanguage.get('trip_action_incident', lang),
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
                      widget.trip.licensePlate ?? widget.trip.vehicleId ?? '',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: fg,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _type,
                      isExpanded: true,
                      decoration: OperationsStyle.inputDeco(
                        isDark,
                        labelText: OperationsLanguage.get(
                          'incident_type',
                          lang,
                        ),
                      ),
                      items: options
                          .map(
                            (o) => DropdownMenuItem<String>(
                              value: o.code,
                              child: Text(o.label),
                            ),
                          )
                          .toList(),
                      onChanged: _submitting
                          ? null
                          : (v) {
                              if (v == null) return;
                              setState(() => _type = v);
                            },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _descriptionCtrl,
                      enabled: !_submitting,
                      maxLines: 4,
                      style: TextStyle(color: fg),
                      decoration: OperationsStyle.inputDeco(
                        isDark,
                        labelText: OperationsLanguage.get(
                          'incident_description',
                          lang,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _submitting ? null : _pickImage,
                      icon: const Icon(Icons.photo_camera_outlined, size: 18),
                      label: Text(
                        OperationsLanguage.get('incident_photo_optional', lang),
                      ),
                    ),
                    if (_imagePath != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _imagePath!.split('/').last,
                          style: TextStyle(
                            fontSize: 12,
                            color: OperationsStyle.fgMuted(isDark),
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _submitting ? null : _submit,
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

class _IncidentTypeOption {
  const _IncidentTypeOption({required this.code, required this.label});

  final String code;
  final String label;
}
