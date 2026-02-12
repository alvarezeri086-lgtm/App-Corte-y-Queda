import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import '../auth_provider.dart';
import 'package:intl/intl.dart';
import '../providers/notification_provider.dart';
import '../models/notification_model.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/error_handler.dart';

class CompanyDashboardPage extends StatefulWidget {
  @override
  _CompanyDashboardPageState createState() => _CompanyDashboardPageState();
}

class _CompanyDashboardPageState extends State<CompanyDashboardPage> {
  bool _isLoading = true;
  String _errorMessage = '';
  Map<String, dynamic> _dashboardData = {
    'total_events': 0,
    'active_events': 0,
    'closed_events': 0,
    'total_positions': 0,
    'covered_positions': 0,
    'unique_freelancers': 0,
  };
  List<Map<String, dynamic>> _recentEvents = [];
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
      setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/dashboard/organization'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(Duration(seconds: 15));

      if (response.isSuccess) {
        final data = jsonDecode(response.body);
        
        if (data.containsKey('kpis') && data['kpis'] is Map) {
          final kpis = data['kpis'] as Map<String, dynamic>;
          
          setState(() {
            _dashboardData = {
              'total_events': kpis['total_events'] ?? 0,
              'active_events': kpis['active_events'] ?? 0,
              'closed_events': kpis['closed_events'] ?? 0,
              'total_positions': kpis['total_positions'] ?? 0,
              'covered_positions': kpis['covered_positions'] ?? 0,
              'unique_freelancers': kpis['unique_freelancers'] ?? 0,
            };
          });
        }

        if (data.containsKey('recent_events') && data['recent_events'] is List) {
          final events = data['recent_events'] as List;
          
          setState(() {
            _recentEvents = events.take(4).map<Map<String, dynamic>>((event) {
              String eventId = event['event_id']?.toString() ?? '';
              
              return {
                'id': eventId,
                'title': event['title']?.toString() ?? event['name']?.toString() ?? 'Sin título',
                'start_date': event['start_date']?.toString(),
                'end_date': event['end_date']?.toString(),
                'location': event['location']?.toString() ?? 'Sin ubicación',
                'status': event['status']?.toString() ?? 'ACTIVE',
                'open_positions': event['urgent_positions'] ?? event['open_positions'] ?? 0,
              };
            }).toList();
          });
        }

        setState(() => _isLoading = false);
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = response.friendlyErrorMessage;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = ApiErrorHandler.handleNetworkException(e);
      });
    }
  }

  void _navigateToEventDetails(String eventId) {
    if (eventId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ID de evento no válido'),
          backgroundColor: Colors.red[600],
        ),
      );
      return;
    }

    Navigator.pushNamed(
      context,
      '/event_details',
      arguments: eventId,
    ).then((value) {
      _loadDashboardData();
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al abrir detalles del evento'),
          backgroundColor: Colors.red[600],
        ),
      );
    });
  }

  Widget _buildMetricCard(String title, dynamic value, String subtitle, Color color) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isVerySmall = constraints.maxWidth < 140;
        final fontSize = isVerySmall ? 20.0 : 26.0;
        final titleFontSize = isVerySmall ? 11.0 : 13.0;
        final subtitleFontSize = isVerySmall ? 9.0 : 11.0;
        
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: Color(0xFF161B22),
            borderRadius: BorderRadius.circular(12),
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
                  value?.toString() ?? '0',
                  style: TextStyle(
                    color: color,
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                ),
              ),
              SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey[300],
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
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
                  height: 1.2,
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

  Widget _buildVerticalEventCard(Map<String, dynamic> event) {
    String dateRange = 'N/A';
    if (event['start_date'] != null) {
      try {
        final start = DateTime.parse(event['start_date']);
        dateRange = DateFormat('dd MMM').format(start);
        if (event['end_date'] != null) {
          final end = DateTime.parse(event['end_date']);
          dateRange += ' - ${DateFormat('dd MMM').format(end)}';
        }
      } catch (e) {}
    }
    
    final openPositions = event['open_positions'] ?? 0;
    final vacancyText = openPositions > 0 ? '$openPositions abiertos' : 'Cubierto';
    final vacancyColor = openPositions > 0 ? Colors.orange[400]! : Colors.green[400]!;
    final status = event['status'] ?? 'INACTIVE';
    final statusColor = status == 'ACTIVE' ? Colors.green[400]! : Colors.grey[400]!;
    final eventId = event['id']?.toString() ?? '';

    return InkWell(
      onTap: () => _navigateToEventDetails(eventId),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: Color(0xFF161B22),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Color(0xFF30363D), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Título y Estado
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      event['title'],
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: statusColor, width: 1),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 8),
              
              // Fecha y Ubicación
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today, color: Colors.grey[500], size: 13),
                      SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          dateRange,
                          style: TextStyle(color: Colors.grey[400], fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_on, color: Colors.grey[500], size: 13),
                      SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          event['location'],
                          style: TextStyle(color: Colors.grey[400], fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              SizedBox(height: 8),
              
              // Vacantes
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: vacancyColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: vacancyColor, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      openPositions > 0 ? Icons.person_outline : Icons.person,
                      color: vacancyColor,
                      size: 13,
                    ),
                    SizedBox(width: 4),
                    Text(
                      vacancyText,
                      style: TextStyle(
                        color: vacancyColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentEventsVertical() {
    if (_recentEvents.isEmpty) {
      return Container(
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Color(0xFF161B22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Color(0xFF30363D), width: 1),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.event_note_outlined, color: Colors.grey[600], size: 40),
              SizedBox(height: 12),
              Text(
                'No hay llamados recientes',
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        ..._recentEvents.map((event) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10.0),
            child: _buildVerticalEventCard(event),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildNotificationBell() {
    final unreadCount = Provider.of<NotificationProvider>(context).unreadCount;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Stack(
      children: [
        IconButton(
          icon: Icon(Icons.notifications_outlined, color: Colors.white, size: 24),
          onPressed: () => setState(() => _showNotifications = !_showNotifications),
        ),
        if (unreadCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              child: Text(
                unreadCount > 9 ? '9+' : '$unreadCount',
                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNotificationsPanel() {
    if (!_showNotifications) return SizedBox.shrink();
    final notificationProvider = Provider.of<NotificationProvider>(context);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Positioned(
      right: 16,
      top: 60,
      child: Container(
        width: isMobile ? MediaQuery.of(context).size.width * 0.9 : 350,
        height: 400,
        decoration: BoxDecoration(
          color: Color(0xFF161B22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Color(0xFF30363D), width: 1),
          boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 20)],
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF30363D)))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Notificaciones', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  if (notificationProvider.unreadCount > 0)
                    TextButton(
                      onPressed: notificationProvider.markAsRead,
                      child: Text('Marcar leídas', style: TextStyle(color: Colors.blue[400])),
                    ),
                ],
              ),
            ),
            Expanded(
              child: notificationProvider.notifications.isEmpty
                  ? Center(child: Text('Sin notificaciones', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: notificationProvider.notifications.length,
                      itemBuilder: (context, index) => _buildNotificationItem(notificationProvider.notifications[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationItem(PushNotification notification) {
    return ListTile(
      leading: Icon(Icons.notifications, color: Colors.blue[400]),
      title: Text(notification.title ?? 'Notificación', style: TextStyle(color: Colors.white, fontSize: 14)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(notification.body ?? '', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
          Text(_formatTimeAgo(notification.timestamp ?? DateTime.now()), style: TextStyle(color: Colors.grey[600], fontSize: 10)),
        ],
      ),
      onTap: () {
        if (notification.route != null) {
          Navigator.pushNamed(context, notification.route!, arguments: notification.parameters);
        }
      },
    );
  }

  String _formatTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    return DateFormat('dd/MM/yyyy').format(time);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 900;

    return Scaffold(
      backgroundColor: Color(0xFF0D1117),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: 12),
              color: Color(0xFF161B22),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.blue[600],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(Icons.connect_without_contact, color: Colors.white, size: 18),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Corte y Queda', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                        if (!isMobile || screenWidth > 360)
                          Text('SISTEMA OPERATIVO', style: TextStyle(color: Colors.grey[600], fontSize: 9)),
                      ],
                    ),
                  ),
                  _buildNotificationBell(),
                ],
              ),
            ),
            
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: Colors.blue[600]))
                  : _errorMessage.isNotEmpty
                      ? ApiErrorHandler.buildErrorWidget(
                          message: _errorMessage,
                          onRetry: _loadDashboardData,
                        )
                      : SingleChildScrollView(
                      padding: EdgeInsets.all(isMobile ? 12 : 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Resumen Operativo',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isMobile ? 20 : 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 14),

                          LayoutBuilder(builder: (context, constraints) {
                            // Determinar número de columnas según el ancho
                            int crossAxisCount;
                            double childAspectRatio;
                            
                            if (constraints.maxWidth < 360) {
                              // Móvil muy pequeño: 2 columnas
                              crossAxisCount = 2;
                              childAspectRatio = 1.1;
                            } else if (constraints.maxWidth < 600) {
                              // Móvil normal: 2 columnas
                              crossAxisCount = 2;
                              childAspectRatio = 1.2;
                            } else if (constraints.maxWidth < 900) {
                              // Tablet: 3 columnas
                              crossAxisCount = 3;
                              childAspectRatio = 1.3;
                            } else {
                              // Desktop: 4 columnas
                              crossAxisCount = 4;
                              childAspectRatio = 1.3;
                            }
                            
                            final metrics = [
                              _buildMetricCard(
                                'Llamados ejecutados',
                                _dashboardData['total_events'],
                                '${_dashboardData['active_events']} activos',
                                Colors.blue[400]!,
                              ),
                              _buildMetricCard(
                                'En curso',
                                _dashboardData['active_events'],
                                'ACTIVOS',
                                Colors.green[400]!,
                              ),
                              _buildMetricCard(
                                'Cobertura',
                                '${_dashboardData['covered_positions']}/${_dashboardData['total_positions']}',
                                'POSICIONES',
                                Colors.purple[400]!,
                              ),
                              _buildMetricCard(
                                'Talento',
                                _dashboardData['unique_freelancers'],
                                'FREELANCERS',
                                Colors.orange[400]!,
                              ),
                            ];

                            return GridView.builder(
                              shrinkWrap: true,
                              physics: NeverScrollableScrollPhysics(),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                childAspectRatio: childAspectRatio,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                              itemCount: metrics.length,
                              itemBuilder: (context, index) => metrics[index],
                            );
                          }),
                          
                          SizedBox(height: 20),
                          Text(
                            'Llamados recientes',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 10),
                          _buildRecentEventsVertical(),
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