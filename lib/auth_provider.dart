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
      
      print('=== VALIDACIÓN PERFIL COMPLETO ===');
      print('Paso 1 (básicos): $step1Complete');
      print('Job Roles presente: $hasJobRoles (tipo: ${jobRoles?.runtimeType})');
      print('Tags presente: $hasTags (tipo: ${tags?.runtimeType})');
      print('Paso 2 (roles/tags): $step2Complete');
      print('Perfil completo: ${step1Complete && step2Complete}');
      
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
      
      print('=== DETERMINANDO RUTA ===');
      print('Perfil existe: ${profile != null}');
      
      if (profile == null) {
        print('Ruta: /complete_profile (no hay perfil)');
        return '/complete_profile';
      }
      
      final basicComplete = profile['bio'] != null && 
                           profile['years_experience'] != null &&
                           profile['rfc'] != null &&
                           profile['location'] != null;
      
      print('Datos básicos completos: $basicComplete');
      
      if (!basicComplete) {
        print('Ruta: /complete_profile (faltan datos básicos)');
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
      
      print('Job Roles: ${hasJobRoles ? 'Presente' : 'Ausente'} (${jobRoles?.runtimeType})');
      print('Tags: ${hasTags ? 'Presente' : 'Ausente'} (${tags?.runtimeType})');
      
      if (!hasJobRoles && !hasTags) {
        print('Ruta: /complete_profile2 (faltan roles/tags)');
        return '/complete_profile2';
      }
      
      print('Ruta: /freelancer_dashboard (perfil completo)');
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
      print('Iniciando sesión con: $email');
      print('URL: $url');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'email=$email&password=$password',
      );

      print('Estado de respuesta: ${response.statusCode}');

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
      print('=== CARGANDO DATOS DEL USUARIO ===');
      
      final userUrl = Uri.parse('$baseUrl/users/me');
      final userResponse = await http.get(
        userUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
      );

      print('Estado users/me: ${userResponse.statusCode}');

      if (userResponse.statusCode == 200) {
        final userData = jsonDecode(userResponse.body);
        
        if (userData['user_type'] == 'FREELANCER') {
          print('Usuario es FREELANCER, obteniendo perfil completo...');
          
          final profileUrl = Uri.parse('$baseUrl/freelancer/profile/get-roles');
          try {
            final profileResponse = await http.get(
              profileUrl,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $_accessToken',
              },
            );
            
            print('Estado freelancer/profile/get-roles: ${profileResponse.statusCode}');
            
            if (profileResponse.statusCode == 200) {
              final profileData = jsonDecode(profileResponse.body);
              
              print('=== PERFIL FREELANCER OBTENIDO ===');
              print('Job Roles recibidos: ${profileData['job_roles']?.length ?? 0}');
              print('Tags recibidos: ${profileData['tags']?.length ?? 0}');
              print('Equipment recibidos: ${profileData['equipment']?.length ?? 0}');
              
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
        
        print('=== INFORMACIÓN DEL USUARIO ===');
        print('ID: ${userData['id']}');
        print('Tipo de usuario: ${userData['user_type']}');
        print('Email: ${userData['email']}');
        print('Nombre completo: ${userData['full_name']}');
        
        if (userData['user_type'] == 'FREELANCER') {
          final profile = userData['freelancer_profile'];
          print('=== PERFIL FREELANCER ===');
          if (profile != null) {
            print('Biografía: ${profile['bio'] != null ? "✓" : "✗"}');
            print('Años experiencia: ${profile['years_experience'] != null ? "✓" : "✗"}');
            print('RFC: ${profile['rfc'] != null ? "✓" : "✗"}');
            print('Ubicación: ${profile['location'] != null ? "✓" : "✗"}');
            
            final jobRoles = profile['job_roles'];
            final tags = profile['tags'];
            
            print('--- Job Roles ---');
            print('Tipo: ${jobRoles?.runtimeType}');
            print('Valor: $jobRoles');
            if (jobRoles is List) {
              print('Es lista: Sí, longitud: ${jobRoles.length}');
            } else if (jobRoles is Map) {
              print('Es mapa: Sí, keys: ${jobRoles.keys}');
            } else {
              print('Es null o tipo desconocido');
            }
            
            print('--- Tags ---');
            print('Tipo: ${tags?.runtimeType}');
            print('Valor: $tags');
            if (tags is List) {
              print('Es lista: Sí, longitud: ${tags.length}');
            } else if (tags is Map) {
              print('Es mapa: Sí, keys: ${tags.keys}');
            } else {
              print('Es null o tipo desconocido');
            }
          } else {
            print('Perfil freelancer: ✗ No existe');
          }
        }
        
        if (userData['user_type'] == 'ADMIN' || userData['user_type'] == 'COMPANY') {
          final org = userData['organization'];
          if (org != null) {
            print('=== ORGANIZACIÓN ===');
            print('ID: ${org['id']}');
            print('Nombre legal: ${org['legal_name']}');
            print('Nombre comercial: ${org['trade_name']}');
            print('RFC: ${org['rfc']}');
            print('Tipo: ${org['org_type']}');
          } else {
            print('Organización: ✗ No creada');
          }
        }
        
        print('========================');
        print('Perfil básico completo: ${isBasicProfileComplete ? "✓" : "✗"}');
        print('Perfil completo: ${isFullProfileComplete ? "✓" : "✗"}');
        print('Ruta de redirección: ${getRedirectRoute()}');
        print('========================');
        
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
      print('=== ACTUALIZANDO PERFIL FREELANCER ===');
      
      final profileUrl = Uri.parse('$baseUrl/freelancer/profile/get-roles');
      final profileResponse = await http.get(
        profileUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
      );
      
      print('Estado de actualización: ${profileResponse.statusCode}');
      
      if (profileResponse.statusCode == 200) {
        final profileData = jsonDecode(profileResponse.body);
        
        print('Datos recibidos en refresh:');
        print('- Job Roles: ${profileData['job_roles']?.length ?? 0}');
        print('- Tags: ${profileData['tags']?.length ?? 0}');
        print('- Equipment: ${profileData['equipment']?.length ?? 0}');
        
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
        
        print('Perfil actualizado exitosamente');
        print('Job Roles ahora: ${_userInfo?['freelancer_profile']?['job_roles']?.length ?? 0}');
        print('Tags ahora: ${_userInfo?['freelancer_profile']?['tags']?.length ?? 0}');
        
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