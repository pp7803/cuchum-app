import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/trans/language_provider.dart';
import '../../../core/trans/profile_language.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/services/user_service.dart';
import '../../../core/services/address_service.dart';
import '../../../core/widgets/address_picker_widget.dart';
import '../../../core/services/api_models.dart';
import '../../../core/utils/alert_utils.dart';
import '../../../core/utils/keyboard_utils.dart';
import '../../../core/utils/local_file_picker.dart';
import '../../../core/widgets/change_password_sheet.dart';
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  ProfileData? _profile;
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;
  bool _privacyMode = true; // default: hide sensitive fields

  /// Local path of optional proof file chosen while editing (uploaded on save).
  String? _proofPickPath;
  String? _proofPickName;

  final _citizenIdController = TextEditingController();
  final _licenseClassController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  final _addressController = TextEditingController(); // kept for display only
  AddressResult _addressResult = const AddressResult();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _citizenIdController.dispose();
    _licenseClassController.dispose();
    _licenseNumberController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final userService = Provider.of<UserService>(context, listen: false);
    final result = await userService.getProfile();

    if (!mounted) return;
    setState(() {
      _profile = result.data;
      if (_profile != null) {
        _citizenIdController.text = _profile!.citizenId ?? '';
        _licenseClassController.text = _profile!.licenseClass ?? '';
        _licenseNumberController.text = _profile!.licenseNumber ?? '';
        _addressController.text = _profile!.address ?? '';
      }
      _isLoading = false;
    });
  }

  Future<void> _pickAndUploadAvatar() async {
    final userService = Provider.of<UserService>(context, listen: false);
    final pickedPath = await pickImagePath(
      context: context,
      allowCamera: true,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
      sheetBuilder: (sheetCtx, isDark) {
        final lang = Provider.of<LanguageProvider>(sheetCtx).language;
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
                title: Text(ProfileLanguage.get('take_photo', lang)),
                onTap: () => Navigator.pop(sheetCtx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
                title: Text(ProfileLanguage.get('pick_from_gallery', lang)),
                onTap: () => Navigator.pop(sheetCtx, ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );

    if (pickedPath == null || !mounted) return;

    setState(() => _isUploadingAvatar = true);

    final uploadResult = await userService.uploadFile(pickedPath, folder: 'avatar');

    if (!mounted) return;

    if (!uploadResult.success) {
      setState(() => _isUploadingAvatar = false);
      AlertUtils.error(context, uploadResult.displayMessage);
      return;
    }

    final updateResult = await userService.updateProfile(
      avatarUrl: uploadResult.data?.fileUrl,
    );

    if (!mounted) return;
    setState(() => _isUploadingAvatar = false);

    if (updateResult.success) {
      await _loadProfile();
    } else {
      AlertUtils.error(context, updateResult.displayMessage);
    }
  }

  Future<void> _saveProfile() async {
    if (!mounted) return;
    setState(() => _isSaving = true);

    final userService = Provider.of<UserService>(context, listen: false);

    // Build address: prefer the structured 3-part picker result,
    // fall back to existing address text if user didn't re-select
    final addressToSave = _addressResult.combined.isNotEmpty
        ? _addressResult.combined         // "Phần1, Phần2, Phần3"
        : (_addressController.text.trim().isNotEmpty ? _addressController.text.trim() : null);

    // Only send fields that have actual values (null = don't change on server)
    final citizenIdVal = _citizenIdController.text.trim();
    final licenseVal = _licenseClassController.text.trim();
    final licenseNoVal = _licenseNumberController.text.trim();

    String? proofUrl;
    final proofPath = _proofPickPath;
    if (proofPath != null && proofPath.isNotEmpty) {
      final uploadResult =
          await userService.uploadFile(proofPath, folder: 'profile-proofs');
      if (!mounted) return;
      if (!uploadResult.success) {
        setState(() => _isSaving = false);
        AlertUtils.error(context, uploadResult.displayMessage);
        return;
      }
      proofUrl = uploadResult.data?.fileUrl;
    }

    final result = await userService.updateProfile(
      citizenId: citizenIdVal.isEmpty ? null : citizenIdVal,
      licenseClass: licenseVal.isEmpty ? null : licenseVal,
      licenseNumber: licenseNoVal.isEmpty ? null : licenseNoVal,
      address: addressToSave,
      proofImageUrl: proofUrl,
    );

    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _isEditing = false;
      _proofPickPath = null;
      _proofPickName = null;
    });

    final lang = Provider.of<LanguageProvider>(context, listen: false).language;
    if (result.success) {
      AlertUtils.success(context, ProfileLanguage.get('profile_updated', lang));
      await _loadProfile();
    } else {
      AlertUtils.error(context, result.displayMessage);
    }
  }

  Future<void> _pickProofFile(AppLanguage lang) async {
    final path = await pickFilesWithExtensions(const ['pdf', 'jpg', 'jpeg', 'png']);
    if (path == null || !mounted) return;
    setState(() {
      _proofPickPath = path;
      _proofPickName = path.split(RegExp(r'[/\\]')).last;
    });
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      _proofPickPath = null;
      _proofPickName = null;
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final lang = languageProvider.language;
    final isDark = themeProvider.isDarkMode;

    return DismissKeyboard(
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF0F4FF),
        body: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : CustomScrollView(
                  slivers: [
                    // ── Gradient header ────────────────────────────────
                    SliverToBoxAdapter(
                      child: _buildHeader(lang, isDark),
                    ),

                    // ── HỒ SƠ section ──────────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionLabel(
                              ProfileLanguage.get('section_profile', lang),
                              isDark,
                            ),
                            const SizedBox(height: 10),
                            _buildAccountInfoCard(lang, isDark),
                            if (_profile?.isDriver ?? false) ...[
                              const SizedBox(height: 12),
                              _buildDriverInfoCard(lang, isDark),
                            ],
                            const SizedBox(height: 12),
                            _buildChangePasswordRow(lang, isDark),
                          ],
                        ),
                      ),
                    ),

                    const SliverToBoxAdapter(
                      child: SizedBox(height: 40),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHeader(AppLanguage lang, bool isDark) {
    final isAdmin = _profile?.isAdmin ?? false;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isAdmin
              ? [AppColors.primary, AppColors.primaryLight]
              : [const Color(0xFF059669), const Color(0xFF10B981)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          // Top bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                ProfileLanguage.get('my_profile', lang),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!_isEditing) ...[
                    // ── Privacy toggle ──────────────────────────────────
                    IconButton(
                      onPressed: () => setState(() => _privacyMode = !_privacyMode),
                      icon: Icon(
                        _privacyMode ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: Colors.white,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(
                            alpha: _privacyMode ? 0.35 : 0.15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      tooltip: _privacyMode ? 'Hiện thông tin' : 'Ẩn thông tin',
                    ),
                    const SizedBox(width: 6),
                    // ── Reload button ───────────────────────────────────
                    IconButton(
                      onPressed: _isLoading ? null : _loadProfile,
                      icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      tooltip: 'Tải lại',
                    ),
                  ],
                  // ── Edit button for DRIVER only ───────────────────────
                  if (_profile?.isDriver ?? false) ...[
                    const SizedBox(width: 6),
                    _isEditing
                        ? Row(
                            children: [
                              _headerBtn(
                                ProfileLanguage.get('cancel', lang),
                                onTap: _cancelEditing,
                              ),
                              const SizedBox(width: 8),
                              _headerBtn(
                                ProfileLanguage.get('save_changes', lang),
                                filled: true,
                                loading: _isSaving,
                                onTap: _isSaving ? null : _saveProfile,
                              ),
                            ],
                          )
                        : IconButton(
                            onPressed: () => setState(() => _isEditing = true),
                            icon: const Icon(Icons.edit_outlined, color: Colors.white),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white.withValues(alpha: 0.2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildAvatar(),
          const SizedBox(height: 12),
          Text(
            _profile?.fullName ?? '',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isAdmin ? 'ADMIN' : 'DRIVER',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerBtn(
    String label, {
    bool filled = false,
    VoidCallback? onTap,
    bool loading = false,
  }) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        backgroundColor: filled
            ? Colors.white.withValues(alpha: 0.25)
            : Colors.white.withValues(alpha: 0.15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            )
          : Text(label, style: const TextStyle(fontSize: 13)),
    );
  }

  Widget _buildAvatar() {
    final name = _profile?.fullName ?? '';
    final initials = name
        .trim()
        .split(' ')
        .map((w) => w.isNotEmpty ? w[0] : '')
        .take(2)
        .join()
        .toUpperCase();

    final avatarUrl = _profile?.avatarUrl;
    final fullAvatarUrl = avatarUrl != null
        ? '${_baseUrl()}$avatarUrl'
        : null;

    return GestureDetector(
      onTap: _isUploadingAvatar ? null : _pickAndUploadAvatar,
      child: Stack(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.25),
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: ClipOval(
              child: _isUploadingAvatar
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : fullAvatarUrl != null
                      ? Image.network(
                          fullAvatarUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _initials(initials),
                        )
                      : _initials(initials),
            ),
          ),
          // Camera overlay badge
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                size: 14,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _baseUrl() => ApiConstants.baseUrl;

  Widget _initials(String text) => Center(
        child: Text(
          text.isEmpty ? '?' : text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

  // ─────────────────────────────────────────────────────────────────────────
  // Privacy masking
  // ─────────────────────────────────────────────────────────────────────────

  /// Masks sensitive string when _privacyMode is on.
  String _mask(String? value, {int start = 3, int end = 0}) {
    if (!_privacyMode || value == null || value.isEmpty) return value ?? '–';
    final s = value.substring(0, start.clamp(0, value.length));
    final e = (end > 0 && value.length > start + end)
        ? value.substring(value.length - end)
        : '';
    return '$s•••••$e';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ACCOUNT INFO CARD
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildAccountInfoCard(AppLanguage lang, bool isDark) {
    return _card(
      isDark: isDark,
      child: Column(
        children: [
          _infoRow(Icons.person_outline_rounded,
              ProfileLanguage.get('full_name', lang), _profile?.fullName ?? '–', isDark),
          _divider(isDark),
          _infoRow(Icons.phone_outlined,
              ProfileLanguage.get('phone_number', lang),
              _mask(_profile?.phoneNumber, start: 4, end: 2), isDark),
          if (_profile?.email != null) ...[
            _divider(isDark),
            _infoRow(Icons.email_outlined,
                ProfileLanguage.get('email', lang),
                _mask(_profile!.email!, start: 3, end: 0), isDark),
          ],
          _divider(isDark),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Icon(Icons.radio_button_checked_rounded,
                    size: 18,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                const SizedBox(width: 12),
                Text(
                  ProfileLanguage.get('status', lang),
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                const Spacer(),
                _statusChip(
                  _profile?.isActive ?? false
                      ? ProfileLanguage.get('status_active', lang)
                      : ProfileLanguage.get('status_inactive', lang),
                  _profile?.isActive ?? false ? AppColors.success : AppColors.error,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DRIVER INFO CARD + PENDING BANNER
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildDriverInfoCard(AppLanguage lang, bool isDark) {
    final pending = _profile?.pendingRequest;
    final hasRejected = pending != null && pending.isRejected;

    return Column(
      children: [
        if (pending != null) ...[
          _buildPendingBanner(pending, lang, isDark),
          const SizedBox(height: 8),
        ],
        _card(
          isDark: isDark,
          child: Column(
            children: [
              _isEditing && !hasRejected
                  ? _buildEditFields(lang, isDark)
                  : Column(
                      children: [
                        _driverInfoRow(
                          Icons.badge_outlined,
                          ProfileLanguage.get('citizen_id', lang),
                          _mask(_profile?.citizenId, start: 4, end: 2),
                          ProfileLanguage.get('not_updated', lang),
                          isDark,
                          isPlaceholder: (_profile?.citizenId?.isEmpty ?? true),
                        ),
                        _divider(isDark),
                        _driverInfoRow(
                          Icons.card_membership_outlined,
                          ProfileLanguage.get('license_class', lang),
                          _profile?.licenseClass,
                          ProfileLanguage.get('not_updated', lang),
                          isDark,
                        ),
                        _divider(isDark),
                        _driverInfoRow(
                          Icons.badge_rounded,
                          ProfileLanguage.get('license_number', lang),
                          _profile?.licenseNumber,
                          ProfileLanguage.get('not_updated', lang),
                          isDark,
                          isPlaceholder: (_profile?.licenseNumber?.isEmpty ?? true),
                        ),
                        _divider(isDark),
                        _driverInfoRow(
                          Icons.home_outlined,
                          ProfileLanguage.get('address', lang),
                          _mask(_profile?.address, start: 6, end: 0),
                          ProfileLanguage.get('not_updated', lang),
                          isDark,
                          isPlaceholder: (_profile?.address?.isEmpty ?? true),
                        ),
                      ],
                    ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPendingBanner(
    ProfileUpdateRequestData pending,
    AppLanguage lang,
    bool isDark,
  ) {
    final isPending = pending.isPending;
    final color = isPending ? AppColors.warning : AppColors.error;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPending ? Icons.pending_outlined : Icons.cancel_outlined,
                color: color,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                isPending
                    ? ProfileLanguage.get('pending_request', lang)
                    : ProfileLanguage.get('pending_rejected', lang),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildPendingChanges(pending, lang, color),
          if (!isPending && pending.adminNote != null) ...[
            const SizedBox(height: 6),
            Text(
              '${ProfileLanguage.get('pending_rejected_reason', lang)}: ${pending.adminNote}',
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPendingChanges(
    ProfileUpdateRequestData pending,
    AppLanguage lang,
    Color color,
  ) {
    final changes = <String>[
      if (pending.citizenId != null)
        '${ProfileLanguage.get('pending_citizen_id', lang)}: ${pending.citizenId}',
      if (pending.licenseClass != null)
        '${ProfileLanguage.get('pending_license_class', lang)}: ${pending.licenseClass}',
      if (pending.licenseNumber != null)
        '${ProfileLanguage.get('pending_license_number', lang)}: ${pending.licenseNumber}',
      if (pending.address != null)
        '${ProfileLanguage.get('pending_address', lang)}: ${pending.address}',
      if (pending.proofImageUrl != null && pending.proofImageUrl!.isNotEmpty)
        '${ProfileLanguage.get('pending_proof', lang)}: ${ProfileLanguage.get('proof_selected', lang)}',
    ];

    if (changes.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: changes
          .map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text('• $c', style: TextStyle(fontSize: 12, color: color)),
              ))
          .toList(),
    );
  }

  Widget _buildEditFields(AppLanguage lang, bool isDark) {
    return Column(
      children: [
        // Citizen ID with 12-digit validation
        _editFieldWithValidation(
          controller: _citizenIdController,
          label: ProfileLanguage.get('citizen_id', lang),
          hint: ProfileLanguage.get('enter_citizen_id', lang),
          icon: Icons.badge_outlined,
          isDark: isDark,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 12,
          validator: (v) {
            if (v != null && v.isNotEmpty && v.length != 12) {
              return ProfileLanguage.get('citizen_id_invalid', lang);
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
        _editField(
          controller: _licenseClassController,
          label: ProfileLanguage.get('license_class', lang),
          hint: ProfileLanguage.get('enter_license_class', lang),
          icon: Icons.card_membership_outlined,
          isDark: isDark,
        ),
        const SizedBox(height: 14),
        _editField(
          controller: _licenseNumberController,
          label: ProfileLanguage.get('license_number', lang),
          hint: ProfileLanguage.get('enter_license_number', lang),
          icon: Icons.badge_rounded,
          isDark: isDark,
        ),
        const SizedBox(height: 14),
        // Structured address picker (Phần3 → Phần2 → Phần1)
        AddressPickerWidget(
          isDark: isDark,
          // Only pre-fill if address is NOT a Media path (bad old data)
          initialAddress: (_profile?.address?.startsWith('/Media') ?? false)
              ? null
              : _profile?.address,
          onChanged: (result) => setState(() => _addressResult = result),
        ),
        const SizedBox(height: 18),
        _buildProofPicker(lang, isDark),
      ],
    );
  }

  Widget _buildProofPicker(AppLanguage lang, bool isDark) {
    final secondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ProfileLanguage.get('proof_optional', lang),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: secondary,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          ProfileLanguage.get('proof_hint', lang),
          style: TextStyle(fontSize: 12, color: secondary),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _isSaving ? null : () => _pickProofFile(lang),
              icon: const Icon(Icons.attach_file_rounded, size: 18),
              label: Text(ProfileLanguage.get('proof_pick', lang)),
            ),
            if (_proofPickName != null) ...[
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _proofPickName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
              ),
              IconButton(
                onPressed: _isSaving
                    ? null
                    : () => setState(() {
                          _proofPickPath = null;
                          _proofPickName = null;
                        }),
                icon: const Icon(Icons.close_rounded, size: 20),
                tooltip: ProfileLanguage.get('proof_remove', lang),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildChangePasswordRow(AppLanguage lang, bool isDark) {
    return _card(
      isDark: isDark,
      child: InkWell(
        onTap: () => ChangePasswordSheet.show(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Icon(Icons.lock_outline_rounded,
                  size: 18,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  ProfileLanguage.get('change_password', lang),
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _sectionLabel(String label, bool isDark) => Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
        ),
      );

  Widget _card({required bool isDark, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _divider(bool isDark) => Divider(
        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        height: 1,
      );

  Widget _infoRow(IconData icon, String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon,
              size: 18,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _driverInfoRow(
    IconData icon,
    String label,
    String? value,
    String placeholder,
    bool isDark, {
    bool? isPlaceholder,
  }) {
    final isEmpty = isPlaceholder ?? (value == null || value.isEmpty);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon,
              size: 18,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isEmpty ? placeholder : value!,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isEmpty ? FontWeight.w400 : FontWeight.w500,
                fontStyle: isEmpty ? FontStyle.italic : FontStyle.normal,
                color: isEmpty
                    ? (isDark ? AppColors.darkBorder : const Color(0xFFD1D5DB))
                    : (isDark ? AppColors.darkText : AppColors.lightText),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _editField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 18),
          ),
        ),
      ],
    );
  }

  Widget _editFieldWithValidation({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLength: maxLength,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 18),
            counterText: '',
          ),
          validator: validator,
        ),
      ],
    );
  }
}
