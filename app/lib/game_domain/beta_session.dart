import 'dart:math' as math;
import 'dart:convert';
import 'beta_world.dart';
import 'beta_spells.dart';
import 'beta_skills.dart';
import 'beta_puzzles.dart';
import 'cosmetics.dart';

export 'beta_world.dart';
export 'beta_spells.dart';
export 'beta_skills.dart';
export 'beta_puzzles.dart';

part 'beta_checkpoint.dart';

/// Offline sandbox. Never writes campaign/online rewards or turn-based saves.
enum BetaPhase { ready, playing, paused, won, lost }

/// Enemy identity and combat tuning share one catalogue; no rendering data.
enum BetaEnemyKind {
  goblin('Goblin', shape: BetaAttackShape.thrust),
  brute(
    'Ogro',
    health: 72,
    shape: BetaAttackShape.sweep,
    reach: 2.7,
    preparation: .85,
    recovery: .55,
    strike: .18,
    speed: 1.65,
    reward: 40,
  ),
  darkElf(
    'Elfo Sombrio',
    shape: BetaAttackShape.sweep,
    reach: 2.25,
    preparation: .85,
    recovery: .5,
    strike: .14,
    speed: 2,
  ),
  guardian(
    'Guardião',
    health: 190,
    shape: BetaAttackShape.slam,
    reach: 2.1,
    preparation: 1.05,
    recovery: .75,
    strike: .18,
    speed: 1.35,
    reward: 100,
    damage: 25,
    radius: .75,
    approach: 2.6,
    cooldown: 1.7,
  );

  const BetaEnemyKind(
    this.label, {
    required this.shape,
    this.health = 38,
    this.reach = 2.4,
    this.preparation = .7,
    this.recovery = .36,
    this.strike = .12,
    this.speed = 2.15,
    this.reward = 20,
    this.damage = 12,
    this.radius = .42,
    this.approach = 1.55,
    this.cooldown = 1.3,
  });
  final String label;
  final BetaAttackShape shape;
  final double health,
      reach,
      preparation,
      recovery,
      strike,
      speed,
      damage,
      radius,
      approach,
      cooldown;
  final int reward;
}

enum BetaSound {
  sword,
  cast,
  impact,
  hurt,
  dodge,
  level,
  victory,
  defeat,
  enemySwing,
  heavyImpact,
  fireImpact,
  waterImpact,
  windImpact,
  earthImpact,
  passage,
  discovery,
  ward,
}

enum BetaAction { sword, cast, dodge }

enum BetaEffectKind { impact, spell, blocked, heal }

enum BetaAttackShape { thrust, sweep, slam }

/// Immutable attack commitment, shared by hit detection and presentation.
/// Dimensions are world units; contains checks the player's ground position.
class BetaAttackArea {
  const BetaAttackArea(this.shape, this.x, this.z, this.angle, this.reach);
  final BetaAttackShape shape;
  final double x, z, angle, reach;
  static const thrustHalfWidth = .42, sweepHalfAngle = math.pi * .38;

  bool contains(double px, double pz) {
    final dx = px - x, dz = pz - z;
    final forward = dx * math.sin(angle) + dz * math.cos(angle);
    final side = dx * math.cos(angle) - dz * math.sin(angle);
    const epsilon = .000001;
    return switch (shape) {
      BetaAttackShape.thrust =>
        forward >= -epsilon &&
            forward <= reach + epsilon &&
            side.abs() <= thrustHalfWidth + epsilon,
      BetaAttackShape.sweep =>
        dx * dx + dz * dz <= reach * reach + epsilon &&
            (dx.abs() + dz.abs() < epsilon ||
                forward >=
                    math.sqrt(dx * dx + dz * dz) * math.cos(sweepHalfAngle) -
                        epsilon),
      BetaAttackShape.slam => dx * dx + dz * dz <= reach * reach + epsilon,
    };
  }

  List<({double x, double z})> get outline {
    ({double x, double z}) point(double forward, double side) => (
      x: x + forward * math.sin(angle) + side * math.cos(angle),
      z: z + forward * math.cos(angle) - side * math.sin(angle),
    );
    if (shape == BetaAttackShape.thrust) {
      return [
        point(0, -thrustHalfWidth),
        point(reach, -thrustHalfWidth),
        point(reach, thrustHalfWidth),
        point(0, thrustHalfWidth),
      ];
    }
    final halfAngle = shape == BetaAttackShape.slam ? math.pi : sweepHalfAngle;
    return [
      if (shape == BetaAttackShape.sweep) (x: x, z: z),
      for (var i = 0; i <= 24; i++)
        point(
          math.cos(-halfAngle + i * halfAngle / 12) * reach,
          math.sin(-halfAngle + i * halfAngle / 12) * reach,
        ),
    ];
  }
}

class BetaEnemy {
  BetaEnemy(this.kind, this.x, this.z) : hp = kind.health;
  final BetaEnemyKind kind;
  double x, z, hp;
  double angle = 0, windup = 0, cooldown = .6, aimX = 0, aimZ = 0;
  double slow = 0, burn = 0, flash = 0, stride = 0;
  double detour = 0, steerX = 0, steerZ = 0;
  double recovery = 0, deathTime = 0, pushTime = 0, pushX = 0, pushZ = 0;
  bool _rewarded = false;
  BetaAttackArea? _attackArea;
  bool moving = false;
  bool get alive => hp > 0;
  bool get boss => kind == BetaEnemyKind.guardian;
  String get label => kind.label;
  double get radius => kind.radius;
  double get maxHp => kind.health;
  BetaAttackShape get attackShape => kind.shape;
  String get attackLabel => kind == BetaEnemyKind.darkElf
      ? 'Corte duplo'
      : switch (attackShape) {
          BetaAttackShape.thrust => 'Estocada',
          BetaAttackShape.sweep => 'Varredura',
          BetaAttackShape.slam => 'Impacto',
        };
  double get preparation => kind.preparation;
  double get recoveryDuration => kind.recovery;
  double get strikeDuration => kind.strike;
  BetaAttackArea get attackArea => _attackArea ?? _makeArea();

