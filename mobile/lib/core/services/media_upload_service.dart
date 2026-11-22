import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';

/// Represents the response payload from the presigned upload URL endpoint.
class MediaUploadResult {
  final String uploadUrl;
  final String fileKey;
  final String publicUrl;
  final String bucket;
  final String purpose;
  final int expiresInSeconds;

  const MediaUploadResult({
    required this.uploadUrl,
    required this.fileKey,
    required this.publicUrl,
    required this.bucket,
    required this.purpose,
    required this.expiresInSeconds,
  });

  factory MediaUploadResult.fromJson(Map<String, dynamic> json) {
    return MediaUploadResult(
      uploadUrl: json['upload_url'] as String? ?? '',
      fileKey: json['file_key'] as String? ?? '',
      publicUrl: json['public_url'] as String? ?? '',
      bucket: json['bucket'] as String? ?? '',
      purpose: json['purpose'] as String? ?? 'private',
      expiresInSeconds: (json['expires_in_seconds'] as num?)?.toInt() ?? 3600,
    );
  }

  Map<String, dynamic> toJson() => {
        'upload_url': uploadUrl,
        'file_key': fileKey,
        'public_url': publicUrl,
        'bucket': bucket,
        'purpose': purpose,
        'expires_in_seconds': expiresInSeconds,
      };
}

/// Service managing the client-to-storage presigned upload workflow:
/// 1. Requests SigV4 presigned upload URL from FastAPI backend (`POST /api/v1/media/upload-url`).
/// 2. Performs direct binary or streamed HTTP PUT upload to MinIO/S3 object storage with NO Authorization headers.
/// 3. Returns the storage metadata including file key and public URL for attachment.
class MediaUploadService {
  final ApiClient _apiClient;

  MediaUploadService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  /// Requests a SigV4 presigned upload URL from the FastAPI backend.
  ///
  /// Important:
  /// - `purpose` must be `'private'` for confidential assets (resumes, audition reels).
  /// - `purpose` must be `'public'` for public assets (logos, feed posts, portfolio).
  /// - Payload strictly adheres to `MediaUploadUrlRequest` (`extra="forbid"`).
  Future<MediaUploadResult> getPresignedUploadUrl({
    required String fileName,
    required String contentType,
    String purpose = 'private',
    int? fileSizeBytes,
  }) async {
    final body = <String, dynamic>{
      'file_name': fileName,
      'content_type': contentType,
      if (fileSizeBytes != null) 'file_size_bytes': fileSizeBytes,
      'purpose': purpose,
    };

    final response = await _apiClient.post(
      ApiEndpoints.mediaUploadUrl,
      body: body,
    );

    if (response is Map<String, dynamic>) {
      return MediaUploadResult.fromJson(response);
    }
    throw ApiException(
      statusCode: 500,
      message: 'Unexpected response format from media upload-url endpoint',
      details: response,
    );
  }

