# Sequência de feedback de ataque — design

Data: 2026-09-08
Status: aprovado pelo usuário, pronto para virar plano de implementação.

## Contexto

O usuário definiu uma nova direção de produto (registrada em `CLAUDE.md`): o
jogo deixa de ser tratado como protótipo técnico e passa a exigir identidade,
apresentação e "game feel" — toda funcionalidade deve ser avaliada em 4
dimensões (Funcionalidade / UX / Visual / Game Feel), não só "funciona
tecnicamente". A prioridade de trabalho é: identidade visual > batalha
(feedback de ataque) > feedback visual > animações > ... — e o pedido
explícito foi trabalhar em blocos pequenos e completos, não tudo de uma vez.

Este é o **Bloco 1**, escolhido em conversa com o usuário: a sequência de
feedback visual de um ataque. Hoje (depois da DECISION-030, cenário de
batalha visual), quando uma combinação causa dano, a barra de HP do alvo
simplesmente encolhe e o personagem faz um flash+shake — instantâneo, sem
nenhuma "encenação" do que aconteceu (qual elemento, quanto de dano, se
aplicou um estado). Esta tarefa substitui isso por uma sequência real:
preparação → efeito elemental → impacto → dano → estado.

## Decisões confirmadas (conversa com o usuário)

1. **Bloco 1 = sequência de feedback de ataque** (não identidade visual
   isolada primeiro) — é o que dá mais "game feel" percebido de uma vez, e é
   o coração do jogo segundo a própria priorização do usuário.
2. **Vale para TODAS as combinações desde já**, não só uma combinação
   "vitrine" — com um visual simples por elemento (símbolo que já existe +
   uma cor nova), não arte customizada por combinação.
3. **Multiplayer**: quando a limitação de dados do backend foi levantada (ver
   seção própria abaixo), o usuário confirmou a opção sem mudança de
   contrato do backend — resolver só com o que o cliente já tem disponível.

## O que NÃO está neste bloco

- Ícone de status permanente sobre o personagem entre turnos (Escudo/
  Queimadura ativos enquanto o efeito dura) — lacuna já conhecida desde a
  DECISION-030, continua fora de escopo.
- Animação de "idle" contínua dos personagens (parados = parados, como hoje,
  fora da sequência de ataque).
- Projétil com física de verdade (curva, gravidade) — o "efeito viajando até
  o alvo" é um movimento linear simples.
- Crítico — não existe no jogo ainda (`critChanceBonus` é um campo inerte,
  ver `hitCount`/`critChanceBonus` no BACKLOG do `TASKS.md`).
- Qualquer mudança em `battle_engine` ou `backend/src/battle-rules/` — dano/
  HP/vitória continuam calculados exatamente como hoje, instantaneamente;
  esta tarefa só reencena visualmente o que já aconteceu.
- Áudio (prioridade mais baixa na direção de produto, bloco futuro).

## Identidade visual mínima por elemento

Sem asset novo: reaproveita o `symbol` que cada `Element` já tem em
`ElementCatalog` (🔥 Fogo, 💧 Água, 🌪️ Vento, ❄️ Gelo, 🌿 Natureza, ⚡ Raio,
🪨 Terra, 🌑 Sombra, ✨ Luz, ☠️ Veneno). Novo: um mapa `elementId → Color` em
`game_presentation` (10 cores, uma por elemento), usado no passo "Efeito
elemental" da sequência (ver tabela abaixo): cada símbolo de elemento
aparece sobre um pequeno círculo colorido com a cor daquele elemento
especificamente — um combo de 2-3 elementos mostra um círculo+símbolo por
elemento, lado a lado, sem misturar cores. Os personagens em si continuam
diferenciados só por lado (decisão da DECISION-030, não muda aqui).

## Modelo de dados

### `AttackEvent` (novo, `game_domain`)

```dart
class AttackEvent {
  final int sequenceId;              // identifica esta ocorrência de forma única
  final bool attackerIsLeft;
  final List<String> elementSymbols; // ex: ['🔥', '🌪️']
  final String? comboName;           // nome da combinação, se disparou uma
  final int damage;
  final List<String> appliedStatusNames; // ex: ['Queimadura']

  const AttackEvent({
    required this.sequenceId,
    required this.attackerIsLeft,
    required this.elementSymbols,
    this.comboName,
    required this.damage,
    required this.appliedStatusNames,
  });
}
```

