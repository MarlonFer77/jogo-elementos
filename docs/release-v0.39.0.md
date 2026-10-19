# Elementos v0.39.0 — Relíquias e Lendas

## Novidades

- **Anjo da Aurora, Demônio das Cinzas e Arthur de Camelot**: trajes do BETA
  com asas, auréola, chifres, cauda, coroa e armadura próprias.
- **Corte Giratório, Golpe Saltado e Mortal do Viajante**: animações equipáveis
  nos movimentos reais. Técnicas não aumentam dano, alcance ou invulnerabilidade.
- **Excalibur**: +4 de ataque; conjurar invoca Merlin e abençoa o próximo corte
  com +3 e energia elemental, por até 5s. Errar também consome a bênção.
- **Capa de Mercerus**: +10 agilidade, equivalente a +10% de movimento;
  distância e recarga da esquiva permanecem iguais.
- **Peitoral de Perseu**: impede queimadura e maldição, sem bloquear o impacto.
  Guardiões queimam por 3s (2 HP/s); elfos reduzem regeneração de mana por 4s.
- **Ateliê dos Ecos**: categorias Trajes/Técnicas/Relíquias, prévia animada,
  compra confirmada e espaços independentes para equipar/remover. Compras
  antigas, saldo e marcos de recompensa são preservados.
- **Grimório → Equipamento**: consulte o conjunto ativo e seus bônus.
  Para trocar, use a loja e entre novamente no BETA; reiniciar mantém o conjunto.
- **Combate mais legível**: vida baixa não é escondida pelos efeitos; indicadores
  com duração e explicação por toque longo. Perseu tem confirmação visual/sonora,
  queimadura e maldição têm sinais separados e a bênção conserva sua cor no golpe.
- Prévia mais limpa, pausa ao sair do aplicativo e ajustes para vertical/horizontal.
- **Cenários restaurados não regridem ao mudar de fase**: o visual conquistado
  acompanha a expedição; cada novo puzzle e portal continua exigindo resolução.

## Atualização e limites

Instale **app-release.apk** por cima da versão anterior, sem desinstalar nem
limpar dados. Confira **0.39.0** nas informações do aplicativo.

Itens exclusivos do **BETA 3D solo/offline**, comprados com Ecos locais — sem
dinheiro real nem vantagens no Multiplayer. Coleção compartilhada no aparelho,
fora do backup online. A loja migra o documento v1 para v2 preservando os dados;
não volte a APKs antigos depois de salvar o novo inventário.

O BETA continua experimental. Níveis/combos/puzzles da expedição são temporários;
as compras e os equipamentos da loja permanecem no aparelho. Treino, Multiplayer
e backend não recebem mudanças neste bloco. A assinatura definitiva segue pendente;
a chave anterior foi mantida para compatibilidade de atualização.

## Teste no celular

- Atualize sem desinstalar e confira saldo, compras anteriores e perfis.
- Compre, equipe e remova itens; saia/entre no BETA e reinicie a partida.
- Experimente os três trajes, técnicas, conjuração com Merlin e proteção de Perseu.
- Restaure o primeiro cenário e avance: a próxima região mantém o visual evoluído,
  mas seu portal permanece bloqueado até concluir o próprio combate e puzzle.
- Confira orientação, pausa, mudo/volume, legibilidade e fluidez por 15–20 minutos.

Verificações automatizadas não substituem o teste físico no Android.

## APK verificado

- Commit compilado: `6bae91843c7d02e120d70d23c77f01a5f4d5825d`.
- [Build GitHub Actions](https://github.com/MarlonFer77/jogo-elementos/actions/runs/39080467270).
- `app-release.apk`: 59.430.274 bytes; versão `0.39.0+39`.
- Package ID `com.example.app`; Android 7/API 24 ou superior.
- Arquiteturas: arm64-v8a, armeabi-v7a e x86_64; APK não depurável.
- Certificado igual ao da v0.38.0; assinatura Android Debug anterior preservada.
- SHA-256: `ef7d33729c443a892fc0c81241392d8e8d9af081149dd81d077124f849a6cf11`.

69 testes focados passaram antes do build, incluindo progressão visual entre
as seis regiões, puzzles, combate, loja, equipamento e atualizador. Análise
estática dos arquivos alterados sem problemas; hash local igual ao do build.

Publicada como Latest em 17/10/2026. Digest público igual ao APK validado.
Verificador real confirmou 0.38.0+38 → 0.39.0; a própria 0.39.0+39 está atualizada.
