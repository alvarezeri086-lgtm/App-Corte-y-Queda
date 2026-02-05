import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AuthProvider with ChangeNotifier {
  bool _isAuthenticated = false;
  String? _accessToken;
  Map<String, dynamic>? _userInfo;
  String? _errorMessage;

  bool get isAuthenticated => _isAuthenticated;
  String? get accessToken => _accessToken;
  Map<String, dynamic>? get userInfo => _userInfo;
  String? get errorMessage => _errorMessage;
  
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
      _errorMessage = 'Error: API_BASE_URL no configurada';
      print(_errorMessage);
      notifyListeners();
      return false;
    }
    final url = Uri.parse('$baseUrl/users/login');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'email=$email&password=$password',
      );

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          if (data.containsKey('access_token')) {
            _accessToken = data['access_token'];
            _isAuthenticated = true;
            _errorMessage = null;

            await getUserInfo();

            notifyListeners();
            return true;
          } else {
            _errorMessage = "Error: No se encontró 'access_token' en la respuesta.";
            print(_errorMessage);
            _isAuthenticated = false;
            notifyListeners();
            return false;
          }
        } catch (e) {
          _errorMessage = 'Error al decodificar la respuesta JSON: $e';
          print(_errorMessage);
          _isAuthenticated = false;
          notifyListeners();
          return false;
        }
      } else {
        try {
          final errorData = jsonDecode(response.body);
          _errorMessage = errorData['message'] ?? 'Error de inicio de sesión: ${response.statusCode}';
        } catch (e) {
          _errorMessage = 'Error de inicio de sesión: ${response.statusCode}';
        }
        print('Error de login: $_errorMessage');
        _isAuthenticated = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error de conexión: $e';
      print(_errorMessage);
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
      print('Error: API_BASE_URL no configurada');
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
      );

      if (userResponse.statusCode == 200) {
        final userData = jsonDecode(userResponse.body);
        
        if (userData['user_type'] == 'FREELANCER') {
          final profileUrl = Uri.parse('$baseUrl/freelancer/profile/get-roles');
          try {
            final profileResponse = await http.get(
              profileUrl,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $_accessToken',
              },
            );
            
            if (profileResponse.statusCode == 200) {
              final profileData = jsonDecode(profileResponse.body);
              
              if (userData['freelancer_profile'] != null) {
                userData['freelancer_profile']['job_roles'] = profileData['job_roles'] ?? [];
                userData['freelancer_profile']['tags'] = profileData['tags'] ?? [];
                userData['freelancer_profile']['equipment'] = profileData['equipment'] ?? [];
              } else {
                userData['freelancer_profile'] = {
                  'job_roles': profileData['job_roles'] ?? [],
                  'tags': profileData['tags'] ?? [],
                  'equipment': profileData['equipment'] ?? [],
                };
              }
            } else {
              print('Error obteniendo perfil freelancer: ${profileResponse.statusCode}');
              print('Respuesta: ${profileResponse.body}');
              
              if (userData['freelancer_profile'] != null) {
                userData['freelancer_profile']['job_roles'] = [];
                userData['freelancer_profile']['tags'] = [];
                userData['freelancer_profile']['equipment'] = [];
              }
            }
          } catch (e) {
            print('Error en petición freelancer/profile/get-roles: $e');
            
            if (userData['freelancer_profile'] != null) {
              userData['freelancer_profile']['job_roles'] = [];
              userData['freelancer_profile']['tags'] = [];
              userData['freelancer_profile']['equipment'] = [];
            }
          }
        }
        
        _userInfo = userData;
        
        notifyListeners();
        return userData;
      } else {
        print('Error al obtener información del usuario: ${userResponse.statusCode}');
        print('Respuesta: ${userResponse.body}');
        return null;
      }
    } catch (e) {
      print('Error de conexión al obtener user info: $e');
      return null;
    }
  }

  Future<void> refreshFreelancerProfile() async {
    if (_accessToken == null || _userInfo == null || _userInfo!['user_type'] != 'FREELANCER') {
      print('No se puede refrescar perfil freelancer: condiciones no cumplidas');
      return;
    }

    final baseUrl = dotenv.env['API_BASE_URL'];
    if (baseUrl == null) {
      print('Error: API_BASE_URL no configurada');
      return;
    }

    try {
      final profileUrl = Uri.parse('$baseUrl/freelancer/profile/get-roles');
      final profileResponse = await http.get(
        profileUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
      );
      
      if (profileResponse.statusCode == 200) {
        final profileData = jsonDecode(profileResponse.body);
        
        if (_userInfo?['freelancer_profile'] != null) {
          _userInfo!['freelancer_profile']['job_roles'] = profileData['job_roles'] ?? [];
          _userInfo!['freelancer_profile']['tags'] = profileData['tags'] ?? [];
          _userInfo!['freelancer_profile']['equipment'] = profileData['equipment'] ?? [];
        } else {
          _userInfo!['freelancer_profile'] = {
            'job_roles': profileData['job_roles'] ?? [],
            'tags': profileData['tags'] ?? [],
            'equipment': profileData['equipment'] ?? [],
          };
        }
        
        notifyListeners();
      } else {
        print('Error refrescando perfil: ${profileResponse.statusCode}');
        print('Respuesta: ${profileResponse.body}');
      }
    } catch (e) {
      print('Error refrescando perfil freelancer: $e');
    }
  }

  Future<void> logout() async {
    _isAuthenticated = false;
    _accessToken = null;
    _userInfo = null;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> refreshUserInfo() async {
    await getUserInfo();
  }
}