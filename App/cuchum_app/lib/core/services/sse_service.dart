import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import 'api_models.dart';

/// Singleton SSE service for receiving real-time notifications.
///
/// Usage:
///   SSEService.start(accessToken);   // on login / MainShell mount
///   SSEService.stream.listen(...);   // in widgets
///   SSEService.stop();               // on logout / dispose
class SSEService {
  SSEService._();

  static final _controller = StreamController<NotificationData>.broadcast();

  /// Broadcast stream of incoming real-time notifications
  static Stream<NotificationData> get stream => _controller.stream;

  static bool _running = false;
  static bool _stopped = false;
  static http.Client? _client;

  /// Start the SSE connection loop. Safe to call multiple times (idempotent).
  static void start(String accessToken) {
    if (_running) return;
    _running = true;
    _stopped = false;
    _loop(accessToken);
  }

  /// Stop and clean up the SSE connection.
  static void stop() {
    _stopped = true;
    _running = false;
    _client?.close();
    _client = null;
  }

  static Future<void> _loop(String token) async {
    while (!_stopped) {
      try {
        _client = http.Client();
        final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.notificationsStream}');
        final request = http.Request('GET', uri)
          ..headers['Authorization'] = 'Bearer $token'
          ..headers['Accept'] = 'text/event-stream'
          ..headers['Cache-Control'] = 'no-cache';

        final response = await _client!.send(request);

        // Buffer for partial lines
        String buffer = '';

        await for (final chunk in response.stream.transform(utf8.decoder)) {
          if (_stopped) break;
          buffer += chunk;

          // Process complete lines
          final lines = buffer.split('\n');
          buffer = lines.last; // keep the incomplete last piece

          for (final line in lines.take(lines.length - 1)) {
            if (line.startsWith('data: ')) {
              _parseAndEmit(line.substring(6).trim());
            }
            // Lines starting with ':' are comments/heartbeats — ignore
          }
        }
      } catch (e) {
        debugPrint('SSEService error: $e');
      } finally {
        _client?.close();
        _client = null;
      }

      if (!_stopped) {
        // Reconnect after delay
        await Future.delayed(const Duration(seconds: 5));
      }
    }
    _running = false;
  }

  static void _parseAndEmit(String data) {
    if (data.isEmpty || data == '{\"type\":\"connected\"}') return;
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      if (json['type'] == 'connected') return; // skip connection ack
      _controller.add(NotificationData.fromJson(json));
    } catch (e) {
      debugPrint('SSEService.parse error: $e — data=$data');
    }
  }
}
