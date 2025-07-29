import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  String? selectedMenuId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menús'),
        actions: [
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
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
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
                            .collection('articles')
                            .where('menuId', isEqualTo: selectedMenuId)
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
                              child: Text('No hay artículos en este menú'),
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
              if (name.isNotEmpty) {
                await FirebaseFirestore.instance.collection('menus').add({
                  'name': name,
                  'language': selectedLanguage,
                  'createdAt': FieldValue.serverTimestamp(),
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
