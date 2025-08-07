import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

enum ViewMode { list, grid, design }

enum TableStatus { available, inUse, reserved }

extension TableStatusExt on TableStatus {
  String get label {
    switch (this) {
      case TableStatus.available:
        return 'Disponible';
      case TableStatus.inUse:
        return 'En uso';
      case TableStatus.reserved:
        return 'Reservada';
    }
  }

  Color get color {
    switch (this) {
      case TableStatus.available:
        return Colors.green.shade100;
      case TableStatus.inUse:
        return Colors.blue.shade100;
      case TableStatus.reserved:
        return Colors.red.shade100;
    }
  }

  Color get textColor {
    switch (this) {
      case TableStatus.available:
        return Colors.green.shade800;
      case TableStatus.inUse:
        return Colors.blue.shade800;
      case TableStatus.reserved:
        return Colors.red.shade800;
    }
  }
}

class TablesScreen extends StatefulWidget {
  const TablesScreen({Key? key}) : super(key: key);

  @override
  State<TablesScreen> createState() => _TablesScreenState();
}

class _TablesScreenState extends State<TablesScreen> {
  String? _businessId;
  bool _loadingBusiness = true;
  String? _error;

  ViewMode _viewMode = ViewMode.list;
  TableStatus? _filterStatus;
  String? _selectedZoneId; // null = todas

  @override
  void initState() {
    super.initState();
    _loadBusiness();
  }