  BetaAttackArea _makeArea() => BetaAttackArea(
    attackShape,
    boss ? aimX : x,
    boss ? aimZ : z,
    math.atan2(aimX - x, aimZ - z),
    kind.reach,
  );

  void beginAttack(double targetX, double targetZ) {
    aimX = targetX;
    aimZ = targetZ;
    angle = math.atan2(aimX - x, aimZ - z);
    _attackArea = _makeArea();
    windup = preparation;
    recovery = 0;
  }

  void cancelAttack() {
    windup = recovery = 0;
    _attackArea = null;
  }
}

class BetaProjectile {
  BetaProjectile(this.x, this.z, this.dx, this.dz, this.element, {this.combo});
  double x, z, life = 1.3;
  final double dx, dz;
  final BetaElement element;
  final BetaCombo? combo;
}

class BetaEffect {
  BetaEffect(
    this.x,
    this.z,
    this.element, {
    this.text,
    this.hurt = false,
    this.kind = BetaEffectKind.impact,
    this.area,
    this.combo,
  });
  final double x, z;
  final BetaElement element;
  final String? text;
  final bool hurt;
  final BetaEffectKind kind;
  final BetaAttackArea? area;
  final BetaCombo? combo;
  double life = .65;
}

class BetaSession {
  BetaSession({this.loadout = const BetaLoadout()});
  final BetaLoadout loadout;
  BetaCheckpoint? latestCheckpoint;
  bool _checkpointAfterCombat = false;
  bool _checkpoint() {
    // Keep the previous safe point if lingering damage would cause a death loop.
    if (hp <= burnTime * 2 || phase == BetaPhase.lost) return false;
    latestCheckpoint = BetaCheckpoint._capture(this);
    return true;
  }

  /// Start-of-region rollback is atomic: no partial combat XP is persisted.
  void checkpointOutsideCombat() {
    if (phase == BetaPhase.ready || remaining == 0) _checkpoint();
  }

  double blessingTime = 0, merlinTime = 0, burnTime = 0, curseTime = 0;
  double wardTime = 0; // Presentation-only confirmation of a resisted status.
  BetaElement blessingElement = BetaElement.fire;
  BetaCombo? blessingCombo;
  BetaElement _strikeElement = BetaElement.fire;
  BetaCombo? _strikeCombo;
  // Keep the committed impact's color through follow-through, after charge consumption.
  BetaElement get bladeElement => swordTime > 0 && !_swordPending
      ? _strikeElement
      : blessingTime > 0
      ? blessingElement
      : element;
  BetaCombo? get bladeCombo => swordTime > 0 && !_swordPending
      ? _strikeCombo
      : blessingTime > 0
      ? blessingCombo
      : null;
  static const arenaX = BetaRegion.halfWidth, arenaZ = BetaRegion.halfDepth;
  // Shared with the renderer: the blade crosses its target at swordContact.
  static const swordDuration = .44, swordContact = .16, castDuration = .35;
  static const dodgeDuration = .42, dodgeDistance = 2.64;
  static const deathDuration = .65, inputBuffer = .18;
  static const swordReach = 1.9, spellAimRange = 9.0, projectileRadius = .12;
  BetaRegion get region =>
      BetaRegion.values[(wave - 1).clamp(0, BetaRegion.values.length - 1)];
  final _puzzles = [
    for (final puzzle in BetaPuzzle.catalog) BetaPuzzleProgress(puzzle),
  ];
  BetaPuzzleProgress get puzzle => _puzzles[region.index];
  int get restoredAreas => _puzzles.where((p) => p.solved).length;

  // Visual restoration carries across regions; local puzzles still gate travel.
  bool get sceneryRestored => restoredAreas > 0;
  bool get puzzleActive =>
      playing && remaining == 0 && !puzzle.solved && arrivalTime <= 0;
  int? get nearbyAltar {
    if (!puzzleActive) return null;
    for (var i = 0; i < BetaAltar.all.length; i++) {
      final altar = BetaAltar.all[i];
      if (distance(x, z, altar.x, altar.z) <= 1.35) return i;
    }
    return null;
  }

  double _attuneCooldown = 0;
  bool get canAttune =>
      nearbyAltar != null &&
      _attuneCooldown <= 0 &&
      swordTime <= 0 &&
      castTime <= 0 &&
      dodgeTime <= 0;

  void revealPuzzleHint() {
    if (!puzzleActive) return;
    puzzle.revealHint();
    _checkpoint();
    message = 'PISTA · ${puzzle.next!.hint}';
    messageTime = 8;
  }

  bool attune() {
    if (!canAttune) return false;
    _clearBuffer();
    _attuneCooldown = .4;
    final altar = BetaAltar.all[nearbyAltar!];
    final accepted = puzzle.offer(nearbyAltar!, element, secondaryElement);
    message = accepted
        ? puzzle.solved
              ? 'RESTAURADO · ${puzzle.puzzle.restoration}'
              : 'ECO ${puzzle.completed}/${puzzle.puzzle.steps.length} · selo ${altar.label} ativado'
        : 'O selo não ressoou. Confira a ordem e os elementos.\nProgresso mantido; Inscrição oferece pistas.';
    messageTime = 4;
    if (accepted) {
      sounds.add(puzzle.solved ? BetaSound.discovery : BetaSound.passage);
      effects.add(
        BetaEffect(
          altar.x,
          altar.z,
          element,
          text: 'ECO',
          kind: BetaEffectKind.heal,
        ),
      );
    }
    // Rituals never spend mana, equip combat skills or grant farmable XP.
    if (accepted) _checkpoint();
    return accepted;
  }

