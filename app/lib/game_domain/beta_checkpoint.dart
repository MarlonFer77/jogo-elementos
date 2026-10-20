part of 'beta_session.dart';

/// Immutable, versioned safe-point. Animation/input/projectiles are not saves.
class BetaCheckpoint {
  BetaCheckpoint._(this.encoded);
  final String encoded;
  Map<String, dynamic> get _data => jsonDecode(encoded) as Map<String, dynamic>;
  int get wave => _data['wave'] as int;
  int get level => _data['level'] as int;
  bool get completed => _data['won'] == true;
  bool get cleared => _data['cleared'] == true;
  BetaRegion get region => BetaRegion.values[wave - 1];

  factory BetaCheckpoint._capture(BetaSession run) => BetaCheckpoint._(
    jsonEncode({
      'version': 1,
      'wave': run.wave,
      'level': run.level,
      'xp': run.xp,
      'kills': run.kills,
      'started': run.phase != BetaPhase.ready,
      'cleared': run.phase != BetaPhase.ready && run.remaining == 0,
      'won': run.phase == BetaPhase.won,
      'hp': run.hp,
      'mana': run.mana,
      'x': run.x,
      'z': run.z,
      'angle': run.angle,
      'time': run.time,
      'element': run.element.name,
      'secondary': run.secondaryElement?.name,
      'points': run.skillPoints,
      'skills': run._skills.map((e) => e.name).toList(),
      'discovered': run._discoveredCombos.map((e) => e.name).toList(),
      'equipped': run._equippedCombos.map((e) => e.name).toList(),
      'puzzles': [
        for (final p in run._puzzles)
          {'steps': p.completed, 'hint': p.revealedHint != null},
      ],
      'burn': run.burnTime,
      'curse': run.curseTime,
      'protection': run.protection,
      'runic': run.runicBladeTime,
      'blessing': run.blessingTime,
      'blessingElement': run.blessingElement.name,
      'blessingCombo': run.blessingCombo?.name,
      'swordCooldown': run.swordCooldown,
      'spellCooldown': run.spellCooldown,
      'dodgeCooldown': run.dodgeCooldown,
    }),
  );

  factory BetaCheckpoint.decode(String encoded) {
    if (encoded.length > 16000) throw const FormatException('Save excessivo.');
    final checkpoint = BetaCheckpoint._(encoded);
    checkpoint.restore(); // Validate every field before accepting a save.
    return checkpoint;
  }

