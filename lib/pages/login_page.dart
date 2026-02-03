import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth_provider.dart';
import 'registro_page.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  String _getFriendlyErrorMessage(String? errorMessage) {
    if (errorMessage == null) {
      return 'Error al iniciar sesión. Verifica tus credenciales.';
    }

    final errorLower = errorMessage.toLowerCase();

    if (errorLower.contains('connection') ||
        errorLower.contains('socket') ||
        errorLower.contains('refused') ||
        errorLower.contains('timeout') ||
        errorLower.contains('network') ||
        errorLower.contains('clientexception')) {
      return 'No se pudo conectar al servidor. Verifica tu conexión a internet.';
    }

    if (errorMessage.contains('401') ||
        errorLower.contains('unauthorized') ||
        errorLower.contains('incorrect') ||
        errorLower.contains('invalid credentials')) {
      return 'Email o contraseña incorrectos.';
    }

    if (errorMessage.contains('404')) {
      return 'Servicio no disponible. Intenta más tarde.';
    }

    if (errorMessage.contains('500') ||
        errorMessage.contains('502') ||
        errorMessage.contains('503') ||
        errorLower.contains('server error')) {
      return 'El servidor está experimentando problemas. Intenta más tarde.';
    }
    return 'Error al iniciar sesión. Por favor intenta nuevamente.';
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: Color(0xFF0A0E1A),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : 40,
                vertical: isMobile ? 12 : 20,
              ),
              decoration: BoxDecoration(
                color: Color(0xFF0F1419),
                border: Border(
                  bottom: BorderSide(color: Color(0xFF1C2432), width: 1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: isMobile ? 28 : 32,
                    height: isMobile ? 28 : 32,
                    decoration: BoxDecoration(
                      color: Colors.blue[600],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(Icons.connect_without_contact,
                        color: Colors.white, size: isMobile ? 16 : 20),
                  ),
                  SizedBox(width: 8),
                  Text('Corte y Queda',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: isMobile ? 16 : 20,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),

            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Container(
                    constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 450),
                    padding: EdgeInsets.all(isMobile ? 20 : 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (isMobile) SizedBox(height: 20),
                        
                        Text(
                          'Iniciar sesión en Corte y Queda',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isMobile ? 28 : 32,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Acceso unificado para Profesionales y Empresas.',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: isMobile ? 14 : 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: isMobile ? 32 : 40),

                        Text(
                          'Email o Nombre de usuario',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isMobile ? 13 : 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 8),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: isMobile ? 14 : 15),
                          decoration: InputDecoration(
                            hintText: 'Ingresa tu email',
                            hintStyle: TextStyle(color: Colors.grey[600]),
                            fillColor: Color(0xFF1C2432),
                            filled: true,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 14 : 16,
                                vertical: isMobile ? 12 : 14),
                            border: OutlineInputBorder(
                              borderSide: BorderSide(
                                  color: Color(0xFF2D3748), width: 1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                  color: Color(0xFF2D3748), width: 1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                  color: Colors.blue[600]!, width: 2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        SizedBox(height: isMobile ? 20 : 24),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Contraseña',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isMobile ? 13 : 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                // Pendiente: implementar recuperación de contraseña
                              },
                              child: Text(
                                '¿Olvidaste tu contraseña?',
                                style: TextStyle(
                                  color: Colors.blue[400],
                                  fontSize: isMobile ? 12 : 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: isMobile ? 14 : 15),
                          decoration: InputDecoration(
                            hintText: 'Ingresa tu contraseña',
                            hintStyle: TextStyle(color: Colors.grey[600]),
                            fillColor: Color(0xFF1C2432),
                            filled: true,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 14 : 16,
                                vertical: isMobile ? 12 : 14),
                            border: OutlineInputBorder(
                              borderSide: BorderSide(
                                  color: Color(0xFF2D3748), width: 1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                  color: Color(0xFF2D3748), width: 1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                  color: Colors.blue[600]!, width: 2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: Colors.grey[500],
                                size: isMobile ? 20 : 22,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                        ),
                        SizedBox(height: isMobile ? 28 : 32),

                        ElevatedButton(
                          onPressed: () async {
                            if (_emailController.text.trim().isEmpty ||
                                _passwordController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Por favor ingresa email y contraseña'),
                                  backgroundColor: Colors.orange[700],
                                ),
                              );
                              return;
                            }

                            final authProvider = Provider.of<AuthProvider>(
                                context,
                                listen: false);
                            
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => Center(
                                child: CircularProgressIndicator(
                                  color: Colors.blue[600],
                                ),
                              ),
                            );

                            bool success = await authProvider.login(
                                _emailController.text.trim(),
                                _passwordController.text.trim());

                            if (Navigator.canPop(context)) {
                              Navigator.of(context).pop();
                            }

                            if (success) {
                              String redirectRoute = authProvider.getRedirectRoute();
                              String? userId = authProvider.userId;

                              print(' LOGIN EXITOSO ');
                              print('ID de usuario: $userId');
                              print('Tipo de usuario: ${authProvider.userInfo?['user_type']}');
                              print('Ruta de redirección: $redirectRoute');
                              
                              if (authProvider.userInfo?['user_type'] == 'FREELANCER') {
                                final profile = authProvider.userInfo?['freelancer_profile'];
                                print(' FREELANCER');
                                print('Perfil existe: ${profile != null}');
                                if (profile != null) {
                                  print('Bio: ${profile['bio']}');
                                  print('Years Experience: ${profile['years_experience']}');
                                  print('RFC: ${profile['rfc']}');
                                  print('Location: ${profile['location']}');
                                  print('Job Roles: ${profile['job_roles']}');
                                  print('Tags: ${profile['tags']}');
                                  print('Job Roles tipo: ${profile['job_roles']?.runtimeType}');
                                  print('Tags tipo: ${profile['tags']?.runtimeType}');
                                }
                              }
                              if (redirectRoute == '/complete_profile') {
                                Navigator.pushReplacementNamed(
                                  context,
                                  '/complete_profile',
                                  arguments: userId,
                                );
                              } else if (redirectRoute == '/complete_profile2') {
                                Navigator.pushReplacementNamed(
                                  context, 
                                  '/complete_profile2',
                                  arguments: userId,
                                );
                              } else if (redirectRoute == '/complete_org_profile') {
                                Navigator.pushReplacementNamed(
                                  context,
                                  '/complete_org_profile',
                                  arguments: userId,
                                );
                              } else if (redirectRoute == '/company_dashboard') {
                                Navigator.pushReplacementNamed(context, '/company_dashboard');
                              } else if (redirectRoute == '/freelancer_dashboard') {
                                Navigator.pushReplacementNamed(context, '/freelancer_dashboard');
                              } else {
                                Navigator.pushReplacementNamed(context, '/home');
                              }

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('¡Bienvenido!'),
                                  backgroundColor: Colors.green[700],
                                ),
                              );
                            } else {
                              String friendlyMessage = _getFriendlyErrorMessage(authProvider.errorMessage);
                              
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(friendlyMessage),
                                  backgroundColor: Colors.red[700],
                                  duration: Duration(seconds: 4),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[600],
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            elevation: 0,
                          ),
                          child: Text('Iniciar sesión',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500)),
                        ),
                        SizedBox(height: isMobile ? 24 : 32),
                        Center(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => RegistroPage()),
                              );
                            },
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: isMobile ? 13 : 14),
                                children: [
                                  TextSpan(text: '¿Nuevo en Corte y Queda? '),
                                  TextSpan(
                                    text: 'Regístrate aquí',
                                    style: TextStyle(
                                      color: Colors.blue[400],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (isMobile) SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : 40,
                vertical: isMobile ? 16 : 24,
              ),
              decoration: BoxDecoration(
                color: Color(0xFF0F1419),
                border: Border(
                  top: BorderSide(color: Color(0xFF1C2432), width: 1),
                ),
              ),
              child: Text(
                '© 2026 Corte y Queda SYSTEMS. TODOS LOS DERECHOS RESERVADOS.',
                style: TextStyle(
                    color: Colors.grey[600], fontSize: isMobile ? 9 : 11),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}