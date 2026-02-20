import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../auth_provider.dart';

class FreelancerActivationsScreen extends StatefulWidget {
  const FreelancerActivationsScreen({Key? key}) : super(key: key);

  @override
  State<FreelancerActivationsScreen> createState() =>
      _FreelancerActivationsScreenState();
}

class _FreelancerActivationsScreenState
    extends State<FreelancerActivationsScreen> {
  List<dynamic> activations = [];
  Map<String, dynamic> _interviewsByPositionId = {};
  bool isLoading = true;
  String? selectedStatus;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchAll();
  }

  Future<void> fetchAll({String? status}) async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      await Future.wait([
        _fetchInterviews(),
        _fetchActivationsOnly(status: status),
      ]);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _fetchInterviews() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.accessToken;
      final baseUrl = dotenv.env['API_BASE_URL'];
      if (token == null || baseUrl == null) return;

      final response = await http.get(
        Uri.parse('$baseUrl/interviews/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          final map = <String, dynamic>{};
          for (final interview in data) {
            final posId = interview['event_position_id']?.toString() ?? '';
            if (posId.isEmpty) continue;
            if (!map.containsKey(posId)) {
              map[posId] = interview;
            } else {
              final existing =
                  DateTime.tryParse(map[posId]['created_at'] ?? '') ??
                      DateTime.fromMillisecondsSinceEpoch(0);
              final newer = DateTime.tryParse(interview['created_at'] ?? '') ??
                  DateTime.fromMillisecondsSinceEpoch(0);
              if (newer.isAfter(existing)) map[posId] = interview;
            }
          }
          _interviewsByPositionId = map;
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchActivationsOnly({String? status}) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.accessToken;

      if (token == null) {
        setState(() {
          errorMessage = 'No hay token de autenticación';
        });
        return;
      }

      final baseUrl = dotenv.env['API_BASE_URL'];
      if (baseUrl == null) {
        setState(() {
          errorMessage = 'API_BASE_URL no configurada en .env';
        });
        return;
      }

      final queryParams = <String>[];
      if (status != null && status.isNotEmpty)
        queryParams.add('status=$status');
      queryParams.add('limit=50');

      final queryString =
          queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';
      final url = Uri.parse('$baseUrl/activations/me$queryString');

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        activations = data is List ? data : [];
      } else if (response.statusCode == 204) {
        activations = [];
      } else if (response.statusCode == 401) {
        setState(() {
          errorMessage =
              'Sesión expirada. Por favor, inicia sesión nuevamente.';
        });
        authProvider.logout();
      } else if (response.statusCode == 403) {
        setState(() {
          errorMessage =
              'No tienes permisos para acceder a estas activaciones.';
        });
      } else {
        setState(() {
          errorMessage = 'Error ${response.statusCode}: ${response.body}';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error de conexión: $e';
      });
    }
  }

  Future<bool> respondToActivation(String activationId, String action,
      {String? reason}) async {
    try {
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
      if (response.statusCode == 404)
        throw Exception('Activación no encontrada');
      if (response.statusCode == 422) {
        final responseBody = json.decode(response.body);
        final errors = responseBody['detail'] as List?;
        if (errors != null && errors.isNotEmpty)
          throw Exception(errors.first['msg'] ?? 'Error de validación');
        throw Exception('Error de validación');
      }
      if (response.statusCode == 400) {
        throw Exception(
            json.decode(response.body)['message'] ?? 'Error al responder');
      }
      throw Exception('Error ${response.statusCode}: ${response.body}');
    } catch (e) {
      rethrow;
    }
  }

  Map<String, dynamic> parseActivation(dynamic raw) {
    String str(dynamic v, [String fallback = '']) =>
        v != null ? v.toString() : fallback;

    final event =
        raw['event'] is Map ? raw['event'] as Map : <String, dynamic>{};
    final positionObj =
        raw['position'] is Map ? raw['position'] as Map : <String, dynamic>{};

    final positionText = str(raw['role_name']).isNotEmpty
        ? str(raw['role_name'])
        : str(positionObj['role']).isNotEmpty
            ? str(positionObj['role'])
            : str(positionObj['name']).isNotEmpty
                ? str(positionObj['name'])
                : 'Sin posición';

    final eventName = str(event['title']).isNotEmpty
        ? str(event['title'])
        : str(event['name']).isNotEmpty
            ? str(event['name'])
            : 'Sin nombre';

    final orgName = str(raw['organization_name']).isNotEmpty
        ? str(raw['organization_name'])
        : str(event['organization_name']);

    final payRate = raw['pay_rate'] != null ? raw['pay_rate'] : 0;
    final currency = str(raw['currency'], 'USD');

    final rawStatus = str(raw['status'], 'UNKNOWN');
    final expireAtStr = str(raw['expire_at']);
    String effectiveStatus = rawStatus;
    if (rawStatus.toUpperCase() == 'PENDING' && expireAtStr.isNotEmpty) {
      try {
        if (DateTime.now().isAfter(DateTime.parse(expireAtStr)))
          effectiveStatus = 'EXPIRED';
      } catch (_) {}
    }

    final eventPositionId = str(raw['event_position_id']);
    final interviewFromApi =
        _interviewsByPositionId[eventPositionId] as Map? ?? <String, dynamic>{};

    final interviewId = str(interviewFromApi['id']);
    final interviewStatus = str(interviewFromApi['status']).isNotEmpty
        ? str(interviewFromApi['status'])
        : str(raw['interview_status']);
    final interviewScheduledAt =
        str(interviewFromApi['scheduled_at']).isNotEmpty
            ? str(interviewFromApi['scheduled_at'])
            : str(raw['interview_scheduled_at']);
    final interviewType = str(interviewFromApi['interview_type']).isNotEmpty
        ? str(interviewFromApi['interview_type'])
        : str(raw['interview_type'], 'Presencial');

    return {
      'id': str(raw['id'], 'N/A'),
      'event_id': str(raw['event_id']).isNotEmpty
          ? str(raw['event_id'])
          : str(event['id'], 'N/A'),
      'event_position_id': eventPositionId,
      'status': effectiveStatus,
      'strategy': str(raw['strategy']),
      'event_name': eventName,
      'organization_name': orgName,
      'position': positionText,
      'pay_rate': payRate,
      'currency': currency,
      'payment_terms': str(event['payment_terms_days'], '0'),
      'start_date': str(event['start_date'], 'No definido'),
      'end_date': str(event['end_date'], 'No definido'),
      'sent_at': str(raw['sent_at']),
      'expire_at': str(raw['expire_at']),
      'requires_documents': event['requires_documents'] ?? false,
      'requires_interview':
          event['requires_interview'] ?? raw['requires_interview'] ?? false,
      'requires_intervals': event['requires_intervals'] ?? false,
      'interview_id': interviewId,
      'interview_status': interviewStatus,
      'interview_scheduled_at': interviewScheduledAt,
      'interview_type': interviewType,
      'event': event,
      'position_info': positionObj,
      'interview': interviewFromApi,
    };
  }

  Color getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return const Color(0xFFFF9800);
      case 'ACTIVE':
      case 'PRODUCING':
      case 'CONFIRMED':
        return const Color(0xFF4CAF50);
      case 'REJECTED':
      case 'RECHAZADA':
      case 'DECLINED':
        return const Color(0xFFE53935);
      case 'EXPIRED':
      case 'EXPIRADO':
        return const Color(0xFF757575);
      default:
        return Colors.grey;
    }
  }

  IconData getStatusIcon(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return Icons.access_time;
      case 'ACTIVE':
      case 'PRODUCING':
      case 'CONFIRMED':
        return Icons.check_circle;
      case 'REJECTED':
      case 'RECHAZADA':
      case 'DECLINED':
        return Icons.cancel;
      case 'EXPIRED':
      case 'EXPIRADO':
        return Icons.schedule;
      default:
        return Icons.info;
    }
  }

  String getStatusText(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return 'Pendiente de confirmación';
      case 'ACTIVE':
        return 'Activa';
      case 'PRODUCING':
        return 'En producción';
      case 'CONFIRMED':
        return 'Confirmada';
      case 'REJECTED':
      case 'RECHAZADA':
        return 'Rechazada';
      case 'DECLINED':
        return 'Declinada';
      case 'EXPIRED':
      case 'EXPIRADO':
        return 'Expirada';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1F3D),
        elevation: 0,
        title: Row(children: [
          Icon(Icons.bolt,
              color: const Color(0xFFFFB800), size: isMobile ? 20 : 24),
          SizedBox(width: isMobile ? 6 : 8),
          Flexible(
            child: Text('Bandeja de Activaciones',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ),
        ]),
        actions: [
          if (!isLoading)
            IconButton(
              icon: Icon(Icons.refresh,
                  color: const Color(0xFFFFB800), size: isMobile ? 20 : 24),
              onPressed: () => fetchAll(status: selectedStatus),
            ),
        ],
      ),
      body: Column(children: [
        Container(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2942),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2A3F5F), width: 1),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedStatus,
                isExpanded: true,
                hint: Text('Filtrar por estado',
                    style: TextStyle(
                        color: Colors.white70, fontSize: isMobile ? 13 : 14)),
                dropdownColor: const Color(0xFF1A2942),
                style: TextStyle(
                    color: Colors.white, fontSize: isMobile ? 13 : 14),
                icon: Icon(Icons.arrow_drop_down,
                    color: Colors.white70, size: isMobile ? 20 : 24),
                items: const [
                  DropdownMenuItem(
                      value: null, child: Text('Todos los estados')),
                  DropdownMenuItem(value: 'PENDING', child: Text('Pendientes')),
                  DropdownMenuItem(value: 'ACTIVE', child: Text('Activas')),
                  DropdownMenuItem(
                      value: 'CONFIRMED', child: Text('Confirmadas')),
                  DropdownMenuItem(
                      value: 'REJECTED', child: Text('Rechazadas')),
                  DropdownMenuItem(
                      value: 'DECLINED', child: Text('Declinadas')),
                  DropdownMenuItem(value: 'EXPIRED', child: Text('Expiradas')),
                  DropdownMenuItem(
                      value: 'PRODUCING', child: Text('En producción')),
                ],
                onChanged: (value) {
                  setState(() => selectedStatus = value);
                  fetchAll(status: value);
                },
              ),
            ),
          ),
        ),
        if (!isLoading && activations.isNotEmpty)
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 16, vertical: isMobile ? 4 : 8),
            child: Row(children: [
              Icon(Icons.info_outline,
                  color: Colors.white60, size: isMobile ? 14 : 16),
              SizedBox(width: isMobile ? 6 : 8),
              Text('${activations.length} activación(es) encontrada(s)',
                  style: TextStyle(
                      color: Colors.white60, fontSize: isMobile ? 11 : 12)),
            ]),
          ),
        Expanded(
          child: isLoading
              ? Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                      const CircularProgressIndicator(color: Color(0xFFFFB800)),
                      const SizedBox(height: 16),
                      Text('Cargando activaciones...',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: isMobile ? 13 : 14)),
                    ]))
              : errorMessage != null
                  ? Center(
                      child: Padding(
                      padding: EdgeInsets.all(isMobile ? 20 : 24),
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline,
                                size: isMobile ? 48 : 64,
                                color: Colors.red[400]),
                            SizedBox(height: isMobile ? 12 : 16),
                            Text('Error al cargar activaciones',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: isMobile ? 16 : 18,
                                    fontWeight: FontWeight.bold)),
                            SizedBox(height: isMobile ? 6 : 8),
                            Text(errorMessage!,
                                style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: isMobile ? 12 : 14),
                                textAlign: TextAlign.center),
                            SizedBox(height: isMobile ? 20 : 24),
                            ElevatedButton.icon(
                              onPressed: () => fetchAll(status: selectedStatus),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Reintentar'),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFFB800),
                                  foregroundColor: Colors.black),
                            ),
                          ]),
                    ))
                  : activations.isEmpty
                      ? Center(
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                              Icon(Icons.inbox,
                                  size: isMobile ? 48 : 64,
                                  color: Colors.white24),
                              SizedBox(height: isMobile ? 12 : 16),
                              Text('No hay activaciones',
                                  style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: isMobile ? 14 : 16)),
                              SizedBox(height: isMobile ? 6 : 8),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                child: Text(
                                  selectedStatus != null
                                      ? 'No hay activaciones con estado: ${selectedStatus!.toLowerCase()}'
                                      : 'No tienes activaciones en este momento',
                                  style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: isMobile ? 11 : 12),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ]))
                      : RefreshIndicator(
                          onRefresh: () => fetchAll(status: selectedStatus),
                          color: const Color(0xFFFFB800),
                          backgroundColor: const Color(0xFF1A2942),
                          child: ListView.builder(
                            padding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 12 : 16,
                                vertical: isMobile ? 8 : 8),
                            itemCount: activations.length,
                            itemBuilder: (context, index) {
                              final activation =
                                  parseActivation(activations[index]);
                              return ActivationCard(
                                activation: activation,
                                getStatusColor: getStatusColor,
                                getStatusIcon: getStatusIcon,
                                getStatusText: getStatusText,
                                onStatusChanged: (_, __) =>
                                    fetchAll(status: selectedStatus),
                                respondToActivation: respondToActivation,
                                isMobile: isMobile,
                              );
                            },
                          ),
                        ),
        ),
      ]),
    );
  }
}

