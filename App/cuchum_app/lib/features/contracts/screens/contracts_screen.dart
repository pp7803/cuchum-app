import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/trans/language_provider.dart';
import '../../../core/trans/contracts_language.dart';
import '../../../core/services/user_service.dart';
import '../../../core/services/api_models.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/utils/alert_utils.dart';
import '../../../core/utils/keyboard_utils.dart';
import '../../../core/utils/local_file_picker.dart';
import '../../../core/services/api_service.dart';
import 'contract_pdf_viewer_screen.dart';

/// Employment contracts.
/// - DRIVER: [driverId] null — read-only list of own contracts (Hồ sơ).
/// - ADMIN: [driverId] + optional [driverName] — manage that driver's contracts (FAB create).
/// - [embeddedInShell]: true when shown as a main tab (no back button).
class ContractsScreen extends StatefulWidget {
  final String? driverId;
  final String? driverName;
  final bool embeddedInShell;

  const ContractsScreen({
    super.key,
    this.driverId,
    this.driverName,
    this.embeddedInShell = false,
  });

  @override
  State<ContractsScreen> createState() => _ContractsScreenState();
}

class _ContractsScreenState extends State<ContractsScreen> {
  List<ContractData> _contracts = [];
  bool _isLoading = true;
  /// ADMIN only: null = all, else PENDING | ACKNOWLEDGED | DECLINED
  String? _ackFilter;

  bool get _isAdminManaging => widget.driverId != null;

