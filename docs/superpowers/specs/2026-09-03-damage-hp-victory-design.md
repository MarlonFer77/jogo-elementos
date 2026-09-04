# Sistema de dano/HP/condição de vitória — design

Data: 2026-09-03
Status: aprovado pelo usuário, pronto para virar plano de implementação.

## Contexto

Até agora, uma "batalha" no `battle_engine` nunca termina: não existe dano, HP
nem condição de vitória em lugar nenhum do projeto (Dart, TypeScript ou
Flutter). `TurnEngine`/`AbilityEngine` resolvem combinações e aplicam
estados, mas nada reduz um "HP" porque esse conceito não existe. Esta
tarefa introduz o núcleo mínimo que faz uma partida ter um fim.

Escopo definido em conversa com o usuário (ver `DECISIONS.md` no repositório
para o histórico de decisões anteriores que este design assume como dado:
DECISION-002 data-driven, DECISION-004 ações de turno, DECISION-008/009
Skill Tree/SkillGrant, DECISION-013/014 mirror do backend).

## Decisões confirmadas

1. **Só combinações causam dano.** Jogar 1 elemento sozinho nunca causa
   dano — é jogada de setup. 2–3 elementos que formam uma combinação
   conhecida causam dano; combinação desconhecida não causa dano (mas ainda
   passa o turno, como hoje).
2. **Combinações de 3 elementos causam mais dano que as de 2** — mais
   difíceis de formar, pagam mais.
3. **HP não é derivado de "quantos combos matam"** — é um atributo próprio:
   HP base fixo + bônus vindo da Skill Tree (e, no futuro, de artefatos —
   não implementados agora, só sem bloquear a entrada deles depois).
4. Estados com dano ao longo do tempo (Burn/Poison) e Escudo (bloqueio de
   dano) entram nesta tarefa. Estados de controle (Freeze/Silence/Slow) e
   Buff/Debuff genéricos continuam sem comportamento.

## Números

| Item | Valor |
|---|---|
| HP base (antes de bônus de Skill Tree) | 100 |
| Dano de combinação de 2 elementos (Tempestade Ígnea, Campo Eletrocutado) | 20 |
| Dano de combinação de 3 elementos (Lava) | 35 |
| Combustão (`Mutations.combustion`) — dano por tick | 8, por 2 ticks (16 no total) |
| Nó de exemplo na Skill Tree concedendo HP ("Vitalidade") | +20 HP máximo |

Poison e Shield ganham o mecanismo (campo de dado pronto) mas nenhuma
`Mutation`/nó de Skill Tree os concede ainda — mesma situação em que Burn
estava antes de `Mutations.combustion` existir.

## Modelo de dados (packages/battle_engine)

### `HpPool` (novo)
```dart
class HpPool {
  final int max;
  final int current;
  bool get isDefeated => current <= 0;
  HpPool withDamage(int amount); // clamped em 0, nunca negativo
}
```
Imutável, mesmo padrão de `FieldEffect`/`ActiveStatus`.

### `BattleState` (alterado)
- Novos campos: `Map<Combatant, HpPool> hp`, `Combatant? winner`.
- `BattleState.start` ganha `playerAMaxHp`/`playerBMaxHp` — **opcionais**,
  com default **100 visível na assinatura** (`int playerAMaxHp = 100`).
  Refinamento decidido durante o planejamento: a versão original deste
  spec pedia parâmetros obrigatórios sem default, mas isso forçaria ~32
  testes existentes (que não têm nada a ver com HP) a passar os dois
  parâmetros só para continuar compilando — puro ruído mecânico. O default
  visível resolve isso sem esconder nada: **código de produção
  (`TrainingMatch`) sempre calcula e passa o valor real (100 + bônus da
  Skill Tree) explicitamente, nunca depende do default** — o default
  existe só para a conveniência de testes que não testam HP.
  `current` começa igual a `max` para os dois. `winner` começa `null`.
- Novo método `withDamage(Combatant target, int amount)`: aplica dano
  (clamped em 0), e se o HP resultante chegar a 0, seta `winner` como o
  **outro** combatente. Retorna novo estado (imutável, como tudo aqui).
- `withStatusesTicked()` já existe (da tarefa de Estados) — passa a ser
  chamado automaticamente pelo `TurnEngine`, não mais só disponível pra
  quem quiser chamar manualmente.
