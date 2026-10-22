import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../models/selected_photo.dart';

/// Opens the browser's picker and bounds size before reading selected bytes.
Future<SelectedPhoto?> pickPhoto() async {
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = 'image/jpeg,image/png,image/webp'
    ..style.display = 'none';
  final selection = Completer<web.File?>();
  final change = ((web.Event _) {
    if (!selection.isCompleted) selection.complete(input.files?.item(0));
  }).toJS;
  final cancel = ((web.Event _) {
    if (!selection.isCompleted) selection.complete(null);
  }).toJS;
  input.addEventListener('change', change);
  input.addEventListener('cancel', cancel);
  web.document.body!.append(input);
  try {
    input.click();
    final file = await selection.future;
    if (file == null) return null;
    if (file.size <= 0 || file.size > 3000000) {
      throw const FormatException(
        'La foto debe pesar entre 1 y 3 000 000 bytes.',
      );
    }
    final bytes = (await file.arrayBuffer().toDart).toDart.asUint8List();
    return SelectedPhoto(
      bytes: bytes,
      fileName: file.name,
      contentType: file.type,
    );
  } finally {
    input.removeEventListener('change', change);
    input.removeEventListener('cancel', cancel);
    input.remove();
  }
}
