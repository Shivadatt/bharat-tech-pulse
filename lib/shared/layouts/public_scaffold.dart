import 'package:flutter/material.dart';
import '../components/app_footer.dart';
import '../components/app_navbar.dart';
import '../components/mobile_drawer.dart';

class PublicScaffold extends StatelessWidget {
  final Widget body;
  final bool showFooter;
  final Widget? floatingActionButton;

  const PublicScaffold({
    super.key,
    required this.body,
    this.showFooter = true,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppNavbar(),
      endDrawer: const MobileDrawer(),
      body: SingleChildScrollView(
        child: Column(
          children: [
            body,
            if (showFooter) const AppFooter(),
          ],
        ),
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}