Dado puro, sem dependência de Flutter/Flame nem de `battle_engine` — mesmo
espírito de `BattleSceneView`.

### `BattleSceneView` (alterado)

Ganha um campo `AttackEvent? lastAttack` (nulo quando não há nada novo pra
encenar — ex.: rebuild disparado por abrir/fechar o modal de Habilidades, ou
um poll do Multiplayer sem novidade).

### `sequenceId` — de onde vem

O mecanismo de "não repetir a mesma sequência" é: `BattleSceneGame` guarda
`int? _lastPlayedSequenceId`; toda vez que `updateView` chega com um
`lastAttack` não nulo cujo `sequenceId` é diferente do último tocado, dispara
a sequência e atualiza o campo. Isso é robusto a qualquer número de rebuilds
"sem novidade" (a tela pode continuar mandando o mesmo `AttackEvent` em
builds seguintes sem problema — só não tocaria de novo).

- **Modo Treino**: `TrainingMatch` ganha um contador `int get turnsPlayed`
  (incrementado a cada `playElementIds` bem-sucedido, independente de ter
  causado dano). `TrainingScreen` usa esse contador como `sequenceId` — só
  monta um `AttackEvent` quando a última jogada de fato triggou uma
  combinação (`lastTriggeredCombinationName != null`) ou aplicou algum
  estado (`lastAppliedStatusNames.isNotEmpty`); uma jogada de "setup" (1
  elemento, sem combo) não gera evento — nada a encenar.
- **Multiplayer**: um contador local em `_MultiplayerBattleScreenState`
  (`int _attackSequenceCounter`), incrementado sempre que: (a) o próprio
  jogador manda uma jogada com sucesso via `submitTurn` e ela disparou uma
  combinação (`SubmitTurnResult.triggeredCombinationId != null`), ou (b) um
  `refresh()` (poll) revela um novo item em `activeFieldEffectIds` que não
  estava lá na leitura anterior (detectado guardando o `Set<String>`
  anterior e comparando).

## A limitação do Multiplayer e como ela é resolvida

`RemoteBattleState` (o que o backend manda a cada poll) não inclui quais
elementos o oponente jogou — só HP, vez, efeitos de campo ativos e vencedor.
Isso significa que, quando o oponente joga (descoberto via poll, não pela
resposta direta de `submitTurn`), o cliente não sabe os elementos escolhidos
diretamente.

**Solução, sem mudar o backend**: quando um novo item aparece em
`activeFieldEffectIds`, o nome/id dessa combinação já identifica exatamente
quais elementos a formam — `CombinationCatalog`/`defaultCombinationBook`
(cliente já os tem, já usados hoje para mostrar "Campo: ...") mapeia o id da
combinação de volta para os elementos que a compõem. Ou seja, **mesmo para a
jogada do oponente, dá pra recuperar os elementos certos** a partir do nome
da combinação — não é preciso ficar com um evento genérico "só impacto". O
dano é a diferença de HP do jogador local antes/depois do `refresh()`.

Único caso que continua sem sequência: o oponente jogou um elemento avulso ou
uma combinação desconhecida (sem dano, por regra do jogo — só combinação
conhecida causa dano) — nesse caso não há nada visível pra encenar mesmo, e
isso já é esperado (mesma regra vale pro jogador local).

## `AttackSequencePlayer` (novo, `game_presentation`)

Um `Component` do Flame, filho de `BattleSceneGame`, criado quando um novo
`AttackEvent` chega e se autorremove ao terminar. Guarda um passo atual
(`enum` interno: `preparation → elementalEffect → impact → damage →
stateApplied → done`) avançado via contagem regressiva em `update(dt)` — o
mesmo padrão de timer manual já usado em `BattleCharacterComponent` (sem o
sistema `Effect` do Flame, mesmo motivo de antes: menos risco de API, mais
fácil de testar sem o game loop).

Durações aproximadas (total ~1.0–1.3s, incluindo o passo de estado só quando
há status aplicado — ritmo rápido, batalha por turnos não pode travar):

