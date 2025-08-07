import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum ReservationStatus { pending, confirmed, cancelled }

extension ReservationStatusExt on ReservationStatus {
  String get label {
    switch (this) {
      case ReservationStatus.pending:
        return 'Pendiente';
      case ReservationStatus.confirmed:
        return 'Confirmado';
      case ReservationStatus.cancelled:
        return 'Cancelado';
    }
  }

  Color get color {
    switch (this) {
      case ReservationStatus.pending:
        return Colors.orange;
      case ReservationStatus.confirmed:
        return Colors.green;
      case ReservationStatus.cancelled:
        return Colors.red;
    }
  }
}

class Client {
  final String nombre, telefono, email;
  Client({required this.nombre, required this.telefono, required this.email});
  factory Client.fromMap(Map<String, dynamic> m) => Client(
    nombre: m['nombre'] as String? ?? '',
    telefono: m['telefono'] as String? ?? '',
    email: m['email'] as String? ?? '',
  );
}

class Reservation {
  final String id;
  final DateTime fecha;
  final int invitados;
  final String franja;
  final String? mesaId, mesaNombre, nota;
  final ReservationStatus status;
  final Client cliente;

  Reservation({
    required this.id,
    required this.fecha,
    required this.invitados,
    required this.franja,
    this.mesaId,
    this.mesaNombre,
    this.nota,
    required this.status,
    required this.cliente,
  });

  factory Reservation.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Reservation(
      id: doc.id,
      fecha: (d['fecha'] as Timestamp).toDate(),
      invitados: d['invitados'] as int,
      franja: d['franja'] as String? ?? '',
      mesaId: d['mesaId'] as String?,
      mesaNombre: d['mesaNombre'] as String?,
      nota: d['nota'] as String?,
      status: ReservationStatus.values.firstWhere(
        (s) => s.name == d['status'] as String?,
        orElse: () => ReservationStatus.pending,
      ),
      cliente: Client.fromMap(d['cliente'] as Map<String, dynamic>? ?? {}),
    );
  }
}

class ReservationCard extends StatelessWidget {
  final Reservation res;
  final VoidCallback onAssignTable;
  final ValueChanged<ReservationStatus> onStatusChanged;

