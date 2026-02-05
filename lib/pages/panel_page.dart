import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import '../auth_provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../componentes/bottoom_company.dart';

class CompanyDashboardPage extends StatefulWidget {
  @override
  _CompanyDashboardPageState createState() => _CompanyDashboardPageState();
}

class _CompanyDashboardPageState extends State<CompanyDashboardPage> {
  bool _isLoading = true;
  Map<String, dynamic> _dashboardData = {
    'total_events': 0,
    'active_events': 0,
    'closed_events': 0,
    'total_positions': 0,
    'covered_positions': 0,
    'unique_freelancers': 0,
  };
  List<Map<String, dynamic>> _recentEvents = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

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
      );

      if (response.statusCode == 200) {
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
              return {
                'id': event['id']?.toString() ?? '',
                'title': event['title']?.toString() ?? event['name']?.toString() ?? 'Sin título',
                'start_date': event['start_date']?.toString(),
                'end_date': event['end_date']?.toString(),
                'location': event['location']?.toString() ?? 'Sin ubicación',
                'status': event['status']?.toString() ?? 'ACTIVE',
                'open_positions': event['open_positions'] ?? 0,
              };
            }).toList();
          });
        }

        setState(() => _isLoading = false);
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
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

    // Navegar a la página de detalles del evento
    Navigator.pushNamed(
      context,
      '/event_details',
      arguments: eventId,
    ).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al abrir detalles del evento'),
          backgroundColor: Colors.red[600],
        ),
      );
    });
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
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  Widget _buildMetricCard(String title, dynamic value, String subtitle, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFF30363D), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value?.toString() ?? '0',
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              height: 1.1,
            ),
          ),
          SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 13,
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
              fontSize: 11,
              height: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
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

    return InkWell(
      onTap: () => _navigateToEventDetails(event['id']),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: Color(0xFF161B22),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Color(0xFF30363D), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fila 1: Título y Estado
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      event['title'],
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: statusColor, width: 1),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 10),
              
              // Fila 2: Fecha y Ubicación
              Row(
                children: [
                  Icon(Icons.calendar_today, color: Colors.grey[500], size: 14),
                  SizedBox(width: 6),
                  Text(
                    dateRange,
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                  SizedBox(width: 14),
                  Icon(Icons.location_on, color: Colors.grey[500], size: 14),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      event['location'],
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 10),
              
              // Fila 3: Vacantes
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                      size: 14,
                    ),
                    SizedBox(width: 6),
                    Text(
                      vacancyText,
                      style: TextStyle(
                        color: vacancyColor,
                        fontSize: 12,
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
        padding: EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Color(0xFF161B22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Color(0xFF30363D), width: 1),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.event_note_outlined, color: Colors.grey[600], size: 48),
              SizedBox(height: 16),
              Text(
                'No hay eventos recientes',
                style: TextStyle(color: Colors.grey[400], fontSize: 15),
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

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      backgroundColor: Color(0xFF0D1117),
      bottomNavigationBar: isMobile 
          ? CompanyBottomNav(currentRoute: '/company_dashboard')
          : null,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(16),
              color: Color(0xFF161B22),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
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
                      SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Corte y Queda', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          Text('SISTEMA OPERATIVO OPERACIONAL', style: TextStyle(color: Colors.grey[600], fontSize: 9)),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh, color: Colors.white),
                    onPressed: _loadDashboardData,
                    tooltip: 'Actualizar',
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: Colors.blue[600]))
                  : SingleChildScrollView(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Panel de la empresa',
                            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 16),

                          // Tarjetas de métricas 2x2 mejor proporcionadas
                          GridView.count(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 1.3,
                            children: [
                              _buildMetricCard('Eventos totales', _dashboardData['total_events'], '${_dashboardData['active_events']} activos', Colors.blue[400]!),
                              _buildMetricCard('Eventos activos', _dashboardData['active_events'], 'EN CURSO', Colors.green[400]!),
                              _buildMetricCard('Posiciones cubiertas', '${_dashboardData['covered_positions']}/${_dashboardData['total_positions']}', 'ESTADO OPERATIVO', Colors.purple[400]!),
                              _buildMetricCard('Freelancers únicos', _dashboardData['unique_freelancers'], 'RED DE TALENTO', Colors.orange[400]!),
                            ],
                          ),
                          
                          SizedBox(height: 24),
                          Text('Eventos recientes', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                          SizedBox(height: 12),
                          _buildRecentEventsVertical(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}