  Future<void> _loadBusiness() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw 'No autenticado';
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();
      final bizId = doc.data()?['negocio_id'] as String?;
      if (bizId == null) throw 'Negocio no configurado';
      setState(() {
        _businessId = bizId;
        _loadingBusiness = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loadingBusiness = false;
      });
    }
  }

  Stream<QuerySnapshot> _zonesStream() {
    return FirebaseFirestore.instance
        .collection('negocios')
        .doc(_businessId)
        .collection('zonas')
        .orderBy('createdAt')
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> tablesStream() {
    // 1) arrancamos con un Query<Map> (no CollectionReference)
    Query<Map<String, dynamic>> ref;

    if (_selectedZoneId != null) {
      // Si hay zona, es la subcolección mesas de esa zona
      ref = FirebaseFirestore.instance
          .collection('negocios')
          .doc(_businessId)
          .collection('zonas')
          .doc(_selectedZoneId)
          .collection('mesas');
    } else {
      // Todas las áreas: uso collectionGroup
      ref = FirebaseFirestore.instance
          .collectionGroup('mesas')
          .where('negocioId', isEqualTo: _businessId);
    }

    // 2) apéndale el filtro de estado, que sigue siendo un Query
    if (_filterStatus != null) {
      ref = ref.where('estado', isEqualTo: _filterStatus!.name);
    }

    // 3) devuelve snapshots() de tu Query
    return ref.snapshots();
  }

  void _showAddTableDialog(List<QueryDocumentSnapshot> zonas) {
    String? zoneId = zonas.isNotEmpty ? zonas.first.id : null;
    final codeCtrl = TextEditingController();
    final capCtrl = TextEditingController();
    TableStatus status = TableStatus.available;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Agregar mesa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Zona
            DropdownButtonFormField<String>(
              value: zoneId,
              items: zonas
                  .map(
                    (z) =>
                        DropdownMenuItem(value: z.id, child: Text(z['nombre'])),
                  )
                  .toList(),
              decoration: const InputDecoration(labelText: 'Elegir zona'),
              onChanged: (v) => zoneId = v,
            ),
            const SizedBox(height: 8),
            // Código
            TextFormField(
              controller: codeCtrl,
              decoration: const InputDecoration(
                labelText: 'Código de mesa',
                hintText: 'Ej. M01',
              ),
            ),
            const SizedBox(height: 8),
            // Capacidad
            TextFormField(
              controller: capCtrl,
              decoration: const InputDecoration(
                labelText: 'Capacidad de asientos',
                hintText: 'Ej. 4',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            // Estado
            Wrap(
              spacing: 8,
              children: TableStatus.values.map((s) {
                final sel = s == status;
                return ChoiceChip(
                  label: Text(s.label),
                  selected: sel,
                  onSelected: (_) => setState(() => status = s),
                  selectedColor: s.color.withOpacity(.5),
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: const Text('Guardar'),
            onPressed: () async {
              if (zoneId != null && codeCtrl.text.isNotEmpty) {
                final cap = int.tryParse(capCtrl.text) ?? 0;
                await FirebaseFirestore.instance
                    .collection('negocios')
                    .doc(_businessId)
                    .collection('zonas')
                    .doc(zoneId)
                    .collection('mesas')
                    .add({
                      'codigo': codeCtrl.text.trim(),
                      'capacidad': cap,
                      'estado': status.name,
                      'kotCount': 0, // <— inicializa aquí
                      'createdAt': FieldValue.serverTimestamp(),
                    });

                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTableCard(DocumentSnapshot doc) {
    final code = doc['codigo'] as String;
    final cap = doc['capacidad'] as int;
    final status = TableStatus.values.firstWhere(
      (s) => s.name == doc['estado'],
      orElse: () => TableStatus.available,
    );
    final kotCount = doc['kotCount'] as int? ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: status.color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: status.textColor, width: 1),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            code,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: status.textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text('$cap Asiento(s)', style: TextStyle(color: status.textColor)),
          if (kotCount > 0) ...[
            const SizedBox(height: 4),
            Text(
              '$kotCount KOT',
              style: TextStyle(fontSize: 12, color: status.textColor),
            ),
          ],
          const SizedBox(height: 8),
          // Actions
          Wrap(
            spacing: 4,
            children: [
              TextButton(
                child: const Text('Ver pedido'),
                onPressed: () {
                  /* TODO */
                },
              ),
              TextButton(
                child: const Text('Nuevo KOT'),
                onPressed: () {
                  /* TODO */
                },
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () {
                  /* TODO */
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingBusiness) {
      return Scaffold(
        appBar: AppBar(title: const Text('Vista de mesa')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Vista de mesa')),
        body: Center(child: Text(_error!)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vista de mesa'),
        actions: [
          // Filter by disponibilidad
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: DropdownButton<TableStatus?>(
              value: _filterStatus,
              underline: const SizedBox(),
              icon: const Icon(Icons.filter_list, color: Colors.white),
              items: [
                const DropdownMenuItem(value: null, child: Text('Todos')),
                ...TableStatus.values
                    .map(
                      (s) => DropdownMenuItem(value: s, child: Text(s.label)),
                    )
                    .toList(),
              ],
              onChanged: (v) => setState(() => _filterStatus = v),
            ),
          ),
          TextButton.icon(
            onPressed: () {}, // TODO: función “Agregar mesa”
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              'Agregar mesa',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Vista selector
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                _buildViewButton(ViewMode.list, Icons.list, 'Lista'),
                const SizedBox(width: 8),
                _buildViewButton(ViewMode.grid, Icons.grid_view, 'Cuadrícula'),
                const SizedBox(width: 8),
                _buildViewButton(
                  ViewMode.design,
                  Icons.design_services,
                  'Diseño',
                ),
              ],
            ),
          ),

          // Zona chips
          SizedBox(
            height: 40,
            child: StreamBuilder<QuerySnapshot>(
              stream: _zonesStream(),
              builder: (ctx, snap) {
                final zones = snap.data?.docs ?? [];
                return ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    ChoiceChip(
                      label: const Text('Todas las áreas'),
                      selected: _selectedZoneId == null,
                      onSelected: (_) => setState(() => _selectedZoneId = null),
                    ),
                    ...zones.map(
                      (z) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(z['nombre']),
                          selected: _selectedZoneId == z.id,
                          onSelected: (_) =>
                              setState(() => _selectedZoneId = z.id),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          const Divider(height: 1),

          // Contenido
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: tablesStream(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('No hay mesas.'));
                }
                switch (_viewMode) {
                  case ViewMode.list:
                    return ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _buildTableCard(docs[i]),
                    );
                  case ViewMode.grid:
                    return GridView.builder(
                      padding: const EdgeInsets.all(8),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 1.2,
                          ),
                      itemCount: docs.length,
                      itemBuilder: (_, i) => _buildTableCard(docs[i]),
                    );
                  case ViewMode.design:
                    // Aquí podrías implementar un lienzo con posicionamiento y drag&drop.
                    // Por ahora lo mostramos igual que grid, dentro de un contenedor.
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: docs
                              .map(
                                (d) => SizedBox(
                                  width: 100,
                                  height: 100,
                                  child: _buildTableCard(d),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    );
                }
              },
            ),
          ),
        ],
      ),
      floatingActionButton: StreamBuilder<QuerySnapshot>(
        stream: _zonesStream(),
        builder: (ctx, snap) {
          final zones = snap.data?.docs ?? [];
          return FloatingActionButton.extended(
            onPressed: () => _showAddTableDialog(zones),
            icon: const Icon(Icons.add),
            label: const Text('Agregar mesa'),
          );
        },
      ),
    );
  }

  Widget _buildViewButton(ViewMode mode, IconData icon, String label) {
    final sel = _viewMode == mode;
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        foregroundColor: sel ? Colors.white : Colors.black87,
        backgroundColor: sel ? Colors.blue : Colors.grey.shade200,
      ),
      onPressed: () => setState(() => _viewMode = mode),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}
