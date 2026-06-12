import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

/// Thrown when a picked file cannot be turned into an avatar (e.g. an
/// unsupported or corrupted image format).
class AvatarImageException implements Exception {
  const AvatarImageException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Opens the system gallery and converts the chosen photo into a compact
/// square `data:image/jpeg;base64,...` URI, the format `PATCH /me/profile`
/// stores on the AppUser node (capped server-side at ~300k characters —
/// a 256px JPEG stays far below that).
///
/// Returns null when the user cancels the picker.
class AvatarImageService {
  AvatarImageService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  static const int _avatarSizePx = 256;
  static const int _jpegQuality = 80;

  final ImagePicker _picker;

  Future<String?> pickAvatarDataUri() async {
    // maxWidth/imageQuality pre-shrink on mobile; desktop implementations
    // ignore them, so the real resize happens in _encodeAvatarDataUri.
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 90,
    );
    if (file == null) return null;

    final bytes = await file.readAsBytes();
    return compute(_encodeAvatarDataUri, bytes);
  }
}

String _encodeAvatarDataUri(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const AvatarImageException('That file is not a supported image.');
  }

  // Apply EXIF rotation before cropping so phone photos keep their orientation.
  final oriented = img.bakeOrientation(decoded);
  final square = img.copyResizeCropSquare(
    oriented,
    size: AvatarImageService._avatarSizePx,
  );
  final jpeg = img.encodeJpg(square, quality: AvatarImageService._jpegQuality);
  return 'data:image/jpeg;base64,${base64Encode(jpeg)}';
}