  BetaSession restore({BetaLoadout loadout = const BetaLoadout()}) {
    final data = _data;
    void require(bool valid) {
      if (!valid) throw const FormatException('Checkpoint inválido.');
    }

    int integer(String key, int min, int max) {
      final value = data[key];
      require(value is int && value >= min && value <= max);
      return value as int;
    }

    double number(String key, double min, double max) {
      final value = data[key];
      require(value is num && value.isFinite && value >= min && value <= max);
      return (value as num).toDouble();
    }

    bool flag(String key) {
      require(data[key] is bool);
      return data[key] as bool;
    }

    T named<T extends Enum>(List<T> values, Object? name) {
      for (final value in values) {
        if (value.name == name) return value;
      }
      throw const FormatException('Conteúdo desconhecido no save.');
    }

    List<T> names<T extends Enum>(String key, List<T> values, int max) {
      final raw = data[key];
      require(raw is List && raw.length <= max);
      final result = (raw as List).map((name) => named(values, name)).toList();
      require(result.toSet().length == result.length);
      return result;
    }

    if (data['version'] is int && (data['version'] as int) > 1) {
      throw StateError(
        'Checkpoint de versão mais recente. Atualize o aplicativo.',
      );
    }
    require(data['version'] == 1);
    final run = BetaSession(loadout: loadout);
    run.wave = integer('wave', 1, BetaRegion.values.length);
    run.level = integer('level', 1, 100);
    run.xp = integer('xp', 0, 100000);
    run.kills = integer('kills', 0, 18);
    // XP is cumulative in the engine; level thresholds must agree with it.
    var expectedLevel = 1;
    while (run.xp >= 60 + (expectedLevel - 1) * 80) {
      expectedLevel++;
    }
    require(run.level == expectedLevel);
    run._skillPoints = integer('points', 0, run.level);
    run._skills.addAll(
      names('skills', BetaSkill.values, BetaSkill.values.length),
    );
    require(run.skillPoints + run._skills.length == run.level);
    for (final skill in run._skills) {
      require(
        run.level >= skill.level &&
            (skill.prerequisite == null || run.hasSkill(skill.prerequisite!)),
      );
    }
    run._discoveredCombos.addAll(
      names('discovered', BetaCombo.values, BetaCombo.values.length),
    );
    run._equippedCombos.addAll(names('equipped', BetaCombo.values, 3));
    require(run._discoveredCombos.containsAll(run._equippedCombos));
    final started = flag('started'),
        cleared = flag('cleared'),
        won = flag('won');
    require(started || (!cleared && !won && run.wave == 1));
    final puzzles = data['puzzles'];
    require(puzzles is List && puzzles.length == run._puzzles.length);
    for (var i = 0; i < run._puzzles.length; i++) {
      final progress = run._puzzles[i], saved = (puzzles as List)[i];
      require(saved is Map && saved['steps'] is int && saved['hint'] is bool);
      final steps = saved['steps'] as int;
      require(steps >= 0 && steps <= progress.puzzle.steps.length);
      require(i >= run.wave - 1 || steps == progress.puzzle.steps.length);
      require(i <= run.wave - 1 || steps == 0);
      require(i != run.wave - 1 || cleared || steps == 0);
      for (var j = 0; j < steps; j++) {
        final step = progress.next!;
        progress.offer(step.altar, step.first, step.second);
      }
      if (saved['hint'] == true) progress.revealHint();
    }
    require(!won || (cleared && run.finalArea && run.puzzle.solved));
    run.hp = number('hp', .000001, run.maxHp);
    run.mana = number('mana', 0, 100);
    run.time = number('time', 0, 1e9);
    run.x = number('x', -BetaSession.arenaX, BetaSession.arenaX);
    run.z = number('z', -BetaSession.arenaZ, BetaSession.arenaZ);
    require(run.walkable(run.x, run.z, .35));
    run.angle = number('angle', -math.pi * 2, math.pi * 2);
    run.element = named(BetaElement.values, data['element']);
    run.secondaryElement = data['secondary'] == null
        ? null
        : named(BetaElement.values, data['secondary']);
    require(run.secondaryElement != run.element);
    run.burnTime = number('burn', 0, 3);
    require(run.hp > run.burnTime * 2);
    run.curseTime = number('curse', 0, 4);
    run.protection = number('protection', 0, 10);
    run.runicBladeTime = number('runic', 0, 4);
    run.blessingTime = number('blessing', 0, 5);
    run.blessingElement = named(BetaElement.values, data['blessingElement']);
    run.blessingCombo = data['blessingCombo'] == null
        ? null
        : named(BetaCombo.values, data['blessingCombo']);
    run.swordCooldown = number('swordCooldown', 0, 10);
    run.spellCooldown = number('spellCooldown', 0, 10);
    run.dodgeCooldown = number('dodgeCooldown', 0, 10);
    if (started && !cleared) run._spawn();
    run.phase = won
        ? BetaPhase.won
        : started
        ? BetaPhase.paused
        : BetaPhase.ready;
    // Never inherit held inputs, in-flight attacks or an automatic portal exit.
    run._waveWait = run.puzzle.solved ? 2 : 0;
    run.latestCheckpoint = this;
    run.message = 'AVENTURA RECUPERADA · ${run.region.title}';
    run.messageTime = 5;
    return run;
  }
}
