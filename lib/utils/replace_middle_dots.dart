String replaceMiddleDots(String stops) {
  final normalized = stops
      .replaceAll(RegExp(r'[·•،؛;|/\\—–-]'), ' . ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return normalized;
}
