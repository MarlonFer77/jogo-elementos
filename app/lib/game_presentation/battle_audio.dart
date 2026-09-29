import '../game_domain/attack_event.dart';
import '../game_domain/combatant_appearance.dart';
import 'sfx_player.dart';

/// One cue per phase, shared by Dungeon, Treino and Multiplayer.
abstract final class BattleAudio {
  static SfxId? preparation(AttackEvent event, CombatantAppearance actor) {
    if (event.isDefend || event.isFizzle || event.isFrozenRecovery) return null;
    if (event.comboName != null || event.elementIds.length != 1) {
      return SfxId.cast;
    }
    return switch (actor) {
      CombatantAppearance.swampGolem ||
      CombatantAppearance.thunderTroll => SfxId.stone,
      CombatantAppearance.ancientEnt => SfxId.wood,
      CombatantAppearance.sunScarab ||
      CombatantAppearance.plagueSpider => SfxId.chitin,
      CombatantAppearance.stormHarpy ||
      CombatantAppearance.ruinDrake => SfxId.wings,
      _ => SfxId.swing,
    };
  }

  static SfxId impact(AttackEvent event) {
    if (event.isFizzle) return SfxId.sealFail;
    if (event.isFrozenRecovery) return SfxId.ice;
    if (event.isDefend) return SfxId.defend;
    if (event.damage == 0) {
      if (event.purified) return SfxId.purify;
      if (event.healing > 0) return SfxId.heal;
    }
    // Fixed priority keeps a recipe sounding identical in either order.
    const elements = {
      'lightning': SfxId.lightning,
      'fire': SfxId.fire,
      'ice': SfxId.ice,
      'poison': SfxId.water,
      'water': SfxId.water,
      'earth': SfxId.stone,
      'wind': SfxId.wind,
      'nature': SfxId.wood,
      'light': SfxId.light,
      'shadow': SfxId.shadow,
    };
    for (final entry in elements.entries) {
      if (event.elementIds.contains(entry.key)) return entry.value;
    }
    return SfxId.impact;
  }
}
