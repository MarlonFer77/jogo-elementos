# TASKS.md

Fonte única da verdade sobre o trabalho atual.

# NOW

Publicação v0.32.0/build 32 em preparação: BETA TEST 3D + variações da Dungeon.
Manter assinatura anterior, sem alteração/deploy do backend. Compilar pelo
workflow existente, conferir certificado/versão/hash, anexar APK à release
estável e verificar latest/atualizador. Não incluir arquivos locais de output.

Checkpoint anterior:

BETA TEST implementado localmente (09/10/2026): primeiro recorte solo de ação,
geometria 3D low-poly/perspectiva, entrada local por senha solicitada pelo usuário
(não é autenticação segura), joystick, espada elemental, quatro magias e esquiva.
Três encontros com goblins/bruto/guardião; intenção no chão, colisões/desvio de
colunas, XP/nível somente da sessão, vitória/derrota/reinício. Pausa no background,
retomada explícita e controles multi-touch. Menu compacto comporta quatro modos.
Flutter/Flame/áudio existentes, sem novas dependências. Regras puras isoladas e
nenhuma gravação nos perfis de Treino/Dungeon/Multiplayer. 17 testes focados
passaram; previews 320×568, 360×640 e 640×360 inspecionados. Pendente playtest e
FPS/bateria em Android real, refinamento de câmera/controles e futuros combos 3D.
Sem APK/release/backend/assinatura. Limites e controles: docs/beta-action-rpg.md.

Checkpoint anterior:

Variações da Dungeon implementadas localmente (08/10/2026): 30 repertórios,
três estilos por sala (ofensiva/defensiva/controle), incluindo três variantes do
dragão. Cada trecho de três salas recebe os três estilos; rota gravada antes
da primeira batalha. Mantidos 10 salas, HP/XP/AP inicial/cura e padrões legados.
Schema 3 migra 1/2 sem reset; sair/reabrir não sorteia outro encontro.
Acampamento mostra próximo desafio/repertório/dicas, permite preparar elementos
e habilidades, recolhe o mapa e usa duas colunas na horizontal. Intenção exibe
a tática. Encerrar pede confirmação. Reutilizados IA, criaturas e combate atuais.
39 testes focados aprovados; análise Dart limpa; capturas 360×640 e 568×320
inspecionadas com ícones/fontes reais. Fonte ampliada e rotação também verificadas.
Pendente playtest físico para dificuldade/duração, especialmente nas variantes
defensivas. Sem alteração nas regras do Treino/Multiplayer, backend, assinatura,
APK ou publicação. Detalhes: docs/dungeon-variations.md.

Checkpoint anterior:

Release v0.31.0/build 31 publicada como latest em 08/10/2026, reunindo os blocos
abaixo. Branch codex/release-v0.31.0; tag no commit 136c908. Actions 37770438516
concluído; APK de 57.461.942 bytes anexado, uploaded/digest SHA-256 conferidos.
APK e versão conferidos pelo SDK; certificado idêntico ao da release v0.29.0.
Render dep-db3nucegekts73fi3k2g live em 08/10/2026; health confirma revisão
136c908c2515, protocol 2, accounts true e Firestore. Smoke online passou em
3f7cad1 (código app/servidor idêntico): sessões legadas isoladas, sala/entrada,
turno/reconexão, rejeição de duplicata, abandono e perfil persistido; salas encerradas.
25 testes focados do app + 11 do servidor e typecheck passaram nesta publicação.
Dois builds anteriores compilaram, mas falharam no parser do apksigner: SDK usa
"V2 Signer"; ambos os certificados eram iguais. Parser corrigido e conferido
localmente nos dois formatos. Guard de assinatura continua obrigatório.
Atualizador real contra GitHub latest: detecta v0.31.0 a partir de v0.29.0 e
v0.30.0; reconhece v0.31.0 como atualizada, com o hash correto. Sem chave nova.
Falta playtest físico: instalar por cima, conferir saves, login/recuperação,
partida entre celulares e balanceamento. Assinatura definitiva permanece NEXT.
Notas/links/hash: docs/release-v0.31.0.md. Artefato local ignorado em
build/release-check/v0.31.0/app-release.apk. Não desinstalar para atualizar.

Checkpoint anterior:

Bênçãos da expedição implementadas localmente: nove opções, três por altar após
salas 3/6/9, uma escolha fixa por altar. Bônus ofensivos/defensivos/AP temporários,
só no jogador da Dungeon; desaparecem na derrota/conclusão/abandono. Build da
árvore continua validada antes dos grants do encontro. Mantidas 10 salas/cura 25.
Schema 2 na chave existente, migração do schema 1 sem reset e altares alcançados
oferecidos ao retomar. Entrada bloqueada até escolha salva; retry/duplo toque
não duplicam benefícios. Cartas responsivas, seleção confirmada, consulta de
bênçãos no acampamento/batalha e feedback sonoro existente.
29 testes focados aprovados (regras, persistência, 10 salas, UI/rotação), análise
Dart limpa, capturas dos altares inspecionadas. Detalhes: docs/dungeon-blessings.md.
Sem alteração no engine/backend/Multiplayer neste bloco; trabalhos locais anteriores
preservados. Falta playtest de balanceamento nos celulares. Sem APK/release/deploy.

Checkpoint anterior:

Gameplay/cenários implementados localmente (07/10/2026): Água básica apaga a
própria Queimadura; Natureza básica neutraliza o próprio Veneno, antes dos ticks,
com dano-base 3 em vez de 5 quando recupera. Dart/servidor, prévias, botões e guia
sincronizados. Dez arenas próprias da Dungeon + Treino/Multiplayer, clima leve,
contornos de Defesa/Escudo no momento correto, partículas de impacto e cura.
Engine e servidor: 12 testes focados cada; cenas/sequências: 42 aprovados.
Quatro casos atuais de controles Treino/Multiplayer nas duas orientações passaram;
capturas do Treino inspecionadas (fontes de teste). Um caso legado de multiplayer
sem mock de SharedPreferences travou antes de conectar; suíte antiga precisa
atualizar fixtures de sessão, não foi usada como evidência de partida online.
Análise Dart/typecheck TS limpos; galeria renderizada e inspecionada. Detalhes em
docs/elemental-counterplay-arenas.md. Saves e trabalhos anteriores preservados.
Faltam playtest de balanceamento/desempenho em celulares e partida real online.
Sem APK, commit, push ou deploy. Assinatura permanece NEXT.

Checkpoint anterior:

Operação/atualização confiáveis implementadas localmente (07/10/2026): consulta
manual no menu, falhas explícitas com retry/continuação offline, validação do
asset oficial e digest SHA-256 passado ao OTA. Mensagens de instalação/erro e
limpeza de stream encerrado para permitir nova tentativa. Backend impede início
em produção sem Firestore/projeto e expõe revisão do commit no health. Workflow
manual limita concorrência/tempo/permissões e falha se faltar APK.
19 testes Dart focados e 6 de backend aprovados; análise Dart e typecheck TS limpos.
Roteiro/limitações: docs/reliable-updates.md. Sem APK, commit, push ou deploy.
Falta validar instalação/rede/permissão em Android real. Assinatura e alertas
anteriores de dependências/actions não foram alterados.

Checkpoint anterior:

Backup e proteção da progressão implementados localmente. Treino/Dungeon mantêm
uma cópia anterior válida, migram as chaves existentes sem reset, serializam
gravações e avisam sobre recuperação/falha. Save ilegível sem backup bloqueia
o carregamento sem apagar dados; versões futuras não são rebaixadas.
Firestore mantém elementosProfileBackups na mesma transação do resultado,
valida perfis e recupera o anterior quando necessário. Novas salas registram
turnos/revisão de origem: encerramentos somam apenas ganhos próprios, preservam
descobertas/talentos e impedem troca de equipamento por uma sala desatualizada.
Salas legadas usam máximo conservador de turnos; escolhas iniciais simultâneas
não liberam elementos acima do gate. Sem escrita extra em polling.
Testes focados de stores/recuperação e tela de erro aprovados; análise Dart e
typecheck TS sem erros. Corrigida retenção da fila assíncrona após concluir uma
operação (teste com tela seguido de stores). Detalhes em docs/progress-backups.md.
Sem APK, commit, push ou deploy neste bloco. Falta validação em aparelho/Firestore
real; cópias locais não sobrevivem à desinstalação e o backup online não é externo.

Checkpoint anterior:

