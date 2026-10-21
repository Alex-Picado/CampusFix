import 'dart:typed_data';

/// In-memory original photograph retained until its upload is acknowledged.
class SelectedPhoto {
  final Uint8List bytes;
  final String fileName;
  final String contentType;
  const SelectedPhoto({
    required this.bytes,
    required this.fileName,
    required this.contentType,
  });
}
