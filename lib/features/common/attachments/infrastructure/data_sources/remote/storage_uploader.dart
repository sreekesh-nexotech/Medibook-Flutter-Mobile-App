import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../../../../../../core/network/network_exceptions.dart';

/// Step 2 of `FLUTTER_API_INTEGRATION.md` §11.1: PUT the raw bytes to the
/// presigned `upload_url`.
///
/// This request goes to the **storage** server, not the API, so it must not
/// carry the bearer token or be joined onto the API base URL. That is why it
/// is a separate seam over its own plain HTTP client and not a method on
/// `ApiClient`.
abstract interface class StorageUploader {
  /// Send [bytes] to [uploadUrl] with [method] and **exactly** [headers].
  /// [onProgress] receives sent/total byte counts.
  ///
  /// Throws a `NetworkException` (mapped to `Failure` by the caller).
  Future<void> put({
    required String uploadUrl,
    required String method,
    required Map<String, String> headers,
    required Uint8List bytes,
    void Function(int sent, int total)? onProgress,
  });
}

/// [StorageUploader] over a dedicated [Dio] with no base URL, no
/// interceptors and no default headers beyond what the ticket lists.
class DioStorageUploader implements StorageUploader {
  DioStorageUploader({
    Duration timeout = const Duration(minutes: 2),
    bool allowBadCertificate = false,
    Dio? dio,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: timeout,
               sendTimeout: timeout,
               receiveTimeout: timeout,
               responseType: ResponseType.plain,
               validateStatus: (status) => status != null && status < 400,
             ),
           ) {
    if (allowBadCertificate) _trustAllCertificates();
  }

  final Dio _dio;

  @override
  Future<void> put({
    required String uploadUrl,
    required String method,
    required Map<String, String> headers,
    required Uint8List bytes,
    void Function(int sent, int total)? onProgress,
  }) async {
    try {
      await _dio.requestUri<void>(
        Uri.parse(uploadUrl),
        data: Stream<List<int>>.value(bytes),
        onSendProgress: onProgress,
        options: Options(
          method: method,
          // The ticket's headers, verbatim. Content-Type is set through the
          // header map only, so Dio does not substitute its own default.
          headers: {...headers, Headers.contentLengthHeader: bytes.length},
          contentType: headers['Content-Type'] ?? headers['content-type'],
        ),
      );
    } on DioException catch (error) {
      throw _map(error);
    }
  }

  NetworkException _map(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return RequestTimeoutException(message: error.message, cause: error);
      case DioExceptionType.cancel:
        return RequestCancelledException(message: error.message, cause: error);
      case DioExceptionType.badCertificate:
        return TlsException(message: error.message, cause: error);
      case DioExceptionType.connectionError:
        return NoConnectionException(message: error.message, cause: error);
      case DioExceptionType.badResponse:
        final status = error.response?.statusCode ?? 0;
        final body = error.response?.data;
        return HttpStatusException(
          statusCode: status,
          // Storage answers with XML/HTML, not the API envelope; surface it
          // as a provider fault so the user hears "storage is unavailable".
          code: status >= 500 ? ApiErrorCodes.providerUnavailable : null,
          body: body is String && body.length > 2000
              ? body.substring(0, 2000)
              : body?.toString(),
          message: 'storage PUT → $status',
          cause: error,
        );
      case DioExceptionType.unknown:
        final cause = error.error;
        if (cause is SocketException) {
          return NoConnectionException(message: cause.message, cause: cause);
        }
        if (cause is HandshakeException) {
          return TlsException(message: cause.message, cause: cause);
        }
        return NoConnectionException(message: error.message, cause: error);
    }
  }

  /// Dev/staging only, mirroring `DioApiClient`: the integration host serves
  /// a self-signed certificate, and its storage may too.
  void _trustAllCertificates() {
    final adapter = _dio.httpClientAdapter;
    if (adapter is IOHttpClientAdapter) {
      adapter.createHttpClient = () {
        final client = HttpClient();
        client.badCertificateCallback = (cert, host, port) => true;
        return client;
      };
    }
  }
}
