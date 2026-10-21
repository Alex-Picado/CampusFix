/// Represents metadata for a locally stored incident photograph.
class IncidentEvidence {
  /// Provider identifier stored for local files.
  static const String localProvider = 'local';

  /// Maximum permitted file size, expressed in decimal bytes.
  static const int maxFileSizeBytes = 3000000;

  /// Canonical image content types supported by incident evidence.
  static const Set<String> supportedContentTypes = {
    'image/jpeg',
    'image/png',
    'image/webp',
  };

  /// Identifier of the evidence document within its incident.
  final String id;

  /// Identifier of the account that uploaded the file.
  final String uploadedByUserId;

  /// Confirmed time when the evidence metadata was recorded.
  final DateTime createdAt;

  /// Local storage provider associated with this file reference.
  String get provider => localProvider;

  /// Identifier of the stored file within the provider.
  final String assetId;

  /// Reference used to retrieve the stored file.
  final String url;

  /// Original file name displayed to the user.
  final String fileName;

  /// Canonical MIME type of the image.
  final String contentType;

  /// Size of the image in bytes.
  final int sizeBytes;

  /// Related progress entry, or null for a report photograph.
  final String? progressId;

  /// Creates evidence metadata without storing image bytes in the model.
  const IncidentEvidence({
    required this.id,
    required this.uploadedByUserId,
    required this.createdAt,
    required this.assetId,
    required this.url,
    required this.fileName,
    required this.contentType,
    required this.sizeBytes,
    this.progressId,
  });

  /// Returns the evidence fields without duplicating the document ID.
  ///
  /// Includes the local provider and null [progressId] for report photographs.
  /// Dates remain [DateTime] values; image bytes are not serialized.
  Map<String, dynamic> toMap() {
    return {
      'uploadedByUserId': uploadedByUserId,
      'createdAt': createdAt,
      'provider': provider,
      'assetId': assetId,
      'url': url,
      'fileName': fileName,
      'contentType': contentType,
      'sizeBytes': sizeBytes,
      'progressId': progressId,
    };
  }

  /// Parses local evidence metadata after timestamp normalization.
  ///
  /// Requires a supported content type and a positive integer file size no
  /// greater than [maxFileSizeBytes]. Missing [progressId] becomes null.
  /// Throws a [FormatException] for invalid metadata or a nonlocal provider.
  /// File contents, path authorization and upload permissions are not verified
  /// by this metadata conversion.
  factory IncidentEvidence.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final uploadedByUserId = data['uploadedByUserId'];
    final createdAt = data['createdAt'];
    final provider = data['provider'];
    final assetId = data['assetId'];
    final url = data['url'];
    final fileName = data['fileName'];
    final contentType = data['contentType'];
    final sizeBytes = data['sizeBytes'];
    final progressId = data['progressId'];

    if (id.trim().isEmpty ||
        uploadedByUserId is! String ||
        uploadedByUserId.trim().isEmpty ||
        createdAt is! DateTime ||
        provider is! String ||
        provider != localProvider ||
        assetId is! String ||
        assetId.trim().isEmpty ||
        url is! String ||
        url.trim().isEmpty ||
        fileName is! String ||
        fileName.trim().isEmpty ||
        contentType is! String ||
        !supportedContentTypes.contains(contentType) ||
        sizeBytes is! int ||
        sizeBytes <= 0 ||
        sizeBytes > maxFileSizeBytes ||
        (progressId != null &&
            (progressId is! String || progressId.trim().isEmpty))) {
      throw const FormatException('Invalid incident evidence data.');
    }

    return IncidentEvidence(
      id: id,
      uploadedByUserId: uploadedByUserId,
      createdAt: createdAt,
      assetId: assetId,
      url: url,
      fileName: fileName,
      contentType: contentType,
      sizeBytes: sizeBytes,
      progressId: progressId,
    );
  }
}
