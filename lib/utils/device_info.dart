import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

class DeviceInfoHelper {
  static Future<Map<String, String>> getDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    
    try {
      if (kIsWeb) {
        final webInfo = await deviceInfo.webBrowserInfo;
        return {
          'device_type': 'WEB',
          'device_name': webInfo.browserName.name,
          'device_os': webInfo.platform ?? 'Unknown',
          'browser': webInfo.userAgent ?? '',
        };
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return {
          'device_type': 'ANDROID',
          'device_name': androidInfo.model,
          'device_os': 'Android ${androidInfo.version.release}',
          'browser': '',
        };
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return {
          'device_type': 'IOS',
          'device_name': iosInfo.model,
          'device_os': 'iOS ${iosInfo.systemVersion}',
          'browser': '',
        };
      }
    } catch (e) {
      print('Error obteniendo info del dispositivo: $e');
    }
    
    return {
      'device_type': 'UNKNOWN',
      'device_name': 'Unknown',
      'device_os': 'Unknown',
      'browser': '',
    };
  }
}