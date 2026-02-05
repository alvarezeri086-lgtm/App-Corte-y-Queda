import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import '../auth_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../componentes/bottoom_freelancer.dart';

class FreelancerDashboardPage extends StatefulWidget {
  @override
  _FreelancerDashboardPageState createState() =>
      _FreelancerDashboardPageState();
}

class _FreelancerDashboardPageState extends State<FreelancerDashboardPage> {
  bool _isLoading = true;
  Map<String, dynamic> _dashboardData = {
    'events_completed': 0,
    'acceptance_rate': 0,
    'profile_completion': 0,
    'upcoming_events_count': 0,
  };
  List<Map<String, dynamic>> _upcomingEvents = [];

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
      final dashboardResponse = await http.get(
        Uri.parse('$baseUrl/dashboard/freelancer'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (dashboardResponse.statusCode == 200) {
        final data = jsonDecode(dashboardResponse.body);
        
        if (data.containsKey('kpis') && data['kpis'] is Map) {
          final kpis = data['kpis'] as Map<String, dynamic>;
          
          setState(() {
            _dashboardData = {
              'events_completed': kpis['events_completed'] ?? 0,
              'acceptance_rate': kpis['acceptance_rate'] ?? 0,
              'profile_completion': kpis['profile_completion'] ?? 0,
              'upcoming_events_count': kpis['upcoming_events_count'] ?? 0,
            };
          });
        }

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
      }

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error loading freelancer dashboard: $e');
      setState(() => _isLoading = false);
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
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
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
          Row(
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
            ],
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
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Color(0xFF161B22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Color(0xFF30363D), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value.toString(),
            style: TextStyle(
              color: color,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              height: 1.0,
            ),
          ),
          SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 3),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 10,
              height: 1.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    final status = event['status']?.toString() ?? 'ACTIVE';
    final isActive = status == 'ACTIVE';
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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

          Expanded(
            child: Container(
              padding: EdgeInsets.all(16),
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
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                      ),
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
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          color: Colors.grey[400], size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(event['location'],
                            style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVaultItem(String name, bool completed) {
    return Container(
      padding: EdgeInsets.all(12),
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Color(0xFF161B22),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0xFF30363D), width: 1),
      ),
      child: Row(
        children: [
          Icon(
            completed ? Icons.check_circle : Icons.circle_outlined,
            color: completed ? Colors.green[400] : Colors.grey[400],
            size: 20,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(name,
                style: TextStyle(
                    color: completed ? Colors.white : Colors.grey[400],
                    fontSize: 14)),
          ),
          if (!completed)
            TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              child: Text('Subir',
                  style: TextStyle(color: Colors.blue[400], fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Panel Freelancer',
          style: TextStyle(
            color: Colors.white,
            fontSize: isMobile ? 22 : 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        IconButton(
          icon: Icon(Icons.refresh, color: Colors.white),
          onPressed: _loadDashboardData,
          tooltip: 'Actualizar',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      backgroundColor: Color(0xFF0D1117),
      bottomNavigationBar: isMobile
          ? FreelancerBottomNav(currentRoute: '/freelancer_dashboard')
          : null,
      
      body: SafeArea(
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: Colors.blue[600]))
            : Row(
                children: [
                  if (!isMobile) _buildSidebar(),

                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(isMobile ? 16 : 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(isMobile),
                          SizedBox(height: isMobile ? 16 : 24),

                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildUrgentBanner(),
                                  SizedBox(height: 20),
                                  
                                  // Tarjetas de métricas compactas
                                  GridView.count(
                                    shrinkWrap: true,
                                    physics: NeverScrollableScrollPhysics(),
                                    crossAxisCount: isMobile ? 1 : 3,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: isMobile ? 3.5 : 1.6,
                                    children: [
                                      _buildMetricCard(
                                          'Eventos completados',
                                          _dashboardData['events_completed'],
                                          'Total histórico',
                                          Colors.green[400]!),
                                      _buildMetricCard(
                                          'Tasa de aceptación',
                                          '${_dashboardData['acceptance_rate']}%',
                                          'Porcentaje de aceptación',
                                          Colors.blue[400]!),
                                      _buildMetricCard(
                                          'Perfil completado',
                                          '${_dashboardData['profile_completion']}%',
                                          'Estado del perfil',
                                          Colors.purple[400]!),
                                    ],
                                  ),
                                  
                                  SizedBox(height: 28),
                                  Text('Próximos eventos',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold)),
                                  SizedBox(height: 16),

                                  if (_upcomingEvents.isEmpty)
                                    Container(
                                      padding: EdgeInsets.all(32),
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
                                                size: 48),
                                            SizedBox(height: 16),
                                            Text('No tienes eventos próximos',
                                                style: TextStyle(
                                                    color: Colors.grey[400],
                                                    fontSize: 16)),
                                            SizedBox(height: 8),
                                            Text(
                                                'Cuando te asignen a eventos, aparecerán aquí',
                                                style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 14),
                                                textAlign: TextAlign.center),
                                          ],
                                        ),
                                      ),
                                    )
                                  else
                                    Column(
                                      children: _upcomingEvents
                                          .map((event) => _buildEventCard(event))
                                          .toList(),
                                    ),

                                  SizedBox(height: 28),
                                  Text('Estado de la bóveda',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold)),
                                  SizedBox(height: 16),

                                  _buildVaultItem('Seguro de responsabilidad civil', true),
                                  _buildVaultItem('Permiso de trabajo (MX)', true),
                                  _buildVaultItem('Certificación de salud', false),

                                  SizedBox(height: 32),
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
      ),
    );
  }
}