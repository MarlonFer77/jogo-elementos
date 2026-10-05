import 'package:flutter/material.dart';

/// Substitui o `TextField` cru da `MultiplayerLobbyScreen`. Continua sendo
/// um `TextField` real por dentro (decisivo pra `find.byType(TextField)`
/// nos testes existentes continuar funcionando sem alteração) — só a
/// decoração muda, pra combinar com a borda/sombra pixel art já usada em
/// `PixelMenuButton`/`PixelElementChip`.
class PixelTextField extends StatelessWidget {
  const PixelTextField({
    super.key,
    required this.controller,
    required this.label,
    this.maxLength,
    this.obscureText = false,
    this.keyboardType,
    this.autofillHints,
    this.capitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String label;
  final int? maxLength;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final TextCapitalization capitalization;

  @override
  Widget build(BuildContext context) {
    const borderColor = Color(0xFF2B2B2B);
    const border = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(4)),
      borderSide: BorderSide(color: borderColor, width: 3),
    );
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      autocorrect: !obscureText,
      enableSuggestions: !obscureText,
      maxLength: maxLength,
      textCapitalization: capitalization,
      style: const TextStyle(fontFamily: 'monospace', color: borderColor),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        counterText: '',
        labelText: label,
        labelStyle: const TextStyle(
          fontFamily: 'monospace',
          color: borderColor,
        ),
        filled: true,
        fillColor: const Color(0xFFF4F4E4),
        border: border,
        enabledBorder: border,
        focusedBorder: border,
      ),
    );
  }
}
