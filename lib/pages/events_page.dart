import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import '../auth_provider.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'create_event_page.dart';
import 'events_details_page.dart';
import 'edit_event_page.dart';
import 'create_posicion_page.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../componentes/bottoom_company.dart';

class EventsPage extends StatefulWidget {
  @override
  _EventsPageState createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  List<dynamic> _events = [];
  List<dynamic> _filteredEvents = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String _searchQuery = '';
  Timer? _searchTimer;
  TextEditingController _searchController = TextEditingController();

  // Filtros
  String _statusFilter = 'Todos';
  List<String> _statusOptions = [
    'Todos',
    'ACTIVE',
    'INACTIVE',
    'COMPLETED',
    'CANCELLED'
  ];

  List<NotificationItem> _notifications = [];
  bool _showNotifications = false;

  @override
  void initState() {
    super.initState();
    _loadEvents();
    _loadNotifications();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    final baseUrl = dotenv.env['API_BASE_URL'];
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.accessToken;

    if (token == null || baseUrl == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'No autenticado o API no configurada';
      });
      return;
    }

    try {
      print('Cargando eventos desde: $baseUrl/events/');
      final response = await http.get(
        Uri.parse('$baseUrl/events/my-events/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('Respuesta eventos (${response.statusCode}): ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<dynamic> loadedEvents = [];
        if (data is List) {
          loadedEvents = data;
        } else if (data is Map) {
          if (data['items'] is List)
            loadedEvents = data['items'];
          else if (data['data'] is List)
            loadedEvents = data['data'];
          else if (data['results'] is List) loadedEvents = data['results'];
        }

        setState(() {
          _events = loadedEvents;
          _filteredEvents = loadedEvents;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error al cargar eventos: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error de conexión: $e';
      });
    }
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _notifications = [
        NotificationItem(
          id: '1',
          title: 'Nuevo evento asignado',
          message: 'Se te ha asignado el evento "Festival de Verano"',
          time: DateTime.now().subtract(Duration(minutes: 5)),
          isRead: false,
          type: 'event',
        ),
        NotificationItem(
          id: '2',
          title: 'Actualización de estado',
          message: 'El evento "Concierto Rock" ha cambiado a COMPLETADO',
          time: DateTime.now().subtract(Duration(hours: 2)),
          isRead: true,
          type: 'status',
        ),
        NotificationItem(
          id: '3',
          title: 'Recordatorio de pago',
          message: 'El pago del evento "Conferencia Tech" vence en 3 días',
          time: DateTime.now().subtract(Duration(days: 1)),
          isRead: false,
          type: 'payment',
        ),
      ];
    });
  }

  void _filterEvents() {
    setState(() {
      _filteredEvents = _events.where((event) {
        final Map<String, dynamic> eventData =
            event is Map<String, dynamic> ? event : {};
        final String title = eventData['title']?.toString().toLowerCase() ?? '';
        final String description =
            eventData['description']?.toString().toLowerCase() ?? '';
        final String location =
            eventData['location']?.toString().toLowerCase() ?? '';
        final String status = eventData['status']?.toString() ?? '';

        bool matchesSearch = _searchQuery.isEmpty ||
            title.contains(_searchQuery.toLowerCase()) ||
            description.contains(_searchQuery.toLowerCase()) ||
            location.contains(_searchQuery.toLowerCase());

        bool matchesStatus =
            _statusFilter == 'Todos' || status == _statusFilter;

        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  void _onSearchChanged(String query) {
    if (_searchTimer != null) {
      _searchTimer!.cancel();
    }

    _searchTimer = Timer(Duration(milliseconds: 300), () {
      setState(() {
        _searchQuery = query;
        _filterEvents();
      });
    });
  }

  void _navigateToCreateEvent() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateEventPage(onEventCreated: _loadEvents),
      ),
    );
  }

  void _markNotificationAsRead(String id) {
    setState(() {
      _notifications = _notifications.map((notification) {
        if (notification.id == id) {
          return notification.copyWith(isRead: true);
        }
        return notification;
      }).toList();
    });
  }

  void _clearAllNotifications() {
    setState(() {
      _notifications = [];
    });
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

  Widget _buildSearchAndFilters() {
    // Detectar si es móvil
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFF30363D), width: 1),
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            style: TextStyle(color: Colors.white, fontSize: isMobile ? 14 : 16),
            decoration: InputDecoration(
              hintText: 'Buscar eventos...',
              hintStyle: TextStyle(color: Colors.grey[600], fontSize: isMobile ? 14 : 16),
              prefixIcon: Icon(Icons.search, color: Colors.grey[500], size: isMobile ? 20 : 24),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: Colors.grey[500], size: isMobile ? 20 : 24),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              fillColor: Color(0xFF0D1117),
              filled: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: isMobile ? 10 : 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Color(0xFF30363D)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Color(0xFF30363D)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.blue[600]!),
              ),
            ),
          ),
          SizedBox(height: isMobile ? 12 : 16),

          Row(
            children: [
              Text(
                'Filtrar por estado:',
                style: TextStyle(color: Colors.grey[400], fontSize: isMobile ? 12 : 14),
              ),
              SizedBox(width: isMobile ? 8 : 12),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _statusOptions.map((status) {
                      final bool isActive = _statusFilter == status;
                      return Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(
                            status == 'Todos'
                                ? 'Todos'
                                : _translateStatus(status),
                            style: TextStyle(
                              color: isActive ? Colors.white : Colors.grey[400],
                              fontSize: isMobile ? 10 : 12,
                            ),
                          ),
                          selected: isActive,
                          onSelected: (selected) {
                            setState(() {
                              _statusFilter = status;
                              _filterEvents();
                            });
                          },
                          backgroundColor: Color(0xFF0D1117),
                          selectedColor: Colors.blue[600],
                          side: BorderSide(
                            color: isActive
                                ? Colors.blue[600]!
                                : Color(0xFF30363D),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 8 : 12,
                            vertical: isMobile ? 4 : 6,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationBell() {
    final unreadCount = _notifications.where((n) => !n.isRead).length;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Stack(
      children: [
        IconButton(
          icon: Icon(
            Icons.notifications_outlined, 
            color: Colors.white,
            size: isMobile ? 22 : 24,
          ),
          onPressed: () {
            setState(() {
              _showNotifications = !_showNotifications;
            });
          },
        ),
        if (unreadCount > 0)
          Positioned(
            right: isMobile ? 6 : 8,
            top: isMobile ? 6 : 8,
            child: Container(
              padding: EdgeInsets.all(isMobile ? 2 : 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
              ),
              constraints: BoxConstraints(
                minWidth: isMobile ? 14 : 16, 
                minHeight: isMobile ? 14 : 16,
              ),
              child: Text(
                unreadCount > 9 ? '9+' : '$unreadCount',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isMobile ? 8 : 10,
                  fontWeight: FontWeight.bold,
                ),
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

    return Positioned(
      right: isMobile ? 8 : 16,
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
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFF30363D), width: 1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Notificaciones',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isMobile ? 14 : 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      if (_notifications.any((n) => !n.isRead))
                        TextButton(
                          onPressed: _markAllAsRead,
                          child: Text(
                            'Marcar todas',
                            style: TextStyle(
                              color: Colors.blue[400],
                              fontSize: isMobile ? 10 : 12,
                            ),
                          ),
                        ),
                      SizedBox(width: isMobile ? 4 : 8),
                      IconButton(
                        icon: Icon(Icons.clear_all,
                            color: Colors.grey[500], size: isMobile ? 18 : 20),
                        onPressed: _clearAllNotifications,
                        tooltip: 'Limpiar todas',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: _notifications.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_none,
                              color: Colors.grey[600], size: isMobile ? 40 : 48),
                          SizedBox(height: isMobile ? 8 : 12),
                          Text(
                            'No hay notificaciones',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: isMobile ? 14 : 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _notifications.length,
                      itemBuilder: (context, index) {
                        final notification = _notifications[index];
                        return _buildNotificationItem(notification);
                      },
                    ),
            ),

            Container(
              padding: EdgeInsets.all(isMobile ? 10 : 12),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFF30363D), width: 1),
                ),
              ),
              child: TextButton(
                onPressed: () {
                  // TODO: Navegar a todas las notificaciones
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Ver todas las notificaciones',
                      style: TextStyle(
                        color: Colors.blue[400],
                        fontSize: isMobile ? 12 : 14,
                      ),
                    ),
                    SizedBox(width: isMobile ? 2 : 4),
                    Icon(Icons.arrow_forward,
                        color: Colors.blue[400], size: isMobile ? 14 : 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationItem(NotificationItem notification) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    Color? iconColor;
    IconData? iconData;

    switch (notification.type) {
      case 'event':
        iconColor = Colors.blue[400];
        iconData = Icons.event;
        break;
      case 'status':
        iconColor = Colors.green[400];
        iconData = Icons.check_circle;
        break;
      case 'payment':
        iconColor = Colors.orange[400];
        iconData = Icons.payment;
        break;
      default:
        iconColor = Colors.grey[400];
        iconData = Icons.notifications;
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFF30363D), width: 1),
        ),
        color: !notification.isRead
            ? Colors.blue[900]!.withOpacity(0.1)
            : Colors.transparent,
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 16, 
          vertical: isMobile ? 8 : 12,
        ),
        leading: Container(
          width: isMobile ? 36 : 40,
          height: isMobile ? 36 : 40,
          decoration: BoxDecoration(
            color: iconColor!.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(iconData, color: iconColor, size: isMobile ? 18 : 20),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            color: Colors.white,
            fontSize: isMobile ? 13 : 14,
            fontWeight:
                !notification.isRead ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: isMobile ? 2 : 4),
            Text(
              notification.message,
              style: TextStyle(
                color: Colors.grey[400], 
                fontSize: isMobile ? 11 : 12,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: isMobile ? 2 : 4),
            Text(
              _formatTimeAgo(notification.time),
              style: TextStyle(
                color: Colors.grey[500], 
                fontSize: isMobile ? 9 : 10,
              ),
            ),
          ],
        ),
        trailing: !notification.isRead
            ? Container(
                width: isMobile ? 6 : 8,
                height: isMobile ? 6 : 8,
                decoration: BoxDecoration(
                  color: Colors.blue[400],
                  borderRadius: BorderRadius.circular(isMobile ? 3 : 4),
                ),
              )
            : null,
        onTap: () {
          _markNotificationAsRead(notification.id);
          // TODO: Navegar a la acción correspondiente
        },
      ),
    );
  }

  void _markAllAsRead() {
    setState(() {
      _notifications =
          _notifications.map((n) => n.copyWith(isRead: true)).toList();
    });
  }

  String _formatTimeAgo(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inSeconds < 60) {
      return 'Hace ${difference.inSeconds} segundos';
    } else if (difference.inMinutes < 60) {
      return 'Hace ${difference.inMinutes} minutos';
    } else if (difference.inHours < 24) {
      return 'Hace ${difference.inHours} horas';
    } else if (difference.inDays < 7) {
      return 'Hace ${difference.inDays} días';
    } else {
      return DateFormat('dd/MM/yyyy').format(time);
    }
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    final title = event['title']?.toString() ?? 'Sin título';
    final description = event['description']?.toString() ?? '';
    final location = event['location']?.toString() ?? '';
    final status = event['status']?.toString() ?? 'ACTIVE';

    DateTime? startDate;
    if (event['start_date'] != null) {
      try {
        startDate = DateTime.tryParse(event['start_date'].toString());
      } catch (e) {
        print('Error parsing date: $e');
      }
    }

    String statusText = _translateStatus(status);

    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 12 : 16),
      padding: EdgeInsets.all(isMobile ? 16 : 20),
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
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              SizedBox(width: isMobile ? 8 : 10),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 10 : 12, 
                  vertical: isMobile ? 4 : 6,
                ),
                decoration: BoxDecoration(
                  color: status == 'ACTIVE'
                      ? Colors.green[900]!.withOpacity(0.2)
                      : Colors.orange[900]!.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: status == 'ACTIVE'
                        ? Colors.green[400]!
                        : Colors.orange[400]!,
                    width: 1,
                  ),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: status == 'ACTIVE'
                        ? Colors.green[400]
                        : Colors.orange[400],
                    fontSize: isMobile ? 10 : 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 6 : 8),
          if (description.isNotEmpty) ...[
            Text(
              description,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: isMobile ? 13 : 14,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: isMobile ? 6 : 8),
          ],
          if (location.isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(Icons.location_on_outlined,
                      color: Colors.grey[500], size: isMobile ? 14 : 16),
                ),
                SizedBox(width: isMobile ? 3 : 4),
                Expanded(
                  child: Text(
                    location,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: isMobile ? 12 : 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 6 : 8),
          ],
          if (startDate != null) ...[
            Row(
              children: [
                Icon(Icons.calendar_today_outlined,
                    color: Colors.grey[500], size: isMobile ? 14 : 16),
                SizedBox(width: isMobile ? 3 : 4),
                Text(
                  DateFormat('dd/MM/yyyy').format(startDate),
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: isMobile ? 12 : 13,
                  ),
                ),
              ],
            ),
          ],
          SizedBox(height: isMobile ? 12 : 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            EventDetailsPage(eventId: event['id'].toString()),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 12 : 16, 
                      vertical: isMobile ? 8 : 10,
                    ),
                    side: BorderSide(color: Colors.blue[600]!, width: 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  icon: Icon(Icons.visibility_outlined,
                      color: Colors.blue[400], size: isMobile ? 14 : 16),
                  label: Text(
                    'Detalles',
                    style: TextStyle(
                      color: Colors.blue[400],
                      fontSize: isMobile ? 13 : 14,
                    ),
                  ),
                ),
              ),
              SizedBox(width: isMobile ? 8 : 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            EditEventPage(eventId: event['id'].toString()),
                      ),
                    ).then((updated) {
                      if (updated == true) {
                        _loadEvents(); 
                      }
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 12 : 16, 
                      vertical: isMobile ? 8 : 10,
                    ),
                    side: BorderSide(color: Colors.grey[600]!, width: 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  icon: Icon(Icons.edit_outlined,
                      color: Colors.grey[400], size: isMobile ? 14 : 16),
                  label: Text(
                    'Editar',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: isMobile ? 13 : 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 10 : 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  '/create_position',
                  arguments: {
                    'eventId': event['id'].toString(),
                    'eventTitle': title,
                  },
                ).then((created) {
                  if (created == true) {
                    _loadEvents();
                  }
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : 20, 
                  vertical: isMobile ? 10 : 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                elevation: 0,
              ),
              child: Text(
                'Generar posición',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isMobile ? 13 : 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _translateStatus(String status) {
    switch (status) {
      case 'ACTIVE':
        return 'ACTIVO';
      case 'INACTIVE':
        return 'INACTIVO';
      case 'COMPLETED':
        return 'COMPLETADO';
      case 'CANCELLED':
        return 'CANCELADO';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userData = authProvider.userInfo;
    
    // Detectar si es móvil
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: Color(0xFF0D1117),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Header principal con logo - Fijo
                Container(
                  padding: EdgeInsets.all(isMobile ? 12 : 16),
                  color: Color(0xFF161B22),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Logo y título
                      Row(
                        children: [
                          Container(
                            width: isMobile ? 28 : 32,
                            height: isMobile ? 28 : 32,
                            decoration: BoxDecoration(
                              color: Colors.blue[600],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(Icons.connect_without_contact,
                                color: Colors.white, 
                                size: isMobile ? 16 : 20),
                          ),
                          SizedBox(width: isMobile ? 8 : 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Corte y Queda',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: isMobile ? 14 : 16,
                                      fontWeight: FontWeight.bold)),
                              Text('SISTEMA OPERATIVO OPERACIONAL',
                                  style: TextStyle(
                                      color: Colors.grey[600], 
                                      fontSize: isMobile ? 7 : 9)),
                            ],
                          ),
                        ],
                      ),
                      
                      // Botones del header
                      Row(
                        children: [
                          _buildNotificationBell(),
                          SizedBox(width: isMobile ? 8 : 12),
                          // Botón Nuevo Evento adaptado para móvil
                          isMobile
                              ? IconButton(
                                  onPressed: _navigateToCreateEvent,
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.blue[600],
                                    padding: EdgeInsets.all(8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  icon: Icon(Icons.add, 
                                      color: Colors.white, 
                                      size: 20),
                                )
                              : ElevatedButton.icon(
                                  onPressed: _navigateToCreateEvent,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue[600],
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  icon: Icon(Icons.add, 
                                      color: Colors.white, 
                                      size: 18),
                                  label: Text(
                                    'Nuevo Evento',
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
                ),
                
                // CONTENIDO PRINCIPAL DESPLAZABLE
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isMobile ? 12 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Título de la página - Desplazable
                        Text(
                          'Mis Eventos',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isMobile ? 20 : 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: isMobile ? 6 : 8),
                        
                        // Descripción - Desplazable
                        Text(
                          'Gestiona todos tus eventos, revisa detalles y crea nuevas posiciones de trabajo.',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: isMobile ? 13 : 14,
                          ),
                        ),
                        SizedBox(height: isMobile ? 16 : 20),
                        
                        // Búsqueda y filtros - Desplazable
                        _buildSearchAndFilters(),
                        SizedBox(height: isMobile ? 16 : 20),

                        // Contador de eventos - Desplazable
                        Text(
                          '${_filteredEvents.length} evento${_filteredEvents.length != 1 ? 's' : ''} encontrado${_filteredEvents.length != 1 ? 's' : ''}',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: isMobile ? 13 : 14,
                          ),
                        ),
                        SizedBox(height: isMobile ? 12 : 16),

                        // CONTENIDO PRINCIPAL (eventos)
                        if (_isLoading)
                          Container(
                            height: 200,
                            child: Center(
                              child: CircularProgressIndicator(
                                  color: Colors.blue[600]),
                            ),
                          )
                        else if (_errorMessage.isNotEmpty)
                          Container(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.error_outline,
                                      color: Colors.red[400], 
                                      size: isMobile ? 40 : 48),
                                  SizedBox(height: 12),
                                  Text(
                                    _errorMessage,
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: isMobile ? 14 : 16,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: 12),
                                  ElevatedButton(
                                    onPressed: _loadEvents,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue[600],
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 10,
                                      ),
                                    ),
                                    child: Text(
                                      'Reintentar',
                                      style: TextStyle(fontSize: isMobile ? 14 : 16),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else if (_filteredEvents.isEmpty)
                          Container(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search_off,
                                      color: Colors.grey[600], 
                                      size: isMobile ? 48 : 64),
                                  SizedBox(height: 12),
                                  Text(
                                    _searchQuery.isNotEmpty ||
                                            _statusFilter != 'Todos'
                                        ? 'No se encontraron eventos con los filtros aplicados'
                                        : 'No hay eventos creados',
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: isMobile ? 14 : 16,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    _searchQuery.isNotEmpty ||
                                            _statusFilter != 'Todos'
                                        ? 'Intenta con otros términos de búsqueda'
                                        : 'Crea tu primer evento para comenzar',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: isMobile ? 12 : 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: 16),
                                  // Botón para crear evento cuando no hay eventos
                                  if (_events.isEmpty)
                                    ElevatedButton.icon(
                                      onPressed: _navigateToCreateEvent,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue[600],
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                      ),
                                      icon: Icon(Icons.add, 
                                          color: Colors.white, 
                                          size: 18),
                                      label: Text(
                                        'Crear Primer Evento',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          )
                        else
                          Column(
                            children: _filteredEvents.map<Widget>((event) {
                              if (event is Map<String, dynamic>) {
                                return _buildEventCard(event);
                              }
                              return SizedBox.shrink();
                            }).toList(),
                          ),
                        
                        // Espacio adicional al final para evitar que se pegue al nav
                        SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                
                // Navegación inferior - Fija
                CompanyBottomNav(currentRoute: '/events'),
              ],
            ),
            
            // Panel de notificaciones
            _buildNotificationsPanel(),
          ],
        ),
      ),
    );
  }
}

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final DateTime time;
  final bool isRead;
  final String type;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.time,
    required this.isRead,
    required this.type,
  });

  NotificationItem copyWith({
    String? id,
    String? title,
    String? message,
    DateTime? time,
    bool? isRead,
    String? type,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      time: time ?? this.time,
      isRead: isRead ?? this.isRead,
      type: type ?? this.type,
    );
  }
}