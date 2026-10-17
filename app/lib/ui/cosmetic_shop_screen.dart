import 'package:flutter/material.dart';
import '../game_domain/beta_session.dart';
import '../game_domain/cosmetics.dart';
import '../game_domain/cosmetic_store.dart';
import '../game_domain/dungeon_progress_store.dart';
import '../game_presentation/beta_arena_painter.dart';
import '../game_presentation/rpg_journal.dart';

class CosmeticShopScreen extends StatefulWidget {
  const CosmeticShopScreen({super.key});
  @override
  State<CosmeticShopScreen> createState() => _CosmeticShopScreenState();
}

class _CosmeticShopScreenState extends State<CosmeticShopScreen> {
  final _store = CosmeticStore();
  CosmeticInventory? _inventory;
  ShopItem _selected = ShopItem.byId('traveler')!;
  ShopCategory _category = ShopCategory.outfits;
  bool _busy = false, _ownedOnly = false;
  String? _error, _notice;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
      _inventory = null;
    });
    try {
      var inventory = await _store.load();
      String? notice;
      try {
        final dungeon = await DungeonProgressStore().load();
        final before = inventory.coins;
        inventory = await _store.claimDungeon(dungeon.level, dungeon.clears);
        if (inventory.coins > before) {
          notice = '+${inventory.coins - before} Ecos da Dungeon recebidos!';
        }
      } catch (_) {
        notice =
            'Recompensas da Dungeon indisponíveis. Tente recarregar depois.';
      }
      if (_store.recovered) notice = 'Inventário recuperado da cópia local.';
      if (mounted) {
        setState(() {
          _inventory = inventory;
          _selected = ShopItem.byId(inventory.equipped.id)!;
          _category = ShopCategory.outfits;
          _notice = notice;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Não foi possível ler a loja. Seus dados foram preservados.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _act() async {
    if (_busy || _inventory == null) return;
    final item = _selected;
    final owned = _inventory!.owned.contains(item.id);
    setState(() => _busy = true);
    try {
      if (!owned) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Adquirir ${item.label}?'),
            content: Text(
              '${item.price} Ecos serão descontados.\n'
              'Saldo após a compra: ${_inventory!.coins - item.price} Ecos.\n\n'
              '${item.description}\n\nSomente BETA 3D. Sem dinheiro real.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirmar compra'),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
      }
      final removing =
          owned && _inventory!.isEquipped(item) && item.upgrade != null;
      final inventory = owned
          ? removing
                ? await _store.unequip(item.upgrade!.slot)
                : await _store.equip(item.id)
          : await _store.buy(item.id);
      if (!mounted) return;
      setState(() {
        _inventory = inventory;
        _notice = removing
            ? 'Removido. O espaço volta ao padrão.'
            : owned
            ? 'Equipado! Disponível ao entrar no BETA 3D.'
            : 'Adquirido! Toque em Equipar para usar.';
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível concluir. Recarregue para conferir seu inventário.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _help() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Ateliê dos Ecos'),
      content: const SingleChildScrollView(
        child: Text(
          '100 Ecos de boas-vindas. Ganhe +25 por nível da Dungeon após o primeiro '
          'e +100 por expedição concluída. Progresso anterior também conta. '
          'Recompensas são recebidas ao abrir a loja, uma vez por marco.\n\n'
          'Trajes com modelos próprios e técnicas mudam somente o visual. '
          'Relíquias têm bônus exclusivos do BETA solo. Espada e esquiva usam '
          'técnicas separadas; cada espaço aceita um item. Remover restaura o padrão. '
          'Prévia não equipa: compre e depois toque em Equipar. '
          'Nenhum traje ou técnica altera dano, alcance ou invulnerabilidade.\n\n'
          'Loja offline deste aparelho, compartilhada localmente. '
          'Sem dinheiro real, anúncios, sorteios ou prazo de oferta. '
          'Não sincroniza com Firebase/Multiplayer nem faz parte do backup online. '
          'Desinstalar ou limpar dados pode perder a coleção.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Entendi'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => RpgJournal(
    title: 'ATELIÊ DOS ECOS',
    actions: [
      IconButton(
        tooltip: 'Como ganhar Ecos',
        onPressed: _help,
        icon: const Icon(Icons.info_outline),
      ),
      IconButton(
        tooltip: 'Recarregar loja',
        onPressed: _busy ? null : _load,
        icon: const Icon(Icons.refresh),
      ),
    ],
    child: _inventory == null
        ? Center(
            child: _error == null
                ? const CircularProgressIndicator()
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _busy ? null : _load,
                          child: const Text('Tentar novamente'),
                        ),
                      ],
                    ),
                  ),
          )
        : _content(),
  );

  Widget _content() {
    final screen = MediaQuery.sizeOf(context);
    final compact = screen.width > screen.height && screen.height < 400;
    final inventory = _inventory!;
    final owned = inventory.owned.contains(_selected.id);
    final equipped = inventory.isEquipped(_selected);
    final affordable = inventory.coins >= _selected.price;
    final items = ShopItem.catalog.where(
      (item) =>
          item.category == _category &&
          (!_ownedOnly || inventory.owned.contains(item.id)),
    );
    final catalog = ListView(
      cacheExtent: 500,
      padding: const EdgeInsets.all(6),
      children: [
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Nenhum item adquirido nesta categoria. Desative o filtro para explorar.',
            ),
          ),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Material(
              color: item == _selected
                  ? const Color(0xFFD8DDC1)
                  : const Color(0xFFFFF7DE),
              shape: Border.all(
                color: item == _selected ? RpgJournal.ink : RpgJournal.gold,
                width: item == _selected ? 2 : 1,
              ),
              child: ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                selected: item == _selected,
                leading: Icon(
                  switch (item.category) {
                    ShopCategory.outfits => Icons.checkroom,
                    ShopCategory.techniques => Icons.rotate_right,
                    ShopCategory.relics => Icons.shield_outlined,
                  },
                  color: Color(item.outfit?.cloth ?? 0xFF6A7861),
                  size: 30,
                ),
                title: Text(item.label),
                subtitle: Text(
                  inventory.isEquipped(item)
                      ? 'Equipado'
                      : inventory.owned.contains(item.id)
                      ? 'Adquirido'
                      : '${item.price} Ecos',
                ),
                trailing: Icon(
                  inventory.isEquipped(item)
                      ? Icons.check_circle
                      : Icons.chevron_right,
                ),
                onTap: _busy ? null : () => setState(() => _selected = item),
              ),
            ),
          ),
      ],
    );
    final action = Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(_selected.label),
                content: Text(_selected.description),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Fechar'),
                  ),
                ],
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _selected.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const Icon(Icons.info_outline, size: 18),
              ],
            ),
          ),
          if (!compact)
            Text(
              _selected.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          const SizedBox(height: 6),
          FilledButton(
            onPressed:
                _busy ||
                    (equipped && _selected.outfit != null) ||
                    (!owned && !affordable)
                ? null
                : _act,
            child: Text(
              _busy
                  ? 'Salvando…'
                  : equipped
                  ? _selected.upgrade != null
                        ? 'Remover · voltar ao padrão'
                        : 'Equipado no BETA 3D'
                  : owned
                  ? 'Equipar'
                  : affordable
                  ? 'Comprar · ${_selected.price} Ecos'
                  : 'Faltam ${_selected.price - inventory.coins} Ecos',
            ),
          ),
        ],
      ),
    );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${inventory.coins} ECOS',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              FilterChip(
                label: const Text('Adquiridos'),
                selected: _ownedOnly,
                onSelected: _busy
                    ? null
                    : (value) => setState(() {
                        _ownedOnly = value;
                        if (value && !owned) {
                          final available = ShopItem.catalog.where(
                            (item) =>
                                item.category == _category &&
                                inventory.owned.contains(item.id),
                          );
                          if (available.isNotEmpty) _selected = available.first;
                        }
                      }),
              ),
            ],
          ),
        ),
        if (_notice != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(_notice!, style: const TextStyle(fontSize: 12)),
          ),
        SizedBox(
          height: 36,
          child: Row(
            children: [
              for (final category in ShopCategory.values)
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: _category == category
                          ? const Color(0xFFD8DDC1)
                          : null,
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                            _category = category;
                            _ownedOnly = false;
                            _selected = ShopItem.catalog.firstWhere(
                              (item) => item.category == category,
                            );
                          }),
                    child: Text(switch (category) {
                      ShopCategory.outfits => 'Trajes',
                      ShopCategory.techniques => 'Técnicas',
                      ShopCategory.relics => 'Relíquias',
                    }),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, size) {
              final slots = {
                ...inventory.slots,
                if (_selected.upgrade != null)
                  _selected.upgrade!.slot: _selected.upgrade!,
              };
              final preview = CosmeticPreview(
                outfit: _selected.outfit ?? inventory.equipped,
                loadout: BetaLoadout(
                  sword: slots[ShopSlot.sword],
                  dodge: slots[ShopSlot.dodge],
                  weapon: slots[ShopSlot.weapon],
                  cloak: slots[ShopSlot.cloak],
                  armor: slots[ShopSlot.armor],
                ),
                demo: _selected.upgrade?.slot == ShopSlot.dodge
                    ? BetaAction.dodge
                    : _selected.upgrade == ShopUpgrade.excalibur
                    ? BetaAction.cast
                    : BetaAction.sword,
              );
              if (screen.width > screen.height || size.maxWidth > 700) {
                return Row(
                  children: [
                    Expanded(child: preview),
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(child: catalog),
                          action,
                        ],
                      ),
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  SizedBox(
                    height: (size.maxHeight * .38).clamp(100.0, 240.0),
                    child: preview,
                  ),
                  Expanded(child: catalog),
                  action,
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Uses the same hero mesh and materials as gameplay; preview never equips.
class CosmeticPreview extends StatefulWidget {
  const CosmeticPreview({
    super.key,
    required this.outfit,
    this.loadout = const BetaLoadout(),
    this.demo = BetaAction.sword,
  });
  final HeroOutfit outfit;
  final BetaLoadout loadout;
  final BetaAction demo;
  @override
  State<CosmeticPreview> createState() => _CosmeticPreviewState();
}

class _CosmeticPreviewState extends State<CosmeticPreview>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  double _angle = .5;
  double _lastFrame = 0;
  late BetaSession _run;
  late final AnimationController _animation;
  late BetaArenaPainter _painter;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animation =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1600),
        )..addListener(() {
          final now = _animation.value * 1.6;
          final dt = now - _lastFrame;
          _lastFrame = now;
          if (dt <= 0) return;
          _run.update(dt);
          // Showcase the equipped actor, not a projectile flying into the camera.
          // These disposable preview events never reach the real session or audio.
          _run.projectiles.clear();
          _run.effects.clear();
          _run.sounds.clear();
          _painter.advance(dt);
          setState(() {});
        });
    _create();
  }

  void _create() {
    _animation.stop();
    _run = BetaSession(loadout: widget.loadout)..start();
    _run.enemies.clear();
    _run.angle = _angle;
    _painter = BetaArenaPainter(
      _run,
      outfit: widget.outfit,
      wardrobePreview: true,
      reduceMotion: true,
    );
  }

  @override
  void didUpdateWidget(CosmeticPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.outfit != widget.outfit ||
        oldWidget.loadout != widget.loadout ||
        oldWidget.demo != widget.demo) {
      _painter.dispose();
      _create();
    }
  }

  void _rotate(double delta) => setState(() {
    _angle += delta;
    _painter.dispose();
    _create();
  });
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animation.dispose();
    _painter.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _animation.stop();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Prévia de ${widget.outfit.label}',
    child: Padding(
      padding: const EdgeInsets.all(6),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _painter),
          Positioned(
            bottom: 0,
            left: 48,
            right: 48,
            child: Center(
              child: IconButton.filledTonal(
                tooltip: 'Testar animação',
                onPressed: () {
                  _painter.dispose();
                  _create();
                  _run.request(widget.demo);
                  _lastFrame = 0;
                  _animation.forward(from: 0);
                },
                icon: const Icon(Icons.play_arrow),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            child: IconButton(
              tooltip: 'Girar para a esquerda',
              onPressed: () => _rotate(-.6),
              color: Colors.white,
              icon: const Icon(Icons.rotate_left),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: IconButton(
              tooltip: 'Girar para a direita',
              onPressed: () => _rotate(.6),
              color: Colors.white,
              icon: const Icon(Icons.rotate_right),
            ),
          ),
        ],
      ),
    ),
  );
}