Identidade recuperável/login implementado localmente: cadastro, confirmação de
e-mail, recuperação, logout, refresh protegido e vínculo transacional do perfil.
Testes focados com Firebase simulado e análise estática aprovados. Em 05/10/2026,
confirmado no console do projeto elements-1173d: provedor E-mail/senha ativado
pelo usuário. FIREBASE_API_KEY configurada e confirmada no GitHub com a chave
de cliente existente do mesmo projeto; nenhuma permissão Firebase ampliada.
Publicação autorizada: v0.30.0+30, commit 7c509f3, branch codex/release-v0.30.0.
Backend publicado no Render (dep-db1r4tmgekts73f40nug): /health confirmou
accounts:true e persistence:firestore; /account sem autenticação retornou 401.
APK gerado com sucesso no Actions 37323904719 (0.30.0/build 30, Android 7+).
Certificado SHA-256 comparado com APK v0.29.0: idêntico; ambos verificados pelo
apksigner. Artefato local ignorado: build/release-check/v0.30.0/app-release.apk.
Falta validar login, recuperação, vínculo e partida em dois celulares, além da
instalação por cima. Nenhuma release GitHub publicada; APK disponível no Actions.
Auditoria de dependências apontou dois alertas moderados indiretos (gaxios/uuid,
GHSA-w5hq-g745-h8pq); correção pendente, sem mudança de pacotes neste deploy.
Actions também avisou sobre versões antigas das actions e futura troca da imagem
ubuntu-latest; revisar no bloco de operação, sem alterar a assinatura existente.
Detalhes/limitações: docs/recoverable-identity.md.
Backup, operação e assinatura permanecem NEXT.

Checkpoint anterior:

Checkpoint: abandono multiplayer implementado localmente. Sala/preparação 5 min,
turno 90 s, desistência confirmada, cancelamento sem vencedor e resultado pelo
servidor. Prazos sobrevivem no Firestore; consultas autenticadas encerram salas
vencidas sem worker/heartbeat. Repetição não regrava perfis; salas antigas recebem
carência. Testes focados e análise estática aprovados; falta playtest em dois
aparelhos. Treino/Dungeon preservados. Sem APK/release/deploy.
Regras e limitações: docs/multiplayer-abandonment.md.

Checkpoint anterior:

Preparação da release v0.29.0/build 29 na branch codex/release-v0.29.0,
reunindo as alterações acumuladas desde v0.28.0. Workflow manual existente
mantido; roteiro em docs/release-v0.29.0.md. Nenhum build, tag, release ou deploy
disparado nesta preparação. Publicação exige backend no mesmo commit e
validação da assinatura/atualização em aparelho real.

Checkpoint anterior:

Livro e Skill Tree renovados localmente no tema pergaminho/RPG: filtros por
função, ordenação, receita clicável, sinergias e informações corretas de selos.
Árvore por especialização com cores/progresso, Minha build, dicas táticas,
filtro de disponíveis e objetivo temporário de planejamento. 18 talentos,
IDs/custos/callbacks/saves preservados; nenhum novo efeito de combate.
19 testes focados aprovados, incluindo orientação e teclado; análise estática
limpa. Falta avaliação visual em aparelho. Sem APK/release/deploy neste bloco.
Detalhes: docs/progression-journals.md.

Checkpoint anterior:

Selos v2 implementados localmente: dificuldade por receita (4/5 nós para
duplas, 6/7 para triplas), precisão média dos centros com 100/80/60/40% do dano
direto. Captura refina a passagem pelo nó, não penaliza a primeira borda;
alvo central, dificuldade e feedback da faixa visíveis. AP/cura/status e
falha anteriores preservados. Dart/servidor calculam a nota; HTTP exige versão
2 antes de reservar a conjuração. Prévia explicita selo perfeito.
9 testes focados do app, 5 do engine e 10 do backend aprovados. Typecheck TS
limpo e análise Dart sem alertas. Falta playtest da precisão no celular.
Sem APK/release/deploy. Próxima publicação exige app + servidor coordenados,
sem partidas ativas. Regras/limites: docs/seal-quality.md.

Checkpoint anterior:

Acabamento implementado localmente: guia opcional de quatro passos no menu
(Comece aqui/Como jogar), com pular/rever e orientação sobre modos, elementos,
HP/AP, habilidades e selos. Volume/mudo persistidos por aparelho, sem tocar
nos saves; mudo rápido no combate Treino/Dungeon/Multiplayer sem pausar turnos.
Áudio aplica volume a todas as pistas e encerra vozes ativas ao silenciar.
27 verificações focadas aprovadas (preferências, guia, áudio, menu e comandos
responsivos); análise estática dos arquivos alterados limpa. Falta ouvir em
aparelho real. Sem APK/release/deploy; regras e backend não alterados neste bloco.

Checkpoint anterior:

Multiplayer preparado localmente para beta restrito de até 10 pessoas: limites
de tráfego/criação, 40 requisições concorrentes, credencial validada antes do DB,
corpo 64 KiB, erros seguros e URLs malformadas tratadas. Firestore compartilha
leituras simultâneas e cache não retrocede após escrita. Polling Android pausa
em segundo plano; falhas usam backoff/Retry-After sem repetir POST. Sem novas
dependências/serviços ou alteração de faturamento. Simulação local de cinco
salas/dez sessões e testes de cache/backoff passaram. Typecheck TS/análise Dart
limpos. Falta publicar app + servidor e playtest físico; retenção/backups e
recuperação de conta não implementados. Sem APK/deploy neste bloco.
Detalhes/limites: docs/multiplayer-beta-10.md.

Checkpoint anterior:

Skill Tree atual concluída localmente: Concentração (+25% de dano com AP cheio,
sem RNG), Fragmentação (80% do dano em dois golpes, rompe proteção no primeiro)
e Incêndio (Queimadura passiva por 3 ações). IDs/compras/pré-requisitos mantidos;
Precisão liberada na dungeon. Dart/TypeScript alinhados; prévia e feedback de
batalha mostram ativações, com códigos opcionais enviados pelo servidor.
28 testes focados do engine, 17 do backend e 53 do app passaram. Typecheck TS
aprovado; falta playtest em aparelhos. Sem APK, release ou deploy. Regras e
limites: docs/skill-tree-completion.md. Próxima publicação: app + servidor.

Checkpoint anterior:

Balanceamento de combos/progressão implementado localmente: passivas exigem
combo pago; Combustão 3 × 2 respeita Escudo, Guarda dura 2 ações e básicos não
renovam proteção. Oito combos ajustados em Dart/TypeScript, mantendo 3/5 AP.
Primeiro ponto da dungeon chega com 40 XP; demais custos mantidos, 5 pontos por
1.000 XP. Saves/IDs/compras preservados. Regras e justificativas: docs/balance.md.
Verificação concluída: 30 testes focados do engine, 19 do backend e 64 do app
aprovados; análise estática Dart e typecheck TS limpos. Playtest humano de
dificuldade/duração continua pendente; não há promessa de equilíbrio definitivo.
Sem APK, release ou deploy; próxima publicação exige app + servidor alinhados.

Checkpoint anterior:

IA da dungeon e intenção concluídas localmente: 10 padrões por sala, separados
da arte; próximo ataque/custo anunciado no HUD antes da jogada. Congelamento,
silêncio e falta de AP interrompem planos com fallback legal. Dragão entra em
FÚRIA abaixo de metade do HP (inclusive), sem bônus grátis nem mudança surpresa
da ação já anunciada. Custos/status seguem o engine; saves, Treino e Multiplayer
mantidos. 19 verificações focadas aprovadas, incluindo as 10 salas, interrupções
e HUD vertical/horizontal. Falta playtest da dificuldade em celular. Sem APK,
release ou deploy neste bloco. Detalhes: docs/dungeon.md.

Checkpoint anterior:

Áudio concluído localmente: 19 OGG novos dos pacotes CC0 Kenney RPG/Impact/
Interface (193 KiB), créditos/licença incluídos. Preparação por arma/material
da criatura, impactos por elemento, cura/purificação, defesa/descongelamento,
falha e nós/alerta do selo. Player limita 4 vozes, descarta repetição <65 ms,
ajusta volumes e libera recursos. 42 verificações focadas aprovadas; assets
OGG/duração e análise estática conferidos. Falta avaliação auditiva de mixagem/
latência em celular. Sem nova biblioteca de runtime, backend, APK ou publicação.
Detalhes e origem de cada arquivo: docs/audio.md.

Checkpoint anterior:

