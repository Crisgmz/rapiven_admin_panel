import 'dart:io' show File;
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:html' as html;

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});
  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  // Usando ValueNotifier para evitar rebuilds innecesarios
  final ValueNotifier<String?> selectedMenuIdNotifier = ValueNotifier<String?>(
    null,
  );
  final ValueNotifier<String> selectedMenuNameNotifier = ValueNotifier<String>(
    '',
  );

  String? businessId;
  bool isLoadingBusiness = true;
  String? error;
  bool _firstMenuSelected = false;

  final TextEditingController _searchController = TextEditingController();
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadBusinessForCurrentUser();
    _searchController.addListener(() {
      setState(() {
        searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    selectedMenuIdNotifier.dispose();
    selectedMenuNameNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadBusinessForCurrentUser() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw 'Usuario no autenticado';

      String? bizId;
      // 1) Desde perfil global
      final globalUser = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();
      if (globalUser.exists) {
        final data = globalUser.data()!;
        if (data['negocio_id'] != null) bizId = data['negocio_id'] as String;
      }
      // 2) Fallback por owner_uid
      if (bizId == null) {
        final q = await FirebaseFirestore.instance
            .collection('negocios')
            .where('owner_uid', isEqualTo: user.uid)
            .where('activo', isEqualTo: true)
            .limit(1)
            .get();
        if (q.docs.isNotEmpty) bizId = q.docs.first.id;
      }
      if (bizId == null) throw 'No se encontró negocio activo';

      setState(() {
        businessId = bizId;
        isLoadingBusiness = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoadingBusiness = false;
      });
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> get _menusStream {
    if (businessId == null) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('negocios')
        .doc(businessId)
        .collection('menus')
        .orderBy('createdAt')
        .snapshots();
  }

  Future<void> _updateMenuCount(String menuId, int newCount) {
    return FirebaseFirestore.instance
        .collection('negocios')
        .doc(businessId)
        .collection('menus')
        .doc(menuId)
        .update({'count': newCount});
  }

  void _showAddMenuDialog() => _showMenuDialog();
  void _showUpdateMenuDialog(
    String menuId,
    String currentName,
    String currentLang,
  ) => _showMenuDialog(menuId: menuId, name: currentName, lang: currentLang);

  Future<void> _showMenuDialog({
    String? menuId,
    String? name,
    String? lang,
  }) async {
    final isEdit = menuId != null;
    final nameCtrl = TextEditingController(text: name);
    String selectedLanguage = lang ?? 'Spanish';

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Actualizar menú' : 'Agregar menú'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: selectedLanguage,
              decoration: const InputDecoration(labelText: 'Idioma'),
              items: [
                'Spanish',
                'English',
              ].map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
              onChanged: (v) => selectedLanguage = v!,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(hintText: 'Ej. Desayuno'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = nameCtrl.text.trim();
              if (newName.isEmpty || businessId == null) return;
              final ref = FirebaseFirestore.instance
                  .collection('negocios')
                  .doc(businessId)
                  .collection('menus');
              if (isEdit) {
                await ref.doc(menuId).update({
                  'name': newName,
                  'language': selectedLanguage,
                  'updatedAt': FieldValue.serverTimestamp(),
                });
              } else {
                await ref.add({
                  'name': newName,
                  'language': selectedLanguage,
                  'count': 0,
                  'createdAt': FieldValue.serverTimestamp(),
                });
              }
              Navigator.pop(ctx);
            },
            child: Text(isEdit ? 'Actualizar' : 'Guardar'),
          ),
        ],
      ),
    );
  }

  void _showVariationsDialog(List<dynamic> variations) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Variaciones'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: variations.map((v) {
            final m = Map<String, dynamic>.from(v as Map);
            return ListTile(
              title: Text(m['name'] ?? ''),
              trailing: Text('\$${m['price'] ?? 0}'),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditArticleDialog(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    final nameCtrl = TextEditingController(text: data['name'] as String?);
    final descCtrl = TextEditingController(
      text: data['description'] as String?,
    );
    String selectedLanguage = data['language'] as String? ?? 'Spanish';
    String? menuId = data['menu_id'] as String?;
    String? categoryName = data['category_name'] as String?;
    final prepCtrl = TextEditingController(
      text: data['prep_time']?.toString() ?? '0',
    );
    bool available = data['available'] as bool? ?? false;
    bool hasVariations = (data['variations'] as List?)?.isNotEmpty ?? false;
    final priceCtrl = TextEditingController(
      text: data['price']?.toString() ?? '',
    );
    List<Map<String, dynamic>> variations =
        (data['variations'] as List?)
            ?.map((v) => Map<String, dynamic>.from(v))
            .toList() ??
        [];

    String? imageUrl = data['imageUrl'] as String?;

    Future<void> pickImage() async {
      if (kIsWeb) {
        final input = html.FileUploadInputElement()..accept = 'image/*';
        input.click();
        await input.onChange.first;
        final file = input.files?.first;
        if (file == null) return;
        final reader = html.FileReader();
        reader.readAsDataUrl(file);
        await reader.onLoad.first;
        imageUrl = reader.result as String;
      } else {
        final picked = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          imageQuality: 75,
        );
        if (picked != null) imageUrl = picked.path;
      }
    }

    final mSnap = await FirebaseFirestore.instance
        .collection('negocios')
        .doc(businessId)
        .collection('menus')
        .orderBy('createdAt')
        .get();
    final menus = mSnap.docs;

    final cSnap = await FirebaseFirestore.instance
        .collection('negocios')
        .doc(businessId)
        .collection('categories')
        .orderBy('createdAt')
        .get();
    final categories = cSnap.docs;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) {
          return AlertDialog(
            scrollable: true,
            title: Text('Editar elemento de menú'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedLanguage,
                  decoration: const InputDecoration(labelText: 'Idioma'),
                  items: ['Spanish', 'English']
                      .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                      .toList(),
                  onChanged: (v) => setSt(() => selectedLanguage = v!),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Nombre ($selectedLanguage)',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descCtrl,
                  decoration: InputDecoration(
                    labelText: 'Descripción ($selectedLanguage)',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: menuId,
                  hint: const Text('Elegir menú'),
                  isExpanded: true,
                  items: menus
                      .map(
                        (m) => DropdownMenuItem(
                          value: m.id,
                          child: Text(m.data()['name'] ?? ''),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setSt(() => menuId = v),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: categoryName,
                  hint: const Text('Categoría de artículo'),
                  isExpanded: true,
                  items: categories
                      .map(
                        (c) => DropdownMenuItem(
                          value: c.data()['name'] as String?,
                          child: Text(c.data()['name'] ?? ''),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setSt(() => categoryName = v),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: pickImage,
                      child: const Text('Elegir imagen'),
                    ),
                    const SizedBox(width: 8),
                    if (imageUrl != null)
                      Expanded(child: Text(imageUrl!.split('/').last)),
                  ],
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: const Text('Tiene variaciones'),
                  value: hasVariations,
                  onChanged: (v) => setSt(() => hasVariations = v!),
                ),
                if (!hasVariations) ...[
                  TextField(
                    controller: priceCtrl,
                    decoration: const InputDecoration(labelText: 'Precio'),
                    keyboardType: TextInputType.number,
                  ),
                ] else ...[
                  Column(
                    children: variations.asMap().entries.map((e) {
                      final idx = e.key;
                      final vd = e.value;
                      final vn = TextEditingController(text: vd['name']);
                      final vp = TextEditingController(
                        text: vd['price']?.toString(),
                      );
                      return Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: vn,
                              decoration: const InputDecoration(
                                hintText: 'Nombre variación',
                              ),
                              onChanged: (v) => vd['name'] = v,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: vp,
                              decoration: const InputDecoration(
                                hintText: 'Precio',
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (v) =>
                                  vd['price'] = double.tryParse(v) ?? 0,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () =>
                                setSt(() => variations.removeAt(idx)),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                  TextButton(
                    onPressed: () =>
                        setSt(() => variations.add({'name': '', 'price': 0.0})),
                    child: const Text('Agregar variación'),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final newName = nameCtrl.text.trim();
                  final newDesc = descCtrl.text.trim();
                  final prep = int.tryParse(prepCtrl.text.trim()) ?? 0;
                  final price = double.tryParse(priceCtrl.text.trim());
                  if (newName.isEmpty ||
                      menuId == null ||
                      categoryName == null) {
                    return;
                  }

                  final menuDoc = menus.firstWhere((m) => m.id == menuId);
                  final menuName = menuDoc.data()['name'] as String? ?? '';

                  final docData = <String, dynamic>{
                    'business_id': businessId,
                    'menu_id': menuId,
                    'menu_name': menuName,
                    'category_name': categoryName,
                    'language': selectedLanguage,
                    'name': newName,
                    'description': newDesc,
                    'prep_time': prep,
                    'available': available,
                    'tags': data['tags'] ?? [],
                    'imageUrl': imageUrl,
                    'updatedAt': FieldValue.serverTimestamp(),
                  };
                  if (hasVariations) {
                    docData['variations'] = variations;
                  } else if (price != null) {
                    docData['price'] = price;
                  }

                  await doc.reference.update(docData);
                  Navigator.pop(context);
                },
                child: const Text('Actualizar'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoadingBusiness) {
      return Scaffold(
        appBar: AppBar(title: const Text('Menús')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Menús')),
        body: Center(child: Text(error!)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          // AppBar personalizado fijo
          Container(
            color: Colors.white,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    const Text(
                      'Menús',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: _showAddMenuDialog,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Agregar menú'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Búsqueda fija
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Busca tu menú aquí',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),

          // Grid de menús - Usando ValueListenableBuilder para evitar rebuilds
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _menusStream,
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 100,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final menus = snap.data?.docs ?? [];

                // Seleccionar primer menú sin setState
                if (!_firstMenuSelected && menus.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    selectedMenuIdNotifier.value = menus.first.id;
                    selectedMenuNameNotifier.value =
                        menus.first.data()['name'] ?? '';
                    _firstMenuSelected = true;
                  });
                }

                final filtered = menus.where((m) {
                  final n = (m.data()['name'] as String? ?? '').toLowerCase();
                  return n.contains(searchQuery);
                }).toList();

                return ValueListenableBuilder<String?>(
                  valueListenable: selectedMenuIdNotifier,
                  builder: (context, selectedMenuId, child) {
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount:
                            (MediaQuery.of(context).size.width ~/ 260).clamp(
                              1,
                              4,
                            ),
                        mainAxisExtent: 70,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final doc = filtered[i];
                        final data = doc.data();
                        final isSel = doc.id == selectedMenuId;
                        final name = data['name'] as String? ?? '';
                        final count = data['count'] as int? ?? 0;
                        return GestureDetector(
                          onTap: () {
                            // Solo actualizamos los ValueNotifier, no setState
                            selectedMenuIdNotifier.value = doc.id;
                            selectedMenuNameNotifier.value = name;
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSel ? Colors.blue : Colors.white,
                              border: Border.all(
                                color: isSel
                                    ? Colors.blue
                                    : Colors.grey.shade300,
                                width: isSel ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.restaurant_menu,
                                  size: 20,
                                  color: isSel
                                      ? Colors.white
                                      : Colors.grey.shade600,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: isSel
                                              ? Colors.white
                                              : Colors.black87,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$count Artículo${count != 1 ? 's' : ''}',
                                        style: TextStyle(
                                          color: isSel
                                              ? Colors.white70
                                              : Colors.grey.shade600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),

          // Header del menú seleccionado - FIJO usando ValueListenableBuilder
          ValueListenableBuilder<String?>(
            valueListenable: selectedMenuIdNotifier,
            builder: (context, selectedMenuId, child) {
              if (selectedMenuId == null) return const SizedBox.shrink();

              return ValueListenableBuilder<String>(
                valueListenable: selectedMenuNameNotifier,
                builder: (context, selectedMenuName, child) {
                  return Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Text(
                          selectedMenuName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final doc = await FirebaseFirestore.instance
                                .collection('negocios')
                                .doc(businessId)
                                .collection('menus')
                                .doc(selectedMenuId)
                                .get();
                            final data = doc.data()!;
                            _showUpdateMenuDialog(
                              selectedMenuId,
                              data['name'] as String,
                              data['language'] as String,
                            );
                          },
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Actualizar'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Confirmar'),
                                content: Text('¿Eliminar "$selectedMenuName"?'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancelar'),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                    ),
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Eliminar'),
                                  ),
                                ],
                              ),
                            );
                            if (ok == true) {
                              await FirebaseFirestore.instance
                                  .collection('negocios')
                                  .doc(businessId)
                                  .collection('menus')
                                  .doc(selectedMenuId)
                                  .delete();
                              selectedMenuIdNotifier.value = null;
                              selectedMenuNameNotifier.value = '';
                              _firstMenuSelected = false;
                            }
                          },
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.red,
                            size: 16,
                          ),
                          label: const Text(''),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),

          // Headers de la tabla - FIJO
          ValueListenableBuilder<String?>(
            valueListenable: selectedMenuIdNotifier,
            builder: (context, selectedMenuId, child) {
              if (selectedMenuId == null) return const SizedBox.shrink();

              return Container(
                color: Colors.grey.shade100,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    const Expanded(
                      flex: 4,
                      child: Text(
                        'ARTÍCULO',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    const Expanded(
                      flex: 2,
                      child: Text(
                        'PRECIO',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    const Expanded(
                      flex: 2,
                      child: Text(
                        'CATEGORÍA',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    const Expanded(
                      flex: 2,
                      child: Text(
                        'DISPONIBLE',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    const Expanded(
                      flex: 2,
                      child: Text(
                        'ACCIONES',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Lista de artículos - SCROLLEABLE
          Expanded(
            child: Container(
              color: Colors.white,
              child: ValueListenableBuilder<String?>(
                valueListenable: selectedMenuIdNotifier,
                builder: (context, selectedMenuId, child) {
                  if (selectedMenuId == null) {
                    return const Center(
                      child: Text(
                        'Selecciona un menú para ver sus artículos',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    );
                  }

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('negocios')
                        .doc(businessId)
                        .collection('menus')
                        .doc(selectedMenuId)
                        .collection('articles')
                        .orderBy('createdAt')
                        .snapshots(),
                    builder: (ctx, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final arts = snap.data?.docs ?? [];

                      // Actualizar count sin setState
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _updateMenuCount(selectedMenuId, arts.length);
                      });

                      if (arts.isEmpty) {
                        return const Center(
                          child: Text('No hay artículos en este menú'),
                        );
                      }

                      return ListView.separated(
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: Colors.grey.shade200),
                        itemCount: arts.length,
                        itemBuilder: (ctx, i) {
                          final doc = arts[i];
                          final d = doc.data();
                          final avail = d['available'] as bool? ?? false;
                          final hasVar =
                              (d['variations'] as List?)?.isNotEmpty == true;

                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Imagen + Nombre del artículo
                                Expanded(
                                  flex: 4,
                                  child: Row(
                                    children: [
                                      // Imagen más pequeña
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          color: Colors.grey.shade200,
                                        ),
                                        child: d['imageUrl'] != null
                                            ? ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                child: Image.network(
                                                  d['imageUrl'],
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) =>
                                                      Icon(
                                                        Icons.restaurant,
                                                        color: Colors
                                                            .grey
                                                            .shade400,
                                                        size: 20,
                                                      ),
                                                ),
                                              )
                                            : Icon(
                                                Icons.restaurant,
                                                color: Colors.grey.shade400,
                                                size: 20,
                                              ),
                                      ),
                                      const SizedBox(width: 12),
                                      // Información del artículo
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              d['name'] ?? 'Sin nombre',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w500,
                                                fontSize: 14,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (d['description'] != null &&
                                                d['description']
                                                    .toString()
                                                    .isNotEmpty)
                                              Text(
                                                d['description'],
                                                style: TextStyle(
                                                  color: Colors.grey.shade600,
                                                  fontSize: 12,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Precio
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    d['price'] != null
                                        ? '\$${d['price']}'
                                        : hasVar
                                        ? 'Varía'
                                        : '--',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                                // Categoría
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    d['category'] ??
                                        d['category_name'] ??
                                        'Sin categoría',
                                    style: const TextStyle(fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                // Disponible
                                Expanded(
                                  flex: 2,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Checkbox(
                                        value: avail,
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        visualDensity: VisualDensity.compact,
                                        onChanged: (v) => doc.reference.update({
                                          'available': v ?? false,
                                          'updatedAt':
                                              FieldValue.serverTimestamp(),
                                        }),
                                      ),
                                      Text(
                                        avail ? 'Sí' : 'No',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: avail
                                              ? Colors.green
                                              : Colors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Acciones
                                Expanded(
                                  flex: 2,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (hasVar)
                                        Tooltip(
                                          message: 'Ver variaciones',
                                          child: IconButton(
                                            icon: const Icon(
                                              Icons.list_alt,
                                              size: 18,
                                              color: Colors.blue,
                                            ),
                                            onPressed: () =>
                                                _showVariationsDialog(
                                                  d['variations']
                                                      as List<dynamic>,
                                                ),
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                        ),
                                      Tooltip(
                                        message: 'Editar',
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons.edit_outlined,
                                            size: 18,
                                            color: Colors.orange,
                                          ),
                                          onPressed: () =>
                                              _showEditArticleDialog(doc),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ),
                                      Tooltip(
                                        message: 'Eliminar',
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            size: 18,
                                            color: Colors.red,
                                          ),
                                          onPressed: () async {
                                            final ok = await showDialog<bool>(
                                              context: context,
                                              builder: (_) => AlertDialog(
                                                title: const Text('Confirmar'),
                                                content: const Text(
                                                  '¿Eliminar este artículo?',
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                          context,
                                                          false,
                                                        ),
                                                    child: const Text(
                                                      'Cancelar',
                                                    ),
                                                  ),
                                                  ElevatedButton(
                                                    style:
                                                        ElevatedButton.styleFrom(
                                                          backgroundColor:
                                                              Colors.red,
                                                        ),
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                          context,
                                                          true,
                                                        ),
                                                    child: const Text(
                                                      'Eliminar',
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (ok == true) {
                                              await doc.reference.delete();
                                            }
                                          },
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
