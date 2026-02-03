import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import '../auth_provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CompanyDashboardPage extends StatefulWidget {
  @override
  _CompanyDashboardPageState createState() => _CompanyDashboardPageState();
}

class _CompanyDashboardPageState extends State<CompanyDashboardPage> {
  bool _isLoading = true;
  Map<String, dynamic> _dashboardData = {};
  List<Map<String, dynamic>> _recentEvents = [];
  int _pendingActivations = 0;
  Map<String, dynamic> _userData = {};

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    final baseUrl = dotenv.env['API_BASE_URL'];
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.accessToken;

    if (token == null || baseUrl == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      await Future.wait([
        _loadUserData(),
        _loadOrganizationDashboard(),
        _loadRecentEvents(),
      ]);
    } catch (e) {
      print('Error loading dashboard: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUserData() async {
    final baseUrl = dotenv.env['API_BASE_URL'];
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.accessToken;

    if (token == null || baseUrl == null) return;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _userData = data;
        });
      } else {
        print('Error loading user data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> _loadOrganizationDashboard() async {
    final baseUrl = dotenv.env['API_BASE_URL'];
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.accessToken;

    if (token == null || baseUrl == null) return;

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
        
        setState(() {
          _dashboardData = data;
          _pendingActivations = _parsePendingActivations(data);
        });
      } else {
        print('Error loading organization dashboard: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
    } catch (e) {
      print('Error loading organization dashboard: $e');
    }
  }

  int _parsePendingActivations(Map<String, dynamic> data) {
    try {
      if (data['pending_activations'] != null) {
        return data['pending_activations'] is int ? data['pending_activations'] : 0;
      }
      if (data['activations_pending'] != null) {
        return data['activations_pending'] is int ? data['activations_pending'] : 0;
      }
      if (data['pending'] != null && data['pending']['activations'] != null) {
        return data['pending']['activations'] is int ? data['pending']['activations'] : 0;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  Future<void> _loadRecentEvents() async {
    final baseUrl = dotenv.env['API_BASE_URL'];
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.accessToken;

    if (token == null || baseUrl == null) return;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/events/?limit=4&status=ACTIVE'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<dynamic> eventsList = [];
        
        if (data is List) {
          eventsList = data;
        } else if (data is Map) {
          if (data['items'] is List) eventsList = data['items'];
          else if (data['data'] is List) eventsList = data['data'];
          else if (data['results'] is List) eventsList = data['results'];
          else if (data['events'] is List) eventsList = data['events'];
        }

        setState(() {
          _recentEvents = eventsList.map<Map<String, dynamic>>((event) {
            return {
              'id': event['id']?.toString() ?? '',
              'title': event['title']?.toString() ?? 'Sin título',
              'start_date': event['start_date']?.toString(),
              'end_date': event['end_date']?.toString(),
              'location': event['location']?.toString() ?? 'Sin ubicación',
              'status': event['status']?.toString() ?? 'INACTIVE',
              'vacancies': event['vacancies'] ?? 0,
            };
          }).toList();
        });
      }
    } catch (e) {
      print('Error loading recent events: $e');
    }
  }

  Future<void> _logout() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF161B22),
        title: Text(
          'Cerrar sesión',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '¿Estás seguro de que quieres cerrar sesión?',
          style: TextStyle(color: Colors.grey[400]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Cerrar sesión',
              style: TextStyle(color: Colors.red[400]),
            ),
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

  Widget _buildSidebar(Map<String, dynamic>? userData) {
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
                    child: Icon(Icons.connect_without_contact,
                        color: Colors.white, size: 20),
                  ),
                  SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Corte y Queda',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      Text('SISTEMA OPERATIVO OPERACIONAL',
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 9)),
                    ],
                  ),
                ],
              ),
            ),
            Divider(color: Colors.grey[800], height: 1),
            SizedBox(height: 20),
            
            // Opciones del menú
            _buildMenuItem(Icons.dashboard_outlined, 'Panel', true, () {
              Navigator.pushNamed(context, '/company-dashboard');
            }),
            _buildMenuItem(Icons.bolt_outlined, 'Activaciones', false, () {
              Navigator.pushNamed(context, '/activations');
            }),
            _buildMenuItem(Icons.event_outlined, 'Eventos', false, () {
              Navigator.pushNamed(context, '/events');
            }),
            _buildMenuItem(Icons.people_outline, 'Red / Historial', false, () {
              Navigator.pushNamed(context, '/company-history');
            }),
            _buildMenuItem(Icons.settings_outlined, 'Configuración', false, () {
              Navigator.pushNamed(context, '/company-settings');
            }),
            
            Spacer(),
            
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                border:
                    Border(top: BorderSide(color: Colors.grey[800]!, width: 1)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.grey[700],
                        child: userData?['photo'] != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.network(
                                  userData!['photo'],
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Icon(Icons.person,
                                          color: Colors.white, size: 18),
                                ),
                              )
                            : Icon(Icons.person, color: Colors.white, size: 18),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              userData?['organization']?['trade_name']
                                      ?.toString() ??
                                  userData?['company_name']?.toString() ??
                                  'Impacto creativo',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text('Acceso Administrador',
                                style: TextStyle(
                                    color: Colors.grey[500], fontSize: 10)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _logout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[900]!.withOpacity(0.2),
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        side: BorderSide(color: Colors.red[700]!),
                        elevation: 0,
                      ),
                      icon:
                          Icon(Icons.logout, color: Colors.red[400], size: 16),
                      label: Text(
                        'Cerrar Sesión',
                        style: TextStyle(
                          color: Colors.red[400],
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
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
        color:
            isActive ? Color(0xFF1F6FEB).withOpacity(0.15) : Colors.transparent,
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

  Widget _buildMetricCard(String title, dynamic value, String subtitle, Color color) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFF30363D), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value?.toString() ?? '0',
            style: TextStyle(
              color: color,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentEventsTable() {
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
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFF30363D), width: 1),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 24,
          dataRowHeight: 60,
          columns: [
            DataColumn(
              label: Container(
                padding: EdgeInsets.only(left: 16),
                child: Text(
                  'NOMBRE DEL PROYECTO',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'FECHA',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'UBICACIÓN',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'URGENCIA',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            DataColumn(
              label: Container(
                padding: EdgeInsets.only(right: 16),
                child: Text(
                  'ESTADO',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
          rows: _recentEvents.map((event) {
            final startDate = event['start_date'] != null
                ? DateFormat('dd MMM').format(DateTime.parse(event['start_date']))
                : 'N/A';
            final endDate = event['end_date'] != null
                ? DateFormat('dd MMM').format(DateTime.parse(event['end_date']))
                : 'N/A';
            final dateRange = '$startDate - $endDate';
            
            final vacancies = event['vacancies'] ?? 0;
            final urgencyText = vacancies > 0 ? '$vacancies Vacantes' : 'Cubierto';
            final urgencyColor = vacancies > 0 ? Colors.orange[400] : Colors.green[400];
            
            final status = event['status'];
            final statusColor = status == 'ACTIVE' ? Colors.green[400] : Colors.grey[400];

            return DataRow(
              cells: [
                DataCell(
                  Container(
                    padding: EdgeInsets.only(left: 16),
                    child: Text(
                      event['title'],
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    dateRange,
                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                  ),
                ),
                DataCell(
                  Text(
                    event['location'],
                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                  ),
                ),
                DataCell(
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: urgencyColor!.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: urgencyColor, width: 1),
                    ),
                    child: Text(
                      urgencyText,
                      style: TextStyle(
                        color: urgencyColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Container(
                    padding: EdgeInsets.only(right: 16),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor!.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: statusColor, width: 1),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Text(
      'Panel de la empresa',
      style: TextStyle(
        color: Colors.white,
        fontSize: isMobile ? 20 : 28,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userData = authProvider.userInfo;
    final isMobile = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      backgroundColor: Color(0xFF0D1117),
      drawer: isMobile
          ? Drawer(
              backgroundColor: Color(0xFF161B22),
              child: _buildSidebar(userData),
            )
          : null,
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(color: Colors.blue[600]),
              )
            : Row(
                children: [
                  if (!isMobile) _buildSidebar(userData),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(isMobile ? 16 : 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isMobile) ...[
                            Builder(builder: (context) {
                              return Row(
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.menu, color: Colors.white),
                                    onPressed: () =>
                                        Scaffold.of(context).openDrawer(),
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(child: _buildHeader(isMobile)),
                                ],
                              );
                            }),
                            SizedBox(height: 16),
                          ] else ...[
                            _buildHeader(isMobile),
                            SizedBox(height: 24),
                          ],

                          if (_pendingActivations > 0)
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(20),
                              margin: EdgeInsets.only(bottom: 24),
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
                                      Icon(Icons.warning_amber_outlined, color: Colors.orange[400]),
                                      SizedBox(width: 12),
                                      Text(
                                        'Atención Requerida',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    '$_pendingActivations activaciones en espera de respuesta.',
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 15,
                                    ),
                                  ),
                                  SizedBox(height: 12),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.pushNamed(context, '/activations');
                                    },
                                    child: Text(
                                      'Revisar solicitudes pendientes.',
                                      style: TextStyle(
                                        color: Colors.blue[400],
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_dashboardData.isNotEmpty)
                                    GridView.count(
                                      shrinkWrap: true,
                                      physics: NeverScrollableScrollPhysics(),
                                      crossAxisCount: isMobile ? 2 : 4,
                                      crossAxisSpacing: isMobile ? 12 : 20,
                                      mainAxisSpacing: isMobile ? 12 : 20,
                                      childAspectRatio: 0.9,
                                      children: [
                                        _buildMetricCard(
                                          'Proyectos totales',
                                          _dashboardData['total_projects'] ?? _dashboardData['projects'] ?? 0,
                                          '+Active now',
                                          Colors.blue[400]!,
                                        ),
                                        _buildMetricCard(
                                          'Eventos activos',
                                          _dashboardData['active_events'] ?? _dashboardData['activeEvents'] ?? 0,
                                          'EN CURSO',
                                          Colors.green[400]!,
                                        ),
                                        _buildMetricCard(
                                          'Posiciones cubiertas',
                                          '${_dashboardData['filled_positions'] ?? _dashboardData['filledPositions'] ?? 0}/${_dashboardData['total_positions'] ?? _dashboardData['totalPositions'] ?? 0}',
                                          'ESTADO OPERATIVO',
                                          Colors.purple[400]!,
                                        ),
                                        _buildMetricCard(
                                          'Freelancers Únicos',
                                          _dashboardData['unique_freelancers'] ?? _dashboardData['uniqueFreelancers'] ?? 0,
                                          'RED DE TALENTO',
                                          Colors.orange[400]!,
                                        ),
                                      ],
                                    )
                                  else
                                    Container(
                                      padding: EdgeInsets.all(32),
                                      decoration: BoxDecoration(
                                        color: Color(0xFF161B22),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Color(0xFF30363D), width: 1),
                                      ),
                                      child: Center(
                                        child: CircularProgressIndicator(color: Colors.blue[600]),
                                      ),
                                    ),
                                  SizedBox(height: 32),

                                  Text(
                                    'Mis eventos recientes',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: isMobile ? 18 : 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  _buildRecentEventsTable(),
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