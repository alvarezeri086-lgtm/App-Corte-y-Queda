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
    'total_projects': 0,
    'active_events': 0,
    'filled_positions': 0,
    'total_positions': 0,
    'unique_freelancers': 0,
  };
  List<Map<String, dynamic>> _recentEvents = [];
  int _pendingActivations = 0;
  Map<String, dynamic> _userData = {};
  String _errorMessage = '';

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

    try {
      await Future.wait([
        _loadUserData(),
        _loadOrganizationDashboard(),
        _loadRecentEvents(),
      ]);
    } catch (e) {
      print('Error loading dashboard: $e');
      setState(() {
        _errorMessage = 'Error al cargar datos';
      });
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
      print('Loading user data from: $baseUrl/users/me');
      final response = await http.get(
        Uri.parse('$baseUrl/users/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('User data response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('User data loaded: $data');
        
        setState(() {
          _userData = data;
        });
      } else {
        print('Error loading user data: ${response.statusCode} - ${response.body}');
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
      print('Loading dashboard from: $baseUrl/dashboard/organization');
      final response = await http.get(
        Uri.parse('$baseUrl/dashboard/organization'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('Dashboard response: ${response.statusCode}');
      print('Dashboard body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Dashboard data parsed: $data');
        
        // Procesar diferentes estructuras de respuesta
        Map<String, dynamic> processedData = {};
        
        // Intenta extraer datos de diferentes estructuras posibles
        if (data is Map<String, dynamic>) {
          // Caso 1: Datos directos
          if (data.containsKey('total_projects') || data.containsKey('projects')) {
            processedData = _extractDashboardData(data);
          }
          // Caso 2: Datos anidados en una clave
          else if (data.containsKey('dashboard')) {
            processedData = _extractDashboardData(data['dashboard']);
          }
          // Caso 3: Datos en data/items
          else if (data.containsKey('data')) {
            processedData = _extractDashboardData(data['data']);
          }
        }
        
        setState(() {
          _dashboardData = processedData;
          _pendingActivations = _parsePendingActivations(data);
        });
        
        print('Processed dashboard data: $_dashboardData');
      } else {
        print('Error loading dashboard: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
    } catch (e) {
      print('Error loading organization dashboard: $e');
    }
  }

  Map<String, dynamic> _extractDashboardData(Map<String, dynamic> data) {
    return {
      'total_projects': data['total_projects'] ?? 
                       data['projects'] ?? 
                       data['total_projects_count'] ?? 
                       data['projects_count'] ?? 0,
      'active_events': data['active_events'] ?? 
                      data['active_events_count'] ?? 
                      data['events_active'] ?? 
                      data['activeEvents'] ?? 0,
      'filled_positions': data['filled_positions'] ?? 
                         data['positions_filled'] ?? 
                         data['filledPositions'] ?? 
                         data['positions_filled_count'] ?? 0,
      'total_positions': data['total_positions'] ?? 
                        data['positions_total'] ?? 
                        data['totalPositions'] ?? 
                        data['positions_total_count'] ?? 0,
      'unique_freelancers': data['unique_freelancers'] ?? 
                           data['freelancers_unique'] ?? 
                           data['uniqueFreelancers'] ?? 
                           data['freelancers_unique_count'] ?? 0,
    };
  }

  int _parsePendingActivations(Map<String, dynamic> data) {
    try {
      // Prueba diferentes estructuras posibles
      final dynamicData = data;
      
      // Buscar en diferentes niveles
      List<String> possiblePaths = [
        'pending_activations',
        'activations_pending',
        'pending.activations',
        'activations.pending',
        'pending_count',
        'pendingActivations',
      ];
      
      for (var path in possiblePaths) {
        if (path.contains('.')) {
          final parts = path.split('.');
          dynamic current = dynamicData;
          bool found = true;
          
          for (var part in parts) {
            if (current is Map<String, dynamic> && current.containsKey(part)) {
              current = current[part];
            } else {
              found = false;
              break;
            }
          }
          
          if (found && current != null && current is int) {
            return current;
          }
        } else if (dynamicData is Map<String, dynamic> && 
                   dynamicData.containsKey(path) && 
                   dynamicData[path] is int) {
          return dynamicData[path];
        }
      }
      
      return 0;
    } catch (e) {
      print('Error parsing pending activations: $e');
      return 0;
    }
  }

  Future<void> _loadRecentEvents() async {
    final baseUrl = dotenv.env['API_BASE_URL'];
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.accessToken;

    if (token == null || baseUrl == null) return;

    try {
      print('Loading recent events from: $baseUrl/events/?limit=4&status=ACTIVE');
      final response = await http.get(
        Uri.parse('$baseUrl/events/my-events/?limit=4&status=ACTIVE'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('Events response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Events data: $data');
        
        List<dynamic> eventsList = [];
        
        // Procesar diferentes estructuras de respuesta
        if (data is List) {
          eventsList = data;
        } else if (data is Map<String, dynamic>) {
          if (data['items'] is List) {
            eventsList = data['items'];
          } else if (data['data'] is List) {
            eventsList = data['data'];
          } else if (data['results'] is List) {
            eventsList = data['results'];
          } else if (data['events'] is List) {
            eventsList = data['events'];
          } else if (data['my_events'] is List) {
            eventsList = data['my_events'];
          }
          
          // Si no hay lista específica, buscar cualquier lista
          if (eventsList.isEmpty) {
            data.forEach((key, value) {
              if (value is List && eventsList.isEmpty) {
                eventsList = value;
              }
            });
          }
        }

        setState(() {
          _recentEvents = eventsList.map<Map<String, dynamic>>((event) {
            DateTime? startDate;
            DateTime? endDate;
            
            if (event['start_date'] != null) {
              try {
                startDate = DateTime.parse(event['start_date'].toString());
              } catch (e) {
                print('Error parsing start date: $e');
              }
            }
            
            if (event['end_date'] != null) {
              try {
                endDate = DateTime.parse(event['end_date'].toString());
              } catch (e) {
                print('Error parsing end date: $e');
              }
            }

            return {
              'id': event['id']?.toString() ?? '',
              'title': event['title']?.toString() ?? 
                      event['name']?.toString() ?? 
                      'Sin título',
              'start_date': startDate,
              'end_date': endDate,
              'location': event['location']?.toString() ?? 
                         event['venue']?.toString() ?? 
                         'Sin ubicación',
              'status': event['status']?.toString() ?? 'INACTIVE',
              'vacancies': event['vacancies'] ?? 
                          event['available_positions'] ?? 
                          event['positions_count'] ?? 0,
            };
          }).toList();
        });
        
        print('Loaded ${_recentEvents.length} recent events');
      } else {
        print('Error loading events: ${response.statusCode} - ${response.body}');
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
              SizedBox(height: 8),
              TextButton(
                onPressed: _loadDashboardData,
                child: Text(
                  'Reintentar carga',
                  style: TextStyle(color: Colors.blue[400]),
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
            String dateRange = 'N/A';
            if (event['start_date'] != null && event['start_date'] is DateTime) {
              final startDate = DateFormat('dd MMM').format(event['start_date'] as DateTime);
              if (event['end_date'] != null && event['end_date'] is DateTime) {
                final endDate = DateFormat('dd MMM').format(event['end_date'] as DateTime);
                dateRange = '$startDate - $endDate';
              } else {
                dateRange = startDate;
              }
            }
            
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

  Widget _buildHeader() {
    return Container(
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
                child: Icon(Icons.connect_without_contact,
                    color: Colors.white, size: 20),
              ),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
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
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadDashboardData,
            tooltip: 'Actualizar',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      backgroundColor: Color(0xFF0D1117),
      bottomNavigationBar: CompanyBottomNav(currentRoute: '/company_dashboard'),
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(color: Colors.blue[600]),
              )
            : Column(
                children: [
                  // Header principal
                  _buildHeader(),
                  
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Título
                          Text(
                            'Panel de la empresa',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          
                          if (_errorMessage.isNotEmpty)
                            Container(
                              padding: EdgeInsets.all(16),
                              margin: EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.red[900]!.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.red[400]!, width: 1),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.error_outline, color: Colors.red[400]),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _errorMessage,
                                      style: TextStyle(
                                        color: Colors.red[400],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          if (_pendingActivations > 0)
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(20),
                              margin: EdgeInsets.only(bottom: 16),
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
                                  // Métricas
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
                                        _dashboardData['total_projects'] ?? 0,
                                        '+Active now',
                                        Colors.blue[400]!,
                                      ),
                                      _buildMetricCard(
                                        'Eventos activos',
                                        _dashboardData['active_events'] ?? 0,
                                        'EN CURSO',
                                        Colors.green[400]!,
                                      ),
                                      _buildMetricCard(
                                        'Posiciones cubiertas',
                                        '${_dashboardData['filled_positions'] ?? 0}/${_dashboardData['total_positions'] ?? 0}',
                                        'ESTADO OPERATIVO',
                                        Colors.purple[400]!,
                                      ),
                                      _buildMetricCard(
                                        'Freelancers Únicos',
                                        _dashboardData['unique_freelancers'] ?? 0,
                                        'RED DE TALENTO',
                                        Colors.orange[400]!,
                                      ),
                                    ],
                                  ),
                                  
                                  SizedBox(height: 32),

                                  // Eventos recientes
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Mis eventos recientes',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      TextButton.icon(
                                        onPressed: () {
                                          Navigator.pushNamed(context, '/events');
                                        },
                                        icon: Icon(Icons.arrow_forward, color: Colors.blue[400], size: 16),
                                        label: Text(
                                          'Ver todos',
                                          style: TextStyle(
                                            color: Colors.blue[400],
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
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