import 'element_combination.dart';

/// One entry of a "Livro de Descobertas" screen: a combination and whether
/// the player has discovered it yet. Undiscovered entries still carry the
/// full [ElementCombination] — hiding its name/description from the player
/// (e.g. showing "???") is a presentation concern, not this class's job.
class DiscoveryEntry {
  final ElementCombination combination;
  final bool discovered;

  const DiscoveryEntry({required this.combination, required this.discovered});
}
