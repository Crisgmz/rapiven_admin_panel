import 'package:flutter/material.dart';

class EstadisticasScreen extends StatefulWidget {
  const EstadisticasScreen({super.key});

  @override
  State<EstadisticasScreen> createState() => _EstadisticasScreenState();
}

class _EstadisticasScreenState extends State<EstadisticasScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Estadísticas',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        elevation: 1,
        shadowColor: Colors.grey.withOpacity(0.1),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Métricas principales
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Estadísticas de hoy',
                    '\$0',
                    'Ventas promedio diario',
                    Icons.trending_up,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildStatCard(
                    'Pedidos de hoy',
                    '0',
                    'Desde ayer',
                    Icons.receipt,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Métricas adicionales
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Ventas promedio (global)',
                    '\$325',
                    'Promedio de los últimos 7 días',
                    Icons.attach_money,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildStatCard(
                    'Total vendido (hoy)',
                    '\$9,177',
                    'Venta total del día',
                    Icons.shopping_cart,
                    Colors.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),

            // Gráfico de ventas
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Tendencia de Ventas',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Últimos 7 días',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Gráfico simulado
                  SizedBox(
                    height: 250,
                    child: CustomPaint(
                      size: const Size.fromHeight(250),
                      painter: SalesChartPainter(),
                    ),
                  ),

                  const SizedBox(height: 15),

                  // Leyenda del gráfico
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildChartLegend('22 jul', false),
                      _buildChartLegend('23 jul', false),
                      _buildChartLegend('24 jul', false),
                      _buildChartLegend('25 jul', false),
                      _buildChartLegend('26 jul', true),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Estadísticas adicionales
            Row(
              children: [
                Expanded(
                  child: _buildInfoCard(
                    'Método de pago (hoy)',
                    'No se encontró ningún pago',
                    Icons.payment,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildInfoCard(
                    'Plato más vendido (hoy)',
                    'No se encontró ningún pago',
                    Icons.restaurant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: _buildInfoCard(
                    'Mesa más vendida (hoy)',
                    'No se encontró ningún pago',
                    Icons.table_bar,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Container(), // Espacio vacío para mantener la simetría
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Icon(Icons.more_vert, color: Colors.grey[400], size: 20),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String message, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.grey[600], size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildChartLegend(String date, bool isToday) {
    return Text(
      date,
      style: TextStyle(
        color: isToday ? Colors.blue : Colors.grey[500],
        fontSize: 12,
        fontWeight: isToday ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }
}

class SalesChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.blue.withOpacity(0.3),
          Colors.blue.withOpacity(0.1),
          Colors.blue.withOpacity(0.05),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    // Puntos de datos para simular la curva de crecimiento
    final points = [
      Offset(0, size.height * 0.9),
      Offset(size.width * 0.2, size.height * 0.85),
      Offset(size.width * 0.4, size.height * 0.8),
      Offset(size.width * 0.6, size.height * 0.6),
      Offset(size.width * 0.8, size.height * 0.3),
      Offset(size.width, size.height * 0.1),
    ];

    // Crear el path para la línea
    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);

    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final current = points[i];
      final controlPoint1 = Offset(
        prev.dx + (current.dx - prev.dx) * 0.5,
        prev.dy,
      );
      final controlPoint2 = Offset(
        current.dx - (current.dx - prev.dx) * 0.5,
        current.dy,
      );
      path.cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        current.dx,
        current.dy,
      );
    }

    // Crear el path para el área rellena
    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    // Dibujar el área rellena
    canvas.drawPath(fillPath, fillPaint);

    // Dibujar la línea
    canvas.drawPath(path, paint);

    // Dibujar puntos en la línea
    final pointPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    for (final point in points) {
      canvas.drawCircle(point, 4, pointPaint);
      canvas.drawCircle(
        point,
        4,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        point,
        2,
        Paint()
          ..color = Colors.blue
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
