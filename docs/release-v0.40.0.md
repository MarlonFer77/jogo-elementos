# Elementos v0.40.0 — Sua Aventura Continua

## Novidades

- **Cadastro na entrada do BETA**: e-mail, confirmação de senha e verificação
  de e-mail. O Firebase gera o ID da conta; contas do Multiplayer também servem.
- **Continuar aventura**: checkpoints guardam nível, XP, pontos de habilidade,
  build, combos, puzzles, cenários restaurados, vida e mana.
- **Saves separados por conta** no mesmo aparelho, retomada pausada e confirmação
  antes de substituir uma aventura.
- Recuperação de checkpoint local corrompido quando existe cópia válida.
  Falhas ao salvar são exibidas e permitem tentar novamente.
- Sair durante uma luta retorna ao início daquele combate, sem duplicar XP
  de inimigos derrotados parcialmente.

## Instalação e limites

Baixe **app-release.apk** e instale por cima da versão anterior, **sem desinstalar
nem limpar os dados**. Confira a versão **0.40.0** no aplicativo.

O primeiro cadastro/login e a confirmação do e-mail precisam de internet.
Após confirmar a identidade, a aventura solo pode continuar offline.

**O save é local, não está na nuvem.** Entrar em outro celular não recupera a
aventura. Desinstalar ou limpar dados pode apagar o progresso e a coleção.
A loja e os Ecos continuam compartilhados no aparelho; não foram migrados
para a conta. Iniciar nova aventura não apaga as compras.

Treino, Dungeon e servidor Multiplayer não recebem mudanças neste bloco.
A assinatura anterior foi preservada; assinatura definitiva continua pendente.
O BETA permanece experimental.

## Validação no celular

- Atualize sem desinstalar e confira compras, saldo e perfis anteriores.
- Crie uma conta, confirme o e-mail e entre no BETA; ou use uma conta existente.
- Avance, resolva um puzzle, salve e saia. Feche e reabra o app para continuar.
- Saia durante uma luta e confira a retomada completa do combate, sem XP extra.
- Troque de conta e confira que cada uma mantém sua própria aventura.
- Confira orientação, áudio e fluidez. Testes automatizados não substituem
  esta validação física.

## APK verificado

- Commit compilado: `33aac587da46f44350c627434f34ae1b048d2ac4`.
- [Build GitHub Actions](https://github.com/MarlonFer77/jogo-elementos/actions/runs/39478699114).
- `app-release.apk`: 59.594.110 bytes; versão `0.40.0+40`.
- Package ID `com.example.app`; Android 7/API 24 ou superior.
- Arquiteturas: arm64-v8a, armeabi-v7a e x86_64; APK não depurável.
- Certificado igual ao da v0.39.0, mantendo a assinatura Android Debug anterior.
- SHA-256: `203558d3064f8f0ce929d43af033c85858c1fd3051812c51817e3bedf0c4e455`.

27 testes focados de cadastro, checkpoints e atualizador passaram nesta release;
análise estática dos arquivos alterados sem problemas. Hash local igual ao build.

Publicada como Latest em 20/10/2026. Digest público igual ao APK validado.
Verificador real confirmou 0.39.0+39 → 0.40.0; a própria 0.40.0+40 está atualizada.
