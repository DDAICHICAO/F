import 'package:flutter/material.dart';

class TrafficProgress extends StatelessWidget {
  final double usedGB;
  final double totalGB;
  final int? expireDays;

  const TrafficProgress({
    super.key,
    required this.usedGB,
    required this.totalGB,
    this.expireDays,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = totalGB > 0 ? (usedGB / totalGB).clamp(0.0, 1.0) : 0.0;
    final percentDisplay = (percent * 100).toStringAsFixed(1);

    Color barColor;
    if (percent > 0.9) {
      barColor = theme.colorScheme.error;
    } else if (percent > 0.7) {
      barColor = Colors.orange;
    } else {
      barColor = theme.colorScheme.primary;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '已用 $usedGBAsString GB / 共 ${totalGB.toStringAsFixed(1)} GB',
              style: theme.textTheme.bodySmall,
            ),
            Text(
              '$percentDisplay%',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: barColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percent,
            minHeight: 8,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(barColor),
          ),
        ),
        if (expireDays != null) ...[
          const SizedBox(height: 4),
          Text(
            expireDays! > 0 ? '距到期还有 $expireDays 天' : '已到期',
            style: theme.textTheme.bodySmall?.copyWith(
              color: expireDays! > 0
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }

  String get usedGBAsString => usedGB.toStringAsFixed(1);
}