  List<BetaObstacle> get obstacles => region.obstacles;
  BetaPhase phase = BetaPhase.ready;
  BetaElement element = BetaElement.fire;
  BetaElement? secondaryElement;
  BetaCombo? get selectedCombo => BetaCombo.resolve(element, secondaryElement);
  final _discoveredCombos = <BetaCombo>{};
  final _equippedCombos = <BetaCombo>[];
  final _skills = <BetaSkill>{};
  int _skillPoints = 1;
  int get skillPoints => _skillPoints;
  Set<BetaCombo> get discoveredCombos => Set.unmodifiable(_discoveredCombos);
  List<BetaCombo> get equippedCombos => List.unmodifiable(_equippedCombos);
  bool hasSkill(BetaSkill skill) => _skills.contains(skill);
  bool get canManageBuild =>
      phase == BetaPhase.ready || (phase == BetaPhase.paused && remaining == 0);
  double runicBladeTime = 0;
  double get spellManaCost => (selectedCombo?.mana ?? 25).toDouble();
  double get spellRecovery => selectedCombo?.cooldown ?? 1.25;
  bool get spellEquipped =>
      selectedCombo == null ||
      !_discoveredCombos.contains(selectedCombo) ||
      _equippedCombos.contains(selectedCombo);
  double get activeCastDuration => _castCombo?.castTime ?? castDuration;
  BetaCombo? get castingCombo => _castCombo;
  final enemies = <BetaEnemy>[];
  final projectiles = <BetaProjectile>[];
  final effects = <BetaEffect>[];
  final sounds = <BetaSound>[];
  double x = 0, z = 5, angle = math.pi, hp = 100, mana = 100, time = 0;
  static const maxStamina = 100.0,
      swordStaminaCost = 18.0,
      dodgeStaminaCost = 28.0,
      staminaRecovery = 22.0,
      staminaRecoveryDelay = .8;
  double stamina = maxStamina;
  double _staminaWait = 0;
  double staminaCost(BetaAction action) => switch (action) {
    BetaAction.sword => swordStaminaCost,
    BetaAction.dodge => dodgeStaminaCost,
    BetaAction.cast => 0,
  };
  bool hasStaminaFor(BetaAction action) => stamina >= staminaCost(action);
  void _spendStamina(BetaAction action) {
    stamina -= staminaCost(action);
    _staminaWait = staminaRecoveryDelay;
  }

  double moveX = 0,
      moveZ = 0,
      swordCooldown = 0,
      spellCooldown = 0,
      dodgeCooldown = 0;
  double swordTime = 0,
      castTime = 0,
      dodgeTime = 0,
      invulnerable = 0,
      protection = 0;
  double _dodgeX = 0, _dodgeZ = 0, _waveWait = 0;
  double _gateHold = 0, arrivalTime = 0;
  static const arrivalDuration = .35, gateHoldDuration = .55;
  double stride = 0, hurtTime = 0, impactTime = 0, resultTime = 0;
  double _bufferTime = 0;
  bool _moving = false;
  int swordSide = 1;
  BetaAction? queuedAction;
  bool _swordPending = false;
  BetaElement _castElement = BetaElement.fire;
  BetaCombo? _castCombo;
  BetaEnemy? _actionTarget;
  int wave = 1, level = 1, xp = 0, kills = 0;
  String message = 'Atravesse a ruína. Desperte os ecos.';
  double messageTime = 5;
  double get maxHp => 100 + (level - 1) * 10;
  int get nextLevelXp => 60 + (level - 1) * 80;
  bool get playing => phase == BetaPhase.playing;
  bool get moving => playing && _moving;
  bool get settling => resultTime > 0;
  bool get finalArea => wave == BetaRegion.values.length;
  double get nextEncounterIn =>
      (playing || phase == BetaPhase.paused) && remaining == 0 && puzzle.solved
      ? math.max(0, 2 - _waveWait)
      : 0;
  bool get passageOpen =>
      (playing || phase == BetaPhase.paused) &&
      remaining == 0 &&
      puzzle.solved &&
      _waveWait >= 2;
  double get passageProgress => (_gateHold / gateHoldDuration).clamp(0.0, 1.0);
  bool get canSelectElement =>
      playing && arrivalTime <= 0 && castTime <= 0 && swordTime <= 0;
  int get remaining => enemies.where((e) => e.alive).length;
  bool get canSword =>
      playing &&
      hasStaminaFor(BetaAction.sword) &&
      arrivalTime <= 0 &&
      swordCooldown <= 0 &&
      castTime <= 0 &&
      dodgeTime <= 0;
  bool get canCast =>
      playing &&
      arrivalTime <= 0 &&
      spellCooldown <= 0 &&
      mana >= spellManaCost &&
      spellEquipped &&
      swordTime <= 0 &&
      dodgeTime <= 0;
  bool get canDodge =>
      playing &&
      hasStaminaFor(BetaAction.dodge) &&
      arrivalTime <= 0 &&
      dodgeCooldown <= 0 &&
      castTime <= 0;
  double get aimDirection => swordTime > 0 || castTime > 0 ? angle : _aimAngle;
  double get dodgeDirection => math.atan2(_dodgeX, _dodgeZ);
  BetaEnemy? get aimTarget {
    if (!playing) return null;
    if (swordTime > 0 || castTime > 0) {
      return _actionTarget?.alive == true ? _actionTarget : null;
    }
    return _findTarget(spellAimRange);
  }

  bool inSwordRange(BetaEnemy target) =>
      target.alive &&
      distance(x, z, target.x, target.z) <= swordReach + target.radius &&
      clearLine(x, z, target.x, target.z);

  void start() {
    if (phase != BetaPhase.ready) return;
    phase = BetaPhase.playing;
    _spawn();
    _checkpoint();
  }

  void pause() {
    if (playing) phase = BetaPhase.paused;
    // Backgrounding during the result transition must not hide every control
    // behind a stopped game loop. Reveal the result immediately in that case.
    if (phase == BetaPhase.won || phase == BetaPhase.lost) resultTime = 0;
    setMovement(0, 0);
    _clearBuffer();
    _gateHold = 0;
    _moving = false;
    checkpointOutsideCombat();
  }

  void resume() {
    if (phase == BetaPhase.paused) phase = BetaPhase.playing;
  }

  void setMovement(double horizontal, double vertical) {
    if (!horizontal.isFinite ||
        !vertical.isFinite ||
        !playing ||
        arrivalTime > 0) {
      moveX = moveZ = 0;
      return;
    }
    final length = math.sqrt(horizontal * horizontal + vertical * vertical);
    final scale = math.max(1, length);
    moveX = horizontal / scale;
    moveZ = vertical / scale;
  }

  void select(BetaElement value) {
    if (canSelectElement) {
      element = value;
      secondaryElement = null;
      _clearBuffer();
    }
  }

