/// A file chosen by the user, already read into memory.
class PickedFile {
  final String name;
  final List<int> bytes;
  final int size;

  const PickedFile({
    required this.name,
    required this.bytes,
    required this.size,
  });
}

abstract class PlatformFileSelector {
  /// Opens the platform picker filtered to images. Returns null when the user
  /// cancels; throws [UnsupportedError] where no picker exists.
  Future<PickedFile?> pickImage();
}
