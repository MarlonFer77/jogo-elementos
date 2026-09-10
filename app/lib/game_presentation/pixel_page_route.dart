import 'package:flutter/material.dart';

/// Transição compartilhada por toda a navegação principal do jogo (Home →
/// Treino/Multiplayer, Lobby → Batalha, Revanche): a tela nova sobe de
/// baixo pra cima, mesmo espírito visual do `PixelSheetPanel` (um painel
/// de jogo entrando), em vez da transição genérica do `MaterialPageRoute`.
PageRouteBuilder<T> pixelSlideRoute<T>(WidgetBuilder builder) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final offsetAnimation = Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
      return SlideTransition(position: offsetAnimation, child: child);
    },
  );
}
