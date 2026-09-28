import 'package:flutter/foundation.dart';

/// Wraps network image URLs using images.weserv.nl proxy when running on Web 
/// to bypass CORS limitations on CanvasKit.
String getCorsFriendlyUrl(String url) {
  if (kIsWeb && url.startsWith('http') && !url.contains('localhost') && !url.contains('127.0.0.1')) {
    return 'https://images.weserv.nl/?url=${Uri.encodeComponent(url)}';
  }
  return url;
}
