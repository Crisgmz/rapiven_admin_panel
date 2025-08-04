import 'dart:io' show File;
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
// Para Flutter Web
import 'dart:html' as html;

class MenuItemsScreen extends StatefulWidget {
  const MenuItemsScreen({Key? key}) : super(key: key);

  @override
  State<MenuItemsScreen> createState() => _MenuItemsScreenState();
}

class _MenuItemsScreenState extends State<MenuItemsScreen> {
  String? businessId;
  bool isLoadingBusiness = true;
  String? error;

  // Búsqueda y filtros
  String searchQuery = '';
  bool showFilters = false;
  String? filterMenuId;
  String? filterCategoryName;

  // Listas con tipado
  List<QueryDocumentSnapshot<Map<String, dynamic>>> menus = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> categories = [];

  // Paginación
  int currentPage = 1;
  final int itemsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _loadBusinessForCurrentUser();
    if (businessId != null) {
      await _loadMenusAndCategories();
    }
  }

  Future<void> _loadBusinessForCurrentUser() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          error = 'Usuario no autenticado';
          isLoadingBusiness = false;
        });
        return;
      }

      // 1) Intentar leer negocio_id desde perfil global
      final globalUser = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();
      String? bizId = globalUser.data()?['negocio_id'] as String?;

      // 2) Fallback: buscar por owner_uid
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
          isLoadingBusiness = false;
        });
      } else {
        setState(() {
          businessId = bizId;
          isLoadingBusiness = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Error cargando negocio: $e';
        isLoadingBusiness = false;
      });
    }
  }

  Future<void> _loadMenusAndCategories() async {
    final bizRef = FirebaseFirestore.instance
        .collection('negocios')
        .doc(businessId);
    final mSnap = await bizRef.collection('menus').orderBy('createdAt').get();
    final cSnap = await bizRef
        .collection('categories')
        .orderBy('createdAt')
        .get();
    setState(() {
      menus = mSnap.docs;
      categories = cSnap.docs;
    });
  }

  /// Ahora traemos TODOS los artículos y filtramos en cliente
  Stream<QuerySnapshot<Map<String, dynamic>>> _itemsStream() {
    return FirebaseFirestore.instance.collectionGroup('articles').snapshots();
  }

  Widget _buildStatusChip(bool available) {
    if (!available) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade300),
        ),
        child: Text(
          'Inactivo',
          style: TextStyle(
            color: Colors.red.shade700,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildVariationsButton(List variations) {
    if (variations.isNotEmpty) {
      return TextButton.icon(
        onPressed: () => _showVariationsDialog(variations),
        icon: const Icon(Icons.list_alt, size: 16),
        label: const Text('Variaciones'),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
    }
    return const SizedBox.shrink();
  }

  void _showVariationsDialog(List variations) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Variaciones'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: variations.map((v) {
            return ListTile(
              title: Text(v['name'] ?? ''),
              trailing: Text('\$${v['price'] ?? 0}'),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoadingBusiness) {
      return Scaffold(
        appBar: AppBar(title: const Text('Elementos del menú')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Elementos del menú')),
        body: Center(child: Text(error!)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Elementos del menú',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 24),

            // Barra de búsqueda, filtros y "Agregar"
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Busca tu elemento del menú aquí',
                        prefixIcon: Icon(Icons.search, color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onChanged: (q) => setState(() {
                        searchQuery = q.toLowerCase();
                        currentPage = 1;
                      }),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                TextButton.icon(
                  onPressed: () => setState(() => showFilters = !showFilters),
                  icon: const Icon(Icons.filter_list),
                  label: const Text('Mostrar filtros'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => _showAddOrEditDialog(context, null),
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar elemento de menú'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),

            // Filtros
            if (showFilters) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: filterMenuId,
                        hint: const Text('Filtrar por menú'),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: menus
                            .map(
                              (m) => DropdownMenuItem(
                                value: m.id,
                                child: Text(m.data()['name'] ?? ''),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() {
                          filterMenuId = v;
                          currentPage = 1;
                        }),
                        isExpanded: true,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: filterCategoryName,
                        hint: const Text('Filtrar por categoría'),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: categories
                            .map(
                              (c) => DropdownMenuItem(
                                value: c.data()['name'] as String?,
                                child: Text(c.data()['name'] ?? ''),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() {
                          filterCategoryName = v;
                          currentPage = 1;
                        }),
                        isExpanded: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Tabla con paginación
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      child: const Row(
                        children: [
                          SizedBox(width: 60),
                          Expanded(
                            flex: 3,
                            child: Text(
                              'NOMBRE DEL ARTÍCULO',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              'PRECIO',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'CATEGORÍA',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'MENÚ',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              'DISPONIBLE',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'ACCIÓN',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Cuerpo
                    Expanded(
                      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _itemsStream(),
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          // 1) Filtrar
                          final docs = snap.data?.docs ?? [];
                          final filtered = docs.where((d) {
                            final data = d.data();
                            final name =
                                (data['name'] as String?)?.toLowerCase() ?? '';
                            final mSearch = name.contains(searchQuery);
                            final mMenu =
                                filterMenuId == null ||
                                data['menu_id'] == filterMenuId;
                            final mCat =
                                filterCategoryName == null ||
                                data['category_name'] == filterCategoryName;
                            return mSearch && mMenu && mCat;
                          }).toList();

                          // 2) Calcular paginación
                          final totalItems = filtered.length;
                          final totalPages = (totalItems / itemsPerPage).ceil();
                          // Asegurar currentPage válido
                          if (currentPage > totalPages && totalPages > 0) {
                            currentPage = totalPages;
                          }
                          final start = (currentPage - 1) * itemsPerPage;
                          final pageItems = filtered
                              .skip(start)
                              .take(itemsPerPage)
                              .toList();

                          if (pageItems.isEmpty) {
                            return const Center(
                              child: Text(
                                'No hay elementos',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            );
                          }

                          return ListView.builder(
                            itemCount: pageItems.length,
                            itemBuilder: (context, i) {
                              final doc = pageItems[i];
                              final data = doc.data();
                              final available =
                                  data['available'] as bool? ?? false;
                              final variations =
                                  data['variations'] as List? ?? [];

                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Imagen
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        color: Colors.grey.shade100,
                                      ),
                                      child: data['imageUrl'] != null
                                          ? ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: kIsWeb
                                                  ? Image.network(
                                                      data['imageUrl']
                                                          as String,
                                                      fit: BoxFit.cover,
                                                    )
                                                  : Image.file(
                                                      File(
                                                        data['imageUrl']
                                                            as String,
                                                      ),
                                                      fit: BoxFit.cover,
                                                    ),
                                            )
                                          : const Icon(
                                              Icons.restaurant_menu,
                                              color: Colors.grey,
                                              size: 24,
                                            ),
                                    ),
                                    const SizedBox(width: 20),

                                    // Nombre + status
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                width: 8,
                                                height: 8,
                                                decoration: BoxDecoration(
                                                  color: available
                                                      ? Colors.green
                                                      : Colors.red,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Flexible(
                                                child: Text(
                                                  data['name'] ?? '',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              _buildStatusChip(available),
                                            ],
                                          ),
                                          if ((data['description'] as String?)
                                                  ?.isNotEmpty ??
                                              false)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 4,
                                                left: 16,
                                              ),
                                              child: Text(
                                                data['description'] as String,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),

                                    // Precio
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        variations.isNotEmpty
                                            ? '--'
                                            : (data['price'] != null
                                                  ? '\$${data['price']}'
                                                  : '--'),
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ),

                                    // Categoría
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        data['category_name'] as String? ?? '',
                                      ),
                                    ),

                                    // Menu
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        data['menu_name'] as String? ?? '',
                                      ),
                                    ),

                                    // Disponible checkbox
                                    Expanded(
                                      flex: 1,
                                      child: Checkbox(
                                        value: available,
                                        onChanged: (v) => doc.reference.update({
                                          'available': v ?? false,
                                          'updatedAt':
                                              FieldValue.serverTimestamp(),
                                        }),
                                      ),
                                    ),

                                    // Acciones
                                    Expanded(
                                      flex: 2,
                                      child: Row(
                                        children: [
                                          _buildVariationsButton(variations),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.edit_outlined,
                                            ),
                                            tooltip: 'Actualizar',
                                            onPressed: () =>
                                                _showAddOrEditDialog(
                                                  context,
                                                  doc,
                                                ),
                                            constraints: const BoxConstraints(
                                              minWidth: 32,
                                              minHeight: 32,
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              color: Colors.red,
                                            ),
                                            tooltip: 'Eliminar',
                                            onPressed: () async {
                                              final confirm = await showDialog<bool>(
                                                context: context,
                                                builder: (context) => AlertDialog(
                                                  title: const Text(
                                                    'Confirmar eliminación',
                                                  ),
                                                  content: const Text(
                                                    '¿Seguro que quieres eliminar este elemento?',
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
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                            context,
                                                            true,
                                                          ),
                                                      style:
                                                          ElevatedButton.styleFrom(
                                                            backgroundColor:
                                                                Colors.red,
                                                          ),
                                                      child: const Text(
                                                        'Eliminar',
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                              if (confirm == true) {
                                                await doc.reference.delete();
                                              }
                                            },
                                            constraints: const BoxConstraints(
                                              minWidth: 32,
                                              minHeight: 32,
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
                      ),
                    ),

                    // Paginación
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _itemsStream(),
                        builder: (context, snap) {
                          final docs = snap.data?.docs ?? [];
                          final filtered = docs.where((d) {
                            final name =
                                (d.data()['name'] as String?)?.toLowerCase() ??
                                '';
                            final mSearch = name.contains(searchQuery);
                            final mMenu =
                                filterMenuId == null ||
                                d.data()['menu_id'] == filterMenuId;
                            final mCat =
                                filterCategoryName == null ||
                                d.data()['category_name'] == filterCategoryName;
                            return mSearch && mMenu && mCat;
                          }).toList();

                          final totalItems = filtered.length;
                          final totalPages = (totalItems / itemsPerPage).ceil();

                          // slice para este page
                          final start = (currentPage - 1) * itemsPerPage;
                          final end = start + itemsPerPage;
                          final pageItems = filtered.sublist(
                            start,
                            end > totalItems ? totalItems : end,
                          );

                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Mostrando ${start + 1} a ${end > totalItems ? totalItems : end} de $totalItems Resultados',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: currentPage > 1
                                        ? () => setState(() => currentPage--)
                                        : null,
                                    icon: const Icon(Icons.chevron_left),
                                  ),
                                  ...List.generate(
                                    totalPages > 5 ? 5 : totalPages,
                                    (index) {
                                      int pageNum;
                                      if (totalPages <= 5) {
                                        pageNum = index + 1;
                                      } else {
                                        if (currentPage <= 3) {
                                          pageNum = index + 1;
                                        } else if (currentPage >=
                                            totalPages - 2) {
                                          pageNum = totalPages - 4 + index;
                                        } else {
                                          pageNum = currentPage - 2 + index;
                                        }
                                      }
                                      return Container(
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 2,
                                        ),
                                        child: Material(
                                          color: pageNum == currentPage
                                              ? Colors.blue.shade600
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            onTap: () => setState(
                                              () => currentPage = pageNum,
                                            ),
                                            child: Container(
                                              width: 32,
                                              height: 32,
                                              alignment: Alignment.center,
                                              child: Text(
                                                pageNum.toString(),
                                                style: TextStyle(
                                                  color: pageNum == currentPage
                                                      ? Colors.white
                                                      : Colors.grey.shade700,
                                                  fontWeight:
                                                      pageNum == currentPage
                                                      ? FontWeight.w600
                                                      : FontWeight.normal,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    onPressed: currentPage < totalPages
                                        ? () => setState(() => currentPage++)
                                        : null,
                                    icon: const Icon(Icons.chevron_right),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
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
  }

  Future<void> _showAddOrEditDialog(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>>? doc,
  ) async {
    final isEdit = doc != null;
    final data = doc?.data() ?? {};

    String selectedLanguage = data['language'] as String? ?? 'Spanish';
    final nameCtrl = TextEditingController(text: data['name'] as String?);
    final descCtrl = TextEditingController(
      text: data['description'] as String?,
    );
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

    final tagOptions = [
      'Vegetariano',
      'No vegetariano',
      'Contiene huevo',
      'Bebida',
      'Otro',
    ];
    final selectedTags = <String>{
      if (data['tags'] is List) ...List<String>.from(data['tags']),
    };

    String? imageUrl = data['imageUrl'] as String?;

    Future<void> _pickImage() async {
      if (kIsWeb) {
        // Flutter Web: usar input HTML
        final input = html.FileUploadInputElement()..accept = 'image/*';
        input.click();
        await input.onChange.first;
        final file = input.files?.first;
        if (file == null) return;
        final reader = html.FileReader();
        reader.readAsDataUrl(file);
        await reader.onLoad.first;
        setState(() {
          imageUrl = reader.result as String; // Data URL
        });
      } else {
        // Móviles: image_picker
        final picked = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          imageQuality: 75,
        );
        if (picked != null) {
          setState(() {
            imageUrl = picked.path;
          });
        }
      }
    }

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(
              isEdit ? 'Editar elemento de menú' : 'Agregar elemento de menú',
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedLanguage,
                    decoration: const InputDecoration(
                      labelText: 'Seleccionar idioma',
                    ),
                    items: ['Spanish', 'English']
                        .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                        .toList(),
                    onChanged: (v) => setState(() => selectedLanguage = v!),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Nombre del artículo ($selectedLanguage)',
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
                    items: menus
                        .map(
                          (m) => DropdownMenuItem(
                            value: m.id,
                            child: Text(m.data()['name'] ?? ''),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => menuId = v),
                    isExpanded: true,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: categoryName,
                    hint: const Text('Categoría de artículo'),
                    items: categories
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.data()['name'] as String?,
                            child: Text(c.data()['name'] ?? ''),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => categoryName = v),
                    isExpanded: true,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: tagOptions.map((t) {
                      final sel = selectedTags.contains(t);
                      return FilterChip(
                        label: Text(t),
                        selected: sel,
                        onSelected: (_) => setState(
                          () => sel
                              ? selectedTags.remove(t)
                              : selectedTags.add(t),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: prepCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Tiempo preparación (min)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<bool>(
                    value: available,
                    decoration: const InputDecoration(
                      labelText: 'Está disponible',
                    ),
                    items: const [
                      DropdownMenuItem(value: false, child: Text('No')),
                      DropdownMenuItem(value: true, child: Text('Sí')),
                    ],
                    onChanged: (v) => setState(() => available = v!),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: _pickImage,
                        child: const Text('Elegir imagen'),
                      ),
                      const SizedBox(width: 8),
                      if (imageUrl != null)
                        Expanded(
                          child: Text(
                            imageUrl!.split('/').last,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    title: const Text('Tiene variaciones'),
                    value: hasVariations,
                    onChanged: (v) =>
                        setState(() => hasVariations = v ?? false),
                  ),
                  if (!hasVariations) ...[
                    TextField(
                      controller: priceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Precio'),
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
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  hintText: 'Precio',
                                ),
                                onChanged: (v) =>
                                    vd['price'] = double.tryParse(v) ?? 0,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () =>
                                  setState(() => variations.removeAt(idx)),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                    TextButton(
                      onPressed: () => setState(
                        () => variations.add({'name': '', 'price': 0.0}),
                      ),
                      child: const Text('Agregar variación'),
                    ),
                  ],
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
                  final desc = descCtrl.text.trim();
                  final prep = int.tryParse(prepCtrl.text.trim()) ?? 0;
                  final price = double.tryParse(priceCtrl.text.trim());
                  if (name.isEmpty || menuId == null || categoryName == null)
                    return;

                  // extraer menu_name con casteo seguro
                  final menuDoc = menus.firstWhere((m) => m.id == menuId);
                  final menuName = menuDoc.data()['name'] as String? ?? '';

                  final docData = <String, dynamic>{
                    'business_id': businessId,
                    'menu_id': menuId,
                    'menu_name': menuName,
                    'category_name': categoryName,
                    'language': selectedLanguage,
                    'name': name,
                    'description': desc,
                    'tags': selectedTags.toList(),
                    'prep_time': prep,
                    'available': available,
                    'imageUrl': imageUrl,
                    'updatedAt': FieldValue.serverTimestamp(),
                  };
                  if (hasVariations) {
                    docData['variations'] = variations;
                  } else if (price != null) {
                    docData['price'] = price;
                  }

                  final bizMenus = FirebaseFirestore.instance
                      .collection('negocios')
                      .doc(businessId)
                      .collection('menus')
                      .doc(menuId);

                  if (isEdit) {
                    await doc!.reference.update(docData);
                  } else {
                    docData['createdAt'] = FieldValue.serverTimestamp();
                    await bizMenus.collection('articles').add(docData);
                  }
                  Navigator.pop(context);
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
