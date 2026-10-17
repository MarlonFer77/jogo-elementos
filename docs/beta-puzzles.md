# Ecos da restauração — BETA 3D

Implementado em 16/10/2026 e incluído na [v0.38.0](release-v0.38.0.md).

## Loop

Combate → ler inscrição → explorar selos A–D → selecionar Solo/Mistura →
Sintonizar perto do selo → restaurar cenário → atravessar passagem.
A última área permanece explorável após combate e puzzle. A vitória acontece
somente ao permanecer no portal aberto por 550ms; sair da zona ou pausar cancela
a travessia. A saída final não cria outra área nem concede cura/XP extra.

| Área | Puzzle | Passos |
| --- | --- | --- |
| Átrio das Raízes | Associar chuva e chão a elementos | 2 |
| Aqueduto Velado | Seguir o curso de uma corrente | 3 |
| Santuário dos Ecos | Ler a inscrição em ordem inversa | 4 |
| Jardins Suspensos | Interpretar receitas alquímicas | 5 |
| Forja das Marés | Repetir uma sequência espelhada | 6 |
| Coroa da Aurora | Combinar os elementos dos selos anteriores | 7 |

## Regras e UX

- Selos etéreos no chão, sem colisão. Interação a até 1,35 unidade.
- Apenas após eliminar inimigos; bloqueada durante chegada, pausa, ataque,
  conjuração, rolamento ou fim da sessão. Intervalo de 0,4s entre tentativas.
- Ordem dos passos importa; ordem dos dois elementos de uma receita não.
- Erros preservam passos concluídos. Pistas opcionais revelam o próximo passo.
- Pistas solicitadas permanecem consultáveis na Inscrição, inclusive após pausa
  ou erro. Marcador/anel dourado e seta indicam o selo apenas após pedir ajuda.
  Ao acertar, a indicação some: o próximo passo não é revelado automaticamente.
- Inscrição registra os ecos já ativados. O selo próximo mostra “aqui” e a cor
  dos elementos selecionados; os demais mostram a quantidade de ecos registrados.
- Sem limite de tempo ou consumo de mana; não exige combo descoberto/equipado.
  Ritual não desbloqueia ataques nem concede XP/itens: combate mantém suas regras.
- Botões de combate viram Sintonizar/Inscrição sem aumentar o painel.
  Teclado: E sintoniza; H revela pista; elementos e Mistura continuam iguais.
- Progresso de puzzles/restauração existe só nesta expedição. Reiniciar/sair
  descarta tudo; sem migração, sincronização ou alteração de outros saves.

## Visual e limites

Após a primeira restauração, a paleta mais clara, flores, cristais, vitrais e
lanternas acompanham as fases seguintes durante toda a expedição. O cenário não
volta ao visual adormecido ao viajar; cada região conserva sua identidade.
Os puzzles e portais continuam independentes: herdar o visual não resolve selos
nem libera passagens. Reiniciar a expedição ainda reinicia essa progressão.
Jardins têm terraços arborizados; Forja, cristais/cascatas;
Coroa, torres com telhados azuis e arco monumental. Decoração sólida permanece
fora da arena; restauração não altera colisões ou configurações gráficas.

Fantasia estilizada original, não equivalência técnica aos gráficos de Genshin.
Mantido o renderizador projetado em software. Cache limitado a seis regiões ×
dois estados, sem reconstrução por frame; teste limita cada cena a 2600 faces.
Movimento reduzido mantém selos legíveis sem girar cristais ambientais.
Uma onda discreta marca a restauração durante a abertura da passagem; fica
desligada com movimento reduzido. Avisos na horizontal ficam à esquerda,
fora dos controles de ação.

52 testes focados passaram; checados caminhos dos altares, seis áreas completas,
guardas de interação, HUD em 320×568/360×640/640×360, render em duas orientações
e diferença antes/depois da restauração. Prévias em app/build/gameplay-preview/:
beta-puzzles-*.png e beta-restoration-*.png. Ainda falta validação real de FPS,
legibilidade, dificuldade e duração da expedição no Android.

Polimento seguinte: 43 testes focados passaram, incluindo pistas sem spoilers,
histórico, exploração final, cancelamento da saída ao pausar e vitória única.
