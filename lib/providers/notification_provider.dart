import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../models/notification_model.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationService _service;
  
  NotificationProvider(this._service);
  
  List<PushNotification> get notifications => _service.notifications;
  int get unreadCount => _service.unreadCount;
  Stream<PushNotification> get notificationStream => _service.notificationStream;
  Stream<int> get countStream => _service.notificationCountStream;
  
  void markAsRead() {
    _service.markAsRead();
    notifyListeners();
  }
  
  void clearAll() {
    _service.clearAllNotifications();
    notifyListeners();
  }
  
  void refresh() {
    notifyListeners();
  }
}