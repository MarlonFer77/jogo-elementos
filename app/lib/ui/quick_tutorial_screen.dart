import 'package:flutter/material.dart';

import '../game_presentation/pixel_menu_button.dart';
import '../settings/game_settings.dart';

class QuickTutorialScreen extends StatefulWidget {
  const QuickTutorialScreen({super.key, this.settings});
  final GameSettings? settings;

  @override
  State<QuickTutorialScreen> createState() => _QuickTutorialScreenState();
}

class _QuickTutorialScreenState extends State<QuickTutorialScreen> {
  int _step = 0;
  bool _leaving = false;
  static const _pages = [
    (
      Icons.explore,
      'Escolha sua jornada',
      'Dungeon: jogue sozinho em 10 salas, ganhe XP e pontos para a árvore.\n\nTreino: dois jogadores no mesmo aparelho, offline.\n\nMultiplayer: cada amigo no seu celular, com internet; um cria a sala e o outro entra com o código.',
    ),
    (
      Icons.auto_awesome,
      'Monte sua identidade',
      'Escolha 2 elementos iniciais. Desbloqueie outros jogando e equipe até 4 para a batalha.\n\nCombine elementos para descobrir habilidades. Você só equipa 3 habilidades: ao descobrir mais, escolha qual substituir. Depois de descobertas, só as equipadas podem ser repetidas.',
    ),
    (
      Icons.bolt,
      'Escolha, confira, jogue',
      'HP é sua vida; AP é a energia das ações. No seu turno, selecione elementos ou uma habilidade. Confira a prévia e o custo; depois toque em Jogar.\n\nAtaques básicos ajudam a recuperar AP. Combos gastam AP; defender também é uma opção. Observe os status e de quem é a vez antes de confirmar.',
    ),
    (
      Icons.gesture,
      'Complete o selo',
      'Comece no nó 1 e arraste pelos nós em ordem, mirando o centro. Combos mais fortes têm mais nós.\n\nPrecisão: perfeito causa 100% do dano direto; depois vêm 80%, 60% e 40%. AP, cura e status não mudam.\n\nO tempo começa ao iniciar o traço. Falhar custa 1 AP, sem regeneração, e encerra o turno. Você pode rever este guia no menu.',
    ),
  ];

  Future<void> _finish() async {
    if (_leaving) return;
    setState(() => _leaving = true);
    final settings = widget.settings ?? gameSettings;
    await settings.markTutorialSeen();
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    if (settings.saveFailed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível salvar a conclusão do guia.'),
        ),
      );
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_step];
    return Scaffold(
      backgroundColor: const Color(0xFFF1E8C9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF1E8C9),
        title: const Text(
          'COMO JOGAR',
          style: TextStyle(fontFamily: 'monospace', fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: _leaving ? null : _finish,
            child: const Text('Pular'),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: (_step + 1) / _pages.length,
                    color: const Color(0xFF345B44),
                    backgroundColor: const Color(0xFFD9CCAA),
                    semanticsLabel: 'Passo ${_step + 1} de ${_pages.length}',
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      key: ValueKey(_step),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                page.$1,
                                size: 32,
                                color: const Color(0xFF345B44),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '${_step + 1}/4 · ${page.$2}',
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            page.$3,
                            style: const TextStyle(fontSize: 16, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      if (_step > 0) ...[
                        TextButton(
                          onPressed: _leaving
                              ? null
                              : () => setState(() => _step--),
                          child: const Text('Voltar'),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: PixelMenuButton(
                          label: _step == _pages.length - 1
                              ? 'Vamos jogar'
                              : 'Próximo',
                          primary: true,
                          onPressed: _leaving
                              ? null
                              : () {
                                  if (_step == _pages.length - 1) {
                                    _finish();
                                  } else {
                                    setState(() => _step++);
                                  }
                                },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