Bestiário visual da dungeon concluído localmente: 10 identidades próprias
(goblin, dois elfos negros, golem, escaravelho, harpia, ent, troll, aranha e
dragão). Arte procedural original, membros/armas por espécie, poses de ataque
e conjuração; retratos do acampamento reutilizam a arte da batalha. Identidade
passada pela BattleSceneView, com avatar padrão preservado nos modos PvP.
21 verificações focadas aprovadas; análise estática limpa. Prévias conferidas
em repouso/ataque/conjuração e arenas 360x230/568x200. Sem alteração de regras,
HP/XP, IA, persistência, backend, APK ou release. Playtest em celular pendente.
Prévia local: app/build/art-preview/dungeon-creatures.png.

Checkpoint anterior:

v0.28.0 publicada em 2026-09-27: versionCode 28, commit 9a29a1e,
CI 36346800307 aprovado. Release latest com app-release.apk; assinatura
igual à v0.27.0 e SHA-256 local igual ao digest do asset público:
d837d07e9f9749821cd51ef44b0038d0991e80f33f830a38d7cdd4daffa318ce.
Master avançada sem reescrita; Render dep-dasneojncjis73enf2vg colocou
o mesmo commit no ar. Health protocolo 2/Firestore aprovado; smoke online
verificou cura, purificação, redução de AP, criar/entrar/preparar, prévia,
selo, descoberta, rejeição de duplicata e retomada (sala de teste 09DEE7).
Inclui HUD, dungeon de 10 salas e 63 combos. Sem mudança de plano/custo.
Pendente: playtest em aparelhos e avaliar 2 alertas moderados transitivos
de npm audit (gaxios/uuid, GHSA-w5hq-g745-h8pq); sem atualização automática
de dependências durante o deploy.

Checkpoint anterior:

Expansão de combos concluída localmente: 25 duplas + 18 triplas inéditas,
totalizando 63 receitas (40 duplas/23 triplas). IDs antigos preservados;
receitas repetidas unificadas. Cura/purificação/redução de AP espelhadas no
servidor; prévia e feedback em ambos os modos. 53 testes de engine, 44 de
backend e 11 de prévia/livro aprovados; análise estática dos arquivos do app
alterados e typecheck TS limpos. Falta playtest em celular e sessão online
com backend atualizado. Sem combos de 4, gates de itens/classes, APK ou
publicação neste bloco. Próxima publicação deve atualizar app e servidor.
Regras e decisões: docs/combo-expansion.md.

Checkpoint anterior:

Dungeon ampliada para 10 salas: HP de 35 a 150, recompensas crescentes (1.000 XP
no total), 0–3 AP iniciais por patamar e 1–3 habilidades equipadas. Elites
conservam AP para combos triplos; chefe final apenas na sala 10. Catálogo único
alimenta combate, indicadores e validação dos saves, preservando progresso antigo.
11 verificações focadas aprovadas, incluindo simulação das 10 salas, recompensa
única, retomada e ações visíveis nas duas orientações. Falta playtest de dificuldade
no celular. Sem APK, publicação ou alteração de Treino/Multiplayer.

Checkpoint anterior:

Dungeon solo concluída localmente: Ruína Elemental (3 salas/IA e guardião de
Lava), 40/60/100 XP por vitória, níveis com 1 ponto para a árvore existente.
Escolha inicial de 2 elementos; compra de elementos/talentos no acampamento.
Talentos de precisão ainda sem efeito não podem consumir pontos neste modo.
Perfil offline próprio, sem tocar nos saves do Treino ou no Multiplayer.
HP atravessa salas com recuperação de até 25; AP/status reiniciam. Retomada
reinicia a sala atual; vitória avança o checkpoint e recompensa apenas uma vez.
Falha de gravação permite retry; save ilegível é preservado. Combate, IA,
animações, selos, equipamento e livro reutilizam as regras/interfaces existentes.
16 testes focados aprovados (7 domínio, 3 UI/IA, 6 Home); análise estática limpa.
Prévias vertical/horizontal conferidas. Balanceamento e sessão real em celular
ainda precisam de playtest. Sem APK, commit, publicação ou alteração de backend.
Detalhes: docs/dungeon.md.

Checkpoint anterior:

Responsividade/HUD concluídos localmente: ação de batalha fixa, grade compacta
nos dois modos e preparação com colunas adaptativas. Menus, conexão, árvore,
ataques e livro com espaçamentos menores; seleção/turno com transições discretas.
Botões principais mantêm altura mínima de 48; escala de fonte preservada e
rolagem de segurança para listas, descrições e fontes ampliadas.
12 verificações de layout aprovadas (320x568, 360x640, 568x320 e 740x360),
mais 8 existentes de home/multiplayer; análise estática limpa nos alterados.
Conferência visual local nas duas orientações. Falta validar em celular físico.
Sem alteração de regras/servidor nem publicação neste bloco.

Checkpoint anterior:

Correção do cold start concluída localmente: GET /health aguarda até 60s antes
de criar/entrar/retomar pelo lobby, com aviso de inicialização. Diagnóstico:
primeira resposta em 33,1s vs timeout do app de 20s; segunda em 0,4s.
Validação de status/protocolo antes da ação; timeout e resposta tardia não enviam
POST. Sem retry de ações, keep-alive ou novo plano. 8 testes focados aprovados,
incluindo espera de 33s, limite de 60s e duplicatas; análise estática limpa.
Ainda não publicado: a v0.26.0 instalada não contém esta correção.

Checkpoint anterior:

v0.26.0 publicada em 2026-09-25: lobby/conexão Multiplayer e pós-batalha.
CI 36137752619 aprovado, commit cd3c59d, versionCode 26. Assinatura igual à
v0.25.0 e SHA-256 local igual ao asset público. Marcada como latest no GitHub.
Servidor respondeu com protocolo 2/Firestore; smoke online aprovou criar/entrar,
preparar, conjurar, rejeitar duplicata e recuperar estado. Sem novo deploy/plano.
No plano gratuito, primeira conexão após inatividade pode demorar.
Próximo: validar em dois celulares com v0.26.0, sem desinstalar o jogo.

Checkpoint anterior:

Lobby/conexão Multiplayer concluídos localmente: criar/entrar/retomar separados,
feedback de requisição real sem reenvio automático, retomada com identidade salva,
erros compreensíveis e validação de código. Sala mostra código copiável e preparo
de ambos antes da batalha; seleção de elementos é aberta pela sala.
Layout rolável nas duas orientações/com teclado. Identidade, polling e backend
reutilizados; reconexão autorizada também atualiza a última sala local.
13 testes focados passaram (6 lobby + 2 multiplayer + 5 pós-batalha), análise limpa
e prévias conferidas. Teste em dois celulares pendente. Sem commit/release;
bloco de pós-batalha anterior preservado.

Checkpoint anterior:

Pós-batalha concluído localmente: painel pixel art compartilhado, arena mantida,
resultado após animação final e ações Revanche/Menu acima dos detalhes.
Ganhos comparados ao progresso inicial (sem conceder recompensas): livro
compartilhado e habilidades/árvore separados por jogador no Treino; estado do
servidor no Multiplayer. Reconexão sem histórico inicial é indicada explicitamente.
Treino permite ajustar os 3 slots; Multiplayer encerrado oferece consulta,
com troca na próxima sala. Revanche mantém fluxo existente e bloqueia duplicatas.
7 testes focados aprovados, análise limpa e prévias vertical/horizontal conferidas.
Sem novo backend, persistência, commit ou release. Falta teste em aparelhos.

Checkpoint anterior:

v0.25.0 publicada em 2026-09-24: Home RPG, Livro de Descobertas e polimento
dos Selos. CI 36052579909 aprovado, commit 6812389, versionCode 25.
APK com a mesma assinatura da v0.24.0; hash local igual ao asset publicado.
Release pública confirmada em 2026-09-25. Sem alteração de backend, protocolo
ou persistência. Falta experimentar no celular, em ambas as orientações.

Checkpoint anterior:

Tela inicial concluída localmente: cena pixel art reaproveita arena/sprites,
emblema de conjuração e menu RPG com identificação de Treino/Multiplayer.
Vertical empilhada; horizontal lado a lado, compacta em telas baixas, com rolagem
de segurança. Navegação protegida contra toque duplo; animação suspensa ao sair
e com movimento reduzido. Combate, atualização, backend e persistência intactos.
6 testes da Home aprovados (incluindo retorno e 360x800/800x360/568x320), análise
focada limpa e prévias renderizadas/inspecionadas. Falta validar no aparelho.
Sem nova release; melhorias anteriores do livro/selos continuam preservadas.

Checkpoint anterior:

