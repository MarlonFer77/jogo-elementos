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
  void dispose() {
    _pointer = null;
    super.dispose();
  }

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
    if (!mounted || _pointer != event.pointer) return;
    final radius = widget.size / 2 - 20;
    final delta =
        event.localPosition - Offset(widget.size / 2, widget.size / 2);
    final offset = delta.distance > radius
        ? delta / delta.distance * radius
        : delta;
    setState(() => _offset = offset);
    // Ignore thumb jitter around the center; reaching the rim still means 100%.
    final magnitude = offset.distance / radius;
    final strength = ((magnitude - .12) / .88).clamp(0.0, 1.0);
    widget.onChanged(
      magnitude > 0 ? offset.dx / radius / magnitude * strength : 0,
      magnitude > 0 ? offset.dy / radius / magnitude * strength : 0,
    );
  }

  void _release(PointerEvent event) {
    if (!mounted || _pointer != event.pointer) return;
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
  void _action(BetaAction action) {
    run.request(action);
    refresh();
  }

  String _detail(BetaAction action) {
    if (run.queuedAction == action) return 'Na fila';
    if (run.castTime > 0) return 'Conjurando';
    if (action == BetaAction.cast && run.swordTime > 0) return 'Em ataque';
    if (action != BetaAction.dodge && run.dodgeTime > 0) return 'Esquivando';
    if (action == BetaAction.cast && run.mana < 25) return 'Sem mana';
    final cooldown = switch (action) {
      BetaAction.sword => run.swordCooldown,
      BetaAction.cast => run.spellCooldown,
      BetaAction.dodge => run.dodgeCooldown,
    };
    if (cooldown > 0) return '${cooldown.toStringAsFixed(1)}s';
    return switch (action) {
      BetaAction.sword =>
        run.aimTarget == null
            ? 'Mire à frente'
            : run.inSwordRange(run.aimTarget!)
            ? 'No alcance'
            : 'Aproxime-se',
      BetaAction.cast => '25 MP',
      BetaAction.dodge => 'Desviar',
    };
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
                      onTap: run.canSelectElement
                          ? () {
                              run.select(e);
                              refresh();
                            }
                          : null,
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
                run.canRequest(BetaAction.sword)
                    ? () => _action(BetaAction.sword)
                    : null,
                _detail(BetaAction.sword),
                progress: 1 - run.swordCooldown / .52,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _button(
                'Magia',
                Icons.auto_fix_high,
                run.canRequest(BetaAction.cast)
                    ? () => _action(BetaAction.cast)
                    : null,
                _detail(BetaAction.cast),
                progress: 1 - run.spellCooldown / 1.25,
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
            run.canRequest(BetaAction.dodge)
                ? () => _action(BetaAction.dodge)
                : null,
            _detail(BetaAction.dodge),
            compact: true,
            progress: 1 - run.dodgeCooldown / 1.6,
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
    double progress = 1,
  }) => Semantics(
    button: true,
    enabled: action != null,
    label: '$label. $detail',
    onTap: action,
    excludeSemantics: true,
    child: Material(
      color: action == null ? const Color(0xFFB4B69F) : const Color(0xFFEBDFBC),
      borderRadius: BorderRadius.circular(8),
      child: Listener(
        key: ValueKey('beta-$label'),
        behavior: HitTestBehavior.opaque,
        // Fire on contact, without waiting for the player's thumb to lift.
        onPointerDown: action == null ? null : (_) => action(),
        child: Container(
          constraints: BoxConstraints(minHeight: compact ? 44 : 64),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF716747), width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              compact
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, size: 18),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            detail,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF263B32),
                          ),
                        ),
                      ],
                    ),
              const SizedBox(height: 2),
              LinearProgressIndicator(
                value: progress.clamp(0, 1),
                minHeight: 2,
                color: const Color(0xFF3B685D),
                backgroundColor: const Color(0xFFABB193),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
