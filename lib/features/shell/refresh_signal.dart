import 'package:flutter/material.dart';

/// Broadcasts "something changed, reload" to every tab in a shell.
///
/// Tabs live in an [IndexedStack] and stay alive while hidden, so a job
/// posted from the Home tab has to reach the Activity tab too. Each tab
/// compares [version] against the last one it handled in
/// `didChangeDependencies` and refetches when they differ.
class RefreshSignal extends ChangeNotifier {
  int _version = 0;

  int get version => _version;

  void bump() {
    _version++;
    notifyListeners();
  }
}

class RefreshScope extends InheritedNotifier<RefreshSignal> {
  const RefreshScope({
    super.key,
    required RefreshSignal signal,
    required super.child,
  }) : super(notifier: signal);

  static RefreshSignal of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<RefreshScope>();
    assert(scope != null, 'No RefreshScope found in context');
    return scope!.notifier!;
  }
}

/// Mixin for a tab screen that reloads whenever the shell's
/// [RefreshSignal] fires. Implement [onRefreshSignal] with the reload.
mixin RefreshAware<T extends StatefulWidget> on State<T> {
  int _handledVersion = 0;

  void onRefreshSignal();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final version = RefreshScope.of(context).version;
    if (version != _handledVersion) {
      _handledVersion = version;
      onRefreshSignal();
    }
  }
}
