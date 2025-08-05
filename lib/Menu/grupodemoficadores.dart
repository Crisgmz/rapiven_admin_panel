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
        appBar: AppBar(title: const Text('Grupos de modificadores')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Grupos de modificadores')),
        body: Center(child: Text(error!)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Grupos de modificadores'),
        actions: [
          TextButton.icon(
            onPressed: () => _showAddOrEditDialog(context, null),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              'Agregar grupo',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Busca tu grupo aquí',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (q) => setState(() => searchQuery = q.toLowerCase()),
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
            return const Center(child: Text('No hay grupos de modificadores'));
          }

          return ListView.separated(
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final d = filtered[i];
              final data = _convertFirestoreData(d.data());
              final options = _convertOptionsList(data['options']);

              return ListTile(
                title: Text(data['name']?.toString() ?? ''),
                subtitle: Wrap(
                  spacing: 8,
                  children: options.map<Widget>((o) {
                    final price = (o['price'] ?? 0).toString();
                    return Chip(
                      label: Text(
                        '${o['name']?.toString().toUpperCase() ?? ''} : \$ $price',
                      ),
                      backgroundColor: Colors.green.shade100,
                    );
                  }).toList(),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _showAddOrEditDialog(context, d),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Eliminar grupo'),
                            content: const Text('¿Seguro deseas eliminarlo?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancelar'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Eliminar'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await d.reference.delete();
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
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
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Descripción'),
                  ),
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Opciones de modificador',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Dynamic options
                  ...localOptions.asMap().entries.map((e) {
                    final idx = e.key;
                    final o = e.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
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
                                  horizontal: 8,
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
                                  horizontal: 8,
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
                            icon: const Icon(Icons.close, color: Colors.red),
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
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Ubicaciones',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 4),
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
                        vertical: 8,
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
