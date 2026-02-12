import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../auth_provider.dart';

class FreelancerActivationsScreen extends StatefulWidget {
  const FreelancerActivationsScreen({Key? key}) : super(key: key);

  @override
  State<FreelancerActivationsScreen> createState() => _FreelancerActivationsScreenState();
}

class _FreelancerActivationsScreenState extends State<FreelancerActivationsScreen> {
  List<dynamic> activations = [];
  bool isLoading = true;
  String? selectedStatus;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchActivations();
  }

  Future<void> fetchActivations({String? status}) async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.accessToken;

      if (token == null) {
        setState(() {
          isLoading = false;
          errorMessage = 'No hay token de autenticación';
        });
        return;
      }

      final baseUrl = dotenv.env['API_BASE_URL'];
      if (baseUrl == null) {
        setState(() {
          isLoading = false;
          errorMessage = 'API_BASE_URL no configurada en .env';
        });
        return;
      }

      final queryParams = <String>[];
      if (status != null && status.isNotEmpty) {
        queryParams.add('status=$status');
      }
      queryParams.add('limit=50');
      
      final queryString = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';
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
        final List<dynamic> data = json.decode(response.body);
        
        List<dynamic> activationsList = [];
        
        if (data is List) {
          activationsList = data;
        }

        setState(() {
          activations = activationsList;
          isLoading = false;
        });
      } else if (response.statusCode == 204) {
        setState(() {
          activations = [];
          isLoading = false;
        });
      } else if (response.statusCode == 401) {
        setState(() {
          isLoading = false;
          errorMessage = 'Sesión expirada. Por favor, inicia sesión nuevamente.';
        });
        authProvider.logout();
      } else if (response.statusCode == 403) {
        setState(() {
          isLoading = false;
          errorMessage = 'No tienes permisos para acceder a estas activaciones.';
        });
      } else {
        setState(() {
          isLoading = false;
          errorMessage = 'Error ${response.statusCode}: ${response.body}';
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Error de conexión: $e';
      });
    }
  }

  Future<bool> respondToActivation(String activationId, String action, {String? reason}) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.accessToken;
      final baseUrl = dotenv.env['API_BASE_URL'];

      if (token == null || baseUrl == null) {
        throw Exception('No hay token de autenticación o URL base');
      }

      final url = Uri.parse('$baseUrl/activations/$activationId/respond');

      final requestBody = <String, dynamic>{
        'action': action,
      };
      
      if (reason != null && reason.isNotEmpty) {
        requestBody['reason'] = reason;
      }

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
        return true;
      } else if (response.statusCode == 401) {
        throw Exception('Sesión expirada');
      } else if (response.statusCode == 404) {
        throw Exception('Activación no encontrada');
      } else if (response.statusCode == 422) {
        final responseBody = json.decode(response.body);
        final errors = responseBody['detail'] as List?;
        if (errors != null && errors.isNotEmpty) {
          throw Exception(errors.first['msg'] ?? 'Error de validación');
        }
        throw Exception('Error de validación');
      } else if (response.statusCode == 400) {
        final responseBody = json.decode(response.body);
        throw Exception(responseBody['message'] ?? 'Error al responder');
      } else {
        throw Exception('Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Map<String, dynamic> parseActivation(dynamic activation) {
    Map<String, dynamic> result = {
      'id': activation['id'] ?? 'N/A',
      'status': activation['status'] ?? 'UNKNOWN',
      'event_name': 'Sin nombre',
      'event_id': activation['event_id'] ?? activation['event']?['id'] ?? 'N/A',
      'position': 'Sin posición',
      'start_date': 'No definido',
      'end_date': 'No definido',
      'payment_terms': '0',
      'organization_name': '',
      'event': activation['event'] ?? {},
      'position_info': activation['position'] ?? {},
      'strategy': activation['strategy'] ?? '',
      'sent_at': activation['sent_at'] ?? '',
      'expire_at': activation['expire_at'] ?? '',
    };

    if (activation['event'] is Map) {
      final event = activation['event'] as Map;
      result['event_name'] = event['name'] ?? event['title'] ?? 'Sin nombre';
      result['start_date'] = event['start_date'] ?? 'No definido';
      result['end_date'] = event['end_date'] ?? 'No definido';
      result['payment_terms'] = event['payment_terms_days']?.toString() ?? '0';
      result['requires_documents'] = event['requires_documents'] ?? false;
      result['requires_intervals'] = event['requires_intervals'] ?? false;
    }

    if (activation['position'] is Map) {
      final position = activation['position'] as Map;
      result['position'] = position['role'] ?? 'Sin posición';
    }

    if (activation['organization_name'] != null) {
      result['organization_name'] = activation['organization_name'];
    } else if (activation['event']?['organization_name'] != null) {
      result['organization_name'] = activation['event']?['organization_name'];
    }

    return result;
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
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1F3D),
        elevation: 0,
        title: Row(
          children: [
            Icon(Icons.bolt, color: Color(0xFFFFB800), size: 24),
            const SizedBox(width: 8),
            const Text(
              'Bandeja de Activaciones',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          if (!isLoading)
            IconButton(
              icon: Icon(Icons.refresh, color: Color(0xFFFFB800)),
              onPressed: () => fetchActivations(status: selectedStatus),
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2942),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF2A3F5F),
                  width: 1,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedStatus,
                  isExpanded: true,
                  hint: const Text(
                    'Filtrar por estado',
                    style: TextStyle(color: Colors.white70),
                  ),
                  dropdownColor: const Color(0xFF1A2942),
                  style: const TextStyle(color: Colors.white),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Todos los estados'),
                    ),
                    const DropdownMenuItem(
                      value: 'PENDING',
                      child: Text('Pendientes'),
                    ),
                    const DropdownMenuItem(
                      value: 'ACTIVE',
                      child: Text('Activas'),
                    ),
                    const DropdownMenuItem(
                      value: 'CONFIRMED',
                      child: Text('Confirmadas'),
                    ),
                    const DropdownMenuItem(
                      value: 'REJECTED',
                      child: Text('Rechazadas'),
                    ),
                    const DropdownMenuItem(
                      value: 'DECLINED',
                      child: Text('Declinadas'),
                    ),
                    const DropdownMenuItem(
                      value: 'EXPIRED',
                      child: Text('Expiradas'),
                    ),
                    const DropdownMenuItem(
                      value: 'PRODUCING',
                      child: Text('En producción'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedStatus = value;
                    });
                    fetchActivations(status: value);
                  },
                ),
              ),
            ),
          ),

          if (!isLoading && activations.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.white60,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${activations.length} activación(es) encontrada(s)',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: Color(0xFFFFB800),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Cargando activaciones...',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 64,
                                color: Colors.red[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Error al cargar activaciones',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                errorMessage!,
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: () => fetchActivations(status: selectedStatus),
                                icon: const Icon(Icons.refresh),
                                label: const Text('Reintentar'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFFB800),
                                  foregroundColor: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : activations.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.inbox,
                                  size: 64,
                                  color: Colors.white24,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No hay activaciones',
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  selectedStatus != null
                                      ? 'No hay activaciones con estado: ${selectedStatus!.toLowerCase()}'
                                      : 'No tienes activaciones en este momento',
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () => fetchActivations(status: selectedStatus),
                            color: const Color(0xFFFFB800),
                            backgroundColor: const Color(0xFF1A2942),
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: activations.length,
                              itemBuilder: (context, index) {
                                final activation = parseActivation(activations[index]);
                                return ActivationCard(
                                  activation: activation,
                                  getStatusColor: getStatusColor,
                                  getStatusIcon: getStatusIcon,
                                  getStatusText: getStatusText,
                                  onStatusChanged: () {
                                    // Recargar la lista después de cambiar el estado
                                    fetchActivations(status: selectedStatus);
                                  },
                                  respondToActivation: respondToActivation,
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class ActivationCard extends StatelessWidget {
  final Map<String, dynamic> activation;
  final Color Function(String) getStatusColor;
  final IconData Function(String) getStatusIcon;
  final String Function(String) getStatusText;
  final VoidCallback onStatusChanged;
  final Future<bool> Function(String, String, {String? reason}) respondToActivation;

  const ActivationCard({
    Key? key,
    required this.activation,
    required this.getStatusColor,
    required this.getStatusIcon,
    required this.getStatusText,
    required this.onStatusChanged,
    required this.respondToActivation,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final status = activation['status'];
    final statusColor = getStatusColor(status);
    final eventName = activation['event_name'];
    final eventId = activation['event_id'];
    final position = activation['position'];
    final startDate = activation['start_date'];
    final endDate = activation['end_date'];
    final paymentTerms = activation['payment_terms'];
    final organizationName = activation['organization_name'];
    final strategy = activation['strategy'];
    final sentAt = activation['sent_at'];
    final expireAt = activation['expire_at'];

    String formatDate(String date) {
      if (date.length > 10) {
        return date.substring(0, 10);
      }
      return date;
    }

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
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2942),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF2A3F5F),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 40,
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          eventName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (organizationName.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              organizationName,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: statusColor,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          getStatusIcon(status),
                          color: statusColor,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.fingerprint,
                        color: Colors.white60,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'ID: $eventId',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (strategy.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.settings,
                          color: Colors.white60,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Estrategia: $strategy',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 12),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.work_outline,
                        color: Colors.white70,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Posición',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 10,
                              ),
                            ),
                            Text(
                              position,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              color: Colors.white70,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Inicio',
                                    style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 10,
                                    ),
                                  ),
                                  Text(
                                    formatDate(startDate),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.event,
                              color: Colors.white70,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Fin',
                                    style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 10,
                                    ),
                                  ),
                                  Text(
                                    formatDate(endDate),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Icon(
                        Icons.payment,
                        color: const Color(0xFF4CAF50),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Términos de pago',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 10,
                              ),
                            ),
                            Text(
                              '$paymentTerms día${paymentTerms != "1" ? "s" : ""}',
                              style: const TextStyle(
                                color: Color(0xFF4CAF50),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F1F3D).withOpacity(0.5),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    getStatusIcon(status),
                    color: statusColor,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      getStatusText(status),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: Colors.white30,
                    size: 20,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ActivationDetailScreen extends StatefulWidget {
  final Map<String, dynamic> activation;
  final VoidCallback onStatusChanged;
  final Future<bool> Function(String, String, {String? reason}) respondToActivation;

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

  Color _getStatusColor(String status) {
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

  String _formatDateTime(String dateTime) {
    if (dateTime.isEmpty || dateTime == 'No definido') {
      return 'No disponible';
    }
    try {
      final date = DateTime.parse(dateTime);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTime;
    }
  }

  Future<void> _handleConfirmActivation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2942),
        title: const Text(
          '¿Confirmar activación?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Estás a punto de confirmar esta activación. La empresa será notificada de tu aceptación.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.white60),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        isUpdating = true;
      });

      try {
        final success = await widget.respondToActivation(
          widget.activation['id'],
          'CONFIRM',
        );

        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Activación confirmada exitosamente'),
              backgroundColor: Color(0xFF4CAF50),
              duration: Duration(seconds: 2),
            ),
          );

          // Esperar un momento para que el usuario vea el mensaje
          await Future.delayed(const Duration(milliseconds: 500));

          // Notificar al padre y regresar
          widget.onStatusChanged();
          if (mounted) {
            Navigator.pop(context);
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al confirmar: ${e.toString()}'),
              backgroundColor: const Color(0xFFE53935),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            isUpdating = false;
          });
        }
      }
    }
  }

  Future<void> _handleRejectActivation() async {
    String? declineReason;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2942),
        title: const Text(
          '¿Rechazar activación?',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Estás a punto de rechazar esta activación. La empresa será notificada de tu rechazo.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            const Text(
              'Razón (opcional):',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 8),
            TextField(
              onChanged: (value) => declineReason = value,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Ej: No estoy disponible en esa fecha',
                hintStyle: TextStyle(color: Colors.white30),
                filled: true,
                fillColor: const Color(0xFF0F1F3D),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF2A3F5F)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF2A3F5F)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE53935)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.white60),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
            ),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        isUpdating = true;
      });

      try {
        final success = await widget.respondToActivation(
          widget.activation['id'],
          'DECLINE',
          reason: declineReason,
        );

        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Activación rechazada'),
              backgroundColor: Color(0xFFE53935),
              duration: Duration(seconds: 2),
            ),
          );

          // Esperar un momento para que el usuario vea el mensaje
          await Future.delayed(const Duration(milliseconds: 500));

          // Notificar al padre y regresar
          widget.onStatusChanged();
          if (mounted) {
            Navigator.pop(context);
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al rechazar: ${e.toString()}'),
              backgroundColor: const Color(0xFFE53935),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            isUpdating = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.activation['status'];
    final statusColor = _getStatusColor(status ?? 'UNKNOWN');
    final eventName = widget.activation['event_name'];
    final eventId = widget.activation['event_id'];
    final position = widget.activation['position'];
    final startDate = widget.activation['start_date'];
    final endDate = widget.activation['end_date'];
    final paymentTerms = widget.activation['payment_terms'];
    final organizationName = widget.activation['organization_name'];
    final strategy = widget.activation['strategy'];
    final sentAt = widget.activation['sent_at'];
    final expireAt = widget.activation['expire_at'];
    final requiresDocuments = widget.activation['requires_documents'] ?? false;
    final requiresIntervals = widget.activation['requires_intervals'] ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1F3D),
        elevation: 0,
        title: const Text(
          'Detalles de Activación',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2942),
                    border: Border(
                      bottom: BorderSide(
                        color: const Color(0xFF2A3F5F),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 60,
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              eventName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (organizationName.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  organizationName,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: statusColor,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoSection(
                        title: 'Información General',
                        icon: Icons.info_outline,
                        children: [
                          _buildInfoRow(
                            icon: Icons.fingerprint,
                            label: 'ID del Evento',
                            value: eventId,
                          ),
                          if (strategy.isNotEmpty)
                            _buildInfoRow(
                              icon: Icons.settings,
                              label: 'Estrategia',
                              value: strategy,
                            ),
                          _buildInfoRow(
                            icon: Icons.work,
                            label: 'Posición',
                            value: position,
                          ),
                          _buildInfoRow(
                            icon: Icons.payment,
                            label: 'Términos de Pago',
                            value: '$paymentTerms días',
                            valueColor: const Color(0xFF4CAF50),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      _buildInfoSection(
                        title: 'Fechas',
                        icon: Icons.calendar_today,
                        children: [
                          _buildInfoRow(
                            icon: Icons.play_arrow,
                            label: 'Fecha de Inicio',
                            value: _formatDateTime(startDate),
                          ),
                          _buildInfoRow(
                            icon: Icons.stop,
                            label: 'Fecha de Fin',
                            value: _formatDateTime(endDate),
                          ),
                          if (sentAt.isNotEmpty && sentAt != 'No definido')
                            _buildInfoRow(
                              icon: Icons.send,
                              label: 'Enviado el',
                              value: _formatDateTime(sentAt),
                            ),
                          if (expireAt.isNotEmpty && expireAt != 'No definido')
                            _buildInfoRow(
                              icon: Icons.timer_off,
                              label: 'Expira el',
                              value: _formatDateTime(expireAt),
                            ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      _buildInfoSection(
                        title: 'Requisitos',
                        icon: Icons.checklist,
                        children: [
                          _buildInfoRow(
                            icon: Icons.description,
                            label: 'Requiere Documentos',
                            value: requiresDocuments ? 'Sí' : 'No',
                            valueColor: requiresDocuments
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFFE53935),
                          ),
                          _buildInfoRow(
                            icon: Icons.timelapse,
                            label: 'Requiere Intervalos',
                            value: requiresIntervals ? 'Sí' : 'No',
                            valueColor: requiresIntervals
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFFE53935),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      if (status == 'PENDING')
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: isUpdating ? null : _handleConfirmActivation,
                                icon: isUpdating
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.check),
                                label: Text(isUpdating ? 'Procesando...' : 'Confirmar'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4CAF50),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: isUpdating ? null : _handleRejectActivation,
                                icon: isUpdating
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFFE53935),
                                        ),
                                      )
                                    : const Icon(Icons.close),
                                label: Text(isUpdating ? 'Procesando...' : 'Rechazar'),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFFE53935)),
                                  foregroundColor: const Color(0xFFE53935),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isUpdating)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFFFB800),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              color: const Color(0xFFFFB800),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A2942),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFF2A3F5F),
              width: 1,
            ),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFF2A3F5F),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F1F3D),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              color: Colors.white70,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: valueColor ?? Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}