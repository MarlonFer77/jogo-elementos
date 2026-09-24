import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../game_domain/conjuration_seal.dart';

/// Null means cancelled before touching the first node. Empty trace is failure.
Future<List<Map<String, num>>?> showConjurationSeal(
  BuildContext context, {
  required List<String> elements,
  required Future<int> Function() onStart,
}) => showDialog<List<Map<String, num>>>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _SealDialog(elements: elements, onStart: onStart),
);

class _SealDialog extends StatefulWidget {
  const _SealDialog({required this.elements, required this.onStart});
  final List<String> elements;
  final Future<int> Function() onStart;
  @override
  State<_SealDialog> createState() => _SealDialogState();
}

class _SealDialogState extends State<_SealDialog> with WidgetsBindingObserver {
  late final seal = ConjurationSeal(widget.elements);
  final trace = <Map<String, num>>[];
  final clock = Stopwatch();
  Timer? timer;
  bool started = false, loading = false, done = false, interrupted = false;
  int limit = 0;
  int? pointer;
  final trail = <Offset>[];
  String? correction;
  int? warnedNode;
  bool timeWarningSent = false;

  int get remainingMs => max(0, limit - clock.elapsedMilliseconds);
  bool get urgent => started && !loading && remainingMs <= 2000;
  int get resumeIndex => max(0, trace.length - 1);
  String get guidance => loading
      ? 'Aguarde a confirmação para traçar.'
      : correction ??
            (!started
                ? 'Comece no nó 1. O tempo ainda não começou.'
                : pointer == null
                ? 'Retome pelo nó ${resumeIndex + 1} aceso.'
                : 'Siga até o nó ${trace.length + 1}.');

  void warn(String message, {int? node}) {
    if (correction == message) return;
    setState(() => correction = message);
    if (node != null && warnedNode != node) {
      warnedNode = node;
      unawaited(HapticFeedback.lightImpact());
    }
  }

  void pointerMove(PointerMoveEvent event, double side) {
    if (event.pointer != pointer || loading || done) return;
    final point = Offset(
      (event.localPosition.dx / side).clamp(0, 1),
      (event.localPosition.dy / side).clamp(0, 1),
    );
    setState(() {
      if (trail.isEmpty || (trail.last - point).distance > .008) {
        trail.add(point);
        if (trail.length > 48) trail.removeAt(0);
      }
    });
    unawaited(touch(event.localPosition, side));
  }

  void pointerEnd(PointerEvent event) {
    if (event.pointer != pointer) return;
    setState(() {
      pointer = null;
      correction = null;
    });
  }

  void pointerDown(PointerDownEvent event, double side) {
    if (pointer != null || loading || done) return;
    final point = event.localPosition;
    final index = resumeIndex;
    if (!seal.hits(index, point.dx / side, point.dy / side)) {
      warn(
        started
            ? 'Retome pelo nó ${index + 1} aceso.'
            : 'Comece pelo nó 1. Sem custo até tocar nele.',
      );
      return;
    }
    setState(() {
      pointer = event.pointer;
      correction = null;
      warnedNode = null;
      trail
        ..clear()
        ..add(Offset(point.dx / side, point.dy / side));
    });
    if (trace.isEmpty) unawaited(touch(point, side));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (started && state != AppLifecycleState.resumed) {
      interrupted = true;
      if (!loading) finish(false);
    }
  }

  void finish(bool success) {
    if (done || !mounted) return;
    done = true;
    timer?.cancel();
    Navigator.of(context).pop(success ? trace : <Map<String, num>>[]);
  }

