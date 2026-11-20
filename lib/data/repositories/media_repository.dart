import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class MediaRepository {
  /// Uploads an image and returns the URL it can be shown from.
  ///
  /// The real version does the presigned-URL flow:
  ///  1. POST /media/upload-url with the filename and content type
  ///  2. PUT the bytes to the returned upload_url (no auth header)
  ///  3. return the returned public_url
  Future<String> uploadImage({
    required Uint8List bytes,
    required String filename,
    required String contentType,
  });
}

class MockMediaRepository implements MediaRepository {
  @override
  Future<String> uploadImage({
    required Uint8List bytes,
    required String filename,
    required String contentType,
  }) async {
    await Future.delayed(const Duration(milliseconds: 900));
    // A "data URL" holds the picture inside the text itself, so the mock can
    // show what you picked without a server. The real URL will be https://...
    return 'data:$contentType;base64,${base64Encode(bytes)}';
  }
}

final mediaRepositoryProvider = Provider<MediaRepository>((ref) {
  return MockMediaRepository();
});