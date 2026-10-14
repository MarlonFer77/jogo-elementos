enum BetaSkillPath {
  vanguard('Vanguarda', 'Alterne combo e espada.'),
  guardian('Guardião', 'Transforme proteção em mobilidade.'),
  attunement('Sintonia', 'Recupere mana lutando.');

  const BetaSkillPath(this.label, this.description);
  final String label, description;
}

enum BetaSkill {
  runicBlade(
    'Lâmina Rúnica',
    BetaSkillPath.vanguard,
    'Acertar um combo prepara +8 de dano na próxima espada por 4s.',
  ),
  pursuit(
    'Perseguição',
    BetaSkillPath.vanguard,
    'Acertar a espada rúnica reduz a recarga atual da esquiva em 0,6s.',
    level: 3,
  ),
  ward(
    'Guarda Arcana',
    BetaSkillPath.guardian,
    'Acertar um combo concede proteção de 50% por pelo menos 1s.',
  ),
  stoneStep(
    'Passo de Pedra',
    BetaSkillPath.guardian,
    'Esquivar com proteção consome-a: invulnerabilidade passa de 0,3s para 0,42s.',
    level: 3,
  ),
  manaWeave(
    'Pulso de Mana',
    BetaSkillPath.attunement,
    'Espada que acerta recupera 6 MP, uma vez por golpe.',
  ),
  flow(
    'Retorno Arcano',
    BetaSkillPath.attunement,
    'Combo que acerta devolve 8 MP, uma vez por conjuração.',
    level: 3,
  );

  const BetaSkill(this.label, this.path, this.description, {this.level = 1});
  final String label, description;
  final BetaSkillPath path;
  final int level;
  BetaSkill? get prerequisite => switch (this) {
    pursuit => runicBlade,
    stoneStep => ward,
    flow => manaWeave,
    _ => null,
  };
}