  void mix(BetaElement value) {
    if (!canSelectElement) return;
    secondaryElement = value == element || value == secondaryElement
        ? null
        : value;
    _clearBuffer();
  }

  bool selectCombo(BetaCombo combo) {
    if (!canSelectElement || !_equippedCombos.contains(combo)) return false;
    element = combo.first;
    secondaryElement = combo.second;
    _clearBuffer();
    checkpointOutsideCombat();
    return true;
  }

  bool equipCombo(BetaCombo combo, {int? replaceSlot}) {
    if (!canManageBuild ||
        !_discoveredCombos.contains(combo) ||
        _equippedCombos.contains(combo)) {
      return false;
    }
    if (replaceSlot != null) {
      if (replaceSlot < 0 || replaceSlot >= _equippedCombos.length) {
        return false;
      }
      _equippedCombos[replaceSlot] = combo;
    } else {
      if (_equippedCombos.length >= 3) return false;
      _equippedCombos.add(combo);
    }
    _clearBuffer();
    checkpointOutsideCombat();
    return true;
  }

  String? skillLock(BetaSkill skill) {
    if (hasSkill(skill)) return 'Aprendida';
    if (!canManageBuild) return 'Limpe a área antes de aprender';
    if (level < skill.level) return 'Requer nível ${skill.level}';
    if (skill.prerequisite case final required?) {
      if (!hasSkill(required)) return 'Requer ${required.label}';
    }
    if (_skillPoints <= 0) return 'Sem pontos';
    return null;
  }

  bool learnSkill(BetaSkill skill) {
    if (skillLock(skill) != null) return false;
    _skills.add(skill);
    _skillPoints--;
    checkpointOutsideCombat();
    return true;
  }

  double _actionWait(BetaAction action) => switch (action) {
    BetaAction.sword => math.max(swordCooldown, math.max(castTime, dodgeTime)),
    BetaAction.cast => math.max(spellCooldown, math.max(swordTime, dodgeTime)),
    BetaAction.dodge => math.max(dodgeCooldown, castTime),
  };

  bool canRequest(BetaAction action) =>
      playing &&
      arrivalTime <= 0 &&
      hasStaminaFor(action) &&
      (action != BetaAction.cast || (mana >= spellManaCost && spellEquipped)) &&
      _actionWait(action) <= inputBuffer;

  /// One short-lived intent, never a chain of automatic attacks. Revalidated
  /// on execution and discarded on pause, element change or dodge.
  bool request(BetaAction action) {
    if (!canRequest(action)) return false;
    if (_actionWait(action) <= 0) {
      _clearBuffer();
      return _execute(action);
    }
    queuedAction = action;
    _bufferTime = inputBuffer;
    return true;
  }

  bool _execute(BetaAction action) => switch (action) {
    BetaAction.sword => sword(),
    BetaAction.cast => cast(),
    BetaAction.dodge => dodge(),
  };

  void _clearBuffer() {
    queuedAction = null;
    _bufferTime = 0;
  }

  void _consumeInput(double dt) {
    final action = queuedAction;
    if (action == null) return;
    // All blocking animation timers must be advanced before expiring intent.
    // Otherwise input on the last frame of a cast/swing is silently dropped.
    if (_actionWait(action) <= 0 && _bufferTime > 0) {
      _clearBuffer();
      _execute(
        action,
      ); // Rechecks resources/phase; queued intent spends nothing.
    } else {
      _bufferTime = _tick(_bufferTime, dt);
      if (_bufferTime == 0) _clearBuffer();
    }
  }

  bool sword() {
    if (!canSword) return false;
    _spendStamina(BetaAction.sword);
    _aim(swordReach, melee: true);
    swordCooldown = .52;
    swordTime = swordDuration;
    swordSide = -swordSide;
    _swordPending = true;
    return true;
  }

  bool cast() {
    if (!canCast) return false;
    _aim(spellAimRange);
    _castCombo = selectedCombo;
    _castElement = _castCombo?.first ?? element;
    mana -= spellManaCost;
    castTime = activeCastDuration;
    spellCooldown = spellRecovery;
    sounds.add(BetaSound.cast);
    return true;
  }

  bool dodge() {
    if (!canDodge) return false;
    _spendStamina(BetaAction.dodge);
    final length = math.sqrt(moveX * moveX + moveZ * moveZ);
    _dodgeX = length > .05 ? moveX / length : math.sin(angle);
    _dodgeZ = length > .05 ? moveZ / length : math.cos(angle);
    dodgeTime = dodgeDuration;
    final stoneStep = hasSkill(BetaSkill.stoneStep) && protection > 0;
    invulnerable = math.max(invulnerable, stoneStep ? .42 : .3);
    if (stoneStep) protection = 0;
    dodgeCooldown = 1.6;
    swordTime = 0;
    _swordPending = false;
    _actionTarget = null;
    _clearBuffer();
    sounds.add(BetaSound.dodge);
    return true;
  }

  double get _aimAngle =>
      moveX.abs() + moveZ.abs() > .1 ? math.atan2(moveX, moveZ) : angle;

  BetaEnemy? _findTarget(double range, {bool melee = false}) {
    BetaEnemy? best;
    var bestScore = double.infinity;
    final heading = _aimAngle;
    for (final e in enemies.where((e) => e.alive)) {
      final d = distance(x, z, e.x, e.z);
      if (d > range + (melee ? e.radius : 0) || !clearLine(x, z, e.x, e.z)) {
        continue;
      }
      final alignment = d < .001
          ? 1.0
          : ((e.x - x) * math.sin(heading) + (e.z - z) * math.cos(heading)) / d;
      // Assist inside a forward cone, never an involuntary 180-degree turn.
      if (alignment < .25) continue;
      final score =
          (d <= swordReach + e.radius ? 0 : 20) + d + (1 - alignment) * 3;
      if (score < bestScore) {
        bestScore = score;
        best = e;
      }
    }
    return best;
  }

  void _aim(double range, {bool melee = false}) {
    _actionTarget = _findTarget(range, melee: melee);
    final target = _actionTarget;
    angle = target != null ? math.atan2(target.x - x, target.z - z) : _aimAngle;
  }

