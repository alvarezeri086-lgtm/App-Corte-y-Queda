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
import 'activaciones_freelancer.dart';

class FreelancerDashboardPage extends StatefulWidget {
  final String? activationIdFromNotification;

  const FreelancerDashboardPage({Key? key, this.activationIdFromNotification})
      : super(key: key);

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
  List<Map<String, dynamic>> _urgentActivations = [];
  bool _showNotifications = false;
  bool _showAllUrgent = false; // Controla si se muestran todas las urgentes

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    // Si se pasó un activationId desde una notificación, navega a él después de cargar
    if (widget.activationIdFromNotification != null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _navigateToActivationFromNotification(
            widget.activationIdFromNotification!);
      });
    }
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
      final results = await Future.wait([
        http.get(
          Uri.parse('$baseUrl/dashboard/freelancer'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ).timeout(const Duration(seconds: 30)),
        http.get(
          Uri.parse('$baseUrl/activations/me?status=PENDING&limit=50'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ).timeout(const Duration(seconds: 30)),
      ]);

      final dashboardResponse = results[0];
      final urgentResponse = results[1];

      if (dashboardResponse.statusCode == 200) {
        final data = jsonDecode(dashboardResponse.body);

        if (data.containsKey('kpis') && data['kpis'] is Map) {
          final kpis = data['kpis'] as Map<String, dynamic>;
          setState(() {
            _dashboardData = {
              'total_events': kpis['total_events'] ?? 0,
              'acceptance_rate':
                  ((kpis['acceptance_rate'] ?? 0.0) * 100).round(),
              'profile_completion': kpis['profile_completion'] ?? 0,
              'active_events': kpis['active_events'] ?? 0,
              'finished_events': kpis['finished_events'] ?? 0,
            };
          });
        }

        if (data.containsKey('upcoming_events') &&
            data['upcoming_events'] is List) {
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
      }

      if (urgentResponse.statusCode == 200) {
        final activationsData = jsonDecode(urgentResponse.body);
        List<dynamic> activationsList = [];
        if (activationsData is List) {
          activationsList = activationsData;
        }

        setState(() {
          // Filtrar: solo PENDING no expiradas
          _urgentActivations =
              activationsList.map<Map<String, dynamic>>((activation) {
            final event = activation['event'] ?? {};
            final positionObj = activation['position'] ?? {};

            // ── role_name directo primero ──
            final role = (activation['role_name']?.toString() ?? '').isNotEmpty
                ? activation['role_name'].toString()
                : (positionObj['role']?.toString() ?? '').isNotEmpty
                    ? positionObj['role'].toString()
                    : (positionObj['name']?.toString() ?? '').isNotEmpty
                        ? positionObj['name'].toString()
                        : 'Sin posición';

            final eventName = (event['title']?.toString() ?? '').isNotEmpty
                ? event['title'].toString()
                : (event['name']?.toString() ?? '').isNotEmpty
                    ? event['name'].toString()
                    : 'Sin nombre';

            final payRate = activation['pay_rate'] ?? 0;
            final currency = activation['currency']?.toString() ?? 'USD';

            return {
              'id': activation['id']?.toString() ?? '',
              'event_name': eventName,
              'role': role,
              'location': event['location']?.toString() ?? 'Sin ubicación',
              'pay_rate': payRate,
              'currency': currency,
              // start_date y end_date SIEMPRE string no-null
              'start_date': event['start_date']?.toString() ?? 'No definido',
              'end_date': event['end_date']?.toString() ?? 'No definido',
              'status': activation['status']?.toString() ?? 'PENDING',
              'event_id': activation['event_id']?.toString() ?? '',
              'organization_name':
                  activation['organization_name']?.toString() ?? '',
              'strategy': activation['strategy']?.toString() ?? '',
              'expire_at': activation['expire_at']?.toString() ?? '',
              // Campos que ActivationDetailScreen accede con cast directo
              'payment_terms': event['payment_terms_days']?.toString() ?? '0',
              'requires_documents':
                  (event['requires_documents'] ?? false) == true,
              'requires_interview':
                  (event['requires_interview'] ?? false) == true,
              'requires_intervals':
                  (event['requires_intervals'] ?? false) == true,
              'sent_at': activation['sent_at']?.toString() ?? '',
              'event_position_id':
                  activation['event_position_id']?.toString() ?? '',
              // Objetos anidados que puede necesitar el detalle
              'event': event,
              'position_info': positionObj,
            };
          }).where((a) {
            // Excluir activaciones cuya fecha de expiración ya pasó
            final expireAt = a['expire_at'] as String;
            if (expireAt.isEmpty) return true; // sin fecha = incluir
            try {
              return DateTime.parse(expireAt).isAfter(DateTime.now());
            } catch (_) {
              return true;
            }
          }).toList();
        });
      } else if (urgentResponse.statusCode == 204) {
        setState(() => _urgentActivations = []);
      }

      if (dashboardResponse.statusCode == 401 ||
          urgentResponse.statusCode == 401) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Sesión expirada. Por favor, inicia sesión nuevamente.';
        });
        await authProvider.logout();
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
              context, '/login', (route) => false);
        }
      } else if (dashboardResponse.statusCode != 200) {
        setState(() {
          _isLoading = false;
          _errorMessage = ApiErrorHandler.handleHttpError(null,
              statusCode: dashboardResponse.statusCode);
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = ApiErrorHandler.handleHttpError(e);
      });
    }
  }

  // Reenvía la respuesta al endpoint — lo necesita ActivationDetailScreen
  Future<bool> _respondToActivation(String activationId, String action,
      {String? reason}) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.accessToken;
    final baseUrl = dotenv.env['API_BASE_URL'];
    if (token == null || baseUrl == null) {
      throw Exception('No hay token de autenticación o URL base');
    }
    final url = Uri.parse('$baseUrl/activations/$activationId/respond');
    final requestBody = <String, dynamic>{'action': action};
    if (reason != null && reason.isNotEmpty) requestBody['reason'] = reason;

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: json.encode(requestBody),
    );

    if (response.statusCode == 200) return true;
    if (response.statusCode == 401) throw Exception('Sesión expirada');
    if (response.statusCode == 404) throw Exception('Activación no encontrada');
    if (response.statusCode == 422) {
      final body = json.decode(response.body);
      final errors = body['detail'] as List?;
      throw Exception(errors?.isNotEmpty == true
          ? errors!.first['msg']
          : 'Error de validación');
    }
    if (response.statusCode == 400) {
      final body = json.decode(response.body);
      throw Exception(body['message'] ?? 'Error al responder');
    }
    throw Exception('Error ${response.statusCode}');
  }

  /// Actualiza una activación específica en la lista sin refetch completo
  void _onActivationStatusChanged(String activationId, String newStatus) {
    setState(() {
      final index =
          _urgentActivations.indexWhere((a) => a['id'] == activationId);
      if (index != -1) {
        _urgentActivations[index]['status'] = newStatus;
      }
    });
  }

  /// Navega a una activación específica desde una notificación
  void _navigateToActivationFromNotification(String activationId) {
    // Busca la activación en la lista
    final activation = _urgentActivations.firstWhere(
      (a) => a['id'] == activationId,
      orElse: () => <String, dynamic>{},
    );

    if (activation.isEmpty) {
      // Si no la encuentra en la lista, muestra error
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No se encontró la activación'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ));
      return;
    }

    // Navega al detalle de la activación
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ActivationDetailScreen(
          activation: activation,
          onStatusChanged: _onActivationStatusChanged,
          respondToActivation: _respondToActivation,
        ),
      ),
    );
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
            child:
                Text('Cerrar sesión', style: TextStyle(color: Colors.red[400])),
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

  // ──────────────────────────────────────────────────────────────────────────
  // SIDEBAR
  // ──────────────────────────────────────────────────────────────────────────
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
                    child: Icon(Icons.connect_without_contact,
                        color: Colors.white, size: 20),
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
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 9)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: Colors.grey[800], height: 1),
            SizedBox(height: 20),
            _buildMenuItem(Icons.dashboard_outlined, 'Resumen Operativo', true,
                () => Navigator.pushNamed(context, '/freelancer_dashboard')),
            _buildMenuItem(Icons.flash_on_outlined, 'Activaciones', false,
                () => Navigator.pushNamed(context, '/freelancer_activations')),
            _buildMenuItem(Icons.person_outline, 'Mi Perfil', false,
                () => Navigator.pushNamed(context, '/profile')),
            Spacer(),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                border:
                    Border(top: BorderSide(color: Colors.grey[800]!, width: 1)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _logout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[900]!.withOpacity(0.2),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                    side: BorderSide(color: Colors.red[700]!),
                    elevation: 0,
                  ),
                  icon: Icon(Icons.logout, color: Colors.red[400], size: 16),
                  label: Text('Cerrar Sesión',
                      style: TextStyle(color: Colors.red[400], fontSize: 13)),
                ),
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

  // ──────────────────────────────────────────────────────────────────────────
  // BANNER URGENTE — REDISEÑADO
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildUrgentBanner() {
    // Sin activaciones urgentes
    if (_urgentActivations.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0D3D2A),
              Color(0xFF0A2A1C),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Color(0xFF1A5C3A), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Color(0xFF1A5C3A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.check_circle_outline,
                  color: Color(0xFF4ADE80), size: 20),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Sin activaciones urgentes pendientes',
                style: TextStyle(
                    color: Color(0xFF4ADE80),
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
    }

    final visibleActivations = _showAllUrgent
        ? _urgentActivations
        : _urgentActivations.take(1).toList();
    final remaining = _urgentActivations.length - 1;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A0A00), Color(0xFF0D1117)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Color(0xFFFFB800).withOpacity(0.5), width: 1),
        boxShadow: [
          BoxShadow(
            color: Color(0xFFFFB800).withOpacity(0.08),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cabecera ──────────────────────────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                    color: Color(0xFFFFB800).withOpacity(0.15), width: 1),
              ),
            ),
            child: Row(
              children: [
                // Ícono rayo
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Color(0xFFFFB800).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Color(0xFFFFB800).withOpacity(0.4), width: 1),
                  ),
                  child: Icon(Icons.bolt, color: Color(0xFFFFB800), size: 20),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Activaciones pendientes',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Requieren tu confirmación',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                // Badge contador
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Color(0xFFFFB800),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_urgentActivations.length}',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Lista de activaciones ─────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Column(
              children: visibleActivations.map((activation) {
                return _buildUrgentActivationItem(activation);
              }).toList(),
            ),
          ),

          // ── Footer: solo expandir/colapsar ───────────────────────────────
          if (!_showAllUrgent && remaining > 0)
            Padding(
              padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: GestureDetector(
                onTap: () => setState(() => _showAllUrgent = true),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Color(0xFFFFB800).withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Color(0xFFFFB800).withOpacity(0.2), width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.keyboard_arrow_down,
                          color: Color(0xFFFFB800), size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Ver $remaining más',
                        style: TextStyle(
                          color: Color(0xFFFFB800),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (_showAllUrgent && _urgentActivations.length > 1)
            Padding(
              padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: GestureDetector(
                onTap: () => setState(() => _showAllUrgent = false),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12, width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.keyboard_arrow_up,
                          color: Colors.white38, size: 16),
                      SizedBox(width: 6),
                      Text('Colapsar',
                          style:
                              TextStyle(color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            )
          else
            SizedBox(height: 12),
        ],
      ),
    );
  }

  /// Tarjeta individual dentro del banner urgente — clickeable al detalle
  Widget _buildUrgentActivationItem(Map<String, dynamic> activation) {
    final payRate = activation['pay_rate'];
    final currency = (activation['currency'] ?? 'USD').toString();
    final hasRate = payRate != null && payRate != 0;

    // Fecha de expiración
    String expiryText = '';
    Color expiryColor = Colors.white54;
    final expireAtRaw = (activation['expire_at'] ?? '').toString();
    if (expireAtRaw.isNotEmpty) {
      try {
        final exp = DateTime.parse(expireAtRaw).toLocal();
        final now = DateTime.now();
        final diff = exp.difference(now);
        if (diff.isNegative) {
          expiryText = 'Expirada';
          expiryColor = Colors.red[400]!;
        } else if (diff.inHours < 24) {
          expiryText =
              'Expira en ${diff.inHours}h ${diff.inMinutes.remainder(60)}m';
          expiryColor = Colors.red[300]!;
        } else {
          expiryText = 'Expira ${exp.day}/${exp.month}/${exp.year}';
          expiryColor = Color(0xFFFFB800);
        }
      } catch (_) {}
    }

    final orgName = (activation['organization_name'] ?? '').toString();
    final startDateRaw = (activation['start_date'] ?? '').toString();

    return GestureDetector(
      onTap: () {
        // Si hay más de una y están colapsadas, expandir en lugar de navegar
        if (!_showAllUrgent &&
            _urgentActivations.length > 1 &&
            _urgentActivations.indexOf(activation) == 0) {
          setState(() => _showAllUrgent = true);
          return;
        }
        // Navegar directamente al detalle de esta activación
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ActivationDetailScreen(
              activation: activation,
              onStatusChanged: _onActivationStatusChanged,
              respondToActivation: _respondToActivation,
            ),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Color(0xFF161B22),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Color(0xFF2A3F5F), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nombre evento + expiración
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    activation['event_name'],
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (expiryText.isNotEmpty) ...[
                  SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: expiryColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: expiryColor.withOpacity(0.4), width: 1),
                    ),
                    child: Text(
                      expiryText,
                      style: TextStyle(
                          color: expiryColor,
                          fontSize: 9,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),

            if (orgName.isNotEmpty) ...[
              SizedBox(height: 3),
              Text(
                orgName,
                style: TextStyle(color: Colors.white54, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            SizedBox(height: 8),

            // Chips de info
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      // Rol
                      _infoChip(
                        icon: Icons.work_outline,
                        label:
                            (activation['role'] ?? 'Sin posición').toString(),
                        color: Color(0xFF60A5FA),
                      ),
                      // Tarifa
                      if (hasRate)
                        _infoChip(
                          icon: Icons.attach_money,
                          label: '\$$payRate $currency',
                          color: Color(0xFF4ADE80),
                        ),
                      // Inicio
                      if (startDateRaw.isNotEmpty &&
                          startDateRaw != 'No definido')
                        _infoChip(
                          icon: Icons.calendar_today,
                          label: _shortDate(startDateRaw),
                          color: Colors.white60,
                        ),
                    ],
                  ),
                ),
                // Indicador de tap
                Icon(Icons.chevron_right, color: Colors.white24, size: 18),
              ],
            ),
          ],
        ),
      ), // Container
    ); // GestureDetector
  }

  Widget _infoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 11),
          SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _shortDate(String date) {
    try {
      final dt = DateTime.parse(date);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      if (date.length > 10) return date.substring(0, 10);
      return date;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // METRIC CARD — rediseñada compacta y elegante
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildMetricCard(String title, dynamic value, String subtitle,
      Color color, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFF30363D), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Ícono
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          SizedBox(width: 10),
          // Textos
          Expanded(
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
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[300],
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle.isNotEmpty) ...[
                  SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 9,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // EVENT CARD
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildEventCard(Map<String, dynamic> event) {
    final status = event['status']?.toString() ?? 'ACTIVO';
    final isActive = status == 'ACTIVO' || status == 'ACTIVE';
    final statusColor = isActive ? Colors.green[400]! : Colors.grey[400]!;

    String dayText = '--';
    String monthText = '---';
    if (event['start_date'] != null) {
      try {
        final dt = DateTime.parse(event['start_date']);
        const months = [
          'ENE',
          'FEB',
          'MAR',
          'ABR',
          'MAY',
          'JUN',
          'JUL',
          'AGO',
          'SEP',
          'OCT',
          'NOV',
          'DIC'
        ];
        dayText = dt.day.toString();
        monthText = months[dt.month - 1];
      } catch (_) {}
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
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
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue[900]!.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[400]!, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(dayText,
                        style: TextStyle(
                            color: Colors.blue[400],
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                    SizedBox(width: 4),
                    Text(monthText,
                        style:
                            TextStyle(color: Colors.blue[300], fontSize: 11)),
                  ],
                ),
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
                        fontSize: 9,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(event['title'],
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.location_on_outlined,
                  color: Colors.grey[400], size: 14),
              SizedBox(width: 6),
              Expanded(
                child: Text(event['location'],
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          if (event['role'] != null && event['role'].toString().isNotEmpty) ...[
            SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.work_outline, color: Colors.grey[400], size: 14),
                SizedBox(width: 6),
                Expanded(
                  child: Text(event['role'],
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // NOTIFICACIONES
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildNotificationBell() {
    final unreadCount = Provider.of<NotificationProvider>(context).unreadCount;
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Stack(
      children: [
        IconButton(
          icon: Icon(Icons.notifications_outlined,
              color: Colors.white, size: isMobile ? 22 : 24),
          onPressed: () =>
              setState(() => _showNotifications = !_showNotifications),
        ),
        if (unreadCount > 0)
          Positioned(
            right: isMobile ? 6 : 8,
            top: isMobile ? 6 : 8,
            child: Container(
              padding: EdgeInsets.all(isMobile ? 2 : 4),
              decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(isMobile ? 8 : 10)),
              constraints: BoxConstraints(
                  minWidth: isMobile ? 14 : 16, minHeight: isMobile ? 14 : 16),
              child: Text(
                unreadCount > 9 ? '9+' : '$unreadCount',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: isMobile ? 8 : 10,
                    fontWeight: FontWeight.bold),
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
                spreadRadius: 5)
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                  border: Border(
                      bottom: BorderSide(color: Color(0xFF30363D), width: 1))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Notificaciones',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  if (notificationProvider.unreadCount > 0)
                    TextButton(
                      onPressed: notificationProvider.markAsRead,
                      child: Text('Marcar leídas',
                          style:
                              TextStyle(color: Colors.blue[400], fontSize: 12)),
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
                          Icon(Icons.notifications_none,
                              color: Colors.grey[600], size: 40),
                          SizedBox(height: 8),
                          Text('No hay notificaciones',
                              style: TextStyle(color: Colors.grey[500])),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: notificationProvider.notifications.length,
                      itemBuilder: (context, index) => _buildNotificationItem(
                          notificationProvider.notifications[index]),
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
          border:
              Border(bottom: BorderSide(color: Color(0xFF30363D), width: 1))),
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
        title: Text(notification.title ?? 'Notificación',
            style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text(notification.body ?? '',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            SizedBox(height: 4),
            Text(_formatTimeAgo(notification.timestamp ?? DateTime.now()),
                style: TextStyle(color: Colors.grey[600], fontSize: 10)),
          ],
        ),
        onTap: () {
          if (notification.route != null) {
            Navigator.pushNamed(context, notification.route!,
                arguments: notification.parameters);
          }
        },
      ),
    );
  }

  String _formatTimeAgo(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    return DateFormat('dd/MM/yyyy').format(time);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // HEADER
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildHeader(bool isMobile) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            'Resumen Operativo',
            style: TextStyle(
              color: Colors.white,
              fontSize: isMobile ? 18 : 28,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Row(
          children: [
            _buildNotificationBell(),
            IconButton(
              icon: Icon(Icons.refresh,
                  color: Colors.white, size: isMobile ? 20 : 24),
              onPressed: _loadDashboardData,
              tooltip: 'Actualizar',
            ),
          ],
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 900;
    final eventsToShow =
        _upcomingEvents.isNotEmpty ? _upcomingEvents : _myEvents;

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
                : GestureDetector(
                    // Cerrar notificaciones al tocar cualquier parte de la pantalla
                    onTap: () {
                      if (_showNotifications) {
                        setState(() => _showNotifications = false);
                      }
                    },
                    behavior: HitTestBehavior.translucent,
                    child: Stack(
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
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _buildUrgentBanner(),
                                            SizedBox(height: 16),

                                            // KPI — columna compacta
                                            Column(
                                              children: [
                                                _buildMetricCard(
                                                  'Total de llamados',
                                                  _dashboardData[
                                                      'total_events'],
                                                  'Activos: ${_dashboardData['active_events']}  •  Finalizados: ${_dashboardData['finished_events']}',
                                                  Color(0xFF4ADE80),
                                                  Icons.event_note_outlined,
                                                ),
                                                SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: _buildMetricCard(
                                                        'Aceptación',
                                                        '${_dashboardData['acceptance_rate']}%',
                                                        'Tasa',
                                                        Color(0xFF60A5FA),
                                                        Icons.thumb_up_outlined,
                                                      ),
                                                    ),
                                                    SizedBox(width: 8),
                                                    Expanded(
                                                      child: _buildMetricCard(
                                                        'Perfil',
                                                        '${_dashboardData['profile_completion']}%',
                                                        'Completado',
                                                        Color(0xFFC084FC),
                                                        Icons.person_outline,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),

                                            SizedBox(height: 20),

                                            Text('Mis llamados',
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 16,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                            SizedBox(height: 12),

                                            if (eventsToShow.isEmpty)
                                              Container(
                                                padding: EdgeInsets.all(20),
                                                decoration: BoxDecoration(
                                                  color: Color(0xFF161B22),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                      color: Color(0xFF30363D),
                                                      width: 1),
                                                ),
                                                child: Center(
                                                  child: Column(
                                                    children: [
                                                      Icon(
                                                          Icons
                                                              .event_available_outlined,
                                                          color:
                                                              Colors.grey[600],
                                                          size: 36),
                                                      SizedBox(height: 10),
                                                      Text(
                                                          'No tienes llamados confirmados',
                                                          style: TextStyle(
                                                              color: Colors
                                                                  .grey[400],
                                                              fontSize: 13),
                                                          textAlign:
                                                              TextAlign.center),
                                                      SizedBox(height: 4),
                                                      Text(
                                                          'Cuando te asignen a llamados, aparecerán aquí',
                                                          style: TextStyle(
                                                              color: Colors
                                                                  .grey[600],
                                                              fontSize: 11),
                                                          textAlign:
                                                              TextAlign.center),
                                                    ],
                                                  ),
                                                ),
                                              )
                                            else
                                              Column(
                                                children: eventsToShow
                                                    .map((event) =>
                                                        _buildEventCard(event))
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
                    ), // Stack
                  ), // GestureDetector
      ),
    );
  }
}
