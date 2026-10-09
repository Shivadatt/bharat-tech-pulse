import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'file_selector_types.dart';

/// Browser file picker built on a throwaway `<input type=file>`, which avoids
/// adding a plugin dependency to a web-only site.
class WebFileSelector implements PlatformFileSelector {
  const WebFileSelector();

  static const int _maxBytes = 5 * 1024 * 1024;

  @override
  Future<PickedFile?> pickImage() async {
    final input = web.document.createElement('input') as web.HTMLInputElement;
    input.type = 'file';
    input.accept = 'image/*';
    input.style.display = 'none';
    web.document.body!.appendChild(input);

    final completer = Completer<PickedFile?>();
    // One-shot so a cancelled dialog never leaks a listener on the element.
    input.addEventListener('change', (web.Event e) {
      final files = input.files;
      if (files == null || files.length == 0) {
        completer.complete(null);
        return;
      }
      final file = files.item(0);
      if (file == null) {
        completer.complete(null);
        return;
      }
      if (file.size > _maxBytes) {
        completer.completeError(StateError(
          'Image is ${(file.size / 1024 / 1024).toStringAsFixed(1)}MB; '
          'the limit is 5MB.',
        ));
        return;
      }
      file.arrayBuffer().toDart.then((buffer) {
        final bytes = Uint8List.view(buffer.toDart);
        completer.complete(PickedFile(
          name: file.name,
          bytes: bytes,
          size: file.size,
        ));
      }).catchError((Object error) {
        completer.completeError(error);
      });
    }.toJS);

    input.click();
    try {
      return await completer.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () => null,
      );
    } finally {
      input.remove();
    }
  }
}
