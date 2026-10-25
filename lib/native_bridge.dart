import 'package:flutter/services.dart';

class PickedFile {
  PickedFile(this.name, this.text);
  final String name;
  final String text;
}

/// Talks to MainActivity.kt: shared links from other apps, the system file
/// picker, and opening Google Maps.
class NativeBridge {
  static const _channel = MethodChannel('pin_roulette/native');
  static void Function(String text)? onShare;

  static void init() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onShare' && call.arguments is String) {
        onShare?.call(call.arguments as String);
      }
      return null;
    });
  }

  static Future<String?> initialShare() async {
    try {
      return await _channel.invokeMethod<String>('getInitialShare');
    } catch (_) {
      return null;
    }
  }

  static Future<List<PickedFile>> pickFiles() async {
    try {
      final res = await _channel.invokeMethod<List<dynamic>>('pickFiles');
      return (res ?? const [])
          .whereType<Map>()
          .map((m) => PickedFile('${m['name'] ?? 'file'}', '${m['text'] ?? ''}'))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<bool> openUrl(String url) async {
    try {
      return await _channel.invokeMethod<bool>('openUrl', {'url': url}) ?? false;
    } catch (_) {
      return false;
    }
  }
}
