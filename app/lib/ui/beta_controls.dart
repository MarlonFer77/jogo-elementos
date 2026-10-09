import 'package:flutter/material.dart';
import '../game_domain/beta_session.dart';
import '../game_presentation/beta_arena_painter.dart';

class BetaJoystick extends StatefulWidget {
  const BetaJoystick({super.key, required this.onChanged, this.size = 112});
  final void Function(double x, double z) onChanged;
  final double size;
  @override
  State<BetaJoystick> createState() => _BetaJoystickState();
}

class _BetaJoystickState extends State<BetaJoystick> {
  int? _pointer;
  Offset _offset = Offset.zero;
  @override
  void didUpdateWidget(covariant BetaJoystick oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.size != widget.size) {
      _pointer = null;
      _offset = Offset.zero;
      widget.onChanged(0, 0);
    }
  }

  void _move(PointerEvent event) {
    if (_pointer != event.pointer) return;
    final radius = widget.size / 2 - 20;
    final delta =
        event.localPosition - Offset(widget.size / 2, widget.size / 2);
    final offset = delta.distance > radius
        ? delta / delta.distance * radius
        : delta;
    setState(() => _offset = offset);
    widget.onChanged(offset.dx / radius, offset.dy / radius);
  }

  void _release(PointerEvent event) {
    if (_pointer != event.pointer) return;
    _pointer = null;
    setState(() => _offset = Offset.zero);
    widget.onChanged(0, 0);
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Joystick de movimento: arraste para andar',
    child: Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        if (_pointer == null) {
          _pointer = event.pointer;
          _move(event);
        }
      },
      onPointerMove: _move,
      onPointerUp: _release,
      onPointerCancel: _release,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xAA203B35),
          border: Border.all(color: const Color(0xFFA7B595), width: 2),
        ),
        child: Center(
          child: Transform.translate(
            offset: _offset,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFE5D6AF),
                border: Border.all(color: const Color(0xFF716747), width: 3),
              ),
              child: const Icon(
                Icons.open_with,
                color: Color(0xFF314C40),
                size: 24,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class BetaActionPad extends StatelessWidget {
  const BetaActionPad({super.key, required this.run, required this.refresh});
  final BetaSession run;
  final VoidCallback refresh;
  void _action(bool Function() action) {
    action();
    refresh();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 196,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            for (final e in BetaElement.values)
              Expanded(
                child: Tooltip(
                  message: '${e.label}: ${e.description}',
                  child: Semantics(
                    selected: run.element == e,
                    button: true,
                    child: InkWell(
                      key: ValueKey('beta-element-${e.name}'),
                      onTap: () {
                        run.select(e);
                        refresh();
                      },
                      child: Container(
                        height: 44,
                        alignment: Alignment.center,
                        margin: const EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          color: run.element == e
                              ? betaElementColor(e)
                              : const Color(0xDD243F38),
                          border: Border.all(
                            color: betaElementColor(e),
                            width: run.element == e ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          e.label,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: run.element == e
                                ? const Color(0xFF253A35)
                                : const Color(0xFFF4E7C8),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _button(
                'Espada',
                Icons.flash_on,
                run.canSword ? () => _action(run.sword) : null,
                run.swordCooldown > 0
                    ? '${run.swordCooldown.toStringAsFixed(1)}s'
                    : 'Perto',
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _button(
                'Magia',
                Icons.auto_fix_high,
                run.canCast ? () => _action(run.cast) : null,
                run.spellCooldown > 0
                    ? '${run.spellCooldown.toStringAsFixed(1)}s'
                    : run.mana < 25
                    ? 'Sem mana'
                    : '25 MP',
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: _button(
            'Esquiva',
            Icons.air,
            run.canDodge ? () => _action(run.dodge) : null,
            run.dodgeCooldown > 0
                ? '${run.dodgeCooldown.toStringAsFixed(1)}s'
                : 'Desviar',
            compact: true,
          ),
        ),
      ],
    ),
  );
  Widget _button(
    String label,
    IconData icon,
    VoidCallback? action,
    String detail, {
    bool compact = false,
  }) => Semantics(
    button: true,
    enabled: action != null,
    label: '$label. $detail',
    excludeSemantics: true,
    child: Material(
      color: action == null ? const Color(0xFF6D7969) : const Color(0xFFEBDFBC),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        key: ValueKey('beta-$label'),
        splashFactory: NoSplash.splashFactory,
        onTap: action,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: BoxConstraints(minHeight: compact ? 44 : 64),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF716747), width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: compact
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 18),
                    const SizedBox(width: 5),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(detail, style: const TextStyle(fontSize: 10)),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 20, color: const Color(0xFF2E453B)),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF263B32),
                      ),
                    ),
                    Text(
                      detail,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF263B32),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    ),
  );
}
