import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/seo/seo_service.dart';

/// Writes SEO metadata for pages that have no controller of their own.
///
/// Deliberately a widget rather than a GetMiddleware: GetX does not run
/// middleware for the initial deep-linked route, which is exactly the visit
/// a crawler makes. initState runs on every mount, boot or client-side.
class PageSeoInit extends StatefulWidget {
  final String title;
  final String description;
  final String? canonicalPath;
  final Widget child;

  const PageSeoInit({
    super.key,
    required this.title,
    required this.description,
    this.canonicalPath,
    required this.child,
  });

  @override
  State<PageSeoInit> createState() => _PageSeoInitState();
}

class _PageSeoInitState extends State<PageSeoInit> {
  @override
  void initState() {
    super.initState();
    _apply();
    // Re-assert after the frame: on a 404 deep link GetX boots HomeController
    // (home beneath the unknown route) in the same frame, and whichever runs
    // later wins. The post-frame callback is guaranteed to be that winner.
    WidgetsBinding.instance.addPostFrameCallback((_) => _apply());
  }

  void _apply() {
    Get.find<SeoService>().updateMeta(
      title: widget.title,
      description: widget.description,
      canonicalPath: widget.canonicalPath,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
