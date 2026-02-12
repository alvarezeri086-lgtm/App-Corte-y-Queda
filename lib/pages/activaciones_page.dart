import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import '../auth_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/error_handler.dart';

class ActivationsPage extends StatefulWidget {
  @override
  _ActivationsPageState createState() => _ActivationsPageState();
}

class _ActivationsPageState extends State<ActivationsPage> {
  List<Map<String, dynamic>> _events = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String _filter = 'all';
  Set<String> _expandedEvents = {};

  @override
  void initState() {
    super.initState();
    _loadEventsWithPositions();
  }

  Future<void> _loadEventsWithPositions() async {
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
      _isLoading = true;
      _errorMessage = '';
      _events = [];
    });

    try {
      final positionsResponse = await http.get(
        Uri.parse('$baseUrl/positions/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(Duration(seconds: 15));

      if (!positionsResponse.isSuccess) {
        throw Exception(positionsResponse.friendlyErrorMessage);
      }

      final positionsData = jsonDecode(positionsResponse.body);
      List<dynamic> positionsList = positionsData is List
          ? positionsData
          : (positionsData['items'] ?? positionsData['data'] ?? []);

      Map<String, List<Map<String, dynamic>>> eventPositionsMap = {};
      Set<String> eventIds = {};

      for (var position in positionsList) {
        final eventId = position['event_id']?.toString();
        if (eventId == null || eventId.isEmpty) continue;

        eventIds.add(eventId);

        final processedPosition = _processPosition(position);

        if (!eventPositionsMap.containsKey(eventId)) {
          eventPositionsMap[eventId] = [];
        }
        eventPositionsMap[eventId]!.add(processedPosition);
      }

      List<Map<String, dynamic>> processedEvents = [];

      for (var eventId in eventIds) {
        try {
          final eventResponse = await http.get(
            Uri.parse('$baseUrl/events/$eventId'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          ).timeout(Duration(seconds: 15));

          String eventTitle = 'Evento $eventId';
          Map<String, dynamic> eventData = {};

          if (eventResponse.isSuccess) {
            eventData = jsonDecode(eventResponse.body);
            eventTitle = eventData['title']?.toString() ??
                eventData['name']?.toString() ??
                'Evento sin nombre';
          } else {
            // Error silencioso o log de error crítico si es necesario
          }

          processedEvents.add({
            'id': eventId,
            'title': eventTitle,
            'organization_id': eventData['organization_id']?.toString() ?? '',
            'start_date': eventData['start_date']?.toString() ?? '',
            'end_date': eventData['end_date']?.toString() ?? '',
            'status': eventData['status']?.toString() ?? '',
            'positions': eventPositionsMap[eventId] ?? [],
          });
        } catch (e) {
          print('Error cargando evento $eventId: $e');
          processedEvents.add({
            'id': eventId,
            'title': 'Evento ${eventId.substring(0, 8)}...',
            'organization_id': '',
            'start_date': '',
            'end_date': '',
            'status': '',
            'positions': eventPositionsMap[eventId] ?? [],
          });
        }
      }

      setState(() {
        _events = processedEvents;
        _isLoading = false;
      });
    } catch (e) {
      print('Error en loadEventsWithPositions: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = ApiErrorHandler.handleNetworkException(e);
      });
    }
  }

  Map<String, dynamic> _processPosition(dynamic position) {
    final stageOptions = [
      'LIST_READY',
      'RED_RECOMMENDED',
      'RED_KNOWN',
      'FILLED'
    ];

    final randomStage =
        stageOptions[(position['id']?.hashCode ?? 0) % stageOptions.length];

    return {
      'id': position['id']?.toString() ?? '',
      'role_name': position['role_name']?.toString() ?? 'Sin nombre',
      'quantity_required': position['quantity_required'] ?? 1,
      'pay_rate': position['pay_rate']?.toDouble() ?? 0.0,
      'currency': position['currency']?.toString() ?? 'USD',
      'event_id': position['event_id']?.toString() ?? '',
      'organization_id': position['organization_id']?.toString() ?? '',
      'fill_stage': randomStage,
    };
  }

  List<Map<String, dynamic>> get _filteredEvents {
    if (_filter == 'all') return _events;

    String stageFilter;
    switch (_filter) {
      case 'ready':
        stageFilter = 'LIST_READY';
        break;
      case 'recommended':
        stageFilter = 'RED_RECOMMENDED';
        break;
      case 'known':
        stageFilter = 'RED_KNOWN';
        break;
      case 'covered':
        stageFilter = 'FILLED';
        break;
      default:
        return _events;
    }

    return _events.where((event) {
      final positions = event['positions'] as List<Map<String, dynamic>>;
      return positions.any((pos) => pos['fill_stage'] == stageFilter);
    }).map((event) {
      return {
        'id': event['id'],
        'title': event['title'],
        'organization_id': event['organization_id'],
        'start_date': event['start_date'],
        'end_date': event['end_date'],
        'status': event['status'],
        'positions': (event['positions'] as List<Map<String, dynamic>>)
            .where((pos) => pos['fill_stage'] == stageFilter)
            .toList(),
      };
    }).toList();
  }

  int get _totalPositions {
    return _filteredEvents.fold(0, (sum, event) {
      return sum + (event['positions'] as List).length;
    });
  }

  String _getStageText(String stage) {
    switch (stage) {
      case 'LIST_READY':
        return 'LISTO PARA SELECCIONAR';
      case 'RED_RECOMMENDED':
        return 'RED RECOMENDADA';
      case 'RED_KNOWN':
        return 'RED CONOCIDA';
      case 'FILLED':
        return 'CUBIERTO';
      default:
        return stage;
    }
  }

  Color _getStageColor(String stage) {
    switch (stage) {
      case 'LIST_READY':
        return Colors.blue[400]!;
      case 'RED_RECOMMENDED':
        return Colors.green[400]!;
      case 'RED_KNOWN':
        return Colors.orange[400]!;
      case 'FILLED':
        return Colors.purple[400]!;
      default:
        return Colors.grey[400]!;
    }
  }

  void _toggleEventExpansion(String eventId) {
    setState(() {
      if (_expandedEvents.contains(eventId)) {
        _expandedEvents.remove(eventId);
      } else {
        _expandedEvents.add(eventId);
      }
    });
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    final eventId = event['id'] as String;
    final positions = event['positions'] as List<Map<String, dynamic>>;
    final isExpanded = _expandedEvents.contains(eventId);
    final showExpandButton = positions.length > 2;
    final displayPositions = isExpanded
        ? positions
        : positions.take(2).toList();

    return Container(
      margin: EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFF30363D), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFF30363D), width: 1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[600]!.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.event, color: Colors.blue[400], size: 24),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event['title'],
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${positions.length} ${positions.length == 1 ? 'posicion' : 'posiciones'}',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                ...displayPositions.asMap().entries.map((entry) {
                  final index = entry.key;
                  final position = entry.value;
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index < displayPositions.length - 1 ? 12 : 0,
                    ),
                    child: _buildPositionCard(position, event),
                  );
                }).toList(),

                if (showExpandButton)
                  Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: InkWell(
                      onTap: () => _toggleEventExpansion(eventId),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.blue[400]!.withOpacity(0.3),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isExpanded
                                  ? 'Ver menos'
                                  : 'Ver todas (${positions.length})',
                              style: TextStyle(
                                color: Colors.blue[400],
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              isExpanded
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              color: Colors.blue[400],
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPositionCard(Map<String, dynamic> position, Map<String, dynamic> event) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(8),
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
              SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      _getStageColor(position['fill_stage']).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _getStageColor(position['fill_stage']),
                    width: 1,
                  ),
                ),
                child: Text(
                  _getStageText(position['fill_stage']),
                  style: TextStyle(
                    color: _getStageColor(position['fill_stage']),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Cantidad: ',
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
              ),
              Text(
                '${position['quantity_required']}',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
              SizedBox(width: 16),
              Text(
                'Tarifa: ',
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
              ),
              Text(
                '\$${position['pay_rate']} ${position['currency']}',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue[900]!.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[400]!, width: 1),
                ),
                child: Text(
                  'PRIVADO',
                  style: TextStyle(
                    color: Colors.blue[400],
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Spacer(),
              ElevatedButton(
                onPressed: () {
                  _viewActivation(position, event);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: Text(
                  'Ver Activacion',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _viewActivation(Map<String, dynamic> position, Map<String, dynamic> event) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final positionId = position['id'];
      final organizationId = position['organization_id']?.toString().isNotEmpty == true
          ? position['organization_id']
          : event['organization_id'] ?? authProvider.userInfo?['organization']?['id'] ?? '';

      final args = {
        'positionId': positionId,
        'organizationId': organizationId,
        'activationId': positionId,
        'payRate': position['pay_rate']?.toDouble() ?? 0.0,
        'currency': position['currency'] ?? 'MXN',
      };

      Navigator.pushNamed(
        context,
        '/candidates',
        arguments: args,
      ).then((result) {
        if (result == true) {
          _loadEventsWithPositions();
        }
      });
    } catch (e) {
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al abrir candidatos'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _showEventSelectorDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Color(0xFF161B22),
          title: Text(
            'Seleccionar evento',
            style: TextStyle(color: Colors.white),
          ),
          content: Container(
            width: double.maxFinite,
            child: _events.isEmpty
                ? Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'No hay eventos disponibles',
                      style: TextStyle(color: Colors.grey[400]),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _events.length,
                    itemBuilder: (context, index) {
                      final event = _events[index];
                      final eventId = event['id'] as String;
                      final eventTitle = event['title'] as String;
                      final positionsCount =
                          (event['positions'] as List).length;

                      return InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(
                            context,
                            '/create_position',
                            arguments: {
                              'eventId': eventId,
                              'eventTitle': eventTitle,
                            },
                          );
                        },
                        child: Container(
                          margin: EdgeInsets.only(bottom: 8),
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Color(0xFF0D1117),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Color(0xFF30363D),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue[600]!.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  Icons.event,
                                  color: Colors.blue[400],
                                  size: 20,
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      eventTitle,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      '$positionsCount ${positionsCount == 1 ? 'posicion' : 'posiciones'}',
                                      style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.grey[600],
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancelar',
                style: TextStyle(color: Colors.grey[400]),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filter == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.grey[400],
          fontSize: 12,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filter = value;
        });
      },
      backgroundColor: Color(0xFF161B22),
      selectedColor: Colors.blue[600],
      side: BorderSide(
        color: isSelected ? Colors.blue[400]! : Color(0xFF30363D),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0D1117),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Color(0xFF161B22),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Posiciones activas',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Administra y revisa tus posiciones de trabajo actuales y sus candidatos.',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _showEventSelectorDialog(),
                    icon: Icon(Icons.add, size: 16),
                    label: Text(
                      'Activar rol',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 60, 142, 64),
                      foregroundColor: Colors.white,
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      minimumSize: Size(0, 36),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Colors.blue[600]),
                          SizedBox(height: 16),
                          Text(
                            'Cargando eventos y posiciones...',
                            style: TextStyle(color: Colors.grey[400]),
                          ),
                        ],
                      ),
                    )
                  : _errorMessage.isNotEmpty
                      ? Center(
                          child: ApiErrorHandler.buildErrorWidget(
                            message: _errorMessage,
                            onRetry: _loadEventsWithPositions,
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadEventsWithPositions,
                          color: Colors.blue[600],
                          child: SingleChildScrollView(
                            physics: AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      _buildFilterChip('Todos', 'all'),
                                      SizedBox(width: 8),
                                      _buildFilterChip(
                                          'Listo para seleccionar', 'ready'),
                                      SizedBox(width: 8),
                                      _buildFilterChip(
                                          'Red recomendada', 'recommended'),
                                      SizedBox(width: 8),
                                      _buildFilterChip('Red conocida', 'known'),
                                      SizedBox(width: 8),
                                      _buildFilterChip('Cubierto', 'covered'),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 24),

                                Text(
                                  '$_totalPositions ${_totalPositions == 1 ? 'posicion' : 'posiciones'} en ${_filteredEvents.length} ${_filteredEvents.length == 1 ? 'evento' : 'eventos'}',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 14,
                                  ),
                                ),
                                SizedBox(height: 16),

                                if (_filteredEvents.isEmpty)
                                  Container(
                                    padding: EdgeInsets.all(48),
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
                                            Icons.work_outline,
                                            color: Colors.grey[600],
                                            size: 64,
                                          ),
                                          SizedBox(height: 16),
                                          Text(
                                            'No hay posiciones para mostrar',
                                            style: TextStyle(
                                              color: Colors.grey[400],
                                              fontSize: 16,
                                            ),
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            'Intenta cambiar los filtros o crear nuevas posiciones',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 14,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                else
                                  Column(
                                    children: _filteredEvents.map((event) {
                                      return _buildEventCard(event);
                                    }).toList(),
                                  ),

                                SizedBox(height: 40),
                              ],
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}