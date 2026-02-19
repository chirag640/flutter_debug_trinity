import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;

import '../../core/causal_event.dart';
import '../../core/context_zone.dart';
import '../../core/trinity_event_bus.dart';

/// A Dio [Interceptor] that records all HTTP requests, responses, and errors
/// as causal events in the [TrinityEventBus].
///
/// ## Usage
/// ```dart
/// final dio = Dio();
/// dio.interceptors.add(CausalityDioInterceptor());
/// ```
///
/// All recording is assert-guarded — zero overhead in release builds.
class CausalityDioInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    assert(() {
      final context = CausalityZone.currentContext();
      final event = CausalEvent(
        parentId: context?.eventId,
        type: CausalEventType.networkEvent,
        description: 'HTTP ${options.method} ${options.uri.path}',
        metadata: {
          'method': options.method,
          'url': options.uri.toString(),
          'path': options.uri.path,
          'phase': 'request',
          'has_body': options.data != null,
          'content_type': options.contentType ?? 'unknown',
        },
      );
      TrinityEventBus.instance.emit(event);
      // Store the event ID in options.extra so we can link the response
      options.extra['_trinity_event_id'] = event.id;
      return true;
    }());
    handler.next(options);
  }

  @override
  void onResponse(
      Response<dynamic> response, ResponseInterceptorHandler handler) {
    assert(() {
      final parentId =
          response.requestOptions.extra['_trinity_event_id'] as String?;
      TrinityEventBus.instance.emit(CausalEvent(
        parentId: parentId,
        type: CausalEventType.networkEvent,
        description:
            'HTTP ${response.statusCode} ${response.requestOptions.method} '
            '${response.requestOptions.uri.path}',
        metadata: {
          'method': response.requestOptions.method,
          'url': response.requestOptions.uri.toString(),
          'path': response.requestOptions.uri.path,
          'phase': 'response',
          'status_code': response.statusCode ?? 0,
          'content_length':
              response.headers.value('content-length') ?? 'unknown',
        },
      ));
      return true;
    }());
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    assert(() {
      final parentId = err.requestOptions.extra['_trinity_event_id'] as String?;
      TrinityEventBus.instance.emit(CausalEvent(
        parentId: parentId,
        type: CausalEventType.networkEvent,
        description: 'HTTP ERROR ${err.requestOptions.method} '
            '${err.requestOptions.uri.path}',
        metadata: {
          'method': err.requestOptions.method,
          'url': err.requestOptions.uri.toString(),
          'path': err.requestOptions.uri.path,
          'phase': 'error',
          'error_type': err.type.name,
          'error_message': err.message ?? 'unknown',
          'status_code': err.response?.statusCode ?? 0,
        },
      ));
      return true;
    }());
    handler.next(err);
  }
}

/// An [http.BaseClient] wrapper that records all HTTP requests as causal events.
///
/// ## Usage
/// ```dart
/// final client = CausalityHttpClient(http.Client());
/// final response = await client.get(Uri.parse('https://api.example.com/data'));
/// ```
///
/// All recording is assert-guarded — zero overhead in release builds.
class CausalityHttpClient extends http.BaseClient {
  /// The inner HTTP client to delegate requests to.
  final http.Client _inner;

  CausalityHttpClient(this._inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    String? requestEventId;

    assert(() {
      final context = CausalityZone.currentContext();
      final event = CausalEvent(
        parentId: context?.eventId,
        type: CausalEventType.networkEvent,
        description: 'HTTP ${request.method} ${request.url.path}',
        metadata: {
          'method': request.method,
          'url': request.url.toString(),
          'path': request.url.path,
          'phase': 'request',
          'content_length': request.contentLength ?? 0,
        },
      );
      TrinityEventBus.instance.emit(event);
      requestEventId = event.id;
      return true;
    }());

    try {
      final response = await _inner.send(request);

      assert(() {
        TrinityEventBus.instance.emit(CausalEvent(
          parentId: requestEventId,
          type: CausalEventType.networkEvent,
          description:
              'HTTP ${response.statusCode} ${request.method} ${request.url.path}',
          metadata: {
            'method': request.method,
            'url': request.url.toString(),
            'path': request.url.path,
            'phase': 'response',
            'status_code': response.statusCode,
            'content_length': response.contentLength ?? 0,
          },
        ));
        return true;
      }());

      return response;
    } catch (error) {
      assert(() {
        TrinityEventBus.instance.emit(CausalEvent(
          parentId: requestEventId,
          type: CausalEventType.networkEvent,
          description: 'HTTP ERROR ${request.method} ${request.url.path}',
          metadata: {
            'method': request.method,
            'url': request.url.toString(),
            'path': request.url.path,
            'phase': 'error',
            'error_type': error.runtimeType.toString(),
            'error_message': error.toString(),
          },
        ));
        return true;
      }());
      rethrow;
    }
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