  Future<void> touch(Offset point, double side) async {
    if (loading || done) return;
    final x = point.dx / side, y = point.dy / side;
    if (!seal.hits(trace.length, x, y)) {
      for (var i = 0; i < seal.nodes.length; i++) {
        if (i != resumeIndex && seal.hits(i, x, y)) {
          warn(
            'Ainda falta o nó ${trace.length + 1}. Continue o traçado.',
            node: i,
          );
          break;
        }
      }
      return;
    }
    if (!started) {
      setState(() {
        started = true;
        loading = true;
      });
      try {
        limit = await widget.onStart();
        if (!mounted) return;
        loading = false;
        if (interrupted || limit <= 0) {
          finish(false);
          return;
        }
        clock.start();
        timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
          if (clock.elapsedMilliseconds >= limit) {
            finish(false);
          } else if (mounted) {
            if (urgent && !timeWarningSent) {
              timeWarningSent = true;
              unawaited(HapticFeedback.mediumImpact());
            }
            setState(() {});
          }
        });
      } catch (_) {
        // Unknown network outcome must be reconciled, never offer free retries.
        if (mounted) Navigator.of(context).pop(<Map<String, num>>[]);
        return;
      }
    }
    if (clock.elapsedMilliseconds >= limit) {
      finish(false);
      return;
    }
    final ms = max(
      clock.elapsedMilliseconds,
      trace.isEmpty ? 0 : trace.last['ms']!.toInt() + 1,
    );
    trace.add({'x': x, 'y': y, 'ms': ms});
    correction = null;
    warnedNode = null;
    unawaited(HapticFeedback.selectionClick());
    setState(() {});
    if (trace.length == seal.nodes.length) finish(true);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final side = min(
      300.0,
      min(
        size.width - 72,
        size.height - MediaQuery.paddingOf(context).vertical - 210,
      ),
    ).clamp(100.0, 300.0);
    return PopScope(
      canPop: !started,
      child: Dialog(
        insetPadding: const EdgeInsets.all(12),
        backgroundColor: const Color(0xFFF3EBD1),
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Color(0xFF343C38), width: 4),
          borderRadius: BorderRadius.circular(4),
        ),
        child: SizedBox(
          width: min(size.width - 24, max(300, side + 24)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  height: 20,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'SELO DE CONJURAÇÃO',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 20,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      loading
                          ? 'Sincronizando… aguarde'
                          : !started
                          ? 'Arraste do 1 pelos nós em ordem'
                          : '${urgent ? 'Tempo acabando · ' : ''}${trace.length}/${seal.nodes.length} nós · ${(remainingMs / 1000).toStringAsFixed(1)}s',
                      key: const ValueKey('seal-timer'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: urgent
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: urgent
                            ? const Color(0xFF993D2C)
                            : const Color(0xFF343C38),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: side,
                  height: side,
                  child: Listener(
                    onPointerDown: (e) => pointerDown(e, side),
                    onPointerMove: (e) => pointerMove(e, side),
                    onPointerUp: pointerEnd,
                    onPointerCancel: pointerEnd,
                    child: CustomPaint(
                      key: const ValueKey('seal-canvas'),
                      painter: _SealPainter(
                        seal,
                        trace.length,
                        widget.elements,
                        trail: List.unmodifiable(trail),
                        urgent: urgent,
                        resume: started && pointer == null && !loading,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
                SizedBox(
                  height: 4,
                  child: started
                      ? LinearProgressIndicator(
                          value: loading
                              ? null
                              : (1 - clock.elapsedMilliseconds / limit).clamp(
                                  0,
                                  1,
                                ),
                          color: urgent
                              ? const Color(0xFF993D2C)
                              : const Color(0xFF997242),
                        )
                      : null,
                ),
                SizedBox(
                  height: 32,
                  child: Center(
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        guidance,
                        key: const ValueKey('seal-guidance'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: correction == null
                              ? const Color(0xFF343C38)
                              : const Color(0xFF993D2C),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(
                  height: 28,
                  child: Center(
                    child: Text(
                      'Falha: −1 AP, sem regeneração · encerra o turno',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10),
                    ),
                  ),
                ),
                SizedBox(
                  height: 40,
                  child: !started
                      ? TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Voltar'),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SealPainter extends CustomPainter {
  _SealPainter(
    this.seal,
    this.reached,
    this.elements, {
    required this.trail,
    required this.urgent,
    required this.resume,
  });
  final ConjurationSeal seal;
  final int reached;
  final List<String> elements;
  final List<Offset> trail;
  final bool urgent;
  final bool resume;
  static const colors = {
    'fire': Color(0xFFB64F32),
    'water': Color(0xFF397797),
    'earth': Color(0xFF886D49),
    'wind': Color(0xFF6A927C),
    'ice': Color(0xFF639AA3),
    'lightning': Color(0xFFAE8734),
    'nature': Color(0xFF5E8041),
    'shadow': Color(0xFF705777),
    'light': Color(0xFFAA955A),
    'poison': Color(0xFF84669B),
  };
  @override
  void paint(Canvas canvas, Size size) {
    final points = seal.nodes
        .map((n) => Offset(n.x * size.width, n.y * size.height))
        .toList();
    final paint = Paint()
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(
      size.center(Offset.zero),
      size.width * .43,
      paint..color = const Color(0xFFD3C7A7),
    );
    if (trail.length > 1) {
      final ink = Paint()
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      for (var i = 1; i < trail.length; i++) {
        ink.color = const Color(
          0xFF776442,
        ).withValues(alpha: .15 + .5 * i / trail.length);
        canvas.drawLine(
          Offset(trail[i - 1].dx * size.width, trail[i - 1].dy * size.height),
          Offset(trail[i].dx * size.width, trail[i].dy * size.height),
          ink,
        );
      }
    }
    for (var i = 1; i < points.length; i++) {
      paint.color = i < reached
          ? colors[elements[(i - 1) % elements.length]] ?? Colors.brown
          : const Color(0xFFB7AF99);
      if (elements.contains('water') || elements.contains('wind')) {
        final mid = Offset.lerp(points[i - 1], points[i], .5)!;
        final control = Offset.lerp(mid, size.center(Offset.zero), -.22)!;
        canvas.drawPath(
          Path()
            ..moveTo(points[i - 1].dx, points[i - 1].dy)
            ..quadraticBezierTo(
              control.dx,
              control.dy,
              points[i].dx,
              points[i].dy,
            ),
          paint,
        );
      } else {
        canvas.drawLine(points[i - 1], points[i], paint);
      }
    }
    for (var i = 0; i < points.length; i++) {
      final active = i == reached;
      final resumeHere = resume && i == reached - 1;
      if (active && !resume || resumeHere) {
        canvas.drawCircle(
          points[i],
          24,
          paint
            ..strokeWidth = 2
            ..color = urgent
                ? const Color(0xFF993D2C)
                : const Color(0xFF997242),
        );
        paint.strokeWidth = 4;
      }
      canvas.drawCircle(
        points[i],
        active ? 19 : 15,
        Paint()
          ..color = i < reached
              ? colors[elements[i % elements.length]] ?? Colors.brown
              : const Color(0xFFFDF8E5),
      );
      canvas.drawCircle(
        points[i],
        active ? 19 : 15,
        paint
          ..color = active ? const Color(0xFF343C38) : const Color(0xFF9B9179),
      );
      final text = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: const TextStyle(
            color: Color(0xFF272E2B),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, points[i] - Offset(text.width / 2, text.height / 2));
    }
  }

  @override
  bool shouldRepaint(_SealPainter old) =>
      old.reached != reached ||
      old.seal != seal ||
      old.trail != trail ||
      old.urgent != urgent ||
      old.resume != resume;
}
