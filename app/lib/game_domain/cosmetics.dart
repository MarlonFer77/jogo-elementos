/// Offline BETA catalog. Cosmetics and gameplay equipment have separate slots.
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
  angel(
    'angel',
    'Anjo da Aurora',
    'Asas de marfim e auréola dourada. Apenas visual.',
    300,
    0xFFE6DFCA,
    0xFF859EAE,
    0xFFEAC578,
    0xFFC8D8DC,
  ),
  demon(
    'demon',
    'Demônio das Cinzas',
    'Chifres, asas de obsidiana e cauda. Apenas visual.',
    300,
    0xFF713E45,
    0xFF302E40,
    0xFFDF865A,
    0xFF515365,
  ),
  arthur(
    'arthur',
    'Arthur de Camelot',
    'Coroa, armadura e tabardo real. Apenas visual.',
    350,
    0xFF55738A,
    0xFF763D49,
    0xFFDFBC70,
    0xFFCCD3D6,
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

enum ShopSlot { sword, dodge, weapon, cloak, armor }

enum ShopCategory { outfits, techniques, relics }

enum ShopUpgrade {
  spin(
    'spin',
    'Corte Giratório',
    'Giro completo ao atacar. Mesmo alcance e dano; não atinge pelas costas.',
    125,
    ShopSlot.sword,
  ),
  leap(
    'leap',
    'Golpe Saltado',
    'Salto com corte. Apenas animação: não evita ataques.',
    125,
    ShopSlot.sword,
  ),
  somersault(
    'somersault',
    'Mortal do Viajante',
    'Esquiva acrobática. Mesma distância e invulnerabilidade.',
    150,
    ShopSlot.dodge,
  ),
  excalibur(
    'excalibur',
    'Excalibur',
    '+4 de ataque. Conjurar invoca Merlin: próximo corte em até 5s recebe +3 e o elemento conjurado.',
    300,
    ShopSlot.weapon,
  ),
  mercerus(
    'mercerus',
    'Capa de Mercerus',
    '+10 agilidade: +10% de movimento. Não altera distância nem recarga da esquiva.',
    200,
    ShopSlot.cloak,
  ),
  perseus(
    'perseus',
    'Peitoral de Perseu',
    'Imune à queimadura dos guardiões e à maldição dos elfos. Não bloqueia o impacto do golpe.',
    250,
    ShopSlot.armor,
  );

  const ShopUpgrade(
    this.id,
    this.label,
    this.description,
    this.price,
    this.slot,
  );
  final String id, label, description;
  final int price;
  final ShopSlot slot;
  bool get isRelic => slot.index >= ShopSlot.weapon.index;
}

/// Immutable snapshot taken when entering the BETA; never used by online combat.
class BetaLoadout {
  const BetaLoadout({
    this.sword,
    this.dodge,
    this.weapon,
    this.cloak,
    this.armor,
  });
  final ShopUpgrade? sword, dodge, weapon, cloak, armor;
  bool get excalibur => weapon == ShopUpgrade.excalibur;
  bool get perseus => armor == ShopUpgrade.perseus;
  int get agility => cloak == ShopUpgrade.mercerus ? 10 : 0;
  int get attackBonus => excalibur ? 4 : 0;
}

class ShopItem {
  const ShopItem.outfit(HeroOutfit value) : outfit = value, upgrade = null;
  const ShopItem.upgrade(ShopUpgrade value) : upgrade = value, outfit = null;
  final HeroOutfit? outfit;
  final ShopUpgrade? upgrade;
  String get id => outfit?.id ?? upgrade!.id;
  String get label => outfit?.label ?? upgrade!.label;
  String get description => outfit?.description ?? upgrade!.description;
  int get price => outfit?.price ?? upgrade!.price;
  ShopCategory get category => outfit != null
      ? ShopCategory.outfits
      : upgrade!.isRelic
      ? ShopCategory.relics
      : ShopCategory.techniques;
  static final catalog = List<ShopItem>.unmodifiable([
    ...HeroOutfit.values.map(ShopItem.outfit),
    ...ShopUpgrade.values.map(ShopItem.upgrade),
  ]);
  static ShopItem? byId(String id) {
    for (final item in catalog) {
      if (item.id == id) return item;
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
    Map<ShopSlot, ShopUpgrade> slots = const {},
  }) : owned = Set.unmodifiable(owned),
       slots = Map.unmodifiable(slots);
  final int coins, claimedLevel, claimedClears;
  final Set<String> owned;
  final HeroOutfit equipped;
  final Map<ShopSlot, ShopUpgrade> slots;
  BetaLoadout get loadout => BetaLoadout(
    sword: slots[ShopSlot.sword],
    dodge: slots[ShopSlot.dodge],
    weapon: slots[ShopSlot.weapon],
    cloak: slots[ShopSlot.cloak],
    armor: slots[ShopSlot.armor],
  );
  bool isEquipped(ShopItem item) => item.outfit != null
      ? equipped == item.outfit
      : slots[item.upgrade!.slot] == item.upgrade;
  CosmeticInventory _copy({
    int? coins,
    int? level,
    int? clears,
    Set<String>? owned,
    HeroOutfit? outfit,
    Map<ShopSlot, ShopUpgrade>? slots,
  }) => CosmeticInventory(
    coins: coins ?? this.coins,
    claimedLevel: level ?? claimedLevel,
    claimedClears: clears ?? claimedClears,
    owned: owned ?? this.owned,
    equipped: outfit ?? equipped,
    slots: slots ?? this.slots,
  );

  CosmeticInventory claimDungeon({required int level, required int clears}) {
    if (level < 1 || clears < 0 || level > 1000000 || clears > 1000000) {
      throw StateError('Progresso de recompensa inválido.');
    }
    final nextLevel = level > claimedLevel ? level : claimedLevel;
    final nextClears = clears > claimedClears ? clears : claimedClears;
    final reward =
        (nextLevel - claimedLevel) * 25 + (nextClears - claimedClears) * 100;
    if (reward == 0) return this;
    return _copy(coins: coins + reward, level: nextLevel, clears: nextClears);
  }

  CosmeticInventory buy(String id) {
    final item = ShopItem.byId(id);
    if (item == null) throw StateError('Item inexistente.');
    if (owned.contains(id)) return this;
    if (coins < item.price) throw StateError('Ecos insuficientes.');
    return _copy(coins: coins - item.price, owned: {...owned, id});
  }

  CosmeticInventory equip(String id) {
    final item = ShopItem.byId(id);
    if (item == null || !owned.contains(id)) {
      throw StateError('Adquira o item antes de equipar.');
    }
    return _copy(
      outfit: item.outfit,
      slots: item.upgrade == null
          ? slots
          : {...slots, item.upgrade!.slot: item.upgrade!},
    );
  }

  CosmeticInventory unequip(ShopSlot slot) =>
      _copy(slots: {...slots}..remove(slot));

  Map<String, Object> toJson() => {
    'version': 2,
    'coins': coins,
    'claimedLevel': claimedLevel,
    'claimedClears': claimedClears,
    'owned': owned.toList(),
    'equipped': equipped.id,
    'slots': {
      for (final entry in slots.entries) entry.key.name: entry.value.id,
    },
  };

  factory CosmeticInventory.fromJson(Map<String, dynamic> json) {
    if (json['version'] is int && json['version'] > 2) {
      throw StateError(
        'Loja salva por uma versão mais recente. Atualize o app.',
      );
    }
    final ids = (json['owned'] as List).cast<String>();
    final outfit = HeroOutfit.byId(json['equipped'] as String);
    final coins = json['coins'] as int, level = json['claimedLevel'] as int;
    final clears = json['claimedClears'] as int;
    if ((json['version'] != 1 && json['version'] != 2) ||
        coins < 0 ||
        coins > 200000000 ||
        level < 1 ||
        level > 1000000 ||
        clears < 0 ||
        clears > 1000000 ||
        ids.length != ids.toSet().length ||
        !ids.contains('traveler') ||
        ids.any((id) => ShopItem.byId(id) == null) ||
        outfit == null ||
        !ids.contains(outfit.id)) {
      throw const FormatException('Inventário de cosméticos inválido.');
    }
    final slots = <ShopSlot, ShopUpgrade>{};
    if (json['version'] == 2) {
      final raw = json['slots'];
      if (raw is! Map) throw const FormatException('Equipamentos inválidos.');
      for (final entry in raw.entries) {
        final item = entry.value is String
            ? ShopItem.byId(entry.value)?.upgrade
            : null;
        if (item == null ||
            item.slot.name != entry.key ||
            !ids.contains(item.id)) {
          throw const FormatException('Equipamento inválido ou não adquirido.');
        }
        slots[item.slot] = item;
      }
    }
    return CosmeticInventory(
      coins: coins,
      claimedLevel: level,
      claimedClears: clears,
      owned: ids.toSet(),
      equipped: outfit,
      slots: slots,
    );
  }
}
