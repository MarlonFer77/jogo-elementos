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

class BetaActionPad extends StatefulWidget {
  const BetaActionPad({super.key, required this.run, required this.refresh});
  final BetaSession run;
  final VoidCallback refresh;
  @override
  State<BetaActionPad> createState() => _BetaActionPadState();
}

enum _SpellMode { single, mix, equipped }

class _BetaActionPadState extends State<BetaActionPad> {
  BetaSession get run => widget.run;
  void refresh() => widget.refresh();
  _SpellMode _mode = _SpellMode.single;

  @override
  void initState() {
    super.initState();
    if (run.selectedCombo != null) _mode = _SpellMode.mix;
  }

  void _action(BetaAction action) {
    run.request(action);
    refresh();
  }

  String _detail(BetaAction action) {
    if (run.queuedAction == action) return 'Na fila';
    if (run.castTime > 0) return 'Conjurando';
    if (action == BetaAction.cast && run.swordTime > 0) return 'Em ataque';
    if (run.dodgeTime > 0) return 'Rolando';
    if (action == BetaAction.cast && !run.spellEquipped) return 'Não equipado';
    if (action == BetaAction.cast && run.mana < run.spellManaCost) {
      return 'Sem mana';
    }
    if (run.arrivalTime > 0) return 'Chegando';
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
      BetaAction.cast =>
        '${run.spellManaCost.round()} MP · ${run.selectedCombo?.label ?? run.element.label}',
      BetaAction.dodge => 'Esquiva direcional',
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
            for (final mode in _SpellMode.values)
              Expanded(
                child: Semantics(
                  selected: _mode == mode,
                  child: TextButton(
                    key: ValueKey('beta-mode-${mode.name}'),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: EdgeInsets.zero,
                      foregroundColor: const Color(0xFFF4E7C8),
                      backgroundColor: _mode == mode
                          ? const Color(0xFF4A6552)
                          : const Color(0xDD243F38),
                      shape: const RoundedRectangleBorder(),
                    ),
                    onPressed: run.canSelectElement
                        ? () {
                            if (mode == _SpellMode.single) {
                              run.select(run.element);
                            }
                            setState(() => _mode = mode);
                            refresh();
                          }
                        : null,
                    child: Text(switch (mode) {
                      _SpellMode.single => 'Solo',
                      _SpellMode.mix => 'Mistura',
                      _SpellMode.equipped => '3 slots',
                    }, style: const TextStyle(fontSize: 11)),
                  ),
                ),
              ),
          ],
        ),
        if (_mode == _SpellMode.equipped)
          Row(
            children: [
              for (var slot = 0; slot < 3; slot++)
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: TextButton(
                      key: ValueKey('beta-combo-slot-$slot'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.all(2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        foregroundColor: const Color(0xFFF4E7C8),
                        backgroundColor:
                            slot < run.equippedCombos.length &&
                                run.selectedCombo == run.equippedCombos[slot]
                            ? const Color(0xFF4A6552)
                            : const Color(0xDD243F38),
                        side: BorderSide(
                          color: slot < run.equippedCombos.length
                              ? betaComboColor(run.equippedCombos[slot])
                              : const Color(0xFF51624D),
                        ),
                      ),
                      onPressed:
                          run.canSelectElement &&
                              slot < run.equippedCombos.length
                          ? () {
                              run.selectCombo(run.equippedCombos[slot]);
                              refresh();
                            }
                          : null,
                      child: Text(
                        slot < run.equippedCombos.length
                            ? run.equippedCombos[slot].label
                            : 'Vazio',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                ),
            ],
          )
        else
          Row(
            children: [
              for (final e in BetaElement.values)
                Expanded(
                  child: Tooltip(
                    message: _mode == _SpellMode.mix
                        ? 'Misture ${run.element.label} com ${e.label}. Toque de novo para remover.'
                        : '${e.label}: ${e.description}',
                    child: Semantics(
                      selected: run.element == e || run.secondaryElement == e,
                      button: true,
                      enabled: run.canSelectElement,
                      child: InkWell(
                        key: ValueKey('beta-element-${e.name}'),
                        onTap: run.canSelectElement
                            ? () {
                                if (_mode == _SpellMode.mix) {
                                  run.mix(e);
                                } else {
                                  run.select(e);
                                }
                                refresh();
                              }
                            : null,
                        child: Container(
                          height: 44,
                          alignment: Alignment.center,
                          margin: const EdgeInsets.all(1),
                          decoration: BoxDecoration(
                            color: run.element == e || run.secondaryElement == e
                                ? betaElementColor(e)
                                : const Color(0xDD243F38),
                            border: Border.all(
                              color: betaElementColor(e),
                              width:
                                  run.element == e || run.secondaryElement == e
                                  ? 2
                                  : 1,
                            ),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            e.label,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color:
                                  run.element == e || run.secondaryElement == e
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
                queued: run.queuedAction == BetaAction.sword,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _button(
                'Magia',
                switch (run.element) {
                  BetaElement.fire => Icons.local_fire_department,
                  BetaElement.water => Icons.water_drop,
                  BetaElement.wind => Icons.air,
                  BetaElement.earth => Icons.landscape,
                },
                run.canRequest(BetaAction.cast)
                    ? () => _action(BetaAction.cast)
                    : null,
                _detail(BetaAction.cast),
                progress: 1 - run.spellCooldown / run.spellRecovery,
                accent: run.selectedCombo == null
                    ? betaElementColor(run.element)
                    : betaComboColor(run.selectedCombo!),
                queued: run.queuedAction == BetaAction.cast,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: _button(
            'Rolar',
            Icons.rotate_right,
            run.canRequest(BetaAction.dodge)
                ? () => _action(BetaAction.dodge)
                : null,
            _detail(BetaAction.dodge),
            compact: true,
            progress: 1 - run.dodgeCooldown / 1.6,
            queued: run.queuedAction == BetaAction.dodge,
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
    Color? accent,
    bool queued = false,
  }) => _ContactFeedback(
    key: ValueKey('beta-$label'),
    label: '$label. $detail',
    onPressed: action,
    child: Material(
      color: action == null
          ? const Color(0xFFB4B69F)
          : Color.lerp(
              const Color(0xFFEBDFBC),
              accent ?? const Color(0xFFEBDFBC),
              .24,
            ),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: BoxConstraints(minHeight: compact ? 44 : 64),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          border: Border.all(
            color: queued ? const Color(0xFFD99A43) : const Color(0xFF716747),
            width: 2,
          ),
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
                      Tooltip(
                        message: detail,
                        child: Text(
                          detail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF263B32),
                          ),
                        ),
                      ),
                    ],
                  ),
            const SizedBox(height: 2),
            LinearProgressIndicator(
              value: progress.clamp(0, 1),
              minHeight: 2,
              color: Color.lerp(
                const Color(0xFF3B685D),
                accent ?? const Color(0xFF3B685D),
                .25,
              ),
              backgroundColor: const Color(0xFFABB193),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Keeps the touch target fixed while its surface gives immediate feedback.
/// One contact means one request; releasing/cancelling never fires again.
class _ContactFeedback extends StatefulWidget {
  const _ContactFeedback({
    super.key,
    required this.label,
    required this.onPressed,
    required this.child,
  });
  final String label;
  final VoidCallback? onPressed;
  final Widget child;

  @override
  State<_ContactFeedback> createState() => _ContactFeedbackState();
}

class _ContactFeedbackState extends State<_ContactFeedback> {
  int? _pointer;

  void _release(PointerEvent event) {
    if (!mounted || _pointer != event.pointer) return;
    setState(() => _pointer = null);
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: widget.onPressed != null,
    label: widget.label,
    onTap: widget.onPressed,
    excludeSemantics: true,
    child: Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        if (!mounted || _pointer != null || widget.onPressed == null) return;
        setState(() => _pointer = event.pointer);
        widget.onPressed!();
      },
      onPointerUp: _release,
      onPointerCancel: _release,
      child: AnimatedScale(
        scale: _pointer == null || MediaQuery.disableAnimationsOf(context)
            ? 1
            : .96,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 70),
        child: widget.child,
      ),
    ),
  );
}
