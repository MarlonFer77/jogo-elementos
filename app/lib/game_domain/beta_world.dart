/// World geometry shared by collision and presentation; no Flutter dependency.
class BetaObstacle {
  const BetaObstacle(this.x, this.z, this.radius, this.height);
  final double x, z, radius, height;
}

enum BetaRegion {
  roots(
    'Átrio das Raízes',
    'Raízes tomaram a antiga estrada dos conjuradores.',
    [
      BetaObstacle(-4, 2, .65, 2.7),
      BetaObstacle(4, 2, .65, 2.7),
      BetaObstacle(-4, -5, .65, 1.5),
      BetaObstacle(4, -5, .65, 3.1),
    ],
  ),
  aqueduct(
    'Aqueduto Velado',
    'A água ainda corre entre os arcos de uma cidade esquecida.',
    [
      BetaObstacle(-2.8, .5, .7, 3.0),
      BetaObstacle(2.8, -2.5, .7, 3.5),
      BetaObstacle(-5.7, -4, .8, 1.4),
      BetaObstacle(5.7, 4, .8, 1.8),
    ],
  ),
  sanctum(
    'Santuário dos Ecos',
    'O último guardião protege a memória dos elementos.',
    [
      BetaObstacle(-5, 1, .85, 2.8),
      BetaObstacle(5, 1, .85, 2.8),
      BetaObstacle(-4.5, -4.5, .7, 2.2),
      BetaObstacle(4.5, -4.5, .7, 2.2),
    ],
  );

  const BetaRegion(this.title, this.story, this.obstacles);
  final String title, story;
  final List<BetaObstacle> obstacles;

  static const halfWidth = 8.5, halfDepth = 10.5;
  static const gateX = 0.0, gateZ = -8.5, gateRadius = 1.15;
  static const entryX = 0.0, entryZ = 5.0;
}
