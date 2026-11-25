import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/media_upload_service.dart';

abstract class MediaRepository {
  /// Uploads an image and returns the URL it can be shown from.
  ///
  /// The real version does the presigned-URL flow:
  ///  1. POST /api/v1/media/upload-url with the filename and content type
  ///  2. PUT the bytes to the returned upload_url (no auth header)
  ///  3. return the returned public_url
  Future<String> uploadImage({
    required Uint8List bytes,
    required String filename,
    required String contentType,
  });

  /// Uploads arbitrary media (video reels, pdf resumes, etc.) with specified bucket purpose.
  Future<MediaUploadResult> uploadMediaFile({
    required Uint8List bytes,
    required String filename,
    required String contentType,
    String purpose = 'private',
  });
}

/// Remote implementation of [MediaRepository] interacting directly with FastAPI & MinIO storage.
class RemoteMediaRepository implements MediaRepository {
  final MediaUploadService _uploadService;

  RemoteMediaRepository({MediaUploadService? uploadService})
      : _uploadService = uploadService ?? MediaUploadService();

  @override
  Future<String> uploadImage({
    required Uint8List bytes,
    required String filename,
    required String contentType,
  }) async {
    final result = await _uploadService.uploadFile(
      bytes: bytes,
      fileName: filename,
      contentType: contentType,
      purpose: 'public',
    );
    return result.publicUrl;
  }

  @override
  Future<MediaUploadResult> uploadMediaFile({
    required Uint8List bytes,
    required String filename,
    required String contentType,
    String purpose = 'private',
  }) async {
    return await _uploadService.uploadFile(
      bytes: bytes,
      fileName: filename,
      contentType: contentType,
      purpose: purpose,
    );
  }
}

/// Mock media repository for offline or disconnected testing.
class MockMediaRepository implements MediaRepository {
  @override
  Future<String> uploadImage({
    required Uint8List bytes,
    required String filename,
    required String contentType,
  }) async {
    await Future.delayed(const Duration(milliseconds: 900));
    return 'data:$contentType;base64,${base64Encode(bytes)}';
  }

  @override
  Future<MediaUploadResult> uploadMediaFile({
    required Uint8List bytes,
    required String filename,
    required String contentType,
    String purpose = 'private',
  }) async {
    await Future.delayed(const Duration(milliseconds: 900));
    final mockUrl = 'data:$contentType;base64,${base64Encode(bytes)}';
    return MediaUploadResult(
      uploadUrl: mockUrl,
      fileKey: 'media/mock-user/mock-id/$filename',
      publicUrl: mockUrl,
      bucket: purpose == 'private' ? 'cineconnect-private' : 'cineconnect-public',
      purpose: purpose,
      expiresInSeconds: 3600,
    );
  }
}

final mediaRepositoryProvider = Provider<MediaRepository>((ref) {
  const useMock = bool.fromEnvironment('USE_MOCK_PH', defaultValue: false);
  if (useMock) {
    return MockMediaRepository();
  }
  final uploadService = ref.watch(mediaUploadServiceProvider);
  return RemoteMediaRepository(uploadService: uploadService);
});
