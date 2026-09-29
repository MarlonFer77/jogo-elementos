# Skill Tree — talentos com efeito real

Os três talentos pendentes foram concluídos sem novos IDs ou migração de saves.
Todas as habilidades atuais têm comportamento no combate; compras antigas passam
a funcionar e Precisão está liberada na dungeon, com os mesmos custos/pré-requisitos.

## Decisões de gameplay

- **Núcleo Instável / Concentração:** AP cheio ao conjurar concede +25% de dano
  direto. Conta a regeneração antes do custo. Lentidão pode impedir atingir o
  máximo; silêncio, congelamento e AP insuficiente continuam bloqueando a ação.
  Não há sorte, rolagem crítica ou divergência entre prévia e resultado.
- **Fragmentação:** reduz o dano direto para 80% e divide em dois golpes. A
  primeira parte recebe o resto do arredondamento. Escudo bloqueia o primeiro;
  Defesa reduz o primeiro em 50%. O segundo pode atingir o HP. Contra alvo sem
  proteção há perda de dano: não é uma melhoria universal.
- **Incêndio:** Queimadura passiva dura três ações globais, em vez de duas,
  mantendo 3 de dano por ação. Substitui a criação do campo decorativo sem dano.
  Não acumula queimaduras: preserva maior dano por tick e, em empate, maior
  duração restante. Escudo bloqueia aplicação; purificação remove normalmente.

Precisão afeta apenas dano direto de combos válidos, nunca básicos, suporte sem
dano, cura ou ticks. Buff/Debuff/Molhado ajustam primeiro o dano; concentração
e redução de Fragmentação vêm depois, arredondando o total antes de dividir.
AP, status, cura, drenagem e passagem do turno ocorrem **uma vez**. Um Escudo
presente no início ainda bloqueia status/drenagem do combo inteiro. Interrompe
os golpes assim que há vencedor. Nenhum efeito novo é aplicado após derrota.

Exemplo: Erupção (18) → concentração (23); fragmentação isolada (15 = 8+7);
concentração + fragmentação (18 = 9+9). Não dobra o dano original.

## Integração

`AbilityEngine` deriva parâmetros das mutações; `TurnEngine` resolve os golpes
antes dos ticks/status. O TypeScript espelha as regras. Parâmetros não são
aceitos do cliente. `lastAction.feedback` transporta códigos opcionais do
servidor; clientes antigos podem ignorá-los e ausência do campo é tolerada.

Prévia e feedback visual exibem Concentração/Fragmentação. Textos da árvore
explicam condições e tradeoffs. Incêndio aparece como Queimadura com duração
real na prévia/HUD; não gera novas instâncias do antigo `fire_zone` decorativo.
`critChanceBonus` mantém o nome interno legado, mas representa bônus determinista.

Sem novos elementos, branches, reset, APK, release ou deploy. A próxima publicação
precisa atualizar app e servidor juntos. Duração percebida, legibilidade e força
das builds ainda exigem playtest em aparelhos; testes não substituem isso.
