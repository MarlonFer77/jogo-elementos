# Dungeon — Ruína Elemental

Primeiro modo solo offline, acessível em **Dungeon · Solo** na Home.
Perfil separado dos slots A/B do Treino e da identidade Multiplayer; XP local
nunca é enviado ao servidor como recompensa confiável.

## Loop

Escolher 2 elementos → acampamento → enfrentar uma sala → receber XP →
gastar pontos na árvore → próxima sala ou nova expedição.

São **10 salas**, totalizando **1.000 XP**. A resistência aumenta a cada sala;
os patamares seguintes também ampliam o repertório e o AP inicial dos inimigos.

| Sala | Inimigo | HP | AP inicial | XP |
| --- | --- | ---: | ---: | ---: |
| 1 | Vigia das Brasas | 35 | 0 | 40 |
| 2 | Sentinela Glacial | 55 | 0 | 60 |
| 3 | Golem do Pântano | 65 | 0 | 70 |
| 4 | Arauto Solar | 75 | 1 | 80 |
| 5 | Vigia da Tempestade | 85 | 1 | 90 |
| 6 | Oráculo Sombrio | 95 | 1 | 100 |
| 7 | Guardião do Bosque | 105 | 2 | 110 |
| 8 | Senhor dos Trovões | 115 | 2 | 120 |
| 9 | Soberano da Peste | 130 | 2 | 150 |
| 10 | Guardião da Ruína | 150 | 3 | 180 |

- Salas 1–3 equipam uma habilidade; 4–6, duas; 7–10, três.
- Elites saudáveis conservam AP para suas conjurações de três elementos.
  Dano, custo, regeneração e status continuam seguindo as mesmas regras.
- Nível 1 começa em 0 XP. Próximo nível exige 100 XP; cada patamar custa
  mais 50 XP que o anterior. Cada nível concede 1 ponto.
- Cada nó custa 1 ponto e respeita os pré-requisitos da árvore. Os dois
  elementos iniciais são gratuitos. Precisão/multigolpe ainda sem efeito
  ficam indisponíveis para compra, sem alterar a árvore dos outros modos.
- Os bônus existentes da árvore se aplicam normalmente. Limites de 4 elementos
  e 3 habilidades equipadas são preservados.
- HP restante persiste entre salas; fogueira cura até 25. Seu AP reinicia em 0;
  inimigos começam com o AP listado acima. Status reiniciam para ambos.
- Derrota encerra a tentativa, não remove XP/desbloqueios já salvos.
- Sair/fechar durante uma sala reinicia esse encontro no checkpoint, sem XP.
  Descobertas/equipamento da sala são salvos ao concluir vitória ou derrota.

## Integração e persistência

`DungeonProgress` contém regras de nível/pontos. `DungeonCampaign` controla
encontros e checkpoints; `DungeonOpponent` escolhe ações legais pelas prévias.
`TrainingScreen` reutiliza combate/HUD/selos com uma sessão opcional de dungeon,
desativa controle do inimigo e não grava nos slots do Treino neste modo.

`dungeon_profile_v1` guarda um único documento JSON em SharedPreferences.
Recompensa e avanço de sala são gravados juntos; o estado em memória só avança
após sucesso. Resultado duplicado/antigo é rejeitado. Save ilegível bloqueia
a carga com aviso, sem sobrescrever dados. Não há backup em nuvem neste bloco.
Saves anteriores de três salas mantêm XP, pontos, conquistas e índice da sala;
uma tentativa ativa continua pela lista ampliada, sem recompensar salas antigas.

IA tem HP definido por sala, mas usa os mesmos custos/status/dano. Ela escolhe
básicos, habilidade equipada ou defesa; conjurações são telegrafadas na arena.
O jogador continua executando seus selos. Evolução da árvore ocorre fora da luta.

Limites atuais: uma ruína fixa, sem geração procedural, dificuldade adaptativa
ou integração de recompensas online. Balanceamento inicial requer playtest real.