class ActivationCard extends StatelessWidget {
  final Map<String, dynamic> activation;
  final Color Function(String) getStatusColor;
  final IconData Function(String) getStatusIcon;
  final String Function(String) getStatusText;
  final Function(String activationId, String newStatus) onStatusChanged;
  final Future<bool> Function(String, String, {String? reason})
      respondToActivation;
  final bool isMobile;

  const ActivationCard({
    Key? key,
    required this.activation,
    required this.getStatusColor,
    required this.getStatusIcon,
    required this.getStatusText,
    required this.onStatusChanged,
    required this.respondToActivation,
    required this.isMobile,
  }) : super(key: key);

  String _shortDate(String date) {
    if (date.length > 10) return date.substring(0, 10);
    return date;
  }

  @override
  Widget build(BuildContext context) {
    String s(String key, [String fb = '']) => activation[key]?.toString() ?? fb;
    final status = s('status', 'UNKNOWN');
    final statusColor = getStatusColor(status);
    final eventName = s('event_name', 'Sin nombre');
    final position = s('position', 'Sin posición');
    final startDate = s('start_date', 'No definido');
    final endDate = s('end_date', 'No definido');
    final organizationName = s('organization_name');
    final payRate = activation['pay_rate'];
    final currency = s('currency', 'USD');

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ActivationDetailScreen(
              activation: activation,
              onStatusChanged: onStatusChanged,
              respondToActivation: respondToActivation,
            ),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: isMobile ? 10 : 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2942),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2A3F5F), width: 1),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Text(eventName,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: isMobile ? 14 : 15,
                            fontWeight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 8 : 10,
                      vertical: isMobile ? 4 : 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor, width: 1),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(getStatusIcon(status),
                        color: statusColor, size: isMobile ? 12 : 14),
                    SizedBox(width: isMobile ? 4 : 6),
                    Text(status.toUpperCase(),
                        style: TextStyle(
                            color: statusColor,
                            fontSize: isMobile ? 9 : 10,
                            fontWeight: FontWeight.bold)),
                  ]),
                ),
              ]),
              if (organizationName.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(organizationName,
                    style: TextStyle(
                        color: Colors.white70, fontSize: isMobile ? 11 : 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ]),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.work_outline,
                    color: Colors.white70, size: isMobile ? 16 : 18),
                SizedBox(width: isMobile ? 6 : 8),
                Expanded(
                    child: Text(position,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: isMobile ? 13 : 14,
                            fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis)),
              ]),
              SizedBox(height: isMobile ? 6 : 8),
              Row(children: [
                Icon(Icons.attach_money,
                    color: Colors.white70, size: isMobile ? 16 : 18),
                SizedBox(width: isMobile ? 6 : 8),
                Text('\$$payRate/$currency por día',
                    style: TextStyle(
                        color: const Color(0xFF4CAF50),
                        fontSize: isMobile ? 12 : 13,
                        fontWeight: FontWeight.w500)),
              ]),
              SizedBox(height: isMobile ? 8 : 10),
              Row(children: [
                Expanded(
                    child: _buildDateInfo(
                        icon: Icons.calendar_today,
                        label: 'Inicio',
                        value: _shortDate(startDate),
                        isMobile: isMobile)),
                const SizedBox(width: 12),
                Expanded(
                    child: _buildDateInfo(
                        icon: Icons.event,
                        label: 'Fin',
                        value: _shortDate(endDate),
                        isMobile: isMobile)),
              ]),
            ]),
          ),
          SizedBox(height: isMobile ? 10 : 12),
          Container(
            padding: EdgeInsets.all(isMobile ? 10 : 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F1F3D).withOpacity(0.5),
              borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12)),
            ),
            child: Row(children: [
              Icon(getStatusIcon(status),
                  color: statusColor, size: isMobile ? 14 : 16),
              SizedBox(width: isMobile ? 6 : 8),
              Expanded(
                  child: Text(getStatusText(status),
                      style: TextStyle(
                          color: Colors.white70, fontSize: isMobile ? 11 : 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis)),
              Icon(Icons.chevron_right,
                  color: Colors.white30, size: isMobile ? 18 : 20),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildDateInfo(
      {required IconData icon,
      required String label,
      required String value,
      required bool isMobile}) {
    return Row(children: [
      Icon(icon, color: Colors.white70, size: isMobile ? 14 : 16),
      SizedBox(width: isMobile ? 4 : 6),
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style:
                TextStyle(color: Colors.white60, fontSize: isMobile ? 9 : 10)),
        Text(value,
            style: TextStyle(color: Colors.white, fontSize: isMobile ? 11 : 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ])),
    ]);
  }
}

