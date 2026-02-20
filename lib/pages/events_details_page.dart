import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import '../auth_provider.dart';
import 'package:intl/intl.dart';
import 'create_posicion_page.dart';
import '../utils/error_handler.dart'; 

class EventDetailsPage extends StatefulWidget {
  final String? eventId;

  EventDetailsPage({this.eventId});

  @override
  _EventDetailsPageState createState() => _EventDetailsPageState();
}

class _EventDetailsPageState extends State<EventDetailsPage> {
  String? _eventId;
  Map<String, dynamic>? _eventData;
  List<Map<String, dynamic>> _positions = [];
  Map<String, Map<String, dynamic>> _positionDetails = {};
  bool _isLoading = true;
  bool _isLoadingPositions = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    if (_eventId == null) {
      final routeArgs = ModalRoute.of(context)?.settings.arguments;
      
      if (routeArgs != null) {
        _eventId = routeArgs.toString();
      } else if (widget.eventId != null) {
        _eventId = widget.eventId;
      }
      
      if (_eventId != null && _eventId!.isNotEmpty) {
        _loadEventDetails();
        _loadPositions();
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No se proporcionó un ID de evento válido';
        });
      }
    }
  }

  Future<void> _loadEventDetails() async {
    if (_eventId == null || _eventId!.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'ID de evento no válido';
      });
      return;
    }

    final baseUrl = dotenv.env['API_BASE_URL'];
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.accessToken;

    if (token == null || baseUrl == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'No autenticado';
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/events/$_eventId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(Duration(seconds: 15));

      if (response.isSuccess) {
        final responseBody = jsonDecode(response.body);
        
        Map<String, dynamic> eventData = {};
        
        if (responseBody.containsKey('event') && responseBody['event'] is Map) {
          eventData = Map<String, dynamic>.from(responseBody['event']);
        } else if (responseBody.containsKey('id')) {
          eventData = Map<String, dynamic>.from(responseBody);
        }
        
        setState(() {
          _eventData = eventData;
        });
      } else {
        setState(() {
          _errorMessage = response.friendlyErrorMessage;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = ApiErrorHandler.handleNetworkException(e);
      });
    }
  }

  Future<void> _loadPositions() async {
    if (_eventId == null || _eventId!.isEmpty) {
      return;
    }

    final baseUrl = dotenv.env['API_BASE_URL'];
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.accessToken;

    if (token == null || baseUrl == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'No autenticado';
      });
      return;
    }

    setState(() {
      _isLoadingPositions = true;
    });

    try {
      // Cargar desde /events/positions y filtrar por event_id
      final response = await http.get(
        Uri.parse('$baseUrl/events/positions'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        
        List<dynamic> eventsWithPositions = responseBody is List
            ? responseBody
            : (responseBody['items'] ?? responseBody['data'] ?? []);

        // Encontrar el evento con el event_id que buscamos
        var eventData = eventsWithPositions.firstWhere(
          (e) => e['event_id']?.toString() == _eventId,
          orElse: () => null,
        );

        if (eventData == null) {
          setState(() {
            _isLoadingPositions = false;
            _positions = [];
            _positionDetails = {};
          });
          return;
        }

        // Obtener las posiciones del evento
        List<dynamic> eventPositions = eventData['event_positions'] ?? [];

        List<Map<String, dynamic>> processedPositions = [];
        Map<String, Map<String, dynamic>> details = {};
        
        for (var position in eventPositions) {
          final positionId = position['position_id']?.toString() ?? position['id']?.toString() ?? '';
          
          processedPositions.add({
            'id': positionId,
            'role_name': position['role_name']?.toString() ?? 'Sin nombre',
            'quantity_required': position['quantity_required'] ?? 1,
            'pay_rate': position['pay_rate']?.toDouble() ?? 0.0,
            'currency': position['currency']?.toString() ?? 'USD',
            'visibility': position['visibility']?.toString() ?? 'PRIVATE',
            'fill_stage': position['fill_stage']?.toString() ?? 'LIST_READY',
            'organization_id': position['organization_id']?.toString(),
          });
          
          details[positionId] = {
            'id': positionId,
            'event_id': position['event_id']?.toString() ?? '',
            'organization_id': position['organization_id']?.toString() ?? '',
            'role_name': position['role_name']?.toString() ?? 'Sin nombre',
            'quantity_required': position['quantity_required'] ?? 1,
            'pay_rate': position['pay_rate']?.toDouble() ?? 0.0,
            'currency': position['currency']?.toString() ?? 'USD',
            'visibility': position['visibility']?.toString() ?? 'PRIVATE',
            'fill_stage': position['fill_stage']?.toString() ?? 'LIST_READY',
            'candidates': position['candidates'] ?? [],
            'confirmed_freelancers': position['confirmed_freelancers'] ?? {},
          };
        }

        setState(() {
          _positions = processedPositions;
          _positionDetails = details;
          _isLoading = false;
          _isLoadingPositions = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _isLoadingPositions = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isLoadingPositions = false;
      });
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _positions.clear();
      _positionDetails.clear();
    });
    await Future.wait([
      _loadEventDetails(),
      _loadPositions(),
    ]);
  }

  Widget _buildDetailRow(String label, String value, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.grey[500], size: 20),
            SizedBox(width: 12),
          ],
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPositionCard(Map<String, dynamic> position) {
    final positionId = position['id'];
    final detailedPosition = _positionDetails[positionId];
    final hasConfirmedFreelancer = detailedPosition != null && 
        detailedPosition['confirmed_freelancers'] != null && 
        detailedPosition['confirmed_freelancers'] is Map &&
        (detailedPosition['confirmed_freelancers'] as Map).isNotEmpty;

    return Container(
      margin: EdgeInsets.only(bottom: 16),
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
                child: Text(
                  position['role_name'],
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: position['visibility'] == 'PUBLIC'
                      ? Colors.green[900]!.withOpacity(0.2)
                      : Colors.blue[900]!.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: position['visibility'] == 'PUBLIC'
                        ? Colors.green[400]!
                        : Colors.blue[400]!,
                    width: 1,
                  ),
                ),
                child: Text(
                  position['visibility'] == 'PUBLIC' ? 'PÚBLICO' : 'PRIVADO',
                  style: TextStyle(
                    color: position['visibility'] == 'PUBLIC'
                        ? Colors.green[400]
                        : Colors.blue[400],
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          
          Row(
            children: [
              _buildPositionInfo(
                'Posiciones',
                '${position['quantity_required']}',
                Icons.people_outline,
              ),
              SizedBox(width: 24),
              _buildPositionInfo(
                'Tarifa',
                '${position['pay_rate']} ${position['currency']}',
                Icons.attach_money_outlined,
              ),
            ],
          ),
          SizedBox(height: 12),
          
          if (detailedPosition != null) ...[
            if (detailedPosition['candidates'] is List && 
                detailedPosition['candidates'].isNotEmpty)
              _buildCandidateInfo(detailedPosition),
            
            if (hasConfirmedFreelancer)
              _buildConfirmedFreelancerInfo(Map<String, dynamic>.from(detailedPosition['confirmed_freelancers'] ?? {})),
          ],
          
          Container(
            margin: EdgeInsets.only(top: 12, bottom: 12),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _getFillStageColor(position['fill_stage']),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getFillStageIcon(position['fill_stage']),
                  color: Colors.white,
                  size: 16,
                ),
                SizedBox(width: 8),
                Text(
                  _getFillStageText(position['fill_stage']),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    _showPositionDetails(positionId);
                  },
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: Colors.blue[600]!, width: 1),
                  ),
                  child: Text(
                    'Ver Detalles',
                    style: TextStyle(color: Colors.blue[400]),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    _deletePosition(positionId);
                  },
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: Colors.red[600]!, width: 1),
                  ),
                  child: Text(
                    'Eliminar',
                    style: TextStyle(color: Colors.red[400]),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPositionInfo(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
            ),
          ),
          SizedBox(height: 4),
          Row(
            children: [
              Icon(icon, color: Colors.grey[400], size: 16),
              SizedBox(width: 8),
              Text(
                value,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCandidateInfo(Map<String, dynamic> position) {
    final candidates = position['candidates'] as List;
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[900]!.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange[400]!, width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.person_add_outlined, color: Colors.orange[400], size: 16),
          SizedBox(width: 8),
          Text(
            '${candidates.length} candidato(s)',
            style: TextStyle(
              color: Colors.orange[300],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmedFreelancerInfo(Map<String, dynamic> freelancer) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[900]!.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green[400]!, width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_outlined, color: Colors.green[400], size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Freelancer confirmado:',
                  style: TextStyle(
                    color: Colors.green[300],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  freelancer['full_name']?.toString() ?? 'Sin nombre',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getFillStageColor(String fillStage) {
    switch (fillStage) {
      case 'LIST_READY':
        return Colors.blue[900]!.withOpacity(0.3);
      case 'PARTIALLY_FILLED':
        return Colors.orange[900]!.withOpacity(0.3);
      case 'FILLED':
        return Colors.green[900]!.withOpacity(0.3);
      case 'CANCELLED':
        return Colors.red[900]!.withOpacity(0.3);
      default:
        return Colors.grey[900]!.withOpacity(0.3);
    }
  }

  IconData _getFillStageIcon(String fillStage) {
    switch (fillStage) {
      case 'LIST_READY':
        return Icons.list_outlined;
      case 'PARTIALLY_FILLED':
        return Icons.person_outline;
      case 'FILLED':
        return Icons.check_circle_outline;
      case 'CANCELLED':
        return Icons.cancel_outlined;
      default:
        return Icons.help_outline;
    }
  }

  String _getFillStageText(String fillStage) {
    switch (fillStage) {
      case 'LIST_READY':
        return 'Listo para asignar';
      case 'PARTIALLY_FILLED':
        return 'Parcialmente asignado';
      case 'FILLED':
        return 'Completamente asignado';
      case 'CANCELLED':
        return 'Cancelado';
      default:
        return fillStage;
    }
  }

  void _showPositionDetails(String positionId) {
    final positionData = _positionDetails[positionId];
    
    if (positionData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se encontraron detalles de la posición'),
          backgroundColor: Colors.red[600],
        ),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF161B22),
        title: Text(
          positionData['role_name']?.toString() ?? 'Detalles de Posición',
          style: TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailDialogRow('ID:', positionData['id']?.toString() ?? ''),
              _buildDetailDialogRow('ID del Evento:', positionData['event_id']?.toString() ?? ''),
              _buildDetailDialogRow('Nombre del Rol:', positionData['role_name']?.toString() ?? ''),
              _buildDetailDialogRow('Posiciones requeridas:', '${positionData['quantity_required']}'),
              _buildDetailDialogRow('Tarifa:', '${positionData['pay_rate']} ${positionData['currency']}'),
              _buildDetailDialogRow('Visibilidad:', positionData['visibility']?.toString() ?? ''),
              _buildDetailDialogRow('Estado:', _getFillStageText(positionData['fill_stage']?.toString() ?? '')),
              
              if (positionData['activation_candidates'] is List && 
                  positionData['activation_candidates'].isNotEmpty) ...[
                SizedBox(height: 16),
                Text(
                  'Candidatos:',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                ...(positionData['activation_candidates'] as List).map((candidate) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• ${candidate.toString()}',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  );
                }).toList(),
              ],
              if (positionData['confirmed_freelancer'] != null && 
                  positionData['confirmed_freelancer'].isNotEmpty) ...[
                SizedBox(height: 16),
                Text(
                  'Freelancer Confirmado:',
                  style: TextStyle(
                    color: Colors.green[400],
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                _buildDetailDialogRow('Nombre:', positionData['confirmed_freelancer']['full_name']?.toString() ?? ''),
                if (positionData['confirmed_freelancer']['photo_url'] != null)
                  _buildDetailDialogRow('Foto URL:', positionData['confirmed_freelancer']['photo_url']?.toString() ?? ''),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar', style: TextStyle(color: Colors.blue[400])),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailDialogRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePosition(String positionId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF161B22),
        title: Text(
          'Confirmar eliminación',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '¿Estás seguro de que quieres eliminar esta posición? Esta acción no se puede deshacer.',
          style: TextStyle(color: Colors.grey[400]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey[400])),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Eliminar', style: TextStyle(color: Colors.red[400])),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final baseUrl = dotenv.env['API_BASE_URL'];
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.accessToken;

    if (token == null || baseUrl == null) return;

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/positions/$positionId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(Duration(seconds: 15));

      if (response.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Posición eliminada exitosamente'),
            backgroundColor: Colors.green[600],
          ),
        );
        setState(() {
          _positions.removeWhere((p) => p['id'] == positionId);
          _positionDetails.remove(positionId);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.friendlyErrorMessage),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ApiErrorHandler.handleNetworkException(e)),
          backgroundColor: Colors.red[600],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      backgroundColor: Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: Color(0xFF161B22),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Detalles del Llamado',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.edit, color: Colors.white),
            onPressed: _eventId != null ? () {
              Navigator.pushNamed(
                context,
                '/edit_event',
                arguments: _eventId,
              ).then((_) => _refreshData());
            } : null,
            tooltip: 'Editar llamado',
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _refreshData,
            tooltip: 'Refrescar',
          ),
        ],
        elevation: 0,
      ),
      floatingActionButton: _eventId != null ? FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreatePositionPage(
                eventId: _eventId!,
                eventTitle: _eventData?['title'] ?? 'Evento',
              ),
            ),
          ).then((created) {
            if (created == true) {
              _refreshData();
            }
          });
        },
        backgroundColor: Colors.blue[600],
        child: Icon(Icons.add, color: Colors.white),
      ) : null,
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: Colors.blue[600]),
            )
          : _errorMessage.isNotEmpty
              ? Center(
                  child: ApiErrorHandler.buildErrorWidget(
                    message: _errorMessage,
                    onRetry: _refreshData,
                  ),
                )
              : RefreshIndicator(
                  color: Colors.blue[600],
                  backgroundColor: Color(0xFF161B22),
                  onRefresh: _refreshData,
                  child: SingleChildScrollView(
                    physics: AlwaysScrollableScrollPhysics(),
                    child: Padding(
                      padding: EdgeInsets.all(isMobile ? 16 : 32),
                      child: Container(
                        constraints: BoxConstraints(maxWidth: 800),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    _eventData?['title'] ?? 'Sin título',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: isMobile ? 24 : 28,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _eventData?['status'] == 'ACTIVE'
                                        ? Colors.green[900]!.withOpacity(0.2)
                                        : Colors.orange[900]!.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: _eventData?['status'] == 'ACTIVE'
                                          ? Colors.green[400]!
                                          : Colors.orange[400]!,
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    _eventData?['status'] == 'ACTIVE'
                                        ? 'ACTIVO'
                                        : _eventData?['status'] ?? 'INACTIVO',
                                    style: TextStyle(
                                      color: _eventData?['status'] == 'ACTIVE'
                                          ? Colors.green[400]
                                          : Colors.orange[400],
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 32),

                            Container(
                              padding: EdgeInsets.all(isMobile ? 16 : 24),
                              decoration: BoxDecoration(
                                color: Color(0xFF161B22),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Color(0xFF30363D), width: 1),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'INFORMACIÓN GENERAL',
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  SizedBox(height: 20),
                                  _buildDetailRow(
                                    'Descripción',
                                    _eventData?['description'] ?? 'Sin descripción',
                                    icon: Icons.description_outlined,
                                  ),
                                  Divider(color: Color(0xFF30363D)),
                                  _buildDetailRow(
                                    'Ubicación',
                                    _eventData?['location'] ?? 'Sin ubicación',
                                    icon: Icons.location_on_outlined,
                                  ),
                                  Divider(color: Color(0xFF30363D)),
                                  _buildDetailRow(
                                    'Fecha de Inicio',
                                    _eventData?['start_date'] != null
                                        ? DateFormat('dd/MM/yyyy').format(
                                            DateTime.parse(
                                                _eventData!['start_date']))
                                        : 'No especificada',
                                    icon: Icons.calendar_today_outlined,
                                  ),
                                  Divider(color: Color(0xFF30363D)),
                                  _buildDetailRow(
                                    'Fecha de Fin',
                                    _eventData?['end_date'] != null
                                        ? DateFormat('dd/MM/yyyy').format(
                                            DateTime.parse(_eventData!['end_date']))
                                        : 'No especificada',
                                    icon: Icons.event_outlined,
                                  ),
                                  Divider(color: Color(0xFF30363D)),
                                  _buildDetailRow(
                                    'Dias de pago',
                                    _eventData?['payment_terms_days']?.toString() ??
                                        'No especificado',
                                    icon: Icons.payment_outlined,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 24),

                            Container(
                              padding: EdgeInsets.all(isMobile ? 16 : 24),
                              decoration: BoxDecoration(
                                color: Color(0xFF161B22),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Color(0xFF30363D), width: 1),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'ACTIVACIONES DEL LLAMADO',
                                        style: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                      Text(
                                        '${_positions.length} posición(es)',
                                        style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 20),
                                  
                                  if (_isLoadingPositions)
                                    Center(
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(vertical: 40),
                                        child: CircularProgressIndicator(color: Colors.blue[600]),
                                      ),
                                    )
                                  else if (_positions.isEmpty)
                                    Center(
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.work_outline,
                                            color: Colors.grey[600],
                                            size: 48,
                                          ),
                                          SizedBox(height: 16),
                                          Text(
                                            'No hay activaciones creadas',
                                            style: TextStyle(
                                              color: Colors.grey[400],
                                              fontSize: 14,
                                            ),
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            'Presiona el botón + para crear una activación',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    Column(
                                      children: _positions.map((position) {
                                        return _buildPositionCard(position);
                                      }).toList(),
                                    ),
                                ],
                              ),
                            ),
                            SizedBox(height: 24),

                            Container(
                              padding: EdgeInsets.all(isMobile ? 16 : 24),
                              decoration: BoxDecoration(
                                color: Color(0xFF161B22),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Color(0xFF30363D), width: 1),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'VALIDACIONES',
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Icon(
                                        _eventData?['requires_documents'] == true
                                            ? Icons.check_circle
                                            : Icons.cancel,
                                        color: _eventData?['requires_documents'] ==
                                                true
                                            ? Colors.green[400]
                                            : Colors.grey[600],
                                        size: 20,
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        'Requiere Documentos',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Icon(
                                        _eventData?['requires_interview'] == true
                                            ? Icons.check_circle
                                            : Icons.cancel,
                                        color: _eventData?['requires_interview'] ==
                                                true
                                            ? Colors.green[400]
                                            : Colors.grey[600],
                                        size: 20,
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        'Requiere Entrevista',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 32),

                            if (isMobile && _eventId != null)
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pushNamed(
                                      context,
                                      '/edit_event',
                                      arguments: _eventId,
                                    ).then((_) => _refreshData());
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue[600],
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  icon: Icon(Icons.edit, color: Colors.white),
                                  label: Text(
                                    'Editar Llamado',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                            SizedBox(height: 80),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
    );
  }
}