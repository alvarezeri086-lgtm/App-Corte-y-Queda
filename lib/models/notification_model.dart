import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class PushNotification {
  final String? title;
  final String? body;
  final Map<String, dynamic>? data;
  final NotificationType type;
  final String? route;
  final Map<String, dynamic>? parameters;
  final DateTime? timestamp;

  PushNotification({
    this.title,
    this.body,
    this.data,
    required this.type,
    this.route,
    this.parameters,
    this.timestamp,
  });

  factory PushNotification.fromRemoteMessage(RemoteMessage message) {
    final data = message.data;

    // Mapear el tipo de notificación
    final type = _mapNotificationType(data['type'] ?? 'general');

    // Obtener ruta y parámetros según el tipo
    final routeInfo = NotificationMapper.getRouteConfig(type, data);

    return PushNotification(
      title: message.notification?.title,
      body: message.notification?.body,
      data: data,
      type: type,
      route: routeInfo['route'],
      parameters: routeInfo['parameters'],
      timestamp: DateTime.now(),
    );
  }

  static NotificationType _mapNotificationType(String typeString) {
    switch (typeString) {
      // EVENTOS
      case 'EVENT_CANCELLED':
        return NotificationType.eventCancelled;
      case 'EVENT_FINISHED':
        return NotificationType.eventFinished;
      case 'EVENT_POSITION_CANCELLED':
        return NotificationType.eventPositionCancelled;
      case 'EVENT_START_TODAY':
        return NotificationType.eventStartToday;

      // ACTIVACIONES
      case 'ACTIVATION_REMINDER_50':
        return NotificationType.activationReminder50;
      case 'ACTIVATION_REMINDER_90':
        return NotificationType.activationReminder90;

      // ENTREVISTAS
      case 'INTERVIEW_PENDING':
        return NotificationType.interviewPending;
      case 'INTERVIEW_REQUIRED':
        return NotificationType.interviewRequired;
      case 'INTERVIEW_ACCEPTED':
        return NotificationType.interviewAccepted;
      case 'INTERVIEW_PROPOSED':
        return NotificationType.interviewProposed;

      default:
        return NotificationType.general;
    }
  }
}

enum NotificationType {
  // Eventos
  eventCancelled,
  eventFinished,
  eventPositionCancelled,
  eventStartToday,

  // Activaciones
  activationReminder50,
  activationReminder90,

  // Entrevistas
  interviewPending,
  interviewRequired,
  interviewAccepted,
  interviewProposed,

  // General
  general,
}

class NotificationConfig {
  final String route;
  final IconData icon;
  final Color color;
  final String titleKey;
  final String bodyKey;

  NotificationConfig({
    required this.route,
    required this.icon,
    required this.color,
    required this.titleKey,
    required this.bodyKey,
  });
}