  static double distance(double ax, double az, double bx, double bz) =>
      math.sqrt((ax - bx) * (ax - bx) + (az - bz) * (az - bz));
  bool walkable(double px, double pz, double radius) =>
      px.abs() <= arenaX - radius &&
      pz.abs() <= arenaZ - radius &&
      obstacles.every((o) => distance(px, pz, o.x, o.z) >= radius + o.radius);
  bool clearLine(double ax, double az, double bx, double bz) {
    final dx = bx - ax, dz = bz - az, length = dx * dx + dz * dz;
    return obstacles.every((o) {
      final t = length == 0
          ? 0.0
          : (((o.x - ax) * dx + (o.z - az) * dz) / length).clamp(0.0, 1.0);
      return distance(ax + dx * t, az + dz * t, o.x, o.z) > o.radius + .1;
    });
  }

  /// First contact on a swept segment, including when it starts inside a body.
  static double? _circleContact(
    double ax,
    double az,
    double bx,
    double bz,
    double cx,
    double cz,
    double radius,
  ) {
    final dx = bx - ax, dz = bz - az, ox = ax - cx, oz = az - cz;
    final c = ox * ox + oz * oz - radius * radius;
    if (c <= 0) return 0;
    final a = dx * dx + dz * dz;
    if (a < .00000001) return null;
    final b = ox * dx + oz * dz, discriminant = b * b - a * c;
    if (discriminant < 0) return null;
    final t = (-b - math.sqrt(discriminant)) / a;
    return t >= 0 && t <= 1 ? t : null;
  }

  double _terrainContact(double ax, double az, double bx, double bz) {
    var first = double.infinity;
    for (final o in obstacles) {
      final t = _circleContact(
        ax,
        az,
        bx,
        bz,
        o.x,
        o.z,
        o.radius + projectileRadius,
      );
      if (t != null) first = math.min(first, t);
    }
    for (final axis in [(ax, bx, arenaX), (az, bz, arenaZ)]) {
      final limit = axis.$3 - projectileRadius;
      if (axis.$1.abs() >= limit) return 0;
      if (axis.$2.abs() > limit) {
        first = math.min(
          first,
          (axis.$2.sign * limit - axis.$1) / (axis.$2 - axis.$1),
        );
      }
    }
    return first;
  }

  void _move(double dx, double dz) {
    final nx = (x + dx).clamp(-arenaX + .35, arenaX - .35);
    final nz = (z + dz).clamp(-arenaZ + .35, arenaZ - .35);
    bool free(double px, double pz) =>
        walkable(px, pz, .35) &&
        (dodgeTime > 0 ||
            enemies.every(
              (e) =>
                  !e.alive ||
                  distance(px, pz, e.x, e.z) >=
                      math.min(.35 + e.radius, distance(x, z, e.x, e.z)) -
                          .000001,
            ));
    if (free(nx, z)) x = nx;
    if (free(x, nz)) z = nz;
  }

  static double _tick(double timer, double dt) => math.max(0, timer - dt);

  static double _rollDistance(double timeLeft) {
    final t = (1 - timeLeft / dodgeDuration).clamp(0.0, 1.0);
    return dodgeDistance *
        (t - .55 * math.sin(t * math.pi * 2) / (math.pi * 2));
  }

  /// Bounded substeps: resuming a suspended app never applies a huge time jump.
  void update(double elapsed) {
    if (!elapsed.isFinite ||
        elapsed <= 0 ||
        (!playing && phase != BetaPhase.won && phase != BetaPhase.lost)) {
      return;
    }
    var left = math.min(elapsed, .1);
    while (left > .000001) {
      final dt = math.min(left, 1 / 60);
      if (playing) {
        _step(dt);
      } else {
        // Finish the impact/death before showing results; no more rules or XP.
        _visualStep(dt);
        swordTime = _tick(swordTime, dt);
        castTime = _tick(castTime, dt);
        dodgeTime = _tick(dodgeTime, dt);
        resultTime = _tick(resultTime, dt);
      }
      left -= dt;
    }
  }

  void _visualStep(double dt) {
    hurtTime = _tick(hurtTime, dt);
    impactTime = _tick(impactTime, dt);
    for (final e in enemies) {
      e.flash = _tick(e.flash, dt);
      e.deathTime = _tick(e.deathTime, dt);
    }
    for (final fx in effects) {
      fx.life -= dt;
    }
    effects.removeWhere((fx) => fx.life <= 0);
    if (effects.length > 40) effects.removeRange(0, effects.length - 40);
  }

