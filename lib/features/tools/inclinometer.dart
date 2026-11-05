import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../app/providers.dart';
import '../../domain/exercise.dart';

/// Settings key for the calibration offset, in degrees.
const _offsetKey = 'inclinometer_offset';

/// Incline of a phone lying screen up with its top towards the head of the
/// bench, from the gravity vector: 0° flat, positive when the head end is
/// higher, negative for a decline.
double inclineDegrees(double y, double z) =>
    math.atan2(y, z.abs()) * 180 / math.pi;

/// Typical positions of adjustable benches, to name the closest one.
const benchPositions = [-15, 0, 15, 30, 45, 60, 75, 90];

int closestBenchPosition(double degrees) => benchPositions.reduce(
  (a, b) => (a - degrees).abs() <= (b - degrees).abs() ? a : b,
);

/// Full-screen inclinometer. With [forExercise] it offers to save the angle
/// and returns it (`context.pop<int>`).
class InclinometerScreen extends StatelessWidget {
  const InclinometerScreen({super.key, this.forExercise});
  final String? forExercise;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Inclinação do banco')),
    body: InclinometerView(
      saveLabel: forExercise == null ? null : 'Guardar em $forExercise',
      onSave: forExercise == null
          ? null
          : (degrees) => Navigator.pop(context, degrees),
    ),
  );
}

class InclinometerView extends ConsumerStatefulWidget {
  const InclinometerView({super.key, this.onSave, this.saveLabel});

  final ValueChanged<int>? onSave;
  final String? saveLabel;

  @override
  ConsumerState<InclinometerView> createState() => _InclinometerViewState();
}

class _InclinometerViewState extends ConsumerState<InclinometerView> {
  StreamSubscription<AccelerometerEvent>? _sub;
  double? _raw; // smoothed, before calibration
  double _offset = 0;
  bool _held = false;
  bool _unavailable = false;
  final _recent = <double>[];

  @override
  void initState() {
    super.initState();
    _loadOffset();
    _sub = accelerometerEventStream(samplingPeriod: SensorInterval.uiInterval)
        .listen(
          _onEvent,
          onError: (_) => setState(() => _unavailable = true),
          cancelOnError: true,
        );
  }

  Future<void> _loadOffset() async {
    final raw = await ref.read(settingsRepositoryProvider).read(_offsetKey);
    final v = raw == null ? null : double.tryParse(raw);
    if (v != null && mounted) setState(() => _offset = v);
  }

  void _onEvent(AccelerometerEvent e) {
    if (_held || !mounted) return;
    final angle = inclineDegrees(e.y, e.z);
    // Exponential smoothing: steady reading without lagging much.
    final next = _raw == null ? angle : _raw! + 0.15 * (angle - _raw!);
    _recent.add(next);
    if (_recent.length > 20) _recent.removeAt(0);
    setState(() => _raw = next);
  }

  bool get _stable {
    if (_recent.length < 10) return false;
    final lo = _recent.reduce(math.min);
    final hi = _recent.reduce(math.max);
    return hi - lo < 0.6;
  }

  double? get _angle => _raw == null ? null : _raw! - _offset;

  Future<void> _calibrate() async {
    final raw = _raw;
    if (raw == null) return;
    setState(() => _offset = raw);
    await ref
        .read(settingsRepositoryProvider)
        .write(_offsetKey, raw.toStringAsFixed(2));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Calibrado: esta superfície é o 0°.')),
      );
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    if (_unavailable) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Este dispositivo não tem acelerómetro disponível.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final angle = _angle;
    final rounded = angle?.round();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text(
          'Pousa o telemóvel no encosto do banco, com o ecrã para cima e o '
          'topo virado para a cabeceira.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: c.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        AspectRatio(
          aspectRatio: 1.6,
          child: CustomPaint(
            painter: _BenchPainter(
              angle: angle ?? 0,
              line: c.primary,
              grid: c.outlineVariant,
              label: c.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            rounded == null ? '--°' : '$rounded°',
            style: theme.textTheme.displayLarge?.copyWith(
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        Center(
          child: Wrap(
            spacing: 8,
            children: [
              if (angle != null)
                Chip(
                  label: Text(
                    'Posição mais próxima: ${formatAngle(closestBenchPosition(angle))}',
                  ),
                ),
              Chip(
                avatar: Icon(
                  _held
                      ? Icons.lock_rounded
                      : _stable
                      ? Icons.check_circle_rounded
                      : Icons.sync_rounded,
                  size: 18,
                  color: _held || _stable ? c.primary : c.onSurfaceVariant,
                ),
                label: Text(
                  _held
                      ? 'Fixado'
                      : _stable
                      ? 'Estável'
                      : 'A medir…',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: angle == null
                    ? null
                    : () => setState(() => _held = !_held),
                icon: Icon(
                  _held ? Icons.lock_open_rounded : Icons.lock_rounded,
                ),
                label: Text(_held ? 'Continuar' : 'Fixar'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _raw == null || _held ? null : _calibrate,
                icon: const Icon(Icons.straighten_rounded),
                label: const Text('Calibrar'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Para calibrar, pousa o telemóvel no chão (ou no banco plano) e toca '
          'em Calibrar. Capas grossas ou câmaras salientes alteram a leitura.',
          style: theme.textTheme.bodySmall?.copyWith(color: c.onSurfaceVariant),
        ),
        if (widget.onSave != null) ...[
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: rounded == null ? null : () => widget.onSave!(rounded),
            icon: const Icon(Icons.save_rounded),
            label: Text(widget.saveLabel ?? 'Guardar'),
          ),
        ],
      ],
    );
  }
}

/// Floor, the backrest at [angle] and reference ticks every 15°.
class _BenchPainter extends CustomPainter {
  _BenchPainter({
    required this.angle,
    required this.line,
    required this.grid,
    required this.label,
  });

  final double angle;
  final Color line;
  final Color grid;
  final Color label;

  @override
  void paint(Canvas canvas, Size size) {
    final pivot = Offset(size.width * 0.3, size.height * 0.85);
    final radius = size.width * 0.6;
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(0, pivot.dy),
      Offset(size.width, pivot.dy),
      gridPaint,
    );

    for (var deg = 0; deg <= 90; deg += 15) {
      final r = deg * math.pi / 180;
      final dir = Offset(math.cos(r), -math.sin(r));
      canvas.drawLine(
        pivot + dir * (radius * 0.92),
        pivot + dir * radius,
        gridPaint,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: '$deg°',
          style: TextStyle(color: label, fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final at = pivot + dir * (radius + 14);
      tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
    }

    final a = angle.clamp(-30, 90) * math.pi / 180;
    final back = Offset(math.cos(a), -math.sin(a));
    canvas.drawLine(
      pivot,
      pivot + back * (radius * 0.85),
      Paint()
        ..color = line
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round,
    );
    // Seat, flat behind the pivot.
    canvas.drawLine(
      pivot,
      pivot - Offset(radius * 0.35, 0),
      Paint()
        ..color = line.withValues(alpha: 0.5)
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_BenchPainter old) => old.angle != angle;
}
