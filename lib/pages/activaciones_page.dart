import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import '../auth_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ActivationsPage extends StatefulWidget {
  @override
  _ActivationsPageState createState() => _ActivationsPageState();
}

class _ActivationsPageState extends State<ActivationsPage> {
  List<Map<String, dynamic>> _positions = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String _filter = 'all'; 

  @override
  void initState() {
    super.initState();
    _loadPositions();
  }

  Future<void> _loadPositions() async {
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
      print('Cargando todas las posiciones...');
      final response = await http.get(
        Uri.parse('$baseUrl/positions/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        await _processPositionsResponse(response.body);
      } else {
        await _loadPositionsAlternative();
      }
    } catch (e) {
      print('Error cargando posiciones: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error de conexión';
      });
    }
  }

  Future<void> _processPositionsResponse(String responseBody) async {
    try {
      final data = jsonDecode(responseBody);
      List<dynamic> positionsList = [];

      if (data is List) {
        positionsList = data;
      } else if (data is Map) {
        if (data.containsKey('id')) {
          positionsList = [data];
        } else if (data['items'] is List) {
          positionsList = data['items'];
        } else if (data['data'] is List) {
          positionsList = data['data'];
        } else if (data['results'] is List) {
          positionsList = data['results'];
        }
      }

      final stageOptions = [
        'LIST_READY',
        'RED_RECOMMENDED',
        'RED_KNOWN',
        'FILLED'
      ];

      setState(() {
        _positions = positionsList.map<Map<String, dynamic>>((position) {
          final randomStage =
              stageOptions[(position['id']?.hashCode ?? 0) % stageOptions.length];
          return {
            'id': position['id']?.toString() ?? '',
            'role_name': position['role_name']?.toString() ?? 'Sin nombre',
            'quantity_required': position['quantity_required'] ?? 1,
            'pay_rate': position['pay_rate']?.toDouble() ?? 0.0,
            'currency': position['currency']?.toString() ?? 'USD',
            'event_id': position['event_id']?.toString() ?? '',
            'fill_stage': randomStage,
          };
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error procesando respuesta: $e');
      await _loadPositionsAlternative();
    }
  }

  Future<void> _loadPositionsAlternative() async {
    setState(() {
      _positions = [
      
      ];
      _isLoading = false;
    });
  }

  List<Map<String, dynamic>> get _filteredPositions {
    if (_filter == 'all') return _positions;

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
        return _positions;
    }

    return _positions
        .where((position) => position['fill_stage'] == stageFilter)
        .toList();
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

  Widget _buildSidebar(Map<String, dynamic>? userData) {
    return Container(
      width: 240,
      color: Color(0xFF161B22),
      child: SafeArea(
        child: Column(
          children: [
            // Logo
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

            _buildMenuItem(Icons.dashboard_outlined, 'Panel', false, () {
              Navigator.pushReplacementNamed(context, '/company_dashboard');
            }),
            _buildMenuItem(Icons.bolt_outlined, 'Activaciones', true, () {
            }),
            _buildMenuItem(Icons.event_outlined, 'Eventos', false, () {
              Navigator.pushNamed(context, '/events');
            }),
            _buildMenuItem(Icons.people_outline, 'Red / Historial', false, () {
              Navigator.pushNamed(context, '/company-history');
            }),
            _buildMenuItem(Icons.settings_outlined, 'Configuración', false,
                () {
              Navigator.pushNamed(context, '/company-settings');
            }),

            Spacer(),

            // Footer del sidebar
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

  Widget _buildPositionCard(Map<String, dynamic> position) {
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
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(width: 12),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStageColor(position['fill_stage'])
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _getStageColor(position['fill_stage']),
                    width: 1,
                  ),
                ),
                child: Text(
                  _getStageText(position['fill_stage']),
                  style: TextStyle(
                    color: _getStageColor(position['fill_stage']),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPositionDetail(
                  'Cantidad:', '${position['quantity_required']}'),
              _buildPositionDetail('Tarifa:',
                  '\$${position['pay_rate']} ${position['currency']}'),
              _buildPositionDetail('ID del evento:', position['event_id']),
            ],
          ),
          SizedBox(height: 16),

          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue[900]!.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue[400]!, width: 1),
                ),
                child: Text(
                  'PRIVADO',
                  style: TextStyle(
                    color: Colors.blue[400],
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Spacer(),
              ElevatedButton(
                onPressed: () {
                  _viewCandidates(position['id']);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: Text(
                  'Ver candidatos',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPositionDetail(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            '$label ',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _viewCandidates(String positionId) {
    Navigator.pushNamed(
      context,
      '/position_candidates',
      arguments: positionId,
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
        child: Row(
          children: [
            if (!isMobile) _buildSidebar(userData),

            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: Colors.blue[600]),
                    )
                  : _errorMessage.isNotEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline,
                                  color: Colors.red[400], size: 48),
                              SizedBox(height: 16),
                              Text(
                                _errorMessage,
                                style: TextStyle(color: Colors.grey[400]),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadPositions,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue[600],
                                ),
                                child: Text('Reintentar'),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          padding: EdgeInsets.all(isMobile ? 16 : 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                             
                              if (isMobile) ...[
                                Builder(builder: (context) {
                                  return Row(
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.menu,
                                            color: Colors.white),
                                        onPressed: () =>
                                            Scaffold.of(context).openDrawer(),
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Posiciones activas',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.refresh,
                                            color: Colors.white),
                                        onPressed: _loadPositions,
                                        tooltip: 'Refrescar',
                                      ),
                                    ],
                                  );
                                }),
                                SizedBox(height: 16),
                              ] else ...[
                                // Header desktop
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Posiciones activas',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.refresh,
                                          color: Colors.white),
                                      onPressed: _loadPositions,
                                      tooltip: 'Refrescar',
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                              ],

                              // Descripción
                              Text(
                                'Administra y revisa tus posiciones de trabajo actuales y sus candidatos.',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(height: 24),

                              // Filtros
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
                                '${_filteredPositions.length} posiciones encontradas',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(height: 16),

                              if (_filteredPositions.isEmpty)
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
                                  children: _filteredPositions.map((position) {
                                    return _buildPositionCard(position);
                                  }).toList(),
                                ),

                              SizedBox(height: 40),
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