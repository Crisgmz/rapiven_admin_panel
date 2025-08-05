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

      // Leer negocio_id desde perfil global
      final globalUserDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();

      String? bizId;
      if (globalUserDoc.exists) {
        final data = globalUserDoc.data()!;
        bizId = data['negocio_id'] as String?;
      }

      // Si no hay negocio_id o no está activo, buscar por owner_uid
      if (bizId == null) {
        final q = await FirebaseFirestore.instance
            .collection('negocios')
            .where('owner_uid', isEqualTo: user.uid)
            .where('activo', isEqualTo: true)
            .limit(1)
            .get();
        if (q.docs.isNotEmpty) {
          bizId = q.docs.first.id;
        }
      }

      if (bizId == null) {
        setState(() {
          error = 'No se encontró un negocio activo para este usuario';
          isLoading = false;
        });
      } else {
        setState(() {
          businessId = bizId;
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Error cargando negocio: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Categorías de artículos')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Categorías de artículos')),
        body: Center(child: Text(error!)),
      );
    }

    final categoriesRef = FirebaseFirestore.instance
        .collection('negocios')
        .doc(businessId)
        .collection('categories')
        .orderBy('createdAt');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categorías de artículos'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Busca tu categoría de elemento aquí',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (q) =>
                  setState(() => searchQuery = q.trim().toLowerCase()),
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _showAddCategoryDialog(context),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              'Agregar categoría',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: categoriesRef.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          final filtered = docs.where((d) {
            final name = (d['name'] as String).toLowerCase();
            return name.contains(searchQuery);
          }).toList();

          if (filtered.isEmpty) {
            return const Center(child: Text('No hay categorías'));
          }

          return ListView.separated(
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final doc = filtered[i];
              final data = doc.data() as Map<String, dynamic>;
              final categoryName = data['name'] as String;
              final language = data['language'] as String;
              // contar artículos que usan esta categoría
              final countArticles = FirebaseFirestore.instance
                  .collectionGroup('articles')
                  .where('category', isEqualTo: categoryName)
                  // opcional: .where('business_id', isEqualTo: businessId)
                  .snapshots()
                  .map((q) => q.size);

              return ListTile(
                title: Text(categoryName),
                subtitle: Text(language),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StreamBuilder<int>(
                      stream: countArticles,
                      builder: (ctx, as) {
                        final cnt = as.data ?? 0;
                        return Text('$cnt Artículo(s)');
                      },
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () =>
                          _showEditCategoryDialog(context, doc.id, data),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => FirebaseFirestore.instance
                          .collection('negocios')
                          .doc(businessId)
                          .collection('categories')
                          .doc(doc.id)
                          .delete(),
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
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                hintText: 'Ej., Postres',
                labelText: 'Nombre de la categoría de artículo',
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
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                hintText: 'Ej., Postres',
                labelText: 'Nombre de la categoría de artículo',
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
