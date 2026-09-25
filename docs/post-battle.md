# Pós-batalha

- `BattleResultPanel` compartilhado; arena permanece visível e a última animação termina antes do resultado.
- Revanche e Menu aparecem antes dos detalhes para facilitar uso na horizontal.
- `BattleProgress` compara snapshots imutáveis: descobertas, ataques e nós da árvore. Não concede prêmios nem escreve progresso.
- Treino captura a base ao criar cada batalha; registro compartilhado aparece uma vez, ganhos pessoais separados por jogador. Revanche redefine somente a comparação.
- Multiplayer captura a base ao entrar/criar ou concluir a preparação, usando exclusivamente dados do servidor. Polling não redefine a base; reconectar sem histórico informa a limitação em vez de inventar ganhos.
- Gestão de habilidades reaproveitada: editável no Treino, somente consulta após término no Multiplayer. Equipamento online continua validado na próxima partida.
- Revanche online continua criando outra sala; o painel explica que é necessário compartilhar o novo código. Erros permitem tentar novamente, sem envio duplicado durante a requisição.
- Sem alteração de protocolo, regras de combate, persistência ou infraestrutura. Publicado na v0.26.0.

Validação focada: diferenças de progresso, reconexão, duas orientações, arena mantida, consulta sem escrita e revanche do Treino. Resta validar o golpe final e a navegação em aparelhos físicos.
