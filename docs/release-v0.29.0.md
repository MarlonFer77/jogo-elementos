# Preparação da v0.29.0 (Android build 29)

Branch: `codex/release-v0.29.0`. Esta preparação não dispara build, cria tag,
publica release nem faz deploy do servidor.

## Conteúdo desde v0.28.0

- Criaturas próprias da dungeon, intenção de ataque e novos sons Kenney CC0.
- Balanceamento de combos/progressão e conclusão dos talentos existentes.
- Multiplayer preparado para beta de até 10 pessoas, com limites e recuperação
  de polling (não é um teste em dez celulares reais).
- Tutorial, volume/mudo persistentes e mudo rápido no combate.
- Selos v2 com dificuldade por receita e 100/80/60/40% do dano direto.
- Livro e Skill Tree no tema RPG, filtros, sinergias e planejamento de build.

## Build e publicação manual

1. No GitHub, Actions → **Build Android APK** → **Run workflow**. Selecione
   `codex/release-v0.29.0` e execute. O workflow é manual, não roda ao fazer push.
2. Ao terminar com sucesso, baixe o artifact `jogo-elementos-apk`. Extraia o
   arquivo `app-release.apk`; não envie o ZIP como instalador.
3. Teste atualização por cima da v0.28.0 (assinatura precisa ser a mesma),
   Treino/Dungeon nas duas orientações, som e selos em aparelho real.
4. Em uma janela sem partidas multiplayer em andamento, atualize o Render para
   **o mesmo commit desta branch**. Mantenha as variáveis secretas já existentes.
   Novos clientes precisam do backend v2; antigos serão orientados a atualizar
   ao iniciar selos. Faça o teste de criar/entrar e conjurar com dois celulares.
5. Releases → Draft a new release → nova tag `v0.29.0`, target
   `codex/release-v0.29.0` (confira o commit usado no build). Anexe
   **`app-release.apk`**, marque como release estável/latest e publique apenas
   após validar app + servidor. O atualizador procura esse nome exato de asset.

Não construir a partir de `master` sem antes integrar essas alterações. Não
desinstalar o app para contornar assinatura incompatível: isso pode apagar o
progresso local. Preserve a chave já usada nos APKs anteriores.
