# Abandono multiplayer

Implementado localmente; publicar app e backend juntos após teste em dois aparelhos.
Não foi gerado APK nem feito deploy neste bloco.

## Regras

- Sala aguarda o segundo jogador por 5 minutos. Ao entrar, inicia uma janela
  de 5 minutos para os dois prepararem os elementos. Expiração cancela sem vencedor.
- Com ambos prontos, cada turno tem 90 segundos. Configurar elementos, habilidades,
  consultar prévia e reconectar **não renovam** esse prazo.
- Ao expirar, o jogador da vez perde. Sair do app não pausa. Não há detecção de
  presença: é prazo de ação/reconexão, não uma alegação de desconexão confirmada.
- Selo iniciado a tempo pode terminar sua janela de execução. Abandonar o selo
  resolve a falha já existente, consumindo a ação; o próximo turno começa nessa
  resolução. Desistir explicitamente durante um selo encerra o duelo.
- Voltar abre confirmação: continuar, voltar ao lobby para reconectar ou desistir.
  Antes do combate, desistir cancela sem vencedor. Nenhum HP/dano é inventado.

## Persistência e autoridade

`deadline` e `ending` ficam no documento existente `elementosMatches`, no Cloud
Firestore (Firebase `elements-1173d`). Render executa o backend; não é o banco.
Treino/Dungeon continuam salvos localmente no aparelho.

O servidor valida prazo antes de aceitar ações. Um GET autenticado resolve o
encerramento vencido em transação. Sem ninguém consultando, a sala continua
armazenada com prazo vencido até a próxima consulta; não há worker nem varredura
paga. Isso não é retenção/limpeza de documentos nem backup.

Finalização e desistência repetidas não regravam progresso. Cancelamento antes
do combate não substitui perfis; vitória/derrota preservam progresso já obtido,
sem novas recompensas por abandono. O problema geral de concorrência entre
perfis de salas diferentes pertence ao bloco de proteção da progressão.

Salas antigas sem prazo ganham uma janela completa na primeira consulta.
GET inclui `serverNow`; o app ajusta a estimativa do contador ao relógio do servidor.
O relógio local jamais determina resultado. POST com resposta incerta não é
repetido automaticamente; consultar/reconectar confirma o estado.

## Verificação manual antes de publicar

Dois aparelhos: criar/entrar, sair e reconectar dentro de 90 s, aguardar prazo,
desistir durante conjuração, cancelar sala e reabrir após reinício do servidor.
Conferir mensagem/resultado nos dois lados, retrato e paisagem. Backend in-memory
só serve a testes locais; produção deve continuar com `MATCH_STORE=firestore`.

Próximos blocos, na ordem solicitada: login recuperável; backup/proteção;
operação/atualização; assinatura definitiva (planejar migração da chave atual).
