import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SearchBarWidget extends StatefulWidget {
  final String? initialQuery;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;

  const SearchBarWidget({
    super.key,
    this.initialQuery,
    this.autofocus = false,
    this.onSubmitted,
  });

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _triggerSearch() {
    final query = _controller.text.trim();
    if (query.isNotEmpty) {
      if (widget.onSubmitted != null) {
        widget.onSubmitted!(query);
      } else {
        Get.toNamed('/search?q=${Uri.encodeComponent(query)}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      autofocus: widget.autofocus,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _triggerSearch(),
      decoration: InputDecoration(
        hintText: 'Search AI, phones, apps, how-to guides...',
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        suffixIcon: IconButton(
          icon: const Icon(Icons.arrow_forward_rounded, size: 18),
          onPressed: _triggerSearch,
        ),
      ),
    );
  }
}
