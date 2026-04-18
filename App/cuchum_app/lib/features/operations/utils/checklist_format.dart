import '../../../core/services/api_models.dart';
import '../../../core/trans/language_provider.dart';
import '../../../core/trans/operations_language.dart';

/// Human-readable checklist lines (e.g. "Lốp: OK") for admin/driver UI.
class ChecklistFormat {
  static List<String> itemLines(ChecklistData c, AppLanguage lang) {
    String row(String labelKey, bool ok) {
      final label = OperationsLanguage.get(labelKey, lang);
      final st = OperationsLanguage.get(
        ok ? 'checklist_ok' : 'checklist_bad',
        lang,
      );
      return '$label: $st';
    }

    return [
      row('tire', c.tireCheck),
      row('lights', c.lightCheck),
      row('clean', c.cleanCheck),
      row('brake', c.brakeCheck),
      row('oil', c.oilCheck),
    ];
  }
}
