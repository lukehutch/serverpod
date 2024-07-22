import 'dart:io';
import 'dart:typed_data';

import 'package:gcloud/storage.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:serverpod/serverpod.dart';

const _googleClientSecretPath = 'config/google_client_secret.json';

/// Concrete implementation of Google Cloud Storage, using native GCP APIs,
/// for use with Serverpod.
class GoogleCloudStorageNative extends CloudStorage {
  final String project;
  final String bucket;
  late final String publicHost;

  Storage? _storage;

  Future<Storage> get storage async {
    if (_storage == null) {
      // Read the service account credentials from the file.
      var jsonCredentials =
          await new File(_googleClientSecretPath).readAsString();
      var credentials =
          new auth.ServiceAccountCredentials.fromJson(jsonCredentials);
      var client =
          await auth.clientViaServiceAccount(credentials, Storage.SCOPES);
      _storage = new Storage(client, project);
    }
    return _storage!;
  }

  /// Creates a new [GoogleCloudStorageNative] object.
  GoogleCloudStorageNative({
    required Serverpod serverpod,
    required String storageId,
    required this.project,
    required this.bucket,
    String? publicHost,
  }) : super(storageId) {
    this.publicHost = publicHost ?? 'storage.googleapis.com/$bucket';
  }

  @override
  Future<void> storeFile({
    required Session session,
    required String path,
    required ByteData byteData,
    DateTime? expiration,
    bool verified = true,
  }) async {
    await (await storage)
        .bucket(bucket)
        .writeBytes(path, byteData.buffer.asUint8List());
  }

  @override
  Future<ByteData?> retrieveFile({
    required Session session,
    required String path,
  }) async {
    var byteLists = await (await storage).bucket(bucket).read(path).toList();
    var totLength =
        byteLists.fold<int>(0, (prev, element) => prev + element.length);
    var bytes = Uint8List(totLength);
    var offset = 0;
    for (var byteList in byteLists) {
      bytes.setRange(offset, offset + byteList.length, byteList);
      offset += byteList.length;
    }
    return ByteData.view(bytes.buffer);
  }

  @override
  Future<Uri?> getPublicUrl({
    required Session session,
    required String path,
  }) async {
    if (await fileExists(session: session, path: path)) {
      return Uri.parse('https://$publicHost/$path');
    }
    return null;
  }

  @override
  Future<bool> fileExists({
    required Session session,
    required String path,
  }) async {
    try {
      await (await storage).bucket(bucket).info(path);
      return true;
    } catch (e) {
      print('Failed to check if file exists: $e'); // TODO
      return false;
    }
  }

  @override
  Future<void> deleteFile({
    required Session session,
    required String path,
  }) async {
    await (await storage).bucket(bucket).delete(path);
  }

  @override
  Future<String?> createDirectFileUploadDescription({
    required Session session,
    required String path,
    Duration expirationDuration = const Duration(minutes: 10),
  }) async {
    return null;

    // TODO V4 signing
    // https://cloud.google.com/storage/docs/access-control/signing-urls-manually
  }

  @override
  Future<bool> verifyDirectFileUpload({
    required Session session,
    required String path,
  }) async {
    return fileExists(session: session, path: path);
  }
}