Livro de Descobertas concluído localmente: tela compartilhada Treino/Multiplayer,
busca por nome/efeito/elemento, filtros por AP/elemento/equipamento, receitas e dano
base das descobertas. Receitas desconhecidas ocultas. Gestão dos 3 slots reutilizada;
registro compartilhado do Treino separado das habilidades pessoais. Sem release.
9 testes focados aprovados (4 do livro + 5 do gerenciador existente). Entrada pelo
ícone de livro na batalha. Disponibilidade é uma consulta, não promessa em tempo
real; botão de atualizar e prévia da batalha mantidos. Persistência não alterada.

Checkpoint anterior:

Polimento dos Selos concluído localmente (sem nova release): rastro do dedo,
orientação de próximo nó/retomada e aviso nos últimos 2s, mantendo dano/AP/prazo.
Janela com espaços fixos para não deslocar o desenho ao iniciar. Alteração apenas
na UI compartilhada entre Treino e Multiplayer; sem novo protocolo/infraestrutura.
6 testes focados aprovados: início, correção/retomada, tempo curto, estabilidade
do desenho em vertical/horizontal e ataque equipado. Falta experimentar no celular.

Checkpoint anterior:

v0.24.0 publicada em 2026-09-24: APK do CI 35998111703 (versionCode 24),
assinatura igual à v0.23.0. Backend 942b336 ativo no Render com Firestore.
Smoke online aprovado: início, reserva, resolução, rejeição de duplicata e recuperação.
Diagrama fixo por receita (4/6 nós, 6/8 segundos), arraste com retomada pelo último
nó, janela compartilhada adaptativa e canalização do avatar. Básicos continuam diretos.
Falha perde 1 AP sem regenerar, passa turno e processa status, sem combo/descoberta.
Servidor reserva ação/build, valida geometria/ordem/prazo e rejeita duplicatas.
Prazo e selo persistidos no snapshot; primeira leitura após expirar resolve a falha
atomicamente (sem jobs nem escritas a cada polling). Tolerância de transporte: 1,5s.
Validação pontual: backend (5 testes), domínio/widget/ataque equipado/multiplayer
(7 testes), análise do app e typecheck backend aprovados;
sem suíte completa. Pendente teste físico de gesto/latência nos dois celulares
atualizados para v0.24.0. Ver docs/conjuration-seals.md. Checkpoint anterior:

v0.23.0 publicada em 2026-09-23 com APK do CI (run 35857481276).
Backend 00a0117 no Render, protocolo 2 e Firestore ativos. Conta exclusiva com
roles/datastore.user; segredo salvo no Render e cópias temporárias locais apagadas.
Cobrança Firebase desativada; nenhum plano pago ativado.
Smoke online aprovado: criar, entrar, preparar ambos, atacar e recuperar estado.
Recuperação por nova instância do adaptador Firestore também aprovada.
Próximo: usuário validar dois celulares com v0.23.0, reconexão e orientações.
Protótipo fechado: identidade por instalação; faltam rate limiting/retenção e
recuperação de conta antes de abertura pública. Checkpoints abaixo são históricos.

Checkpoint anterior:

Multiplayer: protótipo integrado localmente, sem publicação.
Servidor controla preparação, 4 elementos, 3 ataques, descobertas, progressão
e habilidades/status. Credencial por instalação + revisão obrigatória.
Frontend reutiliza preparação, Skill Tree, ataques, arena e feedback; controles
nas duas orientações, reconexão com última sala lembrada e avisos de conexão.
Snapshot atômico opcional via MATCH_STORE_FILE; progresso de partidas concluídas
reutilizado com a mesma credencial e nome. Sem importar progresso local do Treino.
Validação pontual: 2 testes HTTP/persistência + 2 widgets de orientação aprovados;
typecheck aprovado. Não foi rodada suíte completa nem teste em aparelhos físicos.
Contrato novo exige atualizar fixtures antigas de multiplayer (credencial,
revisão e preparação) antes de voltar a usar a suíte legada como gate de release.
Publicação bloqueada até escolher armazenamento durável e validar dois aparelhos;
ver docs/multiplayer-prototype.md. Nenhuma infraestrutura alterada.

Checkpoint anterior:

Árvore de habilidades: incremento concluído, sem publicar. Tela compartilhada
mostra identidade/progresso dos ramos, estados e limitações dos nós ainda inertes.
Detalhes roláveis e desbloqueio protegido contra envio duplicado.
Propagação fortalece DOT de combos; Instabilidade troca duração por dano imediato.
IDs/pré-requisitos/persistência preservados. Validação pontual: 7 testes Dart,
5 backend, 4 da tela compartilhada; typecheck aprovado. Sem suíte completa.

Checkpoint anterior:

INLINE: completar status e ampliar combos. Sem publicar.
Checkpoint 1: regras definidas (Silêncio, Lentidão, Buff/Debuff, Molhado,
Choque e Veneno); 16 novas receitas, total 20.
Checkpoint 2 concluído: engine/backend/UI, prévias, custos e avisos integrados.
Checkpoint 3 concluído: engine 233, backend 160 e app 289 testes aprovados;
análise do app e typecheck do backend sem problemas. Capturas de layout de
defesa em 360x640 e 568x320 inspecionadas (fontes de teste, não arte final).
Validação manual em aparelhos e balanceamento pendentes. Sem commit/release/deploy.

# NEXT

Playtest do BETA TEST: resposta dos controles/alcances, câmera e desempenho
no Android. Só depois expandir combos, exploração e progresso permanente 3D.

Playtest das variações da Dungeon nos celulares: dificuldade por sala, duração
das variantes defensivas e decisões de build. Publicação apenas quando solicitada.
Assinatura definitiva adiada expressamente pelo usuário; não alterar keystore
ou workflow de assinatura neste bloco. A versão pública atual é v0.31.0.

# BACKLOG

Mapa do que falta, por área — não é ordem de prioridade. Consultar antes de
perguntar "o que falta"; atualizar aqui (não como pergunta solta) sempre que
uma tarefa nova terminar revelando um gap novo.

**Battle Engine (packages/battle_engine)**
- `hitCount`/`critChanceBonus` (Fragmentação/Núcleo Instável) inertes —
  precisa desenhar como múltiplos hits/crítico interagem com Escudo
- Conversões adicionais de status: Molhado já amplifica Raio e é consumido;
  outras conversões ainda precisam de desenho de gameplay.
- Dano de campo é hit único — Lava não continua queimando enquanto ativa
- Artefatos não implementado (`MaxHpBonus` é o modelo pronto pra isso)

**Backend (backend/)**
- Firestore configurado em produção (`elementosMatches`/`elementosProfiles`);
  backup anterior e proteção entre salas implementados localmente; faltam
  retenção de partidas e backup externo para desastre do projeto inteiro.
- Conta recuperável por Firebase publicada; validar fluxo completo em aparelhos.
- Sem push em tempo real — só polling (cliente já poll a cada 2s)
- CORS liberado pra `*` — ok sem deploy real, reavaliar quando existir um (DECISION-021)

**Firebase (firebase/)**
- Projeto real `elements-1173d`; autenticação recuperável ainda pendente.
- Emulador do Firestore nunca verificado rodando de verdade nesta máquina
  (limitação de ambiente já diagnosticada, não da config — DECISION-015)

**App Flutter (app/)**
- Livro de Descobertas sem tela própria (só o contador no Modo Treino)
- Sistema de build do Modo Treino simplificado (um slot só, tudo
  desbloqueado se aplica sempre — DECISION-018)
- Sem iOS — precisa de um Mac, indisponível (DECISION-010). Android agora
  tem APK de verdade (ver DECISION-029), mas só compila via GitHub
  Actions — o Gradle não roda localmente nesta máquina (mesma limitação
  de rede da JVM da DECISION-015)
- Layout da Skill Tree visual (DECISION-038) assume que cada branch é
  uma cadeia linear (`orderBranchNodes`) — se um nó ganhar 2+
  pré-requisitos ou 2+ nós dependendo dele no futuro, o layout continua
  correto logicamente mas não desenha a ramificação visualmente
- Botão de mutar/desmutar os efeitos sonoros (Bloco 8, DECISION-042) —
  precisa de uma tela de configurações, que ainda não existe
- Música de fundo (Bloco 8, DECISION-042) — loop/fade/mixagem é
  complexidade própria, fora do escopo do bloco de áudio já feito
- Sons de habilidade desbloqueada/vitória/derrota (Bloco 8, DECISION-042)
  não foram ouvidos manualmente nesta sessão (ícone de Habilidades não
  localizado a tempo no preview web) — só a lógica que decide quando
  tocar foi verificada (suítes de tela passando)
