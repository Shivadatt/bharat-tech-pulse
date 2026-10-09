import 'file_selector_types.dart';

/// Non-browser fallback (tests, dart CLI): the picker is simply unavailable
/// and the media screen reports that instead of pretending to upload.
class WebFileSelector implements PlatformFileSelector {
  const WebFileSelector();

  @override
  Future<PickedFile?> pickImage() async {
    throw UnsupportedError(
      'File picking is only available when running the site in a browser.',
    );
  }
}
