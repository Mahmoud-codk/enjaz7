/// Utility for web-specific functionality with conditional imports.
library;

export 'web_utils_stub.dart'
    if (dart.library.html) 'web_utils_web.dart';
