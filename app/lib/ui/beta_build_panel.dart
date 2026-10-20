import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../game_domain/beta_session.dart';
import '../game_domain/cosmetics.dart';
import '../game_presentation/beta_arena_painter.dart' show betaComboColor;
import '../game_presentation/pixel_content_panel.dart';

/// Paused, session-only build management. Mutations are validated by the domain.
class BetaBuildPanel extends StatefulWidget {
  const BetaBuildPanel({
    super.key,
    required this.run,
    required this.onChanged,
    this.outfit = HeroOutfit.traveler,
  });
  final BetaSession run;
  final HeroOutfit outfit;
  final VoidCallback onChanged;
  @override
  State<BetaBuildPanel> createState() => _BetaBuildPanelState();
}

class _BetaBuildPanelState extends State<BetaBuildPanel> {
  BetaSkillPath _path = BetaSkillPath.vanguard;
  BetaSession get run => widget.run;
  void _changed(bool success) {
    if (!success) return;
    setState(() {});
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(12),
    backgroundColor: Colors.transparent,
    child: SizedBox(
      width: 560,
      height: math.min(610, MediaQuery.sizeOf(context).height - 48),
      child: PixelContentPanel(
        child: DefaultTabController(
          length: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'GRIMÓRIO DOS ECOS',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    constraints: const BoxConstraints.tightFor(
                      width: 36,
                      height: 36,
                    ),
                    padding: EdgeInsets.zero,
                    tooltip: 'Fechar grimório',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Text(
                'Nível ${run.level} · ${run.skillPoints} PH da expedição',
                style: const TextStyle(fontSize: 12),
              ),
              if (!run.canManageBuild)
                const Text(
                  'Combos e habilidades: altere antes de entrar ou após limpar a área.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF754E37)),
                ),
              const TabBar(
                labelStyle: TextStyle(fontSize: 12),
                labelPadding: EdgeInsets.symmetric(horizontal: 4),
                labelColor: Color(0xFF314C40),
                unselectedLabelColor: Color(0xFF646B5A),
                indicatorColor: Color(0xFF887140),
                tabs: [
                  Tab(text: 'Combos', height: 36),
                  Tab(text: 'Habilidades', height: 36),
                  Tab(text: 'Equipamento', height: 36),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    ListView(
                      key: const ValueKey('beta-combo-book'),
                      padding: const EdgeInsets.only(top: 8),
                      children: [
                        const Text(
                          'Em Mistura, toque no segundo elemento e conjure. '
                          'Acerte para descobrir. Só 3 combos descobertos podem ficar equipados.',
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Equipados: ${run.equippedCombos.length}/3 · descobertos: ${run.discoveredCombos.length}/6',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final combo in BetaCombo.values) _combo(combo),
                      ],
                    ),
                    _skillTree(),
                    _equipment(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _equipment() {
    final gear = run.loadout;
    return ListView(
      key: const ValueKey('beta-equipment'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        const Text(
          'EQUIPAMENTO ATIVO',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          'Ataque da relíquia: +${gear.attackBonus} · Agilidade: +${gear.agility}',
          style: const TextStyle(fontSize: 12),
        ),
        const Text(
          'Compras permanecem após sair. Para trocar, volte à loja e entre novamente no BETA. '
          'Consultar aqui não equipa nem gasta Ecos.',
          style: TextStyle(fontSize: 12),
        ),
        const Divider(),
        _equipmentEntry(
          'Traje',
          widget.outfit.label,
          '${widget.outfit.description} Sem bônus de combate.',
        ),
        for (final entry in [
          ('Espada · técnica', gear.sword, 'Corte original'),
          ('Esquiva · técnica', gear.dodge, 'Rolagem original'),
          ('Arma', gear.weapon, 'Espada elemental original'),
          ('Capa', gear.cloak, 'Manto original'),
          ('Peitoral', gear.armor, 'Sem relíquia'),
        ])
          _equipmentEntry(
            entry.$1,
            entry.$2?.label ?? entry.$3,
            entry.$2?.description ?? 'Padrão · sem bônus adicional.',
          ),
        const Divider(),
        const Text(
          'Trajes e técnicas são visuais: não ampliam alcance, dano ou invulnerabilidade.',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _equipmentEntry(String slot, String name, String description) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              slot.toUpperCase(),
              style: const TextStyle(fontSize: 10, color: Color(0xFF646B5A)),
            ),
            Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            Text(description, style: const TextStyle(fontSize: 12)),
          ],
        ),
      );

  Widget _skillTree() => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 480;
      final nodes = BetaSkill.values.where((s) => s.path == _path).toList();
      final connection = run.hasSkill(nodes.first)
          ? const Color(0xFF887140)
          : const Color(0xFFB7B59E);
      return ListView(
        padding: const EdgeInsets.only(top: 4),
        children: [
          Wrap(
            spacing: 4,
            children: [
              for (final path in BetaSkillPath.values)
                ChoiceChip(
                  tooltip: path.description,
                  label: Text(path.label, style: const TextStyle(fontSize: 11)),
                  selectedColor: const Color(0xFFCBD5B9),
                  backgroundColor: const Color(0xFFE5DFC9),
                  checkmarkColor: const Color(0xFF314C40),
                  selected: _path == path,
                  onSelected: (_) => setState(() => _path = path),
                ),
            ],
          ),
          if (!wide) ...[
            const SizedBox(height: 6),
            Text(_path.description, style: const TextStyle(fontSize: 12)),
            const Text(
              '1 PH inicial · +1 PH por nível · cada nó custa 1 PH',
              style: TextStyle(fontSize: 11),
            ),
          ],
          const SizedBox(height: 6),
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _skill(nodes.first)),
                Padding(
                  padding: const EdgeInsets.only(top: 30),
                  child: Icon(Icons.arrow_forward, size: 20, color: connection),
                ),
                Expanded(child: _skill(nodes.last)),
              ],
            )
          else ...[
            _skill(nodes.first),
            Center(child: Container(height: 18, width: 3, color: connection)),
            _skill(nodes.last),
          ],
        ],
      );
    },
  );

  Widget _card({
    required Widget child,
    Color color = const Color(0xFFB7B59E),
  }) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0x55FFFFFF),
      border: Border.all(color: color, width: 2),
    ),
    child: child,
  );