  bool get _showBackButton =>
      !widget.embeddedInShell || _isAdminManaging;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final svc = Provider.of<UserService>(context, listen: false);
    final result = await svc.getContracts(
      driverId: widget.driverId,
      acknowledgmentStatus: _isAdminManaging ? _ackFilter : null,
    );
    if (!mounted) return;
    setState(() {
      _contracts = result.data?.contracts ?? [];
      _isLoading = false;
    });
  }

  Future<void> _openPdf(ContractData c, AppLanguage lang) async {
    if (!_isAdminManaging) {
      final userService = Provider.of<UserService>(context, listen: false);
      await userService.markContractViewed(c.id);
      if (mounted) _load();
    }
    if (!mounted) return;
    final fileUrl = c.fileUrl;
    final fullUrl = fileUrl.startsWith('http://') || fileUrl.startsWith('https://')
        ? fileUrl
        : '${ApiConstants.baseUrl}$fileUrl';
    final api = Provider.of<ApiService>(context, listen: false);
    final headers = <String, String>{};
    final token = api.accessToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ContractPdfViewerScreen(
          pdfUrl: fullUrl,
          title: ContractsLanguage.get('open_pdf', lang),
          httpHeaders: headers.isEmpty ? null : headers,
        ),
      ),
    );
  }

  Future<void> _acknowledgeContract(ContractData c, AppLanguage lang) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ContractsLanguage.get('ack_confirm_title', lang)),
        content: Text(ContractsLanguage.get('ack_confirm_body', lang)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ContractsLanguage.get('cancel', lang)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ContractsLanguage.get('ack_btn', lang)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final svc = Provider.of<UserService>(context, listen: false);
    final r = await svc.respondContract(c.id, status: 'ACKNOWLEDGED');
    if (!mounted) return;
    if (r.success) {
      AlertUtils.success(context, ContractsLanguage.get('responded_ok', lang));
      _load();
    } else {
      AlertUtils.error(context, r.displayMessage);
    }
  }

  Future<void> _declineContract(ContractData c, AppLanguage lang, bool isDark) async {
    final note = await showDialog<String?>(
      context: context,
      builder: (ctx) => _DeclineContractDialog(lang: lang, isDark: isDark),
    );
    if (note == null || note.isEmpty || !mounted) return;
    final svc = Provider.of<UserService>(context, listen: false);
    final r = await svc.respondContract(c.id, status: 'DECLINED', note: note);
    if (!mounted) return;
    if (r.success) {
      AlertUtils.success(context, ContractsLanguage.get('responded_ok', lang));
      _load();
    } else {
      AlertUtils.error(context, r.displayMessage);
    }
  }

  Widget _buildAdminFilters(AppLanguage lang, bool isDark, Color textColor) {
    final secondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    Widget chip(String? value, String labelKey) {
      final selected = _ackFilter == value;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilterChip(
          label: Text(
            ContractsLanguage.get(labelKey, lang),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : textColor,
            ),
          ),
          selected: selected,
          onSelected: (_) {
            setState(() => _ackFilter = value);
            _load();
          },
          selectedColor: AppColors.primary,
          checkmarkColor: Colors.white,
          backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
          side: BorderSide(color: secondary.withValues(alpha: 0.35)),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ContractsLanguage.get('admin_tools', lang),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: secondary),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                chip(null, 'filter_all'),
                chip('PENDING', 'filter_pending'),
                chip('ACKNOWLEDGED', 'filter_ack'),
                chip('DECLINED', 'filter_declined'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateSheet(AppLanguage lang, bool isDark) {
    final id = widget.driverId;
    if (id == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateContractSheet(
        driverId: id,
        driverName: widget.driverName ?? '',
        lang: lang,
        isDark: isDark,
        onCreated: _load,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final lang = Provider.of<LanguageProvider>(context).language;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF0F4FF),
      floatingActionButton: _isAdminManaging
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateSheet(lang, isDark),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: Text(ContractsLanguage.get('create', lang),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header (title trái, refresh phải — giống Payslips) ─────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (_showBackButton)
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor),
                    )
                  else
                    const SizedBox(width: 8),
                  Flexible(
                    fit: FlexFit.loose,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _isAdminManaging &&
                                widget.driverName != null &&
                                widget.driverName!.isNotEmpty
                            ? '${widget.driverName} — ${ContractsLanguage.get('title', lang)}'
                            : ContractsLanguage.get(
                                _isAdminManaging ? 'title' : 'my_contracts', lang),
                        textAlign: TextAlign.start,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _isLoading ? null : _load,
                    icon: Icon(Icons.refresh_rounded, color: textColor),
                  ),
                ],
              ),
            ),

            if (_isAdminManaging) _buildAdminFilters(lang, isDark, textColor),

            // ── List ──────────────────────────────────────────────────
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _contracts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.description_outlined,
                                  size: 64,
                                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                              const SizedBox(height: 12),
                              Text(ContractsLanguage.get('empty', lang),
                                  style: TextStyle(
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary)),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          color: AppColors.primary,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                            itemCount: _contracts.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (_, i) => ContractCard(
                              contract: _contracts[i],
                              isDark: isDark,
                              lang: lang,
                              isAdmin: _isAdminManaging,
                              onOpenPdf: () => _openPdf(_contracts[i], lang),
                              onAcknowledge: _isAdminManaging || !_contracts[i].canRespond
                                  ? null
                                  : () => _acknowledgeContract(_contracts[i], lang),
                              onDecline: _isAdminManaging || !_contracts[i].canRespond
                                  ? null
                                  : () => _declineContract(_contracts[i], lang, isDark),
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Contract Card
// ─────────────────────────────────────────────────────────────────────────────

class ContractCard extends StatelessWidget {
  final ContractData contract;
  final bool isDark;
  final AppLanguage lang;
  final bool isAdmin;
  final VoidCallback onOpenPdf;
  final VoidCallback? onAcknowledge;
  final VoidCallback? onDecline;

  const ContractCard({
    required this.contract,
    required this.isDark,
    required this.lang,
    required this.isAdmin,
    required this.onOpenPdf,
    this.onAcknowledge,
    this.onDecline,
  });

  Color _ackColor(String s) {
    switch (s.toUpperCase()) {
      case 'ACKNOWLEDGED':
        return AppColors.success;
      case 'DECLINED':
        return AppColors.error;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isActive = contract.isActive;
    final statusColor = isActive ? AppColors.success : AppColors.error;
    final statusLabel = contract.endDate == null || contract.endDate!.isEmpty
        ? ContractsLanguage.get('status_no_end', lang)
        : isActive
            ? ContractsLanguage.get('status_active', lang)
            : ContractsLanguage.get('status_expired', lang);
    final ack = contract.acknowledgmentStatus;
    final ackColor = _ackColor(ack);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isActive
            ? Border.all(color: AppColors.success.withValues(alpha: 0.25), width: 1)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: contract number + status
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.description_rounded,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  contract.contractNumber,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: ackColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      ContractsLanguage.ackLabel(ack, lang),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: ackColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (isAdmin && contract.isViewed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.visibility_outlined,
                      size: 14,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                  const SizedBox(width: 6),
                  Text(
                    ContractsLanguage.get('viewed_badge', lang),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),

          // Dates
          _dateRow(isDark, Icons.calendar_today_outlined,
              ContractsLanguage.get('start_date', lang),
              ContractsLanguage.formatDate(contract.startDate, lang)),
          const SizedBox(height: 6),
          _dateRow(isDark, Icons.event_outlined,
              ContractsLanguage.get('end_date', lang),
              contract.endDate?.isNotEmpty == true
                  ? ContractsLanguage.formatDate(contract.endDate!, lang)
                  : ContractsLanguage.get('no_end_date', lang)),

          if (isAdmin &&
              contract.acknowledgmentStatus.toUpperCase() == 'DECLINED' &&
              contract.driverNote != null &&
              contract.driverNote!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ContractsLanguage.get('reason_label', lang),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    contract.driverNote!,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Open PDF button
          if (contract.fileUrl.isNotEmpty) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onOpenPdf,
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: Text(ContractsLanguage.get('open_pdf', lang)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary, width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],

          if (onAcknowledge != null && onDecline != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDecline,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      ContractsLanguage.get('ack_no', lang),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: onAcknowledge,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      ContractsLanguage.get('ack_yes', lang),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _dateRow(bool isDark, IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon,
            size: 15,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isDark ? AppColors.darkText : AppColors.lightText,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Create Contract Sheet (Admin only)
// ─────────────────────────────────────────────────────────────────────────────

class _CreateContractSheet extends StatefulWidget {
  final String driverId;
  final String driverName;
  final AppLanguage lang;
  final bool isDark;
  final VoidCallback onCreated;

  const _CreateContractSheet({
    required this.driverId,
    required this.driverName,
    required this.lang,
    required this.isDark,
    required this.onCreated,
  });

  @override
  State<_CreateContractSheet> createState() => _CreateContractSheetState();
}

class _CreateContractSheetState extends State<_CreateContractSheet> {
  final _formKey = GlobalKey<FormState>();
  final _contractNumCtrl = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  String? _uploadedFileUrl;
  String? _uploadedFileName;
  bool _isUploading = false;
  bool _isSubmitting = false;

  AppLanguage get lang => widget.lang;
  bool get isDark => widget.isDark;

  @override
  void dispose() {
    _contractNumCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadFile() async {
    final svc = Provider.of<UserService>(context, listen: false);
    final path = await pickFilesWithExtensions(['pdf']);
    if (path == null) return;
    if (!mounted) return;

    setState(() { _isUploading = true; _uploadedFileUrl = null; });

    final uploadResult = await svc.uploadFile(path, folder: 'contracts');

    if (!mounted) return;
    setState(() {
      _isUploading = false;
      if (uploadResult.success && uploadResult.data != null) {
        _uploadedFileUrl = uploadResult.data!.fileUrl;
        _uploadedFileName = path.split(RegExp(r'[/\\]')).last;
      }
    });

    if (!uploadResult.success && mounted) {
      AlertUtils.error(context, uploadResult.displayMessage);
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart
        ? (_startDate ?? DateTime.now())
        : (_endDate ?? (_startDate ?? DateTime.now()).add(const Duration(days: 365)));
    final first = isStart ? DateTime(2000) : (_startDate ?? DateTime.now());

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(picked)) _endDate = null;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  String _fmtDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

  String _toIso(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null) {
      AlertUtils.error(context, ContractsLanguage.get('start_date', lang) + ' là bắt buộc');
      return;
    }
    if (_uploadedFileUrl == null) {
      AlertUtils.error(context, ContractsLanguage.get('file_required', lang));
      return;
    }

    setState(() => _isSubmitting = true);
    final svc = Provider.of<UserService>(context, listen: false);
    final result = await svc.createContract(
      driverId: widget.driverId,
      contractNumber: _contractNumCtrl.text.trim(),
      fileUrl: _uploadedFileUrl!,
      startDate: _toIso(_startDate!),
      endDate: _endDate != null ? _toIso(_endDate!) : null,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result.success) {
      Navigator.pop(context);
      AlertUtils.success(context, ContractsLanguage.get('created_success', lang));
      widget.onCreated();
    } else {
      AlertUtils.error(context, result.displayMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? AppColors.darkSurface : Colors.white;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final secondaryColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final fillColor = isDark ? AppColors.darkInputFill : AppColors.lightInputFill;

    return DismissKeyboard(
      child: Container(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 32,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: borderColor, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(ContractsLanguage.get('create_title', lang),
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(ContractsLanguage.get('cancel', lang),
                          style: TextStyle(color: secondaryColor)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Driver badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline_rounded, size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(widget.driverName,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.primary)),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Contract number
                _fieldLabel(ContractsLanguage.get('contract_number', lang), textColor),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _contractNumCtrl,
                  decoration: InputDecoration(
                    hintText: ContractsLanguage.get('contract_number_hint', lang),
                    prefixIcon: const Icon(Icons.numbers_rounded, size: 18),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? ContractsLanguage.get('field_required', lang)
                      : null,
                ),
                const SizedBox(height: 16),

                // Start date
                _fieldLabel(ContractsLanguage.get('start_date', lang), textColor,
                    required: true),
                const SizedBox(height: 6),
                _DatePickerButton(
                  label: _startDate != null
                      ? _fmtDate(_startDate!)
                      : ContractsLanguage.get('start_date_hint', lang),
                  hasValue: _startDate != null,
                  isDark: isDark,
                  onTap: () => _pickDate(isStart: true),
                ),
                const SizedBox(height: 16),

                // End date (optional)
                _fieldLabel(
                    '${ContractsLanguage.get('end_date', lang)} (${lang == AppLanguage.vi ? 'tùy chọn' : 'optional'})',
                    textColor),
                const SizedBox(height: 6),
                _DatePickerButton(
                  label: _endDate != null
                      ? _fmtDate(_endDate!)
                      : ContractsLanguage.get('end_date_hint', lang),
                  hasValue: _endDate != null,
                  isDark: isDark,
                  onTap: () => _pickDate(isStart: false),
                  showClear: _endDate != null,
                  onClear: () => setState(() => _endDate = null),
                ),
                const SizedBox(height: 16),

                // Upload PDF
                _fieldLabel(ContractsLanguage.get('upload_pdf', lang), textColor,
                    required: true),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _isUploading ? null : _pickAndUploadFile,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: fillColor,
                      borderRadius: BorderRadius.circular(12),
                      border: _uploadedFileUrl != null
                          ? Border.all(
                              color: AppColors.success.withValues(alpha: 0.5), width: 1.5)
                          : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (_uploadedFileUrl != null
                                    ? AppColors.success
                                    : AppColors.primary)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _uploadedFileUrl != null
                                ? Icons.check_circle_outline_rounded
                                : Icons.upload_file_rounded,
                            color: _uploadedFileUrl != null
                                ? AppColors.success
                                : AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _isUploading
                              ? Row(
                                  children: [
                                    const SizedBox(
                                      width: 16, height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: AppColors.primary),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(ContractsLanguage.get('uploading', lang),
                                        style: TextStyle(fontSize: 13, color: secondaryColor)),
                                  ],
                                )
                              : Text(
                                  _uploadedFileName != null
                                      ? '${ContractsLanguage.get('file_selected', lang)}: $_uploadedFileName'
                                      : ContractsLanguage.get('upload_pdf', lang),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _uploadedFileName != null
                                        ? AppColors.success
                                        : secondaryColor,
                                  ),
                                ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: secondaryColor, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: (_isSubmitting || _isUploading) ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text(ContractsLanguage.get('confirm', lang)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String text, Color textColor, {bool required = false}) {
    return Row(
      children: [
        Text(text,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600,
                letterSpacing: 0.8, color: textColor.withValues(alpha: 0.7))),
        if (required) ...[
          const SizedBox(width: 3),
          const Text('*', style: TextStyle(color: AppColors.error, fontSize: 12)),
        ],
      ],
    );
  }
}

class _DeclineContractDialog extends StatefulWidget {
  const _DeclineContractDialog({required this.lang, required this.isDark});

  final AppLanguage lang;
  final bool isDark;

  @override
  State<_DeclineContractDialog> createState() => _DeclineContractDialogState();
}

class _DeclineContractDialogState extends State<_DeclineContractDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    return AlertDialog(
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      title: Text(
        ContractsLanguage.get('decline_title', widget.lang),
        style: TextStyle(color: isDark ? AppColors.darkText : AppColors.lightText),
      ),
      content: TextField(
        controller: _ctrl,
        maxLines: 4,
        decoration: InputDecoration(
          hintText: ContractsLanguage.get('decline_hint', widget.lang),
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(ContractsLanguage.get('cancel', widget.lang)),
        ),
        FilledButton(
          onPressed: () {
            final t = _ctrl.text.trim();
            if (t.isEmpty) return;
            Navigator.pop(context, t);
          },
          child: Text(ContractsLanguage.get('decline_send', widget.lang)),
        ),
      ],
    );
  }
}

class _DatePickerButton extends StatelessWidget {
  final String label;
  final bool hasValue;
  final bool isDark;
  final VoidCallback? onTap;
  final bool showClear;
  final VoidCallback? onClear;

  const _DatePickerButton({
    required this.label,
    required this.hasValue,
    required this.isDark,
    this.onTap,
    this.showClear = false,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final fillColor = isDark ? AppColors.darkInputFill : AppColors.lightInputFill;
    final textColor = hasValue
        ? (isDark ? AppColors.darkText : AppColors.lightText)
        : (isDark ? AppColors.darkBorder : const Color(0xFFADB5BD));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(12),
          border: hasValue
              ? Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.5)
              : null,
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_month_outlined,
                size: 18,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: textColor))),
            if (showClear)
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.clear_rounded, size: 18, color: AppColors.error),
              )
            else
              Icon(Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
          ],
        ),
      ),
    );
  }
}
