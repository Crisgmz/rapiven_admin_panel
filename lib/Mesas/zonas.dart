import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ZonesScreen extends StatefulWidget {
  const ZonesScreen({Key? key}) : super(key: key);

  @override
  State<ZonesScreen> createState() => _ZonesScreenState();
}

class _ZonesScreenState extends State<ZonesScreen> {
  String? _businessId;
  bool _isLoading = true;
  String? _error;

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
          _error = 'Usuario no autenticado';
          _isLoading = false;
        });
        return;
      }

      // Leer businessId desde perfil global del usuario
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();

      if (!doc.exists || doc.data()?['negocio_id'] == null) {
        setState(() {
          _error = 'No se encontró el negocio para este usuario';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _businessId = doc.data()!['negocio_id'] as String;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error cargando negocio: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _addZone(String name) {
    final ref = FirebaseFirestore.instance
        .collection('negocios')
        .doc(_businessId)
        .collection('zonas');

    return ref.add({
      'nombre': name,
      'numeroMesas': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _updateZone(String zoneId, String newName) {
    final ref = FirebaseFirestore.instance
        .collection('negocios')
        .doc(_businessId)
        .collection('zonas')
        .doc(zoneId);

    return ref.update({'nombre': newName});
  }

  Future<void> _deleteZone(String zoneId) {
    final ref = FirebaseFirestore.instance
        .collection('negocios')
        .doc(_businessId)
        .collection('zonas')
        .doc(zoneId);

    return ref.delete();
  }

  void _showAddDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Agregar zona'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Nombre de la zona',
            hintText: 'Ej., Terraza',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                await _addZone(name);
                Navigator.of(context).pop();
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(String zoneId, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Editar zona'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Nombre de la zona'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != currentName) {
                await _updateZone(zoneId, newName);
                Navigator.of(context).pop();
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Todas las áreas')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Todas las áreas')),
        body: Center(child: Text(_error!)),
      );
    }

    final zonesRef = FirebaseFirestore.instance
        .collection('negocios')
        .doc(_businessId)
        .collection('zonas')
        .orderBy('createdAt');

    return Scaffold(
      appBar: AppBar(title: const Text('Todas las áreas')),
      body: StreamBuilder<QuerySnapshot>(
        stream: zonesRef.snapshots(),
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No hay zonas aún.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) {
              final d = docs[i];
              final nombre = d['nombre'] as String;
              final mesas = d['numeroMesas'] as int? ?? 0;
              return Card(
                elevation: 1,
                child: ListTile(
                  title: Text(nombre),
                  subtitle: Text('Número de mesas: $mesas'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _showEditDialog(d.id, nombre),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        onPressed: () => _deleteZone(d.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        label: const Text('Agregar zona'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
