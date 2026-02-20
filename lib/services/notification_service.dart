import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/notification_model.dart';


// Handler para background (debe ser top-level, fuera de la clase)
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  // Manejo de notificación en background
  // Aquí puedes procesar datos sin UI
}

class NotificationService {
  FirebaseMessaging? _firebaseMessaging;
  final GlobalKey<NavigatorState> navigatorKey;
  
  // Streams para comunicación con la UI
  final _notificationStream = StreamController<PushNotification>.broadcast();
  final _notificationCountStream = StreamController<int>.broadcast();
  
  int _unreadCount = 0;
  List<PushNotification> _notifications = [];
  bool _isInitialized = false;
  
  Stream<PushNotification> get notificationStream => _notificationStream.stream;
  Stream<int> get notificationCountStream => _notificationCountStream.stream;
  List<PushNotification> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isInitialized => _isInitialized;
  
  NotificationService({required this.navigatorKey}) {
    _tryInitializeFirebase();
  }
  
  void _tryInitializeFirebase() {
    try {
      _firebaseMessaging = FirebaseMessaging.instance;
    } catch (e) {
      print('Error obteniendo FirebaseMessaging instance: $e');
      _firebaseMessaging = null;
    }
  }
  
  Future<void> initialize() async {
    
    // Verificar si Firebase está disponible
    if (_firebaseMessaging == null) {
      _isInitialized = false;
      return;
    }
    
    try {
      await _setupFirebase();
      await _setupInteractedMessage();
      await _loadStoredNotifications();
      
      _isInitialized = true;
    } catch (e) {
      print('Error inicializando servicio de notificaciones: $e');
      _isInitialized = false;
    }
  }
  
