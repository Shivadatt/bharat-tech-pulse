import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/theme/theme_colors.dart';

class CategoryChip extends StatelessWidget {
  final String label;
  final String slug;
  final bool isSelected;
  final VoidCallback? onTap;

  const CategoryChip({
    super.key,
    required this.label,
    required this.slug,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        // An RLS-dropped category row yields an empty slug, and `//' is not a
        // declared route; the chip then renders as plain, inert text.
        onTap: onTap ?? (slug.isEmpty ? null : () => Get.toNamed('/$slug/')),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? primary : primary.withAlpha(20),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? primary : primary.withAlpha(50),
              width: 1,
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: isSelected
                  ? (theme.brightness == Brightness.dark ? Colors.black : Colors.white)
                  : AppColors.linkText(theme.brightness),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
