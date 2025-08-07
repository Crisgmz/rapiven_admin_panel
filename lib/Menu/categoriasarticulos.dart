import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ArticleCategoriesScreen extends StatefulWidget {
  const ArticleCategoriesScreen({super.key});

  @override
  State<ArticleCategoriesScreen> createState() =>
      _ArticleCategoriesScreenState();
}

class _ArticleCategoriesScreenState extends State<ArticleCategoriesScreen> {
  String? businessId;
  bool isLoading = true;
  String? error;
  String searchQuery = '';

  // Lista de menús para iterar luego en el contador
  List<QueryDocumentSnapshot<Map<String, dynamic>>> menus = [];

  @override
  void initState() {
    super.initState();
    _loadBusinessForCurrentUser();
  }

  Future<void> _loadBusinessForCurrentUser() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          error = 'Usuario no autenticado';
          isLoading = false;
        });
        return;
      }

      // 1) Leer negocio_id desde perfil global
      final globalUserDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();

      String? bizId;
      if (globalUserDoc.exists) {
        bizId = globalUserDoc.data()!['negocio_id'] as String?;
      }

      // 2) Fallback por owner_uid si no hubo negocio_id
      if (bizId == null) {
        final q = await FirebaseFirestore.instance
            .collection('negocios')
            .where('owner_uid', isEqualTo: user.uid)
            .where('activo', isEqualTo: true)
            .limit(1)
            .get();
        if (q.docs.isNotEmpty) bizId = q.docs.first.id;
      }

      if (bizId == null) {
        setState(() {
          error = 'No se encontró un negocio activo para este usuario';
          isLoading = false;
        });
        return;
      }

      // Guardar businessId y cargar menús
      setState(() {
        businessId = bizId;
        isLoading = false;
      });
      await _loadMenus();
    } catch (e) {
      setState(() {
        error = 'Error cargando negocio: $e';
        isLoading = false;
      });
    }
  }

  /// Carga todos los menús de negocios/{businessId}/menus
  Future<void> _loadMenus() async {
    final snap = await FirebaseFirestore.instance
        .collection('negocios')
        .doc(businessId)
        .collection('menus')
        .get();
    setState(() {
      menus = snap.docs;
    });
  }

  /// Recorre cada menú y cuenta cuántos artículos tienen esta categoría
  Future<int> _countArticles(String categoryName) async {
    if (businessId == null) return 0;
    var total = 0;
    for (final m in menus) {
      final q = await FirebaseFirestore.instance
          .collection('negocios')
          .doc(businessId)
          .collection('menus')
          .doc(m.id)
          .collection('articles')
          .where('category_name', isEqualTo: categoryName)
          .get();
      total += q.size;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text('Categorías de artículos'),
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
          title: const Text('Categorías de artículos'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        body: Center(child: Text(error!)),
      );
    }

    final categoriesRef = FirebaseFirestore.instance
        .collection('negocios')
        .doc(businessId)
        .collection('categories')
        .orderBy('createdAt');

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Categorías de artículos',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            child: ElevatedButton.icon(
              onPressed: () => _showAddCategoryDialog(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text(
                'Agregar categoría de artículo',
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
                hintText: 'Busca tu categoría de elemento aquí',
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
              onChanged: (q) =>
                  setState(() => searchQuery = q.trim().toLowerCase()),
            ),
          ),
          // Content
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: categoriesRef.snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data?.docs ?? [];
                final filtered = docs.where((d) {
                  final name = (d.data()['name'] as String).toLowerCase();
                  return name.contains(searchQuery);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text(
                      'No hay categorías',
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
                              child: Text(
                                'CATEGORÍA DE ARTÍCULOS',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[600],
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 120,
                              child: Text(
                                'ELEMENTOS DEL MENÚ',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[600],
                                  letterSpacing: 0.5,
                                ),
                                textAlign: TextAlign.center,
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
                            final doc = filtered[i];
                            final data = doc.data();
                            final categoryName = data['name'] as String;
                            final language = data['language'] as String;

                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      categoryName,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 120,
                                    child: FutureBuilder<int>(
                                      future: _countArticles(categoryName),
                                      builder: (ctx, asSnap) {
                                        final cnt = asSnap.data ?? 0;
                                        return Text(
                                          '$cnt Artículo(s)',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.black54,
                                          ),
                                          textAlign: TextAlign.center,
                                        );
                                      },
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
                                              _showEditCategoryDialog(
                                                context,
                                                doc.id,
                                                data,
                                              ),
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
                                                doc.id,
                                                categoryName,
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
    String docId,
    String categoryName,
  ) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text(
          '¿Estás seguro de que deseas eliminar la categoría "$categoryName"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('negocios')
                  .doc(businessId)
                  .collection('categories')
                  .doc(docId)
                  .delete();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context) {
    final nameController = TextEditingController();
    String selectedLanguage = 'Spanish';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Categoría de artículo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: selectedLanguage,
              items: ['Spanish', 'English']
                  .map(
                    (lang) => DropdownMenuItem(value: lang, child: Text(lang)),
                  )
                  .toList(),
              onChanged: (v) => selectedLanguage = v!,
              decoration: const InputDecoration(
                labelText: 'Seleccionar idioma',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                hintText: 'Ej., Postres',
                labelText: 'Nombre de la categoría de artículo',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty || businessId == null) return;
              await FirebaseFirestore.instance
                  .collection('negocios')
                  .doc(businessId)
                  .collection('categories')
                  .add({
                    'name': name,
                    'language': selectedLanguage,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
              Navigator.pop(context);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showEditCategoryDialog(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
  ) {
    final nameController = TextEditingController(text: data['name']);
    String selectedLanguage = data['language'];

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Actualizar categoría'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: selectedLanguage,
              items: ['Spanish', 'English']
                  .map(
                    (lang) => DropdownMenuItem(value: lang, child: Text(lang)),
                  )
                  .toList(),
              onChanged: (v) => selectedLanguage = v!,
              decoration: const InputDecoration(
                labelText: 'Seleccionar idioma',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                hintText: 'Ej., Postres',
                labelText: 'Nombre de la categoría de artículo',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty || businessId == null) return;
              await FirebaseFirestore.instance
                  .collection('negocios')
                  .doc(businessId)
                  .collection('categories')
                  .doc(docId)
                  .update({
                    'name': name,
                    'language': selectedLanguage,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
              Navigator.pop(context);
            },
            child: const Text('Actualizar'),
          ),
        ],
      ),
    );
  }
}