class NotificationMapper {
  static final Map<NotificationType, NotificationConfig> _configs = {
    // EVENTOS
    NotificationType.eventCancelled: NotificationConfig(
      route: '/event-details',
      icon: Icons.event_busy,
      color: Colors.red,
      titleKey: 'event_cancelled_title',
      bodyKey: 'event_cancelled_body',
    ),
    NotificationType.eventFinished: NotificationConfig(
      route: '/event-details',
      icon: Icons.event_available,
      color: Colors.green,
      titleKey: 'event_finished_title',
      bodyKey: 'event_finished_body',
    ),
    NotificationType.eventPositionCancelled: NotificationConfig(
      route: '/my-events',
      icon: Icons.person_off,
      color: Colors.orange,
      titleKey: 'position_cancelled_title',
      bodyKey: 'position_cancelled_body',
    ),
    NotificationType.eventStartToday: NotificationConfig(
      route: '/event-details',
      icon: Icons.today,
      color: Colors.blue,
      titleKey: 'event_start_today_title',
      bodyKey: 'event_start_today_body',
    ),

    // ACTIVACIONES
    NotificationType.activationReminder50: NotificationConfig(
      route: '/freelancer_dashboard',
      icon: Icons.notifications_active,
      color: Colors.purple,
      titleKey: 'activation_reminder_50_title',
      bodyKey: 'activation_reminder_50_body',
    ),
    NotificationType.activationReminder90: NotificationConfig(
      route: '/freelancer_dashboard',
      icon: Icons.notifications_active,
      color: Colors.deepPurple,
      titleKey: 'activation_reminder_90_title',
      bodyKey: 'activation_reminder_90_body',
    ),

    // ENTREVISTAS
    NotificationType.interviewPending: NotificationConfig(
      route: '/interviews',
      icon: Icons.pending_actions,
      color: Colors.amber,
      titleKey: 'interview_pending_title',
      bodyKey: 'interview_pending_body',
    ),
    NotificationType.interviewRequired: NotificationConfig(
      route: '/interviews',
      icon: Icons.interpreter_mode,
      color: Colors.orange,
      titleKey: 'interview_required_title',
      bodyKey: 'interview_required_body',
    ),
    NotificationType.interviewAccepted: NotificationConfig(
      route: '/interview-details',
      icon: Icons.check_circle,
      color: Colors.green,
      titleKey: 'interview_accepted_title',
      bodyKey: 'interview_accepted_body',
    ),
    NotificationType.interviewProposed: NotificationConfig(
      route: '/interview-details',
      icon: Icons.schedule,
      color: Colors.blue,
      titleKey: 'interview_proposed_title',
      bodyKey: 'interview_proposed_body',
    ),

    // GENERAL
    NotificationType.general: NotificationConfig(
      route: '/notifications',
      icon: Icons.notifications,
      color: Colors.grey,
      titleKey: 'general_notification_title',
      bodyKey: 'general_notification_body',
    ),
  };

  static Map<String, dynamic> getRouteConfig(
      NotificationType type, Map<String, dynamic> data) {
    final config = _configs[type] ?? _configs[NotificationType.general]!;

    // Parámetros específicos por tipo
    Map<String, dynamic> parameters = {};

    switch (type) {
      case NotificationType.eventCancelled:
      case NotificationType.eventFinished:
      case NotificationType.eventStartToday:
        parameters = {
          'eventId': data['event_id'] ?? data['eventId'],
          'fromNotification': true,
          'notificationType': type.toString(),
        };
        break;

      case NotificationType.eventPositionCancelled:
        parameters = {
          'eventId': data['event_id'],
          'positionId': data['position_id'],
          'tabIndex': 2, // Pestaña de "Cancelados"
        };
        break;

      case NotificationType.activationReminder50:
      case NotificationType.activationReminder90:
        parameters = {
          'activationId': data['activation_id'],
          'percentage': type == NotificationType.activationReminder50 ? 50 : 90,
          'showReminder': true,
        };
        break;

      case NotificationType.interviewPending:
      case NotificationType.interviewRequired:
        parameters = {
          'tabIndex': 0, // Pestaña de "Pendientes"
          'refreshList': true,
        };
        break;

      case NotificationType.interviewAccepted:
      case NotificationType.interviewProposed:
        parameters = {
          'interviewId': data['interview_id'],
          'status': type == NotificationType.interviewAccepted
              ? 'accepted'
              : 'proposed',
        };
        break;

      default:
        parameters = {
          'notificationData': data,
        };
    }

    return {
      'route': config.route,
      'parameters': parameters,
      'config': config,
    };
  }

  static String getLocalizedTitle(
      NotificationType type, Map<String, dynamic> data) {
    final config = _configs[type] ?? _configs[NotificationType.general]!;

    // Aquí puedes agregar lógica para personalizar títulos con datos
    switch (type) {
      case NotificationType.eventStartToday:
        return '${data['event_name'] ?? 'Evento'} comienza hoy';
      case NotificationType.eventCancelled:
        return '${data['event_name'] ?? 'Evento'} cancelado';
      default:
        return config.titleKey; // En producción, usarías Localizations
    }
  }

  static NotificationConfig getConfig(NotificationType type) {
    return _configs[type] ?? _configs[NotificationType.general]!;
  }
}