class ActivationDetailScreen extends StatefulWidget {
  final Map<String, dynamic> activation;
  final Function(String activationId, String newStatus) onStatusChanged;
  final Future<bool> Function(String, String, {String? reason})
      respondToActivation;

  const ActivationDetailScreen({
    Key? key,
    required this.activation,
    required this.onStatusChanged,
    required this.respondToActivation,
  }) : super(key: key);

  @override
  State<ActivationDetailScreen> createState() => _ActivationDetailScreenState();
}

class _ActivationDetailScreenState extends State<ActivationDetailScreen> {
  bool isUpdating = false;
  bool _isLoadingInterview = false;
  late String _localInterviewStatus;
  late String _resolvedInterviewId;
  late String activationId;
  bool _hasLoadedInitialData = false;

  @override
  void initState() {
    super.initState();
    activationId = widget.activation['id']?.toString() ?? '';
    _localInterviewStatus =
        widget.activation['interview_status']?.toString() ?? '';
    _resolvedInterviewId = widget.activation['interview_id']?.toString() ?? '';

    if (_resolvedInterviewId.isNotEmpty) {
      _hasLoadedInitialData = true;
    } else {
      _fetchInterviewForThisActivation();
    }
  }

  Future<void> _fetchInterviewForThisActivation() async {
    setState(() => _isLoadingInterview = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.accessToken;
      final baseUrl = dotenv.env['API_BASE_URL'];
      if (token == null || baseUrl == null) return;

      final res = await http.get(
        Uri.parse('$baseUrl/interviews/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data is List) {
          final eventPositionId =
              widget.activation['event_position_id']?.toString() ?? '';
          Map<String, dynamic>? match;
          DateTime? matchDate;
          for (final interview in data) {
            final posId = interview['event_position_id']?.toString() ?? '';
            if (posId == eventPositionId && posId.isNotEmpty) {
              final d = DateTime.tryParse(interview['created_at'] ?? '') ??
                  DateTime.fromMillisecondsSinceEpoch(0);
              if (match == null || d.isAfter(matchDate!)) {
                match = interview as Map<String, dynamic>;
                matchDate = d;
              }
            }
          }
          if (match != null && mounted) {
            setState(() {
              _resolvedInterviewId = match!['id']?.toString() ?? '';
              if (_localInterviewStatus.isEmpty) {
                _localInterviewStatus = match['status']?.toString() ?? '';
              }
              _hasLoadedInitialData = true;
            });
          } else {
            setState(() {
              _hasLoadedInitialData = true;
            });
          }
        }
      }
    } catch (_) {
      setState(() {
        _hasLoadedInitialData = true;
      });
    } finally {
      setState(() => _isLoadingInterview = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
      case 'PENDING_ACCEPT':
      case 'PENDING_FREELANCER_ACCEPT':
      case 'FREELANCER_REJECTED':
        return const Color(0xFFFF9800);
      case 'PENDING_SCHEDULE':
        return const Color(0xFF7B9FE0);
      case 'PROPOSED':
        return const Color(0xFF9C27B0);
      case 'SCHEDULED':
      case 'CONFIRMED':
      case 'ACCEPTED':
        return const Color(0xFF4CAF50);
      case 'REJECTED':
      case 'RECHAZADA':
      case 'DECLINED':
      case 'FAILED':
        return const Color(0xFFE53935);
      case 'EXPIRED':
      case 'EXPIRADO':
        return const Color(0xFF757575);
      default:
        return Colors.grey;
    }
  }

  String _formatDateTime(String dateTime) {
    if (dateTime.isEmpty ||
        dateTime == 'No definido' ||
        dateTime == 'No disponible') return 'No disponible';
    try {
      final date = DateTime.parse(dateTime).toLocal();
      const meses = [
        '',
        'enero',
        'febrero',
        'marzo',
        'abril',
        'mayo',
        'junio',
        'julio',
        'agosto',
        'septiembre',
        'octubre',
        'noviembre',
        'diciembre'
      ];
      const dias = [
        'lunes',
        'martes',
        'miércoles',
        'jueves',
        'viernes',
        'sábado',
        'domingo'
      ];
      final diaSemana = dias[date.weekday - 1];
      final mes = meses[date.month];
      final hora =
          date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
      final ampm = date.hour >= 12 ? 'p.m.' : 'a.m.';
      final minuto = date.minute.toString().padLeft(2, '0');
      return '$diaSemana, ${date.day} de $mes de ${date.year}, $hora:$minuto $ampm';
    } catch (_) {
      return dateTime;
    }
  }

  String _formatDateTimeShort(String dateTime) {
    if (dateTime.isEmpty) return 'No disponible';
    try {
      final date = DateTime.parse(dateTime).toLocal();
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateTime;
    }
  }

  String _formatStrategy(String strategy) {
    if (strategy.isEmpty) return 'No definida';
    return strategy
        .toLowerCase()
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  String _formatInterviewType(String type) {
    switch (type.toUpperCase()) {
      case 'PRESENCIAL':
      case 'IN_PERSON':
      case 'ONSITE':
        return 'Presencial';
      case 'VIRTUAL':
      case 'ONLINE':
      case 'REMOTE':
        return 'Virtual';
      case 'PHONE':
      case 'TELEFONICA':
        return 'Telefónica';
      default:
        return type.isNotEmpty ? type : 'Presencial';
    }
  }

  Future<bool> _respondToInterview(String interviewId, String action,
      {String? reason}) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.accessToken;
      final baseUrl = dotenv.env['API_BASE_URL'];

      if (token == null || baseUrl == null)
        throw Exception('No hay token de autenticación o URL base');

      final url = Uri.parse('$baseUrl/interviews/$interviewId/intent/respond');

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

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        return body['ok'] == true;
      }
      if (response.statusCode == 422) {
        final responseBody = json.decode(response.body);
        final errors = responseBody['detail'] as List?;
        if (errors != null && errors.isNotEmpty)
          throw Exception(errors.first['msg'] ?? 'Error de validación');
        throw Exception('Error de validación');
      }
      if (response.statusCode == 401) throw Exception('Sesión expirada');
      if (response.statusCode == 404)
        throw Exception('Entrevista no encontrada');
      throw Exception(json.decode(response.body)['message'] ??
          'Error ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> _respondToScheduleProposal(String interviewId, String action,
      {String? reason}) async {
    try {
      if (interviewId.isEmpty) {
        if (_resolvedInterviewId.isNotEmpty) {
          interviewId = _resolvedInterviewId;
        } else {
          await _fetchInterviewForThisActivation();
          if (_resolvedInterviewId.isEmpty) {
            throw Exception(
                'No se pudo obtener el ID de la entrevista. Por favor, recarga la pantalla.');
          }
          interviewId = _resolvedInterviewId;
        }
      }

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.accessToken;
      final baseUrl = dotenv.env['API_BASE_URL'];

      if (token == null || baseUrl == null)
        throw Exception('No hay token de autenticación o URL base');

      final url =
          Uri.parse('$baseUrl/interviews/$interviewId/schedule/respond');

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

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          _localInterviewStatus =
              action == 'ACCEPT' ? 'SCHEDULED' : 'FREELANCER_REJECTED';
        });
        return true;
      }

