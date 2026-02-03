import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth_provider.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http_parser/http_parser.dart';

class RegistrationPage2 extends StatefulWidget {
  final String accountType;

  RegistrationPage2({required this.accountType});

  @override
  _RegistrationPage2State createState() => _RegistrationPage2State();
}

class _RegistrationPage2State extends State<RegistrationPage2> {
  final _fullNameController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  File? _image;
  final picker = ImagePicker();

  Future getImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    setState(() {
      if (pickedFile != null) {
        _image = File(pickedFile.path);
      }
    });
  }

  Future<void> _submitForm() async {
    final baseUrl = dotenv.env['API_BASE_URL'];
    if (baseUrl == null) {
      print('Error: API_BASE_URL no encontrado en .env');
      return;
    }
    final url = Uri.parse('$baseUrl/users');

    try {
      var request = http.MultipartRequest('POST', url);
      request.fields['full_name'] = _fullNameController.text;
      request.fields['email'] = _emailController.text;
      request.fields['password'] = _passwordController.text;
      request.fields['user_type'] = widget.accountType;
      request.fields['phone'] = _phoneController.text;
      request.fields['nickname'] = _nicknameController.text;

      if (_image != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'photo',
            _image!.path,
            contentType: MediaType('image', 'jpeg'),
          ),
        );
      }

      var response = await request.send();
      final responseString = await response.stream.bytesToString();

      if (response.statusCode == 307) {
        final redirectUrl = response.headers['location'];
        if (redirectUrl != null) {
          final redirectRequest =
              http.MultipartRequest('POST', Uri.parse(redirectUrl));
          redirectRequest.fields.addAll(request.fields);
          redirectRequest.files.addAll(request.files);

          final redirectResponse = await redirectRequest.send();
          final redirectResponseString =
              await redirectResponse.stream.bytesToString();

          if (redirectResponse.statusCode == 200) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('¡Registro exitoso!')),
            );
            
            final responseData = jsonDecode(redirectResponseString);
            final userId = responseData['id'];

            final authProvider =
                Provider.of<AuthProvider>(context, listen: false);
            await authProvider.login(
                _emailController.text, _passwordController.text);
            
            String nextRoute = (widget.accountType == 'ADMIN' || widget.accountType == 'COMPANY') 
                ? '/complete_org_profile' 
                : '/complete_profile';

            Navigator.pushReplacementNamed(context, nextRoute,
                arguments: userId.toString());
          } else {
            try {
              final errorData = jsonDecode(redirectResponseString);
              final errorMessage = errorData['message'] ?? 'Error al registrarse';
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(errorMessage)),
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error al procesar el registro')),
              );
            }
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error: No se recibió URL de redirección')),
          );
        }
      } else if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('¡Registro exitoso!')),
        );

        try {
          final authProvider =
              Provider.of<AuthProvider>(context, listen: false);
          await authProvider.login(
              _emailController.text, _passwordController.text);

          final responseData = jsonDecode(responseString);
          final userId = responseData['id'];
          
          String nextRoute = (widget.accountType == 'ADMIN' || widget.accountType == 'COMPANY') 
              ? '/complete_org_profile' 
              : '/complete_profile';

          Navigator.pushReplacementNamed(context, nextRoute,
              arguments: userId.toString());
        } catch (e) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      } else {
        try {
          final errorData = jsonDecode(responseString);
          final errorMessage = errorData['message'] ?? 'Error al registrarse';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error en el registro')),
          );
        }
      }
    } catch (e) {
      print('Error de conexión: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de conexión con el servidor')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    String accountTypeText = widget.accountType == 'ADMIN' ? 'empresa' : 'profesional';
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
              child: SingleChildScrollView(
                child: Container(
                  constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 800),
                  padding: EdgeInsets.all(isMobile ? 20 : 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isMobile) SizedBox(height: 10),
                      SizedBox(height: isMobile ? 24 : 40),

                      Text(
                        'Completa tu información',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isMobile ? 24 : 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      RichText(
                        text: TextSpan(
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: isMobile ? 14 : 16,
                          ),
                          children: [
                            TextSpan(text: 'Finaliza tu perfil como '),
                            TextSpan(
                              text: accountTypeText,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(text: '.'),
                          ],
                        ),
                      ),
                      SizedBox(height: isMobile ? 24 : 40),

                      Container(
                        padding: EdgeInsets.all(isMobile ? 16 : 24),
                        decoration: BoxDecoration(
                          color: Color(0xFF161B22),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Color(0xFF2D3748), width: 1),
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: getImage,
                              child: Stack(
                                children: [
                                  Container(
                                    width: isMobile ? 70 : 80,
                                    height: isMobile ? 70 : 80,
                                    decoration: BoxDecoration(
                                      color: Color(0xFF1C2432),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Color(0xFF2D3748), width: 2),
                                    ),
                                    child: _image == null
                                        ? Icon(Icons.camera_alt_outlined,
                                            color: Colors.grey[600],
                                            size: isMobile ? 28 : 32)
                                        : ClipOval(
                                            child: Image.file(
                                              _image!,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      width: isMobile ? 24 : 28,
                                      height: isMobile ? 24 : 28,
                                      decoration: BoxDecoration(
                                        color: Colors.blue[600],
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Color(0xFF161B22), width: 3),
                                      ),
                                      child: Icon(Icons.edit,
                                          color: Colors.white,
                                          size: isMobile ? 12 : 14),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: isMobile ? 16 : 24),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Foto de perfil',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: isMobile ? 14 : 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Sube una foto profesional para tu perfil.',
                                    style: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: isMobile ? 12 : 14),
                                  ),
                                  SizedBox(height: isMobile ? 8 : 12),
                                  GestureDetector(
                                    onTap: getImage,
                                    child: Text(
                                      'SELECCIONAR IMAGEN',
                                      style: TextStyle(
                                          color: Colors.blue[400],
                                          fontSize: isMobile ? 11 : 13,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: isMobile ? 20 : 32),

                      if (isMobile)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTextField(
                              'Nombre completo *',
                              'Ej: María González',
                              _fullNameController,
                              isMobile,
                            ),
                            SizedBox(height: 16),
                            _buildTextField(
                              'Apodo (Opcional)',
                              'Ej: Mary',
                              _nicknameController,
                              isMobile,
                            ),
                            SizedBox(height: 16),
                            _buildTextField(
                              'Correo electrónico *',
                              'maria.gonzalez@ejemplo.com',
                              _emailController,
                              isMobile,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            SizedBox(height: 16),
                            _buildTextField(
                              'Teléfono',
                              '+52 55 1234 5678',
                              _phoneController,
                              isMobile,
                              keyboardType: TextInputType.phone,
                            ),
                            SizedBox(height: 16),
                            _buildTextField(
                              'Contraseña *',
                              '•••••••••••••',
                              _passwordController,
                              isMobile,
                              isPassword: true,
                            ),
                          ],
                        )
                      else
                        Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    'Nombre completo *',
                                    'Ej: Carlos Rodríguez',
                                    _fullNameController,
                                    isMobile,
                                  ),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: _buildTextField(
                                    'Apodo (Opcional)',
                                    'Ej: Charlie',
                                    _nicknameController,
                                    isMobile,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    'Correo electrónico *',
                                    'carlos@ejemplo.com',
                                    _emailController,
                                    isMobile,
                                    keyboardType: TextInputType.emailAddress,
                                  ),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: _buildTextField(
                                    'Teléfono',
                                    '+52 55 9876 5432',
                                    _phoneController,
                                    isMobile,
                                    keyboardType: TextInputType.phone,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 24),
                            _buildTextField(
                              'Contraseña *',
                              '•••••••••••••',
                              _passwordController,
                              isMobile,
                              isPassword: true,
                            ),
                          ],
                        ),
                      SizedBox(height: isMobile ? 24 : 40),

                      Divider(color: Color(0xFF2D3748), height: 1),
                      SizedBox(height: isMobile ? 20 : 32),

                      if (isMobile)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                _submitForm();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[600],
                                padding: EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                elevation: 0,
                              ),
                              child: Text('Crear cuenta',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500)),
                            ),
                            SizedBox(height: 12),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.arrow_back,
                                      color: Colors.grey[400], size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'Regresar',
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      else
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: Row(
                                children: [
                                  Icon(Icons.arrow_back,
                                      color: Colors.grey[400], size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'Regresar al paso anterior',
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                _submitForm();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[600],
                                padding: EdgeInsets.symmetric(
                                    horizontal: 32, vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                elevation: 0,
                              ),
                              child: Text('Finalizar registro',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500)),
                            ),
                          ],
                        ),
                      if (isMobile) SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),

            // Pie de página
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
              child: isMobile
                  ? Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: Colors.green[400],
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: 6),
                            Text('SISTEMA OPERATIVO',
                                style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold)),
                            SizedBox(width: 12),
                            Text('V4.2.0-ESTABLE',
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 9)),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                            '© 2026 SISTEMAS Corte y Queda. TODOS LOS DERECHOS RESERVADOS.',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 9),
                            textAlign: TextAlign.center),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Colors.green[400],
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text('SISTEMA OPERATIVO',
                                style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                            SizedBox(width: 24),
                            Text('V4.2.0-ESTABLE',
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 11)),
                          ],
                        ),
                        Text(
                            '© 2026 SISTEMAS Corte y Queda. TODOS LOS DERECHOS RESERVADOS.',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 11)),
                        Row(
                          children: [
                            Text('POLÍTICA DE PRIVACIDAD',
                                style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500)),
                            SizedBox(width: 24),
                            Text('TÉRMINOS DE SERVICIO',
                                style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    String hint,
    TextEditingController controller,
    bool isMobile, {
    TextInputType? keyboardType,
    bool isPassword = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: Colors.white,
                fontSize: isMobile ? 13 : 14,
                fontWeight: FontWeight.w500)),
        SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: isPassword,
          style: TextStyle(color: Colors.white, fontSize: isMobile ? 14 : 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[600]),
            fillColor: Color(0xFF1C2432),
            filled: true,
            contentPadding: EdgeInsets.symmetric(
                horizontal: isMobile ? 14 : 16,
                vertical: isMobile ? 12 : 14),
            border: OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF2D3748), width: 1),
              borderRadius: BorderRadius.circular(8),
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF2D3748), width: 1),
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }
}