  /// Streams byte chunks directly to MinIO/S3 using the presigned PUT URL with exact Content-Length.
  ///
  /// Memory & Framing Guarantees:
  /// - Sets explicit `request.contentLength = length` so `StreamedRequest` uses standard
  ///   Content-Length framing rather than chunked transfer encoding.
  /// - Sets the exact signed Content-Type.
  /// - Omits any Authorization or Bearer token header to ensure SigV4 query authentication succeeds.
  /// - Reads directly from the source stream without buffering the entire payload into RAM.
  Future<void> uploadStreamToStorage({
    required String uploadUrl,
    required Stream<List<int>> stream,
    required int length,
    required String contentType,
  }) async {
    final cleanClient = http.Client();
    try {
      final uri = Uri.parse(uploadUrl);
      final request = http.StreamedRequest('PUT', uri);
      request.contentLength = length;
      request.headers['Content-Type'] = contentType;

      // Pipe the stream to the request sink and initiate send concurrently
      final pipeFuture = stream.pipe(request.sink);
      final sendFuture = cleanClient.send(request);

      // Wait for both upload transmission and server response receipt
      final results = await Future.wait([
        sendFuture,
        pipeFuture,
      ]);

      final streamedResponse = results[0] as http.StreamedResponse;
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'MinIO storage streaming direct upload failed: '
              '${response.body.isNotEmpty ? response.body : response.reasonPhrase}',
        );
      }
    } finally {
      cleanClient.close();
    }
  }

  /// Full orchestration helper for streaming uploads:
  /// 1. Requests presigned upload URL with declared file length.
  /// 2. Streams chunks directly from [stream] to MinIO without loading the entire file into memory.
  /// 3. Returns the resulting [MediaUploadResult].
  Future<MediaUploadResult> uploadStream({
    required Stream<List<int>> stream,
    required int length,
    required String fileName,
    required String contentType,
    String purpose = 'private',
  }) async {
    final presigned = await getPresignedUploadUrl(
      fileName: fileName,
      contentType: contentType,
      purpose: purpose,
      fileSizeBytes: length,
    );

    await uploadStreamToStorage(
      uploadUrl: presigned.uploadUrl,
      stream: stream,
      length: length,
      contentType: contentType,
    );

    return presigned;
  }

  /// Orchestration helper to stream an [XFile] directly to storage without memory buffering.
  Future<MediaUploadResult> uploadXFile({
    required XFile file,
    required String contentType,
    String purpose = 'private',
  }) async {
    final length = await file.length();
    return await uploadStream(
      stream: file.openRead(),
      length: length,
      fileName: file.name,
      contentType: contentType,
      purpose: purpose,
    );
  }

  /// Orchestration helper to stream a resume/document directly to private MinIO storage.
  /// Enforces 'application/pdf' content type and 'private' purpose.
  Future<MediaUploadResult> uploadResumeStream({
    required Stream<List<int>> stream,
    required int length,
    required String fileName,
  }) async {
    return await uploadStream(
      stream: stream,
      length: length,
      fileName: fileName,
      contentType: 'application/pdf',
      purpose: 'private',
    );
  }

  /// Orchestration helper to stream a [PlatformFile] directly to storage without memory buffering.
  /// Prefers [file.readStream], falls back to [XFile.openRead] or bytes if available.
  Future<MediaUploadResult> uploadPlatformFile({
    required PlatformFile file,
    String contentType = 'application/pdf',
    String purpose = 'private',
  }) async {
    Stream<List<int>> stream;
    if (file.readStream != null) {
      stream = file.readStream!;
    } else if (file.path != null && file.path!.isNotEmpty) {
      stream = XFile(file.path!).openRead();
    } else if (file.bytes != null) {
      stream = Stream.value(file.bytes!);
    } else {
      throw ApiException(
        statusCode: 400,
        message: 'No readable data or stream available for the selected file.',
      );
    }

    return await uploadStream(
      stream: stream,
      length: file.size,
      fileName: file.name,
      contentType: contentType,
      purpose: purpose,
    );
  }

  /// Directly uploads raw bytes to MinIO/S3 using the presigned PUT URL.
  /// Retained for backward-compatibility with in-memory byte sources (e.g. image thumbnails).
  Future<void> uploadBinaryToStorage({
    required String uploadUrl,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final cleanClient = http.Client();
    try {
      final uri = Uri.parse(uploadUrl);
      final response = await cleanClient.put(
        uri,
        headers: {
          'Content-Type': contentType,
        },
        body: bytes,
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'MinIO storage direct upload failed: '
              '${response.body.isNotEmpty ? response.body : response.reasonPhrase}',
        );
      }
    } finally {
      cleanClient.close();
    }
  }

  /// Full orchestration helper for byte buffers:
  /// Retained for backward-compatibility with callers supplying Uint8List.
  Future<MediaUploadResult> uploadFile({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    String purpose = 'private',
  }) async {
    final presigned = await getPresignedUploadUrl(
      fileName: fileName,
      contentType: contentType,
      purpose: purpose,
      fileSizeBytes: bytes.length,
    );

    await uploadBinaryToStorage(
      uploadUrl: presigned.uploadUrl,
      bytes: bytes,
      contentType: contentType,
    );

    return presigned;
  }

  /// Utility to resolve common MIME types from file extensions.
  static String resolveMimeType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.avi')) return 'video/x-msvideo';
    if (lower.endsWith('.mkv')) return 'video/x-matroska';
    if (lower.endsWith('.webm')) return 'video/webm';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'application/octet-stream';
  }
}

/// Riverpod provider for [MediaUploadService].
final mediaUploadServiceProvider = Provider<MediaUploadService>((ref) {
  return MediaUploadService();
});
