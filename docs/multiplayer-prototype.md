# Multiplayer — protótipo local

## Firestore (v0.23.0)

Backend: `MATCH_STORE=firestore`, `FIREBASE_PROJECT_ID=elements-1173d` e
`FIREBASE_SERVICE_ACCOUNT_JSON` em variável secreta do Render. Alternativamente,
usar ADC/`GOOGLE_APPLICATION_CREDENTIALS` somente no servidor.
Coleções privadas: `elementosMatches` (partida + hashes das credenciais) e
`elementosProfiles` (progresso de partidas concluídas). Regras do cliente seguem
negando acesso direto; o APK não contém credenciais Firebase.
Cada ação é uma transação que revalida a revisão. Polling usa cache curto de
1,5 segundo; falha na persistência retorna erro, sem confirmar ação em memória.
O banco Standard existente em southamerica-east1 tem free tier e o projeto
teve cobrança desativada confirmada em 2026-09-23. Não ativar faturamento para
contornar quotas. Este protótipo ainda precisa de limites de tráfego e retenção
antes de abertura pública ampla.

## Incluído

- Preparação individual com 2 elementos; até 4 básicos e 3 habilidades.
- Descobertas desbloqueiam ataques; quarto ataque fica disponível para troca.
- Servidor valida elementos, equipamento, turno, AP, status e Skill Tree.
- Credencial local por instalação/URL; reconectar requer mesmo nome e aparelho.
- Revisão em configurações, habilidades, prévias e ações. Repetição rejeitada.
- Polling sem sobreposição e descarte de respostas antigas, timeout de 20 segundos.
- Controles vertical/horizontal; arena/efeitos compartilhados com Treino.
- Progresso reaproveitado após partidas concluídas. Não importa saves do Treino.

## Rodar localmente

No diretório `backend`, configurar `MATCH_STORE_FILE` com um caminho absoluto
para `backend/data/matches.json`, então executar `npm run dev`.
Sem essa variável, o armazenamento é só memória.
O diretório `backend/data` está ignorado pelo Git.

Executar o app com `flutter run --dart-define=MULTIPLAYER_BASE_URL=URL_DO_BACKEND`
apontando para esse backend (ver
`app/lib/game_domain/multiplayer_config.dart`). Em outro aparelho, localhost
não aponta para o computador: usar endereço alcançável na rede e a configuração
Android existente. Não desabilitar TLS nem abrir firewall automaticamente.

1. Aparelho A cria a sala e escolhe elementos; compartilha o código.
2. B entra, escolhe elementos; ambos aguardam preparação antes de agir.
3. Experimentar, descobrir, equipar, defender e desbloquear habilidades.
4. Fechar/reabrir o app e usar Reconectar; nome/código ficam lembrados.
5. Reiniciar o backend com o mesmo arquivo e verificar continuidade.

## Antes de produção pública

- Atualizar backend e APK juntos: o novo contrato rejeita clientes antigos.
- Escolher armazenamento durável dentro do orçamento. Arquivo em disco efêmero
  não preserva dados após substituição da instância; não considerar isso resolvido
  no Render apenas por definir uma variável. Nenhum recurso foi provisionado.
- Arquivo suporta uma instância apenas; não usar réplicas simultâneas.
- Definir backups, retenção/limpeza de salas, rate limiting e limites de uso.
- Usar HTTPS. Credencial de instalação não é login, conta ou recuperação em outro
  aparelho; limpar os dados do app perde o acesso. Definir recuperação antes de
  oferecer progressão permanente como promessa ao jogador.
- Migrar fixtures antigas para o contrato com credencial, revisão e preparação.
- Validar dois aparelhos físicos, suspensão do Android, rede móvel e balanceamento.

Validação feita: testes locais de dois clientes HTTP, persistência/reinício,
progressão entre partidas e widgets nas duas orientações. Não houve deploy,
geração de APK ou teste físico nesta etapa.
