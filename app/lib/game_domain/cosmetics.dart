/// Local-only cosmetic catalog. Never used to calculate combat or online rewards.
enum HeroOutfit {
  traveler(
    'traveler',
    'Viajante dos Ecos',
    'O manto original da Ordem.',
    0,
    0xFF356D79,
    0xFF244D59,
    0xFFC3A46A,
    0xFF9AABAA,
  ),
  ember(
    'ember',
    'Brasa Errante',
    'Tecido rubro e bronze de forja.',
    75,
    0xFF964A38,
    0xFF542E2E,
    0xFFE1B46E,
    0xFF9B7359,
  ),
  grove(
    'grove',
    'Sentinela do Bosque',
    'Verde musgo e armadura envelhecida.',
    100,
    0xFF56734B,
    0xFF30483A,
    0xFFCCBA7D,
    0xFF798A6D,
  ),
  moon(
    'moon',
    'Peregrino Lunar',
    'Índigo profundo com prata fosca.',
    175,
    0xFF666387,
    0xFF383650,
    0xFFCDCEDE,
    0xFFA3ADB9,
  ),
  crown(
    'crown',
    'Guardião Real',
    'Marfim, vinho e detalhes dourados.',
    250,
    0xFFD2C6A7,
    0xFF663746,
    0xFFDEB969,
    0xFFAA986F,
  );

  const HeroOutfit(
    this.id,
    this.label,
    this.description,
    this.price,
    this.cloth,
    this.mantle,
    this.trim,
    this.armor,
  );
  final String id, label, description;
  final int price, cloth, mantle, trim, armor;
  static HeroOutfit? byId(String id) {
    for (final outfit in values) {
      if (outfit.id == id) return outfit;
    }
    return null;
  }
}

class CosmeticInventory {
  CosmeticInventory({
    this.coins = 100,
    this.claimedLevel = 1,
    this.claimedClears = 0,
    Set<String> owned = const {'traveler'},
    this.equipped = HeroOutfit.traveler,
  }) : owned = Set.unmodifiable(owned);
  final int coins, claimedLevel, claimedClears;
  final Set<String> owned;
  final HeroOutfit equipped;

  CosmeticInventory claimDungeon({required int level, required int clears}) {
    if (level < 1 || clears < 0 || level > 1000000 || clears > 1000000) {
      throw StateError('Progresso de recompensa inválido.');
    }
    final nextLevel = level > claimedLevel ? level : claimedLevel;
    final nextClears = clears > claimedClears ? clears : claimedClears;
    final reward =
        (nextLevel - claimedLevel) * 25 + (nextClears - claimedClears) * 100;
    if (reward == 0) return this;
    return CosmeticInventory(
      coins: coins + reward,
      owned: owned,
      equipped: equipped,
      claimedLevel: nextLevel,
      claimedClears: nextClears,
    );
  }

  CosmeticInventory buy(String id) {
    final item = HeroOutfit.byId(id);
    if (item == null) throw StateError('Traje inexistente.');
    if (owned.contains(id)) return this;
    if (coins < item.price) throw StateError('Ecos insuficientes.');
    return CosmeticInventory(
      coins: coins - item.price,
      owned: {...owned, id},
      equipped: equipped,
      claimedLevel: claimedLevel,
      claimedClears: claimedClears,
    );
  }

  CosmeticInventory equip(String id) {
    final item = HeroOutfit.byId(id);
    if (item == null || !owned.contains(id)) {
      throw StateError('Adquira o traje antes de equipar.');
    }
    return CosmeticInventory(
      coins: coins,
      owned: owned,
      equipped: item,
      claimedLevel: claimedLevel,
      claimedClears: claimedClears,
    );
  }

  Map<String, Object> toJson() => {
    'version': 1,
    'coins': coins,
    'claimedLevel': claimedLevel,
    'claimedClears': claimedClears,
    'owned': owned.toList(),
    'equipped': equipped.id,
  };

  factory CosmeticInventory.fromJson(Map<String, dynamic> json) {
    if (json['version'] is int && json['version'] > 1) {
      throw StateError(
        'Loja salva por uma versão mais recente. Atualize o app.',
      );
    }
    final ids = (json['owned'] as List).cast<String>();
    final outfit = HeroOutfit.byId(json['equipped'] as String);
    final coins = json['coins'] as int, level = json['claimedLevel'] as int;
    final clears = json['claimedClears'] as int;
    if (json['version'] != 1 ||
        coins < 0 ||
        coins > 200000000 ||
        level < 1 ||
        level > 1000000 ||
        clears < 0 ||
        clears > 1000000 ||
        ids.length != ids.toSet().length ||
        !ids.contains('traveler') ||
        ids.any((id) => HeroOutfit.byId(id) == null) ||
        outfit == null ||
        !ids.contains(outfit.id)) {
      throw const FormatException('Inventário de cosméticos inválido.');
    }
    return CosmeticInventory(
      coins: coins,
      claimedLevel: level,
      claimedClears: clears,
      owned: ids.toSet(),
      equipped: outfit,
    );
  }
}
