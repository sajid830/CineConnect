import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'error_retry_view.dart';
import 'skeleton_list.dart';

class AsyncBody<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback onRetry;
  final String errorMessage;
  final Widget? loading;

  const AsyncBody({
    super.key,
    required this.value,
    required this.data,
    required this.onRetry,
    this.errorMessage = 'Something went wrong',
    this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => loading ?? const SkeletonList(),
      error: (error, _) =>
          ErrorRetryView(message: errorMessage, onRetry: onRetry),
      data: data,
    );
  }
}