import 'package:flutter/material.dart';
import 'package:get/get.dart';

class BreadcrumbItem {
  final String label;
  final String? route;

  const BreadcrumbItem({required this.label, this.route});
}

class BreadcrumbWidget extends StatelessWidget {
  final List<BreadcrumbItem> items;

  const BreadcrumbWidget({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.color ?? Colors.grey;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        children: [
          InkWell(
            onTap: () => Get.toNamed('/'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.home_outlined, size: 15, color: muted),
                const SizedBox(width: 4),
                Text('Home', style: TextStyle(color: muted, fontSize: 13)),
              ],
            ),
          ),
          ...items.expand((item) {
            final isLast = item == items.last;
            return [
              Icon(Icons.chevron_right_rounded, size: 15, color: muted),
              if (isLast || item.route == null)
                Text(
                  item.label,
                  style: TextStyle(
                    color: theme.textTheme.bodyLarge?.color,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
                InkWell(
                  onTap: () => Get.toNamed(item.route!),
                  child: Text(
                    item.label,
                    style: TextStyle(color: muted, fontSize: 13),
                  ),
                ),
            ];
          }),
        ],
      ),
    );
  }
}