- Novo método `withMaxHpIncreased(Combatant target, int amount)`: soma
  `amount` tanto no `max` quanto no `current` do alvo (fica mais forte na
  hora, não só com um teto mais alto). **Detalhe adicionado durante o
  planejamento** (não estava nos 3 blocos originais): como um jogador pode
  desbloquear um nó de HP no **meio da partida** (depois que
  `BattleState.start` já rodou com o HP inicial), o bônus precisa ser
  aplicado ao vivo. `TrainingMatch.unlockSkillForCurrentPlayer` chama isso
  quando o nó recém-desbloqueado concede um `MaxHpBonus`.

### `ActiveStatus` (alterado)
- Novo campo `damagePerTick` (int, default 0). Quem aplica o status decide
  o valor (data-driven) — não é fixo por tipo de `StatusEffect`.

### `Mutations.combustion` (alterado)
- Passa a aplicar `ActiveStatus(effect: StatusEffects.burn, turnsRemaining: 2, damagePerTick: 8)`
  em vez de `ActiveStatus(effect: StatusEffects.burn, turnsRemaining: 2)`
  (sem dano).

### `FieldEffect` (alterado)
- Novo campo `damage` (int, default 0).

### `ElementCombination` / `default_combinations.dart` (alterado)
- `ElementCombination` ganha campo `damage` (repassado pro `FieldEffect`
  via `.result`).
- `defaultCombinationBook`: Tempestade Ígnea e Campo Eletrocutado com
  `damage: 20`; Lava com `damage: 35`.

### `MaxHpBonus` (novo)
```dart
class MaxHpBonus implements SkillGrant {
  final String id;
  final int bonus;
}
```
Mesmo padrão de `Mutation`/`CombinationModifier` (DECISION-009) — um novo
tipo de `SkillGrant` que um `SkillNode` pode conceder.

### `SkillProgress` (alterado)
- Novo getter `grantedMaxHpBonus` (soma de todo `MaxHpBonus` concedido por
  nós desbloqueados, mesmo padrão de `grantedMutations`/
  `grantedCombinationModifiers`).

### `defaultSkillTree` (alterado)
- Novo nó de exemplo ("Vitalidade" ou nome similar) concedendo
  `MaxHpBonus(bonus: 20)`, numa branch existente ou nova — a definir na
  implementação (não é uma decisão de design, é detalhe de conteúdo).

## Lógica de resolução (`TurnEngine.playTurn`)

Ordem de operações dentro de uma chamada:

1. Validar: `state.winner == null` (senão `TurnValidationError`/`StateError`
   — partida já acabou), é a vez do ator, `elements` não vazio (como hoje).
2. Resolver combinação via `CombinationBook` (como hoje) — 2–3 elementos.
3. Aplicar `combinationModifiers` ao `FieldEffect` resultante (como hoje —
   isso já pode alterar `damage` no futuro, mas os modificadores atuais
   [Propagação, Instabilidade] não mexem em `damage`, só `area`/`duration`;
   não faz parte desta tarefa estender eles).
4. Se há combinação: determinar dano = `fieldEffect.damage`. Se o alvo
   (oponente do ator) tem Escudo ativo (`hasStatus(target, StatusEffects.shield)`):
   dano vira 0 e o Escudo é removido (`withStatusRemoved`). Aplicar o dano
   restante via `state.withDamage(target, damage)`.
5. (Só em `AbilityEngine.useAbility`) aplicar `statusesToApply` das
   mutações no oponente — comportamento já existente, inalterado. Isso
   acontece independente do Escudo (Escudo só bloqueia dano de combo
   direto, não impede um status ser aplicado).
6. Passar o turno (como hoje).
7. Tickar os estados dos dois combatentes: para cada `ActiveStatus` ainda
   ativo **antes** do tick (ou seja, incluindo aquele cujo `turnsRemaining`
   vai virar 0 e expirar nesse exato tick), aplicar `damagePerTick` via
   `withDamage` no dono do estado — depois disso, decrementar/remover como
   `withStatusesTicked` já faz hoje. Isso é o que faz Combustão (2 ticks)
   causar os 16 de dano total: os dois ticks (incluindo o que expira o
   estado) causam dano, nenhum "tick fantasma" sem efeito.
8. Checar vencedor: se algum HP chegou a 0 (no passo 4 ou no passo 7),
   `winner` já foi setado por `withDamage`. Caso as duas pontas cheguem a 0
   na mesma resolução (dano de combo + DOT simultâneos matando os dois —
   caso extremo), quem estava jogando o turno (`action.actorId`) vence o
   desempate.

`AbilityEngine.useAbility` segue a mesma ordem, já que internamente chama
`TurnEngine.playTurn`.

