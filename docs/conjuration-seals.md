# Selos de Conjuração

Implementação local após v0.23.0; não publicada.

- Combo manual ou habilidade equipada abre o mesmo selo. Primeiro toque no nó 1
  reserva a ação; antes dele é possível voltar sem custo. Básicos/defesa/gelo seguem diretos.
- Receitas de 2 elementos: 4 nós/6 segundos; de 3: 6 nós/8 segundos. Geometria fixa,
  independente da ordem de seleção, em coordenadas normalizadas; tolerância 13%.
  Traçar na ordem. Soltar não reinicia: retomar pelo último nó; multitoque ignorado.
- UI não calcula dano. Sucesso usa o fluxo existente, incluindo equipamento,
  modificadores, descoberta, status, AP e animação. Sem bônus por velocidade.
- Interrupção custa 1 AP, sem regenerar, não ataca nem aplica mutações; passa o
  turno com o processamento habitual de status/DOT/vitória. Não concede descobertas.
  Fechar/suspender durante o traçado interrompe a tentativa.

## Multiplayer

`POST /matches/:id/seal/start`: ação, credencial e revisão. Valida a prévia e
persiste `seal` com ID único, ator, elementos, AP reservado e prazo. Reserva é
exclusiva: não debita antecipadamente, mas bloqueia ações, equipamento e Skill Tree.
Não manda um pacote por ponto: início e resolução são as duas escritas normais.

`POST /matches/:id/seal/finish`: ID do selo e amostras `{x,y,ms}` dos nós atingidos.
Valida ordem, coordenadas finitas, tempo crescente e prazo do servidor. Traço
inválido/incompleto resolve como falha; token de outro jogador e replay são rejeitados.
`/turns` não permite combos diretos. `/preview` permanece sem efeitos colaterais.

O prazo começa no servidor ao iniciar. Cliente desconta o RTT inteiro do tempo
mostrado, conservadoramente, sem depender da sincronização de relógios. Servidor
permite 1,5 segundo adicional para transporte; amostras nunca podem declarar tempo
maior que a janela de desenho. Em rede lenta pode ser preciso tentar outro turno.
Sem resposta não reenvia automaticamente: polling recupera o estado. Selo expirado
é resolvido por transação na primeira leitura; reiniciar backend não reinicia prazo.
O adversário vê o avatar canalizando via polling existente (não tempo real).

Isso valida protocolo e plausibilidade, não prova movimento humano: cliente
modificado ainda pode sintetizar um traço válido. Não prometer anticheat competitivo.

## Arquivos e compatibilidade

- `app/lib/game_domain/conjuration_seal.dart` ↔ `backend/src/battle-rules/seal.ts`:
  manter geometria, duração e tolerância iguais.
- `TurnAction.fizzle` / `kind: fizzle`: resolução interna sem efeito ofensivo.
- Telas usam diálogo comum; Flame só apresenta pose/energia e resultado.
- Dados antigos não têm `seal` e continuam válidos. Sem migrar progresso local.
- Publicar backend e APK juntos: v0.23.0 não implementa o novo protocolo de selos.
- Validar em dois celulares: arraste, correção, suspensão, rotação e latência real.