  void _step(double dt) {
    _visualStep(dt);
    if (arrivalTime > 0) {
      arrivalTime = _tick(arrivalTime, dt);
      return; // Fade in before AI or held input can affect the new region.
    }
    time += dt;
    _attuneCooldown = _tick(_attuneCooldown, dt);
    messageTime = _tick(messageTime, dt);
    swordCooldown = _tick(swordCooldown, dt);
    spellCooldown = _tick(spellCooldown, dt);
    dodgeCooldown = _tick(dodgeCooldown, dt);
    invulnerable = _tick(invulnerable, dt);
    protection = _tick(protection, dt);
    runicBladeTime = _tick(runicBladeTime, dt);
    blessingTime = _tick(blessingTime, dt);
    merlinTime = _tick(merlinTime, dt);
    wardTime = _tick(wardTime, dt);
    final burning = math.min(burnTime, dt);
    burnTime = _tick(burnTime, dt);
    curseTime = _tick(curseTime, dt);
    if (burning > 0) {
      hp = math.max(0, hp - burning * 2);
      if (hp == 0) {
        _finish(BetaPhase.lost);
        sounds.add(BetaSound.defeat);
        return;
      }
    }
    mana = math.min(100, mana + dt * (curseTime > 0 ? 4.5 : 9));
    // Integrate only the part of this step after the recovery delay expires.
    final recoveryTime = math.max(0.0, dt - _staminaWait);
    _staminaWait = _tick(_staminaWait, dt);
    if (swordTime <= 0 && dodgeTime <= 0) {
      stamina = math.min(maxStamina, stamina + recoveryTime * staminaRecovery);
    }
    final rolling = dodgeTime > 0;
    final speed = castTime > 0
        ? 1.1
        : swordTime > 0
        ? 2.0
        : 4.1;
    final oldX = x, oldZ = z;
    // Integrate a smooth travel curve, preserving range at every frame rate.
    final travel = rolling
        ? _rollDistance(math.max(0, dodgeTime - dt)) - _rollDistance(dodgeTime)
        : speed * (1 + loadout.agility / 100) * dt;
    _move(
      (rolling ? _dodgeX : moveX) * travel,
      (rolling ? _dodgeZ : moveZ) * travel,
    );
    final travelled = distance(oldX, oldZ, x, z);
    _moving = travelled > .00001;
    if (dodgeTime <= 0) stride += travelled * 3;
    if (moving && swordTime <= 0 && castTime <= 0 && dodgeTime <= 0) {
      angle = math.atan2(moveX, moveZ);
    }
    dodgeTime = _tick(dodgeTime, dt);
    swordTime = _tick(swordTime, dt);
    if (_swordPending && swordTime <= swordDuration - swordContact) {
      _swordPending = false;
      sounds.add(BetaSound.sword);
      final empowered = runicBladeTime > 0;
      final blessed = loadout.excalibur && blessingTime > 0;
      final swordElement = blessed ? blessingElement : element;
      _strikeElement = swordElement;
      _strikeCombo = blessed ? blessingCombo : null;
      blessingTime = 0; // Also consumed by a miss; no stored multiple charges.
      runicBladeTime =
          0; // A missed empowered swing consumes the opportunity too.
      var landed = false;
      for (final e in enemies.where((e) => e.alive)) {
        final dx = e.x - x, dz = e.z - z, d = distance(x, z, e.x, e.z);
        if (d <= swordReach + e.radius &&
            (d < .1 ||
                (dx * math.sin(angle) + dz * math.cos(angle)) / d > .4) &&
            clearLine(x, z, e.x, e.z)) {
          _hit(
            e,
            13 +
                (level - 1) * 2.0 +
                (empowered ? 8 : 0) +
                loadout.attackBonus +
                (blessed ? 3 : 0),
            swordElement,
          );
          landed = true;
        }
      }
      if (landed && hasSkill(BetaSkill.manaWeave)) {
        mana = math.min(100, mana + 6);
      }
      if (landed && empowered && hasSkill(BetaSkill.pursuit)) {
        dodgeCooldown = math.max(0, dodgeCooldown - .6);
      }
    }
    if (castTime > 0) {
      castTime = _tick(castTime, dt);
      if (castTime == 0) {
        if (loadout.excalibur) {
          blessingTime = 5;
          merlinTime = 1.25;
          blessingElement = _castElement;
          blessingCombo = _castCombo;
          effects.add(BetaEffect(x, z, _castElement, text: 'MERLIN · +3'));
        }
        projectiles.add(
          BetaProjectile(
            x,
            z,
            math.sin(angle),
            math.cos(angle),
            _castElement,
            combo: _castCombo,
          ),
        );
        if (_castCombo == null && _castElement == BetaElement.earth) {
          protection = 2;
        }
      }
    }
    _consumeInput(dt);
    for (final p in projectiles) {
      final nx = p.x + p.dx * dt * 12, nz = p.z + p.dz * dt * 12;
      p.life -= dt;
      if (p.life <= 0) continue;
      var contact = _terrainContact(p.x, p.z, nx, nz);
      BetaEnemy? victim;
      for (final e in enemies.where((e) => e.alive)) {
        final t = _circleContact(p.x, p.z, nx, nz, e.x, e.z, e.radius + .35);
        // Strict comparison makes terrain win a tie, regardless of list order.
        if (t != null && t < contact) {
          contact = t;
          victim = e;
        }
      }
      final travel = math.min(1.0, contact);
      p.x += (nx - p.x) * travel;
      p.z += (nz - p.z) * travel;
      if (contact > 1) continue;
      p.life = 0;
      if (victim case final e?) {
        if (p.combo != null) {
          _resolveCombo(p, e);
          continue;
        }
        final damage = switch (p.element) {
          BetaElement.fire => 27.0,
          BetaElement.water => 18.0,
          BetaElement.wind => 16.0,
          BetaElement.earth => 23.0,
        };
        _hit(
          e,
          damage + (level - 1) * 3,
          p.element,
          spell: true,
          hitX: p.x,
          hitZ: p.z,
        );
        if (p.element == BetaElement.fire && e.alive) e.burn = 3;
        if (p.element == BetaElement.water) {
          e.slow = 2.5;
          final healed = math.min(8.0, maxHp - hp);
          hp = math.min(maxHp, hp + 8);
          if (healed > 0) {
            effects.add(
              BetaEffect(
                x,
                z,
                p.element,
                text: '+${healed.ceil()}',
                kind: BetaEffectKind.heal,
              ),
            );
          }
        }
        if (p.element == BetaElement.wind) {
          for (final target in enemies.where((e) => e.alive)) {
            if (distance(p.x, p.z, target.x, target.z) < 2 &&
                clearLine(p.x, p.z, target.x, target.z)) {
              if (!identical(target, e)) {
                _hit(target, 10, p.element);
              }
              if (!target.alive) continue;
              target.cancelAttack();
              target.cooldown = .8;
              target.pushTime = .2;
              target.pushX = p.dx * 6;
              target.pushZ = p.dz * 6;
            }
          }
        }
      } else {
        effects.add(
          BetaEffect(
            p.x,
            p.z,
            p.element,
            kind: BetaEffectKind.blocked,
            combo: p.combo,
          ),
        );
      }
    }
    projectiles.removeWhere((p) => p.life <= 0);
    for (final e in enemies.where((e) => e.alive)) {
      if (!playing) break;
      e.slow = _tick(e.slow, dt);
      if (e.burn > 0) {
        e.burn = _tick(e.burn, dt);
        e.hp = math.max(0, e.hp - 3 * dt);
        if (!e.alive) {
          _kill(e);
          continue;
        }
      }
      e.moving = false;
      if (e.pushTime > 0) {
        final step = math.min(dt, e.pushTime);
        _moveEnemy(e, e.pushX * step, e.pushZ * step);
        e.pushTime = _tick(e.pushTime, dt);
        continue;
      }
      e.cooldown = _tick(e.cooldown, dt);
      if (e.recovery > 0) {
        e.recovery = _tick(e.recovery, dt);
        continue;
      }
      if (e.windup > 0) {
        final before = e.windup;
        e.windup = _tick(e.windup, dt);
        if (before > e.strikeDuration && e.windup <= e.strikeDuration) {
          sounds.add(BetaSound.enemySwing);
        }
        if (e.windup == 0) {
          e.cooldown = e.kind.cooldown;
          e.recovery = e.recoveryDuration;
          final area = e.attackArea;
          effects.add(
            BetaEffect(
              e.aimX,
              e.aimZ,
              BetaElement.earth,
              hurt: true,
              area: area,
            ),
          );
          if (e.boss) sounds.add(BetaSound.heavyImpact);
          if (area.contains(x, z) && clearLine(e.x, e.z, x, z)) {
            _hurt(e.kind.damage, source: e.kind);
          }
        }
        continue;
      }
      final dx = x - e.x, dz = z - e.z, d = distance(x, z, e.x, e.z);
      e.angle = math.atan2(dx, dz);
      if (d < e.kind.approach && e.cooldown == 0 && clearLine(e.x, e.z, x, z)) {
        e.beginAttack(x, z);
      } else if (d > .95) {
        final speed = e.kind.speed * (e.slow > 0 ? .45 : 1);
        var headingX = dx / d, headingZ = dz / d;
        if (e.detour <= 0 &&
            !walkable(
              e.x + headingX * speed * dt,
              e.z + headingZ * speed * dt,
              e.radius,
            )) {
          // Briefly commit to a side instead of oscillating against a column.
          for (final side in [1.0, -1.0]) {
            final sx = -headingZ * side, sz = headingX * side;
            if (walkable(e.x + sx * .3, e.z + sz * .3, e.radius)) {
              e.steerX = sx;
              e.steerZ = sz;
              e.detour = 1.1;
              break;
            }
          }
        }
        if (e.detour > 0) {
          e.detour = _tick(e.detour, dt);
          headingX = e.steerX;
          headingZ = e.steerZ;
        }
        final oldX = e.x, oldZ = e.z;
        _moveEnemy(e, headingX * speed * dt, headingZ * speed * dt);
        final travelled = distance(oldX, oldZ, e.x, e.z);
        e.moving = travelled > .00001;
        e.stride += travelled * 4;
      }
    }
    if (!playing) return;
    if (remaining == 0 && puzzle.solved) {
      if (_waveWait < 2) {
        _waveWait = math.min(2, _waveWait + dt);
        if (_waveWait == 2) sounds.add(BetaSound.passage);
      }
      final nearGate =
          distance(x, z, BetaRegion.gateX, BetaRegion.gateZ) <=
          BetaRegion.gateRadius;
      if (passageOpen &&
          nearGate &&
          swordTime <= 0 &&
          castTime <= 0 &&
          dodgeTime <= 0) {
        _gateHold += dt;
        if (_gateHold >= gateHoldDuration) _travel();
      } else {
        _gateHold = 0;
      }
    }
    if (_checkpointAfterCombat && playing) {
      _checkpointAfterCombat = !_checkpoint();
    }
  }

