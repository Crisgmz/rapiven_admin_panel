import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ArticleModifiersScreen extends StatefulWidget {
  const ArticleModifiersScreen({super.key});

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
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text('Modificadores de artículo'),
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
          title: const Text('Modificadores de artículo'),
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
          'Modificadores de artículo',
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
                'Agregar modificador de artículo',
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
                  return const Center(
                    child: Text(
                      'No hay modificadores asignados',
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
                                'NOMBRE DEL ARTÍCULO',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[600],
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'GRUPO DE MODIFICADORES',
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
                                'OBLIGATORIO',
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
                              width: 120,
                              child: Text(
                                'PERMITE SELECCIÓN MÚLTIPLE',
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
                            final d = filtered[i];
                            final data = d.data();

                            final art = articles.firstWhere(
                              (a) => a.id == data['article_id'],
                            );
                            final grp = groups.firstWhere(
                              (g) => g.id == data['group_id'],
                            );
                            final mandatory =
                                data['mandatory'] as bool? ?? false;
                            final multiple = data['multiple'] as bool? ?? false;

                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      art.data()['name'] ?? '',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      grp.data()['name'] ?? '',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 100,
                                    child: Center(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: mandatory
                                              ? Colors.red[50]
                                              : Colors.grey[100],
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: mandatory
                                                ? Colors.red[200]!
                                                : Colors.grey[300]!,
                                          ),
                                        ),
                                        child: Text(
                                          mandatory
                                              ? 'Obligatorio'
                                              : 'Opcional',
                                          style: TextStyle(
                                            color: mandatory
                                                ? Colors.red[700]
                                                : Colors.grey[600],
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 120,
                                    child: Center(
                                      child: Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color: multiple
                                              ? Colors.green[600]
                                              : Colors.grey[300],
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: multiple
                                            ? const Icon(
                                                Icons.check,
                                                color: Colors.white,
                                                size: 16,
                                              )
                                            : null,
                                      ),
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
    final data = doc.data();
    final art = articles.firstWhere((a) => a.id == data['article_id']);
    final grp = groups.firstWhere((g) => g.id == data['group_id']);

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text(
          '¿Estás seguro de que deseas eliminar el modificador de "${art.data()['name']}" con el grupo "${grp.data()['name']}"?',
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
    if (ok == true) await doc.reference.delete();
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
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Elemento del menú',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedArticleId,
                  hint: const Text('Seleccionar elemento del menú'),
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
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Grupo de modificadores',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedGroupId,
                  hint: const Text('Seleccionar grupo de modificadores'),
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
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Configuración',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  title: const Text('Permitir selección múltiple'),
                  subtitle: const Text(
                    'Los usuarios pueden seleccionar varias opciones',
                  ),
                  value: multiple,
                  onChanged: (v) => setState(() => multiple = v ?? false),
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  title: const Text('Obligatorio'),
                  subtitle: const Text(
                    'Los usuarios deben seleccionar al menos una opción',
                  ),
                  value: mandatory,
                  onChanged: (v) => setState(() => mandatory = v ?? false),
                  contentPadding: EdgeInsets.zero,
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
                if (selectedArticleId == null || selectedGroupId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Por favor selecciona tanto el artículo como el grupo',
                      ),
                    ),
                  );
                  return;
                }
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
                  await doc.reference.update(payload);
                } else {
                  payload['createdAt'] = FieldValue.serverTimestamp();
                  await ref.add(payload);
                }
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isEdit
                          ? 'Modificador actualizado exitosamente'
                          : 'Modificador creado exitosamente',
                    ),
                  ),
                );
              },
              child: Text(isEdit ? 'Actualizar' : 'Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
