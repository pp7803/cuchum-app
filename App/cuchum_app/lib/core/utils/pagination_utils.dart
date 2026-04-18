import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

// ─── Pagination Controller ────────────────────────────────────────────────────

/// Immutable pagination state. Pass into [PaginationWidget] and manage
/// updates externally (e.g. in a StatefulWidget).
class PaginationState {
  final int currentPage;
  final int totalItems;
  final int itemsPerPage;

  const PaginationState({
    this.currentPage = 1,
    this.totalItems = 0,
    this.itemsPerPage = 20,
  });

  int get totalPages =>
      totalItems == 0 ? 1 : (totalItems / itemsPerPage).ceil();
  bool get hasPrev => currentPage > 1;
  bool get hasNext => currentPage < totalPages;
  int get startIndex => (currentPage - 1) * itemsPerPage + 1;
  int get endIndex => (currentPage * itemsPerPage).clamp(0, totalItems);

  PaginationState copyWith({
    int? currentPage,
    int? totalItems,
    int? itemsPerPage,
  }) =>
      PaginationState(
        currentPage: currentPage ?? this.currentPage,
        totalItems: totalItems ?? this.totalItems,
        itemsPerPage: itemsPerPage ?? this.itemsPerPage,
      );
}

/// Client-side paging when the API returns a full list (same bar as [MemberManagementScreen]).
PaginationState paginationStateForTotal(PaginationState p, int totalItems) {
  if (totalItems <= 0) {
    return p.copyWith(currentPage: 1, totalItems: 0);
  }
  final per = p.itemsPerPage <= 0 ? 20 : p.itemsPerPage;
  final pages = (totalItems + per - 1) ~/ per;
  final clamped = p.currentPage.clamp(1, pages);
  return p.copyWith(currentPage: clamped, totalItems: totalItems, itemsPerPage: per);
}

List<T> paginatedSlice<T>(List<T> items, PaginationState p) {
  if (items.isEmpty) return [];
  final per = p.itemsPerPage <= 0 ? 20 : p.itemsPerPage;
  final start = (p.currentPage - 1) * per;
  if (start >= items.length) return [];
  final end = (start + per).clamp(0, items.length);
  return items.sublist(start, end);
}

// ─── Pagination Widget ────────────────────────────────────────────────────────

class PaginationWidget extends StatefulWidget {
  final PaginationState state;
  final void Function(int page) onPageChanged;
  final void Function(int size)? onPageSizeChanged;
  final List<int> pageSizeOptions;
  final bool isDark;

  const PaginationWidget({
    super.key,
    required this.state,
    required this.onPageChanged,
    required this.isDark,
    this.onPageSizeChanged,
    this.pageSizeOptions = const [10, 20, 50],
  });

  @override
  State<PaginationWidget> createState() => _PaginationWidgetState();
}

class _PaginationWidgetState extends State<PaginationWidget> {
  final _jumpCtrl = TextEditingController();

  @override
  void dispose() {
    _jumpCtrl.dispose();
    super.dispose();
  }