  void _resolveCombo(BetaProjectile projectile, BetaEnemy primary) {
    final combo = projectile.combo!;
    final damage = combo.damage + (level - 1) * 3;
    final targets = [
      primary,
      if (combo.radius > 0)
        ...enemies.where(
          (enemy) =>
              enemy.alive &&
              !identical(enemy, primary) &&
              distance(projectile.x, projectile.z, enemy.x, enemy.z) <=
                  combo.radius &&
              clearLine(projectile.x, projectile.z, enemy.x, enemy.z),
        ),
    ];
    for (final target in targets) {
      final first = identical(target, primary);
      _hit(
        target,
        damage * (first ? 1 : .6),
        combo.first,
        spell: true,
        combo: first ? combo : null,
        hitX: first ? projectile.x : target.x,
        hitZ: first ? projectile.z : target.z,
      );
      if (!target.alive) continue;
      target.burn = math.max(target.burn, combo.burn);
      target.slow = math.max(target.slow, combo.slow);
      if (combo.stagger > 0 || combo.push > 0) {
        target.cancelAttack();
        target.cooldown = math.max(
          target.cooldown,
          combo.stagger > 0 ? (target.boss ? .25 : combo.stagger) : .6,
        );
      }
      if (combo.push > 0) {
        target.pushTime = .2;
        target.pushX = projectile.dx * combo.push;
        target.pushZ = projectile.dz * combo.push;
      }
    }
    if (combo.heal > 0) {
      final healed = math.min(combo.heal, maxHp - hp);
      hp += healed;
      if (healed > 0) {
        effects.add(
          BetaEffect(
            x,
            z,
            BetaElement.water,
            text: '+${healed.ceil()}',
            kind: BetaEffectKind.heal,
          ),
        );
      }
    }
    protection = math.max(
      protection,
      math.max(combo.ward, hasSkill(BetaSkill.ward) ? 1 : 0),
    );
    if (hasSkill(BetaSkill.runicBlade)) runicBladeTime = 4;
    if (hasSkill(BetaSkill.flow)) mana = math.min(100, mana + 8);
    if (_discoveredCombos.add(combo)) {
      final equipped = _equippedCombos.length < 3;
      if (equipped) _equippedCombos.add(combo);
      message =
          'DESCOBERTO: ${combo.label} · ${equipped ? 'equipado' : 'troque um slot após limpar a área'}';
      messageTime = 4;
      sounds.add(BetaSound.discovery);
    }
  }

  void _travel() {
    if (finalArea) {
      _gateHold = 0;
      _finish(BetaPhase.won);
      sounds.add(BetaSound.victory);
      return; // No seventh region, healing reward or additional XP.
    }
    wave++;
    _waveWait = _gateHold = 0;
    _attuneCooldown = 0;
    x = BetaRegion.entryX;
    z = BetaRegion.entryZ;
    angle = math.pi;
    setMovement(0, 0);
    _moving = _swordPending = false;
    _actionTarget = null;
    _clearBuffer();
    swordTime = castTime = dodgeTime = 0;
    swordCooldown = spellCooldown = dodgeCooldown = 0;
    hurtTime = impactTime = protection = invulnerable = 0;
    runicBladeTime = 0;
    blessingTime = merlinTime = burnTime = curseTime = wardTime = 0;
    effects.clear();
    hp = math.min(maxHp, hp + 20);
    mana = math.min(100, mana + 25);
    arrivalTime = arrivalDuration;
    _spawn();
    _checkpoint();
  }

