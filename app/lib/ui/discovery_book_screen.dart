import 'package:flutter/material.dart';
import '../game_domain/discovery_catalog.dart';
import '../game_domain/element_catalog.dart';
import '../game_presentation/pixel_arena_background.dart';
import '../game_presentation/pixel_content_panel.dart';

/// Read-only book. Equipment still uses the existing three-slot manager.
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
  String? element;
  int? cost;
  bool equippedOnly = false, managing = false;
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.entries();
    final total = const DiscoveryCatalog().total;
    final visible = entries
        .where(
          (e) => e.matches(
            query: search.text,
            element: element,
            cost: cost,
            equippedOnly: equippedOnly,
          ),
        )
        .toList();
    final elements = const ElementCatalog().all();
    return Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: ArenaBackdropPainter())),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text(
              'Livro de Descobertas',
              style: TextStyle(fontFamily: 'monospace', fontSize: 18),
            ),
            actions: [
              IconButton(
                tooltip: 'Atualizar livro',
                icon: const Icon(Icons.refresh),
                onPressed: () => setState(() {}),
              ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: PixelContentPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.playerLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${entries.length}/$total descobertas · ${entries.where((e) => e.equipped).length}/3 equipadas',
                    ),
                    LinearProgressIndicator(
                      value: total == 0 ? 0 : entries.length / total,
                      color: const Color(0xFF6D7D49),
                      backgroundColor: const Color(0xFFD8D1B8),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Gerenciar habilidades'),
                      onPressed: managing
                          ? null
                          : () async {
                              setState(() => managing = true);
                              try {
                                await widget.onManage();
                              } finally {
                                if (mounted) setState(() => managing = false);
                              }
                            },
                    ),
                    TextField(
                      controller: search,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Buscar nome, elemento ou efeito',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      key: ValueKey('element-filter-$element'),
                      initialValue: element,
                      hint: const Text('Todos os elementos'),
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Elemento da receita',
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Todos os elementos'),
                        ),
                        for (final e in elements)
                          DropdownMenuItem(
                            value: e.id,
                            child: Text('${e.symbol} ${e.name}'),
                          ),
                      ],
                      onChanged: (value) => setState(() => element = value),
                    ),
                    Wrap(
                      spacing: 6,
                      children: [
                        FilterChip(
                          label: const Text('Equipadas'),
                          selected: equippedOnly,
                          onSelected: (value) =>
                              setState(() => equippedOnly = value),
                        ),
                        for (final ap in [3, 5])
                          FilterChip(
                            label: Text('$ap AP base'),
                            selected: cost == ap,
                            onSelected: (value) =>
                                setState(() => cost = value ? ap : null),
                          ),
                      ],
                    ),
                    if (search.text.isNotEmpty ||
                        element != null ||
                        cost != null ||
                        equippedOnly)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => setState(() {
                            search.clear();
                            element = null;
                            cost = null;
                            equippedOnly = false;
                          }),
                          child: const Text('Limpar filtros'),
                        ),
                      ),
                    const Text(
                      'Valores base. A prévia da batalha considera sua build e os status.',
                      style: TextStyle(fontSize: 11),
                    ),
                    const Text(
                      'Disponibilidade na última consulta. Use ↻ para atualizar.',
                      style: TextStyle(fontSize: 11),
                    ),
                    const SizedBox(height: 12),
                    if (entries.isEmpty)
                      const Text(
                        'Seu livro está em branco. Experimente 2 ou 3 elementos e complete o selo para registrar uma combinação.',
                      ),
                    if (entries.isNotEmpty && visible.isEmpty)
                      const Text('Nenhuma descoberta corresponde aos filtros.'),
                    for (final entry in visible)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F2DA),
                            border: Border.all(
                              color: const Color(0xFF343C38),
                              width: 2,
                            ),
                          ),
                          child: ExpansionTile(
                            key: ValueKey('discovery-${entry.id}'),
                            title: Text(
                              entry.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              '${entry.apCost} AP base · ${entry.damage} dano base\n${entry.equipped
                                  ? 'Equipada · ${entry.unavailableReason ?? 'disponível na consulta'}'
                                  : entry.learned
                                  ? 'Descoberta · não equipada'
                                  : 'Registrada · ainda não aprendida por este jogador'}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            childrenPadding: const EdgeInsets.all(12),
                            expandedCrossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Receita: ${entry.elements.map((id) => elements.firstWhere((e) => e.id == id)).map((e) => '${e.symbol} ${e.name}').join(' + ')}',
                              ),
                              const SizedBox(height: 8),
                              Text(entry.description),
                              Text(
                                'Selo: ${entry.elements.length == 2 ? '4 nós · 6 segundos' : '6 nós · 8 segundos'}',
                              ),
                              if (!entry.learned)
                                const Text(
                                  'Descubra esta combinação com este jogador para desbloquear sua habilidade.',
                                ),
                            ],
                          ),
                        ),
                      ),
                    if (entries.length < total)
                      Text(
                        '${total - entries.length} combinações ainda desconhecidas. As receitas permanecem ocultas.',
                        key: const ValueKey('undiscovered-count'),
                        style: const TextStyle(fontStyle: FontStyle.italic),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
