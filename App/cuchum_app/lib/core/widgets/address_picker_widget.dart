import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/address_service.dart';

/// A 3-part address input widget.
/// Flow: Province → Commune → Street number
/// Combined result: "Street, Commune, Province"
///
/// Behaviour:
/// - Selecting a new province clears commune AND street field.
/// - Selecting a new commune clears the street field.
/// - Shows a loading indicator while fetching from the API.
class AddressPickerWidget extends StatefulWidget {
  final String? initialAddress;
  final bool isDark;
  final bool required;
  final void Function(AddressResult result) onChanged;

  const AddressPickerWidget({
    super.key,
    this.initialAddress,
    required this.isDark,
    required this.onChanged,
    this.required = false,
  });

  @override
  State<AddressPickerWidget> createState() => _AddressPickerWidgetState();
}

class _AddressPickerWidgetState extends State<AddressPickerWidget> {
  final _streetCtrl = TextEditingController();
  ProvinceData? _selectedProvince;
  CommuneData? _selectedCommune;

  bool _isLoadingProvinces = false;
  bool _isLoadingCommunes = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill street only when editing an existing non-Media address
    if (widget.initialAddress != null && widget.initialAddress!.isNotEmpty) {
      _streetCtrl.text = widget.initialAddress!;
    }
    _streetCtrl.addListener(_notify);
  }

  @override
  void dispose() {
    _streetCtrl.removeListener(_notify);
    _streetCtrl.dispose();
    super.dispose();
  }

  void _notify() {
    widget.onChanged(
      AddressResult(
        street: _streetCtrl.text,
        commune: _selectedCommune,
        province: _selectedProvince,
      ),
    );
  }

  // ── Province selection ─────────────────────────────────────────────────────

  Future<void> _selectProvince() async {
    if (_isLoadingProvinces) return;

    setState(() => _isLoadingProvinces = true);
    final provinces = await AddressService.getProvinces();
    if (!mounted) {
      setState(() => _isLoadingProvinces = false);
      return;
    }
    setState(() => _isLoadingProvinces = false);

    final result = await _showSearchSheet<ProvinceData>(
      context: context,
      title: 'Chọn Tỉnh/Thành phố',
      items: provinces,
      labelOf: (p) => p.name,
      isDark: widget.isDark,
    );

    if (result != null && mounted) {
      setState(() {
        _selectedProvince = result;
        _selectedCommune = null; // reset commune
        _streetCtrl.clear(); // reset street — prevent stale data
      });
      _notify();
    }
  }

  // ── Commune selection ──────────────────────────────────────────────────────

  Future<void> _selectCommune() async {
    if (_selectedProvince == null || _isLoadingCommunes) return;

    setState(() => _isLoadingCommunes = true);
    final communes = await AddressService.getCommunes(_selectedProvince!.code);
    if (!mounted) {
      setState(() => _isLoadingCommunes = false);
      return;
    }
    setState(() => _isLoadingCommunes = false);

    final result = await _showSearchSheet<CommuneData>(
      context: context,
      title: 'Chọn Xã/Phường',
      items: communes,
      labelOf: (c) => c.name,
      isDark: widget.isDark,
    );

    if (result != null && mounted) {
      setState(() {
        _selectedCommune = result;
        _streetCtrl.clear(); // reset street — prevent stale data
      });
      _notify();
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final hintColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Province ────────────────────────────────────────────────────
        _label('Tỉnh/Thành phố', isDark, required: widget.required),
        const SizedBox(height: 6),
        _SelectorButton(
          label: _selectedProvince?.name ?? 'Chọn tỉnh/thành phố...',
          hasValue: _selectedProvince != null,
          isLoading: _isLoadingProvinces,
          isDark: isDark,
          onTap: _selectProvince,
        ),
        const SizedBox(height: 14),

        // ── Commune ─────────────────────────────────────────────────────
        _label('Xã/Phường', isDark),
        const SizedBox(height: 6),
        _SelectorButton(
          label:
              _selectedCommune?.name ??
              (_selectedProvince == null
                  ? 'Chọn tỉnh/thành phố trước'
                  : 'Chọn xã/phường...'),
          hasValue: _selectedCommune != null,
          isLoading: _isLoadingCommunes,
          isDark: isDark,
          enabled: _selectedProvince != null && !_isLoadingProvinces,
          onTap: _selectedProvince != null ? _selectCommune : null,
        ),
        const SizedBox(height: 14),

        // ── Street ──────────────────────────────────────────────────────
        _label('Số nhà, Tên đường', isDark),
        const SizedBox(height: 6),
        TextField(
          controller: _streetCtrl,
          style: TextStyle(fontSize: 14, color: textColor),
          decoration: InputDecoration(
            hintText: 'Ví dụ: 41 Đường Nguyễn Huệ',
            hintStyle: TextStyle(color: hintColor, fontSize: 14),
            filled: true,
            fillColor: isDark
                ? AppColors.darkInputFill
                : AppColors.lightInputFill,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
          ),
        ),

        // ── Preview ─────────────────────────────────────────────────────
        if (_selectedProvince != null || _selectedCommune != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    AddressResult(
                      street: _streetCtrl.text,
                      commune: _selectedCommune,
                      province: _selectedProvince,
                    ).combined,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _label(String text, bool isDark, {bool required = false}) {
    return Row(
      children: [
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
        ),
        if (required) ...[
          const SizedBox(width: 3),
          const Text(
            '*',
            style: TextStyle(color: AppColors.error, fontSize: 12),
          ),
        ],
      ],
    );
  }
}

// ─── Selector Button ─────────────────────────────────────────────────────────

class _SelectorButton extends StatelessWidget {
  final String label;
  final bool hasValue;
  final bool isDark;
  final bool enabled;
  final bool isLoading;
  final VoidCallback? onTap;

  const _SelectorButton({
    required this.label,
    required this.hasValue,
    required this.isDark,
    this.enabled = true,
    this.isLoading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fillColor = isDark
        ? AppColors.darkInputFill
        : AppColors.lightInputFill;
    final textColor = hasValue && enabled
        ? (isDark ? AppColors.darkText : AppColors.lightText)
        : (isDark ? AppColors.darkBorder : const Color(0xFFADB5BD));

    return InkWell(
      onTap: (enabled && !isLoading) ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: enabled ? fillColor : fillColor.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: hasValue
              ? Border.all(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  width: 1.5,
                )
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                isLoading ? 'Đang tải...' : label,
                style: TextStyle(
                  fontSize: 14,
                  color: isLoading
                      ? (isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary)
                      : textColor,
                  fontStyle: isLoading ? FontStyle.italic : FontStyle.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Show spinner while loading, chevron otherwise
            isLoading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary.withValues(alpha: 0.6),
                    ),
                  )
                : Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: enabled
                        ? (isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary)
                        : AppColors.darkBorder,
                    size: 20,
                  ),
          ],
        ),
      ),
    );
  }
}

