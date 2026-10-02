import 'dart:async';
import 'dart:math';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:protein_calculator/core/widgets/shaker.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// [Shaker] whose liquid stays level when the phone tilts and mixes when the
/// phone is shaken.
///
/// Built to cost as little as possible: a single accelerometer stream at
/// about 15 Hz, read only while the shaker is on screen and the app is in the
/// foreground; frames are drawn only while the liquid actually moves, and
/// only the drawing repaints. Disabled when the device asks to reduce
/// animations.
class MotionShaker extends StatefulWidget {
  const MotionShaker({
    super.key,
    required this.layers,
    required this.goal,
    required this.semanticLabel,
  });

  final List<ShakerLayer> layers;
  final double goal;
  final String semanticLabel;

  @override
  State<MotionShaker> createState() => _MotionShakerState();
}

class _MotionShakerState extends State<MotionShaker>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _motion = ShakerMotion();
  late final Ticker _ticker = createTicker(_onTick);
  StreamSubscription<AccelerometerEvent>? _sensor;
  bool _visible = true;
  bool _reduceMotion = false;
  bool _foreground = true;
  bool _landscape = false;

  // Gravity estimated with a low-pass filter, in m/s².
  double _gx = 0, _gy = 9.81, _gz = 0;
  double _targetTilt = 0;

  // Shake detection: several separate jolts close together.
  final _jolts = <DateTime>[];
  Duration? _lastShake;
  Duration _now = Duration.zero;
  Duration? _lastTick;

  static const _sampling = SensorInterval.uiInterval;

  /// Acceleration of a jolt, gravity removed, in m/s².
  static const _joltThreshold = 12.0;

  /// Jolts needed, within [_shakeWindow], to count as shaking.
  static const _joltsPerShake = 3;
  static const _shakeWindow = Duration(milliseconds: 800);

  /// Shortest time between two counted jolts: the samples of one movement
  /// and of its rebound count once.
  static const _minJoltGap = Duration(milliseconds: 250);
  static const _maxTilt = 0.6;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // TickerMode turns off when the tab is hidden behind another one.
    _visible = TickerMode.valuesOf(context).enabled;
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _landscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    _updateListening();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _updateListening();
  }

  void _updateListening() {
    final listen = _visible && _foreground && !_reduceMotion;
    if (listen && _sensor == null) {
      _sensor = accelerometerEventStream(samplingPeriod: _sampling).listen(
        _onSensor,
        // No accelerometer (most browsers): the shaker simply stays still.
        onError: (Object _) => _stopListening(),
        cancelOnError: true,
      );
    } else if (!listen) {
      _stopListening();
      if (_reduceMotion || !_visible) _settle();
    }
  }

  void _stopListening() {
    _sensor?.cancel();
    _sensor = null;
  }

  /// Puts the liquid back at rest at once, without animating.
  void _settle() {
    _ticker.stop();
    _lastTick = null;
    _targetTilt = 0;
    _lastShake = null;
    _motion.update(tilt: 0, mix: 0, phase: _motion.phase);
  }

  void _onSensor(AccelerometerEvent event) {
    _gx = _gx * 0.85 + event.x * 0.15;
    _gy = _gy * 0.85 + event.y * 0.15;
    _gz = _gz * 0.85 + event.z * 0.15;
    final jolt = sqrt(
      pow(event.x - _gx, 2) + pow(event.y - _gy, 2) + pow(event.z - _gz, 2),
    );
    _countJolt(jolt, event.timestamp);

    // The surface stays level: when the phone rolls one way, the liquid
    // rises on the lower side of the screen.
    // Sensor axes follow the phone, not the screen: in landscape, the
    // screen is turned a quarter, one way or the other.
    var angle = atan2(-_gx, _gy);
    if (_landscape) {
      angle += _gx > 0 ? pi / 2 : -pi / 2;
      if (angle > pi) angle -= 2 * pi;
      if (angle < -pi) angle += 2 * pi;
    }
    _targetTilt = angle.clamp(-_maxTilt, _maxTilt);

    // Ignores hand tremor: about one degree.
    final moving = (_targetTilt - _motion.tilt).abs() > 0.02;
    if ((moving || _lastShake != null || _motion.mix > 0) &&
        !_ticker.isActive) {
      _lastTick = null;
      _ticker.start();
    }
  }

  /// Counts a jolt when the acceleration goes above the threshold, at most
  /// once every [_minJoltGap].
  void _countJolt(double jolt, DateTime at) {
    if (jolt < _joltThreshold) return;
    if (_jolts.isNotEmpty && at.difference(_jolts.last) < _minJoltGap) return;
    _jolts
      ..add(at)
      ..removeWhere((t) => at.difference(t) > _shakeWindow);
    if (_jolts.length >= _joltsPerShake) _lastShake = _now;
  }

  void _onTick(Duration elapsed) {
    final previous = _lastTick;
    _lastTick = elapsed;
    final dt = previous == null
        ? 1 / 60
        : (elapsed - previous).inMicroseconds / 1e6;
    _now += Duration(microseconds: (dt * 1e6).round());

    final tilt = _motion.tilt + (_targetTilt - _motion.tilt) * min(1.0, dt * 8);
    final shaking =
        _lastShake != null &&
        _now - _lastShake! < const Duration(milliseconds: 500);
    // Mixes quickly, then settles back into layers in about 1.5 s.
    final mix = shaking
        ? min(1.0, _motion.mix + dt * 4)
        : max(0.0, _motion.mix - dt * 0.7);
    final phase = _motion.phase + dt * 7 * max(mix, 0.2);
    _motion.update(tilt: tilt, mix: mix, phase: phase);

    if (!shaking) _lastShake = null;
    final atRest = (_targetTilt - tilt).abs() < 0.002 && mix == 0;
    if (atRest) {
      _ticker.stop();
      _lastTick = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopListening();
    _ticker.dispose();
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Shaker(
    layers: widget.layers,
    goal: widget.goal,
    semanticLabel: widget.semanticLabel,
    motion: _motion,
  );
}