  void _moveEnemy(BetaEnemy e, double dx, double dz) {
    bool separating(
      double px,
      double pz,
      double ox,
      double oz,
      double radius,
    ) =>
        distance(px, pz, ox, oz) >=
        math.min(radius, distance(e.x, e.z, ox, oz)) - .000001;
    bool free(double px, double pz) =>
        walkable(px, pz, e.radius) &&
        separating(px, pz, x, z, e.radius + .35) &&
        enemies.every(
          (other) =>
              identical(e, other) ||
              !other.alive ||
              separating(px, pz, other.x, other.z, e.radius + other.radius),
        );
    if (free(e.x + dx, e.z)) e.x += dx;
    if (free(e.x, e.z + dz)) e.z += dz;
  }

  void _finish(BetaPhase result) {
    blessingTime = merlinTime = burnTime = curseTime = wardTime = 0;
    phase = result;
    resultTime = .7;
    setMovement(0, 0);
    _clearBuffer();
    _moving = false;
    _swordPending = false;
    if (result == BetaPhase.lost) swordTime = castTime = dodgeTime = 0;
    projectiles.clear();
    if (result == BetaPhase.won) _checkpoint();
  }

  void _hit(
    BetaEnemy e,
    double damage,
    BetaElement source, {
    bool spell = false,
    double? hitX,
    double? hitZ,
    BetaCombo? combo,
  }) {
    if (!e.alive) return;
    e.hp = math.max(0, e.hp - damage);
    e.flash = .22;
    impactTime = .14;
    effects.add(
      BetaEffect(
        hitX ?? e.x,
        hitZ ?? e.z,
        source,
        text: '${damage.round()}',
        kind: spell ? BetaEffectKind.spell : BetaEffectKind.impact,
        combo: combo,
      ),
    );
    sounds.add(
      spell
          ? switch (source) {
              BetaElement.fire => BetaSound.fireImpact,
              BetaElement.water => BetaSound.waterImpact,
              BetaElement.wind => BetaSound.windImpact,
              BetaElement.earth => BetaSound.earthImpact,
            }
          : BetaSound.impact,
    );
    if (!e.alive) _kill(e);
  }

  void _kill(BetaEnemy e) {
    if (e._rewarded) return;
    e._rewarded = true;
    e.deathTime = deathDuration;
    e.cancelAttack();
    e.moving = false;
    kills++;
    if (remaining == 0) _checkpointAfterCombat = true;
    xp += e.kind.reward;
    while (xp >= nextLevelXp) {
      level++;
      _skillPoints++;
      hp = math.min(maxHp, hp + 20);
      message = 'NÍVEL $level · +1 ponto de habilidade · aprenda entre áreas';
      messageTime = 3;
      sounds.add(BetaSound.level);
    }
  }

  void _hurt(double amount, {BetaEnemyKind? source}) {
    if (!playing || invulnerable > 0) return;
    if (source == BetaEnemyKind.guardian || source == BetaEnemyKind.darkElf) {
      if (loadout.perseus) {
        wardTime = .7;
        sounds.add(BetaSound.ward);
        effects.add(
          BetaEffect(
            x,
            z,
            BetaElement.earth,
            text: source == BetaEnemyKind.guardian
                ? 'QUEIMADURA NEGADA'
                : 'MALDIÇÃO NEGADA',
          ),
        );
      } else if (source == BetaEnemyKind.guardian) {
        burnTime = 3; // Six extra HP total; refreshing never stacks intensity.
        effects.add(
          BetaEffect(x, z, BetaElement.fire, text: 'QUEIMADURA · 3s'),
        );
      } else {
        curseTime = 4; // Half mana regeneration, not an input/control lock.
        effects.add(BetaEffect(x, z, BetaElement.wind, text: 'MALDIÇÃO · 4s'));
      }
    }
    final damage = protection > 0 ? amount * .5 : amount;
    hp = math.max(0, hp - damage);
    invulnerable = .5;
    hurtTime = .28;
    impactTime = .18;
    effects.add(
      BetaEffect(x, z, element, text: '-${damage.round()}', hurt: true),
    );
    sounds.add(BetaSound.hurt);
    if (hp == 0) {
      _finish(BetaPhase.lost);
      sounds.add(BetaSound.defeat);
    }
  }

  void _spawn() {
    enemies.clear();
    projectiles.clear();
    final kinds = switch (wave) {
      1 => [BetaEnemyKind.goblin, BetaEnemyKind.goblin, BetaEnemyKind.goblin],
      2 => [BetaEnemyKind.goblin, BetaEnemyKind.brute, BetaEnemyKind.darkElf],
      4 => [BetaEnemyKind.darkElf, BetaEnemyKind.brute, BetaEnemyKind.darkElf],
      5 => [BetaEnemyKind.brute, BetaEnemyKind.guardian, BetaEnemyKind.darkElf],
      6 => [BetaEnemyKind.darkElf, BetaEnemyKind.guardian, BetaEnemyKind.brute],
      _ => [
        BetaEnemyKind.darkElf,
        BetaEnemyKind.guardian,
        BetaEnemyKind.goblin,
      ],
    };
    for (var i = 0; i < kinds.length; i++) {
      // Spawn at the far end from the hero; never on a column or on the player.
      enemies.add(BetaEnemy(kinds[i], (i - 1) * 3.0, z >= 0 ? -7 : 7));
    }
    final hint = switch (wave) {
      1 => 'GOBLINS · desvie para o lado da estocada',
      2 ||
      4 => 'OGRO E ELFO · desvie dos cortes; maldição reduz regeneração de MP',
      _ => 'GUARDIÃO · saia do círculo; impactos causam queimadura',
    };
    message = '${region.title.toUpperCase()}\n$hint';
    messageTime = 4;
  }
}
