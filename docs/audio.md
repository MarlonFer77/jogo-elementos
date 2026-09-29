# Áudio do Elementos

## Biblioteca e licença

19 efeitos novos (197.629 bytes, aproximadamente 193 KiB), selecionados dos
pacotes gratuitos do Kenney, todos CC0. Nenhuma dependência nova de runtime.

- RPG Audio: https://kenney.nl/assets/rpg-audio
- Impact Sounds: https://kenney.nl/assets/impact-sounds
- Interface Sounds: https://kenney.nl/assets/interface-sounds
- CC0: https://creativecommons.org/publicdomain/zero/1.0/
- Licença incluída no APK: `assets/audio/KENNEY_LICENSE.txt`.

Arquivos OGG originais, apenas renomeados com prefixo `kenney_`.
Volumes por efeito ajustados na reprodução; não houve edição das amostras.

| Arquivo local | Pacote / original |
| --- | --- |
| kenney_knifeSlice.ogg | rpg / knifeSlice.ogg |
| kenney_knifeSlice2.ogg | rpg / knifeSlice2.ogg |
| kenney_cloth3.ogg | rpg / cloth3.ogg |
| kenney_impactMining_000.ogg | impact / impactMining_000.ogg |
| kenney_impactWood_heavy_000.ogg | impact / impactWood_heavy_000.ogg |
| kenney_impactTin_medium_000.ogg | impact / impactTin_medium_000.ogg |
| kenney_impactSoft_heavy_000.ogg | impact / impactSoft_heavy_000.ogg |
| kenney_impactGlass_medium_000.ogg | impact / impactGlass_medium_000.ogg |
| kenney_impactMetal_light_000.ogg | impact / impactMetal_light_000.ogg |
| kenney_maximize_005.ogg | interface / maximize_005.ogg |
| kenney_drop_003.ogg | interface / drop_003.ogg |
| kenney_glitch_002.ogg | interface / glitch_002.ogg |
| kenney_minimize_005.ogg | interface / minimize_005.ogg |
| kenney_glass_005.ogg | interface / glass_005.ogg |
| kenney_confirmation_002.ogg | interface / confirmation_002.ogg |
| kenney_confirmation_004.ogg | interface / confirmation_004.ogg |
| kenney_tick_001.ogg | interface / tick_001.ogg |
| kenney_error_006.ogg | interface / error_006.ogg |
| kenney_question_002.ogg | interface / question_002.ogg |

## Uso e limites

- Corte: lâmina do jogador/goblin/elfos. Pedra: golem/troll. Madeira: ent.
  Quitina: aranha/escaravelho. Tecido/asa: harpia/dragão.
- Impacto escolhe uma textura por elemento dominante, independentemente da
  ordem da receita; não sobrepõe um áudio para cada elemento.
- Fogo usa impacto abafado, gelo usa vidro, água/veneno usam gota,
  raio usa estalo digital, sombra usa tom descendente e luz usa timbre cristalino.
  São interpretações estilizadas dos samples, não gravações reais de magia
  ou vocalizações próprias das criaturas.
- Cura/purificação sem dano têm confirmações próprias; defesa, descongelar
  e selo rompido não tocam preparação ofensiva.
- Cada nó aceito do selo toca um tick discreto; aviso de tempo toca uma vez.
  Falha toca apenas ao resolver a ação, não novamente ao fechar o diálogo.
- Vitória, derrota, desbloqueio e toque de botão existentes foram preservados.
- Até 4 vozes simultâneas; repetição do mesmo efeito em menos de 65 ms é
  descartada, sem fila. Volume entre 22% e 60%; os clipes importados duram
  de 0,02 a 0,94 s. Players são liberados ao concluir ou no limite de vida.
- Todo áudio está no APK e funciona offline. A apresentação compartilhada
  atende Treino, Dungeon e Multiplayer, sem interferir no engine/servidor.
- Arquivo ausente, plugin indisponível ou falha de áudio não bloqueiam a ação.

Verificação automatizada cobre assets, seleção dos sons e sequência de combate.
A mixagem/latência precisa de avaliação auditiva em celular; não houve nova
release neste bloco.