- Animação nos badges de status/campo (Bloco 9, DECISION-044) — fica
  pra um bloco futuro de polimento, se quiser
- Tooltip/descrição ao tocar num badge de status/campo (Bloco 9,
  DECISION-044) — não pedido, YAGNI
- Ícone dedicado por combinação futura sem entrada em
  `status_visuals.dart` (Bloco 9, DECISION-044) — cai no fallback (✨)
  até alguém adicionar

**Multiplayer (cliente)**
- A modal de Habilidades não escuta o polling por trás — se a vez mudar
  com ela aberta, a lista não atualiza sozinha (mesma limitação que a
  `TrainingScreen` já tinha — DECISION-026)
- Revanche simultânea dos dois jogadores cria duas partidas separadas, não
  ligadas — só um dos dois deveria clicar (DECISION-023)
- Sem indicação visual de "enviando"/erro de rede além do texto cru do
  backend
- `CombinationCatalog` precisa sincronizar manualmente toda vez que
  `default_combinations.dart` ganhar uma combinação nova
- Progressão persistente no Multiplayer (Bloco 11 da direção de
  produto, decidido mas não iniciado): Skill Tree persistente + Livro
  de Descobertas novo no backend (não existe nenhum hoje), via
  Firestore. Projeto Firebase real já criado (`elements-1173d`,
  DECISION-045) — falta gerar a credencial de serviço (Admin SDK) no
  console e configurar no backend/Render antes de poder implementar

**Produção / deploy**
- Backend implantado no Render (free tier) — ver DECISION-028. APK
  Android distribuído via GitHub Release (ver DECISION-029) — compilado
  via GitHub Actions, não localmente (Gradle não roda nesta máquina).
  Ainda faltam: versão web do app não está implantada em lugar nenhum
  (só roda localmente, `flutter run -d web-server`); Firebase continua só
  local (emulador); free tier do Render hiberna após ~15min sem uso
  (primeira requisição depois disso demora mais, "cold start"); APK sem
  assinatura de release de verdade (usa a chave de debug — suficiente
  pra instalar direto, não pra publicar numa loja); sem atualização
  automática — uma nova versão do jogo exige gerar e reenviar um APK novo

# DONE

- Congelamento funcional: Água + Gelo cria Prisão Glacial (10 de dano),
  aplicando Congelamento se Escudo não bloquear. O alvo perde a próxima ação
  para quebrar o gelo, sem regenerar AP; ataques/Defesa são rejeitados até
  isso acontecer. Treino e Multiplayer mostram badge, camada azul/cristais no
  personagem, aviso, prévia e comando exclusivo “Quebrar gelo”. Mirror Dart/
  TypeScript e rotas autoritativas sincronizados. 226 testes no engine, 153 no
  backend e 286 no app; análises estáticas limpas. Ver DECISION-055.
  Preparado para distribuição na v0.22.0+22.

- v0.21.0+21 publicada: backend validado no Render com prévia de Defesa sem
  mutar a partida; APK Android de 52.879.521 bytes publicado no GitHub Release
  `v0.21.0` após build verde no Actions. Defender, prévia autoritativa e combos
  diferenciados disponíveis em produção. Ver DECISION-054.

- Combate fluido: básicos com aproximação, golpe e recuo; combos com
  canalização e projétil pixelado; pernas, poses, respiração e reação a dano.
  HUD sincronizado com impacto; legenda e dano legíveis; rotação/cancelamento
  sem poses presas. Básicos locais do Multiplayer também geram animação.
  250 testes aprovados, análise estática limpa e preview visual verificado
  com básicos/combo nas orientações vertical/horizontal. DECISION-052.
  Preparado para distribuição na v0.19.0+19.

- Preparação personalizada do Treino: etapas A/B, seleção de dois elementos,
  contador e entrada explícita na batalha. Campo e comandos lado a lado na
  horizontal, empilhados na vertical; abas/AP/confirmação fixos, áreas seguras
  respeitadas e rotação sem reiniciar a animação ou perder seleção/progresso.
  Suíte do app: 237 testes aprovados; análise estática sem problemas.
  Ver DECISION-051. Preparado para distribuição na v0.18.0+18.

- Interface portátil do Treino: arena/HUD fixos, grade 2×2 com até quatro
  elementos ativos por jogador, aba com três habilidades, troca em janela
  inferior e combinação com confirmação. Equipamento elemental persistente,
  migração de saves antigos e validação no domínio. Habilidades aprendidas
  independem dos quatro elementos básicos. Mensagem durante animação;
  troca de habilidade nova só abre após o feedback. Ver DECISION-050.

- Bloco 2d: painel com três slots de ataques equipados no Treino, seleção,
  descrição, custo e motivo de indisponibilidade; execução por ID validada
  em TrainingMatch e encaminhada ao motor existente. Básicos e combinação
  livre preservados; AP disponível inclui a regeneração existente. Bloqueio
  contra toque duplo acompanha a conclusão real da animação. Corrigidos
  estouros de texto no HUD/botões em 360 px. Ver DECISION-049.

- Definição da arquitetura mínima e criação dos 4 arquivos de contexto (CLAUDE.md,
  ARCHITECTURE.md, TASKS.md, DECISIONS.md)
- Pacote `packages/battle_engine` criado (Dart puro, sem dependência de Flutter)
- `Element` implementado (data-driven: id, nome, símbolo) com os 10 elementos do design
- `ElementCombination` + `CombinationBook` implementados (2 e 3 elementos → efeito),
  com combinações de exemplo (Tempestade Ígnea, Campo Eletrocutado, Lava)
- Testes das combinações (13 testes, `dart analyze` e `dart test` passando)
- `Combatant` e `BattleState` implementados (participantes, turno atual, efeitos
  de campo ativos), imutáveis com `copyWith`/`withFieldEffect`, com testes
  (20 testes no total no pacote, `dart analyze` e `dart test` passando)
- `TurnAction` e `TurnEngine` implementados: joga 1–3 elementos, resolve
  combinação via `CombinationBook`, rejeita ação fora da vez, alterna o turno
  e acumula efeitos de campo. Sem dano/HP/vitória ainda (fora de escopo)
  (31 testes no total no pacote, `dart analyze` e `dart test` passando)
- `StatusEffect`/`StatusEffects` (data-driven: Burn, Freeze, Wet, Poison, Shock,
  Slow, Shield, Silence, Buff, Debuff, AreaEffect) e `ActiveStatus` (duração em
  turnos) implementados. `BattleState` ganhou `statusesOf`/`hasStatus`/
  `withStatusApplied`/`withStatusRemoved`/`withStatusesTicked`. Sem integração
  automática com o `TurnEngine` ainda (fora de escopo)
  (43 testes no total no pacote, `dart analyze` e `dart test` passando)
- `FieldEffect` extraído (efeito de campo genérico); `ElementCombination.result`
  e `BattleState.activeFieldEffects` passaram a usá-lo. `Ability`, `Mutation`/
  `Mutations` (Combustão, Fragmentação, Incêndio, Núcleo Instável) e
  `AbilityEngine` implementados: uma habilidade joga elementos via `TurnEngine`
  e suas mutações acumulam um `AbilityEffect` (status a aplicar no oponente,
  efeito de campo, hitCount e critChanceBonus — os dois últimos ainda inertes,
  sem sistema de dano)
  (62 testes no total no pacote, `dart analyze` e `dart test` passando)
- `SkillNode`/`SkillTree` (grafo data-driven, valida ids duplicados,
  pré-requisito inexistente e ciclos) e `SkillProgress` (desbloqueio
  imutável, `availableNodes`, `grantedMutations`) implementados. Cada nó
  concede uma `Mutation` já existente — pronta para anexar a uma `Ability`.
  `defaultSkillTree` de exemplo com 2 branches (fogo, precisão). Nós que
  alteram combinações/estados diretamente ficaram fora de escopo
  (ver DECISION-008)
  (90 testes no total no pacote, `dart analyze` e `dart test` passando)
- `Build` implementado: `skillProgress` + lista de `Ability`s (ids únicos),
  validado na construção e a cada mudança (toda `Mutation` usada precisa
  estar desbloqueada em `skillProgress`). `abilityById`, `withAbility`,
  `withSkillProgress`. `Ability` ganhou igualdade por id (faltava, corrigido
  por consistência). Não depende de nenhuma batalha — build é editável offline
  (102 testes no total no pacote, `dart analyze` e `dart test` passando)
