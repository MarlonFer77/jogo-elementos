# Abertura global do Elementos — Anjo da Aurora

Incluído na v0.41.0, publicada como Latest em 22/10/2026.

Correção posterior (ainda não publicada): abertura → verificação da versão →
conta do Elementos → menu de todos os modos. Uma sessão já confirmada abre o
menu diretamente, sem repetir cadastro. A arte do anjo/goblins é a abertura
do aplicativo, não a entrada exclusiva do BETA; a legenda agora é global.

- Cena procedural de oito segundos: defesa luminosa, corte giratório,
  rolamento, conjuração e recuo dos três goblins. Ruínas, bandeiras e partículas
  limitadas, sombras, pequenas pausas de contato e tremor discreto.
- Reutiliza as modelagens de Anjo/goblins do BETA; a instância de poses não
  inicia nem atualiza o engine e não acessa saves, inventário ou recompensas.
- `loading_battle_art.dart` integra a biblioteca de desenho existente;
  `loading_battle_scene.dart` controla animação, áudio e layout.
- `UpdateGateScreen` continua responsável pela consulta e atualização.
  Consulta manual não reproduz a abertura. Erro ou nova versão substitui a
  cena imediatamente, preservando retry, download, checksum e instalador.
- Preferências já são carregadas pelo `main.dart`. Barra em duas etapas:
  preferências concluídas + consulta da versão. A consulta é indeterminada;
  nenhum percentual fictício de download ou de recursos é exibido.
- Quando pronto: pode entrar por toque ou automaticamente após três segundos
  de apresentação ativa. Se a rede demorar, a coreografia repete; a intro nunca
  dispensa o resultado da consulta. Falha permite continuar explicitamente
  sem verificar, como antes. Entrada de conta/menu usa fade de 240 ms.
- Horizontal/vertical sem scroll. Segundo plano pausa animação e corta os
  efeitos da abertura; preferências de volume/mudo são respeitadas. Redução
  de movimento usa quadro estático, sem som, tremor ou espera obrigatória.
- Recursos de desenho/áudio são liberados ao sair; não há novas dependências,
  imagens baixadas, mudança de backend ou desbloqueio da skin apresentada.

Validação: 15 testes focados da abertura e do atualizador passaram; análise
estática limpa e prévias de 320×568/568×320 conferidas visualmente.
Fluidez/áudio reais ainda dependem do Android.
