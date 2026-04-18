// Conditional import based on platform
export 'cache_service_mobile.dart' if (dart.library.html) 'cache_service_web.dart';
