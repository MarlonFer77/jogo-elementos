import 'dart:ui';

/// Grade de pixels (20 linhas × 16 colunas) de um combatente genérico —
/// cabeça, tronco, cinto, pernas — desenhado por índice de cor, `0` sempre
/// transparente. A MESMA grade serve pros dois lados (ver [pixelPaletteLeft]/
/// [pixelPaletteRight]) — ver
/// docs/superpowers/specs/2026-09-08-pixel-battle-arena-design.md.
const List<List<int>> trainerSpriteGrid = [
  [0, 0, 0, 0, 0, 3, 3, 3, 3, 3, 3, 0, 0, 0, 0, 0],
  [0, 0, 0, 0, 1, 2, 2, 2, 2, 2, 2, 1, 0, 0, 0, 0],
  [0, 0, 0, 0, 1, 2, 2, 2, 2, 2, 2, 1, 0, 0, 0, 0],
  [0, 0, 0, 0, 1, 2, 1, 2, 2, 1, 2, 1, 0, 0, 0, 0],
  [0, 0, 0, 0, 1, 2, 2, 2, 2, 2, 2, 1, 0, 0, 0, 0],
  [0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0],
  [0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0],
  [0, 0, 0, 1, 4, 4, 4, 4, 4, 4, 4, 4, 1, 0, 0, 0],
  [0, 0, 0, 1, 4, 4, 4, 4, 4, 5, 5, 4, 1, 0, 0, 0],
  [0, 0, 0, 1, 4, 4, 4, 4, 4, 5, 5, 4, 1, 0, 0, 0],
  [0, 0, 0, 1, 4, 4, 4, 4, 4, 5, 5, 4, 1, 0, 0, 0],
  [0, 0, 0, 1, 4, 4, 4, 4, 4, 5, 5, 4, 1, 0, 0, 0],
  [0, 0, 0, 1, 6, 6, 6, 6, 6, 6, 6, 6, 1, 0, 0, 0],
  [0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0],
  [0, 0, 0, 0, 1, 1, 1, 0, 0, 1, 1, 1, 0, 0, 0, 0],
  [0, 0, 0, 0, 1, 3, 3, 0, 0, 3, 3, 1, 0, 0, 0, 0],
  [0, 0, 0, 0, 1, 3, 3, 0, 0, 3, 3, 1, 0, 0, 0, 0],
  [0, 0, 0, 0, 1, 3, 3, 0, 0, 3, 3, 1, 0, 0, 0, 0],
  [0, 0, 0, 0, 1, 6, 6, 0, 0, 6, 6, 1, 0, 0, 0, 0],
  [0, 0, 0, 0, 1, 1, 1, 0, 0, 1, 1, 1, 0, 0, 0, 0],
];

/// Paleta pro lado esquerdo. Índices: 0 transparente, 1 contorno, 2 pele,
/// 3 cabelo/detalhe escuro, 4 cor principal, 5 sombra da cor principal,
/// 6 cinto/detalhe.
const List<Color> pixelPaletteLeft = [
  Color(0x00000000),
  Color(0xFF20242B),
  Color(0xFFF4C99B),
  Color(0xFF2B2F38),
  Color(0xFF3D6FE0),
  Color(0xFF2B52B0),
  Color(0xFFF4C94A),
];

/// Paleta pro lado direito — mesmos índices, só a cor principal/sombra
/// (4/5) mudam.
const List<Color> pixelPaletteRight = [
  Color(0x00000000),
  Color(0xFF20242B),
  Color(0xFFF4C99B),
  Color(0xFF2B2F38),
  Color(0xFFE0503D),
  Color(0xFFB02B2B),
  Color(0xFFF4C94A),
];

/// Desenha [grid] em [canvas]: cada célula vira um `Rect` de [pixelSize]
/// lógico, na cor `palette[índice]`. Índice `0` nunca é desenhado
/// (transparente). Pura função de desenho — não sabe nada de personagem,
/// lado ou jogo.
void drawPixelGrid(
  Canvas canvas,
  List<List<int>> grid,
  List<Color> palette, {
  required double pixelSize,
}) {
  for (var row = 0; row < grid.length; row++) {
    final cols = grid[row];
    for (var col = 0; col < cols.length; col++) {
      final index = cols[col];
      if (index == 0) continue;
      canvas.drawRect(
        Rect.fromLTWH(col * pixelSize, row * pixelSize, pixelSize, pixelSize),
        Paint()..color = palette[index],
      );
    }
  }
}
