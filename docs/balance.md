# Balanceamento — combos e progressão

Ajuste inicial, ainda sujeito a playtest em aparelhos. Não é garantia de igual
taxa de vitória para todas as builds. Sem APK/deploy neste bloco.

## Problema principal: passivas sem custo

Básicos de 0 AP ativavam Queimadura de 8 × 2 e renovavam Escudo a cada ação.
Guarda + Combustão desvalorizavam combos, gerenciamento de AP e novas escolhas.

- Mutações agora exigem receita válida: básicos não ativam passivas.
- Combustão aplica 3 × 2, sem somar/substituir Queimadura igual ou mais forte.
- Guarda concede Escudo por 2 ações globais, consumido no primeiro golpe.
- Escudo bloqueia também a Queimadura passiva; derrota não aplica novos efeitos.
- Efeitos nativos dos combos e os modificadores de dano contínuo permanecem.
- IDs, compras, elementos e ataques equipados antigos são preservados.

## Ajustes de catálogo

| Combo | Antes → agora | Motivo |
| --- | --- | --- |
| Guarda Viva | dano 14 → 12 | Mesma defesa de Campo Eletrocutado, mesmo custo |
| Temporal Elétrico | dano 24 → 28 | Equiparar ao Cataclismo, ambos com Choque |
| Colosso | dano 18 → 14 | Escudo + Buff exige abrir mão de impacto frente a Bosque Sagrado |
| Tempestade Celestial | dano 24 → 22 | Purificação tem preço frente à Tempestade Solar |
| Nova | dano 32 → 30 | Separar explosão com purificação da força bruta de Lava (35) |
| Água Purificadora | cura 12 → 14 | Compensar ação sem causar dano |
| Cristal Vivo | cura 8 → 10 | Dar valor à recuperação com defesa |
| Mar Primordial | cura 24 → 26 | Recompensar preparação de 5 AP sem dano |

Custos preservados: 3 AP/dupla, 5 AP/tripla; Choque adiciona 1. Nenhuma receita
nova. Balanceamento igual em Dart e TypeScript; próxima publicação deve incluir
app e servidor juntos. Fixtures compartilhadas conferem os combos expandidos.

## Dungeon: primeira escolha mais cedo

Primeiro nível exige 40 XP (era 100): vencer o goblin já rende um ponto para
elemento ou habilidade. Demais custos por nível continuam 150, 200, 250…
Limiares acumulados: 40, 190, 390, 640, 940. Uma expedição de 1.000 XP ainda
rende 5 pontos, não mais que antes. Recompensas/HP/AP das salas não mudam.

Saves v1 mantêm XP e compras. Como os limiares apenas diminuíram, ninguém perde
nível ou pontos; perfis próximos do próximo nível podem ganhar um ponto ao
carregar. Não há reembolso/reset de árvore nem alteração na progressão PvP.

## Verificação e limites

Testes focados cobrem básicos sem passivas, custo de combos, Escudo/Queimadura,
paridade, cura, limites de XP e preservação de saves. Teste das dez recompensas
usa oponente roteirizado: não exige que uma build fixa vença todas as IAs reais.
Balanceamento de escolhas reais, duração das lutas, selos e dificuldade final
continua dependendo de playtest humano. Não alteramos habilidades ainda sem
comportamento de combate nem adicionamos sistemas de recompensa.