  const ReservationCard({
    Key? key,
    required this.res,
    required this.onAssignTable,
    required this.onStatusChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dFmt = DateFormat('dd MMM, yyyy').format(res.fecha);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Invitados + Estado
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${res.invitados} Invitados',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: res.status.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: res.status.color.withOpacity(0.3)),
                ),
                child: Text(
                  res.status.label,
                  style: TextStyle(
                    fontSize: 11,
                    color: res.status.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Fecha y hora
          Row(
            children: [
              Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 6),
              Text(
                dFmt,
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
              const SizedBox(width: 12),
              Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 6),
              Text(
                res.franja,
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
            ],
          ),

          // Mesa (si está asignada)
          if (res.mesaNombre != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.table_restaurant, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                  'Mesa: ${res.mesaNombre}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 1),
          const SizedBox(height: 12),

          // Información del cliente
          Text(
            res.cliente.nombre,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Icon(Icons.email_outlined, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  res.cliente.email,
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          Row(
            children: [
              Icon(Icons.phone_outlined, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 6),
              Text(
                res.cliente.telefono,
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
            ],
          ),

          // Nota (si existe)
          if (res.nota?.isNotEmpty ?? false) ...[
            const SizedBox(height: 12),
            Text(
              'Nota:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              res.nota!,
              style: const TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Colors.black87,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const Spacer(),
          const SizedBox(height: 16),

          // Acciones
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 36,
                child: ElevatedButton(
                  onPressed: onAssignTable,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E88E5),
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    res.mesaId == null ? 'Asignar mesa' : 'Cambiar mesa',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 36,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<ReservationStatus>(
                    value: res.status,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    items: ReservationStatus.values
                        .map(
                          (s) => DropdownMenuItem(
                            value: s,
                            child: Text(
                              s.label,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (s) {
                      if (s != null) onStatusChanged(s);
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ReservationsScreen extends StatefulWidget {
  const ReservationsScreen({Key? key}) : super(key: key);
  @override
  State<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends State<ReservationsScreen> {
  String? _businessId;
  bool _loading = true;
  String? _error;

  String _period = 'Semana actual';
  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now().add(const Duration(days: 6));

  @override
  void initState() {
    super.initState();
    _loadBusiness();
    _applyPeriod();
  }

  Future<void> _loadBusiness() async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .get();
      _businessId = doc.data()?['negocio_id'] as String?;
      if (_businessId == null) throw 'Negocio no configurado';
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() => _loading = false);
    }
  }

  void _applyPeriod() {
    final now = DateTime.now();
    if (_period == 'Hoy') {
      _from = DateTime(now.year, now.month, now.day);
      _to = DateTime(now.year, now.month, now.day, 23, 59, 59);
    } else {
      final start = now.subtract(Duration(days: now.weekday - 1));
      _from = DateTime(start.year, start.month, start.day);
      _to = _from.add(
        const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
      );
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> get _reservationsStream {
    return FirebaseFirestore.instance
        .collection('negocios')
        .doc(_businessId)
        .collection('reservas')
        .where(
          'fecha',
          isGreaterThanOrEqualTo: Timestamp.fromDate(_from),
          isLessThanOrEqualTo: Timestamp.fromDate(_to),
        )
        .orderBy('fecha')
        .snapshots();
  }

  Future<void> _showNewReservationDialog() async {
    DateTime date = DateTime.now();
    int guests = 2;
    String meal = 'Cena';
    String? timeslot;
    final noteCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setStateDialog) => AlertDialog(
          title: const Text('Nueva reserva'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                ListTile(
                  title: Text(DateFormat.yMMMd().format(date)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx2,
                      initialDate: date,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (d != null) setStateDialog(() => date = d);
                  },
                ),
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(
                    labelText: 'Invitados',
                    prefixIcon: Icon(Icons.group),
                  ),
                  value: guests,
                  items: List.generate(20, (i) => i + 1)
                      .map(
                        (n) => DropdownMenuItem(
                          value: n,
                          child: Text('$n Invitados'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setStateDialog(() => guests = v!),
                ),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Comida',
                    prefixIcon: Icon(Icons.free_breakfast),
                  ),
                  value: meal,
                  items: ['Desayuno', 'Almuerzo', 'Cena']
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (v) => setStateDialog(() => meal = v!),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Selecciona franja horaria',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children:
                      [
                            '06:00 p.m.',
                            '07:00 p.m.',
                            '08:00 p.m.',
                            '09:00 p.m.',
                            '10:00 p.m.',
                          ]
                          .map(
                            (slot) => ChoiceChip(
                              label: Text(slot),
                              selected: timeslot == slot,
                              onSelected: (_) =>
                                  setStateDialog(() => timeslot = slot),
                            ),
                          )
                          .toList(),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(
                    labelText: '¿Alguna solicitud especial?',
                  ),
                ),
                const Divider(),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del cliente',
                  ),
                ),
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Teléfono'),
                  keyboardType: TextInputType.phone,
                ),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx2),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (timeslot == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Selecciona una franja horaria'),
                    ),
                  );
                  return;
                }
                await FirebaseFirestore.instance
                    .collection('negocios')
                    .doc(_businessId)
                    .collection('reservas')
                    .add({
                      'fecha': Timestamp.fromDate(date),
                      'invitados': guests,
                      'comida': meal,
                      'franja': timeslot,
                      'nota': noteCtrl.text.trim(),
                      'cliente': {
                        'nombre': nameCtrl.text.trim(),
                        'telefono': phoneCtrl.text.trim(),
                        'email': emailCtrl.text.trim(),
                      },
                      'status': ReservationStatus.pending.name,
                      'mesaId': null,
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                Navigator.pop(ctx2);
              },
              child: const Text('Reservar ahora'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAssignTableDialog(Reservation res) async {
    final fecha = res.fecha;
    final invitados = res.invitados;
    final zonasSnap = await FirebaseFirestore.instance
        .collection('negocios')
        .doc(_businessId)
        .collection('zonas')
        .orderBy('nombre')
        .get();
    final reservasSnap = await FirebaseFirestore.instance
        .collection('negocios')
        .doc(_businessId)
        .collection('reservas')
        .where('fecha', isEqualTo: Timestamp.fromDate(fecha))
        .get();
    final mesasReservadas = reservasSnap.docs
        .map((r) => r.data()['mesaId'] as String?)
        .whereType<String>()
        .toSet();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Mesas disponibles'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var z in zonasSnap.docs) ...[
                  Text(
                    z['nombre'] ?? 'Sin nombre',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    future: FirebaseFirestore.instance
                        .collection('negocios')
                        .doc(_businessId)
                        .collection('zonas')
                        .doc(z.id)
                        .collection('mesas')
                        .get(),
                    builder: (ctx, ms) {
                      if (!ms.hasData) return const CircularProgressIndicator();
                      final mesas = ms.data!.docs.where(
                        (m) => (m.data()['capacidad'] as int) >= invitados,
                      );
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: mesas.map((mDoc) {
                          final m = mDoc.data();
                          final blocked = mesasReservadas.contains(mDoc.id);
                          return ElevatedButton(
                            onPressed: blocked
                                ? null
                                : () async {
                                    await FirebaseFirestore.instance
                                        .collection('negocios')
                                        .doc(_businessId)
                                        .collection('reservas')
                                        .doc(res.id)
                                        .update({
                                          'mesaId': mDoc.id,
                                          'mesaNombre': m['nombre'],
                                          'status':
                                              ReservationStatus.confirmed.name,
                                        });
                                    Navigator.pop(context);
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: blocked
                                  ? Colors.grey.shade300
                                  : Colors.green.shade50,
                              foregroundColor: blocked
                                  ? Colors.grey
                                  : Colors.green.shade800,
                              padding: const EdgeInsets.all(8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  m['nombre'] ?? 'Mesa',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${m['capacidad']} Asiento(s)',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                if (blocked)
                                  const Text(
                                    'Reservada',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.red,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const Divider(height: 24),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Reservas'),
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            )
          : Column(
              children: [
                // Barra de filtros y acciones
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Selector de período
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _period,
                            items:
                                const ['Hoy', 'Semana actual', 'Personalizado']
                                    .map(
                                      (p) => DropdownMenuItem(
                                        value: p,
                                        child: Text(p),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (v) => setState(() {
                              _period = v!;
                              _applyPeriod();
                            }),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Rango de fechas
                      if (_period == 'Personalizado') ...[
                        InkWell(
                          onTap: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: _from,
                              firstDate: DateTime.now().subtract(
                                const Duration(days: 365),
                              ),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (d != null) setState(() => _from = d);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.calendar_today,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  DateFormat('dd/MM/yyyy').format(_from),
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            'a',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),

                        InkWell(
                          onTap: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: _to,
                              firstDate: DateTime.now().subtract(
                                const Duration(days: 365),
                              ),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (d != null) setState(() => _to = d);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.calendar_today,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  DateFormat('dd/MM/yyyy').format(_to),
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        // Mostrar rango de fechas actual
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            border: Border.all(color: Colors.blue[200]!),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                size: 16,
                                color: Colors.blue,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _period == 'Hoy'
                                    ? DateFormat('dd/MM/yyyy').format(_from)
                                    : '${DateFormat('dd/MM').format(_from)} - ${DateFormat('dd/MM/yyyy').format(_to)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const Spacer(),

                      // Botón Nueva Reserva
                      ElevatedButton.icon(
                        onPressed: _showNewReservationDialog,
                        icon: const Icon(Icons.add, size: 20),
                        label: const Text('Nueva Reserva'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E88E5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ],
                  ),
                ),

                if (_period == 'Personalizado') ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(DateFormat('dd/MM/yyyy').format(_from)),
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: _from,
                              firstDate: DateTime.now().subtract(
                                const Duration(days: 365),
                              ),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (d != null) setState(() => _from = d);
                          },
                        ),
                        const Text(
                          ' a ',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(DateFormat('dd/MM/yyyy').format(_to)),
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: _to,
                              firstDate: DateTime.now().subtract(
                                const Duration(days: 365),
                              ),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (d != null) setState(() => _to = d);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _reservationsStream,
                    builder: (ctx, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final docs = snap.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.event_busy,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No hay reservas',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          // Cálculo dinámico del número de columnas basado en el ancho
                          int crossAxisCount;
                          double cardWidth;

                          if (constraints.maxWidth > 1200) {
                            crossAxisCount = 4;
                            cardWidth =
                                (constraints.maxWidth - 80) /
                                4; // 4 columnas + padding
                          } else if (constraints.maxWidth > 900) {
                            crossAxisCount = 3;
                            cardWidth =
                                (constraints.maxWidth - 64) /
                                3; // 3 columnas + padding
                          } else if (constraints.maxWidth > 600) {
                            crossAxisCount = 2;
                            cardWidth =
                                (constraints.maxWidth - 48) /
                                2; // 2 columnas + padding
                          } else {
                            crossAxisCount = 1;
                            cardWidth =
                                constraints.maxWidth -
                                32; // 1 columna + padding
                          }

                          // Altura estimada basada en el contenido típico de una card
                          double estimatedHeight = 400; // Altura base
                          double childAspectRatio = cardWidth / estimatedHeight;

                          return GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  childAspectRatio: childAspectRatio,
                                ),
                            itemCount: docs.length,
                            itemBuilder: (ctx, i) {
                              final res = Reservation.fromDoc(docs[i]);
                              return ReservationCard(
                                res: res,
                                onAssignTable: () =>
                                    _showAssignTableDialog(res),
                                onStatusChanged: (s) {
                                  FirebaseFirestore.instance
                                      .collection('negocios')
                                      .doc(_businessId)
                                      .collection('reservas')
                                      .doc(res.id)
                                      .update({'status': s.name});
                                },
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
