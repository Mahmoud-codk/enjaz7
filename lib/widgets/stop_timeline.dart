import 'package:flutter/material.dart';
import 'package:timeline_tile/timeline_tile.dart';

class StopTimeline extends StatelessWidget {
  final List<String> stops;
  final Function(String)? onStopTap;

  const StopTimeline({super.key, required this.stops, this.onStopTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(stops.length, (index) {
        final stop = stops[index].trim();
        if (stop.isEmpty) return const SizedBox.shrink();

        return TimelineTile(
          alignment: TimelineAlign.manual,
          lineXY: 0.1,
          isFirst: index == 0,
          isLast: index == stops.length - 1,
          indicatorStyle: IndicatorStyle(
            width: 24,
            color: _getIndicatorColor(context, index, stops.length),
            padding: const EdgeInsets.all(4),
            iconStyle: IconStyle(
              color: Colors.white,
              iconData: _getIndicatorIcon(index, stops.length),
              fontSize: 16,
            ),
          ),
          beforeLineStyle: LineStyle(
            color: Theme.of(context).primaryColor.withOpacity(0.7),
            thickness: 2,
          ),
          afterLineStyle: LineStyle(
            color: Theme.of(context).primaryColor.withOpacity(0.7),
            thickness: 2,
          ),
          endChild: InkWell(
            onTap: onStopTap != null ? () => onStopTap!(stop) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      stop,
                      style: TextStyle(
                        fontWeight: _getTextWeight(index, stops.length),
                        fontSize: 16,
                        color: _getTextColor(context, index, stops.length),
                      ),
                    ),
                  ),
                  if (index == 0)
                    const Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child: Text(
                        'بداية',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (index == stops.length - 1)
                    const Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child: Text(
                        'نهاية',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Color _getIndicatorColor(BuildContext context, int index, int length) {
    if (index == 0) return Colors.green;
    if (index == length - 1) return Colors.red;
    return Theme.of(context).primaryColor;
  }

  IconData _getIndicatorIcon(int index, int length) {
    if (index == 0) return Icons.play_arrow;
    if (index == length - 1) return Icons.flag;
    return Icons.radio_button_checked;
  }

  FontWeight _getTextWeight(int index, int length) {
    if (index == 0 || index == length - 1) return FontWeight.bold;
    return FontWeight.normal;
  }

  Color _getTextColor(BuildContext context, int index, int length) {
    if (index == 0) return Colors.green;
    if (index == length - 1) return Colors.red;
    return Colors.black87;
  }
}