| Passo | Duração | O que acontece |
|---|---|---|
| Preparação | ~150ms | O personagem atacante pulsa (leve aumento de escala) |
| Efeito elemental | ~200ms | Para cada elemento do combo, um círculo pequeno da cor daquele elemento com o símbolo por cima (`TextComponent` sobre um círculo desenhado, sem asset novo) aparece perto do atacante, lado a lado, crescendo e ganhando opacidade |
| Impacto | ~200ms | Esses círculos+símbolos se movem linearmente (juntos) até a posição do alvo; ao chegar, somem e disparam `BattleCharacterComponent.playHitEffect()` no alvo (reaproveita o flash+shake já existente da DECISION-030) |
| Dano | ~400ms | Um número flutuante (`TextComponent`, vermelho/branco) aparece sobre o alvo, sobe ~20px e desaparece; a barra de HP do alvo, que hoje pula direto pro valor novo, passa a **interpolar** até o valor novo nesse intervalo (`BattleCharacterComponent` ganha uma fração "exibida" que persegue a fração real) |
| Estado (só se houver) | ~300ms | Um texto curto (ex: "🔥 Queimadura") aparece sobre o alvo e desaparece |

Depois do último passo, o componente se remove — o resto da cena (barra de
HP no valor final, contorno de vez) já reflete o estado real, que nunca
mudou de forma diferente do que muda hoje (só a apresentação foi encenada
por cima).

## `BattleCharacterComponent` (alterado)

- `setHpFraction` passa a só atualizar um alvo interno (`_targetHpFraction`);
  a fração realmente desenhada (`_displayedHpFraction`) persegue esse alvo em
  `update(dt)` a uma velocidade fixa (chega no valor novo em ~400-500ms,
  compatível com o passo "Dano" da sequência). Sem sequência ativa (ex.:
  abrir o modal de Habilidades não muda HP), não há diferença visual — a
  barra já está no lugar.
- Ganha um pequeno "pulso" de escala reutilizável para o passo de preparação
  (mesmo componente, não um novo).

## Integração nas telas

`TrainingScreen`/`MultiplayerBattleScreen` passam a montar `lastAttack` (não
mais só HP/turno) ao construir o `BattleSceneView`, usando exatamente os
dados que já calculam hoje (`lastTriggeredCombinationName`,
`lastAppliedStatusNames`, elementos jogados/HP antes-depois) — nenhuma nova
chamada ao domínio ou ao backend, só reorganizar o que já existe em um
`AttackEvent`.

## Testes esperados

- `AttackEvent`: construção simples guarda os valores.
- `TrainingMatch.turnsPlayed`: incrementa a cada `playElementIds`.
- `AttackSequencePlayer`: avançar `update(dt)` no total esperado passa por
  todos os passos e termina (`isDone`/se autorremove); com
  `appliedStatusNames` vazio, pula o passo de estado (sequência mais curta).
- `BattleCharacterComponent`: fração exibida da barra de HP persegue a
  fração alvo ao longo de `update(dt)` em vez de saltar instantaneamente.
- Detecção de "novo evento" (`sequenceId`): dois `AttackEvent`s com o mesmo
  `sequenceId` não disparam a sequência duas vezes; `sequenceId`s diferentes
  disparam.
- Testes de widget existentes de `TrainingScreen`/`MultiplayerBattleScreen`
  continuam passando — texto de HP/vez vem do domínio, que não muda de
  comportamento; ajustar apenas se algum `pump()` precisar de mais tempo
  para os novos componentes assíncronos (mesmo cuidado já tomado nas tasks
  do cenário visual, DECISION-030).
- Verificação manual via `flutter run -d web-server`: jogar algumas
  combinações diferentes no Treino e no Multiplayer (duas abas/sessões) e
  observar a sequência de verdade, incluindo o caso da jogada do oponente
  descoberta via poll.

## Fora de escopo, mas não esquecido

Ícones de status persistentes, áudio, projétil com física, crítico — como
listado em "O que NÃO está neste bloco". Registrar como lembrete no
`DECISIONS.md`/`TASKS.md` ao final desta tarefa, mesmo padrão já usado nas
tarefas anteriores desta sessão.
