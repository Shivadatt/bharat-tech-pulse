import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../shared/components/breadcrumb_widget.dart';
import '../../../shared/layouts/public_scaffold.dart';
import '../../../shared/responsive/responsive_breakpoints.dart';
import '../../../shared/responsive/responsive_container.dart';
import '../../../shared/responsive/responsive_grid.dart';
import '../../../shared/skeletons/empty_state.dart';
import '../../../shared/skeletons/error_state.dart';
import '../../../shared/skeletons/loading_skeleton.dart';
import '../../../shared/widgets/article_card.dart';
import '../controllers/search_page_controller.dart';

class SearchView extends StatefulWidget {
  const SearchView({super.key});

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  SearchPageController get controller => Get.find<SearchPageController>();

  @override
  void initState() {
    super.initState();
    // The controller is type-keyed and survives a visit to an article and back,
    // so onInit never re-runs and the old results would stay on screen under a
    // bare /search URL. Re-sync with the route instead.
    controller.syncRouteQuery();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = ResponsiveBreakpoints.isMobile(context);

    return PublicScaffold(
      body: ResponsiveContainer(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BreadcrumbWidget(
              items: [
                BreadcrumbItem(label: 'Search'),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Search Technology & Guides',
              style: theme.textTheme.displaySmall?.copyWith(
                fontSize: compact ? 24 : null,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Query our database of AI tools, phone benchmarks, UPI walkthroughs, and safety protocols.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),

            // Search Bar Input
            Builder(
              builder: (context) {
                final compact = ResponsiveBreakpoints.isMobileSmall(context);
                final field = TextField(
                  controller: controller.searchController,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (q) => controller.performSearch(q),
                  decoration: InputDecoration(
                    hintText: compact
                        ? 'Search AI, phones, UPI, safety...'
                        : 'e.g. Sarvam AI, UPI Lite, Best phones under ₹20,000, DigiLocker...',
                    // No labelText on an icon-only field; InputDecoration uses
                    // hintText as the semantics label, which is what a screen
                    // reader announces here.
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      tooltip: 'Clear search',
                      // clearSearch() also drops the previous results and the
                      // "Found N stories" header; emptying the field alone left
                      // stale results under an empty input.
                      onPressed: controller.clearSearch,
                    ),
                  ),
                );
                final button = ElevatedButton(
                  onPressed: () => controller.performSearch(controller.searchController.text),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                  child: const Text('Search'),
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      field,
                      const SizedBox(height: 12),
                      button,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: field),
                    const SizedBox(width: 12),
                    button,
                  ],
                );
              },
            ),
            const SizedBox(height: 36),

            // Results State
            Obx(() {
              if (controller.isLoading.value) {
                return Column(
                  children: const [
                    LoadingSkeleton(height: 120),
                    SizedBox(height: 16),
                    LoadingSkeleton(height: 120),
                  ],
                );
              }

              if (controller.errorMessage.value.isNotEmpty) {
                return ErrorState(
                  message: controller.errorMessage.value,
                  onRetry: () => controller.performSearch(controller.currentQuery.value),
                );
              }

              if (!controller.hasSearched.value) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Text(
                      'Type a keyword above to find relevant stories.',
                      style: TextStyle(color: theme.textTheme.bodySmall?.color),
                    ),
                  ),
                );
              }

              if (controller.searchResults.isEmpty) {
                return EmptyState(
                  title: 'No Matching Articles Found',
                  message:
                      'We couldn\'t find any stories matching "${controller.currentQuery.value}". Try broader terms like "AI", "5G", or "Smartphones".',
                  icon: Icons.search_off_rounded,
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Found ${controller.searchResults.length} stories for "${controller.currentQuery.value}"',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ResponsiveGrid(
                    desktopColumns: 3,
                    tabletColumns: 2,
                    mobileColumns: 1,
                    children: controller.searchResults
                        .map((a) => ArticleCard(article: a))
                        .toList(),
                  ),
                ],
              );
            }),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}