- Ponto de extensão implementado: `CombinationModifier` (id/nome/descrição +
  `apply(FieldEffect)→FieldEffect`), aplicado por `TurnEngine.playTurn`
  (parâmetro opcional `combinationModifiers`) antes do efeito ir pro campo;
  `AbilityEngine` repassa. `FieldEffect` ganhou `area`/`duration` para ter o
  que modificar. `SkillNode.grants` virou `SkillGrant` (`Mutation` ou
  `CombinationModifier`, via interface comum) — `SkillProgress` ganhou
  `grantedCombinationModifiers`. `Build` ganhou `combinationModifiers`
  (validado contra o skillProgress) e `withCombinationModifier`.
  `defaultSkillTree` ganhou a branch "elemental" (Propagação, Instabilidade)
  (125 testes no total no pacote, `dart analyze` e `dart test` passando)
- App Flutter criado em `app/` (plataformas web + windows, únicas com
  toolchain nesta máquina), com `battle_engine` como path dependency.
  Estrutura inicial: `lib/game_domain/element_catalog.dart` (primeira classe
  da camada Game Domain) + `lib/ui/home_screen.dart` (tela provisória que
  lista os elementos — prova a fiação, não é UI de jogo real). `flutter
  analyze` limpo, teste de widget passando, verificado rodando de verdade no
  navegador (`flutter run -d web-server`, via `.claude/launch.json`)
- Integração Flame: dependência `flame` adicionada. `BattleView` (projeção
  somente-leitura de `BattleState`) e `DemoBattle.start()` (roda um turno via
  `TurnEngine`) em `game_domain`. `BattleGame extends FlameGame` em
  `game_presentation` renderiza o `BattleView` como texto — sem regra de jogo
  nenhuma. `BattleScreen` hospeda o `BattleGame` num `GameWidget`, acessível
  pelo botão na `HomeScreen`. `flutter analyze` limpo, 3 testes passando
  (unitário do `DemoBattle` + navegação), verificado rodando de verdade no
  navegador — Flame renderizou "Ana"/"Beto"/"Turno: Beto"/"Tempestade Ígnea"
- Backend Node/TS criado em `backend/`: TypeScript + `tsx` (dev/execução) +
  `node:test` nativo (sem dependência de test runner). `src/server.ts`
  (`createServer()`, testável em porta efêmera) + `src/index.ts` (entry
  point). Só `GET /health` por enquanto — nenhuma regra de jogo ainda.
  `tsc --noEmit` limpo, 2 testes passando, servidor rodado de verdade
  (`curl /health` → `{"status":"ok"}`). Problema arquitetural identificado
  e registrado: ver DECISION-013 antes de começar "Validação de ações
  críticas no backend"
- Validação de ações críticas no backend: `src/battle-rules/` — mirror
  deliberado e mínimo do `battle_engine` em TypeScript (`FieldEffect`,
  `CombinationBook`/`defaultCombinationBook`, `createBattleState`/
  `opponentOf`, `TurnEngine.playTurn`). Endpoint `POST /battles/validate-turn`
  (stateless: cliente manda o estado, servidor recalcula e devolve o
  resultado autoritativo). Sem estados/habilidades/skill tree/builds no
  servidor ainda (ver DECISION-013/014). `tsc --noEmit` limpo, 24 testes
  passando (unitário das regras + integração HTTP em porta efêmera),
  servidor testado de verdade com `curl` (turno válido calcula
  `ignited_storm` e passa o turno; turno fora de vez → 400)
- Firebase (setup mínimo, free tier, sem cartão): `firebase/` criado com
  `firebase-tools` (dev dependency), `firebase.json` (emulador do Firestore +
  UI), `firestore.rules` (nega tudo por padrão — sem schema/auth decididos),
  `firestore.indexes.json` (vazio), `.firebaserc` apontando pro project id
  demo `demo-jogo-elementos` (Firebase Emulator Suite reconhece "demo-*" como
  projeto falso — roda 100% local, sem login, sem cartão, sem projeto real
  criado). JSON de todos os arquivos validado. Emulador do Firestore não
  pôde ser verificado rodando de verdade nesta máquina — precisa de Java 21+
  (instalado via choco), mas o próprio JVM falha com "Unable to establish
  loopback connection" (bug/limitação de sockets Unix domain do ambiente,
  reproduzido em Bash, PowerShell nativo e com sandbox desabilitado — não é
  problema da configuração). Ver DECISION-015. Nenhum projeto real do
  Firebase foi criado — isso exige login numa conta Google do usuário
- Multiplayer: `POST /matches`, `POST /matches/:id/join`,
  `POST /matches/:id/turns`, `GET /matches/:id` implementados. `MatchStore`
  in-memory (perde estado ao reiniciar o servidor — persistência real via
  Firestore é follow-up, bloqueado em ter um projeto Firebase de verdade).
  Reconexão por polling (`GET /matches/:id`), sem push em tempo real ainda.
  Identidade de jogador é só uma string mandada pelo cliente, sem
  autenticação (aceitável para "dois amigos", registrado como limitação).
  `tsc --noEmit` limpo, 38 testes passando no total do backend, fluxo
  completo (criar → entrar → ação A → ação B → reconectar) testado de
  verdade com `curl` contra o servidor rodando (ver DECISION-016)
- Livro de Descobertas: `DiscoveryEntry`/`DiscoveryBook` implementados em
  `battle_engine` — rastreia `ElementCombination`s descobertas por
  `resultId` (`withDiscovered`, `isDiscovered`, `entriesFor(CombinationBook)`).
  Meta-progressão pura, offline, imutável, sem integração automática com
  `TurnEngine`/`AbilityEngine` (a camada que processa o resultado decide
  atualizar o livro). Sem UI no Flutter ainda (fora de escopo, mesmo padrão
  de Skill Tree/Build)
  (132 testes no total no pacote, `dart analyze` e `dart test` passando)
- Modo treino / offline: `TrainingMatch` (game_domain) — batalha local
  hotseat (`BattleState`+`TurnEngine`+`DiscoveryBook`, offline, sem IA),
  expõe só tipos simples pra UI. `TrainingScreen` — primeira tela realmente
  jogável do app: seleciona 1–3 elementos (chips), joga o turno, vê o
  campo/última combinação/progresso do Livro de Descobertas atualizarem.
  `ElementCatalog` refatorado pra devolver `ElementOption` (tipo próprio da
  Game Domain) em vez do `Element` do `battle_engine`, fechando de vez a
  regra "UI nunca precisa nomear um tipo do battle_engine" (ver
  DECISION-017). `flutter analyze` limpo, 10 testes passando no app
  (unitário do `TrainingMatch` + 2 de widget), verificado jogando de
  verdade no navegador — Fogo+Vento disparou "Tempestade Ígnea", passou o
  turno pra Jogador B e "Descobertas: 1/3" atualizou
- Integrar Habilidades/Mutações/Skill Tree/Build no Modo Treino:
  `TrainingMatch` ganhou um `SkillProgress` independente por jogador sobre
  `defaultSkillTree`. `playElementIds` agora monta um `Ability` novo a cada
  turno (elementos escolhidos + `grantedMutations` do jogador da vez),
  embrulha num `Build` (validado) e chama `AbilityEngine.useAbility` em vez
  do `TurnEngine.playTurn` cru. `TrainingScreen` ganhou o botão
  "Habilidades" (abre modal listando nós desbloqueáveis do jogador da vez,
  com desbloqueio ao vivo) e mostra estados ativos de cada jogador + efeitos
  aplicados no oponente. `SkillNodeOption` criado (Game Domain) pro mesmo
  motivo do `ElementOption`. `flutter analyze` limpo, 16 testes passando no
  app, verificado jogando de verdade no navegador: Jogador A desbloqueou
  Maestria da Brasa, jogou só Fogo, e "Queimadura" foi aplicada em Jogador B
  — a cadeia Skill Tree → SkillProgress → Build → Ability → AbilityEngine →
  BattleState funcionando de ponta a ponta pela UI
