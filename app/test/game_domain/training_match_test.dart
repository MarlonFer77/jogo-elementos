import 'package:app/game_domain/training_match.dart';
import 'package:flutter_test/flutter_test.dart';

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
    final match = TrainingMatch();

    match.playElementIds(['fire', 'wind']);

    expect(match.currentTurnName, equals('Jogador B'));
    expect(match.lastTriggeredCombinationName, equals('Tempestade Ígnea'));
    expect(match.activeFieldEffectNames, equals(['Tempestade Ígnea']));
    expect(match.discoveredCount, equals(1));
  });

  test('discovering the same combination twice does not double-count', () {
    final match = TrainingMatch();

    match.playElementIds(['fire', 'wind']); // Jogador A
    match.playElementIds(['fire', 'wind']); // Jogador B, same combo

    expect(match.discoveredCount, equals(1));
  });

  test('an unknown combination does not add a field effect but still '
      'passes the turn', () {
    final match = TrainingMatch();

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
      final match = TrainingMatch();
      match.unlockSkillForCurrentPlayer('ember_mastery'); // Jogador A

      match.playElementIds(['fire']);

      expect(match.lastAppliedStatusNames, contains('Queimadura'));
      expect(match.playerBStatusNames, contains('Queimadura'));
      expect(match.playerAStatusNames, isEmpty);
    });

    test('each player\'s unlocked skills are independent', () {
      final match = TrainingMatch();
      match.unlockSkillForCurrentPlayer('ember_mastery'); // Jogador A
      expect(match.unlockedGrantNamesForCurrentPlayer, contains('Combustão'));

      match.playElementIds(['fire']); // turn passes to Jogador B

      // Jogador B hasn't unlocked anything yet.
      expect(match.unlockedGrantNamesForCurrentPlayer, isEmpty);
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
      final match = TrainingMatch();
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
      final match = TrainingMatch();
      // 5 hits of 20 damage from Jogador A defeat Jogador B (100 HP).
      for (var i = 0; i < 4; i++) {
        match.playElementIds(['fire', 'wind']); // Jogador A
        match.playElementIds(['ice']); // Jogador B, no damage
      }
      match.playElementIds(['fire', 'wind']); // 5th hit: defeats Jogador B

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
      final match = TrainingMatch();
      match.playElementIds(['fire', 'wind']); // Jogador A hits B for 20
      // Now it's Jogador B's turn; they unlock Vitalidade for themselves.
      match.unlockSkillForCurrentPlayer('vitality_training');

      expect(match.playerBMaxHp, equals(120));
      expect(match.playerBCurrentHp, equals(100)); // 80 + 20, not 120
    });
  });
}
