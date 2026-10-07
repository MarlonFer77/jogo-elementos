# Contrajogo elemental e arenas

Implementado localmente em 07/10/2026; sem publicação, APK ou mudança de saves.

## Mecânica

Ataques básicos passam a oferecer uma resposta específica a dano contínuo:

| Básico | Condição no atacante | Resultado |
| --- | --- | --- |
| Água | Queimadura ativa | Remove Queimadura; dano-base 3 em vez de 5 |
| Natureza | Veneno ativo | Remove Veneno; dano-base 3 em vez de 5 |

Sem o status correspondente, o básico continua com dano-base 5. A recuperação
acontece antes do dano contínuo e remove apenas esse status do próprio atacante.
Não cura HP, não dá imunidade e não se aplica automaticamente a combos.
Fortalecimento/Enfraquecimento e defesa continuam modificando o dano normalmente.
AP/turnos não mudam. Silêncio permite básicos; Lentidão continua impedindo a
regeneração; Congelamento continua exigindo Quebrar gelo. Escudo do adversário
bloqueia o golpe, não a recuperação do atacante. Outras condições seguem ativas.

Objetivo: dar motivo para escolher o básico e reservar um dos quatro slots a
contrajogo, com perda de pressão ofensiva. Purificação por combo continua tendo
valor: remove todas as condições negativas e não depende dessas duas respostas.
O valor 3 é inicial, não balanceamento comprovado; avaliar em partidas reais.

Mesma regra no TurnEngine Dart e no mirror TypeScript autoritativo. Códigos
`recover_burn`/`recover_poison` usam o feedback existente, incluindo prévias.
Botões exibem o benefício/custo quando aplicável; tutorial e descrições explicam.

## Cenários e feedback

- Treino: Clareira dos Aprendizes. Multiplayer: Pátio dos Elementos.
- Salas 1–10: Desfiladeiro das Brasas, Gruta Glacial, Pântano de Pedra, Templo do
  Sol, Penhascos da Tempestade, Ruínas da Lua, Bosque Ancestral, Picos do Trovão,
  Cripta da Peste, Caldeira da Ruína.
- Pixel art procedural: silhuetas, pilares, bandeiras, vegetação, cristais,
  crateras e piso contínuo para aproximação. Sem imagens/dependências novas.
- Clima cosmético com orçamento fixo de 14 partículas por arena. Não modifica
  AP/dano/status e não é um perigo de campo. Sem relâmpagos piscando.
- Movimento ambiental e partículas de impacto respeitam redução de animações
  do sistema; as animações essenciais de ação existentes permanecem.
- Defesa tem contorno aberto dourado; Escudo tem contorno fechado azul. Os
  estados visuais acompanham o impacto, como o HUD, sem expirar antecipadamente.
- Golpes interceptados/reduzidos têm som defensivo e texto; impactos têm pequenas
  partículas elementais. Cura líquida aparece no atacante. Os números continuam
  representando a variação de HP da ação, incluindo dano contínuo (modelo anterior).

Arena é dado de apresentação, não persistido nem enviado como regra. A sequência
existente continua controlando seleção/bloqueio de comandos e callbacks únicos.
Menus/campamento não foram redesenhados neste bloco.

## Verificação e publicação futura

Testes focados: engine e servidor (status, dano, AP, ação inválida), renderização
das 12 arenas nas duas proporções, sincronização de defesa/impacto, rotação,
cancelamento e prevenção de replay. Galeria local inspecionada em
`app/build/gameplay-preview/arenas.png` (arte sem HUD, ordem do enum ArenaTheme).
Quatro casos atuais de UI do Treino/Multiplayer aprovados nas duas orientações;
capturas do Treino em `app/build/art-preview/defend-360.png` e `defend-568.png`
inspecionadas (fontes de teste). Um caso legado em `multiplayer_battle_screen_test`
não simulava SharedPreferences, necessário agora para sessão, e foi interrompido
antes de conectar; revisão dessa suíte antiga permanece pendente. Os testes atuais
usados foram `multiplayer_prototype_test` e os casos de defesa de `tactical_battle_test`.

Faltam playtest/balanceamento em celulares reais, desempenho em aparelhos fracos
e partida real entre dois dispositivos. Publicar backend e APK coordenadamente:
clientes antigos não conhecem as novas dicas; servidor antigo não aplica a regra.
Não foi publicado nada neste bloco; assinatura definitiva continua pendente.
