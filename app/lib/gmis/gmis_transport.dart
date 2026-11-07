import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'gmis_exception.dart';

/// 一次 GMIS 请求。Transport 负责网络，Client 负责 Cookie、跳转和业务解析。
class GmisRequest {
  const GmisRequest({
    required this.method,
    required this.path,
    this.query,
    this.form,
    this.headers = const {},
    this.asBytes = false,
    this.followRedirects = false,
  });

  final String method;
  final String path;
  final Map<String, String>? query;
  final Map<String, String>? form;
  final Map<String, String> headers;
  final bool asBytes;
  final bool followRedirects;
}

class GmisResponse {
  const GmisResponse({
    required this.statusCode,
    required this.headers,
    required this.body,
    this.bytes,
  });

  final int statusCode;
  final Map<String, List<String>> headers;
  final String body;
  final Uint8List? bytes;

  String? header(String name) {
    final values = headers[name.toLowerCase()];
    return values == null || values.isEmpty ? null : values.first;
  }
}

abstract interface class GmisTransport {
  Future<GmisResponse> send(GmisRequest request);
}

/// Dio 实现。默认关闭自动重定向，让 Client 能识别 302 会话过期。
class DioGmisTransport implements GmisTransport {
  DioGmisTransport({Dio? dio, String baseUrl = AppConfig.baseUrl})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl.endsWith('/') ? baseUrl : '$baseUrl/',
              connectTimeout: AppConfig.connectTimeout,
              receiveTimeout: AppConfig.receiveTimeout,
              sendTimeout: AppConfig.receiveTimeout,
              followRedirects: false,
              validateStatus: (_) => true,
              responseType: ResponseType.plain,
              headers: {
                'User-Agent': AppConfig.userAgent,
                'Accept': 'application/json, text/javascript, */*; q=0.01',
                'X-Requested-With': 'XMLHttpRequest',
                'Referer':
                    '${baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl}/home/stulogin',
              },
            ),
          );

  final Dio _dio;

  @override
  Future<GmisResponse> send(GmisRequest request) async {
    try {
      final path = request.path.startsWith('/')
          ? request.path.substring(1)
          : request.path;
      final response = await _dio.request<dynamic>(
        path,
        data: request.form,
        queryParameters: request.query,
        options: Options(
          method: request.method,
          headers: {...request.headers},
          responseType: request.asBytes
              ? ResponseType.bytes
              : ResponseType.plain,
          contentType: request.form == null
              ? null
              : 'application/x-www-form-urlencoded',
          followRedirects: request.followRedirects,
          validateStatus: (_) => true,
        ),
      );
      final raw = response.data;
      final bytes = raw is Uint8List
          ? raw
          : raw is List<int>
          ? Uint8List.fromList(raw)
          : null;
      return GmisResponse(
        statusCode: response.statusCode ?? 0,
        headers: response.headers.map.map(
          (key, value) => MapEntry(key.toLowerCase(), value),
        ),
        body: raw is String ? raw : '',
        bytes: request.asBytes ? bytes : null,
      );
    } on DioException catch (error) {
      throw GmisNetworkException(_networkMessage(error));
    }
  }

  String _networkMessage(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '连接学校系统超时，请稍后重试';
      case DioExceptionType.connectionError:
        return '网络连接失败，请检查网络后重试';
      case DioExceptionType.badCertificate:
        return '学校系统证书校验失败';
      case DioExceptionType.cancel:
        return '请求已取消';
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
      case DioExceptionType.transformTimeout:
        return '无法连接学校系统，请稍后重试';
    }
  }
}
