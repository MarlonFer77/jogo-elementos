import 'package:flutter/material.dart';

/// Embrulha o conteúdo de um `showModalBottomSheet` (usado pelo modal de
/// Skill Tree em Treino e Multiplayer) num painel pixel art — fundo creme,
/// borda escura nos lados/topo (sem borda inferior, que encosta na borda
/// da tela) e cantos superiores arredondados, pra parecer um painel de
/// jogo subindo, não um bottom sheet branco genérico. O `showModalBottomSheet`
/// que usa isso precisa de `backgroundColor: Colors.transparent` pra essa
/// decoração aparecer no lugar do fundo branco padrão do Material.
class PixelSheetPanel extends StatelessWidget {
  const PixelSheetPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF4F4E4),
        border: Border(
          top: BorderSide(color: Color(0xFF2B2B2B), width: 3),
          left: BorderSide(color: Color(0xFF2B2B2B), width: 3),
          right: BorderSide(color: Color(0xFF2B2B2B), width: 3),
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
      ),
      child: child,
    );
  }
}
