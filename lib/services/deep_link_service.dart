import 'dart:async';
import 'package:app_links/app_links.dart';
import 'supabase_service.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  void init() {
    _appLinks = AppLinks();
    
    // Handle link when app is in cold state (killed)
    _appLinks.getInitialLink().then((Uri? uri) {
      if (uri != null) {
        _handleLink(uri);
      }
    });

    // Handle link when app is in warm state (running in background)
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleLink(uri);
    }, onError: (err) {
      print('Error listening to deep links: $err');
    });
  }

  void _handleLink(Uri uri) {
    if (uri.scheme == 'workoutpro' || uri.scheme == 'https') {
      final code = uri.queryParameters['id'] ?? uri.queryParameters['routine'] ?? uri.queryParameters['code'];
      if (code != null && code.isNotEmpty) {
        SupabaseService.pendingShareCode = code;
        // The UI will handle it when it renders, or we can broadcast an event.
      }
    }
  }

  void dispose() {
    _linkSubscription?.cancel();
  }
}
