import 'package:fl_clash/v2board/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CurrencyText extends ConsumerWidget {
  final int amountInCents;
  final TextStyle? style;

  const CurrencyText({
    super.key,
    required this.amountInCents,
    this.style,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commConfig = ref.watch(userProvider).commConfig;
    final symbol = commConfig?.currencySymbol ?? '';
    final value = (amountInCents / 100).toStringAsFixed(2);
    return Text(
      '$symbol$value',
      style: style,
    );
  }
}
