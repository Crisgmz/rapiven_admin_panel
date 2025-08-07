import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PuntoVentaScreen extends StatefulWidget {
  const PuntoVentaScreen({Key? key}) : super(key: key);

  @override
  State<PuntoVentaScreen> createState() => _PuntoVentaScreenState();
}

class _PuntoVentaScreenState extends State<PuntoVentaScreen> {
  String? _businessId;
  bool _loading = true;
  String? _error;

  // Búsqueda y menú seleccionado
  String _search = '';
  String? _selectedMenuId;

  // Pedido en memoria
  final List<_OrderItem> _orderItems = [];
  bool _isDelivery = false;
  String? _orderNote;
  late final String _orderNumber; // Número fijo del pedido

  @override
  void initState() {
    super.initState();
    _orderNumber = (DateTime.now().millisecondsSinceEpoch % 10000).toString();
    _loadBusiness();
  }

  Future<void> _loadBusiness() async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .get();
      _businessId = doc.data()?['business_id'] as String?;
      if (_businessId == null) throw 'Negocio no configurado';
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() => _loading = false);
    }
  }

  /// Stream de menús
  Stream<List<_Menu>> get _menusStream {
    if (_businessId == null) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('negocios')
        .doc(_businessId)
        .collection('menus')
        .orderBy('createdAt')
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) {
            final m = d.data();
            return _Menu(
              id: d.id,
              name: m['name'] as String? ?? 'Sin nombre',
              count: m['count'] as int? ?? 0,
            );
          }).toList(),
        );
  }

  /// Stream de artículos
  Stream<QuerySnapshot<Map<String, dynamic>>> get _articlesStream {
    if (_businessId == null || _selectedMenuId == null) {
      return const Stream.empty();
    }
    var ref = FirebaseFirestore.instance
        .collection('negocios')
        .doc(_businessId)
        .collection('menus')
        .doc(_selectedMenuId)
        .collection('articles')
        .orderBy('createdAt');
    if (_search.isNotEmpty) {
      ref = ref.where('search_keys', arrayContains: _search.toLowerCase());
    }
    return ref.snapshots();
  }

  /// Agrega un artículo al pedido: maneja variaciones y modificadores
  Future<void> _onTapArticle(
    String articleId,
    String baseName,
    double basePrice,
  ) async {
    String? variationName;
    List<Map<String, dynamic>> modifiersList = [];

    // 1) Variaciones
    final artDoc = await FirebaseFirestore.instance
        .collection('negocios')
        .doc(_businessId)
        .collection('menus')
        .doc(_selectedMenuId)
        .collection('articles')
        .doc(articleId)
        .get();
    final artData = artDoc.data()!;
    final variations = (artData['variations'] as List?) ?? [];
    if (variations.isNotEmpty) {
      final selVar = await _showVariationsDialog(
        baseName,
        variations.cast<Map>(),
        artData['imageUrl'] as String?,
      );
      if (selVar == null) return; // canceló
      variationName = selVar['name'] as String;
      basePrice = (selVar['price'] as num).toDouble();
    }

    // 2) Modificadores
    final linkSnap = await FirebaseFirestore.instance
        .collection('negocios')
        .doc(_businessId)
        .collection('articleModifiers')
        .where('article_id', isEqualTo: articleId)
        .get();
    final groupIds = linkSnap.docs
        .map((d) => d.data()['group_id'] as String)
        .toList();
    if (groupIds.isNotEmpty) {
      final groupsSnap = await FirebaseFirestore.instance
          .collection('negocios')
          .doc(_businessId)
          .collection('modifierGroups')
          .where(FieldPath.documentId, whereIn: groupIds)
          .get();
      final selMods = await _showModifiersDialog(groupsSnap.docs, baseName);
      if (selMods == null) return; // canceló
      modifiersList = selMods.values.toList();
    }

    // Agrega al pedido con precio base y lista de modificadores
    setState(() {
      _orderItems.add(
        _OrderItem(
          id: articleId,
          name: baseName,
          basePrice: basePrice,
          variation: variationName,
          modifiers: modifiersList,
          quantity: 1,
        ),
      );
    });
  }

  /// Diálogo de variaciones con diseño exacto
  Future<Map<String, dynamic>?> _showVariationsDialog(
    String title,
    List<Map> variations,
    String? imageUrl,
  ) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Variaciones de artículo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 24),
              // Producto con imagen e icono
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[100],
                    ),
                    child: imageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(imageUrl, fit: BoxFit.cover),
                          )
                        : const Icon(Icons.fastfood, color: Colors.grey),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.stop, color: Color(0xFFFF5722), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Headers
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        'NOMBRE DEL ARTÍCULO',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'PRECIO',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: Text(
                        'ACCIÓN',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Variaciones
              ...variations.map((v) {
                final m = Map<String, dynamic>.from(v);
                return Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey, width: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          m['name'] ?? '',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '\$${(m['price'] ?? 0)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, m),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2196F3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                          child: const Text(
                            'Seleccionar',
                            style: TextStyle(fontSize: 12, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              const SizedBox(height: 24),
              // Botón cancelar
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Diálogo de modificadores con diseño exacto
  /// Diálogo de modificadores con diseño exacto - VERSIÓN CORREGIDA
  Future<Map<String, Map<String, dynamic>>?> _showModifiersDialog(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> groups,
    String articleName,
  ) {
    final Map<String, Map<String, dynamic>> selected = {};

    return showDialog<Map<String, Map<String, dynamic>>>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Container(
            width: 500,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Modificadores de artículo',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 24),
                // Producto con imagen e icono
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey[100],
                      ),
                      child: const Icon(
                        Icons.fastfood,
                        color: Colors.grey,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.local_drink,
                      color: Color(0xFF2196F3),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            articleName.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Grupos de modificadores
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: groups.map((gDoc) {
                        final g = gDoc.data();
                        final groupName = g['name'] as String? ?? 'Grupo';
                        final multiple = g['multiple'] as bool? ?? false;
                        final opts =
                            (g['options'] as List?)
                                ?.cast<Map<String, dynamic>>() ??
                            [];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Theme(
                            data: Theme.of(
                              context,
                            ).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              initiallyExpanded: true,
                              title: Text(
                                groupName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              children: [
                                // Headers
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 16,
                                  ),
                                  child: const Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'NOMBRE DE LA OPCIÓN',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          'PRECIO',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 100,
                                        child: Text(
                                          'SELECCIONAR',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ...opts.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final opt = entry.value;
                                  // Usar el índice como ID si no existe un ID específico
                                  final optId =
                                      opt['id'] as String? ?? index.toString();
                                  final key = multiple
                                      ? '${gDoc.id}:$optId'
                                      : gDoc.id;

                                  // Para debug - imprimir información
                                  print(
                                    'Grupo: ${gDoc.id}, Multiple: $multiple, OptId: $optId, Key: $key',
                                  );
                                  print(
                                    'Selected keys: ${selected.keys.toList()}',
                                  );

                                  // Para grupos de selección única, verificamos si alguna opción de este grupo está seleccionada
                                  // y si es esta opción específica
                                  final chosen = multiple
                                      ? selected.containsKey(key)
                                      : selected.containsKey(gDoc.id) &&
                                            selected[gDoc.id]?['id'] == optId;

                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 16,
                                    ),
                                    decoration: const BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: Colors.grey,
                                          width: 0.1,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            opt['name'] ?? '',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            opt['price'] != null
                                                ? '\$${opt['price']}'
                                                : '--',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 100,
                                          child: Checkbox(
                                            value: chosen,
                                            onChanged: (v) {
                                              print(
                                                'Checkbox changed - Group: ${gDoc.id}, OptId: $optId, Value: $v, Multiple: $multiple',
                                              );
                                              setSt(() {
                                                if (v == true) {
                                                  if (!multiple) {
                                                    // Para grupos de selección única:
                                                    // Usar el ID del grupo como clave única
                                                    selected[gDoc.id] = {
                                                      ...opt,
                                                      'id': optId,
                                                      'group_id': gDoc.id,
                                                      'group_name': groupName,
                                                    };
                                                    print(
                                                      'Selected for single group: ${selected[gDoc.id]}',
                                                    );
                                                  } else {
                                                    // Para grupos múltiples: usar clave compuesta
                                                    selected[key] = {
                                                      ...opt,
                                                      'id': optId,
                                                      'group_id': gDoc.id,
                                                      'group_name': groupName,
                                                    };
                                                  }
                                                } else {
                                                  // Remover la selección
                                                  if (!multiple) {
                                                    selected.remove(gDoc.id);
                                                  } else {
                                                    selected.remove(key);
                                                  }
                                                }
                                                print(
                                                  'Updated selected: ${selected.keys.toList()}',
                                                );
                                              });
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Botones
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, selected),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2196F3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: const Text(
                        'Guardar',
                        style: TextStyle(fontSize: 14, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Nota del pedido
  void _onAddNote() async {
    final controller = TextEditingController(text: _orderNote);
    final note = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Agregar nota'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nota del pedido'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (note != null) setState(() => _orderNote = note);
    controller.dispose();
  }

  /// Cambia la cantidad de un ítem en el pedido
  void _changeQuantity(_OrderItem item, int delta) {
    setState(() {
      item.quantity += delta;
      if (item.quantity <= 0) _orderItems.remove(item);
    });
  }

  double get _subtotal {
    double total = 0;
    for (final item in _orderItems) {
      total += item.unitPrice * item.quantity;
    }
    return total;
  }

  int get _totalItems {
    int total = 0;
    for (final item in _orderItems) {
      total += item.quantity;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Punto de Venta')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Punto de Venta')),
        body: Center(child: Text(_error!)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Punto de Venta'),
        backgroundColor: const Color(0xFF1E88E5),
      ),
      body: Row(
        children: [
          // PANEL PRODUCTOS
          Expanded(
            flex: 2,
            child: Column(
              children: [
                // Búsqueda
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Buscar elemento del menú aquí',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                ),
                // Selector de menús horizontal
                SizedBox(
                  height: 40,
                  child: StreamBuilder<List<_Menu>>(
                    stream: _menusStream,
                    builder: (ctx, snap) {
                      final menus = snap.data ?? [];
                      return ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: menus.length,
                        itemBuilder: (_, i) {
                          final m = menus[i];
                          final sel = m.id == _selectedMenuId;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ChoiceChip(
                              label: Text('${m.name} (${m.count})'),
                              selected: sel,
                              onSelected: (_) =>
                                  setState(() => _selectedMenuId = m.id),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                // Grid de artículos
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _articlesStream,
                    builder: (ctx, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final docs = snap.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return const Center(child: Text('No hay artículos.'));
                      }
                      return GridView.builder(
                        padding: const EdgeInsets.all(8),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                              childAspectRatio: 0.75,
                            ),
                        itemCount: docs.length,
                        itemBuilder: (_, i) {
                          final d = docs[i].data();
                          final name = d['name'] as String? ?? 'Sin nombre';
                          final price = (d['price'] as num?)?.toDouble() ?? 0;
                          final img = d['imageUrl'] as String?;
                          return GestureDetector(
                            onTap: () => _onTapArticle(docs[i].id, name, price),
                            child: Card(
                              clipBehavior: Clip.antiAlias,
                              elevation: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Container(
                                      color: Colors.grey[100],
                                      child: img != null
                                          ? Image.network(
                                              img,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  const Icon(
                                                    Icons.fastfood,
                                                    size: 48,
                                                  ),
                                            )
                                          : const Icon(
                                              Icons.fastfood,
                                              size: 48,
                                            ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            name,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            '\$${price.toStringAsFixed(0)}',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // PANEL PEDIDO
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.white,
              child: Column(
                children: [
                  // Encabezado
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey, width: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Pedido #$_orderNumber',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Text('Entrega', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 8),
                        Switch(
                          value: _isDelivery,
                          onChanged: (value) =>
                              setState(() => _isDelivery = value),
                          activeColor: const Color(0xFF4CAF50),
                        ),
                      ],
                    ),
                  ),
                  // Asignar mesa + nota
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.table_restaurant, size: 16),
                            label: const Text('Asignar mesa'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(
                            Icons.note_add,
                            color: _orderNote != null
                                ? const Color(0xFF2196F3)
                                : Colors.grey,
                          ),
                          onPressed: _onAddNote,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Lista de ítems
                  // Reemplaza la sección del ListView.builder en el panel del pedido (línea ~630 aprox)
                  // desde "Lista de ítems" hasta antes del "Divider"

                  // Lista de ítems
                  Expanded(
                    child: _orderItems.isEmpty
                        ? const Center(child: Text('No hay ítems en el pedido'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(8),
                            itemCount: _orderItems.length,
                            itemBuilder: (_, i) {
                              final it = _orderItems[i];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Nombre y botón eliminar
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            it.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.close,
                                            size: 16,
                                          ),
                                          onPressed: () => setState(
                                            () => _orderItems.removeAt(i),
                                          ),
                                          constraints: const BoxConstraints(),
                                          padding: EdgeInsets.zero,
                                        ),
                                      ],
                                    ),

                                    // Precio base (siempre mostrar)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8),
                                      child: Text(
                                        'Precio base: \$${it.basePrice.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),

                                    // Variación
                                    if (it.variation != null) ...[
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: 8,
                                          top: 2,
                                        ),
                                        child: Text(
                                          'Variación: ${it.variation!}',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                    ],

                                    // Modificadores
                                    if (it.modifiers.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      ...it.modifiers
                                          .map(
                                            (m) => Padding(
                                              padding: const EdgeInsets.only(
                                                left: 8,
                                              ),
                                              child: Text(
                                                "+ ${m['name']} (\$${m['price']})",
                                                style: TextStyle(
                                                  color: const Color(
                                                    0xFF2196F3,
                                                  ),
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ],

                                    const SizedBox(height: 8),
                                    // Cantidad y precios
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        // Controles de cantidad
                                        Container(
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: Colors.grey.shade300,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              InkWell(
                                                onTap: () =>
                                                    _changeQuantity(it, -1),
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    4,
                                                  ),
                                                  child: const Icon(
                                                    Icons.remove,
                                                    size: 16,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 4,
                                                    ),
                                                child: Text(
                                                  '${it.quantity}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                              InkWell(
                                                onTap: () =>
                                                    _changeQuantity(it, 1),
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    4,
                                                  ),
                                                  child: const Icon(
                                                    Icons.add,
                                                    size: 16,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Precios
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            // Precio unitario total (base + modificadores)
                                            Text(
                                              'Unit: \$${it.unitPrice.toStringAsFixed(0)}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            // Si hay más de 1 unidad, mostramos total de línea
                                            if (it.quantity > 1)
                                              Text(
                                                'Total: \$${(it.unitPrice * it.quantity).toStringAsFixed(0)}',
                                                style: TextStyle(
                                                  color: Colors.grey.shade600,
                                                  fontSize: 12,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  const Divider(height: 1),
                  // Resumen
                  // Dentro de tu Column de resumen, reemplaza por este Container:
                  Container(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        _buildSummaryRow('Artículos', '${_orderItems.length}'),
                        const SizedBox(height: 4),
                        _buildSummaryRow(
                          'Subtotal',
                          '\$${_subtotal.toStringAsFixed(0)}',
                        ),
                        const SizedBox(height: 4),
                        _buildSummaryRow(
                          'Propina (10.00%)',
                          '\$${(_subtotal * 0.1).toStringAsFixed(0)}',
                          isSubtle: true,
                        ),
                        const Divider(height: 16),
                        _buildSummaryRow(
                          'Total',
                          '\$${(_subtotal * 1.1).toStringAsFixed(0)}',
                          isTotal: true,
                        ),
                      ],
                    ),
                  ),

                  // Botones finales
                  Container(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildActionButton(
                                'KOT',
                                Colors.grey.shade600,
                                () {},
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildActionButton(
                                'KOT e imprimir',
                                Colors.grey.shade700,
                                () {},
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildActionButton(
                          'CUENTA',
                          const Color(0xFF2196F3),
                          () {},
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildActionButton(
                                'Cuenta y pago',
                                const Color(0xFF4CAF50),
                                () {},
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildActionButton(
                                'Facturar e imprimir',
                                const Color(0xFF2196F3),
                                () {},
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isTotal = false,
    bool isSubtle = false,
  }) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: isTotal ? 16 : 14,
          fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          color: isSubtle ? Colors.grey.shade600 : Colors.black87,
        ),
      ),
      Text(
        value,
        style: TextStyle(
          fontSize: isTotal ? 16 : 14,
          fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
          color: isSubtle ? Colors.grey.shade600 : Colors.black87,
        ),
      ),
    ],
  );

  Widget _buildActionButton(String text, Color color, VoidCallback onPressed) =>
      SizedBox(
        width: double.infinity,
        height: 36,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
}

/// Modelo de menú
class _Menu {
  final String id, name;
  final int count;
  _Menu({required this.id, required this.name, this.count = 0});
}

/// Modelo de ítem de pedido
class _OrderItem {
  final String id, name;
  final double basePrice;
  final String? variation;
  final List<Map<String, dynamic>> modifiers;
  int quantity;

  _OrderItem({
    required this.id,
    required this.name,
    required this.basePrice,
    this.variation,
    this.modifiers = const [],
    required this.quantity,
  });

  /// Precio unitario = base + suma de modificadores
  double get unitPrice {
    final modSum = modifiers.fold<double>(
      0,
      (sum, m) => sum + (m['price'] as num).toDouble(),
    );
    return basePrice + modSum;
  }
}
