import 'package:flutter/material.dart';

/// « Application développée par PyreCore », avec PyreCore en rouge
/// (plus clair en thème sombre pour rester lisible).
class DevelopedBy extends StatelessWidget {
  final TextStyle? style;
  final TextAlign textAlign;

  const DevelopedBy({super.key, this.style, this.textAlign = TextAlign.start});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Text.rich(
      TextSpan(
        text: 'Application développée par ',
        children: [
          TextSpan(
            text: 'PyreCore',
            style: TextStyle(
              color: dark ? const Color(0xFFFF6B6B) : const Color(0xFFD32F2F),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
      style: style,
      textAlign: textAlign,
    );
  }
}
