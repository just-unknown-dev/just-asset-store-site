import 'package:just_signals/just_signals.dart';

/// The router's location as a signal.
final class RouteState {
  final Signal<String> location = Signal<String>('/', debugLabel: 'location');
}
