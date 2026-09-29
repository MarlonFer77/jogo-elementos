import 'package:flutter/material.dart';
import '../game_domain/dungeon_campaign.dart';
import '../game_domain/dungeon_progress_store.dart';
import '../game_presentation/pixel_content_panel.dart';
import '../game_presentation/pixel_menu_button.dart';
import '../game_presentation/pixel_page_route.dart';
import '../game_presentation/creature_portrait.dart';
import 'element_starter_screen.dart';
import 'skill_tree_screen.dart';
import 'training_screen.dart';

class DungeonScreen extends StatefulWidget {
  const DungeonScreen({super.key});
  @override
  State<DungeonScreen> createState() => _DungeonScreenState();
}

class _DungeonScreenState extends State<DungeonScreen> {
  DungeonCampaign? _campaign;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _perform(() async {
      final store = DungeonProgressStore();
      final progress = await store.load();
      _campaign = DungeonCampaign(progress, store);
    });
  }

  Future<void> _perform(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is StateError
              ? e.message
              : 'Não foi possível salvar. Tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _enter() => _perform(() async {
    final campaign = _campaign!;
    if (!campaign.progress.active) await campaign.start();
    if (!mounted) return;
    final encounter = campaign.enter();
    try {
      await Navigator.of(context).push(
        pixelSlideRoute(
          (_) => TrainingScreen(dungeon: campaign, encounter: encounter),
        ),
      );
    } finally {
      campaign.leave(encounter);
    }
  });

  Future<void> _tree() => _perform(() async {
    final campaign = _campaign!;
    await Navigator.of(context).push(
      pixelSlideRoute(
        (_) => SkillTreeScreen(
          title: 'Árvore da expedição',
          unlockedNodeIds: campaign.progress.nodes,
          canUnlockNow: true,
          progressLabel: () =>
              'Nível ${campaign.progress.level} · ${campaign.progress.points} ponto(s) disponível(is)',
          unlockLabel: 'Desbloquear · 1 ponto',
          extraLockedHint: (id) => campaign.progress.unlockReason(id),
          onUnlock: (id) async {
            try {
              await campaign.unlock(id);
              return null;
            } on StateError catch (e) {
              return e.message;
            }
          },
        ),
      ),
    );
  });

  @override
  Widget build(BuildContext context) {
    final campaign = _campaign;
    if (campaign != null && !campaign.progress.prepared) {
      return Stack(
        children: [
          ElementStarterScreen(
            modeLabel: 'DUNGEON',
            playerLabel: 'Explorador',
            totalSteps: 1,
            confirmLabel: 'Preparar expedição',
            onConfirm: (ids) => _perform(() => campaign.prepare(ids)),
          ),
          if (_busy)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x66000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          if (_error != null)
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Material(child: Text(_error!)),
            ),
        ],
      );
    }
    final progress = campaign?.progress;
    return Scaffold(
      backgroundColor: const Color(0xFF263D3D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF263D3D),
        foregroundColor: const Color(0xFFF8F2DA),
        toolbarHeight: 44,
        title: const Text(
          'DUNGEON · ACAMPAMENTO',
          style: TextStyle(fontFamily: 'monospace', fontSize: 16),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (progress == null) ...[
                if (_busy) const LinearProgressIndicator(),
                Text(
                  _error ?? 'Carregando expedição…',
                  style: const TextStyle(color: Colors.white),
                ),
                if (!_busy)
                  PixelMenuButton(label: 'Tentar novamente', onPressed: _load),
              ] else ...[
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        PixelContentPanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'RUÍNA ELEMENTAL',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                              Text(
                                'Nível ${progress.level} · ${progress.points} ponto(s) · ${progress.clears} expedição(ões) concluída(s)',
                              ),
                              const SizedBox(height: 6),
                              TweenAnimationBuilder<double>(
                                tween: Tween(
                                  begin: 0,
                                  end: progress.levelXp / progress.nextLevelXp,
                                ),
                                duration:
                                    MediaQuery.disableAnimationsOf(context)
                                    ? Duration.zero
                                    : const Duration(milliseconds: 400),
                                builder: (_, value, _) =>
                                    LinearProgressIndicator(
                                      value: value,
                                      minHeight: 7,
                                      color: const Color(0xFFA57830),
                                      backgroundColor: const Color(0xFFD8D1B8),
                                    ),
                              ),
                              Text(
                                '${progress.levelXp}/${progress.nextLevelXp} XP · '
                                '${progress.level == 1 ? 'Primeira vitória: 1 ponto para habilidade ou elemento.' : 'Cada nível concede 1 ponto para a árvore.'}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final entry in DungeonRoom.all.indexed)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: _room(entry.$1, entry.$2),
                          ),
                        PixelContentPanel(
                          child: Text(
                            '${progress.active ? 'Próxima sala: ${progress.room + 1}/${DungeonRoom.all.length} · ${progress.hp}/${progress.maxHp} HP' : 'Nova expedição: ${DungeonRoom.all.length} salas · ${DungeonRoom.totalXp} XP ao concluir'}\n'
                            'Fogueiras recuperam até 25 HP entre salas. Seu AP e os status reiniciam; o AP inicial inimigo aparece em cada sala. '
                            'Derrota mantém o XP conquistado. Sair ou fechar o jogo reinicia apenas a sala atual, sem recompensa.\n'
                            'Perfil solo local, separado do Treino e do Multiplayer.',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_error != null)
                  Text(
                    _error!,
                    style: const TextStyle(color: Color(0xFFFFDCA5)),
                  ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: PixelMenuButton(
                        label: progress.active
                            ? 'Sala ${progress.room + 1}/${DungeonRoom.all.length} · Entrar'
                            : 'Iniciar expedição',
                        primary: true,
                        onPressed: _busy ? null : _enter,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 2,
                      child: PixelMenuButton(
                        label: 'Árvore · ${progress.points}',
                        onPressed: _busy ? null : _tree,
                      ),
                    ),
                  ],
                ),
                if (progress.active)
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => _perform(() => campaign!.abandon()),
                    child: const Text(
                      'Encerrar tentativa · manter ganhos',
                      style: TextStyle(color: Color(0xFFF8F2DA)),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _room(int index, DungeonRoom room) {
    final p = _campaign!.progress;
    final done = p.active && index < p.room;
    final current = index == (p.active ? p.room : 0);
    return AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: current ? const Color(0xFFF2DB88) : const Color(0xFFE6DFC5),
        border: Border.all(
          color: current ? const Color(0xFFB38632) : const Color(0xFF889581),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CreaturePortrait(appearance: room.appearance, label: room.name),
              if (done)
                const Positioned(
                  right: 0,
                  bottom: 0,
                  child: Icon(
                    Icons.check_circle,
                    color: Color(0xFF38604A),
                    size: 18,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${index + 1}. ${room.name}',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${room.hp} HP · ${room.initialAp} AP inicial · ${room.hint}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '+${room.xp} XP',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
