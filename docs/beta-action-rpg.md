# BETA TEST — Ruína dos Ecos

Primeiro protótipo solo de ação 3D dentro do app, implementado em 09/10/2026.
Não substitui o combate por turnos. Base publicada v0.33.0; os polimentos
posteriores estão locais, ainda sem novo APK, release, deploy ou assinatura.

## Acesso

Menu inicial → BETA TEST → senha de seis dígitos definida pelo responsável.
O zero inicial faz parte da senha. Nova entrada exige a senha novamente;
não há desbloqueio permanente nem armazenamento da senha digitada.

**Trava local para testadores, não autenticação segura:** a verificação está
no cliente e pode ser encontrada/contornada inspecionando o APK. Não concede
privilégios online. Distribuição restrita real precisará de autorização no
servidor ou canal fechado, em outro bloco.

## Recorte jogável

- Ruína low-poly, câmera em perspectiva seguindo o herói, colisões com colunas
  e limites. Herói e criaturas usam malhas XYZ construídas no código, não sprites.
- Joystick multi-touch, espada, magia e esquiva. Mira assistida no cone à frente,
  priorizando alvos ao alcance da espada, direção e proximidade, sem mirar através
  de colunas. Espada atinge uma vez por ação, recarga de 0,52s.
- Magia canaliza por 0,35s, custa 25 MP, recarrega em 1,25s. Regeneração: 9 MP/s.
- Fogo: projétil + queimadura. Água: lentidão + cura de 8 HP somente ao acertar.
  Vento: explosão curta com interrupção/afastamento. Terra: impacto e proteção
  de 50% por dois segundos. São magias individuais; combos 3D ainda não existem.
- Esquiva direcional: invulnerabilidade breve, recarga de 1,6s; não atravessa
  colunas ou bordas. Faixa, setor frontal e círculo anunciam os ataques inimigos.
- Três encontros: goblins, grupo com bruto e guardião com escolta. Entre grupos,
  recuperação de até 20 HP/25 MP. XP aumenta nível, vitalidade e dano na sessão.
- Vitória/derrota permitem reiniciar. Sair descarta progresso experimental.
  Não grava XP, elementos, habilidades ou recompensas em outros perfis.
- Respeita volume/mudo global. Trocar de aplicativo pausa; retomada explícita
  limpa movimento anterior. Voltar durante a ação abre a pausa antes de sair.

Teclado: WASD/setas, J (espada), K (magia), Espaço (esquiva), 1–4 (elemento),
Esc (pausa). No celular todas essas ações possuem controles de toque.

## Integração e limites

- `beta_session.dart`: regras puras Dart, tempo em subpassos limitados, IA,
  colisão, projéteis, recursos e progressão temporária.
- `beta_game.dart`: loop Flame, áudio existente e HUD atualizado a 10 Hz.
- `beta_arena_painter.dart`: malhas, câmera, projeção, iluminação direcional,
  ordenação de faces, animação de membros e feedback visual.
- `beta_screen.dart` / `beta_controls.dart`: HUD, ciclo de vida e controles.
- `beta_access_screen.dart`: trava local. Home: botão novo e grade compacta.

