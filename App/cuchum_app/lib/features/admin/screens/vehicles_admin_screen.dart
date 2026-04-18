import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/trans/admin_language.dart';
import '../../../core/trans/common_language.dart';
import '../../../core/trans/language_provider.dart';
import '../widgets/admin_ui.dart';
import '../../../core/services/api_models.dart';
import '../../../core/services/user_service.dart';
import '../../../core/utils/alert_utils.dart';
import '../../../core/utils/keyboard_utils.dart';
import '../../../core/utils/local_file_picker.dart';
import '../../../core/utils/pagination_utils.dart';

String _vehicleImageFullUrl(String? path) {
  if (path == null || path.isEmpty) return '';
  if (path.startsWith('http')) return path;
  final base = ApiConstants.baseUrl.replaceAll(RegExp(r'/$'), '');
  final p = path.startsWith('/') ? path : '/$path';
  return '$base$p';
}

String _formatDate(DateTime? d) {
  if (d == null) return '—';
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

String? _toApiDate(DateTime? d) {
  if (d == null) return null;
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// Danh sách + tạo/sửa/xóa xe (ADMIN). Hạn đăng kiểm = `registration_expiry` từ API.
class VehiclesAdminScreen extends StatefulWidget {
  const VehiclesAdminScreen({super.key});

  @override
  State<VehiclesAdminScreen> createState() => _VehiclesAdminScreenState();
}

class _VehiclesAdminScreenState extends State<VehiclesAdminScreen> {
  bool _loading = true;
  List<VehicleData> _list = [];
  String? _statusFilter; // null = all, ACTIVE, INACTIVE
  PaginationState _pagination = const PaginationState(itemsPerPage: 20);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final svc = Provider.of<UserService>(context, listen: false);
    final r = await svc.getVehicles(status: _statusFilter);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _list = r.data?.vehicles ?? [];
      _pagination = paginationStateForTotal(_pagination, _list.length);
    });
    if (!r.success && mounted) {
      AlertUtils.error(context, r.displayMessage);
    }
  }

  Future<void> _openEditor(VehicleData vehicle) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => VehicleEditorScreen(vehicle: vehicle),
      ),
    );
    if (changed == true) _load();
  }

  Future<void> _openCreateVehicleModal() async {
    final lang = Provider.of<LanguageProvider>(context, listen: false).language;
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.45,
        maxChildSize: 0.98,
        expand: false,
        builder: (_, scrollController) => VehicleEditorScreen(
          vehicle: null,
          asModalSheet: true,
          sheetScrollController: scrollController,
        ),
      ),
    );
    if (!mounted) return;
    if (changed == true) {
      AlertUtils.success(context, AdminLanguage.get('vehicle_created', lang));
      _load();
    }
  }

  Future<void> _confirmDelete(VehicleData v) async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final lang = Provider.of<LanguageProvider>(context, listen: false).language;
    final isDark = themeProvider.isDarkMode;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          AdminLanguage.get('vehicle_delete', lang),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkText : AppColors.lightText,
          ),
        ),
        content: Text(
          AdminLanguage.get('vehicle_delete_confirm', lang),
          style: TextStyle(color: isDark ? AppColors.darkText : AppColors.lightText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(CommonLanguage.get('cancel', lang)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              AdminLanguage.get('vehicle_delete', lang),
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final svc = Provider.of<UserService>(context, listen: false);
    final r = await svc.deleteVehicle(v.id);
    if (!mounted) return;
    if (r.success) {
      AlertUtils.success(context, AdminLanguage.get('vehicle_deleted', lang));
      _load();
    } else {
      AlertUtils.error(context, r.displayMessage);
    }
  }

  List<VehicleData> get _pageList => paginatedSlice(_list, _pagination);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final lang = Provider.of<LanguageProvider>(context).language;
    final isDark = themeProvider.isDarkMode;

    final bottomPad = MediaQuery.paddingOf(context).bottom + 24.0;

    return Scaffold(
      backgroundColor: AdminTheme.canvas(isDark),
      bottomNavigationBar: _pagination.totalItems > 0
          ? PaginationWidget(
              state: _pagination,
              isDark: isDark,
              onPageChanged: (p) => setState(
                () => _pagination = _pagination.copyWith(currentPage: p),
              ),
              onPageSizeChanged: (s) => setState(() {
                _pagination = paginationStateForTotal(
                  _pagination.copyWith(currentPage: 1, itemsPerPage: s),
                  _list.length,
                );
              }),
            )
          : null,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateVehicleModal,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          AdminLanguage.get('vehicle_add', lang),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AdminScreenHeader(
              title: AdminLanguage.get('vehicle_management', lang),
              isDark: isDark,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip(lang, isDark, null, AdminLanguage.get('filter_all', lang)),
                    const SizedBox(width: 8),
                    _filterChip(
                        lang, isDark, 'ACTIVE', AdminLanguage.get('filter_active', lang)),
                    const SizedBox(width: 8),
                    _filterChip(
                        lang, isDark, 'INACTIVE', AdminLanguage.get('filter_inactive', lang)),
                  ],
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _load,
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      )
                    : _list.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height: MediaQuery.of(context).size.height * 0.35,
                                child: Center(
                                  child: Text(
                                    AdminLanguage.get('vehicle_none', lang),
                                    style: TextStyle(
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            padding: EdgeInsets.fromLTRB(16, 4, 16, bottomPad),
                            itemCount: _pageList.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (_, i) =>
                                _buildVehicleCard(_pageList[i], lang, isDark),
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        width: 56,
        height: 56,
        color: AppColors.primary.withValues(alpha: 0.12),
        child: const Icon(Icons.directions_car_rounded, color: AppColors.primary),
      );

  Widget _filterChip(AppLanguage lang, bool isDark, String? value, String label) {
    final selected = _statusFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() => _statusFilter = value);
        _load();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : (isDark ? AppColors.darkSurface : Colors.white),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            if (!selected)
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.06),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected
                ? Colors.white
                : (isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleCard(VehicleData v, AppLanguage lang, bool isDark) {
    final url = _vehicleImageFullUrl(v.imageUrl);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openEditor(v),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AdminTheme.outline(isDark)),
            boxShadow: AdminTheme.cardShadow(isDark),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: url.isNotEmpty
                    ? Image.network(
                        url,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _placeholder(),
                      )
                    : _placeholder(),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      v.licensePlate,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                    ),
                    if (v.vehicleType != null && v.vehicleType!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        v.vehicleType!,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      '${AdminLanguage.get('vehicle_registration_expiry', lang)}: ${_formatDate(v.registrationExpiry)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
                onSelected: (val) {
                  if (val == 'edit') _openEditor(v);
                  if (val == 'delete') _confirmDelete(v);
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text(AdminLanguage.get('vehicle_edit', lang)),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      AdminLanguage.get('vehicle_delete', lang),
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class VehicleEditorScreen extends StatefulWidget {
  final VehicleData? vehicle;
  final bool asModalSheet;
  final ScrollController? sheetScrollController;

  const VehicleEditorScreen({
    super.key,
    this.vehicle,
    this.asModalSheet = false,
    this.sheetScrollController,
  });

  @override
  State<VehicleEditorScreen> createState() => _VehicleEditorScreenState();
}

class _VehicleEditorScreenState extends State<VehicleEditorScreen> {
  late final TextEditingController _plateCtrl;
  late final TextEditingController _typeCtrl;
  String _status = 'ACTIVE';
  DateTime? _insurance;
  DateTime? _registration;
  DateTime? _lastMaint;
  DateTime? _nextMaint;
  String? _imageUrl;
  /// Local file chosen in session; uploaded on Save with `vehicle_id` (stable name on server).
  String? _pendingImagePath;
  bool _saving = false;

  bool get _isEdit => widget.vehicle != null;

  @override
  void initState() {
    super.initState();
    final v = widget.vehicle;
    _plateCtrl = TextEditingController(text: v?.licensePlate ?? '');
    _typeCtrl = TextEditingController(text: v?.vehicleType ?? '');
    if (v != null) {
      _status = v.status.isNotEmpty ? v.status : 'ACTIVE';
      _insurance = v.insuranceExpiry;
      _registration = v.registrationExpiry;
      _lastMaint = v.lastMaintenanceDate;
      _nextMaint = v.nextMaintenanceDate;
      _imageUrl = v.imageUrl;
    }
  }

  @override
  void dispose() {
    _plateCtrl.dispose();
    _typeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(String field) async {
    final now = DateTime.now();
    final DateTime initial = field == 'insurance'
        ? (_insurance ?? now)
        : field == 'registration'
            ? (_registration ?? now)
            : field == 'last'
                ? (_lastMaint ?? now)
                : (_nextMaint ?? now);
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d == null || !mounted) return;
    setState(() {
      if (field == 'insurance') {
        _insurance = d;
      } else if (field == 'registration') {
        _registration = d;
      } else if (field == 'last') {
        _lastMaint = d;
      } else {
        _nextMaint = d;
      }
    });
  }

  Future<void> _pickVehiclePhoto() async {
    final path = await pickImagePath(
      context: context,
      allowCamera: false,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 88,
    );
    if (path == null || !mounted) return;
    setState(() => _pendingImagePath = path);
  }

  Map<String, dynamic> _buildBody({String? imageUrl}) {
    final plate = _plateCtrl.text.trim();
    final img = imageUrl ?? _imageUrl;
    final body = <String, dynamic>{
      'license_plate': plate,
      'vehicle_type': _typeCtrl.text.trim().isEmpty ? null : _typeCtrl.text.trim(),
      'status': _status,
      if (img != null && img.isNotEmpty) 'image_url': img,
      if (_insurance != null) 'insurance_expiry': _toApiDate(_insurance),
      if (_registration != null) 'registration_expiry': _toApiDate(_registration),
      if (_lastMaint != null) 'last_maintenance_date': _toApiDate(_lastMaint),
      if (_nextMaint != null) 'next_maintenance_date': _toApiDate(_nextMaint),
    };
    body.removeWhere((k, v) => v == null);
    return body;
  }

  Future<void> _save() async {
    final lang = Provider.of<LanguageProvider>(context, listen: false).language;
    if (_plateCtrl.text.trim().isEmpty) {
      AlertUtils.error(context, AdminLanguage.get('field_required', lang));
      return;
    }
    setState(() => _saving = true);
    final svc = Provider.of<UserService>(context, listen: false);
    var ok = false;
    var failMessage = '';

    if (_isEdit) {
      final id = widget.vehicle!.id;
      String? imageUrl = _imageUrl;
      if (_pendingImagePath != null) {
        final up = await svc.uploadFile(
          _pendingImagePath!,
          folder: 'vehicles',
          vehicleId: id,
        );
        if (!mounted) {
          setState(() => _saving = false);
          return;
        }
        if (!up.success) {
          failMessage = up.displayMessage;
        } else {
          imageUrl = up.data?.fileUrl;
        }
      }
      if (failMessage.isEmpty) {
        final r = await svc.updateVehicle(id, _buildBody(imageUrl: imageUrl));
        if (!mounted) {
          setState(() => _saving = false);
          return;
        }
        ok = r.success;
        if (!ok) failMessage = r.displayMessage;
      }
    } else {
      final r = await svc.createVehicle(_buildBody());
      if (!mounted) {
        setState(() => _saving = false);
        return;
      }
      if (!r.success) {
        failMessage = r.displayMessage;
      } else {
        final newId = r.data!.id;
        if (_pendingImagePath != null) {
          final up = await svc.uploadFile(
            _pendingImagePath!,
            folder: 'vehicles',
            vehicleId: newId,
          );
          if (!mounted) {
            setState(() => _saving = false);
            return;
          }
          if (!up.success) {
            failMessage = up.displayMessage;
          } else {
            final url = up.data?.fileUrl;
            if (url != null && url.isNotEmpty) {
              final r2 = await svc.updateVehicle(newId, {'image_url': url});
              if (!mounted) {
                setState(() => _saving = false);
                return;
              }
              ok = r2.success;
              if (!ok) failMessage = r2.displayMessage;
            } else {
              ok = true;
            }
          }
        } else {
          ok = true;
        }
      }
    }

    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      if (widget.asModalSheet) {
        Navigator.pop(context, true);
      } else {
        AlertUtils.success(
          context,
          _isEdit
              ? AdminLanguage.get('vehicle_updated', lang)
              : AdminLanguage.get('vehicle_created', lang),
        );
        Navigator.pop(context, true);
      }
    } else {
      AlertUtils.error(
        context,
        failMessage.isEmpty ? CommonLanguage.get('error', lang) : failMessage,
      );
    }
  }

  List<Widget> _formListChildren(
    AppLanguage lang,
    bool isDark,
    Color fieldFill,
    OutlineInputBorder fieldBorder,
    String imgUrl,
  ) {
    return [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: imgUrl.isNotEmpty
                        ? Image.network(
                            imgUrl,
                            width: 200,
                            height: 120,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _photoPlaceholder(isDark),
                          )
                        : _photoPlaceholder(isDark),
                  ),
                  if (_pendingImagePath != null)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: ColoredBox(
                          color: Colors.black54,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                AdminLanguage.get('vehicle_image_pending', lang),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _pickVehiclePhoto,
              icon: Icon(Icons.photo_camera_outlined, color: AppColors.primary),
              label: Text(
                AdminLanguage.get('vehicle_pick_photo', lang),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      TextField(
        controller: _plateCtrl,
        decoration: InputDecoration(
          labelText: AdminLanguage.get('vehicle_plate', lang),
          filled: true,
          fillColor: fieldFill,
          border: fieldBorder,
        ),
        textCapitalization: TextCapitalization.characters,
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _typeCtrl,
        decoration: InputDecoration(
          labelText: AdminLanguage.get('vehicle_type', lang),
          hintText: AdminLanguage.get('vehicle_type_hint', lang),
          filled: true,
          fillColor: fieldFill,
          border: fieldBorder,
        ),
      ),
      const SizedBox(height: 14),
      DropdownButtonFormField<String>(
        key: ValueKey<String>(_status),
        initialValue: _status == 'INACTIVE' ? 'INACTIVE' : 'ACTIVE',
        decoration: InputDecoration(
          labelText: AdminLanguage.get('vehicle_status', lang),
          filled: true,
          fillColor: fieldFill,
          border: fieldBorder,
        ),
        items: [
          DropdownMenuItem(
            value: 'ACTIVE',
            child: Text(AdminLanguage.get('status_active', lang)),
          ),
          DropdownMenuItem(
            value: 'INACTIVE',
            child: Text(AdminLanguage.get('status_inactive', lang)),
          ),
        ],
        onChanged: (v) => setState(() => _status = v ?? 'ACTIVE'),
      ),
      const SizedBox(height: 20),
      _dateTile(
        lang,
        isDark,
        AdminLanguage.get('vehicle_insurance_expiry', lang),
        _insurance,
        () => _pickDate('insurance'),
      ),
      _dateTile(
        lang,
        isDark,
        AdminLanguage.get('vehicle_registration_expiry', lang),
        _registration,
        () => _pickDate('registration'),
      ),
      _dateTile(
        lang,
        isDark,
        AdminLanguage.get('vehicle_last_maintenance', lang),
        _lastMaint,
        () => _pickDate('last'),
      ),
      _dateTile(
        lang,
        isDark,
        AdminLanguage.get('vehicle_next_maintenance', lang),
        _nextMaint,
        () => _pickDate('next'),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final lang = Provider.of<LanguageProvider>(context).language;
    final isDark = themeProvider.isDarkMode;
    final imgUrl = _vehicleImageFullUrl(_imageUrl);

    final fieldFill = isDark ? AppColors.darkSurface : Colors.white;
    final fieldBorder = OutlineInputBorder(borderRadius: BorderRadius.circular(12));
    final listChildren = _formListChildren(lang, isDark, fieldFill, fieldBorder, imgUrl);

    if (widget.asModalSheet) {
      final sheetBg = isDark ? AppColors.darkSurface : Colors.white;
      return DismissKeyboard(
        child: Container(
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close_rounded,
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        AdminLanguage.get('vehicle_add', lang),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkText : AppColors.lightText,
                        ),
                      ),
                    ),
                    if (_saving)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        ),
                      )
                    else
                      TextButton(
                        onPressed: _save,
                        child: Text(
                          AdminLanguage.get('vehicle_save', lang),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: widget.sheetScrollController,
                  padding: EdgeInsets.fromLTRB(
                    20,
                    12,
                    20,
                    24 + MediaQuery.of(context).padding.bottom,
                  ),
                  children: listChildren,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return DismissKeyboard(
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF0F4FF),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _isEdit
                            ? AdminLanguage.get('vehicle_edit', lang)
                            : AdminLanguage.get('vehicle_add', lang),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkText : AppColors.lightText,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_saving)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        ),
                      )
                    else
                      TextButton(
                        onPressed: _save,
                        child: Text(
                          AdminLanguage.get('vehicle_save', lang),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  children: listChildren,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoPlaceholder(bool isDark) => Container(
        width: 200,
        height: 120,
        color: AppColors.primary.withValues(alpha: isDark ? 0.14 : 0.08),
        child: Icon(
          Icons.directions_car_rounded,
          size: 48,
          color: isDark ? AppColors.darkTextSecondary : AppColors.primary,
        ),
      );

  Widget _dateTile(
    AppLanguage lang,
    bool isDark,
    String label,
    DateTime? value,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            filled: true,
            fillColor: isDark ? AppColors.darkSurface : Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            suffixIcon: Icon(
              Icons.calendar_today_rounded,
              size: 18,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          child: Text(
            _formatDate(value),
            style: TextStyle(
              fontSize: 16,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
        ),
      ),
    );
  }
}
