import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'utils/guardar_sesion.dart';
import 'utils/error_handler.dart';
import 'utils/device_info.dart';



class AuthProvider with ChangeNotifier {
  bool _isAuthenticated = false;
  String? _accessToken;
  Map<String, dynamic>? _userInfo;
  String? _errorMessage;
  bool _isLoading = true; 

  bool get isAuthenticated => _isAuthenticated;
  String? get accessToken => _accessToken;
  Map<String, dynamic>? get userInfo => _userInfo;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading; 
  
  AuthProvider() {
    _loadSavedSession();
  }

  Future<void> _loadSavedSession() async {
    _isLoading = true;
    notifyListeners();

    try {
      final hasSession = await StorageHelper.hasSession();
      
      if (hasSession) {
        final savedToken = await StorageHelper.getAccessToken();
        final savedUserInfo = await StorageHelper.getUserInfo();
        final savedAuthStatus = await StorageHelper.getAuthStatus();

        if (savedToken != null && savedUserInfo != null && savedAuthStatus) {
          _accessToken = savedToken;
          _userInfo = savedUserInfo;
          _isAuthenticated = true;

          getUserInfo().catchError((error) {
            print('No se pudo refrescar user info: $error');
          });
        }
      }
    } catch (e) {
      print('Error cargando sesión guardada: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  bool get isBasicProfileComplete {
    if (_userInfo == null) return false;
    
    if (_userInfo!['user_type'] == 'FREELANCER') {
      final profile = _userInfo!['freelancer_profile'];
      if (profile == null) return false;
      
      return profile['bio'] != null && 
             profile['years_experience'] != null &&
             profile['rfc'] != null &&
             profile['location'] != null;
    }
    
    if (_userInfo!['user_type'] == 'ADMIN' || _userInfo!['user_type'] == 'COMPANY') {
      final org = _userInfo!['organization'];
      return org != null && org['legal_name'] != null && org['trade_name'] != null;
    }
    
    return false;
  }

  bool get isFullProfileComplete {
    if (_userInfo == null) return false;
    
    if (_userInfo!['user_type'] == 'FREELANCER') {
      final profile = _userInfo!['freelancer_profile'];
      if (profile == null) return false;
      
      bool step1Complete = profile['bio'] != null && 
                          profile['years_experience'] != null &&
                          profile['rfc'] != null &&
                          profile['location'] != null;
      
      if (!step1Complete) return false;
      
      final jobRoles = profile['job_roles'];
      final tags = profile['tags'];
      
      bool hasJobRoles = false;
      bool hasTags = false;
      
      if (jobRoles != null) {
        if (jobRoles is List) {
          hasJobRoles = jobRoles.isNotEmpty;
        } else if (jobRoles is Map) {
          hasJobRoles = jobRoles.isNotEmpty;
        }
      }
      
      if (tags != null) {
        if (tags is List) {
          hasTags = tags.isNotEmpty;
        } else if (tags is Map) {
          hasTags = tags.isNotEmpty;
        }
      }
      
      bool step2Complete = hasJobRoles || hasTags;
      
      return step1Complete && step2Complete;
    }
    
    if (_userInfo!['user_type'] == 'ADMIN' || _userInfo!['user_type'] == 'COMPANY') {
      final org = _userInfo!['organization'];
      return org != null && org['legal_name'] != null && org['trade_name'] != null;
    }
    
    return false;
  }

  String getRedirectRoute() {
    if (!_isAuthenticated || _userInfo == null) return '/login';
    
    final userType = _userInfo!['user_type'];
    
    if (userType == 'FREELANCER') {
      final profile = _userInfo!['freelancer_profile'];
      
      if (profile == null) {
        return '/complete_profile';
      }
      
      final basicComplete = profile['bio'] != null && 
                           profile['years_experience'] != null &&
                           profile['rfc'] != null &&
                           profile['location'] != null;
      
      if (!basicComplete) {
        return '/complete_profile';
      }
      
      final jobRoles = profile['job_roles'];
      final tags = profile['tags'];
      
      bool hasJobRoles = false;
      bool hasTags = false;
      
      if (jobRoles != null) {
        if (jobRoles is List) {
          hasJobRoles = jobRoles.isNotEmpty;
        } else if (jobRoles is Map) {
          hasJobRoles = jobRoles.isNotEmpty;
        }
      }
      
      if (tags != null) {
        if (tags is List) {
          hasTags = tags.isNotEmpty;
        } else if (tags is Map) {
          hasTags = tags.isNotEmpty;
        }
      }
      
      if (!hasJobRoles && !hasTags) {
        return '/complete_profile2';
      }
      
      return '/freelancer_dashboard';
    }
    
    if (userType == 'ADMIN' || userType == 'COMPANY') {
      final org = _userInfo!['organization'];
      
      if (org == null || org['legal_name'] == null || org['trade_name'] == null) {
        return '/complete_org_profile';
      }
      
      return '/company_dashboard';
    }
    
    return '/login';
  }

  String? get userId {
    return _userInfo?['id']?.toString();
  }

  Future<bool> login(String email, String password) async {
    final baseUrl = dotenv.env['API_BASE_URL'];
    if (baseUrl == null) {
      _errorMessage = 'Configuración no disponible';
      notifyListeners();
      return false;
    }
    
    final url = Uri.parse('$baseUrl/users/login');

    try {
      String fcmToken = '';
      try {
        fcmToken = await FirebaseMessaging.instance.getToken() ?? '';
      } catch (e) {
        print('Error obteniendo FCM token: $e');
      }
      
      final deviceInfo = await DeviceInfoHelper.getDeviceInfo();

      final bodyMap = {
        'email': email,
        'password': password,
        'fcm_token': fcmToken,
        'device_type': deviceInfo['device_type'] ?? '',
        'device_name': deviceInfo['device_name'] ?? '',
        'device_os': deviceInfo['device_os'] ?? '',
        'browser': deviceInfo['browser'] ?? '',
      };

      final body = bodyMap.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: body,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('La conexión ha excedido el tiempo de espera');
        },
      );

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          if (data.containsKey('access_token')) {
            _accessToken = data['access_token'];
            _isAuthenticated = true;
            _errorMessage = null;

            await StorageHelper.saveAccessToken(_accessToken!);
            await StorageHelper.saveAuthStatus(true);

            await getUserInfo();

            notifyListeners();
            return true;
          } else {
            _errorMessage = "Respuesta inválida del servidor";
            _isAuthenticated = false;
            notifyListeners();
            return false;
          }
        } catch (e) {
          _errorMessage = 'Error procesando respuesta del servidor';
          _isAuthenticated = false;
          notifyListeners();
          return false;
        }
      } else if (response.statusCode == 401) {
        _errorMessage = 'Email o contraseña incorrectos';
        _isAuthenticated = false;
        notifyListeners();
        return false;
      } else {
        _errorMessage = ApiErrorHandler.handleHttpError(null, statusCode: response.statusCode);
        _isAuthenticated = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = ApiErrorHandler.handleHttpError(e);
      print('Error de conexión en login: $e');
      _isAuthenticated = false;
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>?> getUserInfo() async {
    if (_accessToken == null) {
      return null;
    }

    final baseUrl = dotenv.env['API_BASE_URL'];
    if (baseUrl == null) {
      return null;
    }

    try {
      final userUrl = Uri.parse('$baseUrl/users/me');
      final userResponse = await http.get(
        userUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Timeout obteniendo información de usuario');
        },
      );

      if (userResponse.statusCode == 200) {
        final userData = jsonDecode(userResponse.body);
        
        if (userData['user_type'] == 'FREELANCER') {
          if (userData['freelancer_profile'] == null) {
            userData['freelancer_profile'] = {};
          }

          try {
            final profileUrl = Uri.parse('$baseUrl/freelancer/profile/get-roles');
            final profileResponse = await http.get(
              profileUrl,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $_accessToken',
              },
            ).timeout(
              const Duration(seconds: 30),
            );
            
            if (profileResponse.statusCode == 200) {
              final profileData = jsonDecode(profileResponse.body);
              
              userData['freelancer_profile']['job_roles'] = profileData['job_roles'] ?? [];
              userData['freelancer_profile']['tags'] = profileData['tags'] ?? [];
              userData['freelancer_profile']['equipment'] = profileData['equipment'] ?? [];
            } else if (profileResponse.statusCode == 404) {
              userData['freelancer_profile']['job_roles'] = [];
              userData['freelancer_profile']['tags'] = [];
              userData['freelancer_profile']['equipment'] = [];
            } else {
              userData['freelancer_profile']['job_roles'] = [];
              userData['freelancer_profile']['tags'] = [];
              userData['freelancer_profile']['equipment'] = [];
            }
          } catch (e) {
            print('Error en petición de perfil freelancer: $e');
            userData['freelancer_profile']['job_roles'] = [];
            userData['freelancer_profile']['tags'] = [];
            userData['freelancer_profile']['equipment'] = [];
          }
        }
        
        _userInfo = userData;
        
        await StorageHelper.saveUserInfo(userData);
        
        notifyListeners();
        return userData;
      } else if (userResponse.statusCode == 401) {
        await logout();
        return null;
      } else {
        return null;
      }
    } catch (e) {
      print('Error de conexión al obtener user info: $e');
      return null;
    }
  }

  Future<void> refreshFreelancerProfile() async {
    if (_accessToken == null || _userInfo == null || _userInfo!['user_type'] != 'FREELANCER') {
      return;
    }

    final baseUrl = dotenv.env['API_BASE_URL'];
    if (baseUrl == null) {
      return;
    }

    try {
      if (_userInfo!['freelancer_profile'] == null) {
        _userInfo!['freelancer_profile'] = {};
      }

      final profileUrl = Uri.parse('$baseUrl/freelancer/profile/get-roles');
      final profileResponse = await http.get(
        profileUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
      ).timeout(
        const Duration(seconds: 30),
      );
      
      if (profileResponse.statusCode == 200) {
        final profileData = jsonDecode(profileResponse.body);
        
        _userInfo!['freelancer_profile']['job_roles'] = profileData['job_roles'] ?? [];
        _userInfo!['freelancer_profile']['tags'] = profileData['tags'] ?? [];
        _userInfo!['freelancer_profile']['equipment'] = profileData['equipment'] ?? [];

        await StorageHelper.saveUserInfo(_userInfo!);
      } else {
        // Error silencioso al refrescar perfil
      }
      
      notifyListeners();
    } catch (e) {
      print('Error refrescando perfil freelancer: $e');
    }
  }

  Future<void> logout() async {
    _isAuthenticated = false;
    _accessToken = null;
    _userInfo = null;
    _errorMessage = null;
    
    await StorageHelper.clearAll();
    
    notifyListeners();
  }

  Future<void> refreshUserInfo() async {
    await getUserInfo();
  }
}