  Widget _combo(BetaCombo combo) {
    final known = run.discoveredCombos.contains(combo);
    final slot = run.equippedCombos.indexOf(combo);
    return _card(
      color: known ? betaComboColor(combo) : const Color(0xFFB7B59E),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            combo.label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          Text(
            '${combo.recipe} · ${combo.mana} MP · ${combo.cooldown}s',
            style: const TextStyle(fontSize: 11),
          ),
          Text(combo.description, style: const TextStyle(fontSize: 12)),
          if (combo.radius > 0)
            const Text(
              'Alvos secundários: 60% do dano; colunas bloqueiam a explosão.',
              style: TextStyle(fontSize: 11),
            ),
          if (!known)
            const Text(
              'Não descoberto · acerte um inimigo para registrar.',
              style: TextStyle(fontSize: 11),
            )
          else if (slot >= 0)
            Row(
              children: [
                const Icon(Icons.check, size: 16, color: Color(0xFF416D51)),
                const SizedBox(width: 4),
                Text(
                  'Equipado no slot ${slot + 1}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            )
          else if (run.equippedCombos.length < 3)
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF314C40),
              ),
              onPressed: run.canManageBuild
                  ? () => _changed(run.equipCombo(combo))
                  : null,
              child: const Text('Equipar'),
            )
          else
            PopupMenuButton<int>(
              enabled: run.canManageBuild,
              tooltip: 'Escolher slot para ${combo.label}',
              onSelected: (slot) =>
                  _changed(run.equipCombo(combo, replaceSlot: slot)),
              itemBuilder: (_) => [
                for (var i = 0; i < run.equippedCombos.length; i++)
                  PopupMenuItem(
                    value: i,
                    child: Text(
                      'Slot ${i + 1}: ${run.equippedCombos[i].label}',
                    ),
                  ),
              ],
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Substituir um slot ▾',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _skill(BetaSkill skill) {
    final lock = run.skillLock(skill);
    final learned = run.hasSkill(skill);
    return _card(
      color: learned ? const Color(0xFF416D51) : const Color(0xFFB7B59E),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                learned
                    ? Icons.check_circle
                    : switch (skill.path) {
                        BetaSkillPath.vanguard => Icons.flash_on,
                        BetaSkillPath.guardian => Icons.shield,
                        BetaSkillPath.attunement => Icons.auto_awesome,
                      },
                size: 18,
                color: const Color(0xFF416D51),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  skill.label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          Text(skill.description, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 6),
          TextButton(
            key: ValueKey('beta-learn-${skill.name}'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF314C40),
            ),
            onPressed: lock == null
                ? () => _changed(run.learnSkill(skill))
                : null,
            child: Text(lock ?? 'Aprender · 1 PH'),
          ),
        ],
      ),
    );
  }
}
