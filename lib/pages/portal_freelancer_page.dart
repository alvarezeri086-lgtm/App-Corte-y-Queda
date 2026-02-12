import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import '../providers/notification_provider.dart';
import '../models/notification_model.dart';
import 'package:provider/provider.dart';
import '../auth_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/error_handler.dart';

class FreelancerDashboardPage extends StatefulWidget {
  @override
  _FreelancerDashboardPageState createState() =>
      _FreelancerDashboardPageState();
}

class _FreelancerDashboardPageState extends State<FreelancerDashboardPage> {
  bool _isLoading = true;
  String _errorMessage = '';
  Map<String, dynamic> _dashboardData = {
    'total_events': 0,
    'acceptance_rate': 0,
    'profile_completion': 0,
    'active_events': 0,
    'finished_events': 0,
  };
  List<Map<String, dynamic>> _upcomingEvents = [];
  List<Map<String, dynamic>> _myEvents = [];
  bool _showNotifications = false;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final baseUrl = dotenv.env['API_BASE_URL'];
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.accessToken;

    if (token == null || baseUrl == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Sesión no válida';
      });
      return;
    }

    try {
      final dashboardResponse = await http.get(
        Uri.parse('$baseUrl/dashboard/freelancer'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('La conexión ha excedido el tiempo de espera');
        },
      );

      if (dashboardResponse.statusCode == 200) {
        final data = jsonDecode(dashboardResponse.body);
        
        // Mapear los KPIs correctamente según la estructura real del API
        if (data.containsKey('kpis') && data['kpis'] is Map) {
          final kpis = data['kpis'] as Map<String, dynamic>;
          
          setState(() {
            _dashboardData = {
              'total_events': kpis['total_events'] ?? 0,
              'acceptance_rate': ((kpis['acceptance_rate'] ?? 0.0) * 100).round(),
              'profile_completion': kpis['profile_completion'] ?? 0,
              'active_events': kpis['active_events'] ?? 0,
              'finished_events': kpis['finished_events'] ?? 0,
            };
          });
        }

        // Procesar upcoming_events (puede estar vacío)
        if (data.containsKey('upcoming_events') && data['upcoming_events'] is List) {
          final events = data['upcoming_events'] as List;
          setState(() {
            _upcomingEvents = events.map<Map<String, dynamic>>((event) {
              return {
                'id': event['id']?.toString() ?? '',
                'title': event['title']?.toString() ?? 'Sin título',
                'start_date': event['start_date']?.toString(),
                'end_date': event['end_date']?.toString(),
                'location': event['location']?.toString() ?? 'Sin ubicación',
                'status': event['status']?.toString() ?? 'ACTIVE',
              };
            }).toList();
          });
        }

        // Procesar my_events (eventos propios del freelancer)
        if (data.containsKey('my_events') && data['my_events'] is List) {
          final events = data['my_events'] as List;
          setState(() {
            _myEvents = events.map<Map<String, dynamic>>((event) {
              return {
                'id': event['event_id']?.toString() ?? '',
                'title': event['name']?.toString() ?? 'Sin título',
                'start_date': event['start_date']?.toString(),
                'end_date': event['end_date']?.toString(),
                'location': event['location']?.toString() ?? 'Sin ubicación',
                'status': event['status']?.toString() ?? 'ACTIVO',
                'role': event['role']?.toString() ?? '',
              };
            }).toList();
          });
        }

        setState(() => _isLoading = false);
      } else if (dashboardResponse.statusCode == 401) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Sesión expirada. Por favor, inicia sesión nuevamente.';
        });
        await authProvider.logout();
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = ApiErrorHandler.handleHttpError(null, statusCode: dashboardResponse.statusCode);
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = ApiErrorHandler.handleHttpError(e);
      });
    }
  }

  Future<void> _logout() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF161B22),
        title: Text('Cerrar sesión', style: TextStyle(color: Colors.white)),
        content: Text(
          '¿Estás seguro de que quieres cerrar sesión?',
          style: TextStyle(color: Colors.grey[400]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey[400])),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Cerrar sesión', style: TextStyle(color: Colors.red[400])),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final storage = FlutterSecureStorage();
      await storage.deleteAll();
      await authProvider.logout();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    }
  }

  Widget _buildSidebar() {
    return Container(
      width: 240,
      color: Color(0xFF161B22),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.blue[600],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(Icons.connect_without_contact, color: Colors.white, size: 20),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Corte y Queda',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold)),
                        Text('FREELANCER',
                            style: TextStyle(color: Colors.grey[600], fontSize: 9)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: Colors.grey[800], height: 1),
            SizedBox(height: 20),

            _buildMenuItem(Icons.dashboard_outlined, 'Panel', true, () {
              Navigator.pushNamed(context, '/freelancer_dashboard');
            }),
            _buildMenuItem(Icons.flash_on_outlined, 'Activaciones', false, () {
              Navigator.pushNamed(context, '/freelancer_activations');
            }),
            _buildMenuItem(Icons.person_outline, 'Mi Perfil', false, () {
              Navigator.pushNamed(context, '/profile');
            }),

            Spacer(),

            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[800]!, width: 1)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _logout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[900]!.withOpacity(0.2),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    side: BorderSide(color: Colors.red[700]!),
                    elevation: 0,
                  ),
                  icon: Icon(Icons.logout, color: Colors.red[400], size: 16),
                  label: Text(
                    'Cerrar Sesión',
                    style: TextStyle(color: Colors.red[400], fontSize: 13),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, bool isActive, VoidCallback onTap) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? Color(0xFF1F6FEB).withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: isActive
            ? Border.all(color: Color(0xFF1F6FEB).withOpacity(0.4), width: 1)
            : null,
      ),
      child: ListTile(
        dense: true,
        leading: Icon(icon,
            color: isActive ? Colors.blue[400] : Colors.grey[500], size: 20),
        title: Text(title,
            style: TextStyle(
                color: isActive ? Colors.blue[300] : Colors.grey[400],
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w500 : FontWeight.normal)),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        onTap: onTap,
      ),
    );
  }

  Widget _buildUrgentBanner() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[900]!.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[400]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red[900]!.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.red[400]!, width: 1),
            ),
            child: Text('ALTA PRIORIDAD',
                style: TextStyle(
                    color: Colors.red[400],
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
          ),
          SizedBox(height: 12),
          Text('Actividades Urgentes',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('No tienes actividades urgentes por el momento.',
              style: TextStyle(color: Colors.grey[400], fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, dynamic value, String subtitle, Color color) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Ajustar tamaños según el ancho disponible
        final isVerySmall = constraints.maxWidth < 140;
        final fontSize = isVerySmall ? 20.0 : 24.0;
        final titleFontSize = isVerySmall ? 11.0 : 12.0;
        final subtitleFontSize = isVerySmall ? 9.0 : 10.0;
        
        return Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Color(0xFF161B22),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Color(0xFF30363D), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value.toString(),
                  style: TextStyle(
                    color: color,
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    height: 1.0,
                  ),
                ),
              ),
              SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey[300],
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: subtitleFontSize,
                  height: 1.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    final status = event['status']?.toString() ?? 'ACTIVO';
    final isActive = status == 'ACTIVO';
    final statusColor = isActive ? Colors.green[400]! : Colors.grey[400]!;

    String dayText = '--';
    String monthText = '---';
    if (event['start_date'] != null) {
      try {
        final dt = DateTime.parse(event['start_date']);
        final months = [
          'ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN',
          'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC'
        ];
        dayText = dt.day.toString();
        monthText = months[dt.month - 1];
      } catch (e) {}
    }

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isSmall = constraints.maxWidth < 400;
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En pantallas pequeñas, fecha arriba
              if (isSmall) ...[
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.blue[900]!.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[400]!, width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(dayText,
                          style: TextStyle(
                              color: Colors.blue[400],
                              fontSize: 14,
                              fontWeight: FontWeight.bold)),
                      SizedBox(width: 6),
                      Text(monthText,
                          style: TextStyle(color: Colors.blue[300], fontSize: 12)),
                    ],
                  ),
                ),
                SizedBox(height: 12),
              ],
              
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fecha a la izquierda solo en pantallas grandes
                  if (!isSmall) ...[
                    Container(
                      width: 60,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.blue[900]!.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[400]!, width: 1),
                      ),
                      child: Column(
                        children: [
                          Text(dayText,
                              style: TextStyle(
                                  color: Colors.blue[400],
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          Text(monthText,
                              style: TextStyle(color: Colors.blue[300], fontSize: 12)),
                        ],
                      ),
                    ),
                    SizedBox(width: 16),
                  ],

                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Color(0xFF161B22),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Color(0xFF30363D), width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(event['title'],
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold)),
                              ),
                              SizedBox(width: 8),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: statusColor, width: 1),
                                ),
                                child: Text(status,
                                    style: TextStyle(
                                        color: statusColor,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined,
                                  color: Colors.grey[400], size: 14),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(event['location'],
                                    style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                              ),
                            ],
                          ),
                          if (event['role'] != null && event['role'].toString().isNotEmpty) ...[
                            SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.work_outline,
                                    color: Colors.grey[400], size: 14),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text(event['role'],
                                      style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNotificationBell() {
    final unreadCount = Provider.of<NotificationProvider>(context).unreadCount;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Stack(
      children: [
        IconButton(
          icon: Icon(
            Icons.notifications_outlined,
            color: Colors.white,
            size: isMobile ? 22 : 24,
          ),
          onPressed: () {
            setState(() {
              _showNotifications = !_showNotifications;
            });
          },
        ),
        if (unreadCount > 0)
          Positioned(
            right: isMobile ? 6 : 8,
            top: isMobile ? 6 : 8,
            child: Container(
              padding: EdgeInsets.all(isMobile ? 2 : 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
              ),
              constraints: BoxConstraints(
                minWidth: isMobile ? 14 : 16,
                minHeight: isMobile ? 14 : 16,
              ),
              child: Text(
                unreadCount > 9 ? '9+' : '$unreadCount',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isMobile ? 8 : 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNotificationsPanel() {
    if (!_showNotifications) return SizedBox.shrink();

    final isMobile = MediaQuery.of(context).size.width < 600;
    final screenWidth = MediaQuery.of(context).size.width;
    final notificationProvider = Provider.of<NotificationProvider>(context);

    return Positioned(
      right: isMobile ? 10 : 20,
      top: isMobile ? 60 : 70,
      child: Container(
        width: isMobile ? screenWidth * 0.9 : 350,
        height: isMobile ? 350 : 400,
        decoration: BoxDecoration(
          color: Color(0xFF161B22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Color(0xFF30363D), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFF30363D), width: 1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Notificaciones', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  if (notificationProvider.unreadCount > 0)
                    TextButton(
                      onPressed: notificationProvider.markAsRead,
                      child: Text('Marcar leídas', style: TextStyle(color: Colors.blue[400], fontSize: 12)),
                    ),
                ],
              ),
            ),
            Expanded(
              child: notificationProvider.notifications.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_none, color: Colors.grey[600], size: 40),
                          SizedBox(height: 8),
                          Text('No hay notificaciones', style: TextStyle(color: Colors.grey[500])),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: notificationProvider.notifications.length,
                      itemBuilder: (context, index) {
                        return _buildNotificationItem(notificationProvider.notifications[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationItem(PushNotification notification) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF30363D), width: 1)),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue[900]!.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.notifications, color: Colors.blue[400], size: 20),
        ),
        title: Text(
          notification.title ?? 'Notificación',
          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text(
              notification.body ?? '',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 4),
            Text(
              _formatTimeAgo(notification.timestamp ?? DateTime.now()),
              style: TextStyle(color: Colors.grey[600], fontSize: 10),
            ),
          ],
        ),
        onTap: () {
          if (notification.route != null) {
            Navigator.pushNamed(context, notification.route!, arguments: notification.parameters);
          }
        },
      ),
    );
  }

  String _formatTimeAgo(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    if (difference.inMinutes < 60) return 'Hace ${difference.inMinutes} min';
    if (difference.inHours < 24) return 'Hace ${difference.inHours} h';
    return DateFormat('dd/MM/yyyy').format(time);
  }

  Widget _buildHeader(bool isMobile) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            'Panel Freelancer',
            style: TextStyle(
              color: Colors.white,
              fontSize: isMobile ? 20 : 28,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Row(
          children: [
            _buildNotificationBell(),
            IconButton(
              icon: Icon(Icons.refresh, color: Colors.white),
              onPressed: _loadDashboardData,
              tooltip: 'Actualizar',
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 900;

    // Determinar qué eventos mostrar: priorizar upcoming_events, luego my_events
    final eventsToShow = _upcomingEvents.isNotEmpty ? _upcomingEvents : _myEvents;

    return Scaffold(
      backgroundColor: Color(0xFF0D1117),
      
      body: SafeArea(
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: Colors.blue[600]))
            : _errorMessage.isNotEmpty
                ? ApiErrorHandler.buildErrorWidget(
                    message: _errorMessage,
                    onRetry: _loadDashboardData,
                  )
                : Stack(
                  children: [
                    Row(
                children: [
                  if (!isMobile) _buildSidebar(),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(isMobile ? 12 : 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(isMobile),
                          SizedBox(height: isMobile ? 12 : 24),

                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildUrgentBanner(),
                                  SizedBox(height: 16),
                                  
                                  LayoutBuilder(builder: (context, constraints) {
                                    // Determinar número de columnas según el ancho
                                    int crossAxisCount;
                                    double childAspectRatio;
                                    
                                    if (constraints.maxWidth < 360) {
                                      // Móvil muy pequeño: 1 columna
                                      crossAxisCount = 1;
                                      childAspectRatio = 2.5;
                                    } else if (constraints.maxWidth < 600) {
                                      // Móvil normal: 2 columnas
                                      crossAxisCount = 2;
                                      childAspectRatio = 1.4;
                                    } else if (constraints.maxWidth < 900) {
                                      // Tablet: 3 columnas
                                      crossAxisCount = 3;
                                      childAspectRatio = 1.5;
                                    } else {
                                      // Desktop: 3 columnas
                                      crossAxisCount = 3;
                                      childAspectRatio = 1.8;
                                    }
                                    
                                    final metrics = [
                                      _buildMetricCard(
                                          'Total de eventos',
                                          _dashboardData['total_events'],
                                          'Activos: ${_dashboardData['active_events']} | Finalizados: ${_dashboardData['finished_events']}',
                                          Colors.green[400]!),
                                      _buildMetricCard(
                                          'Tasa de aceptación',
                                          '${_dashboardData['acceptance_rate']}%',
                                          'Porcentaje',
                                          Colors.blue[400]!),
                                      _buildMetricCard(
                                          'Perfil completado',
                                          '${_dashboardData['profile_completion']}%',
                                          'Estado del perfil',
                                          Colors.purple[400]!),
                                    ];

                                    return GridView.builder(
                                      shrinkWrap: true,
                                      physics: NeverScrollableScrollPhysics(),
                                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: crossAxisCount,
                                        childAspectRatio: childAspectRatio,
                                        crossAxisSpacing: 10,
                                        mainAxisSpacing: 10,
                                      ),
                                      itemCount: metrics.length,
                                      itemBuilder: (context, index) => metrics[index],
                                    );
                                  }),
                                  
                                  SizedBox(height: 24),
                                  Text('Mis eventos',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold)),
                                  SizedBox(height: 12),

                                  if (eventsToShow.isEmpty)
                                    Container(
                                      padding: EdgeInsets.all(24),
                                      decoration: BoxDecoration(
                                        color: Color(0xFF161B22),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: Color(0xFF30363D), width: 1),
                                      ),
                                      child: Center(
                                        child: Column(
                                          children: [
                                            Icon(Icons.event_available_outlined,
                                                color: Colors.grey[600],
                                                size: 40),
                                            SizedBox(height: 12),
                                            Text('No tienes eventos confirmados',
                                                style: TextStyle(
                                                    color: Colors.grey[400],
                                                    fontSize: 14),
                                                textAlign: TextAlign.center),
                                            SizedBox(height: 6),
                                            Text(
                                                'Cuando te asignen a eventos, aparecerán aquí',
                                                style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 12),
                                                textAlign: TextAlign.center),
                                          ],
                                        ),
                                      ),
                                    )
                                  else
                                    Column(
                                      children: eventsToShow
                                          .map((event) => _buildEventCard(event))
                                          .toList(),
                                    ),

                                  SizedBox(height: 24),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              _buildNotificationsPanel(),
            ],
          ),
      ),
    );
  }
}