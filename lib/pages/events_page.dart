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
import '../utils/error_handler.dart';
import '../providers/notification_provider.dart'; 
import '../models/notification_model.dart';

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
  bool _isSearchExpanded = false; 

  String _statusFilter = 'TODOS';
  List<String> _statusOptions = [
    'TODOS',
    'ACTIVE',
    'INACTIVE',
    'COMPLETED',
    'CANCELLED'
  ];

  bool _showNotifications = false;

  @override
  void initState() {
    super.initState();
    _loadEvents();
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
      final response = await http.get(
        Uri.parse('$baseUrl/events/my-events/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(Duration(seconds: 15));

      if (response.isSuccess) {
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
          _errorMessage = response.friendlyErrorMessage;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = ApiErrorHandler.handleNetworkException(e);
      });
    }
  }

  void _filterEvents() {
    setState(() {
      _filteredEvents = _events.where((event) {
        final Map<String, dynamic> eventData =
            event is Map ? Map<String, dynamic>.from(event) : {};
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
            _statusFilter == 'TODOS' || status == _statusFilter;

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

  Widget _buildSearchAndFilters() {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Container(
      padding: EdgeInsets.all(isMobile ? 10 : 14),
      decoration: BoxDecoration(
        color: Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFF30363D), width: 1),
      ),
      child: Column(
        children: [
          AnimatedContainer(
            duration: Duration(milliseconds: 300),
            child: _isSearchExpanded
                ? Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          autofocus: true,
                          style: TextStyle(color: Colors.white, fontSize: isMobile ? 14 : 16),
                          decoration: InputDecoration(
                            hintText: 'Buscar llamados...',
                            hintStyle: TextStyle(color: Colors.grey[600], fontSize: isMobile ? 14 : 16),
                            prefixIcon: Icon(Icons.search, color: Colors.grey[500], size: isMobile ? 20 : 24),
                            suffixIcon: IconButton(
                              icon: Icon(Icons.close, color: Colors.grey[500], size: isMobile ? 20 : 24),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                                setState(() {
                                  _isSearchExpanded = false;
                                });
                              },
                            ),
                            fillColor: Color(0xFF0D1117),
                            filled: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: isMobile ? 10 : 12),
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
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Botón de lupa para expandir búsqueda
                      InkWell(
                        onTap: () {
                          setState(() {
                            _isSearchExpanded = true;
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 12 : 14,
                            vertical: isMobile ? 8 : 10,
                          ),
                          decoration: BoxDecoration(
                            color: Color(0xFF0D1117),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Color(0xFF30363D)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.search, color: Colors.grey[500], size: isMobile ? 20 : 22),
                              if (_searchQuery.isNotEmpty) ...[
                                SizedBox(width: 6),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[600],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '1',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      // Filtros siempre visibles
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
                                    status == 'TODOS'
                                        ? 'TODOS'
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
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationBell() {
    final unreadCount = Provider.of<NotificationProvider>(context).unreadCount;
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

    final notificationProvider = Provider.of<NotificationProvider>(context);

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
                      if (notificationProvider.unreadCount > 0)
                        TextButton(
                          onPressed: notificationProvider.markAsRead,
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
                        onPressed: notificationProvider.clearAll,
                        tooltip: 'Limpiar todas',
                      ),
                    ],
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
                      itemCount: notificationProvider.notifications.length,
                      itemBuilder: (context, index) {
                        final notification = notificationProvider.notifications[index];
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

  Widget _buildNotificationItem(PushNotification notification) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    Color? iconColor;
    IconData? iconData;

    switch (notification.type) {
      case NotificationType.eventStartToday:
        iconColor = Colors.blue[400];
        iconData = Icons.event;
        break;
      case NotificationType.eventFinished:
        iconColor = Colors.green[400];
        iconData = Icons.check_circle;
        break;
      case NotificationType.activationReminder50:
        iconColor = Colors.orange[400];
        iconData = Icons.notifications_active;
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
        // Como PushNotification no tiene isRead individual, usamos transparente por defecto
        color: Colors.transparent,
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
          notification.title ?? 'Notificación',
          style: TextStyle(
            color: Colors.white,
            fontSize: isMobile ? 13 : 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: isMobile ? 2 : 4),
            Text(
              notification.body ?? '',
              style: TextStyle(
                color: Colors.grey[400], 
                fontSize: isMobile ? 11 : 12,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: isMobile ? 2 : 4),
            Text(
              _formatTimeAgo(notification.timestamp ?? DateTime.now()),
              style: TextStyle(
                color: Colors.grey[500], 
                fontSize: isMobile ? 9 : 10,
              ),
            ),
          ],
        ),
        onTap: () {
          // Aquí podrías navegar a la ruta de la notificación
          if (notification.route != null) {
             Navigator.pushNamed(context, notification.route!, arguments: notification.parameters);
          }
        },
      ),
    );
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
      margin: EdgeInsets.only(bottom: isMobile ? 10 : 14),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
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
                    fontSize: isMobile ? 15 : 17,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              SizedBox(width: isMobile ? 6 : 8),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 8 : 10, 
                  vertical: isMobile ? 3 : 4,
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
                    fontSize: isMobile ? 9 : 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 4 : 6),
          if (description.isNotEmpty) ...[
            Text(
              description,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: isMobile ? 12 : 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: isMobile ? 4 : 6),
          ],
          Row(
            children: [
              if (location.isNotEmpty) ...[
                Icon(Icons.location_on_outlined,
                    color: Colors.grey[500], size: isMobile ? 12 : 14),
                SizedBox(width: isMobile ? 2 : 3),
                Expanded(
                  child: Text(
                    location,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: isMobile ? 11 : 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              if (startDate != null && location.isNotEmpty)
                SizedBox(width: 8),
              if (startDate != null) ...[
                Icon(Icons.calendar_today_outlined,
                    color: Colors.grey[500], size: isMobile ? 12 : 14),
                SizedBox(width: isMobile ? 2 : 3),
                Text(
                  DateFormat('dd/MM/yyyy').format(startDate),
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: isMobile ? 11 : 12,
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: isMobile ? 8 : 10),
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
                      horizontal: isMobile ? 8 : 12, 
                      vertical: isMobile ? 6 : 8,
                    ),
                    side: BorderSide(color: Colors.blue[600]!, width: 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  icon: Icon(Icons.visibility_outlined,
                      color: Colors.blue[400], size: isMobile ? 13 : 15),
                  label: Text(
                    'Detalles',
                    style: TextStyle(
                      color: Colors.blue[400],
                      fontSize: isMobile ? 12 : 13,
                    ),
                  ),
                ),
              ),
              SizedBox(width: isMobile ? 6 : 10),
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
                      horizontal: isMobile ? 8 : 12, 
                      vertical: isMobile ? 6 : 8,
                    ),
                    side: BorderSide(color: Colors.grey[600]!, width: 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  icon: Icon(Icons.edit_outlined,
                      color: Colors.grey[400], size: isMobile ? 13 : 15),
                  label: Text(
                    'Editar',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: isMobile ? 12 : 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 6 : 8),
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
                  horizontal: isMobile ? 12 : 16, 
                  vertical: isMobile ? 8 : 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                elevation: 0,
              ),
              child: Text(
                'Activar rol',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isMobile ? 12 : 13,
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
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: Color(0xFF0D1117),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Container(
                  padding: EdgeInsets.only(
                    left: isMobile ? 12 : 16,
                    right: isMobile ? 12 : 16,
                    top: isMobile ? 8 : 10,
                    bottom: isMobile ? 10 : 12,
                  ),
                  color: Color(0xFF161B22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Título principal
                          Text(
                            'Mis Llamados',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isMobile ? 18 : 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          
                          // Botones del header
                          Row(
                            children: [
                              _buildNotificationBell(),
                              SizedBox(width: isMobile ? 6 : 10),
                              isMobile
                                  ? IconButton(
                                      onPressed: _navigateToCreateEvent,
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.blue[600],
                                        padding: EdgeInsets.all(7),
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
                                          horizontal: 14,
                                          vertical: 8,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                      ),
                                      icon: Icon(Icons.add, 
                                          color: Colors.white, 
                                          size: 16),
                                      label: Text(
                                        'Nuevo Evento',
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
                      SizedBox(height: 4),
                      
                      // Descripción compacta
                      Text(
                        'Gestiona todos tus llamados, revisa detalles y crea nuevas posiciones de trabajo.',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: isMobile ? 11 : 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                
                // CONTENIDO PRINCIPAL DESPLAZABLE
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isMobile ? 10 : 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Búsqueda y filtros
                        _buildSearchAndFilters(),
                        SizedBox(height: isMobile ? 10 : 14),

                        // Contador de llamados
                        Text(
                          '${_filteredEvents.length} llamado${_filteredEvents.length != 1 ? 's' : ''} encontrado${_filteredEvents.length != 1 ? 's' : ''}',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: isMobile ? 12 : 13,
                          ),
                        ),
                        SizedBox(height: isMobile ? 10 : 12),

                        // CONTENIDO PRINCIPAL (llamados)
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
                            child: ApiErrorHandler.buildErrorWidget(
                              message: _errorMessage,
                              onRetry: _loadEvents,
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
                                            _statusFilter != 'TODOS'
                                        ? 'No se encontraron llamados con los filtros aplicados'
                                        : 'No hay llamados creados',
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: isMobile ? 14 : 16,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    _searchQuery.isNotEmpty ||
                                            _statusFilter != 'TODOS'
                                        ? 'Intenta con otros términos de búsqueda'
                                        : 'Crea tu primer evento para comenzar',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: isMobile ? 12 : 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: 16),
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
                                        'Crear llamado',
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
                              if (event is Map) {
                                return _buildEventCard(Map<String, dynamic>.from(event));
                              }
                              return SizedBox.shrink();
                            }).toList(),
                          ),
                    
                        SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            _buildNotificationsPanel(),
          ],
        ),
      ),
    );
  }
}