import 'package:app/game_domain/effect_badge_view.dart';
import 'package:app/game_domain/training_match.dart';
import 'package:battle_engine/battle_engine.dart';
import 'package:flutter_test/flutter_test.dart';

SkillProgress _allElementsUnlocked() => SkillProgress(
      defaultSkillTree,
      unlockedNodeIds: ElementUnlocks.all.map((u) => u.id).toList(),
    );

void main() {
  test('starts with Jogador A to act and nothing discovered', () {
    final match = TrainingMatch();

    expect(match.currentTurnName, equals('Jogador A'));
    expect(match.discoveredCount, equals(0));
    expect(match.totalCombinationsCount, greaterThan(0));
    expect(match.activeFieldEffectNames, isEmpty);
    expect(match.lastTriggeredCombinationName, isNull);
  });

  test('playing fire+wind triggers Tempestade Ígnea and passes the turn',
      () {
    final match = TrainingMatch(
      initialApA: const ApPool(max: 5, current: 3),
      initialProgressA: _allElementsUnlocked(),
    );

    match.playElementIds(['fire', 'wind']);

    expect(match.currentTurnName, equals('Jogador B'));
    expect(match.lastTriggeredCombinationName, equals('Tempestade Ígnea'));
    expect(match.activeFieldEffectNames, equals(['Tempestade Ígnea']));
    expect(match.discoveredCount, equals(1));
  });

  test('discovering the same combination twice does not double-count', () {
    final match = TrainingMatch(
      initialApA: const ApPool(max: 5, current: 3),
      initialApB: const ApPool(max: 5, current: 3),
      initialProgressA: _allElementsUnlocked(),
      initialProgressB: _allElementsUnlocked(),
    );

    match.playElementIds(['fire', 'wind']); // Jogador A
    match.playElementIds(['fire', 'wind']); // Jogador B, same combo

    expect(match.discoveredCount, equals(1));
  });

  test('an unknown combination does not add a field effect but still '
      'passes the turn', () {
    final match = TrainingMatch(
      initialApA: const ApPool(max: 5, current: 3),
      initialProgressA: _allElementsUnlocked(),
    );

    match.playElementIds(['ice', 'shadow']);

    expect(match.lastTriggeredCombinationName, isNull);
    expect(match.activeFieldEffectNames, isEmpty);
    expect(match.currentTurnName, equals('Jogador B'));
  });

  test('throws for an unknown element id', () {
    final match = TrainingMatch();
    expect(() => match.playElementIds(['ghost']), throwsArgumentError);
  });

  group('skill tree integration', () {
    test('unlocking a node adds it to the current player\'s granted list',
        () {
      final match = TrainingMatch();
      match.unlockSkillForCurrentPlayer('ember_mastery');

      expect(
        match.unlockedGrantNamesForCurrentPlayer,
        contains('Combustão'),
      );
    });

    test('unlocking a node makes its dependents available', () {
      final match = TrainingMatch();
      expect(
        match.availableSkillNodesForCurrentPlayer
            .map((n) => n.id),
        isNot(contains('wildfire_path')),
      );

      match.unlockSkillForCurrentPlayer('ember_mastery');

      expect(
        match.availableSkillNodesForCurrentPlayer.map((n) => n.id),
        contains('wildfire_path'),
      );
    });

    test('throws when trying to unlock a node whose prerequisite is '
        'missing', () {
      final match = TrainingMatch();
      expect(
        () => match.unlockSkillForCurrentPlayer('wildfire_path'),
        throwsStateError,
      );
    });

    test('a mutation unlocked by Jogador A applies to every action they '
        'take, hitting the opponent', () {
      final match = TrainingMatch(initialProgressA: _allElementsUnlocked());
      match.unlockSkillForCurrentPlayer('ember_mastery'); // Jogador A

      match.playElementIds(['fire']);

      expect(match.lastAppliedStatusNames, contains('Queimadura'));
      expect(match.playerBStatusNames, contains('Queimadura'));
      expect(match.playerAStatusNames, isEmpty);
    });

    test('each player\'s unlocked skills are independent', () {
      final match = TrainingMatch(initialProgressA: _allElementsUnlocked());
      match.unlockSkillForCurrentPlayer('ember_mastery'); // Jogador A
      expect(match.unlockedGrantNamesForCurrentPlayer, contains('Combustão'));

      match.playElementIds(['fire']); // turn passes to Jogador B

      // Jogador B hasn't unlocked anything yet.
      expect(match.unlockedGrantNamesForCurrentPlayer, isEmpty);
    });

    test('unlockedNodeIdsForCurrentPlayer reflects what the current player has unlocked', () {
      final match = TrainingMatch();

      expect(match.unlockedNodeIdsForCurrentPlayer, isEmpty);

      match.unlockSkillForCurrentPlayer('ember_mastery');

      expect(match.unlockedNodeIdsForCurrentPlayer, ['ember_mastery']);
    });
  });

  group('HP and victory', () {
    test('both players start at 100/100 HP', () {
      final match = TrainingMatch();
      expect(match.playerAMaxHp, equals(100));
      expect(match.playerACurrentHp, equals(100));
      expect(match.playerBMaxHp, equals(100));
      expect(match.playerBCurrentHp, equals(100));
    });

    test('a triggered combination reduces the opponent\'s current HP', () {
      final match = TrainingMatch(
        initialApA: const ApPool(max: 5, current: 3),
        initialProgressA: _allElementsUnlocked(),
      );
      match.playElementIds(['fire', 'wind']); // Jogador A, 20 damage
      expect(match.playerBCurrentHp, equals(80));
    });

    test('is not over and has no winner while both are alive', () {
      final match = TrainingMatch();
      expect(match.isOver, isFalse);
      expect(match.winnerName, isNull);
    });

    test('ends the match and names the winner once someone reaches 0 HP',
        () {
      final match = TrainingMatch(
        initialProgressA: _allElementsUnlocked(),
        initialProgressB: _allElementsUnlocked(),
      );
      // 5 basic damage per hit (single element, always free) — 20 hits
      // defeat 100 HP. Jogador A acts first each round, so their 20th
      // hit lands before Jogador B's 20th.
      for (var i = 0; i < 19; i++) {
        match.playElementIds(['fire']); // Jogador A
        match.playElementIds(['ice']); // Jogador B
      }
      match.playElementIds(['fire']); // Jogador A's 20th hit defeats Jogador B

      expect(match.isOver, isTrue);
      expect(match.winnerName, equals('Jogador A'));
      expect(match.playerBCurrentHp, equals(0));
    });

    test('unlocking Treino de Vitalidade raises current player\'s max and '
        'current HP by 20 immediately', () {
      final match = TrainingMatch();
      match.unlockSkillForCurrentPlayer('vitality_training'); // Jogador A

      expect(match.playerAMaxHp, equals(120));
      expect(match.playerACurrentHp, equals(120));
      expect(match.playerBMaxHp, equals(100));
    });

    test('a Vitalidade bonus unlocked mid-match does not affect prior '
        'damage taken', () {
      final match = TrainingMatch(
        initialApA: const ApPool(max: 5, current: 3),
        initialProgressA: _allElementsUnlocked(),
      );
      match.playElementIds(['fire', 'wind']); // Jogador A hits B for 20
      // Now it's Jogador B's turn; they unlock Vitalidade for themselves.
      match.unlockSkillForCurrentPlayer('vitality_training');

      expect(match.playerBMaxHp, equals(120));
      expect(match.playerBCurrentHp, equals(100)); // 80 + 20, not 120
    });
  });

  test('isPlayerATurn reflects whose turn it currently is', () {
    final match = TrainingMatch(
      initialProgressA: _allElementsUnlocked(),
      initialProgressB: _allElementsUnlocked(),
    );
    expect(match.isPlayerATurn, isTrue);

    match.playElementIds(['fire']);
    expect(match.isPlayerATurn, isFalse);

    match.playElementIds(['ice']);
    expect(match.isPlayerATurn, isTrue);
  });

  test('turnsPlayed counts successful plays regardless of damage', () {
    final match = TrainingMatch(
      initialProgressA: _allElementsUnlocked(),
      initialProgressB: _allElementsUnlocked(),
    );
    expect(match.turnsPlayed, 0);

    match.playElementIds(['fire']); // sem dano, ainda conta
    expect(match.turnsPlayed, 1);

    match.playElementIds(['wind']);
    expect(match.turnsPlayed, 2);
  });

  test('activeFieldEffectBadges resolves id and remainingTurns from a '
      'triggered combination', () {
    final match = TrainingMatch(
      initialApA: const ApPool(max: 5, current: 3),
      initialProgressA: _allElementsUnlocked(),
    );
    match.playElementIds(['fire', 'wind']); // Tempestade Ígnea

    expect(
      match.activeFieldEffectBadges,
      [const EffectBadgeView(id: 'ignited_storm', remainingTurns: null)],
    );
  });

  test('playerAActiveStatuses/playerBActiveStatuses resolve id and '
      'remainingTurns from an applied mutation status', () {
    final match = TrainingMatch(initialProgressA: _allElementsUnlocked());
    match.unlockSkillForCurrentPlayer('ember_mastery'); // Jogador A

    match.playElementIds(['fire']); // aplica Queimadura em Jogador B

    expect(match.playerAActiveStatuses, isEmpty);
    expect(
      match.playerBActiveStatuses,
      [const EffectBadgeView(id: 'burn', remainingTurns: 2)],
    );
  });

  test('a player seeded with Treino de Vitalidade already unlocked starts '
      'with 120 HP, not 100', () {
    final match = TrainingMatch(
      initialProgressA: SkillProgress(defaultSkillTree, unlockedNodeIds: ['vitality_training']),
    );

    expect(match.playerAMaxHp, equals(120));
    expect(match.playerACurrentHp, equals(120));
    expect(match.playerBMaxHp, equals(100));
  });

  test('a player seeded with Maestria da Brasa already unlocked applies '
      'Queimadura on the first action, no need to unlock again', () {
    final match = TrainingMatch(
      initialProgressA: SkillProgress(
        defaultSkillTree,
        unlockedNodeIds: ['ember_mastery', 'unlock_fire'],
      ),
    );

    match.playElementIds(['fire']);

    expect(match.lastAppliedStatusNames, contains('Queimadura'));
  });

  test('unlockedNodeIdsForPlayerA/B and discoveredCombinationIds reflect '
      'real state', () {
    final match = TrainingMatch(
      initialApA: const ApPool(max: 5, current: 3),
      initialProgressA: SkillProgress(
        defaultSkillTree,
        unlockedNodeIds: ['unlock_fire', 'unlock_wind'],
      ),
    );
    match.unlockSkillForCurrentPlayer('ember_mastery'); // Jogador A
    match.playElementIds(['fire', 'wind']); // Jogador A, Tempestade Ígnea

    expect(
      match.unlockedNodeIdsForPlayerA,
      ['unlock_fire', 'unlock_wind', 'ember_mastery'],
    );
    expect(match.unlockedNodeIdsForPlayerB, isEmpty);
    expect(match.discoveredCombinationIds, ['ignited_storm']);
  });

  group('fromPersistedProgress', () {
    test('seeds both players\' Skill Tree and the shared Discovery Book '
        'from raw ids', () {
      final match = TrainingMatch.fromPersistedProgress(
        unlockedNodeIdsA: ['ember_mastery'],
        unlockedNodeIdsB: ['vitality_training'],
        discoveredCombinationIds: ['ignited_storm'],
        turnsPlayedA: 0,
        turnsPlayedB: 0,
      );

      expect(match.unlockedNodeIdsForPlayerA, ['ember_mastery']);
      expect(match.unlockedNodeIdsForPlayerB, ['vitality_training']);
      expect(match.discoveredCombinationIds, ['ignited_storm']);
      expect(match.playerBMaxHp, equals(120)); // Vitalidade já aplicada
    });

    test('seeds the cumulative turns-played counters', () {
      final match = TrainingMatch.fromPersistedProgress(
        unlockedNodeIdsA: [],
        unlockedNodeIdsB: [],
        discoveredCombinationIds: [],
        turnsPlayedA: 7,
        turnsPlayedB: 12,
      );

      expect(match.cumulativeTurnsPlayedA, equals(7));
      expect(match.cumulativeTurnsPlayedB, equals(12));
    });
  });

  group('startNewBattleKeepingProgress', () {
    test('resets HP/turn/campo but keeps Skill Tree and Discovery Book', () {
      final match = TrainingMatch(
        initialApA: const ApPool(max: 5, current: 3),
        initialProgressA: _allElementsUnlocked(),
      );
      match.unlockSkillForCurrentPlayer('vitality_training'); // Jogador A
      match.playElementIds(['fire', 'wind']); // Jogador A, descobre Tempestade Ígnea

      final rematch = match.startNewBattleKeepingProgress();

      expect(rematch.playerAMaxHp, equals(120)); // Vitalidade mantida
      expect(rematch.playerACurrentHp, equals(120)); // batalha nova, HP cheio
      expect(rematch.currentTurnName, equals('Jogador A')); // turno resetado
      expect(rematch.activeFieldEffectNames, isEmpty); // campo resetado
      expect(rematch.discoveredCombinationIds, ['ignited_storm']); // mantido
    });

    test('keeps the cumulative turns-played counter (does not reset)', () {
      final match = TrainingMatch(initialProgressA: _allElementsUnlocked());
      match.playElementIds(['fire']); // Jogador A, 1 turno cumulativo

      final rematch = match.startNewBattleKeepingProgress();

      expect(rematch.cumulativeTurnsPlayedA, equals(1));
    });
  });

  test('playerAAp/playerAApMax/playerBAp/playerBApMax reflect real state',
      () {
    final match = TrainingMatch(initialProgressA: _allElementsUnlocked());
    expect(match.playerAAp, 0);
    expect(match.playerAApMax, 5);

    match.playElementIds(['fire']); // Jogador A regenera 1 AP no próprio turno

    expect(match.playerAAp, 1);
    expect(match.playerBAp, 0);
  });

  group('locked elements (Bloco 2b)', () {
    test('availableElementIdsForCurrentPlayer reflects granted elements', () {
      final match = TrainingMatch(
        initialProgressA: SkillProgress(
          defaultSkillTree,
          unlockedNodeIds: ['unlock_fire', 'unlock_wind'],
        ),
      );
      expect(
        match.availableElementIdsForCurrentPlayer,
        equals(['fire', 'wind']),
      );
    });

    test('playElementIds throws for an element the current player has not '
        'unlocked', () {
      final match = TrainingMatch(
        initialProgressA: SkillProgress(
          defaultSkillTree,
          unlockedNodeIds: ['unlock_fire'],
        ),
      );
      expect(
        () => match.playElementIds(['water']),
        throwsArgumentError,
      );
    });

    test('cumulativeTurnsPlayedA/B increment only for whoever just played', () {
      final match = TrainingMatch(
        initialProgressA: _allElementsUnlocked(),
        initialProgressB: _allElementsUnlocked(),
      );
      expect(match.cumulativeTurnsPlayedA, 0);
      expect(match.cumulativeTurnsPlayedB, 0);

      match.playElementIds(['fire']); // Jogador A
      expect(match.cumulativeTurnsPlayedA, 1);
      expect(match.cumulativeTurnsPlayedB, 0);

      match.playElementIds(['water']); // Jogador B
      expect(match.cumulativeTurnsPlayedA, 1);
      expect(match.cumulativeTurnsPlayedB, 1);
    });

    test('unlockSkillForCurrentPlayer throws for an element node without '
        'enough cumulative turns', () {
      final match = TrainingMatch(
        initialProgressA: SkillProgress(
          defaultSkillTree,
          unlockedNodeIds: ['unlock_fire', 'unlock_wind'],
        ),
      );
      expect(
        () => match.unlockSkillForCurrentPlayer('unlock_water'),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          'Faltam 10 turnos para desbloquear Água.',
        )),
      );
    });

    test('unlockSkillForCurrentPlayer unlocks an element node once enough '
        'cumulative turns have been played', () {
      final match = TrainingMatch(
        initialProgressA: SkillProgress(
          defaultSkillTree,
          unlockedNodeIds: ['unlock_fire', 'unlock_wind'],
        ),
        initialTurnsPlayedA: 10,
      );

      match.unlockSkillForCurrentPlayer('unlock_water');

      expect(match.availableElementIdsForCurrentPlayer, contains('water'));
    });

    test('turnsRemainingToUnlock reflects the increasing cost curve', () {
      final match = TrainingMatch(
        initialProgressA: SkillProgress(
          defaultSkillTree,
          unlockedNodeIds: ['unlock_fire', 'unlock_wind'],
        ),
        initialProgressB: SkillProgress(
          defaultSkillTree,
          unlockedNodeIds: ['unlock_fire'],
        ),
      );
      expect(match.turnsRemainingToUnlock('unlock_water'), equals(10));

      for (var i = 0; i < 10; i++) {
        match.playElementIds(['fire']); // Jogador A
        match.playElementIds(['fire']); // Jogador B
      }

      expect(match.turnsRemainingToUnlock('unlock_water'), isNull); // já alcançável
      match.unlockSkillForCurrentPlayer('unlock_water'); // ainda a vez de A
      expect(
        match.turnsRemainingToUnlock('unlock_earth'),
        equals(10), // 3 elementos já: (3-1)*10=20, já tem 10 jogados
      );
    });
  });
}
