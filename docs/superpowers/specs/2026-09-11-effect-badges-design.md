# Badges de status/efeito de campo (Bloco 9) — design

Data: 2026-09-11
Status: aprovado pelo usuário, pronto para virar plano de implementação.

## Contexto

O battle_engine já tem um sistema completo de status ativos (Queimadura,
Escudo, Congelar, Veneno, Choque, Lentidão, Silêncio, Fortalecimento,
Enfraquecimento, Molhado, Efeito de Área — 11 tipos) e de efeitos de
campo (Tempestade Ígnea, Campo Eletrocutado, Lava), mas a apresentação
na cena de batalha é só texto cru: "Jogador A: Escudo",
"Campo: Tempestade Ígnea". Próximo item sem bloco dedicado na ordem de
prioridade do CLAUDE.md ("Direção de produto"): efeitos.

Descoberta importante durante o brainstorming: o backend do Multiplayer
**já manda** `combatantStatuses` (status ativos por jogador) na resposta
de `GET /matches/:id`, desde a DECISION-024 — só o cliente Flutter nunca
parseou esse campo. Então este bloco não precisa de nenhuma mudança no
backend, só no modelo do cliente (`RemoteBattleState`).

## Escopo

Badges pequenos e coloridos (não pixel art — estilo escolhido pelo
usuário no companheiro visual, diferente da família
PixelMenuButton/PixelElementChip) abaixo da barra de HP de cada jogador
(status ativos) e numa fileira central abaixo dos dois painéis do HUD
(efeitos de campo, sem "dono"). Cada badge mostra um ícone (emoji) e,
quando o efeito tem duração contada em turnos, um número pequeno com os
turnos restantes.

Fora de escopo: nenhuma animação nova nos badges (isso é "animações",
já coberto no Bloco 6); nenhum tooltip/descrição ao tocar (YAGNI); sem
mudança nenhuma em `battle_engine`/backend — puramente apresentação e um
parse de campo que já existe na API.

## `EffectBadgeView` (`game_domain/effect_badge_view.dart`, novo)

```dart
/// Dado puro pra um badge de status/efeito de campo: [id] mapeia pra
/// ícone/cor (`game_presentation/status_visuals.dart`); [remainingTurns]
/// é `null` quando o efeito não tem contagem visível (Escudo, que dura
/// até ser consumido; ou qualquer efeito de campo hoje — nenhuma
/// combinação atual define duração). Mesma forma serve pra status por
/// jogador e pra efeito de campo — os dois viram badge idêntico na UI.
class EffectBadgeView {
  final String id;
  final int? remainingTurns;

  const EffectBadgeView({required this.id, this.remainingTurns});
}
```

## Ícones (`game_presentation/status_visuals.dart`, novo)

Mesma forma de `element_visuals.dart` (mapa fixo + fallback), cobrindo
os 11 ids de `StatusEffect` (mesmo os 9 ainda inertes hoje — é só dado,
já fica pronto pro dia que ganharem comportamento) e um fallback
genérico pra `FieldEffect`/combinação sem entrada dedicada:

```dart
const Map<String, String> _statusIcons = {
  'burn': '🔥',
  'freeze': '❄️',
  'wet': '💧',
  'poison': '☠️',
  'shock': '⚡',
  'slow': '🐌',
  'shield': '🛡️',
  'silence': '🤐',
  'buff': '⬆️',
  'debuff': '⬇️',
  'area_effect': '🌀',
};

const Map<String, String> _fieldEffectIcons = {
  'ignited_storm': '🌪️',
  'electrified_field': '🌩️',
  'lava': '🌋',
};

const Map<String, Color> _statusColors = {
  'burn': Color(0xFFFF7043),
  'freeze': Color(0xFF64B5F6),
  'wet': Color(0xFF4FC3F7),
  'poison': Color(0xFFAB47BC),
  'shock': Color(0xFFFFD54F),
  'slow': Color(0xFF8D6E63),
  'shield': Color(0xFF90CAF9),
  'silence': Color(0xFFBCAAA4),
  'buff': Color(0xFF81C784),
  'debuff': Color(0xFFE57373),
  'area_effect': Color(0xFFCE93D8),
};

/// Ícone (emoji) de um badge de status por jogador. `?` como fallback
/// (não deveria ser atingido com um id real de `StatusEffects.all`).
String statusIcon(String statusId) => _statusIcons[statusId] ?? '?';

/// Cor do badge de status por jogador. Cinza como fallback.
Color statusColor(String statusId) =>
    _statusColors[statusId] ?? const Color(0xFF9E9E9E);

/// Ícone (emoji) de um badge de efeito de campo. Fallback genérico (✨)
/// pra qualquer `FieldEffect`/combinação sem entrada dedicada — mantém
/// data-driven: uma combinação nova não quebra nada, só usa o fallback
/// até alguém adicionar o ícone específico.
String fieldEffectIcon(String fieldEffectId) =>
    _fieldEffectIcons[fieldEffectId] ?? '✨';
```

