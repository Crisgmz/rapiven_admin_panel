import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ModifierGroupsScreen extends StatefulWidget {
  const ModifierGroupsScreen({super.key});

  @override
  State<ModifierGroupsScreen> createState() => _ModifierGroupsScreenState();
}

class _ModifierGroupsScreenState extends State<ModifierGroupsScreen> {
  String? businessId;
  bool isLoading = true;
  String? error;
  String searchQuery = '';

  // Para el dropdown de "Ubicaciones"
  List<QueryDocumentSnapshot<Map<String, dynamic>>> articles = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw 'Usuario no autenticado';

      // 1) Obtener businessId
      final userDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();
      String? biz = userDoc.data()?['negocio_id'] as String?;
      if (biz == null) {
        final q = await FirebaseFirestore.instance
            .collection('negocios')
            .where('owner_uid', isEqualTo: user.uid)
            .where('activo', isEqualTo: true)
            .limit(1)
            .get();
        if (q.docs.isNotEmpty) biz = q.docs.first.id;
      }
      if (biz == null) throw 'No se encontró negocio activo';
      businessId = biz;

      // 2) Cargar TODOS los artículos y filtrar en cliente
      final artSnap = await FirebaseFirestore.instance
          .collectionGroup('articles')
          .get();
      articles = artSnap.docs.where((d) {
        final data = d.data();
        return data['business_id'] == businessId;
      }).toList();

      setState(() => isLoading = false);
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> get _groupsStream {
    return FirebaseFirestore.instance
        .collection('negocios')
        .doc(businessId)
        .collection('modifierGroups')
        .orderBy('createdAt')
        .snapshots();
  }

