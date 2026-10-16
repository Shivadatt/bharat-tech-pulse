import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/theme/theme_colors.dart';
import '../../data/models/author_model.dart';
import 'author_avatar.dart';

class AuthorInfoWidget extends StatelessWidget {
  final AuthorModel author;
  final bool showBio;

  const AuthorInfoWidget({
    super.key,
    required this.author,
    this.showBio = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      // A byline whose author row was dropped by RLS carries slug '' and
      // '/author/' is not a declared route; the box becomes inert instead of
      // sending the reader to a 404 from a profile card.
      onTap: author.slug.isEmpty
          ? null
          : () => Get.toNamed('/author/${author.slug}'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AuthorAvatar(
              name: author.name,
              avatarUrl: author.avatarUrl,
              radius: 28,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    author.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    author.role,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.linkText(theme.brightness),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (showBio && author.bio.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      author.bio,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
