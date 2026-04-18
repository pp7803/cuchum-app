import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/trans/language_provider.dart';
import '../../../core/trans/fuel_prices_language.dart';
import '../../../core/services/user_service.dart';
import '../../../core/services/api_models.dart';

class FuelPricesScreen extends StatefulWidget {
  const FuelPricesScreen({super.key});

  @override
  State<FuelPricesScreen> createState() => _FuelPricesScreenState();
}

class _FuelPricesScreenState extends State<FuelPricesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  FuelPricesData? _data;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _hasError = false; });
    final svc = Provider.of<UserService>(context, listen: false);
    final result = await svc.getFuelPrices();
    if (!mounted) return;
    setState(() {
      _data = result.data;
      _isLoading = false;
      _hasError = !result.success || result.data == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final lang = Provider.of<LanguageProvider>(context).language;
    final bgColor = isDark ? AppColors.darkBackground : const Color(0xFFF0F4FF);
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final surfaceColor = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor),
                  ),
                  Expanded(
                    child: Text(
                      FuelPricesLanguage.get('title', lang),
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
                    ),
                  ),
                  IconButton(
                    onPressed: _isLoading ? null : _load,
                    icon: Icon(Icons.refresh_rounded, color: textColor),
                    tooltip: 'Tải lại',
                  ),
                ],
              ),
            ),

            // ── Company TabBar ──────────────────────────────────────────
            if (!_isLoading && !_hasError && _data != null) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                        blurRadius: 8, offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TabBar(
                    controller: _tabs,
                    indicator: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Colors.white,
                    unselectedLabelColor: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                    labelStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                    unselectedLabelStyle: const TextStyle(fontSize: 13),
                    dividerColor: Colors.transparent,
                    padding: const EdgeInsets.all(4),
                    tabs: [
                      Tab(text: _data!.petrolimex.company),
                      Tab(text: _data!.pvoil.company),
                    ],
                  ),
                ),
              ),
            ],

            // ── Content ─────────────────────────────────────────────────
            Expanded(
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(color: AppColors.primary),
                          const SizedBox(height: 16),
                          Text(FuelPricesLanguage.get('loading', lang),
                              style: TextStyle(color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary)),
                        ],
                      ),
                    )
                  : _hasError || _data == null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.wifi_off_rounded,
                                  size: 56, color: borderColor),
                              const SizedBox(height: 12),
                              Text(FuelPricesLanguage.get('error', lang),
                                  style: TextStyle(
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary)),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _load,
                                icon: const Icon(Icons.refresh_rounded),
                                label: Text(FuelPricesLanguage.get('retry', lang)),
                              ),
                            ],
                          ),
                        )
                      : TabBarView(
                          controller: _tabs,
                          children: [
                            _CompanyPricesTab(
                              company: _data!.petrolimex,
                              isDark: isDark,
                              lang: lang,
                            ),
                            _CompanyPricesTab(
                              company: _data!.pvoil,
                              isDark: isDark,
                              lang: lang,
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Company prices tab
// ─────────────────────────────────────────────────────────────────────────────

class _CompanyPricesTab extends StatelessWidget {
  final FuelCompanyPrices company;
  final bool isDark;
  final AppLanguage lang;

  const _CompanyPricesTab({
    required this.company,
    required this.isDark,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceColor = isDark ? AppColors.darkSurface : Colors.white;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final secondaryColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final hasZone2 = company.prices.any((p) => p.priceZone2 != null);

    return RefreshIndicator(
      onRefresh: () async {
        // Refresh handled by parent — pull to refresh reloads whole screen
        context.findAncestorStateOfType<_FuelPricesScreenState>()!._load();
      },
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // ── Updated at ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule_rounded, size: 15, color: AppColors.info),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${FuelPricesLanguage.get('updated_at', lang)}: ${_formatDate(company.updatedAt)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.info),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Column headers ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Loại nhiên liệu',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: Text(
                    FuelPricesLanguage.get('zone1', lang),
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                  ),
                ),
                if (hasZone2)
                  SizedBox(
                    width: 80,
                    child: Text(
                      FuelPricesLanguage.get('zone2', lang),
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ── Price rows ─────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.05),
                  blurRadius: 10, offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: company.prices.asMap().entries.map((entry) {
                final i = entry.key;
                final p = entry.value;
                final isDiesel = p.name.toLowerCase().contains('do') ||
                    p.name.toLowerCase().contains('dầu') ||
                    p.name.toLowerCase().contains('dau');
                final fuelColor = isDiesel ? AppColors.warning : const Color(0xFF059669);

                return Column(
                  children: [
                    if (i > 0) Divider(color: borderColor, height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 13),
                      child: Row(
                        children: [
                          // Fuel type indicator dot
                          Container(
                            width: 8, height: 8,
                            decoration: BoxDecoration(
                              color: fuelColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 3,
                            child: Text(
                              p.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: textColor,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 80,
                            child: Text(
                              _formatPrice(p.priceZone1),
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: fuelColor,
                              ),
                            ),
                          ),
                          if (hasZone2)
                            SizedBox(
                              width: 80,
                              child: Text(
                                p.priceZone2 != null
                                    ? _formatPrice(p.priceZone2!)
                                    : '–',
                                textAlign: TextAlign.end,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: p.priceZone2 != null ? textColor : secondaryColor,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          // Unit note
          Text(
            '${FuelPricesLanguage.get('unit', lang)} (VNĐ)',
            textAlign: TextAlign.end,
            style: TextStyle(fontSize: 11, color: secondaryColor),
          ),
        ],
      ),
    );
  }

  String _formatPrice(String raw) {
    // "26080" or "26.080" → format with dots
    final num = double.tryParse(raw.replaceAll('.', '').replaceAll(',', ''));
    if (num == null) return raw;
    // Format as Vietnamese number: 26.080
    final s = num.toInt().toString();
    final result = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) result.write('.');
      result.write(s[i]);
    }
    return result.toString();
  }

  String _formatDate(String raw) {
    // Try parsing ISO datetime
    try {
      final dt = DateTime.parse(raw).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw; // Already formatted text (PVOil uses string format)
    }
  }
}
