# CLAUDE.md

Regras permanentes do projeto. Não é um diário — não adicionar tarefas ou histórico aqui.

## Projeto

Jogo mobile 2D de batalhas 1v1 por turnos para dois amigos, baseado em combinação de
elementos, Skill Tree, builds e efeitos de campo. Objetivo: partidas de 3–7 minutos,
decisões relevantes, "só mais uma partida".

## Stack

- Mobile: Flutter + Dart + Flame
- Backend: Node.js + TypeScript
- Serviços: Firebase (free tier)

## Regra de custo (inegociável)

- Buscar R$ 0 de custo de infraestrutura no desenvolvimento e MVP.
- Não adicionar serviços pagos sem autorização explícita do usuário.
- Não assumir que um free tier é ilimitado — projetar para minimizar requisições,
  leituras, escritas, armazenamento, tráfego e processamento no servidor.
- Se uma decisão puder gerar custo, informar antes de implementar.

## Arquitetura (princípios)

```
Flutter → UI/Navegação → Game Presentation → Game Domain → Battle Engine
```

- O Battle Engine é lógica pura (Dart), sem dependência do Flutter ou do Flame.
  Deve rodar e ser testado isoladamente (`dart test`, sem SDK do Flutter).
- Flame é só a camada visual da batalha.
- O backend é a autoridade para tudo que é crítico no multiplayer: dano, vitória,
  derrota, recompensa, XP, recursos, resultado final. Nunca confiar no cliente
  para esses valores.
- Elementos, combinações e efeitos devem ser data-driven — evitar regras
  hardcoded espalhadas pelo código.

## Convenções de trabalho

- Sem fases artificiais (nada de "FASE 1", "FASE 2"...). Só NOW/NEXT/BACKLOG/DONE/BLOCKED
  em TASKS.md.
- Trabalhar apenas na tarefa de NOW. Não adiantar funcionalidades futuras.
- Regra de escopo: se a tarefa não exige alterar outro sistema, não alterar outro sistema.
- Toda lógica de domínio importante precisa de teste (combinações, dano, estados,
  turnos, Skill Tree, builds, validações, multiplayer).
- Sem segredos no cliente, sem dependências desnecessárias, sem overengineering.
- Não reescrever documentação que não mudou. Não relatar tudo de novo a cada resposta.
- Não criar múltiplos agentes/subagentes para este projeto — um único desenvolvedor.
- `backend/src/battle-rules/` (TypeScript) é um mirror manual e deliberadamente
  mínimo de partes do `packages/battle_engine` (Dart) — ver DECISION-013/014.
  Sempre que uma tarefa alterar `ElementCombination`, `default_combinations.dart`,
  `FieldEffect` ou `TurnEngine.playTurn` no Dart, checar se `backend/src/battle-rules/`
  precisa do mesmo ajuste antes de considerar a tarefa concluída.

## Problemas arquiteturais

Se encontrado, reportar como: Problema / Impacto / Solução recomendada / Alternativas.
Problemas triviais de implementação: resolver direto, sem interromper o fluxo.
