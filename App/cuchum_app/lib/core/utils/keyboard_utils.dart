import 'package:flutter/material.dart';

class KeyboardUtils {
  static void dismiss(BuildContext context) {
    FocusScope.of(context).unfocus();
  }
}

class DismissKeyboard extends StatelessWidget {
  final Widget child;

  const DismissKeyboard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => KeyboardUtils.dismiss(context),
      behavior: HitTestBehavior.opaque,
      child: child,
    );
  }
}
