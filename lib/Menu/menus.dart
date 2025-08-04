import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  String? selectedMenuId;
  String? businessId;
  bool isLoadingBusiness = true;
  String? error;

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
          isLoadingBusiness = false;
        });
        return;
      }

      String? bizId;

      // 1. Intentar obtener negocio_id desde el perfil global del usuario
      final globalUserDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();

      if (globalUserDoc.exists) {
        final data = globalUserDoc.data() as Map<String, dynamic>;
        if (data['negocio_id'] != null &&
            (data['negocio_id'] as String).isNotEmpty) {
          final candidate = data['negocio_id'] as String;
          final bizDoc = await FirebaseFirestore.instance
              .collection('negocios')
              .doc(candidate)
              .get();
          if (bizDoc.exists && (bizDoc.data()?['activo'] == true)) {
            bizId = candidate;
          }
        }
      }

      // 2. Fallback: buscar por owner_uid si no se resolvió antes
      if (bizId == null) {
        final bizQuery = await FirebaseFirestore.instance
            .collection('negocios')
            .where('owner_uid', isEqualTo: user.uid)
            .where('activo', isEqualTo: true)
            .limit(1)
            .get();

        if (bizQuery.docs.isNotEmpty) {
          bizId = bizQuery.docs.first.id;
        }
      }

      if (bizId == null) {
        setState(() {
          error = 'No se encontró un negocio activo para este usuario';
          isLoadingBusiness = false;
        });
        return;
      }

      setState(() {
        businessId = bizId;
        isLoadingBusiness = false;
      });
    } catch (e) {
      setState(() {
        error = 'Error cargando negocio: $e';
        isLoadingBusiness = false;
      });
    }
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
      appBar: AppBar(
        title: const Text('Menús'),
        actions: [
          if (businessId != null)
            TextButton.icon(
              onPressed: () => showAddMenuDialog(context),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Agregar menú',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: businessId == null
          ? const Center(child: Text('No hay negocio asociado'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('negocios')
                  .doc(businessId)
                  .collection('menus')
                  .orderBy('createdAt')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final menus = snapshot.data?.docs ?? [];

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: menus.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final isSelected = doc.id == selectedMenuId;
                          return ChoiceChip(
                            label: Text(data['name'] ?? 'Sin nombre'),
                            selected: isSelected,
                            onSelected: (_) {
                              setState(() {
                                selectedMenuId = doc.id;
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                    const Divider(),
                    Expanded(
                      child: selectedMenuId == null
                          ? const Center(
                              child: Text(
                                'Selecciona un menú para ver sus artículos',
                              ),
                            )
                          : StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('negocios')
                                  .doc(businessId)
                                  .collection('menus')
                                  .doc(selectedMenuId)
                                  .collection('articles')
                                  .snapshots(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }

                                final articles = snapshot.data?.docs ?? [];

                                if (articles.isEmpty) {
                                  return const Center(
                                    child: Text(
                                      'No hay artículos en este menú',
                                    ),
                                  );
                                }

                                return ListView.builder(
                                  itemCount: articles.length,
                                  itemBuilder: (context, index) {
                                    final data =
                                        articles[index].data()
                                            as Map<String, dynamic>;
                                    return ListTile(
                                      leading: data['imageUrl'] != null
                                          ? Image.network(
                                              data['imageUrl'],
                                              width: 50,
                                              height: 50,
                                              fit: BoxFit.cover,
                                            )
                                          : const Icon(Icons.fastfood),
                                      title: Text(data['name'] ?? 'Sin nombre'),
                                      subtitle: Text(data['category'] ?? ''),
                                      trailing: Text(
                                        data['price'] != null
                                            ? '\$${data['price']}'
                                            : '--',
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  void showAddMenuDialog(BuildContext context) {
    final nameController = TextEditingController();
    String selectedLanguage = 'Spanish';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AGREGAR MENÚ'),
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
              onChanged: (value) => selectedLanguage = value!,
              decoration: const InputDecoration(labelText: 'Idioma'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(hintText: 'Ej. Desayuno'),
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
                  .collection('menus')
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
}
