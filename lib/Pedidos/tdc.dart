import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TdcScreen extends StatefulWidget {
  const TdcScreen({super.key});

  @override
  State<TdcScreen> createState() => _TdcScreenState();
}

class _TdcScreenState extends State<TdcScreen> {
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
        debugPrint('[TDC] Error: Usuario no autenticado');
        return;
      }

      final globalUserDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();

      String? bizId;
      if (globalUserDoc.exists) {
        final val = globalUserDoc.data();
        bizId = val?['negocio_id'] as String?;
        debugPrint('[TDC] negocio_id desde usuarios: $bizId');
      }

      if (bizId == null) {
        final q = await FirebaseFirestore.instance
            .collection('negocios')
            .where('owner_uid', isEqualTo: user.uid)
            .where('activo', isEqualTo: true)
            .limit(1)
            .get();

        if (q.docs.isNotEmpty) {
          bizId = q.docs.first.id;
          debugPrint('[TDC] negocio_id por fallback en negocios: $bizId');
        }
      }

      if (bizId == null) {
        setState(() {
          error = 'No se encontró un negocio activo para este usuario';
          isLoading = false;
        });
        debugPrint(
          '[TDC] Error: No se encontró negocio activo para ${user.uid}',
        );
        return;
      }

      setState(() {
        businessId = bizId;
        isLoading = false;
      });
    } catch (e, st) {
      setState(() {
        error = 'Error cargando negocio: $e';
        isLoading = false;
      });
      debugPrint('[TDC] Excepción cargando negocio: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text('TDC'),
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
          title: const Text('TDC'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        body: Center(child: Text(error!)),
      );
    }

    final baseQuery = FirebaseFirestore.instance
        .collection('negocios')
        .doc(businessId)
        .collection('pedidos')
        .where('estado', isEqualTo: 'cocina')
        .orderBy('createdAt', descending: true);

    // Log de la consulta
    debugPrint(
      '[TDC] Suscribiendo a pedidos de cocina para negocio: $businessId',
    );

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Tiempo de cocina',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        // Manejo de errores del stream para imprimir en consola
        stream: baseQuery.snapshots().handleError((e, st) {
          debugPrint('[TDC] Error en stream de pedidos: $e');
          debugPrintStack(stackTrace: st);
        }),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            debugPrint('[TDC] snapshot.hasError: ${snapshot.error}');
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];
          debugPrint('[TDC] Pedidos recibidos: ${docs.length}');

          if (docs.isEmpty) {
            return const Center(child: Text('No hay pedidos en cocina'));
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final numero = data['numero']?.toString() ?? 'Sin número';
              final estado = data['estado'] ?? '';
              final createdAt = data['createdAt'];
              debugPrint(
                '[TDC] Pedido idx=$index numero=$numero estado=$estado createdAt=$createdAt',
              );

              return ListTile(
                title: Text('Pedido $numero'),
                subtitle: Text('Estado: $estado'),
                onTap: () {
                  // Útil para depurar un documento específico
                  debugPrint(
                    '[TDC] Tap en pedido $numero -> ${docs[index].id}',
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
