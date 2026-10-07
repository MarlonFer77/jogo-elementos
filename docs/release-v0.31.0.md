# Elementos v0.31.0 — Bênçãos e arenas

## Novidades

- Nove bênçãos temporárias na Dungeon: após as salas 3, 6 e 9, escolha uma entre
  três opções de ataque, proteção ou AP. Cada escolha vale só naquela expedição.
- Altares com seleção e confirmação, adaptados para vertical e horizontal;
  consulta das bênçãos no acampamento e durante a batalha.
- Dez arenas próprias da Dungeon, cenários de Treino e Multiplayer renovados,
  clima leve e novos efeitos de impacto, cura e proteção.
- Água básica remove sua Queimadura; Natureza básica remove seu Veneno.
  Quando recuperam, causam dano-base 3 em vez de 5.
- Cópia anterior de progresso, recuperação de saves e proteção contra gravações
  duplicadas ou incompatíveis. Perfis online ganham backup no Firestore.
- Verificação manual de atualização no menu, mensagens de falha mais claras
  e conferência SHA-256 do APK baixado pelo atualizador.
- Inclui as melhorias da v0.30.0, que não teve release pública: conta recuperável
  por e-mail/senha, vínculo do perfil antigo, recuperação de senha e tratamento
  de abandono/expiração das partidas multiplayer.

## Como atualizar

Baixe **app-release.apk** e instale por cima da versão atual. **Não desinstale
nem apague os dados do aplicativo**: Treino e Dungeon permanecem locais e não
são sincronizados pela conta. A cópia local também é apagada na desinstalação.

O progresso antigo da Dungeon é migrado sem reset. Expedições em andamento
recebem as escolhas dos altares já alcançados. Não volte a um APK antigo depois
de salvar na nova versão: o formato da Dungeon passa para a versão 2.

## Observações

- Mantidas as dez salas e a cura de 25 HP nos acampamentos. Bênçãos não afetam
  Treino comum ou Multiplayer, nem alteram a Skill Tree permanente.
- Android 7 ou superior. A publicação deve manter o certificado da versão
  anterior; a assinatura definitiva de produção continua pendente.
- Os testes automatizados dos blocos passaram, mas ainda falta validar em
  celulares reais a atualização sem desinstalação, o balanceamento/desempenho,
  login/recuperação e uma partida completa entre dois aparelhos.
- Backend deve acompanhar o commit do APK. Sem novo serviço pago.
- Backups online ficam no mesmo projeto Firestore; não são backups externos.
  Permanecem dois alertas moderados de dependências indiretas já documentados.
