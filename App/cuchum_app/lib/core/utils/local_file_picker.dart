import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Desktop / web: [FileType.image] (macOS sandbox needs user-selected file entitlement).
/// iOS / Android: optional bottom sheet then [ImagePicker].
bool get _useFilePickerForImages =>
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.windows ||
    defaultTargetPlatform == TargetPlatform.linux;

/// Picks a local image path suitable for multipart upload.
/// On macOS/Windows/Linux, uses the system file dialog (avoids broken gallery/camera).
///
/// When [allowCamera] is false, opens gallery directly on mobile (no sheet).
/// When [allowCamera] is true, [sheetBuilder] must build the source chooser (returns via [Navigator.pop] with [ImageSource]).
Future<String?> pickImagePath({
  required BuildContext context,
  Widget Function(BuildContext sheetContext, bool isDark)? sheetBuilder,
  bool allowCamera = true,
  int maxWidth = 1600,
  int maxHeight = 1600,
  int imageQuality = 85,
}) async {
  if (_useFilePickerForImages) {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: false,
    );
    if (r == null || r.files.isEmpty) return null;
    final p = r.files.first.path;
    if (p == null || p.isEmpty) return null;
    return p;
  }

  ImageSource? source;
  if (allowCamera && sheetBuilder != null) {
    source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return sheetBuilder(ctx, isDark);
      },
    );
  } else {
    source = ImageSource.gallery;
  }

  if (source == null) return null;

  final x = await ImagePicker().pickImage(
    source: source,
    maxWidth: maxWidth.toDouble(),
    maxHeight: maxHeight.toDouble(),
    imageQuality: imageQuality,
  );
  return x?.path;
}

/// PDF / images / custom extensions — [withData: false] so paths work on desktop.
Future<String?> pickFilesWithExtensions(List<String> allowedExtensions) async {
  final r = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: allowedExtensions,
    allowMultiple: false,
    withData: false,
  );
  if (r == null || r.files.isEmpty) return null;
  final p = r.files.first.path;
  if (p == null || p.isEmpty) return null;
  return p;
}