  Future<void> _setupFirebase() async {
    if (_firebaseMessaging == null) {
      return;
    }
    
    try {
      // Solicitar permisos
      await _firebaseMessaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        announcement: false,
      );
      
      // Obtener token
      await _getFCMToken();
      
      // Registrar handler de background
      FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
      
      // Configurar manejadores
      _setupMessageHandlers();
      
      // Configurar para iOS
      await _configureIOS();
      
    } catch (e) {
      print('Error en _setupFirebase: $e');
      rethrow;
    }
  }
  
  Future<String?> _getFCMToken() async {
    if (_firebaseMessaging == null) {
      return null;
    }
    
    try {
      final token = await _firebaseMessaging!.getToken();
      
      return token;
    } catch (e) {
      print('Error obteniendo token FCM: $e');
      return null;
    }
  }
  
  void _setupMessageHandlers() {
    if (_firebaseMessaging == null) {
      return;
    }
    
    try {
      // 1. App en primer plano
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _handleIncomingNotification(message, fromBackground: false);
      });
      
      // 2. App en segundo plano (usuario toca notificación)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleIncomingNotification(message, fromBackground: true);
      });
    } catch (e) {
      print('Error configurando message handlers: $e');
    }
  }
  
  Future<void> _setupInteractedMessage() async {
    if (_firebaseMessaging == null) return;
    
    try {
      // 3. App cerrada (usuario toca notificación)
      final initialMessage = await _firebaseMessaging!.getInitialMessage();
      if (initialMessage != null) {
        // Pequeño delay para que la app se inicialice completamente
        Timer(const Duration(milliseconds: 1500), () {
          _handleIncomingNotification(initialMessage, fromBackground: true);
        });
      }
    } catch (e) {
      print('Error en _setupInteractedMessage: $e');
    }
  }
  
  Future<void> _configureIOS() async {
    if (_firebaseMessaging == null) return;
    
    try {
      // Configuraciones específicas para iOS
      await _firebaseMessaging!.setForegroundNotificationPresentationOptions(
        alert: true,    // Mostrar alerta
        badge: true,    // Actualizar badge
        sound: true,    // Reproducir sonido
      );
    } catch (e) {
      print('Error configurando iOS: $e');
    }
  }
  
  void _handleIncomingNotification(
    RemoteMessage message, {
    bool fromBackground = false
  }) {
    try {
      // Convertir a nuestro modelo
      final notification = PushNotification.fromRemoteMessage(message);
      
      // Agregar a la lista
      _addNotificationToList(notification);
      
      // Incrementar contador no leídos
      if (!fromBackground) {
        _incrementUnreadCount();
      }
      
      // Navegar si viene de background/cerrada
      if (fromBackground && notification.route != null) {
        _navigateToNotificationScreen(notification);
      }
      
      // Mostrar en app si está en primer plano
      if (!fromBackground) {
        _showInAppNotification(notification);
      }
      
      // Emitir al stream
      _notificationStream.add(notification);
      
    } catch (e) {
      print('Error manejando notificación: $e');
    }
  }
  
  void _addNotificationToList(PushNotification notification) {
    _notifications.insert(0, notification); // Agregar al inicio
    // _saveNotifications(); // Persistir (Descomentar cuando se implemente)
  }
  
  void _incrementUnreadCount() {
    _unreadCount++;
    _notificationCountStream.add(_unreadCount);
    _updateAppBadge();
  }
  
  void markAsRead() {
    _unreadCount = 0;
    _notificationCountStream.add(_unreadCount);
    _updateAppBadge();
  }
  
  void markNotificationAsRead(int index) {
    if (index >= 0 && index < _notifications.length) {
      // Aquí podrías marcar notificaciones individuales como leídas
      _updateAppBadge();
    }
  }
  
  void _navigateToNotificationScreen(PushNotification notification) {
    if (notification.route == null) {
      return;
    }
    
    // Usar Future.microtask para navegar en el siguiente ciclo de eventos
    Future.microtask(() {
      final currentState = navigatorKey.currentState;
      if (currentState != null && !currentState.mounted) {
        return;
      }
      
      try {
        navigatorKey.currentState?.pushNamed(
          notification.route!,
          arguments: notification.parameters,
        );
      } catch (e) {
        print('Error navegando a ${notification.route}: $e');
        // Fallback a pantalla de notificaciones
        _navigateToNotificationsFallback();
      }
    });
  }
  
  void _navigateToNotificationsFallback() {
    Future.microtask(() {
      try {
        navigatorKey.currentState?.pushNamed('/notifications_list');
      } catch (e) {
        print('Error navegando a fallback: $e');
      }
    });
  }
  
  void _showInAppNotification(PushNotification notification) {
    // Verificar si el contexto está disponible
    final context = navigatorKey.currentContext;
    if (context == null) {
      return;
    }
    
    try {
      final config = NotificationMapper.getConfig(notification.type);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: config.color.withOpacity(0.9),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(config.icon, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      notification.title ?? 'Nueva notificación',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (notification.body != null) ...[
                SizedBox(height: 4),
                Text(
                  notification.body!,
                  style: TextStyle(color: Colors.white70),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
          action: SnackBarAction(
            label: 'VER',
            textColor: Colors.white,
            onPressed: () => _navigateToNotificationScreen(notification),
          ),
          duration: Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(10),
        ),
      );
    } catch (e) {
      print('Error mostrando snackbar: $e');
    }
  }
  
  void _updateAppBadge() {
    if (_firebaseMessaging == null) return;
    
    try {
      // Actualizar badge (solo funciona en iOS)
      // Nota: FirebaseMessaging no tiene método setBadge nativo. Se requiere un paquete externo o configuración de payload.
      // _firebaseMessaging!.setBadge(_unreadCount);
    } catch (e) {
      print('Error actualizando badge: $e');
    }
  }
  
  Future<void> _loadStoredNotifications() async {
    try {
      // Aquí cargarías notificaciones de almacenamiento local (SharedPreferences)
      // Ejemplo con SharedPreferences:
      /*
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson = prefs.getStringList('notifications');
      if (notificationsJson != null) {
        _notifications = notificationsJson
            .map((json) => PushNotification.fromJson(jsonDecode(json)))
            .toList();
      }
      */
    } catch (e) {
      print('Error cargando notificaciones almacenadas: $e');
    }
  }
  
  Future<void> clearAllNotifications() async {
    try {
      _notifications.clear();
      _unreadCount = 0;
      _notificationCountStream.add(_unreadCount);
      _updateAppBadge();
      
      // Limpiar almacenamiento local
      /*
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('notifications');
      */
    } catch (e) {
      print('Error limpiando notificaciones: $e');
    }
  }
  
  // Método para forzar re-inicialización si Firebase falló al inicio
  Future<void> retryInitialize() async {
    _tryInitializeFirebase();
    await initialize();
  }
  
  
  void dispose() {
    _notificationStream.close();
    _notificationCountStream.close();
  }
}