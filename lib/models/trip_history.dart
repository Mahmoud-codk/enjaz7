class TripHistory {
  final DateTime timestamp;
  final String route;
  final String from;
  final String to;

  TripHistory({
    required this.timestamp,
    required this.route,
    required this.from,
    required this.to,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'route': route,
      'from': from,
      'to': to,
    };
  }

  factory TripHistory.fromJson(Map<String, dynamic> json) {
    return TripHistory(
      timestamp: DateTime.parse(json['timestamp']),
      route: json['route'],
      from: json['from'],
      to: json['to'],
    );
  }
}
