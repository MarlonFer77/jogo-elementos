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
  static const guard = StatusEffect(
    id: 'guard',
    name: 'Defesa',
    description:
        'Reduz o próximo golpe direto em 50%. Expira após a ação adversária; não reduz dano contínuo.',
  );
  static const freeze = StatusEffect(
    id: 'freeze',
    name: 'Congelamento',
    description: 'Perde a próxima ação para quebrar o gelo, sem regenerar AP.',
  );
  static const wet = StatusEffect(
    id: 'wet',
    name: 'Molhado',
    description:
        'Recebe +25% de dano direto de Raio; consumido ao atingir. Dura 2 ações.',
  );
  static const poison = StatusEffect(
    id: 'poison',
    name: 'Veneno',
    description:
        'Dano ao fim de cada ação; aumenta em 1 por aplicação de dano. Não acumula.',
  );
  static const shock = StatusEffect(
    id: 'shock',
    name: 'Choque',
    description:
        'Combos custam +1 AP na próxima ação. Básicos e Defender continuam livres.',
  );
  static const slow = StatusEffect(
    id: 'slow',
    name: 'Lentidão',
    description:
        'Não regenera AP na próxima ação. Não altera a ordem dos turnos.',
  );
  static const shield = StatusEffect(
    id: 'shield',
    name: 'Escudo',
    description: 'Reduz ou bloqueia o próximo dano recebido.',
  );
  static const silence = StatusEffect(
    id: 'silence',
    name: 'Silêncio',
    description:
        'Bloqueia combos na próxima ação. Permite básicos e Defender; passivas permanecem.',
  );
  static const buff = StatusEffect(
    id: 'buff',
    name: 'Fortalecimento',
    description:
        '+25% de dano direto até o fim da próxima ação do dono; não altera dano contínuo.',
  );
  static const debuff = StatusEffect(
    id: 'debuff',
    name: 'Enfraquecimento',
    description:
        '−25% de dano direto na próxima ação; não altera dano contínuo.',
  );
  static const areaEffect = StatusEffect(
    id: 'area_effect',
    name: 'Efeito de Área',
    description: 'Afeta o campo de batalha, não um combatente específico.',
  );

  static const List<StatusEffect> all = [
    guard,
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
