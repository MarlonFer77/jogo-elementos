import 'package:app/game_domain/training_match.dart';
import 'package:app/main.dart';
import 'package:app/ui/training_screen.dart';
import 'package:battle_engine/battle_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

SkillProgress _allElementsUnlocked() => SkillProgress(
  defaultSkillTree,
  unlockedNodeIds: ElementUnlocks.all.map((u) => u.id).toList(),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'selecting fire and wind then playing triggers Tempestade Ígnea and '
    'passes the turn to Jogador B',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TrainingScreen(
            initialMatch: TrainingMatch(
              initialApA: const ApPool(max: 5, current: 3),
              initialProgressA: _allElementsUnlocked(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Vez de: Jogador A'), findsOneWidget);

      await tester.ensureVisible(find.text('Combinar elementos'));
      await tester.tap(find.text('Combinar elementos'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('🔥 Fogo'));
      await tester.pump();
      await tester.tap(find.text('🌪️ Vento'));
      await tester.pump();

      await tester.tap(find.text('Confirmar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.ensureVisible(find.text('Jogar'));
      await tester.tap(find.text('Jogar'));
      await tester.pump();

      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Vez de: Jogador B'), findsOneWidget);
      await tester.tap(find.byTooltip('Resumo da batalha'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Última combinação: Tempestade Ígnea'), findsOneWidget);
      expect(find.text('Descobertas: 1/3'), findsOneWidget);
      expect(find.textContaining('80/100 HP'), findsOneWidget);
      expect(
        find.textContaining('Novo ataque desbloqueado: Tempestade Ígnea'),
        findsOneWidget,
      );
    },
  );

  testWidgets('the play button is disabled until an element is selected', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'training_unlocked_a': ['unlock_fire'],
      'training_unlocked_b': ['unlock_fire'],
    });

    await tester.pumpWidget(const GameApp());
    await tester.pump(
      const Duration(milliseconds: 1),
    ); // resolve o Future.delayed da checagem de atualização

    await tester.tap(find.text('MODO TREINO'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Jogar'), findsNothing);
  });

  testWidgets(
    'unlocking Maestria da Brasa applies Queimadura to the opponent on the '
    'next action',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'training_unlocked_a': ['unlock_fire'],
        'training_unlocked_b': ['unlock_fire'],
      });

      await tester.pumpWidget(const GameApp());
      await tester.pump(
        const Duration(milliseconds: 1),
      ); // resolve o Future.delayed da checagem de atualização

      await tester.tap(find.text('MODO TREINO'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.byIcon(Icons.account_tree_outlined));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('Maestria da Brasa'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('Desbloquear'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.byType(BackButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.ensureVisible(find.text('Combinar elementos'));
      await tester.tap(find.text('Combinar elementos'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('🔥 Fogo'));
      await tester.pump();

      await tester.tap(find.text('Confirmar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.ensureVisible(find.text('Jogar'));
      await tester.tap(find.text('Jogar'));
      await tester.pump();

      // Status is already resolved in the domain, but the HUD reveals it
      // together with the hit, not before the projectile reaches its target.
      expect(find.text('🔥'), findsNothing);
      for (var i = 0; i < 7; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.tap(find.byTooltip('Resumo da batalha'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Efeitos aplicados: Queimadura'), findsOneWidget);
      expect(
        find.text('🔥'),
        findsOneWidget,
      ); // badge de Queimadura em Jogador B
    },
  );

  testWidgets(
    'shows the winner and a rematch button once the battle ends, hiding '
    'the play form',
    (WidgetTester tester) async {
      final match = TrainingMatch(
        initialProgressA: SkillProgress(
          defaultSkillTree,
          unlockedNodeIds: ['unlock_fire'],
        ),
        initialProgressB: SkillProgress(
          defaultSkillTree,
          unlockedNodeIds: ['unlock_ice'],
        ),
      );
      // 5 basic damage per hit (single element, always free) — 20 hits
      // defeat 100 HP.
      for (var i = 0; i < 19; i++) {
        match.playElementIds(['fire']); // Jogador A
        match.playElementIds(['ice']); // Jogador B
      }
      match.playElementIds(['fire']); // 20th hit: defeats Jogador B
      expect(match.isOver, isTrue); // sanity check on the setup itself

      await tester.pumpWidget(
        MaterialApp(home: TrainingScreen(initialMatch: match)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('Vencedor: Jogador A'), findsOneWidget);
      expect(find.text('Nova partida'), findsOneWidget);
      expect(find.text('Jogar'), findsNothing);
    },
  );

  testWidgets('Nova partida starts a fresh match', (WidgetTester tester) async {
    final match = TrainingMatch(
      initialProgressA: SkillProgress(
        defaultSkillTree,
        unlockedNodeIds: ['unlock_fire'],
      ),
      initialProgressB: SkillProgress(
        defaultSkillTree,
        unlockedNodeIds: ['unlock_ice'],
      ),
    );
    for (var i = 0; i < 19; i++) {
      match.playElementIds(['fire']);
      match.playElementIds(['ice']);
    }
    match.playElementIds(['fire']);

    await tester.pumpWidget(
      MaterialApp(home: TrainingScreen(initialMatch: match)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.ensureVisible(find.text('Nova partida'));
    await tester.tap(find.text('Nova partida'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Vez de: Jogador A'), findsOneWidget);
    expect(find.text('Escolha uma ação. +1 AP ao agir.'), findsOneWidget);
  });

  testWidgets(
    'loads persisted Skill Tree progress before showing the play form',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'training_unlocked_a': ['ember_mastery', 'unlock_fire'],
        'training_unlocked_b': ['unlock_fire'],
      });

      await tester.pumpWidget(const MaterialApp(home: TrainingScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));

      await tester.tap(find.byIcon(Icons.account_tree_outlined));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('Caminho do Incêndio'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Desbloquear'), findsOneWidget);
    },
  );

  testWidgets(
    'shows a friendly message when a combo is attempted without enough AP',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TrainingScreen(
            initialMatch: TrainingMatch(
              initialProgressA: SkillProgress(
                defaultSkillTree,
                unlockedNodeIds: ['unlock_fire', 'unlock_wind'],
              ),
            ), // AP começa em 0
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.ensureVisible(find.text('Combinar elementos'));
      await tester.tap(find.text('Combinar elementos'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('🔥 Fogo'));
      await tester.pump();
      await tester.tap(find.text('🌪️ Vento'));
      await tester.pump();

      await tester.tap(find.text('Confirmar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.ensureVisible(find.text('Jogar'));
      await tester.tap(find.text('Jogar'));
      await tester.pump();

      expect(
        find.text('AP insuficiente para essa combinação.'),
        findsOneWidget,
      );
      expect(
        find.text('Vez de: Jogador A'),
        findsOneWidget,
      ); // turno não passou
    },
  );

  testWidgets(
    'shows the starting-element picker for Jogador A when no progress is '
    'saved yet, then for Jogador B, then the normal play form',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: TrainingScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));

      expect(find.textContaining('Jogador A'), findsWidgets);

      await tester.tap(find.text('🔥 Fogo'));
      await tester.pump();
      await tester.tap(find.text('🌪️ Vento'));
      await tester.pump();
      await tester.tap(find.text('Preparar Jogador B'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('Jogador B'), findsWidgets);

      await tester.tap(find.text('🔥 Fogo'));
      await tester.pump();
      await tester.tap(find.text('🌪️ Vento'));
      await tester.pump();
      await tester.tap(find.text('Entrar na batalha'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Vez de: Jogador A'), findsOneWidget);
    },
  );

  testWidgets('locked elements appear with a lock icon and are not '
      'selectable', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TrainingScreen(
          initialMatch: TrainingMatch(
            initialProgressA: SkillProgress(
              defaultSkillTree,
              unlockedNodeIds: ['unlock_fire'],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.ensureVisible(find.text('Combinar elementos'));
    await tester.tap(find.text('Combinar elementos'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('🔥 Fogo'), findsOneWidget);
    expect(find.text('💧 Água'), findsNothing);
  });

  testWidgets(
    'rejects replaying a discovered-but-unequipped combination with a '
    'friendly message',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TrainingScreen(
            initialMatch: TrainingMatch(
              initialApA: const ApPool(max: 5, current: 5),
              initialProgressA: _allElementsUnlocked(),
              initialLoadoutA: AttackLoadout(
                unlockedCombinationIds: const {'ignited_storm'},
                equippedCombinationIds: const [], // desbloqueado, não equipado
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.ensureVisible(find.text('Combinar elementos'));
      await tester.tap(find.text('Combinar elementos'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('🔥 Fogo'));
      await tester.pump();
      await tester.tap(find.text('🌪️ Vento'));
      await tester.pump();

      await tester.tap(find.text('Confirmar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.ensureVisible(find.text('Jogar'));
      await tester.tap(find.text('Jogar'));
      await tester.pump();

      expect(
        find.text(
          'Tempestade Ígnea não está equipado. Troque na janela de '
          'Ataques Combinados.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Vez de: Jogador A'),
        findsOneWidget,
      ); // turno não passou
    },
  );

  testWidgets(
    'opens Ataques Combinados automatically when unlocking with 3 slots '
    'already full',
    (WidgetTester tester) async {
      // O jogo só define 3 combinações reais hoje (ignited_storm,
      // electrified_field, lava) — não dá pra encher 3 vagas com
      // combos reais e ainda sobrar um 4º real pra descobrir. Os 2
      // ids "fake_a"/"fake_b" preenchem 2 das 3 vagas de propósito
      // (`AttackLoadout` não valida que um id equipado corresponda a
      // uma `ElementCombination` real — é só contagem); a 3ª vaga é
      // preenchida com "electrified_field" (também não jogado nesta
      // partida) só pra reduzir o que aparece de "ruído" na tela. O
      // que este teste verifica é só a navegação (TrainingScreen abre
      // AttacksScreen sozinha) — o conteúdo exato do seletor de troca
      // já é coberto por `attacks_screen_test.dart` (Task 5).
      await tester.pumpWidget(
        MaterialApp(
          home: TrainingScreen(
            initialMatch: TrainingMatch(
              initialApA: const ApPool(max: 5, current: 5),
              initialProgressA: _allElementsUnlocked(),
              initialEquippedElementsA: ['earth', 'fire', 'water'],
              initialLoadoutA: AttackLoadout(
                unlockedCombinationIds: const {
                  'electrified_field',
                  'fake_a',
                  'fake_b',
                },
                equippedCombinationIds: const [
                  'electrified_field',
                  'fake_a',
                  'fake_b',
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.ensureVisible(find.text('Combinar elementos'));
      await tester.tap(find.text('Combinar elementos'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('🪨 Terra'));
      await tester.pump();
      await tester.tap(find.text('🔥 Fogo'));
      await tester.pump();
      await tester.tap(find.text('💧 Água'));
      await tester.pump();

      await tester.tap(find.text('Confirmar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.ensureVisible(find.text('Jogar'));
      await tester.tap(find.text('Jogar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Habilidades · 3 slots'), findsOneWidget);
    },
  );
}