Sem dependências novas, serviços, assets externos ou mudanças no engine por
turnos/backend. Renderizador pequeno usando [Canvas do Flutter](https://api.flutter.dev/flutter/dart-ui/Canvas-class.html)
para projetar malhas. Não é motor 3D geral: sem depth buffer, modelos esqueléticos,
salto/física vertical ou mundo aberto. Geometria cruzada poderá exigir renderizador
mais robusto no futuro. Desempenho de produção ainda não está demonstrado.

## Verificação e próximo trabalho

### Critérios de liberação do beta atual

Status: rodada de acabamento local fechada para playtest, **não aprovado para
produção**. Este aceite cobre o modo solo de três encontros com progresso de
sessão; não significa um RPG completo com save, combos 3D ou exploração.

- [x] Controles, alvo/colisões, dano, pausa, vitória/derrota e reinício verificados
  localmente; HP, efeitos, áreas inimigas e animações têm apresentação revisada.
- [x] Entrada curta, guia consultável, saída com confirmação e movimento reduzido.
- [x] 37 testes beta aprovados no conjunto; análise Dart limpa; previews revistos.
- [ ] APK candidato com assinatura compatível; instalar por atualização e conferir
  que perfis de Treino/Dungeon/Multiplayer continuam disponíveis.
- [ ] Android real: concluir três encontros, perder/reiniciar, cancelar/confirmar
  saída, girar o aparelho segurando o joystick e alternar aplicativos. Nenhum
  comando preso, repetição de ação ou avanço enquanto pausado.
- [ ] Sessão prolongada nos aparelhos de teste: conferir fluidez, áudio/mudo,
  legibilidade e aquecimento percebido. Coletar diagnóstico local para investigar
  travadas; suas métricas não provam FPS apresentado nem temperatura física.
- [ ] Corrigir e repetir os casos com falha; só então aprovar a publicação.

Não gerar APK/publicar automaticamente. Combos 3D, save e exploração continuam
no roadmap posterior, não são preenchidos por polimento visual. A senha local
continua sendo conveniência para testadores, não proteção de acesso em produção.

### Entrada, pausa e saída — fechamento do fluxo

- Entrada apresenta objetivo e controles essenciais sem o texto longo inicial;
  HUD de combate fica oculto até iniciar. Guia expansível disponível na entrada,
  pausa e resultado: elementos, custo de mana, mira e como evitar cada inimigo.
- Voltar durante a ação pausa. Na pausa, voltar ou sair abre confirmação explícita
  sobre perda da sessão; cancelar permanece pausado e preserva recursos. Resultado
  informa o encontro da derrota ou a conclusão dos três encontros. Outros saves
  não são modificados. Pintor da tela de acesso tem ciclo de vida controlado.
- Opção de movimento reduzido do sistema remove tremor e antecipação da câmera,
  destaque de escala dos números e pressão animada dos botões. Mantém movimento
  de acompanhamento e animações de combate necessárias; não altera regras.
- Preferência preservada ao reiniciar. Verificados navegação/cancelamento, comandos
  simultâneos, transparência do efeito de câmera e retorno aos menus.
  Previews `beta-menu-{320,360,640}.png`, `beta-guide-polish.png` e
  `beta-exit-polish.png`. Avaliação física continua pendente para o final.

### Vida, dano e recuperação — continuação do polimento

- HP numérico e preenchimento sólido permanecem reais. Rastro do dano segura
  por 180ms e recolhe a 1,8 barras/s, sem atraso no acerto. Usa o relógio visual
  existente: pausa congela; reiniciar/sair descarta; nenhum timer independente.
- Cura ou mudança de HP máximo limpa o rastro imediatamente. Dano contínuo não
  reinicia indefinidamente a espera. Memória dos inimigos descartada ao trocar
  encontros; barra do guardião maior para facilitar leitura.
- HUD atualiza no mesmo frame lógico de dano/cura, além da atualização habitual
  de 10Hz. Com HP positivo <=25%, cor coral e dica “Água cura ao acertar” ocupam
  a linha já existente; sem piscar a tela, aumentar o painel ou bloquear controles.
- Feedback compartilhado apenas na apresentação em `beta_health_feedback.dart`;
  não muda HP, cura, dano, mana, progressão ou saves. Treino/Multiplayer intactos.
- 11 testes focados aprovados, análise limpa e previews revisados em vertical e
  horizontal: `beta-vitals-{320,360,640}.png` e `beta-health-polish.png`.
  Sem APK/release/backend; avaliação física continua reservada para o final.

### Contato e controles — continuação do polimento

- Marca física de cinco traços por 220ms no ponto do acerto confirmado. Cor
  elemental ao atingir, coral ao receber dano; composta acima dos corpos para
  não desaparecer dentro da malha. Golpes perdidos/bloqueados não geram acerto.
- Números têm destaque inicial de 120ms e desaparecem nos últimos 180ms,
  mantendo a duração existente de 650ms. Escala/alpha não criam entradas novas
  no cache de texto; a composição de transparência fica restrita ao rótulo.
- Botões encolhem levemente ao toque, mantendo área de contato fixa. Um pedido
  por contato: segurar não repete, outro dedo não solta o primeiro e cancelar
  libera o estado visual. Magia mostra ícone/cor/nome do elemento ativo;
  comandos na fila têm borda âmbar, sem ampliar o painel.
- 8 testes focados aprovados (6 telas/controles, 2 renderização/cache), análise
  limpa e capturas 320/640 revisadas. Sequência em `beta-contact-polish.png`.
  Sem regras novas, APK/release, backend ou alteração dos outros modos.
- Conforme solicitado, playtest no celular fica para o final dos polimentos;
  continuar acabamento local sem tratar essa validação pendente como bloqueio.

### Esquiva e transição de magia — 13/10/2026

- Esquiva inclina o corpo para frente, lateralmente ou para trás, conforme a
  direção comprometida pela regra. Entrada/saída suaves durante os mesmos 240ms;
  câmera acompanha a esquiva mesmo se o joystick mudar durante o deslocamento.
- Braço retorna gradualmente ao repouso durante 140ms após a conjuração. Somente
  apresentação: não bloqueia comandos, congela na pausa e cede imediatamente
  à espada, esquiva ou nova magia. Dano, mana, recargas e invulnerabilidade iguais.
- 31 testes beta aprovados antes da alteração; 25 verificações afetadas passaram
  depois, incluindo direção da esquiva preservada ao inverter o joystick.
  Análise Dart limpa; poses conferidas em `beta-motion-polish.png`.
- Sem Android conectado: suavidade percebida/FPS físicos ainda pendentes.
  Alterações locais após v0.33.0, sem APK, publicação ou mudanças no backend.

### Câmera e leitura de perigo — 13/10/2026

- Câmera antecipa suavemente a direção de movimento ou o alvo a até 6 unidades;
  deslocamento de foco limitado a 1,2 por eixo, mantendo perspectiva fixa.
- Avisos no chão ficam mais fortes quando o jogador está na área de um golpe
  em preparação com linha livre. Reutilizados `attackArea.contains` e `clearLine`;
  não há regra de acerto paralela. Fora da área, o contorno permanece âmbar.
- “SAIA DA ÁREA” aparece abaixo do personagem, sem encobrir a arma ou o inimigo.
  Colunas, cancelamento e morte removem o alerta; não há alerta após o golpe.
  Invulnerabilidade temporária não oculta a área, pois pode terminar antes do
  impacto. O aviso de perigo tem prioridade sobre o texto de proteção, cujas
  pedras orbitais continuam visíveis.
- Somente apresentação alterada; dano, alcance, recarga e persistência mantidos.
  7 verificações existentes aprovadas (5 telas, 2 renderização/cache), análise
  limpa e capturas vertical/horizontal revisadas. Prévias em `beta-danger-polish.png`
  e `beta-danger-{320,360,640}.png`. Sensação de câmera pendente no celular.
  Este bloco está local, posterior à release v0.33.0.

### Resposta dos comandos e leitura do combate

- Corrigido comando antecipado que expirava antes de atualizar o último frame
  da animação. A intenção única de até 180ms é consumida depois dos timers e
  revalida recursos; sem autofire, gasto duplicado ou alteração de recargas.
- Botões mostram o motivo de espera: Conjurando, Em ataque, Esquivando,
  Sem mana ou Na fila. Estado indisponível mantém contraste legível.
- Impactos de fogo/água/vento/terra reutilizam sons elementais do catálogo.
  Golpe físico mantém som original; magia bloqueada não emite som de acerto.
  Respeitados volume/mudo/limite de vozes existentes; sem novos arquivos de áudio.
- Pausa de 2s entre encontros agora informa contagem e recuperação existente
  (até +20 HP/+25 MP). Timer congela na pausa e não aparece após o encontro final.
  Avisos ficam abaixo da altura real do HUD, não numa posição vertical fixa.
- Dano, mana, recompensa, progressão e outros modos preservados. 28 testes
  focados aprovados (23 regras e 5 telas), análise limpa e capturas 320×568,
  360×640 e 640×360 revisadas. Limite de entrada simulado a 30/60/120 FPS não é
  medição de desempenho. Sem APK/release; áudio/fluidez físicos ainda pendentes.

### Estabilidade e preparação para medir desempenho

- Rotação/redimensionamento pausa a sessão e limpa entrada; retomar exige novo
  toque. Pausa não consome recargas nem movimento. Toques de controles removidos
  são ignorados. Texto da esquiva limitado ao espaço do botão.
- Loop Flame para na entrada, pausa e resultado (após a animação final). Voltar
  ou reiniciar libera textos/caches; não fica renderizando por trás do menu.
- Layout de textos reutilizado em cache LRU de até 64 entradas; trigonometria
  calculada uma vez por caixa/ator/cristal em vez de por vértice. Visual e regras
  mantidos. Isto reduz trabalho repetido, mas não comprova ganho de FPS no aparelho.
- Menu → **Diagnóstico local → Medir desempenho** (desligado por padrão). Jogue,
  pause e use **Copiar diagnóstico**. Últimas 240 amostras: frequência do loop,
  maior intervalo, p95 de construção UI e rasterização Flutter. FPS do loop não
  é FPS apresentado; rasterização não é medição direta de execução da GPU.
- Coleta somente jogando; lotes atrasados anteriores à retomada são descartados.
  Dados temporários, sem gravação, envio ou identificadores. Cópia inclui versão,
  modo debug/profile/release, plataforma, tamanho lógico/DPR e encontro.
- Verificação local: 8 testes focados (5 telas/acesso, 2 renderização/cache,
  1 métricas), análise limpa e capturas revisadas. Simulações verificam lógica
  de coleta, não performance física. Sem APK, publicação ou backend neste bloco.

Pendente: APK release em Android real; informar modelo, duração da sessão e
problema observado. Experimentar encontros, rotação segurando joystick, alternar
aplicativos, derrota/reinício e sessão prolongada. Observar fluidez/aquecimento
separadamente — diagnóstico não mede temperatura nem bateria. Sem aparelho ADB
conectado nesta etapa. Playtest adiado pelo usuário para o fim dos polimentos;
acabamento local pode continuar, sem considerar desempenho físico validado.

### Leitura dos inimigos — polimento atual

- Goblin: estocada em faixa de 2,4 × 0,84 unidades, preparação de 0,7s e
  recuperação de 0,36s. Desvio lateral evita a estocada.
- Bruto: machado em varredura frontal, alcance de 2,7 unidades e arco de 136,8°,
  preparação de 0,85s e recuperação de 0,55s. Contornar evita a varredura.
- Guardião: marreta/armadura de pedra, impacto circular de raio 2,1 no ponto
  marcado, preparação de 1,05s e recuperação de 0,75s. Sair da área evita o impacto.
- `BetaAttackArea` é o compromisso imutável de posição/direção/forma usado tanto
  pelo teste de dano quanto pelo desenho. Mede o centro no chão do jogador;
  não há dano fora da marca pela simples interseção da roupa ou arma do avatar.
  Colunas continuam bloqueando golpes. Vento/morte cancelam a ameaça.
- Contorno preenche durante a preparação; depois do golpe, resíduo apagado e
  indicador verde/“Recuperando” mostram a janela de resposta sem bônus de dano.
  Poses/armas e áudio de golpe usam os recursos existentes, sem novas dependências.
- HP, dano (12 goblin/bruto, 25 guardião), recompensas, três encontros e regras do
  jogador preservados. Formas e tempos inimigos são mudanças locais de balanceamento;
  precisam de playtest físico. Nenhuma alteração no Treino/Dungeon/Multiplayer.
- Verificação: 25 testes focados aprovados (20 regras, 4 telas/acesso,
  1 renderização), análise Dart limpa; poses em `beta-enemy-polish.png` e telas
  320×568, 360×640 e 640×360 inspecionadas. Sem APK/release neste bloco.

### Continuação — mira e identidade elemental

- Joystick orienta a mira imediatamente; não escolhe um inimigo atrás do herói.
  Alvo e direção ficam comprometidos durante a ação, sem projéteis perseguidores.
  Marca dourada completa indica alcance da espada; azul parcial indica distância.
  Botão orienta aproximação/direção; nome, vida e status identificam o alvo.
- Disparo usa o primeiro contato de toda a trajetória do frame, independente da
  ordem dos inimigos. Colunas/bordas bloqueiam antes de quem está atrás; empate
  favorece o obstáculo. Impacto bloqueado não cura, aplica status ou causa dano.
- Fogo com núcleo/brasa, água facetada/respingos, vento em espiral/onda, terra
  rochosa/fragmentos. Canalização usa a mesma identidade do disparo. Área do vento
  é desenhada no contato real, sem multiplicar explosões nos alvos secundários.
- Cura mostra apenas HP efetivamente restaurado; proteção tem pedras orbitais,
  indicador de duração e arco decrescente. Números separados do nome do inimigo.
- Mantidos dano, mana, recargas, duração dos status e progressão. Apenas beta;
  sem dependências/assets externos, mudanças no backend ou geração de APK.
- Verificação atual: 22 testes focados aprovados (17 regras, 4 telas/acesso,
  1 renderização), análise Dart limpa e previews vertical/horizontal/magias
  inspecionados. Ainda pendente playtest e desempenho em Android real.

### Polimento após playtest — 09/10/2026

- Braços/pernas articulados por segmentos, mãos presas à arma, cortes alternados,
  preparação, recuperação e rastro curto. Espada mantém dano e recarga (0,52s);
  animação dura 0,44s, contato aos 0,16s e cone frontal mais coerente com a lâmina.
- Inimigos terminam o golpe anunciado e recuperam por 0,36s antes de perseguir.
  Reação ao dano, queda de 0,65s e resultado após 0,7s, sem repetir XP ou ataques.
- Câmera interpolada, leve impacto e passos baseados em deslocamento real.
  Chão/marcações desenhados antes das malhas para não recortar pernas e armas.
- Colisão entre corpos, saída de sobreposições e vento deslocando em 0,2s,
  respeitando obstáculos. Esquiva atravessa criaturas, não paredes/colunas.
- Botões respondem ao contato, mostram recarga e aceitam uma intenção até 0,18s
  antes de liberar a ação. Não há autofire; pausa, esquiva ou troca de elemento
  cancelam essa intenção. Custo e disponibilidade são revalidados na execução.
- Joystick ignora tremor central; HUD menor na horizontal. Background durante
  a transição de resultado exibe o resultado sem prender a interface.

Verificação deste bloco: 17 testes focados (12 regras, 4 tela/acesso, 1 renderização).
Capturas vertical/horizontal e sequência de poses em
`app/build/gameplay-preview/`, geradas com `ELEMENTOS_ART_PREVIEW=1`.
Sem novas dependências, persistência, backend, APK ou publicação. Ainda requer
novo playtest físico: suavidade percebida e FPS não são comprovados pelos testes.

### Verificação original do protótipo

17 testes focados (regras, menu e UI): dano único, recargas, mana, status,
colisões/desvio da IA, pausa, vitória/derrota, senha com zero inicial, reentrada,
multi-touch e ausência de escritas nos perfis existentes. Previews inspecionados
em 320×568, 360×640 e 640×360. `ELEMENTOS_ART_PREVIEW=1` habilita capturas no
teste `beta_screen_test.dart`.

Pendente: playtest e medição de FPS/bateria/temperatura em Android real.
Prioridade seguinte: reproduzir bugs restantes com vídeo/modelo do aparelho e
medir desempenho antes de ampliar combos de ação, exploração e progressão.
