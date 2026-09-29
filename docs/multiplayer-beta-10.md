# Multiplayer — beta de até dez pessoas

Dimensionamento-alvo: dez jogadores, até cinco duelos simultâneos. Não é um
limite de cadastro nem controle de convidados. Manter distribuição restrita ao
grupo; esta configuração não equivale a lançamento público irrestrito.

## Implementado

- Polling existente de 2 segundos, pausado quando o app perde o primeiro plano.
  Retomar faz uma leitura; nunca repete automaticamente ataque/criação de sala.
- Falhas de leitura esperam 2, 4, 8, 16 e até 30 segundos. `Retry-After` é
  respeitado (até 10 minutos). Sucesso restabelece a frequência normal.
- Cada instância admite até 40 requisições em processamento. Excesso retorna
  503 e espera de 3 segundos; timeouts HTTP evitam uploads indefinidos.
- 900 requisições/minuto por instância; 120/minuto por credencial nas rotas de
  sala, das quais até 60 POST/minuto. Criação: 6 por credencial/10 minutos e
  60 globais/10 minutos. Inclui tentativas inválidas; não há limite de cinco
  salas históricas. Não é necessário criar outra sala para reconectar.
- Controle em memória, até 256 contadores; guarda hashes, nunca tokens puros.
  Não confia em `X-Forwarded-For`; pessoas na mesma rede não dividem um limite
  por IP. Reinício limpa contadores; não protege contra DDoS distribuído.
- Credencial malformada é rejeitada antes de consultar o banco; requisições
  JSON têm limite de 64 KiB, campos textuais até 64 caracteres. Erros internos
  não expõem mensagens técnicas; respostas de sala não permitem cache HTTP.
- Firestore compartilha GETs simultâneos da mesma sala, mantendo cache de
  1,5 segundo. Transação concluída abastece cache; leitura antiga não sobrescreve
  revisão mais nova. Cada consumidor ainda passa pela autorização.
- Transações continuam validando revisão, turno, AP, equipamento e selos.
  Perfis continuam salvos após partidas concluídas. `updatedAt` nos documentos
  de sala registra atividade de escrita sem gerar gravações extras no polling.

## Escopo operacional

Manter uma instância do backend e o Firestore já configurado. Nenhuma assinatura,
serviço, regra de faturamento ou infraestrutura foi alterada neste bloco.
Dez pessoas não garantem consumo ilimitado: duração das sessões, quantidade de
salas e polling importam. Acompanhar uso no console durante os testes; não
habilitar cobrança para contornar limite sem autorização.

Credenciais são por instalação/URL, não contas recuperáveis. Cada pessoa deve
usar o mesmo aparelho e nome e guardar seu código de sala. Reinstalar/limpar
dados pode perder acesso. Não prometer recuperação de conta/progresso em nuvem
entre aparelhos neste beta.

## Publicação e teste em aparelhos — ainda pendentes

1. Publicar juntos backend e APK, incluindo os blocos anteriores de gameplay.
2. Conferir `/health`, persistência Firestore e manter HTTPS.
3. Duas pessoas criam/entram/preparam, jogam um combo e desbloqueiam habilidade.
4. Colocar um aparelho em segundo plano, desligar/ligar a rede e reconectar sem
   duplicar ação. Repetir com dez pessoas / cinco salas.
5. Concluir uma partida, criar outra e conferir progressão; reiniciar backend e
   reconectar a uma sala em andamento com os mesmos dados locais.

A simulação local de dez sessões passou; não é teste de carga do Render ou
Firestore real. Latência, quotas e suspensão Android precisam desse playtest.

## Retenção e recuperação

Nenhuma sala/perfil existente foi apagado. Não ativamos TTL, limpeza automática
ou backup pago. `updatedAt` ajuda futura manutenção; documentos antigos podem
não ter o campo. Antes de qualquer limpeza, definir prazo, exportação segura e
testar restauração, preservando perfis e partidas em andamento. Backups devem
ser privados porque snapshots contêm hashes de credenciais. Esta política e a
recuperação de identidade continuam pendentes antes de distribuição mais ampla.