- Sistema de dano/HP/condição de vitória: `HpPool` (novo); `damage` em
  `FieldEffect`/`ElementCombination` (Tempestade Ígnea/Campo Eletrocutado
  20, Lava 35); `damagePerTick` em `ActiveStatus` (Combustão: 8×2 = 16);
  `TurnEngine.playTurn` passou a aplicar dano de combo (bloqueado por
  Escudo, que é consumido), tickar estados automaticamente (dano incluso,
  inclusive no tick que expira) e setar `BattleState.winner` — rejeita
  ação se a partida já acabou; empate simultâneo é decidido a favor de quem
  jogou o turno. `MaxHpBonus`/`MaxHpBonuses` (novo `SkillGrant`,
  `SkillProgress.grantedMaxHpBonus`) + nó "Treino de Vitalidade" (+20 HP)
  na `defaultSkillTree`. `TrainingMatch` calcula HP inicial (100 + bônus) e
  aplica bônus desbloqueado no meio da partida ao vivo; `TrainingScreen`
  mostra HP, tela de fim de partida e botão "Nova partida" (corrigiu de
  passagem um overflow no modal de Habilidades, exposto pelo 4º nó da
  árvore). 173 testes no total no battle_engine, 24 no app — `dart
  analyze`/`flutter analyze` limpos, `dart test`/`flutter test` passando.
  Verificado jogando uma partida completa até o fim de verdade no
  navegador (5 combos de Fogo+Vento derrubaram Jogador B de 100 a 0,
  "Vencedor: Jogador A" apareceu, "Nova partida" resetou corretamente).
  O mirror do backend (`backend/src/battle-rules/`) **não** foi
  atualizado — continua validando só a resolução básica de turno, sem
  dano/HP/vitória (ver DECISION-019)
- Sincronizar dano/HP/vitória no backend: `backend/src/battle-rules/`
  ganhou `HpPool`/`hp-pool.ts`, `damage` em `FieldEffect`/
  `defaultCombinationBook` (mesmos números do Dart), `hp`/`winner` em
  `BattleState` (`hpOf`/`withDamage`), e `playTurn` passou a aplicar dano
  de combo ao oponente, definir o vencedor e rejeitar jogar depois que a
  partida acabou. `MatchStatus` ganhou `"finished"`; `MatchStore.applyTurn`
  marca o match e passa a rejeitar novas jogadas (409). O endpoint
  stateless `/battles/validate-turn` também aceita/devolve `hp`/`winner`.
  Deliberadamente sem Escudo/Queimadura (DOT) — dependem de
  status/abilities/skill tree, que o backend nunca mirrorizou e que o
  Multiplayer não expõe ainda (ver DECISION-020). `tsc --noEmit` limpo, 57
  testes passando no backend
- Conectar o Multiplayer ao app: `MultiplayerLobbyScreen` (criar/entrar com
  código) + `MultiplayerBattleScreen` (joga, HP dos dois lados, campo
  ativo, fim de partida, polling a cada 2s) no Flutter, sobre
  `MultiplayerClient`/`MultiplayerMatch`/`CombinationCatalog` (novos, em
  `game_domain`). Backend ganhou CORS permissivo (necessário pro app web
  chamar o backend numa origem diferente) — ver DECISION-021. `flutter
  analyze` limpo, 39 testes passando no app (incluindo os novos de
  multiplayer), 59 no backend. Verificado de ponta a ponta de verdade:
  backend + app rodando juntos, duas abas do navegador como "ana"/"beto" —
  criar, entrar, jogar Fogo+Vento (dano e nome da combinação corretos), a
  outra aba atualizando sozinha via polling
- Tela de reconexão do Multiplayer: `MultiplayerMatch.reconnect` (GET
  puro, valida localmente que o jogador faz parte da partida) + botão
  "Reconectar" na `MultiplayerLobbyScreen` (mesmos campos de nome/código).
  Motivado por um gap descoberto jogando a partida anterior de ponta a
  ponta: fechar a aba não deixava voltar pra partida em andamento (ver
  DECISION-022). `flutter analyze` limpo, 43 testes passando no app.
  Verificado de verdade: joguei um turno real, fechei a aba do "beto" por
  completo, abri uma aba nova, reconectei só com nome + código — voltou
  no HP/turno/campo reais, sem resetar nada
- Botão de revanche no Multiplayer: `MultiplayerMatch.startRematch()` cria
  uma partida nova pro mesmo jogador (não existe "reset" no backend — uma
  `Match` `finished` fica `finished`); botão "Revanche" na tela de fim de
  partida navega pra ela via `pushReplacement`, código novo pra
  compartilhar de novo com o amigo (ver DECISION-023). `flutter analyze`
  limpo, 45 testes passando no app. Verificado de verdade: joguei uma
  partida até o fim, cliquei Revanche, confirmei por `GET` no backend que
  a partida antiga ficou intacta (`finished`) e a nova nasceu
  `waiting_for_opponent` com código diferente
- Escudo e Queimadura/DOT no backend: `ActiveStatus`/`active-status.ts` +
  `combatantStatuses` em `BattleState`; `playTurn` bloqueia dano de combo e
  consome Escudo (`SHIELD_STATUS_ID`), tica `damagePerTick` de todo status
  ativo dos dois jogadores ao final de cada turno (dano genérico, não
  específico de Queimadura), remove estados expirados — mesma ordem
  `[oponente, ator]` que decide empate simultâneo a favor de quem jogou
  (mirror 1:1 de `TurnEngine.playTurn`). `/battles/validate-turn` também
  aceita/devolve `combatantStatuses`. Fecha a lacuna da DECISION-020/021
  (ver DECISION-024). Deliberadamente sem ligação com abilities/Skill
  Tree — `TurnAction` do Multiplayer continua só `{actorId, elementIds}`,
  então nenhuma jogada real ainda produz um status (registrado no
  BACKLOG). `tsc --noEmit` limpo, 76 testes passando no backend,
  incluindo os 5 casos espelhados 1:1 de `turn_engine_test.dart` (Dart)
- Habilidades, Mutações e Skill Tree no backend do Multiplayer: novos
  `ability-effect.ts`/`mutations.ts`/`combination-modifiers.ts`/
  `max-hp-bonuses.ts`/`skill-tree.ts`/`ability-engine.ts` em
  `battle-rules/`; `Match.skillProgress` (nós desbloqueados por jogador);
  `MatchStore.applyTurn` passou a usar `useAbility` (aplica as Mutações/
  CombinationModifiers já desbloqueadas do ator automaticamente); nova
  `MatchStore.unlockSkill` (só quem tem a vez desbloqueia, aplica
  `maxHpBonus` na hora) + rota `POST /matches/:id/skills/unlock`. Fecha o
  gap da DECISION-024 (ver DECISION-025). `SkillNode`/`SkillTree`/
  `SkillProgress` genéricos do Dart viraram dado estático + funções puras
  (tradução, não port 1:1); `Build` não foi portado (não precisa — mesmo
  padrão que `TrainingMatch.playElementIds` já usava sem `Build`/`Ability`
  como classes). `tsc --noEmit` limpo, 118 testes passando no backend.
  Deliberadamente sem UI no app ainda — verificado de ponta a ponta via
  HTTP puro contra o servidor rodando: criar, entrar, desbloquear Maestria
  da Brasa pra "ana", jogar só Fogo, Queimadura apareceu em
  `combatantStatuses.beto` na resposta
