import 'package:flutter/material.dart';
import '../game_domain/conjuration_seal.dart';
import '../game_domain/discovery_catalog.dart';
import '../game_domain/element_catalog.dart';
import '../game_presentation/rpg_journal.dart';
import '../game_presentation/sfx_player.dart';

/// Only discovered recipes enter this screen. Equipment uses its existing owner.
class DiscoveryBookScreen extends StatefulWidget {
  const DiscoveryBookScreen({
    super.key,
    required this.entries,
    required this.onManage,
    required this.playerLabel,
  });
  final List<DiscoveryEntry> Function() entries;
  final Future<void> Function() onManage;
  final String playerLabel;
  @override
  State<DiscoveryBookScreen> createState() => _DiscoveryBookScreenState();
}

class _DiscoveryBookScreenState extends State<DiscoveryBookScreen> {
  final search = TextEditingController();
  String? element, role;
  int? cost;
  bool equippedOnly = false, managing = false;
  String order = 'Nome';
  String? error;
  bool get filtered =>
      search.text.isNotEmpty ||
      element != null ||
      role != null ||
      cost != null ||
      equippedOnly;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void _clear() => setState(() {
    search.clear();
    element = null;
    role = null;
    cost = null;
    equippedOnly = false;
  });

  Future<void> _manage() async {
    if (managing) return;
    setState(() {
      managing = true;
      error = null;
    });
    try {
      await widget.onManage();
    } catch (_) {
      if (mounted) {
        error = 'Não foi possível abrir as habilidades. Tente novamente.';
      }
    } finally {
      if (mounted) setState(() => managing = false);
    }
  }