  void _jump() {
    final page = int.tryParse(_jumpCtrl.text.trim());
    if (page != null && page >= 1 && page <= widget.state.totalPages) {
      widget.onPageChanged(page);
      _jumpCtrl.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final isDark = widget.isDark;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final secondaryColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final surfaceColor = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    if (s.totalItems == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(top: BorderSide(color: borderColor, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Summary row ──────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${s.startIndex}–${s.endIndex} / ${s.totalItems}',
                style: TextStyle(
                  fontSize: 12,
                  color: secondaryColor,
                ),
              ),
              if (widget.onPageSizeChanged != null)
                _PageSizeSelector(
                  value: s.itemsPerPage,
                  options: widget.pageSizeOptions,
                  isDark: isDark,
                  onChanged: widget.onPageSizeChanged!,
                ),
            ],
          ),
          const SizedBox(height: 10),
          // ── Page buttons row ─────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // First + Prev
              _NavBtn(
                icon: Icons.first_page_rounded,
                enabled: s.hasPrev,
                isDark: isDark,
                onTap: () => widget.onPageChanged(1),
              ),
              const SizedBox(width: 4),
              _NavBtn(
                icon: Icons.chevron_left_rounded,
                enabled: s.hasPrev,
                isDark: isDark,
                onTap: () => widget.onPageChanged(s.currentPage - 1),
              ),
              const SizedBox(width: 8),
              // Page numbers
              ..._buildPageNumbers(s, textColor, secondaryColor, isDark),
              const SizedBox(width: 8),
              // Next + Last
              _NavBtn(
                icon: Icons.chevron_right_rounded,
                enabled: s.hasNext,
                isDark: isDark,
                onTap: () => widget.onPageChanged(s.currentPage + 1),
              ),
              const SizedBox(width: 4),
              _NavBtn(
                icon: Icons.last_page_rounded,
                enabled: s.hasNext,
                isDark: isDark,
                onTap: () => widget.onPageChanged(s.totalPages),
              ),
            ],
          ),
          // ── Jump to page ─────────────────────────────────────────────
          if (s.totalPages > 3) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Đến trang:', style: TextStyle(fontSize: 12, color: secondaryColor)),
                const SizedBox(width: 8),
                SizedBox(
                  width: 52,
                  height: 32,
                  child: TextField(
                    controller: _jumpCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: textColor),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      filled: true,
                      fillColor: isDark ? AppColors.darkInputFill : AppColors.lightInputFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                    onSubmitted: (_) => _jump(),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: _jump,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.arrow_forward_rounded,
                        color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildPageNumbers(
    PaginationState s,
    Color textColor,
    Color secondaryColor,
    bool isDark,
  ) {
    final pages = _visiblePages(s.currentPage, s.totalPages);
    final widgets = <Widget>[];

    for (int i = 0; i < pages.length; i++) {
      final p = pages[i];
      if (p == -1) {
        // Ellipsis
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Text('…', style: TextStyle(color: secondaryColor, fontSize: 13)),
        ));
      } else {
        widgets.add(_PageBtn(
          page: p,
          isActive: p == s.currentPage,
          isDark: isDark,
          onTap: () => widget.onPageChanged(p),
        ));
      }
      if (i < pages.length - 1) widgets.add(const SizedBox(width: 4));
    }
    return widgets;
  }

  /// Returns a list of page numbers with -1 for ellipsis
  List<int> _visiblePages(int current, int total) {
    if (total <= 7) return List.generate(total, (i) => i + 1);

    final result = <int>{};
    result.add(1);
    result.add(total);

    // Window around current
    for (int p = current - 1; p <= current + 1; p++) {
      if (p >= 1 && p <= total) result.add(p);
    }

    final sorted = result.toList()..sort();

    // Insert ellipsis (-1) where there are gaps > 1
    final withEllipsis = <int>[];
    for (int i = 0; i < sorted.length; i++) {
      if (i > 0 && sorted[i] - sorted[i - 1] > 1) {
        withEllipsis.add(-1);
      }
      withEllipsis.add(sorted[i]);
    }
    return withEllipsis;
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final bool isDark;
  final VoidCallback onTap;

  const _NavBtn({
    required this.icon,
    required this.enabled,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled
        ? AppColors.primary
        : (isDark ? AppColors.darkBorder : AppColors.lightBorder);

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

class _PageBtn extends StatelessWidget {
  final int page;
  final bool isActive;
  final bool isDark;
  final VoidCallback onTap;

  const _PageBtn({
    required this.page,
    required this.isActive,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary
              : (isDark ? AppColors.darkSurface : Colors.white),
          borderRadius: BorderRadius.circular(8),
          border: isActive
              ? null
              : Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Center(
          child: Text(
            '$page',
            style: TextStyle(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w400,
              color: isActive
                  ? Colors.white
                  : (isDark ? AppColors.darkText : AppColors.lightText),
            ),
          ),
        ),
      ),
    );
  }
}

class _PageSizeSelector extends StatelessWidget {
  final int value;
  final List<int> options;
  final bool isDark;
  final void Function(int) onChanged;

  const _PageSizeSelector({
    required this.value,
    required this.options,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final bgColor = isDark ? AppColors.darkInputFill : AppColors.lightInputFill;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Mỗi trang:',
            style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary)),
        const SizedBox(width: 6),
        Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: value,
              isDense: true,
              style: TextStyle(fontSize: 12, color: textColor),
              dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
              iconSize: 16,
              iconEnabledColor: textColor,
              items: options
                  .map((o) => DropdownMenuItem(value: o, child: Text('$o')))
                  .toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
      ],
    );
  }
}
