import 'beta_spells.dart';

/// Walkable floor seals, not solid props. The order matters, recipes do not.
class BetaAltar {
  const BetaAltar(this.label, this.x, this.z);
  final String label;
  final double x, z;
  static const all = [
    BetaAltar('A', -2, 3),
    BetaAltar('B', 2, 3),
    BetaAltar('C', -2, -4),
    BetaAltar('D', 2, -4),
  ];
}

class BetaPuzzleStep {
  const BetaPuzzleStep(this.altar, this.first, [this.second]);
  final int altar;
  final BetaElement first;
  final BetaElement? second;
  bool accepts(int target, BetaElement a, BetaElement? b) =>
      target == altar &&
      ((a == first && b == second) ||
          (second != null && a == second && b == first));
  String get hint =>
      '${BetaAltar.all[altar].label}: ${first.label}'
      '${second == null ? '' : ' + ${second!.label}'}';
}

class BetaPuzzle {
  const BetaPuzzle(this.title, this.inscription, this.restoration, this.steps);
  final String title, inscription, restoration;
  final List<BetaPuzzleStep> steps;

  static const catalog = [
    BetaPuzzle(
      'Sementes adormecidas',
      'Em A, a chuva acorda a semente. Em B, o chão sustenta a raiz.',
      'As raízes florescem',
      [
        BetaPuzzleStep(0, BetaElement.water),
        BetaPuzzleStep(1, BetaElement.earth),
      ],
    ),
    BetaPuzzle(
      'Curso das águas',
      'A fonte C recebe chuva; o sopro em A move a corrente; D recebe a água.',
      'O aqueduto volta a brilhar',
      [
        BetaPuzzleStep(2, BetaElement.water),
        BetaPuzzleStep(0, BetaElement.wind),
        BetaPuzzleStep(3, BetaElement.water),
      ],
    ),
    BetaPuzzle(
      'Memória do espelho',
      'A inscrição deve ser lida de trás para frente: A chama, B pedra, C sopro, D chuva.',
      'Os vitrais recuperam suas cores',
      [
        BetaPuzzleStep(3, BetaElement.water),
        BetaPuzzleStep(2, BetaElement.wind),
        BetaPuzzleStep(1, BetaElement.earth),
        BetaPuzzleStep(0, BetaElement.fire),
      ],
    ),
    BetaPuzzle(
      'Jardim alquímico',
      'A: forme barro. C: aqueça água em vapor. B: leve água no vento. D: firme a terra. A: regue.',
      'O jardim suspenso desperta',
      [
        BetaPuzzleStep(0, BetaElement.water, BetaElement.earth),
        BetaPuzzleStep(2, BetaElement.fire, BetaElement.water),
        BetaPuzzleStep(1, BetaElement.water, BetaElement.wind),
        BetaPuzzleStep(3, BetaElement.earth),
        BetaPuzzleStep(0, BetaElement.water),
      ],
    ),
    BetaPuzzle(
      'Forja das marés',
      'Acenda A, funda rocha em C, resfrie B. Repita no espelho: acenda B, funda D, resfrie A.',
      'Cristais e cascatas renascem',
      [
        BetaPuzzleStep(0, BetaElement.fire),
        BetaPuzzleStep(2, BetaElement.fire, BetaElement.earth),
        BetaPuzzleStep(1, BetaElement.water),
        BetaPuzzleStep(1, BetaElement.fire),
        BetaPuzzleStep(3, BetaElement.earth, BetaElement.fire),
        BetaPuzzleStep(0, BetaElement.water),
      ],
    ),
    BetaPuzzle(
      'Concerto da aurora',
      'A pedra, B chuva, C sopro, D chama. Una A+B em C; C+D em B; pedra+sopro em A.',
      'A aurora ilumina a cidade dos Ecos',
      [
        BetaPuzzleStep(0, BetaElement.earth),
        BetaPuzzleStep(1, BetaElement.water),
        BetaPuzzleStep(2, BetaElement.wind),
        BetaPuzzleStep(3, BetaElement.fire),
        BetaPuzzleStep(2, BetaElement.earth, BetaElement.water),
        BetaPuzzleStep(1, BetaElement.wind, BetaElement.fire),
        BetaPuzzleStep(0, BetaElement.earth, BetaElement.wind),
      ],
    ),
  ];
}

/// Session-only progress. Failed offerings preserve the already solved steps.
class BetaPuzzleProgress {
  BetaPuzzleProgress(this.puzzle);
  final BetaPuzzle puzzle;
  int _completed = 0;
  bool _hintRevealed = false;
  int get completed => _completed;
  bool get solved => _completed == puzzle.steps.length;
  BetaPuzzleStep? get next => solved ? null : puzzle.steps[_completed];
  BetaPuzzleStep? get revealedHint => _hintRevealed ? next : null;
  Iterable<BetaPuzzleStep> get history => puzzle.steps.take(_completed);
  void revealHint() {
    if (!solved) _hintRevealed = true;
  }

  bool offer(int altar, BetaElement first, BetaElement? second) {
    if (next?.accepts(altar, first, second) != true) return false;
    _completed++;
    _hintRevealed = false; // Never reveal the following step automatically.
    return true;
  }
}
