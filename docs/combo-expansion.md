# Expansão de combos

Implementação local: **63 receitas únicas**, sendo 40 duplas e 23 triplas.
São 43 novas receitas (25 duplas e 18 triplas); os 20 IDs anteriores foram
preservados para manter descobertas, ataques equipados e saves compatíveis.

## Regras e apresentação

- Duplas custam 3 AP e triplas 5 AP, antes dos modificadores existentes.
- A ordem dos elementos não muda a receita. Mantido o limite de 3 ataques
  equipados e o fluxo descobrir → aprender → equipar.
- Cura atua no conjurador, respeita HP máximo e não revive derrotados.
- Purificação remove queimadura, veneno, congelamento, silêncio, lentidão,
  choque, molhado e enfraquecimento; preserva benefícios.
- Validação e custo acontecem antes da purificação: ela não permite conjurar
  sob silêncio/congelamento nem recuperar o custo de choque/lentidão.
- Após dano direto, purificação e cura acontecem antes dos ticks de status;
  novos status são aplicados depois. Suporte é imediato, não cura a cada tick.
- Redução de AP afeta apenas o adversário, sem transferir AP ao conjurador,
  nunca fica abaixo de zero e é bloqueada por Escudo ativo antes da ação.
- Prévia informa cura, purificação e redução de AP; feedback do impacto exibe
  HP recuperado líquido e AP efetivamente retirado, junto ao dano existente.
- Treino/Dungeon usam o engine Dart; Multiplayer calcula no servidor TypeScript.
  Nenhum valor de cura/dano/AP informado pelo cliente é aceito como resultado.

Catálogos: `packages/battle_engine/lib/src/default_combinations.dart` e
`backend/src/battle-rules/combination-book.ts`. A fixture
`test_fixtures/expanded_combos.json` registra os 43 acréscimos com números e
status para conferir paridade; não é uma segunda fonte de runtime.

## Receitas repetidas na proposta

Uma mesma seleção não pode resultar em dois ataques diferentes. Estes nomes
da proposta foram unificados aos resultados abaixo (não são aliases na UI):

| Nome proposto | Resultado mantido |
| --- | --- |
| Fogo Venenoso | Chama Cáustica |
| Névoa | Dança da Chuva |
| Turbilhão Sombrio | Vendaval Mudo |
| Nevasca | Vento Invernal |
| Flora Ígnea | Brasa Vital |
| Minério Vivo | Raízes Profundas |
| Prisma / Luz Terrena | Muralha de Cristal |
| Trevas Venenosas | Maldição Tóxica |
| Eclipse Vivo | Floresta Sombria |
| Raio Abissal | Trovão Sombrio |
| Vazio Congelante | Geada Sombria |
| Luz Vital | Guarda Viva |
| Luz Elétrica | Raio Sagrado |
| Supercélula | Temporal Elétrico |
| Corrupção | Jardim da Peste |

## Limites deste bloco

Não liberamos automaticamente descobertas/elementos. Permanecem 5 duplas
sem receita: Fogo+Água, Fogo+Gelo, Gelo+Terra, Gelo+Raio e Vento+Natureza.
Triplas custam mais AP; raridade por loot/itens, classes, bênçãos, condições de
descoberta e combos de 4 elementos ficam para um bloco próprio.
Colosso/Dragão Vulcânico e efeitos de grandes áreas são representados pelas
regras de combate 1v1, sem criar unidades invocadas ou um sistema de áreas.

Sem APK, release ou deploy neste bloco. A próxima publicação precisa atualizar
backend e aplicativo juntos para disponibilizar as novas receitas online.
Testes focados não substituem playtest de balanceamento/feedback em celular.
