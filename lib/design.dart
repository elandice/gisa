import 'package:flutter/material.dart';

const canvasColor = Color(0xFFECF0F5);
const inkColor = Color(0xFF344158);
const mutedColor = Color(0xFF68778D);
const accentColor = Color(0xFF7468C6);
const greenColor = Color(0xFF3E8B78);
const redColor = Color(0xFFB45E68);

class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.color = canvasColor,
    this.inset = false,
    this.radius = 24,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final bool inset;
  final double radius;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: Colors.white.withValues(alpha: .6)),
      boxShadow: inset
          ? [
              BoxShadow(
                color: const Color(0xFFD5DCE6).withValues(alpha: .65),
                offset: const Offset(2, 2),
                blurRadius: 5,
                spreadRadius: -2,
              ),
            ]
          : const [
              BoxShadow(
                color: Color(0xFFCDD5E0),
                offset: Offset(6, 6),
                blurRadius: 16,
                spreadRadius: -2,
              ),
              BoxShadow(
                color: Colors.white,
                offset: Offset(-6, -6),
                blurRadius: 16,
                spreadRadius: -2,
              ),
            ],
    ),
    child: child,
  );
}

class SoftButton extends StatelessWidget {
  const SoftButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.primary = false,
    this.small = false,
    this.color,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool primary;
  final bool small;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final foreground = primary ? Colors.white : (color ?? inkColor);
    return Opacity(
      opacity: onPressed == null ? .45 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: primary ? (color ?? accentColor) : canvasColor,
          borderRadius: BorderRadius.circular(small ? 12 : 15),
          boxShadow: primary
              ? [
                  BoxShadow(
                    color: (color ?? accentColor).withValues(alpha: .22),
                    offset: const Offset(3, 5),
                    blurRadius: 10,
                  ),
                ]
              : const [
                  BoxShadow(
                    color: Color(0xFFCED6E1),
                    offset: Offset(3, 3),
                    blurRadius: 7,
                  ),
                  BoxShadow(
                    color: Colors.white,
                    offset: Offset(-3, -3),
                    blurRadius: 7,
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(small ? 12 : 15),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(small ? 12 : 15),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: small ? 14 : 20,
                vertical: small ? 11 : 15,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: small ? 17 : 19, color: foreground),
                    const SizedBox(width: 9),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      color: foreground,
                      fontSize: small ? 12 : 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.color = accentColor});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
    ),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: const TextStyle(
                  color: mutedColor,
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
            ],
          ],
        ),
      ),
      ?trailing,
    ],
  );
}

class ProgressTrack extends StatelessWidget {
  const ProgressTrack(this.value, {super.key, this.color = accentColor});
  final double value;
  final Color color;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: LinearProgressIndicator(
      value: value.clamp(0, 1),
      minHeight: 7,
      color: color,
      backgroundColor: const Color(0xFFDDE3EC),
    ),
  );
}

IconData categoryIcon(String id) => switch (id) {
  'keyword' => Icons.lightbulb_outline_rounded,
  'sql' => Icons.storage_rounded,
  'control' => Icons.alt_route_rounded,
  'pointer' => Icons.near_me_outlined,
  'struct' => Icons.account_tree_outlined,
  'function' => Icons.functions_rounded,
  'java' => Icons.coffee_rounded,
  _ => Icons.code_rounded,
};

Color categoryColor(String id) => switch (id) {
  'keyword' => accentColor,
  'sql' => greenColor,
  'control' => const Color(0xFF597FB2),
  'pointer' => const Color(0xFFB68759),
  'struct' => const Color(0xFFAD748E),
  'function' => const Color(0xFF608F99),
  'java' => const Color(0xFFAD785D),
  _ => const Color(0xFF6A8D65),
};