## O que fica fora desta tarefa (e por quê)

- **Artefatos**: mencionados pelo usuário como fonte futura de bônus de
  HP, junto com a Skill Tree. `MaxHpBonus` já serve de modelo pra esse
  sistema entrar depois sem redesenhar nada; não é implementado agora.
- **hitCount (Fragmentação) e critChanceBonus (Núcleo Instável)**:
  continuam inertes (dado carregado, não consumido) — dar significado a
  eles (múltiplos hits, crítico) interage com Escudo de um jeito que
  merece uma conversa própria (ex: múltiplos hits furando o escudo).
- **Dano recorrente de campo**: `FieldEffect.damage` é um hit único no
  momento em que a combinação dispara — não é dano contínuo enquanto o
  efeito estiver ativo no campo (Lava não continua queimando a cada turno
  só por estar no `activeFieldEffects`).
- **Freeze/Silence/Slow/Buff/Debuff/Wet/Shock**: continuam sem
  comportamento — são efeitos de controle/utilidade, não de dano.
- **Backend (`backend/src/battle-rules/`)**: por ora, o mirror em
  TypeScript (DECISION-013/014) NÃO ganha HP/dano nesta tarefa — o
  `battle-rules` do backend valida só a resolução de turno básica
  (elementos → combinação → passa o turno), como já documentado. Estender
  o mirror pra validar dano/HP/vitória é uma tarefa própria futura (fica
  registrado como lacuna conhecida, não decisão silenciosa).
- **Flutter (`TrainingMatch`/`TrainingScreen`)**: a UI SERÁ atualizada
  nesta tarefa (é o único lugar onde dá pra jogar de verdade hoje) —
  mostrar HP de cada jogador, aplicar `playerAMaxHp`/`playerBMaxHp`
  (100 + bônus de Skill Tree de cada um) ao criar a `BattleState`, e
  mostrar quando alguém vence. Isso não é "fora de escopo", é a UI
  necessária pra verificar a tarefa de verdade rodando.

## Testes esperados (packages/battle_engine)

- `HpPool`: `withDamage` clampa em 0, `isDefeated` reflete `current <= 0`.
- `BattleState.start` com `playerAMaxHp`/`playerBMaxHp` diferentes; `hp`
  inicial correto; `winner` null.
- `BattleState.withDamage`: reduz HP, seta `winner` quando chega a 0, não
  deixa `current` negativo.
- `TurnEngine.playTurn`: combinação de 2 elementos aplica 20 de dano no
  oponente; combinação de 3 aplica 35; elemento único ou combinação
  desconhecida não aplica dano; Escudo bloqueia o dano de combo e é
  consumido; `winner` setado quando o HP chega a 0; `playTurn` lança erro
  se `state.winner != null`.
- Tick automático: `ActiveStatus` com `damagePerTick` aplica dano ao fim de
  `playTurn`, nos dois combatentes; estado expira conforme já testado
  antes; DOT pode ser a causa da vitória (winner setado pelo tick).
- `Mutations.combustion`: `ActiveStatus` resultante tem `damagePerTick: 8`.
- `SkillProgress.grantedMaxHpBonus`: soma corretamente, ignora outros tipos
  de `SkillGrant` (mesmo padrão dos testes já existentes de
  `grantedMutations`/`grantedCombinationModifiers`).
- `defaultSkillTree`: novo nó de HP presente, testável via
  `SkillProgress.grantedMaxHpBonus` depois de desbloqueado.

## Testes esperados (app/ — Flutter)

- `TrainingMatch`: HP inicial de cada jogador reflete
  `100 + grantedMaxHpBonus`; combinação de 2/3 elementos reduz o HP do
  oponente nos valores certos; partida marca vencedor quando o HP chega a
  0; nenhuma ação é aceita depois que há vencedor.
- `TrainingScreen` (widget): mostra HP de cada jogador; mostra uma tela/
  mensagem de fim de partida com o vencedor; o formulário de jogada some
  ou fica desabilitado depois do fim.

## Fora de escopo, mas não esquecido

Este spec não altera `backend/src/battle-rules/`. Quando uma tarefa futura
precisar validar dano/HP/vitória no servidor (pré-requisito real pro
Multiplayer valer a pena de verdade — hoje ele só teria combinação/turno
validados, não o resultado da partida), esse mirror em TypeScript precisa
ganhar os mesmos campos/lógica descritos aqui. Registrar isso como um
lembrete no `DECISIONS.md` ao final desta tarefa.
