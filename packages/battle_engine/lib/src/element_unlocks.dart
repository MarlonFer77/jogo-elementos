import 'element_unlock.dart';

/// Built-in element unlocks, one per element in `Elements.all` — used by
/// `defaultSkillTree`'s "elementos" branch (Bloco 2b, DECISION-047). Node
/// ids follow the `'unlock_<elementId>'` convention — `TrainingScreen`
/// relies on that same convention (as plain strings, never importing this
/// class) to know when a player still needs to make their starting pick.
class ElementUnlocks {
  ElementUnlocks._();

  static const fire = ElementUnlock(id: 'unlock_fire', elementId: 'fire');
  static const water = ElementUnlock(id: 'unlock_water', elementId: 'water');
  static const wind = ElementUnlock(id: 'unlock_wind', elementId: 'wind');
  static const ice = ElementUnlock(id: 'unlock_ice', elementId: 'ice');
  static const nature = ElementUnlock(id: 'unlock_nature', elementId: 'nature');
  static const lightning = ElementUnlock(id: 'unlock_lightning', elementId: 'lightning');
  static const earth = ElementUnlock(id: 'unlock_earth', elementId: 'earth');
  static const shadow = ElementUnlock(id: 'unlock_shadow', elementId: 'shadow');
  static const light = ElementUnlock(id: 'unlock_light', elementId: 'light');
  static const poison = ElementUnlock(id: 'unlock_poison', elementId: 'poison');

  static const List<ElementUnlock> all = [
    fire, water, wind, ice, nature, lightning, earth, shadow, light, poison,
  ];
}