(Cores dos efeitos de campo não são necessárias — o mockup escolhido
usa um fundo neutro único pra badge de campo, só o ícone muda.)

## Dados: Modo Treino (`game_domain/training_match.dart`)

Três getters novos em `TrainingMatch`, ao lado de
`playerAStatusNames`/`playerBStatusNames`/`activeFieldEffectNames`
(que continuam existindo — ainda usados pelo resumo de texto):

```dart
List<EffectBadgeView> get playerAActiveStatuses => _state
    .statusesOf(_playerA)
    .map((s) => EffectBadgeView(id: s.effect.id, remainingTurns: s.turnsRemaining))
    .toList();

List<EffectBadgeView> get playerBActiveStatuses => _state
    .statusesOf(_playerB)
    .map((s) => EffectBadgeView(id: s.effect.id, remainingTurns: s.turnsRemaining))
    .toList();

List<EffectBadgeView> get activeFieldEffectBadges => _state.activeFieldEffects
    .map((effect) => EffectBadgeView(id: effect.id, remainingTurns: effect.duration))
    .toList();
```

## Dados: Multiplayer

`RemoteBattleState` (`game_domain/multiplayer_models.dart`) ganha um
tipo novo `RemoteActiveStatus` e o campo `combatantStatuses`, espelhando
o shape real do JSON do backend
(`backend/src/battle-rules/types.ts`'s `ActiveStatus`:
`{effectId, turnsRemaining, damagePerTick}` — plano, sem objeto
`StatusEffect` aninhado, diferente do Dart do battle_engine):

```dart
class RemoteActiveStatus {
  final String effectId;
  final int? turnsRemaining;

  const RemoteActiveStatus({required this.effectId, this.turnsRemaining});

  factory RemoteActiveStatus.fromJson(Map<String, dynamic> json) {
    return RemoteActiveStatus(
      effectId: json['effectId'] as String,
      turnsRemaining: json['turnsRemaining'] as int?,
    );
  }
}
```

Em `RemoteBattleState`: novo campo
`final Map<String, List<RemoteActiveStatus>> combatantStatuses;`,
parseado em `fromJson` a partir de `json['combatantStatuses']` (mapa de
playerId pra lista — mesmo padrão do parse de `hp`).

Em `MultiplayerMatch` (`game_domain/multiplayer_match.dart`), dois
getters novos ao lado de `activeFieldEffectIds` (que continua existindo
— ainda usado pelo resumo de texto):

```dart
List<EffectBadgeView> _statusesOf(String? playerId) {
  if (playerId == null) return const [];
  final statuses = _match?.state?.combatantStatuses[playerId] ?? const [];
  return statuses
      .map((s) => EffectBadgeView(id: s.effectId, remainingTurns: s.turnsRemaining))
      .toList();
}

List<EffectBadgeView> get myActiveStatuses => _statusesOf(localPlayerId);
List<EffectBadgeView> get opponentActiveStatuses => _statusesOf(_opponentId);

List<EffectBadgeView> get activeFieldEffectBadges =>
    _match?.state?.activeFieldEffects
        .map((e) => EffectBadgeView(id: e.id, remainingTurns: e.duration))
        .toList() ??
    const [];
```

