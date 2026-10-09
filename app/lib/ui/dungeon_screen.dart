import 'package:flutter/material.dart';
import '../game_domain/attack_catalog.dart';
import '../game_domain/dungeon_campaign.dart';
import '../game_domain/dungeon_progress_store.dart';
import '../game_domain/element_catalog.dart';
import '../game_presentation/pixel_content_panel.dart';
import '../game_presentation/pixel_element_chip.dart';
import '../game_presentation/pixel_menu_button.dart';
import '../game_presentation/pixel_page_route.dart';
import '../game_presentation/creature_portrait.dart';
import '../game_presentation/sfx_player.dart';
import 'element_starter_screen.dart';
import 'skill_tree_screen.dart';
import 'training_screen.dart';
import 'dungeon_blessing_screen.dart';
import 'dungeon_encounter_preview.dart';
import 'attacks_screen.dart';

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
      if (store.recovered && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expedição recuperada da cópia local anterior.'),
          ),
        );
      }
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
    if (!campaign.progress.active) {
      await campaign.start();
      return; // Reveal the saved route before committing to the first fight.
    }
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

  Future<void> _elements() => _perform(() async {
    final campaign = _campaign!;
    final selected = [...campaign.progress.elements];
    final available = const ElementCatalog().all().where(
      (e) => campaign.progress.skills.grantedElementIds.contains(e.id),
    );
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          backgroundColor: const Color(0xFFF8F2DA),
          title: Text('Elementos · ${selected.length}/4'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Prepare até 4 elementos para esta sala. Desbloqueie outros na árvore.',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final element in available)
                      PixelElementChip(
                        label: '${element.symbol} ${element.name}',
                        selected: selected.contains(element.id),
                        onTap:
                            !selected.contains(element.id) &&
                                selected.length == 4
                            ? null
                            : () => update(() {
                                if (!selected.remove(element.id)) {
                                  selected.add(element.id);
                                }
                              }),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: selected.isEmpty
                  ? null
                  : () => Navigator.pop(context, selected),
              child: const Text('Equipar'),
            ),
          ],
        ),
      ),
    );
    if (result != null) {
      await campaign.equip(elements: result);
      if (!mounted) return;
      sfxPlayer.play(SfxId.tap);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Elementos equipados · ${result.length}/4')),
      );
    }
  });

  Future<void> _attacks() => _perform(() async {
    final campaign = _campaign!;
    await Navigator.of(context).push(
      pixelSlideRoute(
        (_) => AttacksScreen(
          attacks: allAttackOptions(
            unlockedIds: campaign.progress.attacks,
            equippedIds: campaign.progress.equippedAttacks,
          ),
          onSetEquipped: (ids) async {
            try {
              await campaign.equip(attacks: ids);
              return null;
            } on StateError catch (e) {
              return e.message;
            } catch (_) {
              return 'Não foi possível salvar. Tente novamente.';
            }
          },
        ),
      ),
    );
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
    if (progress?.pendingAltar != null) {
      return DungeonBlessingScreen(
        key: ValueKey('${progress!.run}-${progress.pendingAltar}'),
        altar: progress.pendingAltar!,
        offers: progress.blessingOffers,
        busy: _busy,
        error: _error,
        onConfirm: (id) => _perform(() async {
          await campaign!.chooseBlessing(id);
          if (!context.mounted) return;
          sfxPlayer.play(SfxId.unlock);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bênção recebida · válida nesta expedição.'),
            ),
          );
        }),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFF263D3D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF263D3D),
        foregroundColor: const Color(0xFFF8F2DA),
        toolbarHeight: 44,
        actions: [
          if (progress?.active == true)
            IconButton(
              tooltip: 'Encerrar tentativa · manter ganhos',
              icon: const Icon(Icons.exit_to_app),
              onPressed: _busy
                  ? null
                  : () => _perform(() async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: const Color(0xFFF8F2DA),
                          title: const Text('Encerrar expedição?'),
                          content: const Text(
                            'Você mantém XP, elementos e habilidades. A rota e as bênçãos desta tentativa serão encerradas.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Continuar'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Encerrar'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) await campaign!.abandon();
                    }),
            ),
        ],
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
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final scouting = progress.active
                          ? DungeonEncounterPreview(
                              room: progress.roomAt(progress.room),
                              index: progress.room,
                              onElements: _busy ? null : _elements,
                              onAttacks: _busy ? null : _attacks,
                            )
                          : const PixelContentPanel(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'RUÍNA ELEMENTAL',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    '10 salas, novas táticas a cada expedição.',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Inicie para revelar os encontros. Depois, prepare sua build e entre na primeira sala.',
                                  ),
                                ],
                              ),
                            );
                      if (constraints.maxWidth >= 480 &&
                          MediaQuery.orientationOf(context) ==
                              Orientation.landscape) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: SingleChildScrollView(child: scouting),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: SingleChildScrollView(child: _overview()),
                            ),
                          ],
                        );
                      }
                      return SingleChildScrollView(
                        child: Column(
                          children: [
                            scouting,
                            const SizedBox(height: 8),
                            _overview(),
                          ],
                        ),
                      );
                    },
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
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _overview() {
    final progress = _campaign!.progress;
    return PixelContentPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Nível ${progress.level} · ${progress.points} ponto(s)',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            '${progress.hp}/${progress.maxHp} HP · ${progress.clears} vitória(s) na ruína',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 6),
          TweenAnimationBuilder<double>(
            tween: Tween(
              begin: 0,
              end: progress.levelXp / progress.nextLevelXp,
            ),
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 400),
            builder: (_, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 7,
              color: const Color(0xFFA57830),
              backgroundColor: const Color(0xFFD8D1B8),
            ),
          ),
          Text(
            '${progress.levelXp}/${progress.nextLevelXp} XP · Próximo nível: +1 ponto',
            style: const TextStyle(fontSize: 12),
          ),
          if (progress.activeBlessings.isNotEmpty)
            TextButton.icon(
              onPressed: () =>
                  showDungeonBlessings(context, progress.activeBlessings),
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: Text('Bênçãos · ${progress.blessings.length}/3'),
            ),
          if (progress.active)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: const Text(
                'Mapa · 10 salas',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              children: [
                for (var i = 0; i < DungeonRoom.all.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _room(i, progress.roomAt(i)),
                  ),
              ],
            ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Como funciona', style: TextStyle(fontSize: 13)),
            children: const [
              Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Fogueiras recuperam até 25 HP. Após as salas 3, 6 e 9, escolha uma bênção temporária. '
                  'Cada sala reinicia AP e status com as bênçãos de abertura. '
                  'Derrota mantém XP e descobertas. Sair reinicia só a sala atual, sem recompensa e sem sortear outro inimigo. '
                  'Perfil local, separado do Treino e do Multiplayer.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ],
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
                  '${room.hp} HP · ${room.initialAp} AP · +${room.xp} XP'
                  '${room.tactic == null ? '' : ' · ${room.tactic!.label}'}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
