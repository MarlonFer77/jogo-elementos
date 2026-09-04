import 'status_effect.dart';

/// Built-in status effects. `areaEffect` is a marker for effects that apply
/// to the battlefield rather than a specific combatant — how it plugs into
/// field state is left for whichever future system first needs it.
class StatusEffects {
  StatusEffects._();

  static const burn = StatusEffect(
    id: 'burn',
    name: 'Queimadura',
    description: 'Sofre dano ao final de cada turno.',
  );
  static const freeze = StatusEffect(
    id: 'freeze',
    name: 'Congelamento',
    description: 'Impede de agir enquanto durar.',
  );
  static const wet = StatusEffect(
    id: 'wet',
    name: 'Molhado',
    description: 'Mais vulnerável a efeitos elétricos.',
  );
  static const poison = StatusEffect(
    id: 'poison',
    name: 'Veneno',
    description: 'Sofre dano crescente ao final de cada turno.',
  );
  static const shock = StatusEffect(
    id: 'shock',
    name: 'Choque',
    description: 'Chance de perder a ação do turno.',
  );
  static const slow = StatusEffect(
    id: 'slow',
    name: 'Lentidão',
    description: 'Reduz a iniciativa/ordem de ação.',
  );
  static const shield = StatusEffect(
    id: 'shield',
    name: 'Escudo',
    description: 'Reduz ou bloqueia o próximo dano recebido.',
  );
  static const silence = StatusEffect(
    id: 'silence',
    name: 'Silêncio',
    description: 'Impede o uso de habilidades.',
  );
  static const buff = StatusEffect(
    id: 'buff',
    name: 'Fortalecimento',
    description: 'Aumenta um atributo temporariamente.',
  );
  static const debuff = StatusEffect(
    id: 'debuff',
    name: 'Enfraquecimento',
    description: 'Reduz um atributo temporariamente.',
  );
  static const areaEffect = StatusEffect(
    id: 'area_effect',
    name: 'Efeito de Área',
    description: 'Afeta o campo de batalha, não um combatente específico.',
  );

  static const List<StatusEffect> all = [
    burn,
    freeze,
    wet,
    poison,
    shock,
    slow,
    shield,
    silence,
    buff,
    debuff,
    areaEffect,
  ];
}