      if (response.statusCode == 404) {
        await _fetchInterviewForThisActivation();
        throw Exception(
            'La entrevista no fue encontrada. Se ha recargado la información.');
      }

      if (response.statusCode == 422) {
        final responseBody = json.decode(response.body);
        final errors = responseBody['detail'] as List?;
        if (errors != null && errors.isNotEmpty) {
          throw Exception(errors.first['msg'] ?? 'Error de validación');
        }
        throw Exception('Error de validación');
      }

      throw Exception('Error ${response.statusCode}: ${response.body}');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _handleAcceptActivation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2942),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(children: [
          Icon(Icons.check_circle, color: Color(0xFF4CAF50)),
          SizedBox(width: 8),
          Text('¿Aceptar activación?',
              style: TextStyle(color: Colors.white, fontSize: 16)),
        ]),
        content: const Text(
          'Estás a punto de aceptar esta activación. La empresa será notificada de tu confirmación.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar',
                  style: TextStyle(color: Colors.white60))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => isUpdating = true);
      try {
        final success = await widget.respondToActivation(
            widget.activation['id'], 'ACCEPT');
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('¡Activación aceptada exitosamente!'),
              backgroundColor: Color(0xFF4CAF50),
              duration: Duration(seconds: 2)));
          await Future.delayed(const Duration(milliseconds: 500));
          widget.onStatusChanged(activationId, 'CONFIRMED');
          if (mounted) Navigator.pop(context);
        }
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Error al aceptar: ${e.toString()}'),
              backgroundColor: const Color(0xFFE53935),
              duration: const Duration(seconds: 3)));
      } finally {
        if (mounted) setState(() => isUpdating = false);
      }
    }
  }

  Future<void> _handleAcceptInterview() async {
    final interviewId = _resolvedInterviewId.isNotEmpty
        ? _resolvedInterviewId
        : widget.activation['interview_id']?.toString() ?? '';

    if (interviewId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:
            Text('No se encontró la entrevista. Intenta recargar la pantalla.'),
        backgroundColor: Color(0xFFE53935),
        duration: Duration(seconds: 3),
      ));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2942),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(children: [
          Icon(Icons.event_available, color: Color(0xFF4CAF50)),
          SizedBox(width: 8),
          Text('¿Aceptar entrevista?',
              style: TextStyle(color: Colors.white, fontSize: 16)),
        ]),
        content: const Text(
          'Al aceptar, notificarás a la empresa tu disponibilidad para la entrevista. Ellos procederán a agendarte una fecha y hora.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar',
                  style: TextStyle(color: Colors.white60))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            child: const Text('Aceptar entrevista'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => isUpdating = true);
      try {
        final success = await _respondToInterview(interviewId, 'ACCEPT');
        if (success && mounted) {
          setState(() => _localInterviewStatus = 'PENDING_SCHEDULE');
          widget.onStatusChanged(activationId, 'PENDING_SCHEDULE');
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                '¡Entrevista aceptada! La empresa procederá a agendarte una fecha.'),
            backgroundColor: Color(0xFF4CAF50),
            duration: Duration(seconds: 3),
          ));
        }
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error al aceptar entrevista: ${e.toString()}'),
            backgroundColor: const Color(0xFFE53935),
            duration: const Duration(seconds: 3),
          ));
      } finally {
        if (mounted) setState(() => isUpdating = false);
      }
    }
  }

  Future<void> _handleDeclineInterview() async {
    final interviewId = _resolvedInterviewId.isNotEmpty
        ? _resolvedInterviewId
        : widget.activation['interview_id']?.toString() ?? '';

    if (interviewId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:
            Text('No se encontró la entrevista. Intenta recargar la pantalla.'),
        backgroundColor: Color(0xFFE53935),
        duration: Duration(seconds: 3),
      ));
      return;
    }

    String? declineReason;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2942),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(children: [
          Icon(Icons.event_busy, color: Color(0xFFE53935)),
          SizedBox(width: 8),
          Flexible(
              child: Text('No disponible para entrevista',
                  style: TextStyle(color: Colors.white, fontSize: 16))),
        ]),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  'Indícanos el motivo por el que no puedes asistir a la entrevista.',
                  style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              const Text('Razón (opcional):',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              TextField(
                onChanged: (value) => declineReason = value,
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Ej: No estoy disponible en ese horario',
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: const Color(0xFF0F1F3D),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF2A3F5F))),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF2A3F5F))),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE53935))),
                ),
              ),
            ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar',
                  style: TextStyle(color: Colors.white60))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            child: const Text('No disponible'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => isUpdating = true);
      try {
        final success = await _respondToInterview(interviewId, 'DECLINE',
            reason: declineReason);
        if (success && mounted) {
          setState(() => _localInterviewStatus = 'DECLINED');
          widget.onStatusChanged(activationId, 'REJECTED');
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Has rechazado la entrevista. La empresa ha sido notificada.'),
            backgroundColor: Color(0xFFE53935),
            duration: Duration(seconds: 3),
          ));
        }
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error al rechazar entrevista: ${e.toString()}'),
            backgroundColor: const Color(0xFFE53935),
            duration: const Duration(seconds: 3),
          ));
      } finally {
        if (mounted) setState(() => isUpdating = false);
      }
    }
  }

  Future<void> _handleAcceptScheduleProposal() async {
    if (_isLoadingInterview) {
      await Future.delayed(const Duration(milliseconds: 500));
    }

    final interviewId = _resolvedInterviewId.isNotEmpty
        ? _resolvedInterviewId
        : widget.activation['interview_id']?.toString() ?? '';

    if (interviewId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'No se encontró la entrevista. Intenta recargar la pantalla primero.'),
        backgroundColor: Color(0xFFE53935),
        duration: Duration(seconds: 4),
      ));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2942),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(children: [
          Icon(Icons.check_circle, color: Color(0xFF4CAF50)),
          SizedBox(width: 8),
          Flexible(
              child: Text('¿Aceptar horario?',
                  style: TextStyle(color: Colors.white, fontSize: 16))),
        ]),
        content: const Text(
          'Al aceptar, confirmarás tu disponibilidad en el horario propuesto por la empresa.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar',
                  style: TextStyle(color: Colors.white60))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            child: const Text('Aceptar horario'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => isUpdating = true);
      try {
        final success = await _respondToScheduleProposal(interviewId, 'ACCEPT');
        if (success && mounted) {
          setState(() => _localInterviewStatus = 'SCHEDULED');
          widget.onStatusChanged(activationId, _localInterviewStatus);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('¡Horario de entrevista aceptado exitosamente!'),
            backgroundColor: Color(0xFF4CAF50),
            duration: Duration(seconds: 3),
          ));
        }
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error al aceptar horario:\n${e.toString()}'),
            backgroundColor: const Color(0xFFE53935),
            duration: const Duration(seconds: 4),
          ));
      } finally {
        if (mounted) setState(() => isUpdating = false);
      }
    }
  }

  Future<void> _handleDeclineScheduleProposal() async {
    if (_isLoadingInterview) {
      await Future.delayed(const Duration(milliseconds: 500));
    }

    final interviewId = _resolvedInterviewId.isNotEmpty
        ? _resolvedInterviewId
        : widget.activation['interview_id']?.toString() ?? '';

    if (interviewId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'No se encontró la entrevista. Intenta recargar la pantalla primero.'),
        backgroundColor: Color(0xFFE53935),
        duration: Duration(seconds: 4),
      ));
      return;
    }

    String? declineReason;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2942),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(children: [
          Icon(Icons.event_busy, color: Color(0xFFE53935)),
          SizedBox(width: 8),
          Flexible(
              child: Text('¿Cambiar horario?',
                  style: TextStyle(color: Colors.white, fontSize: 16))),
        ]),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Indícanos por qué no puedes asistir a este horario.',
                  style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              const Text('Razón (opcional):',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              TextField(
                onChanged: (value) => declineReason = value,
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Ej: Tengo un conflicto de horario',
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: const Color(0xFF0F1F3D),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF2A3F5F))),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF2A3F5F))),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE53935))),
                ),
              ),
            ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar',
                  style: TextStyle(color: Colors.white60))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            child: const Text('Cambiar horario'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => isUpdating = true);
      try {
        final success = await _respondToScheduleProposal(interviewId, 'REJECT',
            reason: declineReason);
        if (success && mounted) {
          setState(() => _localInterviewStatus = 'FREELANCER_REJECTED');
          widget.onStatusChanged(activationId, _localInterviewStatus);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Cambio de horario solicitado. Esperando nueva propuesta de la empresa.'),
            backgroundColor: Color(0xFF7B9FE0),
            duration: Duration(seconds: 3),
          ));
        }
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error al cambiar horario:\n${e.toString()}'),
            backgroundColor: const Color(0xFFE53935),
            duration: const Duration(seconds: 4),
          ));
      } finally {
        if (mounted) setState(() => isUpdating = false);
      }
    }
  }

  Future<void> _handleRejectActivation() async {
    String? declineReason;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2942),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('¿Rechazar activación?',
            style: TextStyle(color: Colors.white)),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  'Estás a punto de rechazar esta activación. La empresa será notificada de tu rechazo.',
                  style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              const Text('Razón (opcional):',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              TextField(
                onChanged: (value) => declineReason = value,
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Ej: No estoy disponible en esa fecha',
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: const Color(0xFF0F1F3D),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF2A3F5F))),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF2A3F5F))),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE53935))),
                ),
              ),
            ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar',
                  style: TextStyle(color: Colors.white60))),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  foregroundColor: Colors.white),
              child: const Text('Rechazar')),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => isUpdating = true);
      try {
        final success = await widget.respondToActivation(
            widget.activation['id'], 'DECLINE',
            reason: declineReason);
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Activación rechazada'),
              backgroundColor: Color(0xFFE53935),
              duration: Duration(seconds: 2)));
          await Future.delayed(const Duration(milliseconds: 500));
          widget.onStatusChanged(activationId, 'REJECTED');
          if (mounted) Navigator.pop(context);
        }
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Error al rechazar: ${e.toString()}'),
              backgroundColor: const Color(0xFFE53935),
              duration: const Duration(seconds: 3)));
      } finally {
        if (mounted) setState(() => isUpdating = false);
      }
    }
  }

  bool _isInterviewResponded(String interviewStatus) {
    switch (interviewStatus.toUpperCase()) {
      case 'ACCEPTED':
      case 'DECLINED':
      case 'FAILED':
      case 'REJECTED':
      case 'CONFIRMED':
      case 'SCHEDULED':
        return true;
      default:
        return false;
    }
  }

  bool _isInterviewAccepted(String interviewStatus) {
    switch (interviewStatus.toUpperCase()) {
      case 'ACCEPTED':
      case 'PENDING_SCHEDULE':
      case 'PROPOSED':
      case 'SCHEDULED':
      case 'CONFIRMED':
        return true;
      default:
        return false;
    }
  }

  bool _isInterviewDeclined(String interviewStatus) {
    switch (interviewStatus.toUpperCase()) {
      case 'DECLINED':
      case 'FAILED':
      case 'REJECTED':
        return true;
      default:
        return false;
    }
  }

  bool _isPendingSchedule(String interviewStatus) {
    return interviewStatus.toUpperCase() == 'PENDING_SCHEDULE' ||
        interviewStatus.toUpperCase() == 'FREELANCER_REJECTED';
  }

  bool _isProposed(String interviewStatus) {
    return interviewStatus.toUpperCase() == 'PROPOSED';
  }

  bool _isScheduled(String interviewStatus) {
    return interviewStatus.toUpperCase() == 'SCHEDULED';
  }

  String _interviewStatusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING_FREELANCER_ACCEPT':
      case 'PENDING_ACCEPT':
      case 'PENDING':
        return 'PENDIENTE ACEPTAR';
      case 'PENDING_SCHEDULE':
        return 'ESPERANDO PROPUESTA DE HORARIO';
      case 'PROPOSED':
        return 'HORARIO PROPUESTO';
      case 'FREELANCER_REJECTED':
        return 'ESPERANDO NUEVO HORARIO';
      case 'SCHEDULED':
        return 'ENTREVISTA AGENDADA';
      case 'ACCEPTED':
      case 'ACCEPT':
        return 'ACEPTADA';
      case 'DECLINED':
      case 'DECLINE':
        return 'RECHAZADA';
      case 'FAILED':
        return 'FALLIDA';
      case 'CONFIRMED':
        return 'CONFIRMADA';
      default:
        return status.isNotEmpty ? status.toUpperCase() : 'PENDIENTE ACEPTAR';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final a = widget.activation;
    String s(String key, [String fb = '']) => a[key]?.toString() ?? fb;
    bool bv(String key) {
      final v = a[key];
      if (v == null) return false;
      if (v is bool) return v;
      return v.toString().toLowerCase() == 'true';
    }

    final rawStatus = s('status', 'UNKNOWN');
    final expireAtStr = s('expire_at');
    final status = () {
      if (rawStatus.toUpperCase() == 'PENDING' && expireAtStr.isNotEmpty) {
        try {
          if (DateTime.now().isAfter(DateTime.parse(expireAtStr)))
            return 'EXPIRED';
        } catch (_) {}
      }
      return rawStatus;
    }();
    final statusColor = _getStatusColor(status);
    final requiresInterview = bv('requires_interview');
    final interviewId = s('interview_id');
    final interviewStatus = _localInterviewStatus.isNotEmpty
        ? _localInterviewStatus
        : s('interview_status');
    final interviewScheduledAt = s('interview_scheduled_at');
    final interviewType = s('interview_type', 'Presencial');
    final interviewOnlineLink = s('interview_online_meeting_link');
    final interviewOnSiteAddress = s('interview_onsite_address');
    final interviewNotes = s('interview_notes');
    final interviewResponded = _isInterviewResponded(interviewStatus);
    final interviewAccepted = _isInterviewAccepted(interviewStatus);
    final interviewDeclined = _isInterviewDeclined(interviewStatus);

    final isPendingFreelancerAccept =
        interviewStatus.toUpperCase() == 'PENDING_FREELANCER_ACCEPT';
    final isPendingSchedule = _isPendingSchedule(interviewStatus);
    final isProposed = _isProposed(interviewStatus);
    final isScheduled = _isScheduled(interviewStatus);

    // ────────────────────────────────────────────────
    // LÓGICA DEL BLOQUE DE ENTREVISTA
    // ────────────────────────────────────────────────
    Widget interviewWidget;
    if (_isLoadingInterview && !_hasLoadedInitialData) {
      interviewWidget = Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              color: Color(0xFF7B9FE0),
              strokeWidth: 2,
            ),
          ),
        ),
      );
    } else if (isPendingSchedule) {
      interviewWidget =
          _buildPendingScheduleBlock(isMobile, interviewStatus);
    } else if (isProposed) {
      interviewWidget = _buildScheduleProposalBlock(
        isMobile: isMobile,
        interviewId: _resolvedInterviewId.isNotEmpty
            ? _resolvedInterviewId
            : interviewId,
        scheduledAt: interviewScheduledAt,
        interviewType: interviewType,
        onlineLink: interviewOnlineLink,
        onSiteAddress: interviewOnSiteAddress,
        notes: interviewNotes,
        status: interviewStatus,
        isAccepted: isScheduled,
        isDeclined: interviewDeclined,
      );
    } else if (isScheduled) {
      interviewWidget = _buildScheduleAcceptedPanel(isMobile);
    } else {
      interviewWidget = _buildInterviewBlock(
        isMobile: isMobile,
        interviewId: _resolvedInterviewId.isNotEmpty
            ? _resolvedInterviewId
            : interviewId,
        interviewStatus: interviewStatus,
        interviewScheduledAt: interviewScheduledAt,
        interviewType: interviewType,
        interviewDeclined: interviewDeclined,
        interviewAccepted: interviewAccepted,
        interviewResponded: interviewResponded,
        isPendingFreelancerAccept: isPendingFreelancerAccept,
      );
    }

    // ────────────────────────────────────────────────
    // LÓGICA DE BOTONES DE ACTIVACIÓN (sin entrevista)
    // ────────────────────────────────────────────────
    // Cuando NO requiere entrevista y status == PENDING → mostrar Aceptar + Rechazar
    // Cuando SÍ requiere entrevista y aún está pendiente de aceptarla → solo mensaje informativo
    // Cuando SÍ requiere entrevista y ya respondió → mostrar Rechazar activación
    Widget activationButtons = const SizedBox.shrink();

    if (status == 'PENDING') {
      if (!requiresInterview) {
        // Sin entrevista: dos botones lado a lado
        activationButtons = Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: isUpdating ? null : _handleRejectActivation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                      vertical: isMobile ? 14 : 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                    isUpdating ? 'Procesando...' : 'Rechazar',
                    style: TextStyle(fontSize: isMobile ? 13 : 14)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: isUpdating ? null : _handleAcceptActivation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                      vertical: isMobile ? 14 : 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                    isUpdating ? 'Procesando...' : 'Aceptar Activación',
                    style: TextStyle(fontSize: isMobile ? 13 : 14)),
              ),
            ),
          ],
        );
      } else if (isPendingFreelancerAccept) {
        // Con entrevista, pendiente de aceptarla: aviso
        activationButtons = Container(
          width: double.infinity,
          padding: EdgeInsets.all(isMobile ? 14 : 16),
          decoration: BoxDecoration(
            color: const Color(0xFFFF9800).withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: const Color(0xFFFF9800).withOpacity(0.4), width: 1),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline,
                color: const Color(0xFFFF9800),
                size: isMobile ? 18 : 20),
            const SizedBox(width: 10),
            Expanded(
                child: Text(
                    'Acepta la solicitud de entrevista para que la empresa pueda agendarte una fecha y hora.',
                    style: TextStyle(
                        color: const Color(0xFFFF9800),
                        fontSize: isMobile ? 12 : 13))),
          ]),
        );
      } else {
        // Con entrevista ya respondida: solo botón de rechazar activación
        activationButtons = Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: isUpdating ? null : _handleRejectActivation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                      vertical: isMobile ? 14 : 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                    isUpdating ? 'Procesando...' : 'Rechazar Activación',
                    style: TextStyle(fontSize: isMobile ? 13 : 14)),
              ),
            ),
          ],
        );
      }
    } else if (status.toUpperCase() == 'EXPIRED' ||
        status.toUpperCase() == 'EXPIRADO') {
      activationButtons = Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
            vertical: isMobile ? 14 : 16, horizontal: 16),
        decoration: BoxDecoration(
            color: const Color(0xFF757575).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: const Color(0xFF757575).withOpacity(0.4), width: 1)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.schedule,
              color: Colors.grey[500], size: isMobile ? 16 : 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(
                  'Esta activación ha expirado y ya no puede ser aceptada o rechazada.',
                  style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: isMobile ? 12 : 13),
                  textAlign: TextAlign.center)),
        ]),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1F3D),
        elevation: 0,
        title: Text('Detalles de Activación',
            style: TextStyle(
                color: Colors.white,
                fontSize: isMobile ? 16 : 18,
                fontWeight: FontWeight.w600)),
        leading: IconButton(
            icon: Icon(Icons.arrow_back,
                color: Colors.white, size: isMobile ? 20 : 24),
            onPressed: () => Navigator.pop(context)),
      ),
      body: Stack(children: [
        SingleChildScrollView(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── HEADER ──────────────────────────────────────────────────────
            Container(
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              decoration: const BoxDecoration(
                  color: Color(0xFF1A2942),
                  border:
                      Border(bottom: BorderSide(color: Color(0xFF2A3F5F)))),
              child: Row(children: [
                Container(
                    width: isMobile ? 4 : 6,
                    height: isMobile ? 40 : 60,
                    decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(3))),
                SizedBox(width: isMobile ? 12 : 20),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(s('event_name', 'Sin nombre'),
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: isMobile ? 18 : 22,
                              fontWeight: FontWeight.bold)),
                      if (s('organization_name').isNotEmpty)
                        Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(s('organization_name'),
                                style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: isMobile ? 12 : 14))),
                    ])),
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 10 : 16,
                      vertical: isMobile ? 6 : 8),
                  decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor, width: 1)),
                  child: Text(
                      requiresInterview
                          ? _interviewStatusLabel(interviewStatus)
                          : status.toUpperCase(),
                      style: TextStyle(
                          color: statusColor,
                          fontSize: isMobile ? 10 : 12,
                          fontWeight: FontWeight.bold)),
                ),
              ]),
            ),

            // ── CONTENIDO ───────────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Bloque de entrevista (solo si la requiere)
                    if (requiresInterview) ...[
                      interviewWidget,
                      SizedBox(height: isMobile ? 16 : 24),
                    ],

                    // Información General
                    _buildInfoSection(
                        title: 'Información General',
                        icon: Icons.info_outline,
                        isMobile: isMobile,
                        children: [
                          _buildInfoRow(
                              icon: Icons.fingerprint,
                              label: 'ID del Evento',
                              value: s('event_id', 'N/A'),
                              isMobile: isMobile,
                              monospace: true),
                          _buildInfoRow(
                              icon: Icons.settings,
                              label: 'Estrategia',
                              value: _formatStrategy(s('strategy')),
                              isMobile: isMobile),
                          _buildInfoRow(
                              icon: Icons.work,
                              label: 'Posición',
                              value: s('position', 'Sin posición'),
                              isMobile: isMobile),
                          _buildInfoRow(
                              icon: Icons.attach_money,
                              label: 'Tarifa',
                              value:
                                  '\$${a['pay_rate'] ?? 0} ${s('currency', 'USD')} por día',
                              valueColor: const Color(0xFF4CAF50),
                              isMobile: isMobile),
                          _buildInfoRow(
                              icon: Icons.receipt_long_rounded,
                              label: 'Términos de Pago',
                              value: 'Net ${s('payment_terms', '0')} días',
                              valueColor: const Color(0xFF4CAF50),
                              isMobile: isMobile),
                        ]),
                    SizedBox(height: isMobile ? 16 : 24),

                    // Fechas
                    _buildInfoSection(
                        title: 'Fechas',
                        icon: Icons.date_range_rounded,
                        isMobile: isMobile,
                        children: [
                          _buildInfoRow(
                              icon: Icons.event_available_rounded,
                              label: 'Fecha de Inicio',
                              value: _formatDateTimeShort(s('start_date')),
                              isMobile: isMobile),
                          _buildInfoRow(
                              icon: Icons.event_busy_rounded,
                              label: 'Fecha de Fin',
                              value: _formatDateTimeShort(s('end_date')),
                              isMobile: isMobile),
                          _buildInfoRow(
                              icon: Icons.outgoing_mail,
                              label: 'Enviado el',
                              value: _formatDateTimeShort(s('sent_at')),
                              isMobile: isMobile),
                          _buildInfoRow(
                              icon: Icons.hourglass_bottom_rounded,
                              label: 'Expira el',
                              value: _formatDateTimeShort(s('expire_at')),
                              valueColor: s('expire_at').isNotEmpty
                                  ? const Color(0xFFFF9800)
                                  : null,
                              isMobile: isMobile),
                        ]),
                    SizedBox(height: isMobile ? 16 : 24),

                    // Requisitos
                    _buildInfoSection(
                        title: 'Requisitos',
                        icon: Icons.checklist_rtl_rounded,
                        isMobile: isMobile,
                        children: [
                          _buildInfoRow(
                              icon: Icons.folder_copy_outlined,
                              label: 'Requiere Documentos',
                              value: bv('requires_documents') ? 'Sí' : 'No',
                              valueColor: bv('requires_documents')
                                  ? const Color(0xFF4CAF50)
                                  : const Color(0xFFE53935),
                              isMobile: isMobile),
                          _buildInfoRow(
                              icon: Icons.groups_2_outlined,
                              label: 'Requiere Entrevista',
                              value: requiresInterview ? 'Sí' : 'No',
                              valueColor: requiresInterview
                                  ? const Color(0xFF4CAF50)
                                  : const Color(0xFFE53935),
                              isMobile: isMobile),
                          _buildInfoRow(
                              icon: Icons.splitscreen_outlined,
                              label: 'Requiere Intervalos',
                              value: bv('requires_intervals') ? 'Sí' : 'No',
                              valueColor: bv('requires_intervals')
                                  ? const Color(0xFF4CAF50)
                                  : const Color(0xFFE53935),
                              isMobile: isMobile),
                        ]),
                    SizedBox(height: isMobile ? 24 : 32),

                    // ── BOTONES DE ACCIÓN ──────────────────────────────────
                    activationButtons,
                    const SizedBox(height: 32),
                  ]),
            ),
          ]),
        ),
        if (isUpdating)
          Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                  child:
                      CircularProgressIndicator(color: Color(0xFFFFB800)))),
      ]),
    );
  }

  // ── WIDGETS DE ENTREVISTA ────────────────────────────────────────────────

  Widget _buildPendingScheduleBlock(bool isMobile, String status) {
    final isRejected = status.toUpperCase() == 'FREELANCER_REJECTED';
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
          vertical: isMobile ? 12 : 16, horizontal: isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFF7B9FE0).withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: const Color(0xFF7B9FE0).withOpacity(0.4), width: 1),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.access_time,
            color: const Color(0xFF7B9FE0), size: isMobile ? 20 : 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              isRejected
                  ? 'HORARIO RECHAZADO'
                  : 'ESPERANDO PROPUESTA DE HORARIO',
              style: TextStyle(
                  color: const Color(0xFF7B9FE0),
                  fontSize: isMobile ? 13 : 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5),
            ),
            const SizedBox(height: 4),
            Text(
              isRejected
                  ? 'Has solicitado un cambio de horario. Esperando que la empresa proponga una nueva fecha.'
                  : 'Has aceptado la entrevista. La empresa está configurando un horario para la reunión.',
              style:
                  TextStyle(color: Colors.white70, fontSize: isMobile ? 12 : 13),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildScheduleProposalBlock({
    required bool isMobile,
    required String interviewId,
    required String scheduledAt,
    required String interviewType,
    required String onlineLink,
    required String onSiteAddress,
    required String notes,
    required String status,
    required bool isAccepted,
    required bool isDeclined,
  }) {
    final scheduledText =
        scheduledAt.isNotEmpty ? _formatDateTime(scheduledAt) : 'Por definir';
    final typeText = _formatInterviewType(interviewType);
    final statusColor = isAccepted
        ? const Color(0xFF4CAF50)
        : isDeclined
            ? const Color(0xFFE53935)
            : const Color(0xFF9C27B0);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A2942),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: statusColor.withOpacity(0.5), width: 1),
        ),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 14 : 18),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(children: [
              Icon(Icons.event_note_rounded,
                  color: statusColor, size: isMobile ? 18 : 20),
              const SizedBox(width: 8),
              Text('PROPUESTA DE HORARIO',
                  style: TextStyle(
                      color: statusColor,
                      fontSize: isMobile ? 12 : 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5)),
            ]),
            SizedBox(height: isMobile ? 14 : 16),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                Text('FECHA Y HORA',
                    style: TextStyle(
                        color: Colors.white60,
                        fontSize: isMobile ? 9 : 10,
                        letterSpacing: 0.5)),
                const SizedBox(height: 6),
                Text(scheduledText,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: isMobile ? 13 : 14,
                        fontWeight: FontWeight.w600)),
              ])),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                Text('TIPO',
                    style: TextStyle(
                        color: Colors.white60,
                        fontSize: isMobile ? 9 : 10,
                        letterSpacing: 0.5)),
                const SizedBox(height: 6),
                Text(typeText,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: isMobile ? 12 : 13,
                        fontWeight: FontWeight.w500)),
              ])),
            ]),
            if (interviewType.toUpperCase().contains('ONSITE') &&
                onSiteAddress.isNotEmpty) ...[
              SizedBox(height: isMobile ? 12 : 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('UBICACIÓN',
                    style: TextStyle(
                        color: Colors.white60,
                        fontSize: isMobile ? 9 : 10,
                        letterSpacing: 0.5)),
                const SizedBox(height: 6),
                Text(onSiteAddress,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: isMobile ? 12 : 13)),
              ]),
            ],
            if ((interviewType.toUpperCase().contains('ONLINE') ||
                    interviewType.toUpperCase().contains('VIRTUAL')) &&
                onlineLink.isNotEmpty) ...[
              SizedBox(height: isMobile ? 12 : 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('ENLACE DE REUNIÓN',
                    style: TextStyle(
                        color: Colors.white60,
                        fontSize: isMobile ? 9 : 10,
                        letterSpacing: 0.5)),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Enlace: $onlineLink'),
                      backgroundColor: Colors.blue,
                    ));
                  },
                  child: Text(onlineLink,
                      style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 12,
                          decoration: TextDecoration.underline)),
                ),
              ]),
            ],
            if (notes.isNotEmpty) ...[
              SizedBox(height: isMobile ? 12 : 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('NOTAS',
                    style: TextStyle(
                        color: Colors.white60,
                        fontSize: isMobile ? 9 : 10,
                        letterSpacing: 0.5)),
                const SizedBox(height: 6),
                Text(notes,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: isMobile ? 12 : 13)),
              ]),
            ],
          ]),
        ),
      ),
      SizedBox(height: isMobile ? 12 : 14),
      if (isAccepted)
        _buildScheduleAcceptedPanel(isMobile)
      else if (isDeclined)
        _buildScheduleDeclinedPanel(isMobile)
      else
        _buildScheduleProposalButtons(isMobile),
    ]);
  }

  Widget _buildScheduleAcceptedPanel(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 14 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50).withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: const Color(0xFF4CAF50).withOpacity(0.4), width: 1),
      ),
      child: Row(children: [
        const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 22),
        const SizedBox(width: 10),
        Expanded(
            child: Text('Has aceptado este horario de entrevista.',
                style: TextStyle(
                    color: const Color(0xFF4CAF50),
                    fontSize: isMobile ? 12 : 13))),
      ]),
    );
  }

  Widget _buildScheduleDeclinedPanel(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
          vertical: isMobile ? 20 : 24, horizontal: isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: const Color(0xFFE53935).withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: const Color(0xFFE53935).withOpacity(0.5), width: 1),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE53935), width: 2)),
          child: const Icon(Icons.close, color: Color(0xFFE53935), size: 28),
        ),
        const SizedBox(height: 12),
        Text('HORARIO RECHAZADO',
            style: TextStyle(
                color: const Color(0xFFE53935),
                fontSize: isMobile ? 13 : 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5),
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(
            'Se ha solicitado un cambio de horario. La empresa enviará una nueva propuesta.',
            style: TextStyle(
                color: Colors.white60, fontSize: isMobile ? 11 : 12),
            textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _buildInterviewBlock({
    required bool isMobile,
    required String interviewId,
    required String interviewStatus,
    required String interviewScheduledAt,
    required String interviewType,
    required bool interviewDeclined,
    required bool interviewAccepted,
    required bool interviewResponded,
    required bool isPendingFreelancerAccept,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A2942),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF3D5A99), width: 1),
        ),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 14 : 18),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.calendar_today,
                  color: const Color(0xFF7B9FE0), size: isMobile ? 18 : 20),
              const SizedBox(width: 8),
              Text('SOLICITUD DE ENTREVISTA',
                  style: TextStyle(
                      color: const Color(0xFF7B9FE0),
                      fontSize: isMobile ? 12 : 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5)),
            ]),
          ]),
        ),
      ),
      SizedBox(height: isMobile ? 12 : 14),
      if (interviewDeclined)
        _buildInterviewDeclinedPanel(isMobile)
      else if (isPendingFreelancerAccept)
        _buildInterviewActionButtons(isMobile),
    ]);
  }

  Widget _buildInterviewDeclinedPanel(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 14 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFFE53935).withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: const Color(0xFFE53935).withOpacity(0.4), width: 1),
      ),
      child: Row(children: [
        const Icon(Icons.cancel_outlined, color: Color(0xFFE53935), size: 22),
        const SizedBox(width: 10),
        Expanded(
            child: Text('Has rechazado la solicitud de entrevista.',
                style: TextStyle(
                    color: const Color(0xFFE53935),
                    fontSize: isMobile ? 12 : 13))),
      ]),
    );
  }

  Widget _buildInterviewActionButtons(bool isMobile) {
    return Row(children: [
      Expanded(
        child: GestureDetector(
          onTap: isUpdating ? null : _handleDeclineInterview,
          child: Container(
            height: isMobile ? 60 : 70,
            padding: EdgeInsets.symmetric(
                vertical: isMobile ? 8 : 10, horizontal: 4),
            decoration: BoxDecoration(
                color: const Color(0xFF1A2942),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: const Color(0xFF2A3F5F), width: 1)),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.cancel_outlined,
                  color: Colors.red[300], size: isMobile ? 20 : 22),
              const SizedBox(height: 4),
              Flexible(
                child: Text('NO DISPONIBLE',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: isMobile ? 11 : 12,
                        fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center),
              ),
            ]),
          ),
        ),
      ),
      SizedBox(width: isMobile ? 8 : 10),
      Expanded(
        child: GestureDetector(
          onTap: isUpdating ? null : _handleAcceptInterview,
          child: Container(
            height: isMobile ? 60 : 70,
            padding: EdgeInsets.symmetric(
                vertical: isMobile ? 8 : 10, horizontal: 4),
            decoration: BoxDecoration(
                color: const Color(0xFF2ECC71),
                borderRadius: BorderRadius.circular(8)),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.check_circle_outline,
                  color: Colors.white, size: isMobile ? 20 : 22),
              const SizedBox(height: 4),
              Flexible(
                child: Text('ACEPTAR ENTREVISTA',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: isMobile ? 11 : 12,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center),
              ),
            ]),
          ),
        ),
      ),
    ]);
  }

  Widget _buildScheduleProposalButtons(bool isMobile) {
    return Row(children: [
      Expanded(
          child: GestureDetector(
        onTap: isUpdating ? null : _handleDeclineScheduleProposal,
        child: Container(
          height: isMobile ? 60 : 70,
          padding: EdgeInsets.symmetric(
              vertical: isMobile ? 8 : 10, horizontal: 4),
          decoration: BoxDecoration(
              color: const Color(0xFF1A2942),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: const Color(0xFF2A3F5F), width: 1)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.sync_alt_rounded,
                color: Colors.orange[300], size: isMobile ? 20 : 22),
            const SizedBox(height: 4),
            Flexible(
              child: Text('CAMBIAR HORARIO',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: isMobile ? 11 : 12,
                      fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center),
            ),
          ]),
        ),
      )),
      const SizedBox(width: 10),
      Expanded(
          child: GestureDetector(
        onTap: isUpdating ? null : _handleAcceptScheduleProposal,
        child: Container(
          height: isMobile ? 60 : 70,
          padding: EdgeInsets.symmetric(
              vertical: isMobile ? 8 : 10, horizontal: 4),
          decoration: BoxDecoration(
              color: const Color(0xFF4CAF50),
              borderRadius: BorderRadius.circular(8)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.event_available_rounded,
                color: Colors.white, size: isMobile ? 20 : 22),
            const SizedBox(height: 4),
            Flexible(
              child: Text('ACEPTAR HORARIO',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: isMobile ? 11 : 12,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
            ),
          ]),
        ),
      )),
    ]);
  }

  // ── WIDGETS GENÉRICOS ────────────────────────────────────────────────────

  Widget _buildInfoSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
    required bool isMobile,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon,
            color: const Color(0xFFFFB800), size: isMobile ? 18 : 20),
        SizedBox(width: isMobile ? 6 : 8),
        Text(title,
            style: TextStyle(
                color: Colors.white,
                fontSize: isMobile ? 14 : 16,
                fontWeight: FontWeight.w600)),
      ]),
      SizedBox(height: isMobile ? 10 : 12),
      Container(
        decoration: BoxDecoration(
            color: const Color(0xFF1A2942),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF2A3F5F), width: 1)),
        child: Column(children: children),
      ),
    ]);
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    required bool isMobile,
    bool monospace = false,
  }) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: const BoxDecoration(
          border:
              Border(bottom: BorderSide(color: Color(0xFF2A3F5F), width: 1))),
      child: Row(children: [
        Container(
            padding: EdgeInsets.all(isMobile ? 6 : 8),
            decoration: BoxDecoration(
                color: const Color(0xFF0F1F3D),
                borderRadius: BorderRadius.circular(6)),
            child: Icon(icon,
                color: Colors.white70, size: isMobile ? 18 : 20)),
        SizedBox(width: isMobile ? 10 : 12),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
          Text(label,
              style: TextStyle(
                  color: Colors.white60, fontSize: isMobile ? 11 : 12)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: valueColor ?? Colors.white,
                  fontSize: isMobile ? 13 : 14,
                  fontWeight: FontWeight.w500,
                  fontFamily: monospace ? 'monospace' : null)),
        ])),
      ]),
    );
  }
}