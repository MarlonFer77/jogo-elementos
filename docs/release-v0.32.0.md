# Elementos v0.32.0 — BETA TEST 3D e variações da Dungeon

## Novidades

- **BETA TEST:** novo protótipo solo de RPG de ação 3D, acessível pelo menu com
  senha de testador. Ruína low-poly, joystick, espada elemental, magia e esquiva.
- Quatro elementos no beta: Fogo, Água, Vento e Terra, com efeitos distintos.
  Três encontros com goblins, bruto e guardião final; XP e níveis durante a sessão.
- Ataques inimigos sinalizados no chão, colisões com colunas, pausa ao trocar de
  aplicativo e controles para jogar na vertical ou horizontal.
- **Dungeon:** 30 variantes de combate nas dez salas, entre ofensiva, defensiva
  e controle, incluindo três repertórios para o dragão.
- Acampamento mostra o próximo adversário, repertório e dicas. Prepare até quatro
  elementos e três habilidades antes da luta. Mapa recolhido e layout horizontal.
- A rota da expedição fica salva: sair e reabrir não sorteia outros encontros.
  Expedições antigas em andamento mantêm os padrões anteriores até terminar.
- Menu compacto em grade para manter os quatro modos acessíveis.

## Como atualizar

Baixe **app-release.apk** e instale por cima da versão atual. **Não desinstale
nem apague os dados:** Treino e Dungeon têm progresso local; entrar na conta não
restaura esses perfis. Faça uma cópia de segurança antes de atualizar, se possível.

A Dungeon migra para o formato de save 3 sem reset. Após salvar nesta versão,
não volte a um APK antigo: ele pode não reconhecer o novo formato.

## Observações

- O BETA TEST é experimental, offline e separado dos demais modos. Seu progresso
  dura apenas a sessão. Ainda não inclui combos 3D, mundo aberto ou save permanente.
- A senha é uma trava local para testadores, não autenticação de segurança.
  Peça a senha ao responsável pelos testes; não foi incluída nestas notas.
- O desempenho e o balanceamento do beta ainda precisam de validação em celulares
  reais. O renderizador inicial usa geometria simples, com limitações de profundidade.
- Treino, Multiplayer e seus perfis permanecem separados. Esta release não muda
  o backend nem o protocolo de comunicação, portanto não requer deploy no Render.
- Assinatura definitiva continua adiada. O build mantém a chave existente e
  interrompe se o certificado não for compatível com os APKs anteriores.

## Validação

39 testes focados das variações da Dungeon e 17 do beta/menu aprovados durante
o desenvolvimento; análise Dart limpa. Interfaces inspecionadas em telas
verticais e horizontais, incluindo 320×568. Instalação em Android real pendente.

Versão **0.32.0**, build **32**. Identificação do artefato será registrada após
a compilação e a conferência da assinatura/hash.