- UI de Habilidades/Skill Tree no Multiplayer: botão "Habilidades" na
  AppBar da `MultiplayerBattleScreen` (só com a partida em progresso) abre
  modal igual à `TrainingScreen`, listando nós desbloqueáveis só quando é
  a vez do jogador local (`MultiplayerMatch.unlockedNodeIdsForMe` +
  `unlockSkill` novos, `RemoteMatch.skillProgress`,
  `skill_tree_catalog.dart`'s `availableSkillNodeOptions`). Fecha a
  lacuna da DECISION-025 (ver DECISION-026). `flutter analyze` limpo, 52
  testes passando no app. Verificado de ponta a ponta de verdade jogando
  pela tela: criei partida como "ana", "beto" entrou via API, abri
  Habilidades, desbloqueei Maestria da Brasa (lista atualizou na hora
  pra "Caminho do Incêndio"), joguei só Fogo, `GET /matches/:id`
  confirmou Queimadura aplicada em "beto"
- Escudo via Skill Tree: nova Mutação "Guarda" que protege quem a usa, não
  o oponente. Isso expôs um problema real — `AbilityEngine.useAbility`
  sempre mirava o oponente do ator, hardcoded. Solução: novo
  `TargetedStatus`/`StatusTarget` (Dart) e mirror em TypeScript
  (`ability-effect.ts`), `AbilityEngine`/`ability-engine.ts` escolhem o
  alvo por status. Nó `guard_training` (branch "defesa", raiz) na
  `defaultSkillTree`/`skill-tree.ts`. Como a árvore é data-driven, a UI
  (Treino e Multiplayer) já lista e permite desbloquear o nó novo sem
  nenhuma mudança de tela (ver DECISION-027). Ripple pego rodando os
  testes: `TrainingMatch`/`ability_test.dart` acessavam `ActiveStatus`
  direto de `statusesToApply`, corrigido pra `.status.effect`. 176 testes
  no battle_engine, 52 no app, 123 no backend — todos verdes, analyze/
  typecheck limpos. Verificado de ponta a ponta de verdade jogando o
  Modo Treino no navegador: desbloqueei Treino de Guarda, joguei um
  elemento ("Jogador A: Escudo" apareceu no jogador certo), o outro
  jogador disparou Tempestade Ígnea contra ele — HP ficou intacto em
  100/100 e o Escudo foi consumido
- Backend implantado no Render (free tier): `tsx` movido de
  `devDependencies` pra `dependencies` (precisa em runtime, não só em
  dev). Projeto virou repositório git pela primeira vez, publicado no
  GitHub (`github.com/MarlonFer77/jogo-elementos`, público — a integração
  Render↔GitHub App deu erro tentando conceder acesso a um repo privado
  novo, então usei repositório público como alternativa, confirmado com o
  usuário antes). Serviço `jogo-elementos-backend` criado no Render
  (plano free, região Virginia) via MCP. App Flutter passou a apontar
  `defaultMultiplayerBaseUrl` pro Render em vez de `localhost:3000`. Ver
  DECISION-028. Verificado de ponta a ponta contra o serviço real: `curl`
  direto (criar/entrar/jogar com dano correto) e o app rodando localmente
  **sem nenhum backend local no ar** — criei partida pela tela, "beto"
  entrou via `curl`, a tela da "ana" pegou a mudança sozinha via polling
- APK Android de verdade: gerado `app/android/` (`flutter create
  --platforms=android .`), `AndroidManifest.xml` ganhou a permissão de
  INTERNET (faltava, o Multiplayer não funcionaria sem ela). Build local
  (`flutter build apk`) esbarra na mesma limitação de rede da JVM da
  DECISION-015 ("Unable to establish loopback connection", agora no
  Gradle) — contornado compilando via GitHub Actions
  (`.github/workflows/build-apk.yml`, `workflow_dispatch`, runner
  `ubuntu-latest`). APK publicado como asset de uma GitHub Release
  (`v0.1.0`) pra dar um link de download direto, já que o arquivo
  (48MB) passa do limite de anexo do chat e o amigo também precisa
  baixá-lo (não só o usuário). Ver DECISION-029. Verificado: build real
  no Actions terminou verde, `curl` no link de download confirmou
  `Content-Type: application/vnd.android.package-archive` e tamanho
  correto
- Cenário de batalha visual (Flame): fundo CC0 + dois personagens
  genéricos por lado + flash/shake ao tomar dano, ligado ao Modo Treino e
  ao Multiplayer, substituindo a demo Flame desconectada (DECISION-030)
- Sequência de feedback visual de ataque (Bloco 1 da direção de produto):
  preparação→efeito→impacto→dano→estado pra qualquer combinação, Modo
  Treino e Multiplayer, sem mudar battle_engine/backend (DECISION-031)
- Arena de batalha em pixel art (Bloco 2 da direção de produto): HUD estilo
  jogo de luta no topo, personagens em sprite pixel art (grade de cores em
  código), fundo procedural — Modo Treino e Multiplayer (DECISION-032)
- Tela inicial de verdade (Bloco 3 da direção de produto): título com
  contorno, personagens pixel art de frente, botões blocudos pro Treino/
  Multiplayer — substitui o placeholder antigo (DECISION-033)
- Consistência visual pixel art (Bloco 4 da direção de produto): Treino,
  Lobby e batalha Multiplayer ganham o mesmo fundo/título/botões da Home,
  sem mudar lógica nem texto (DECISION-034)
- Feedback visual pixel art em chips/campos/modal (Bloco 5 da direção de
  produto): `PixelElementChip`, `PixelTextField` e `PixelSheetPanel` novos,
  substituindo `FilterChip`/`TextField`/conteúdo cru do modal de Skill Tree
  em Treino e Multiplayer, sem mudar lógica nem texto (DECISION-035)
- Animações + painel de seleção de elementos (Bloco 6 da direção de
  produto): idle nos sprites (Home e batalha), botões/chips afundando ao
  toque, transição de tela em slide de baixo pra cima, e a lista de
  elementos virando um painel (`PixelSheetPanel`) em vez de ficar sempre
  visível — resolve a rolagem em Treino e Multiplayer (DECISION-036)
- Checagem obrigatória de atualização: `UpdateChecker` consulta a API do
  GitHub Releases, `UpdateGateScreen` vira a raiz do app e bloqueia o jogo
  inteiro se existir versão mais nova (fail-open em erro de rede,
  checagem só em Android) — acaba com o aviso manual de "tem APK novo"
  pro amigo (DECISION-037)
- Skill Tree visual (Bloco 7 da direção de produto): `SkillTreeScreen`
  única (Treino e Multiplayer) substitui o modal de "disponíveis agora"
  por uma árvore completa — travados/disponíveis/desbloqueados juntos,
  ícone por nó, 5 branches lado a lado roláveis, painel de detalhe ao
  tocar um nó (DECISION-038)
- Assinatura estável do APK: workflow de build passa a cachear o keystore
  de debug entre execuções, em vez de gerar um novo a cada build —
  corrige atualização in-place falhando com "app não instalado"
  (DECISION-039)
- Download de atualização dentro do app: `UpdateGateScreen` baixa o APK
  com barra de progresso (pacote `ota_update`) e abre o instalador do
  Android sozinho, substituindo o "abrir navegador" — erro mostra
  "Tentar de novo", sem fallback pro navegador (DECISION-040)
- Core library desugaring habilitado no Gradle do app — exigido pelo
  `ota_update`, descoberto só numa build real via GitHub Actions
  (DECISION-041)
- Efeitos sonoros (Bloco 8 da direção de produto): primeiro som do jogo —
  `SfxPlayer`/`flame_audio`, 6 sons CC0 cobrindo toque de botão/chip,
  ataque disparado, impacto, habilidade desbloqueada, vitória (Treino) e
  vitória/derrota (Multiplayer). Só efeitos sonoros — sem música de fundo
  nem botão de mutar (DECISION-042)
- Badges de status ativo/efeito de campo (Bloco 9 da direção de
  produto): círculo colorido com ícone e turnos restantes na cena de
  batalha, substituindo o texto cru — Treino e Multiplayer, sem mudar
  battle_engine/backend (o Multiplayer já recebia `combatantStatuses`
  do backend, só o cliente nunca parseava) (DECISION-044)
- Progressão persistente do Modo Treino (Bloco 10 da direção de
  produto): Skill Tree (por Jogador A/Jogador B) e Livro de Descobertas
  (compartilhado) sobrevivem a "Nova partida" e a fechar/reabrir o app,
  via `shared_preferences` local ao aparelho (DECISION-045)
- Custo de AP pra combinar elementos (Bloco 2a, fora da ordem de
  prioridade do CLAUDE.md, a pedido do usuário após jogar): elemento
  sozinho grátis + 5 de dano básico; combinar 2-3 elementos custa AP
  (3/5), que regenera +1 por turno próprio e acumula (não recarrega
  tudo de uma vez); sem AP suficiente, a jogada inteira é rejeitada.
  Pips de AP no HUD de batalha (Treino e Multiplayer). Sincronizado em
  `battle_engine` (Dart) e `backend/src/battle-rules/` (TypeScript)
  (DECISION-046)
- Elementos bloqueados no Modo Treino (Bloco 2b, sequência combinada
  com o usuário desde o Bloco 2a): cada jogador escolhe 2 elementos
  iniciais uma vez, os outros 8 desbloqueiam via nova branch
  "elementos" na Skill Tree (`ElementUnlock`/`ElementUnlocks`), com
  custo crescente em turnos cumulativos jogados ((E-1)×10) além do
  pré-requisito de sempre. Só Modo Treino — Multiplayer aguarda o
  Bloco 11 pra ter persistência real primeiro (DECISION-047)
- Ataques combinados equipáveis no Modo Treino (Bloco 2c, sequência
  combinada com o usuário desde o Bloco 2a, fecha a sequência): a
  primeira vez que um jogador dispara uma combinação, ela vira um
  ataque pessoal desbloqueado; até 3 podem ficar equipados por vez
  (`AttackLoadout`, novo, separado do Livro de Descobertas
  compartilhado); replay de combo desbloqueado-mas-não-equipado é
  rejeitado; vaga livre equipa automático, vagas cheias abre a tela
  "Ataques Combinados" pedindo a troca. Só Modo Treino — Multiplayer
  aguarda o Bloco 11 (DECISION-048)

# BLOCKED

Nenhum
