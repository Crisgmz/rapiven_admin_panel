import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ClientesScreen extends StatefulWidget {
  const ClientesScreen({super.key});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  String? businessId;
  bool isLoading = true;
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
          isLoading = false;
        });
        return;
      }

      final globalUserDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();
      String? bizId;
      if (globalUserDoc.exists) {
        bizId = globalUserDoc.data()!['negocio_id'] as String?;
      }
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
      setState(() {
        businessId = bizId;
        isLoading = false;
      });
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
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text('Clientes'),
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
          title: const Text('Clientes'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        body: Center(child: Text(error!)),
      );
    }

    final clientsRef = FirebaseFirestore.instance
        .collection('negocios')
        .doc(businessId)
        .collection('clientes')
        .orderBy('createdAt', descending: true);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Clientes',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: clientsRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No hay clientes registrados'));
          }
          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final name = data['nombre'] ?? 'Sin nombre';
              final email = data['email'] ?? '';
              final phone = data['telefono'] ?? '';
              return ListTile(
                title: Text(name),
                subtitle: Text(email.isNotEmpty ? email : phone),
              );
            },
          );
        },
      ),
    );
  }
}