## Visual: `BattleSceneView` e `BattleHudWidget`

`BattleSceneView` (`game_domain/battle_scene_view.dart`) ganha três
campos novos, com default `const []` (nenhuma tela existente quebra até
ser atualizada pra passar o dado real):

```dart
final List<EffectBadgeView> leftStatuses;
final List<EffectBadgeView> rightStatuses;
final List<EffectBadgeView> fieldEffects;
```

`BattleHudWidget`/`_HudPanel` (`game_presentation/battle_hud_widget.dart`)
ganham um novo parâmetro `statuses: List<EffectBadgeView>`, renderizado
como uma `Wrap` de círculos pequenos (18px) logo abaixo do texto de HP —
cada um com `statusColor(id)` de fundo, `statusIcon(id)` centralizado, e
(se `remainingTurns != null`) um número pequeno no canto inferior
direito do círculo.

Abaixo do `Row` dos dois painéis, um widget novo `_FieldEffectBadges`
(privado, mesmo arquivo) renderiza uma `Wrap` centralizada com um badge
por `view.fieldEffects` (mesmo componente visual dos badges de status,
sem "dono", cor de fundo neutra fixa) — só aparece quando a lista não
está vazia (nenhum efeito de campo ativo = nada renderizado, sem espaço
reservado).

## Fiação nas telas

`TrainingScreen`/`MultiplayerBattleScreen` passam os novos campos ao
montar `BattleSceneView`:

```dart
BattleSceneView(
  // ...campos já existentes...
  leftStatuses: _match.playerAActiveStatuses,       // ou myActiveStatuses no Multiplayer
  rightStatuses: _match.playerBActiveStatuses,       // ou opponentActiveStatuses
  fieldEffects: _match.activeFieldEffectBadges,
)
```

## Testes esperados

- `status_visuals_test.dart` (novo): `statusIcon`/`statusColor`/
  `fieldEffectIcon` pra cada id conhecido + fallback pra um id
  desconhecido.
- `training_match_test.dart`: `playerAActiveStatuses`/
  `playerBActiveStatuses`/`activeFieldEffectBadges` devolvem os ids e
  `remainingTurns` certos depois de aplicar um status/campo real (ex:
  jogar Fogo sozinho aplica Queimadura com `turnsRemaining` > 0; Fogo+
  Vento ativa Tempestade Ígnea).
- `multiplayer_match_test.dart`: não existe um `multiplayer_models_test.dart`
  dedicado hoje — o parse de `RemoteMatch`/`RemoteBattleState` já é
  coberto indiretamente pelas fixtures JSON deste arquivo (mesmo padrão
  do campo `hp`, ver linha ~50). `combatantStatuses` parseado certo
  entra do mesmo jeito; `myActiveStatuses`/`opponentActiveStatuses`/
  `activeFieldEffectBadges` resolvem "eu" vs "oponente" certo a partir
  de uma fixture com `combatantStatuses` preenchido.
- `battle_hud_widget_test.dart`: passando `statuses`/`fieldEffects` não
  vazios, os badges aparecem (por texto do emoji ou por
  `find.byType`/chave); lista vazia não renderiza nada.
- Nenhum teste existente deveria quebrar — os três campos novos de
  `BattleSceneView` têm default `[]`.
- Verificação manual: `flutter run -d web-server`, jogar Fogo sozinho no
  Treino pra ver o badge de Queimadura aparecer com o número de turnos,
  e Fogo+Vento pra ver o badge de campo (Tempestade Ígnea) aparecer
  entre os dois painéis.

## Fora de escopo, mas não esquecido

- Animação nos badges (pulsar, entrar/sair) — "animações" já foi um
  bloco (6); se quiser polir mais tarde, fica pra um bloco futuro.
- Tooltip/descrição ao tocar num badge — não pedido, YAGNI.
- Ícone específico por combinação nova — cai no fallback (✨) até
  alguém adicionar a entrada em `_fieldEffectIcons`.
