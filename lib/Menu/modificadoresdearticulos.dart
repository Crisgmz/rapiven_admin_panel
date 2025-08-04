import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ArticleModifiersScreen extends StatefulWidget {
  const ArticleModifiersScreen({Key? key}) : super(key: key);

  @override
  State<ArticleModifiersScreen> createState() => _ArticleModifiersScreenState();
}

class _ArticleModifiersScreenState extends State<ArticleModifiersScreen> {
  String? businessId;
  bool isLoading = true;
  String? error;

  String searchQuery = '';

  // En memoria: todos los artículos y todos los grupos
  List<QueryDocumentSnapshot<Map<String, dynamic>>> articles = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> groups = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw 'Usuario no autenticado';

      // 1) Leer businessId de perfil global
      final userDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();
      String? biz = userDoc.data()?['negocio_id'] as String?;

      // 2) Fallback: buscar por owner_uid
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

      // 3) Cargar artículos del negocio
      final artSnap = await FirebaseFirestore.instance
          .collectionGroup('articles')
          .get();
      articles = artSnap.docs.where((d) {
        final data = d.data();
        return data['business_id'] == businessId;
      }).toList();

      // 4) Cargar grupos de modificadores
      final grpSnap = await FirebaseFirestore.instance
          .collection('negocios')
          .doc(businessId)
          .collection('modifierGroups')
          .orderBy('createdAt')
          .get();
      groups = grpSnap.docs;

      setState(() => isLoading = false);
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> get _modStream {
    return FirebaseFirestore.instance
        .collection('negocios')
        .doc(businessId)
        .collection('articleModifiers')
        .orderBy('createdAt')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Modificadores de artículo')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Modificadores de artículo')),
        body: Center(child: Text(error!)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modificadores de artículo'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Busca tu grupo o artículo aquí',
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
        actions: [
          TextButton.icon(
            onPressed: () => _showAddOrEditDialog(context, null),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              'Agregar modificador',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _modStream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data?.docs ?? [];
          final filtered = docs.where((d) {
            final data = d.data();

            // artículo
            final artMatches = articles
                .where((a) => a.id == data['article_id'])
                .toList();
            final artName = artMatches.isNotEmpty
                ? (artMatches.first.data()['name'] as String? ?? '')
                      .toLowerCase()
                : '';

            // grupo
            final grpMatches = groups
                .where((g) => g.id == data['group_id'])
                .toList();
            final grpName = grpMatches.isNotEmpty
                ? (grpMatches.first.data()['name'] as String? ?? '')
                      .toLowerCase()
                : '';

            return artName.contains(searchQuery) ||
                grpName.contains(searchQuery);
          }).toList();

          if (filtered.isEmpty) {
            return const Center(child: Text('No hay modificadores asignados'));
          }

          return ListView.separated(
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final d = filtered[i];
              final data = d.data();

              final art = articles.firstWhere(
                (a) => a.id == data['article_id'],
              );
              final grp = groups.firstWhere((g) => g.id == data['group_id']);
              final mandatory = data['mandatory'] as bool? ?? false;
              final multiple = data['multiple'] as bool? ?? false;

              return ListTile(
                title: Text(art.data()['name'] ?? ''),
                subtitle: Text(grp.data()['name'] ?? ''),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: mandatory
                            ? Colors.red.shade100
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        mandatory ? 'Obligatorio' : 'Opcional',
                        style: TextStyle(
                          color: mandatory
                              ? Colors.red.shade700
                              : Colors.grey.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: multiple
                            ? Colors.green.shade100
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        multiple ? 'Sí' : 'No',
                        style: TextStyle(
                          color: multiple
                              ? Colors.green.shade700
                              : Colors.grey.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _showAddOrEditDialog(context, d),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Confirmar'),
                            content: const Text('Eliminar este modificador?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancelar'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                child: const Text('Eliminar'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) await d.reference.delete();
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
    final data = doc?.data() ?? {};

    String? selectedArticleId = data['article_id'] as String?;
    String? selectedGroupId = data['group_id'] as String?;
    bool multiple = data['multiple'] as bool? ?? false;
    bool mandatory = data['mandatory'] as bool? ?? false;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            isEdit
                ? 'Actualizar modificador'
                : 'Agregar modificador de artículo',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedArticleId,
                hint: const Text('Nombre del elemento del menú'),
                items: articles
                    .map(
                      (a) => DropdownMenuItem(
                        value: a.id,
                        child: Text(a.data()['name'] ?? ''),
                      ),
                    )
                    .toList(),
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
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedGroupId,
                hint: const Text('Grupo de modificadores'),
                items: groups
                    .map(
                      (g) => DropdownMenuItem(
                        value: g.id,
                        child: Text(g.data()['name'] ?? ''),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => selectedGroupId = v),
                isExpanded: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                title: const Text('Permitir selección múltiple'),
                value: multiple,
                onChanged: (v) => setState(() => multiple = v ?? false),
              ),
              CheckboxListTile(
                title: const Text('Obligatorio'),
                value: mandatory,
                onChanged: (v) => setState(() => mandatory = v ?? false),
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
                if (selectedArticleId == null || selectedGroupId == null)
                  return;
                final payload = {
                  'article_id': selectedArticleId,
                  'group_id': selectedGroupId,
                  'multiple': multiple,
                  'mandatory': mandatory,
                  'updatedAt': FieldValue.serverTimestamp(),
                };
                final ref = FirebaseFirestore.instance
                    .collection('negocios')
                    .doc(businessId)
                    .collection('articleModifiers');
                if (isEdit) {
                  await doc!.reference.update(payload);
                } else {
                  payload['createdAt'] = FieldValue.serverTimestamp();
                  await ref.add(payload);
                }
                Navigator.pop(context);
              },
              child: Text(isEdit ? 'Actualizar' : 'Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
