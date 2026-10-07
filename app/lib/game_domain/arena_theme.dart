/// Presentation identity only. Arenas never change damage, AP or rewards.
enum ArenaTheme {
  training('Clareira dos Aprendizes'),
  multiplayer('Pátio dos Elementos'),
  embers('Desfiladeiro das Brasas'),
  glacier('Gruta Glacial'),
  swamp('Pântano de Pedra'),
  sunTemple('Templo do Sol'),
  stormCliffs('Penhascos da Tempestade'),
  moonRuins('Ruínas da Lua'),
  ancientGrove('Bosque Ancestral'),
  thunderPeaks('Picos do Trovão'),
  plagueCrypt('Cripta da Peste'),
  caldera('Caldeira da Ruína');

  const ArenaTheme(this.label);
  final String label;
}
