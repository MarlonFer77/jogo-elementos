# Lobby e conexão

- Entrada pixel art com Criar, Entrar e Retomar. Nome identifica o perfil na credencial de instalação existente; não é uma conta com senha.
- Código de 6 caracteres, normalizado para maiúsculas. Erros não apagam os campos.
- Tela de conexão corresponde à requisição real, sem porcentagem fictícia, chamadas de saúde extras ou retry automático. Voltar/envios duplicados ficam bloqueados durante a operação (timeout HTTP existente: 20s).
- Última sala usa o nome salvo, mesmo que o campo tenha sido editado. Reconectar manualmente também lembra a sala após autorização.
- Sala de espera com código selecionável/copiável e preparação de cada jogador. Esses dados não representam presença online em tempo real.
- Preparar elementos reutiliza a tela existente. Após confirmação, volta à sala ou entra na batalha quando ambos estiverem prontos. Em falha, uma leitura verifica se a preparação foi aceita antes de permitir nova tentativa.
- Polling e credencial atuais mantidos; nenhuma nova infraestrutura ou cobrança. Voltar ao lobby não exclui sala nem progresso.
- Layout vertical/horizontal rolável, incluindo teclado aberto.

Validação focada de navegação, preparação, erros, duplicação, retomada e layout. Teste físico em dois aparelhos pendente. Não publicado.