  void _filters() {
    FocusScope.of(context).unfocus();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: RpgJournal.paper,
      builder: (context) => StatefulBuilder(
        builder: (context, update) {
          void change(VoidCallback action) {
            setState(action);
            update(() {});
          }

          return Theme(
            data: RpgJournal.themeFor(context),
            child: SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * .85,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'ENCONTRE SUA PRÓXIMA ESCOLHA',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: element,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Elemento da receita',
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Todos os elementos'),
                          ),
                          for (final e in const ElementCatalog().all())
                            DropdownMenuItem(
                              value: e.id,
                              child: Text('${e.symbol} ${e.name}'),
                            ),
                        ],
                        onChanged: (value) => change(() => element = value),
                      ),
                      Wrap(
                        spacing: 6,
                        children: [
                          for (final value in [
                            'Ataque',
                            'Suporte',
                            'Controle',
                            'Desgaste',
                          ])
                            FilterChip(
                              label: Text(value),
                              selected: role == value,
                              onSelected: (selected) =>
                                  change(() => role = selected ? value : null),
                            ),
                        ],
                      ),
                      Wrap(
                        spacing: 6,
                        children: [
                          FilterChip(
                            label: const Text('Equipadas'),
                            selected: equippedOnly,
                            onSelected: (value) =>
                                change(() => equippedOnly = value),
                          ),
                          for (final ap in [3, 5])
                            FilterChip(
                              label: Text('$ap AP base'),
                              selected: cost == ap,
                              onSelected: (selected) =>
                                  change(() => cost = selected ? ap : null),
                            ),
                        ],
                      ),
                      const Text(
                        'Filtros só mostram receitas já registradas. Uma combinação pode ter mais de uma função.',
                        style: TextStyle(fontSize: 12),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Ver resultados'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final typing = MediaQuery.viewInsetsOf(context).bottom > 0;
    final entries = widget.entries();
    final total = const DiscoveryCatalog().total;
    final visible =
        entries
            .where(
              (e) => e.matches(
                query: search.text,
                element: element,
                cost: cost,
                equippedOnly: equippedOnly,
                role: role,
              ),
            )
            .toList()
          ..sort((a, b) {
            final comparison = switch (order) {
              'Dano' => b.damage.compareTo(a.damage),
              'AP' => a.apCost.compareTo(b.apCost),
              _ => 0,
            };
            return comparison != 0 ? comparison : a.name.compareTo(b.name);
          });
    return RpgJournal(
      title: 'LIVRO DE DESCOBERTAS',
      actions: [
        IconButton(
          tooltip: 'Atualizar livro',
          icon: const Icon(Icons.refresh),
          onPressed: () => setState(() {}),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!typing)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.playerLabel,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${entries.length}/$total descobertas · ${entries.where((e) => e.equipped).length}/3 equipadas',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 104,
                    child: TextButton(
                      onPressed: managing ? null : _manage,
                      child: Text(
                        managing ? 'Abrindo…' : 'Gerenciar habilidades',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (!typing)
            LinearProgressIndicator(
              value: total == 0 ? 0 : (entries.length / total).clamp(0, 1),
              color: const Color(0xFF6D7D49),
              backgroundColor: const Color(0xFFD8D1B8),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: search,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Nome, elemento ou efeito',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Filtrar descobertas',
                  onPressed: _filters,
                  icon: Icon(
                    filtered ? Icons.filter_alt : Icons.filter_alt_outlined,
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Ordenar descobertas',
                  initialValue: order,
                  icon: const Icon(Icons.sort),
                  onSelected: (value) => setState(() => order = value),
                  itemBuilder: (_) => [
                    for (final value in ['Nome', 'AP', 'Dano'])
                      PopupMenuItem(value: value, child: Text(value)),
                  ],
                ),
              ],
            ),
          ),
          if (!typing)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${visible.length} registros · ${role ?? (equippedOnly ? 'Equipadas' : order)}${element == null ? '' : ' · ${const ElementCatalog().all().firstWhere((e) => e.id == element).name}'}${cost == null ? '' : ' · $cost AP'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  if (filtered)
                    TextButton(
                      onPressed: _clear,
                      child: const Text('Limpar filtros'),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        'Toque para explorar',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: ListView(
              key: const PageStorageKey('discovery-pages'),
              padding: const EdgeInsets.all(8),
              children: [
                if (error != null)
                  Text(
                    error!,
                    style: const TextStyle(color: Color(0xFF993D2C)),
                  ),
                if (entries.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Seu livro está em branco. Experimente 2 ou 3 elementos e complete o selo para registrar uma combinação.\n\nDepois, equipe suas favoritas entre as 3 habilidades.',
                    ),
                  ),
                if (entries.isNotEmpty && visible.isEmpty)
                  const Text('Nenhuma descoberta corresponde aos filtros.'),
                for (final entry in visible) _entry(entry),
                if (entries.length < total)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      '${total - entries.length} combinações ainda desconhecidas. As receitas permanecem ocultas.',
                      key: const ValueKey('undiscovered-count'),
                      style: const TextStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: 12,
                      ),
                    ),
                  ),
                const Text(
                  'Valores base. A prévia da batalha considera build, status e selo perfeito. Disponibilidade na última consulta; use ↻ para atualizar.',
                  style: TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _entry(DiscoveryEntry entry) {
    final elements = const ElementCatalog().all();
    final seal = ConjurationSeal(entry.elements);
    final accent = entry.equipped
        ? const Color(0xFF537345)
        : const Color(0xFF886D49);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8DF),
        border: Border(
          left: BorderSide(color: accent, width: 5),
          top: const BorderSide(color: RpgJournal.gold),
          right: const BorderSide(color: RpgJournal.gold),
          bottom: const BorderSide(color: RpgJournal.gold),
        ),
      ),
      child: ExpansionTile(
        onExpansionChanged: (open) {
          if (open) sfxPlayer.play(SfxId.tap);
        },
        key: ValueKey('discovery-${entry.id}'),
        leading: Icon(
          entry.equipped ? Icons.bookmark : Icons.auto_awesome,
          color: accent,
        ),
        title: Text(
          entry.name,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          '${entry.apCost} AP · ${entry.roles.join(' / ')}\n${entry.equipped
              ? 'Equipada'
              : entry.learned
              ? 'Aprendida · não equipada'
              : 'Registrada · ainda não aprendida'}',
          style: const TextStyle(fontSize: 12),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(color: RpgJournal.gold),
          const Text(
            'Receita: toque em um elemento para encontrar sinergias',
            style: TextStyle(fontSize: 12),
          ),
          Wrap(
            spacing: 6,
            children: [
              for (final id in entry.elements)
                ActionChip(
                  label: Text(
                    '${elements.firstWhere((e) => e.id == id).symbol} ${elements.firstWhere((e) => e.id == id).name}',
                  ),
                  onPressed: () => setState(() {
                    element = id;
                    search.clear();
                    role = null;
                    cost = null;
                    equippedOnly = false;
                  }),
                ),
            ],
          ),
          Text(entry.description),
          if (entry.roles.contains('Desgaste'))
            const Text(
              'Sinergia: Percepção Elemental reforça Queimadura e Veneno dos combos.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            )
          else if (entry.damage > 0)
            const Text(
              'Sinergia: Concentração recompensa conjurar com AP cheio; Fragmentação ajuda contra proteções.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            )
          else if (entry.roles.contains('Suporte'))
            const Text(
              'Sinergia: Treino de Guarda acrescenta proteção ao conjurar combos de suporte.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          const SizedBox(height: 8),
          Text(
            '${entry.damage} dano direto base${entry.healing > 0 ? ' · +${entry.healing} HP' : ''}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            'Selo ${seal.difficulty.toLowerCase()}: ${seal.nodes.length} nós · ${seal.durationMs ~/ 1000} segundos',
          ),
          const Text(
            'Precisão: 100 / 80 / 60 / 40% do dano direto. Cura e status não diminuem.',
            style: TextStyle(fontSize: 11),
          ),
          if (entry.equipped)
            Text(
              entry.unavailableReason ?? 'Disponível na última consulta.',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          if (!entry.learned)
            const Text(
              'Descubra esta combinação com este jogador para desbloquear sua habilidade.',
            )
          else
            TextButton.icon(
              onPressed: managing ? null : _manage,
              icon: const Icon(Icons.tune),
              label: const Text('Ajustar minhas 3 habilidades'),
            ),
        ],
      ),
    );
  }
}