// ─── Generic Searchable Selection Sheet ──────────────────────────────────────

Future<T?> _showSearchSheet<T>({
  required BuildContext context,
  required String title,
  required List<T> items,
  required String Function(T) labelOf,
  required bool isDark,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SearchSheet<T>(
      title: title,
      items: items,
      labelOf: labelOf,
      isDark: isDark,
    ),
  );
}

class _SearchSheet<T> extends StatefulWidget {
  final String title;
  final List<T> items;
  final String Function(T) labelOf;
  final bool isDark;

  const _SearchSheet({
    required this.title,
    required this.items,
    required this.labelOf,
    required this.isDark,
  });

  @override
  State<_SearchSheet<T>> createState() => _SearchSheetState<T>();
}

class _SearchSheetState<T> extends State<_SearchSheet<T>> {
  final _searchCtrl = TextEditingController();
  List<T> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.items;
    _searchCtrl.addListener(_filter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? widget.items
          : widget.items
                .where((item) => widget.labelOf(item).toLowerCase().contains(q))
                .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bgColor = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              widget.title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Divider(color: borderColor, height: 1),
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Text(
                      'Không tìm thấy kết quả',
                      style: TextStyle(color: borderColor),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 20),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final item = _filtered[i];
                      return ListTile(
                        title: Text(
                          widget.labelOf(item),
                          style: TextStyle(fontSize: 15, color: textColor),
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: borderColor,
                        ),
                        onTap: () => Navigator.pop(context, item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
