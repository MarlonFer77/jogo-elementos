# BETA TEST — Ruína dos Ecos

Primeiro protótipo solo de ação 3D dentro do app, implementado em 09/10/2026.
Não substitui o combate por turnos. Sem APK, release, deploy ou assinatura nova.

## Acesso

Menu inicial → BETA TEST → senha de seis dígitos definida pelo responsável.
O zero inicial faz parte da senha. Nova entrada exige a senha novamente;
não há desbloqueio permanente nem armazenamento da senha digitada.

**Trava local para testadores, não autenticação segura:** a verificação está
no cliente e pode ser encontrada/contornada inspecionando o APK. Não concede
privilégios online. Distribuição restrita real precisará de autorização no
servidor ou canal fechado, em outro bloco.

## Recorte jogável

- Ruína low-poly, câmera em perspectiva seguindo o herói, colisões com colunas
  e limites. Herói e criaturas usam malhas XYZ construídas no código, não sprites.
- Joystick multi-touch, espada, magia e esquiva. Mira no inimigo visível mais
  próximo dentro do alcance. Espada atinge uma vez por ação, recarga de 0,52s.
- Magia canaliza por 0,35s, custa 25 MP, recarrega em 1,25s. Regeneração: 9 MP/s.
- Fogo: projétil + queimadura. Água: lentidão + cura de 8 HP somente ao acertar.
  Vento: explosão curta com interrupção/afastamento. Terra: impacto e proteção
  de 50% por dois segundos. São magias individuais; combos 3D ainda não existem.
- Esquiva direcional: invulnerabilidade breve, recarga de 1,6s; não atravessa
  colunas ou bordas. Círculos anunciam a área comprometida do ataque inimigo.
- Três encontros: goblins, grupo com bruto e guardião com escolta. Entre grupos,
  recuperação de até 20 HP/25 MP. XP aumenta nível, vitalidade e dano na sessão.
- Vitória/derrota permitem reiniciar. Sair descarta progresso experimental.
  Não grava XP, elementos, habilidades ou recompensas em outros perfis.
- Respeita volume/mudo global. Trocar de aplicativo pausa; retomada explícita
  limpa movimento anterior. Voltar durante a ação abre a pausa antes de sair.

Teclado: WASD/setas, J (espada), K (magia), Espaço (esquiva), 1–4 (elemento),
Esc (pausa). No celular todas essas ações possuem controles de toque.

## Integração e limites

- `beta_session.dart`: regras puras Dart, tempo em subpassos limitados, IA,
  colisão, projéteis, recursos e progressão temporária.
- `beta_game.dart`: loop Flame, áudio existente e HUD atualizado a 10 Hz.
- `beta_arena_painter.dart`: malhas, câmera, projeção, iluminação direcional,
  ordenação de faces, animação de membros e feedback visual.
- `beta_screen.dart` / `beta_controls.dart`: HUD, ciclo de vida e controles.
- `beta_access_screen.dart`: trava local. Home: botão novo e grade compacta.

Sem dependências novas, serviços, assets externos ou mudanças no engine por
turnos/backend. Renderizador pequeno usando [Canvas do Flutter](https://api.flutter.dev/flutter/dart-ui/Canvas-class.html)
para projetar malhas. Não é motor 3D geral: sem depth buffer, modelos esqueléticos,
salto/física vertical ou mundo aberto. Geometria cruzada poderá exigir renderizador
mais robusto no futuro. Desempenho de produção ainda não está demonstrado.

## Verificação e próximo trabalho

17 testes focados (regras, menu e UI): dano único, recargas, mana, status,
colisões/desvio da IA, pausa, vitória/derrota, senha com zero inicial, reentrada,
multi-touch e ausência de escritas nos perfis existentes. Previews inspecionados
em 320×568, 360×640 e 640×360. `ELEMENTOS_ART_PREVIEW=1` habilita capturas no
teste `beta_screen_test.dart`.

Pendente: playtest e medição de FPS/bateria/temperatura em Android real.
Prioridade seguinte: câmera, alcance e resposta dos controles conforme esse
feedback; depois desenhar combos de ação, exploração e progressão permanente.
