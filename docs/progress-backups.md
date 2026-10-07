# Proteção da progressão

Implementação local; não altera os dados do Firebase ou aparelhos até publicação.

## Treino e Dungeon

- Chaves e formatos existentes preservados. Cada valor possui uma cópia anterior
  válida (`.backup.v1`), gravada antes de substituir o principal.
- Primeira gravação já cria uma cópia. Gravações de progresso são serializadas
  no isolate, mesmo entre instâncias diferentes dos stores.
- Valor ausente/corrompido pode carregar a cópia. A UI informa a recuperação.
  Valor corrompido fica intacto até salvar novamente; nessa hora é preservado em
  `.corrupt.v1` (uma cópia limitada por chave).
- Sem cópia válida, o jogo não reinicializa nem sobrescreve dados. Treino mostra
  erro com nova tentativa; Dungeon mantém seu tratamento de erro existente.
- Retorno falso/erro de escrita é tratado; o cache de SharedPreferences é
  recarregado para não transformar gravação falha no próximo backup.
- Dungeon valida estrutura, IDs, pontos e equipamento; versão futura bloqueia
  leitura/gravação. Treino valida tipos das chaves legadas e turnos não negativos,
  mantendo a normalização de IDs/equipamentos feita por TrainingMatch.

## Multiplayer

- `elementosProfiles` recebe versão 1 e revisão crescente, aceitando documentos
  legados sem esses campos. A validação cobre tipos, IDs, pré-requisitos e loadout.
- `elementosProfileBackups/{mesmaChave}` mantém o perfil anterior válido, sem
  tokens, senhas ou chaves privadas. Não há endpoint de upload de progresso.
- Resultado, novo perfil e backup são gravados na mesma transação. Todas as
  leituras precedem escritas; conflitos do Firestore recalculam os ganhos.
- Perfil ilegível/ausente usa a cópia válida; se ambos forem ilegíveis, retorna
  erro preservando os documentos. Perfil com versão futura não é rebaixado.
- Novas salas guardam os turnos/revisão de origem. Ao finalizar, somam somente
  os turnos ganhos nessa sala, unem descobertas/talentos e preservam o loadout
  mais recente quando a sala partiu de uma revisão antiga. Nunca reduzem turnos.
- Elementos de escolhas iniciais divergentes só são incorporados até o limite
  permitido pelos turnos acumulados; duas salas não concedem elementos grátis.
- Salas antigas sem origem usam `max(atual, recebido)` para evitar dupla contagem;
  não é possível reconstruir com certeza ganhos concorrentes antigos.
- Repetir encerramento não regrava/recompensa. Cancelar antes do combate não
  substitui perfil. Regras de combate e autenticação permanecem no servidor.

## Custo e limites

Sem serviço pago, cron, nova dependência ou escrita por polling. Por término,
até duas leituras de perfil e duas escritas de backup adicionais; recuperação
consulta a cópia apenas quando o principal falta ou falha na validação. A criação
de sala pode consultar backup de perfil inexistente. O free tier tem limites.

Uma cópia anterior pode perder o último avanço. Cópias locais não protegem contra
desinstalação/perda do aparelho, nem corrupção de todo o arquivo de preferências.
Treino ainda salva campos separados, não uma transação de todos os campos; o
encerramento forçado durante várias gravações continua sendo uma limitação.
Não existe sincronização offline-online nem importação de XP offline no multiplayer.

O backup online fica no mesmo projeto Firestore: não protege contra exclusão do
projeto, das duas coleções, nem corrupção estrutural que continue passando na
validação. Contas, claims e partidas não recebem backup externo neste bloco.
Perfis continuam consolidados ao término da partida; o estado em andamento segue
na coleção de partidas. Backups passam a existir após uma gravação nesta versão.

## Verificação

Testes focados cobrem corrupção, ausência de chave, formato futuro, migração de
chaves legadas, gravações concorrentes locais, conflitos de salas, cópia anterior,
encerramento repetido e ausência de backup válido. Firestore usado nos testes é
simulado; falta ensaio em projeto de teste e aparelhos reais antes de publicar.
