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
  Map<String, dynamic> _userData = {};
  Map<String, dynamic> _freelancerProfile = {};
  List<Map<String, dynamic>> _jobRoles = [];
  List<Map<String, dynamic>> _tags = [];
  List<Map<String, dynamic>> _equipment = [];
  List<Map<String, dynamic>> _upcomingEvents = [];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    final baseUrl = dotenv.env['API_BASE_URL'];
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.accessToken;

    if (token == null || baseUrl == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      await Future.wait([
        _loadUserData(baseUrl, token),
        _loadEvents(baseUrl, token),
      ]);
    } catch (e) {
      print('Error loading freelancer dashboard: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUserData(String baseUrl, String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (!mounted) return;

        setState(() {
          _userData = data;
          _freelancerProfile = data['freelancer_profile'] ?? {};

          final rawRoles = _freelancerProfile['job_roles'];
          if (rawRoles is List) {
            _jobRoles = rawRoles.map((e) => e as Map<String, dynamic>).toList();
          }

          final rawTags = _freelancerProfile['tags'];
          if (rawTags is List) {
            _tags = rawTags.map((e) => e as Map<String, dynamic>).toList();
          }

          final rawEquip = _freelancerProfile['equipment'];
          if (rawEquip is List) {
            _equipment =
                rawEquip.map((e) => e as Map<String, dynamic>).toList();
          }
        });
      } else {
        print('Error cargando datos del usuario: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en _loadUserData: $e');
    }
  }

  Future<void> _loadEvents(String baseUrl, String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/events/?limit=5'),
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
        }

        if (!mounted) return;
        setState(() {
          _upcomingEvents = eventsList.map<Map<String, dynamic>>((e) {
            return {
              'id': e['id']?.toString() ?? '',
              'title': e['title']?.toString() ?? 'Sin título',
              'start_date': e['start_date']?.toString(),
              'end_date': e['end_date']?.toString(),
              'location': e['location']?.toString() ?? 'Sin ubicación',
              'status': e['status']?.toString() ?? 'ACTIVE',
            };
          }).toList();
        });
      }
    } catch (e) {
      print('Error en _loadEvents: $e');
    }
  }

  Future<void> _logout() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF161B22),
        title:
            Text('Cerrar sesión', style: TextStyle(color: Colors.white)),
        content: Text(
          '¿Estás seguro de que quieres cerrar sesión?',
          style: TextStyle(color: Colors.grey[400]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                Text('Cancelar', style: TextStyle(color: Colors.grey[400])),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Cerrar sesión',
                style: TextStyle(color: Colors.red[400])),
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

  // Sidebar solo para DESKTOP
  Widget _buildSidebar() {
    final name = _userData['full_name']?.toString() ?? 'Freelancer';

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

            _buildMenuItem(
                Icons.dashboard_outlined, 'Panel', true, () {
              Navigator.pushNamed(context, '/freelancer_dashboard');
                }),
                _buildMenuItem(
                Icons.dashboard_outlined, 'Activaciones', true, () {
              Navigator.pushNamed(context, '/freelancer_jobs');
                }),
            _buildMenuItem(Icons.person_outline, 'Mi Perfil', false, () {
              Navigator.pushNamed(context, '/freelancer_profile');
            }),
            _buildMenuItem(
                Icons.event_outlined, 'Mis Eventos', false, () {
              Navigator.pushNamed(context, '/freelancer_events');
                }),
            _buildMenuItem(
                Icons.settings_outlined, 'Configuración', false, () {
              Navigator.pushNamed(context, '/freelancer_settings');
                }),

            Spacer(),

            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                    top: BorderSide(color: Colors.grey[800]!, width: 1)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.grey[700],
                        child: Icon(Icons.person,
                            color: Colors.white, size: 18),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                  color: Colors.white, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text('Portal Freelancer',
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
                      icon: Icon(Icons.logout,
                          color: Colors.red[400], size: 16),
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

  Widget _buildMenuItem(
      IconData icon, String title, bool isActive, VoidCallback onTap) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? Color(0xFF1F6FEB).withOpacity(0.15)
            : Colors.transparent,
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
                fontWeight:
                    isActive ? FontWeight.w500 : FontWeight.normal)),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        onTap: onTap,
      ),
    );
  }

  Widget _buildProfileCard() {
    final name = _userData['full_name']?.toString() ?? 'Sin nombre';
    final email = _userData['email']?.toString() ?? 'Sin correo';
    final bio = _freelancerProfile['bio']?.toString() ?? 'Sin biografía';
    final years =
        _freelancerProfile['years_experience']?.toString() ?? '0';
    final location =
        _freelancerProfile['location']?.toString() ?? 'Sin ubicación';
    final rfc = _freelancerProfile['rfc']?.toString() ?? 'Sin RFC';

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
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.blue[900],
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'F',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.email_outlined,
                            color: Colors.grey[500], size: 14),
                        SizedBox(width: 6),
                        Text(email,
                            style: TextStyle(
                                color: Colors.grey[400], fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 14),

          Text(bio,
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                  child: _buildInfoChip(
                      Icons.work_outline, '$years años exp.', Colors.blue)),
              SizedBox(width: 10),
              Expanded(
                  child: _buildInfoChip(Icons.location_on_outlined, location,
                      Colors.green)),
              SizedBox(width: 10),
              Expanded(
                  child: _buildInfoChip(
                      Icons.description_outlined, rfc, Colors.purple)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(
      IconData icon, String text, MaterialColor color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color[900]!.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color[700]!.withOpacity(0.4), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color[400], size: 18),
          SizedBox(height: 6),
          Text(text,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildRolesTagsSection() {
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
          Text('Habilidades profesionales',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          SizedBox(height: 16),

          if (_jobRoles.isNotEmpty) ...[
            Text('Roles',
                style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _jobRoles.map((role) {
                final roleName =
                    role['job_role']?['name']?.toString() ??
                        role['name']?.toString() ??
                        'Rol';
                final years = role['years']?.toString() ?? '0';
                final level = role['level']?.toString() ?? '1';
                return Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue[900]!.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.blue[600]!.withOpacity(0.5), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(roleName,
                          style: TextStyle(
                              color: Colors.blue[300], fontSize: 13)),
                      SizedBox(width: 6),
                      Text('• ${years}a Nv.$level',
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 11)),
                    ],
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 16),
          ],

          if (_tags.isNotEmpty) ...[
            Text('Tags',
                style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _tags.map((tag) {
                final tagName =
                    tag['name']?.toString() ?? 'Tag';
                return Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green[900]!.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.green[600]!.withOpacity(0.5),
                        width: 1),
                  ),
                  child: Text(tagName,
                      style: TextStyle(
                          color: Colors.green[300], fontSize: 13)),
                );
              }).toList(),
            ),
            SizedBox(height: 16),
          ],

          if (_equipment.isNotEmpty) ...[
            Text('Equipo',
                style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _equipment.map((equip) {
                final equipName =
                    equip['equipment_item']?['name']?.toString() ??
                        equip['name']?.toString() ??
                        'Equipo';
                final qty = equip['quantity']?.toString() ?? '1';
                return Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.purple[900]!.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.purple[600]!.withOpacity(0.5),
                        width: 1),
                  ),
                  child: Text('$equipName x$qty',
                      style: TextStyle(
                          color: Colors.purple[300], fontSize: 13)),
                );
              }).toList(),
            ),
          ],

          if (_jobRoles.isEmpty && _tags.isEmpty && _equipment.isEmpty)
            Text('No tienes habilidades profesionales registradas.',
                style: TextStyle(color: Colors.grey[500], fontSize: 13)),
        ],
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
              style:
                  TextStyle(color: Colors.grey[400], fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
      String title, dynamic value, String subtitle, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFF30363D), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value.toString(),
              style: TextStyle(
                  color: color,
                  fontSize: 24,
                  fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text(title,
              style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
          SizedBox(height: 4),
          Text(subtitle,
              style: TextStyle(
                  color: Colors.grey[600], fontSize: 10)),
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
                    style: TextStyle(
                        color: Colors.blue[300], fontSize: 12)),
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
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                      Text(event['location'],
                          style: TextStyle(
                              color: Colors.grey[400], fontSize: 12)),
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
    return Text(
      'Panel Freelancer',
      style: TextStyle(
        color: Colors.white,
        fontSize: isMobile ? 20 : 28,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      backgroundColor: Color(0xFF0D1117),
      
      // ============================================================
      // BOTTOM NAVIGATION (solo en móvil, reemplaza drawer)
      bottomNavigationBar: isMobile
          ? FreelancerBottomNav(currentRoute: '/freelancer_dashboard')
          : null,
      // ============================================================
      
      body: SafeArea(
        child: _isLoading
            ? Center(
                child:
                    CircularProgressIndicator(color: Colors.blue[600]),
              )
            : Row(
                children: [
                  // Sidebar solo en desktop
                  if (!isMobile) _buildSidebar(),

                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(isMobile ? 16 : 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header (sin botón hamburguesa)
                          if (isMobile) ...[
                            _buildHeader(isMobile),
                            SizedBox(height: 16),
                          ] else ...[
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                _buildHeader(isMobile),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color:
                                        Colors.blue[900]!.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: Colors.blue[400]!, width: 1),
                                  ),
                                  child: Text('PORTAL FREELANCER',
                                      style: TextStyle(
                                          color: Colors.blue[400],
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            SizedBox(height: 24),
                          ],

                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildProfileCard(),
                                  SizedBox(height: 24),
                                  _buildUrgentBanner(),
                                  SizedBox(height: 24),
                                  GridView.count(
                                    shrinkWrap: true,
                                    physics: NeverScrollableScrollPhysics(),
                                    crossAxisCount: isMobile ? 1 : 3,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                    childAspectRatio: isMobile ? 1.5 : 1.2,
                                    children: [
                                      _buildMetricCard(
                                          'EVENTOS COMPLETADOS',
                                          '1',
                                          'Total histórico',
                                          Colors.green[400]!),
                                      _buildMetricCard(
                                          'TASA DE ACEPTACIÓN',
                                          '0%',
                                          'Total histórico',
                                          Colors.blue[400]!),
                                      _buildMetricCard(
                                          'PERFIL COMPLETADO',
                                          '100%',
                                          'Totalmente en regla',
                                          Colors.purple[400]!),
                                    ],
                                  ),
                                  SizedBox(height: 32),
                                  _buildRolesTagsSection(),
                                  SizedBox(height: 32),
                                  Text('Próximos eventos (Mis Eventos)',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
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
                                            Icon(
                                                Icons
                                                    .event_available_outlined,
                                                color: Colors.grey[600],
                                                size: 48),
                                            SizedBox(height: 16),
                                            Text(
                                                'No tienes eventos próximos',
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

                                  SizedBox(height: 32),
                                  Text('Estado de la bóveda',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold)),
                                  SizedBox(height: 16),

                                  _buildVaultItem(
                                      'Seguro de responsabilidad civil', true),
                                  _buildVaultItem(
                                      'Permiso de trabajo (MX)', true),
                                  _buildVaultItem(
                                      'Certificación de salud', false),

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