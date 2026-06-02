// Data layer — raw HTTP client. Only this class knows about Dio.
import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';

class OpenAlexApiClient {
  late final Dio _dio;

  OpenAlexApiClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(milliseconds: ApiConstants.connectTimeoutMs),
        receiveTimeout: const Duration(milliseconds: ApiConstants.receiveTimeoutMs),
        headers: {
          'Accept': 'application/json',
          // Polite pool: OpenAlex asks clients to identify themselves.
          'User-Agent': 'JournalTrendAnalyzer/1.0 (mailto:beu2901@gmail.com)',
        },
      ),
    );

    _dio.interceptors.add(LogInterceptor(
      request: false,
      requestBody: false,
      responseBody: false,
      error: true,
    ));

    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException error, ErrorInterceptorHandler handler) {
          handler.next(error);
        },
      ),
    );
  }

  Dio get dio => _dio;
}