  // Helper method to safely convert Firestore data
  Map<String, dynamic> _convertFirestoreData(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    } else if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return {};
  }

  // Helper method to safely convert options list
  List<Map<String, dynamic>> _convertOptionsList(dynamic optionsData) {
    if (optionsData == null) return [];

    final List<dynamic> optionsList = optionsData is List ? optionsData : [];

    return optionsList.map((dynamic option) {
      Map<String, dynamic> convertedOption = {};

      if (option is Map<String, dynamic>) {
        convertedOption = Map<String, dynamic>.from(option);
      } else if (option is Map) {
        // Convert any Map type to Map<String, dynamic>
        option.forEach((key, value) {
          convertedOption[key.toString()] = value;
        });
      }

      // Ensure all required fields exist with proper types
      return {
        'name': convertedOption['name']?.toString() ?? '',
        'price': _convertToDouble(convertedOption['price']),
        'available': convertedOption['available'] is bool
            ? convertedOption['available']
            : true,
      };
    }).toList();
  }

  // Helper method to safely convert price to double
  double _convertToDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text('Grupos de modificadores'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text('Grupos de modificadores'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        body: Center(child: Text(error!)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Grupos de modificadores',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            child: ElevatedButton.icon(
              onPressed: () => _showAddOrEditDialog(context, null),
              icon: const Icon(Icons.add, size: 18),
              label: const Text(
                'Agregar grupo de modificadores',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Busca tu categoria de elemento aquí',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.blue[600]!),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              onChanged: (q) => setState(() => searchQuery = q.toLowerCase()),
            ),
          ),
          // Content
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _groupsStream,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data?.docs ?? [];
                final filtered = docs.where((d) {
                  final data = _convertFirestoreData(d.data());
                  final name = (data['name'] as String? ?? '').toLowerCase();
                  return name.contains(searchQuery);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text(
                      'No hay grupos de modificadores',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                return Container(
                  color: Colors.white,
                  child: Column(
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.grey[200]!),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                'NOMBRE DEL GRUPO',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[600],
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                'OPCIONES',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[600],
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
                                  color: Colors.grey[600],
                                  letterSpacing: 0.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // List items
                      Expanded(
                        child: ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              Divider(height: 1, color: Colors.grey[200]),
                          itemBuilder: (context, i) {
                            final d = filtered[i];
                            final data = _convertFirestoreData(d.data());
                            final options = _convertOptionsList(
                              data['options'],
                            );

                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      data['name']?.toString() ?? '',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: options.map<Widget>((o) {
                                        final price = _convertToDouble(
                                          o['price'],
                                        ).toStringAsFixed(0);
                                        final name =
                                            o['name']
                                                ?.toString()
                                                .toUpperCase() ??
                                            '';
                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green[100],
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: Colors.green[200]!,
                                            ),
                                          ),
                                          child: Text(
                                            '$name : \$ $price',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.green[800],
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 100,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit_outlined,
                                            size: 18,
                                          ),
                                          onPressed: () =>
                                              _showAddOrEditDialog(context, d),
                                          color: Colors.blue[600],
                                          tooltip: 'Actualizar',
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            size: 18,
                                          ),
                                          onPressed: () =>
                                              _showDeleteConfirmation(
                                                context,
                                                d,
                                              ),
                                          color: Colors.red[400],
                                          tooltip: 'Eliminar',
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = _convertFirestoreData(doc.data());
    final groupName = data['name']?.toString() ?? '';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar grupo'),
        content: Text(
          '¿Estás seguro de que deseas eliminar el grupo "$groupName"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await doc.reference.delete();
    }
  }

  Future<void> _showAddOrEditDialog(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>>? doc,
  ) async {
    final isEdit = doc != null;
    final data = doc != null
        ? _convertFirestoreData(doc.data())
        : <String, dynamic>{};

    final nameCtrl = TextEditingController(text: data['name']?.toString());
    final descCtrl = TextEditingController(
      text: data['description']?.toString(),
    );

    // Convert options to local format with controllers
    final List<Map<String, dynamic>> localOptions =
        _convertOptionsList(data['options']).map((option) {
          return {
            'nameCtrl': TextEditingController(
              text: option['name']?.toString() ?? '',
            ),
            'priceCtrl': TextEditingController(
              text: _convertToDouble(option['price']).toString(),
            ),
            'available': option['available'] is bool
                ? option['available']
                : true,
          };
        }).toList();

    String? selectedArticleId = data['article_id']?.toString();

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(isEdit ? 'Actualizar grupo' : 'Agregar grupo'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del modificador',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Descripción',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Opciones de modificador',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Dynamic options
                  ...localOptions.asMap().entries.map((e) {
                    final idx = e.key;
                    final o = e.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller:
                                  o['nameCtrl'] as TextEditingController,
                              decoration: const InputDecoration(
                                hintText: 'Ej., Queso Extra',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller:
                                  o['priceCtrl'] as TextEditingController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                hintText: 'Precio',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Checkbox(
                            value: o['available'] as bool,
                            onChanged: (v) =>
                                setState(() => o['available'] = v ?? true),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.red,
                              size: 20,
                            ),
                            onPressed: () =>
                                setState(() => localOptions.removeAt(idx)),
                          ),
                        ],
                      ),
                    );
                  }),
                  TextButton.icon(
                    onPressed: () => setState(() {
                      localOptions.add({
                        'nameCtrl': TextEditingController(),
                        'priceCtrl': TextEditingController(text: '0'),
                        'available': true,
                      });
                    }),
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar opción de modificador'),
                  ),
                  const SizedBox(height: 20),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Ubicaciones',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedArticleId,
                    hint: const Text('Seleccionar elemento del menú'),
                    items: articles.map((a) {
                      final articleData = _convertFirestoreData(a.data());
                      final name = articleData['name']?.toString() ?? '';
                      return DropdownMenuItem(value: a.id, child: Text(name));
                    }).toList(),
                    onChanged: (v) => setState(() => selectedArticleId = v),
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty ||
                      localOptions.isEmpty ||
                      selectedArticleId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Por favor completa todos los campos requeridos',
                        ),
                      ),
                    );
                    return;
                  }

                  // Validate that at least one option has a name
                  final validOptions = localOptions.where((o) {
                    final optionName = (o['nameCtrl'] as TextEditingController)
                        .text
                        .trim();
                    return optionName.isNotEmpty;
                  }).toList();

                  if (validOptions.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Debe agregar al menos una opción válida',
                        ),
                      ),
                    );
                    return;
                  }

                  final opts = validOptions.map((o) {
                    final priceText = (o['priceCtrl'] as TextEditingController)
                        .text
                        .trim();
                    return {
                      'name': (o['nameCtrl'] as TextEditingController).text
                          .trim(),
                      'price': _convertToDouble(priceText),
                      'available': o['available'] as bool,
                    };
                  }).toList();

                  final docData = {
                    'name': name,
                    'description': descCtrl.text.trim(),
                    'options': opts,
                    'article_id': selectedArticleId,
                    'updatedAt': FieldValue.serverTimestamp(),
                  };

                  try {
                    final ref = FirebaseFirestore.instance
                        .collection('negocios')
                        .doc(businessId)
                        .collection('modifierGroups');

                    if (isEdit) {
                      await doc.reference.update(docData);
                    } else {
                      docData['createdAt'] = FieldValue.serverTimestamp();
                      await ref.add(docData);
                    }

                    Navigator.pop(context);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isEdit
                              ? 'Grupo actualizado exitosamente'
                              : 'Grupo creado exitosamente',
                        ),
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: Text(isEdit ? 'Actualizar' : 'Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }
}
