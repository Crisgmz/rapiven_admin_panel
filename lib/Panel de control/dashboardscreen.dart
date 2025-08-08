import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rapiven_admin_panel/Clientes/clientes.dart';
import 'package:rapiven_admin_panel/Menu/categoriasarticulos.dart';
import 'package:rapiven_admin_panel/Menu/elementosdemenu.dart';
import 'package:rapiven_admin_panel/Menu/grupodemoficadores.dart';
import 'package:rapiven_admin_panel/Menu/menus.dart';
import 'package:rapiven_admin_panel/Menu/modificadoresdearticulos.dart';
import 'package:rapiven_admin_panel/Mesas/mesas.dart';
import 'package:rapiven_admin_panel/Mesas/zonas.dart';
import 'package:rapiven_admin_panel/Panel%20de%20control/estadisticasscreen.dart';
import 'package:rapiven_admin_panel/Pedidos/pedidos.dart';
import 'package:rapiven_admin_panel/Pedidos/tdc.dart';
import 'package:rapiven_admin_panel/Punto%20de%20Venta%20(TPV)/puntodeventa.dart';
import 'package:rapiven_admin_panel/Reservas/reservas.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool isCollapsed = false;
  bool isFullScreen = false;
  String selectedMenuItem = 'Panel de control'; // Agregar control de selección

  // Control de submenús expandidos
  Map<String, bool> expandedMenus = {
    'menu': false,
    'mesas': false,
    'pedidos': false,
    'pagos': false,
    'informes': false,
    'inventario': false,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isCollapsed ? 70 : 250,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(2, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  height: 80,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.icecream,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      if (!isCollapsed)
                        const Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(left: 12),
                            child: Text(
                              'RAPIVEN',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: isCollapsed
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.end,
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () =>
                              setState(() => isCollapsed = !isCollapsed),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              isCollapsed
                                  ? Icons.keyboard_arrow_right
                                  : Icons.keyboard_arrow_left,
                              color: Colors.grey[600],
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      _buildDrawerItem(
                        Icons.dashboard,
                        'Panel de control',
                        isSelected: selectedMenuItem == 'Panel de control',
                        onTap: () => _selectMenuItem('Panel de control'),
                      ),
                      // Menú con submenús
                      _buildExpandableDrawerItem(
                        Icons.restaurant_menu,
                        'Menú',
                        'menu',
                        [
                          'Menús',
                          'Elementos de menú',
                          'Categorías de artículos',
                          'Grupos de modificadores',
                          'Modificadores de artículo',
                        ],
                      ),
                      // Mesas con submenús
                      _buildExpandableDrawerItem(
                        Icons.table_bar,
                        'Mesas',
                        'mesas',
                        ['Zonas', 'Mesas', 'Códigos QR'],
                      ),
                      _buildDrawerItem(
                        Icons.support_agent,
                        'Solicitudes de mesero',
                        onTap: () => _selectMenuItem('Solicitudes de mesero'),
                      ),
                      _buildDrawerItem(
                        Icons.event,
                        'Reservas',
                        onTap: () => _selectMenuItem('Reservas'),
                      ),
                      _buildDrawerItem(
                        Icons.point_of_sale,
                        'Punto de Venta',
                        onTap: () => _selectMenuItem('Punto de Venta'),
                      ),
                      // Pedidos con submenús
                      _buildExpandableDrawerItem(
                        Icons.receipt,
                        'Pedidos',
                        'pedidos',
                        ['TDC', 'Pedidos'],
                      ),
                      _buildDrawerItem(
                        Icons.people,
                        'Clientes',
                        onTap: () => _selectMenuItem('Clientes'),
                      ),
                      _buildDrawerItem(
                        Icons.person,
                        'Personal',
                        onTap: () => _selectMenuItem('Personal'),
                      ),
                      _buildDrawerItem(
                        Icons.delivery_dining,
                        'Repartidor',
                        onTap: () => _selectMenuItem('Repartidor'),
                      ),
                      // Pagos con submenús
                      _buildExpandableDrawerItem(
                        Icons.payment,
                        'Pagos',
                        'pagos',
                        ['Pagos', 'Pagos pendientes'],
                      ),
                      // Informes con submenús
                      _buildExpandableDrawerItem(
                        Icons.bar_chart,
                        'Informes',
                        'informes',
                        [
                          'Informe de ventas',
                          'Informe de artículos',
                          'Informe de categorías',
                        ],
                      ),
                      // Inventario con submenús
                      _buildExpandableDrawerItem(
                        Icons.inventory,
                        'Inventario',
                        'inventario',
                        [
                          'Panel de Control',
                          'Unidades',
                          'Ítems de Inventario',
                          'Categorías de Ítems de Inventario',
                          'Existencias de Inventario',
                          'Movimientos de Inventario',
                          'Recetas',
                          'Órdenes de Compra',
                          'Proveedores',
                          'Reportes',
                          'Configuraciones',
                        ],
                      ),
                      _buildDrawerItem(
                        Icons.settings,
                        'Configuración',
                        onTap: () => _selectMenuItem('Configuración'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Builder(
              builder: (context) {
                switch (selectedMenuItem) {
                  case 'Panel de control':
                    return const EstadisticasScreen();
                  case 'Menús':
                    return const MenuScreen();
                  case 'Elementos de menú':
                    return const MenuItemsScreen();
                  case 'Categorías de artículos':
                    return const ArticleCategoriesScreen();
                  case 'Grupos de modificadores':
                    return const ModifierGroupsScreen();
                  case 'Modificadores de artículo':
                    return const ArticleModifiersScreen();
                  case 'Zonas':
                    return const ZonesScreen();
                  case 'Mesas':
                    return const TablesScreen();
                  case 'Reservas':
                    return const ReservationsScreen();
                  case 'Punto de Venta':
                    return const PuntoVentaScreen();
                  case 'Clientes':
                    return const ClientesScreen();
                  case 'TDC':
                    return const TdcScreen();
                  case 'Pedidos':
                    return const PedidosScreen();
                  // Puedes agregar más pantallas aquí
                  default:
                    return Padding(
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: Text(
                          'Contenido del Dashboard - $selectedMenuItem',
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                    );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  void _selectMenuItem(String menuItem) {
    setState(() {
      selectedMenuItem = menuItem;
    });
  }

  Widget _buildDrawerItem(
    IconData icon,
    String label, {
    bool isSelected = false,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap ?? () {},
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? Colors.grey[800] : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? Colors.white : Colors.grey[600],
                ),
                if (!isCollapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey[700],
                        fontSize: 14,
                        fontWeight: isSelected
                            ? FontWeight.w500
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandableDrawerItem(
    IconData icon,
    String label,
    String menuKey,
    List<String> subItems,
  ) {
    bool isExpanded = expandedMenus[menuKey] ?? false;

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                if (!isCollapsed) {
                  setState(() {
                    expandedMenus[menuKey] = !isExpanded;
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(icon, size: 20, color: Colors.grey[600]),
                    if (!isCollapsed) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 14,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ),
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_down
                            : Icons.keyboard_arrow_right,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        if (!isCollapsed && isExpanded)
          ...subItems.map((subItem) => _buildSubMenuItem(subItem)),
      ],
    );
  }

  Widget _buildSubMenuItem(String label) {
    return Container(
      margin: const EdgeInsets.only(left: 20, right: 8, top: 2, bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () {
            setState(() {
              selectedMenuItem = label;
            });
          },

          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildTopButton('Pedidos de hoy', 1, () {
            print('Pedidos de hoy');
          }),
          const SizedBox(width: 12),
          _buildTopButton('Nuevas reservas', 0, () {
            print('Nuevas reservas');
          }),
          const SizedBox(width: 12),
          _buildTopButton('Nueva solicitud de camarero', 3, () {
            print('Nueva solicitud de camarero');
          }),
          const Spacer(),
          _buildIconButton(Icons.language),
          const SizedBox(width: 8),
          _buildIconButton(
            isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
            onTap: _toggleFullScreen,
          ),
          const SizedBox(width: 8),
          _buildIconButton(Icons.dark_mode),
          const SizedBox(width: 12),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {},
              child: const CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey,
                child: Text(
                  'D',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon, {VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap ?? () {},
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 20, color: Colors.grey[600]),
        ),
      ),
    );
  }

  void _toggleFullScreen() {
    setState(() {
      isFullScreen = !isFullScreen;
    });

    if (isFullScreen) {
      // Entrar en pantalla completa
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      // Salir de pantalla completa
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  Widget _buildTopButton(String label, int count, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.blue.shade300, width: 1),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.1),
                spreadRadius: 0,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: count > 0 ? Colors.blue : Colors.grey[400],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
