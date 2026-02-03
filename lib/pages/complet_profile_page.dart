import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart'; 
import '../auth_provider.dart';

class CompleteProfilePage extends StatefulWidget {
  final String userId;

  CompleteProfilePage({required this.userId});

  @override
  _CompleteProfilePageState createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage> {
  final _bioController = TextEditingController();
  final _yearsExperienceController = TextEditingController();
  final _rfcController = TextEditingController();
  final _locationController = TextEditingController();
  double _yearsExperience = 1;
  Future<void> _openGoogleMaps() async {
    final double lat = 19.432608;
    final double lng = -99.133209;
    
    final Uri url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo abrir Google Maps'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error al abrir Google Maps: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _submitProfile() async {
    final baseUrl = dotenv.env['API_BASE_URL'];
    if (baseUrl == null) {
      print('Error: No se encontró API_BASE_URL en .env');
      return;
    }
    final url = Uri.parse('$baseUrl/freelancer/profile');

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.accessToken;

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'user_id': widget.userId,
          'bio': _bioController.text,
          'years_experience': _yearsExperience.toInt(),
          'rfc': _rfcController.text,
          'location': _locationController.text,
        }),
      );

      if (response.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('¡Perfil actualizado exitosamente!')),
        );

        Navigator.pushReplacementNamed(context, '/complete_profile2',
            arguments: widget.userId);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar el perfil')),
        );
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
    final authProvider = Provider.of<AuthProvider>(context);
    final userData = authProvider.userInfo;
    final isMobile = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      backgroundColor: Color(0xFF0D1117),
      drawer: isMobile ? _buildDrawer(userData) : null,
      body: SafeArea(
        child: Row(
          children: [
            if (!isMobile)
              Container(
                width: 200,
                color: Color(0xFF161B22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.blue[600],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(Icons.connect_without_contact,
                                color: Colors.white, size: 20),
                          ),
                          SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Corte y Queda',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              Text('SISTEMA OPERATIVO OPERACIONAL',
                                  style: TextStyle(
                                      color: Colors.grey[600], fontSize: 9)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Divider(color: Colors.grey[800], height: 1),
                    SizedBox(height: 20),
                    _buildMenuItem(Icons.dashboard_outlined, 'Panel de Control', false),
                    _buildMenuItem(Icons.person_outline, 'Perfil', true),
                    Spacer(),
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border(
                            top: BorderSide(color: Colors.grey[800]!, width: 1)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.grey[700],
                            child:
                                Icon(Icons.person, color: Colors.white, size: 18),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  userData?['full_name']?.split(' ')[0] ??
                                      'Usuario',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text('Plan Pro',
                                    style: TextStyle(
                                        color: Colors.grey[500], fontSize: 10)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            Expanded(
              child: Container(
                color: Color(0xFF0D1117),
                child: isMobile
                    ? _buildMobileLayout(userData)
                    : _buildDesktopLayout(userData),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(Map<String, dynamic>? userData) {
    return Drawer(
      backgroundColor: Color(0xFF161B22),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.blue[600],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(Icons.connect_without_contact,
                        color: Colors.white, size: 20),
                  ),
                  SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Corete y Queda',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      Text('SISTEMA AUDIOVISUAL',
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 9)),
                    ],
                  ),
                ],
              ),
            ),
            Divider(color: Colors.grey[800], height: 1),
            SizedBox(height: 20),
            _buildMenuItem(Icons.dashboard_outlined, 'Panel de Control', false),
            _buildMenuItem(Icons.person_outline, 'Perfil', true),
            Spacer(),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                border:
                    Border(top: BorderSide(color: Colors.grey[800]!, width: 1)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.grey[700],
                    child: Icon(Icons.person, color: Colors.white, size: 18),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          userData?['full_name']?.split(' ')[0] ?? 'Usuario',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text('Plan Pro',
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 10)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildMobileLayout(Map<String, dynamic>? userData) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Builder(
              builder: (BuildContext context) {
                return Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.menu, color: Colors.white, size: 24),
                      onPressed: () {
                        Scaffold.of(context).openDrawer();
                      },
                    ),
                    SizedBox(width: 8),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.blue[600],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(Icons.connect_without_contact,
                          color: Colors.white, size: 16),
                    ),
                    SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Corte Y Queda',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold)),
                        Text('SISTEMA OPERATIVO OPERACIONAL',
                            style: TextStyle(color: Colors.grey[600], fontSize: 8)),
                      ],
                    ),
                  ],
                );
              }
            ),
            SizedBox(height: 24),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xFF161B22),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Color(0xFF30363D), width: 1),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.grey[700],
                    child: Icon(Icons.person, color: Colors.white, size: 30),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userData?['full_name'] ?? 'Nombre no disponible',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.email_outlined,
                                color: Colors.grey[500], size: 12),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                userData?['email'] ?? 'correo@ejemplo.com',
                                style: TextStyle(
                                    color: Colors.grey[500], fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),

            Row(
              children: [
                _buildStepIndicator('1', true),
                Expanded(
                  child: Container(
                    height: 2,
                    color: Colors.grey[800],
                  ),
                ),
                _buildStepIndicator('2', false),
              ],
            ),
            SizedBox(height: 24),

            Text('Paso 1: Información Básica',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            SizedBox(height: 20),

            Text('BIOGRAFÍA PROFESIONAL',
                style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5)),
            SizedBox(height: 10),
            TextFormField(
              controller: _bioController,
              maxLines: 4,
              style: TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Cuéntanos sobre ti...',
                hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                fillColor: Color(0xFF0D1117),
                filled: true,
                contentPadding: EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF30363D), width: 1),
                  borderRadius: BorderRadius.circular(6),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF30363D), width: 1),
                  borderRadius: BorderRadius.circular(6),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue[600]!, width: 1),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
            SizedBox(height: 20),

            Text('AÑOS DE EXPERIENCIA',
                style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5)),
            SizedBox(height: 10),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Color(0xFF0D1117),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Color(0xFF30363D), width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_yearsExperience.round()}',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold),
                  ),
                  Icon(Icons.arrow_drop_down, color: Colors.grey[500]),
                ],
              ),
            ),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: Colors.blue[600],
                inactiveTrackColor: Colors.grey[800],
                thumbColor: Colors.blue[600],
                overlayColor: Colors.blue.withOpacity(0.2),
                trackHeight: 4,
              ),
              child: Slider(
                value: _yearsExperience,
                min: 1,
                max: 10,
                divisions: 9,
                onChanged: (double value) {
                  setState(() {
                    _yearsExperience = value;
                  });
                },
              ),
            ),
            SizedBox(height: 20),

            Text('RFC (Identificación Fiscal)',
                style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5)),
            SizedBox(height: 10),
            TextFormField(
              controller: _rfcController,
              style: TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'AAAA000000XXX',
                hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                fillColor: Color(0xFF0D1117),
                filled: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF30363D), width: 1),
                  borderRadius: BorderRadius.circular(6),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF30363D), width: 1),
                  borderRadius: BorderRadius.circular(6),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue[600]!, width: 1),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
            SizedBox(height: 20),

            Text('UBICACIÓN',
                style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5)),
            SizedBox(height: 10),
            TextFormField(
              controller: _locationController,
              style: TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Seleccionar en el mapa...',
                hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                fillColor: Color(0xFF0D1117),
                filled: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                prefixIcon:
                    Icon(Icons.location_on_outlined, color: Colors.grey[500]),
                suffixIcon: TextButton(
                  onPressed: _openGoogleMaps, 
                  child: Text('Abrir Mapa',
                      style: TextStyle(color: Colors.blue[400], fontSize: 12)),
                ),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF30363D), width: 1),
                  borderRadius: BorderRadius.circular(6),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF30363D), width: 1),
                  borderRadius: BorderRadius.circular(6),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue[600]!, width: 1),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
            SizedBox(height: 28),

            ElevatedButton(
              onPressed: () {
                _submitProfile();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                padding: EdgeInsets.symmetric(vertical: 14),
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Continuar al Paso 2',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, color: Colors.white, size: 16),
                ],
              ),
            ),
            SizedBox(height: 28),

            // Vista previa del portafolio (versión móvil)
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Color(0xFF161B22),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Color(0xFF30363D), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    height: 180,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Color(0xFF30363D), width: 1),
                    ),
                    child: Center(
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Color(0xFF161B22),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.play_circle_outline,
                            color: Colors.grey[600], size: 28),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text('Vista Previa del Perfil',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text(
                      'Tu información de perfil es visible para productoras registradas en Conekta.',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  SizedBox(height: 12),
                  InkWell(
                    onTap: () {},
                    child: Row(
                      children: [
                        Text('Ver Perfil Público',
                            style: TextStyle(
                                color: Colors.blue[400],
                                fontSize: 13,
                                fontWeight: FontWeight.w500)),
                        SizedBox(width: 4),
                        Icon(Icons.open_in_new,
                            color: Colors.blue[400], size: 13),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(Map<String, dynamic>? userData) {
    return Row(
      children: [
        
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Color(0xFF161B22),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Color(0xFF30363D), width: 1),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 35,
                          backgroundColor: Colors.grey[700],
                          child:
                              Icon(Icons.person, color: Colors.white, size: 35),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userData?['full_name'] ??
                                    'Nombre no disponible',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.alternate_email,
                                      color: Colors.grey[500], size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    userData?['email']?.split('@')[0] ??
                                        'usuario',
                                    style: TextStyle(
                                        color: Colors.grey[400], fontSize: 14),
                                  ),
                                ],
                              ),
                              SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(Icons.email_outlined,
                                      color: Colors.grey[500], size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    userData?['email'] ?? 'correo@ejemplo.com',
                                    style: TextStyle(
                                        color: Colors.grey[500], fontSize: 13),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 32),
                  Row(
                    children: [
                      _buildStepIndicator('1', true),
                      Expanded(
                        child: Container(
                          height: 2,
                          color: Colors.grey[800],
                        ),
                      ),
                      _buildStepIndicator('2', false),
                    ],
                  ),
                  SizedBox(height: 32),
                  Text('Paso 1: Información Básica',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold)),
                  SizedBox(height: 24),

                  Text('BIOGRAFÍA PROFESIONAL',
                      style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5)),
                  SizedBox(height: 12),
                  TextFormField(
                    controller: _bioController,
                    maxLines: 4,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Cuéntanos sobre ti...',
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      fillColor: Color(0xFF0D1117),
                      filled: true,
                      border: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: Color(0xFF30363D), width: 1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: Color(0xFF30363D), width: 1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: Colors.blue[600]!, width: 1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  SizedBox(height: 24),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('AÑOS DE EXPERIENCIA',
                                style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5)),
                            SizedBox(height: 12),
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Color(0xFF0D1117),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: Color(0xFF30363D), width: 1),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${_yearsExperience.round()}',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  Icon(Icons.arrow_drop_down,
                                      color: Colors.grey[500]),
                                ],
                              ),
                            ),
                            SliderTheme(
                              data: SliderThemeData(
                                activeTrackColor: Colors.blue[600],
                                inactiveTrackColor: Colors.grey[800],
                                thumbColor: Colors.blue[600],
                                overlayColor: Colors.blue.withOpacity(0.2),
                                trackHeight: 4,
                              ),
                              child: Slider(
                                value: _yearsExperience,
                                min: 1,
                                max: 10,
                                divisions: 9,
                                onChanged: (double value) {
                                  setState(() {
                                    _yearsExperience = value;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 24),
                      // RFC
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('RFC (Identificación Fiscal)',
                                style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5)),
                            SizedBox(height: 12),
                            TextFormField(
                              controller: _rfcController,
                              style: TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'AAAA000000XXX',
                                hintStyle: TextStyle(color: Colors.grey[600]),
                                fillColor: Color(0xFF0D1117),
                                filled: true,
                                border: OutlineInputBorder(
                                  borderSide: BorderSide(
                                      color: Color(0xFF30363D), width: 1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                      color: Color(0xFF30363D), width: 1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                      color: Colors.blue[600]!, width: 1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 24),
                  Text('UBICACIÓN',
                      style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5)),
                  SizedBox(height: 12),
                  TextFormField(
                    controller: _locationController,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Seleccionar en el mapa...',
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      fillColor: Color(0xFF0D1117),
                      filled: true,
                      prefixIcon: Icon(Icons.location_on_outlined,
                          color: Colors.grey[500]),
                      suffixIcon: TextButton(
                        onPressed: _openGoogleMaps, 
                        child: Text('Abrir Mapa',
                            style: TextStyle(
                                color: Colors.blue[400], fontSize: 13)),
                      ),
                      border: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: Color(0xFF30363D), width: 1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: Color(0xFF30363D), width: 1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: Colors.blue[600]!, width: 1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  SizedBox(height: 32),

                  ElevatedButton(
                    onPressed: () {
                      _submitProfile();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      padding: EdgeInsets.symmetric(vertical: 16),
                      minimumSize: Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Continuar al Paso 2',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w500)),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        Expanded(
          flex: 2,
          child: Container(
            color: Color(0xFF0D1117),
            padding: EdgeInsets.all(40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 100), 
                Container(
                  width: double.infinity,
                  height: 280,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Color(0xFF30363D), width: 1),
                  ),
                  child: Center(
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Color(0xFF161B22),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.play_circle_outline,
                          color: Colors.grey[600], size: 32),
                    ),
                  ),
                ),
                SizedBox(height: 24),
                Text('Vista Previa del Perfil',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text(
                    'Tu información de perfil es visible para productoras registradas en Conekta.',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                SizedBox(height: 16),
                InkWell(
                  onTap: () {
                  },
                  child: Row(
                    children: [
                      Text('Ver Perfil Público',
                          style: TextStyle(
                              color: Colors.blue[400],
                              fontSize: 14,
                              fontWeight: FontWeight.w500)),
                      SizedBox(width: 4),
                      Icon(Icons.open_in_new,
                          color: Colors.blue[400], size: 14),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  Widget _buildMenuItem(IconData icon, String title, bool isActive) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? Color(0xFF1F6FEB).withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: isActive
            ? Border.all(color: Color(0xFF1F6FEB).withOpacity(0.4), width: 1)
            : null,
      ),
      child: ListTile(
        dense: true,
        leading: Icon(icon,
            color: isActive ? Colors.blue[400] : Colors.grey[500], size: 20),
        title: Text(title,
            style: TextStyle(
                color: isActive ? Colors.blue[300] : Colors.grey[400],
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w500 : FontWeight.normal)),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      ),
    );
  }
  Widget _buildStepIndicator(String step, bool isActive) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isActive ? Colors.green[600] : Color(0xFF161B22),
        shape: BoxShape.circle,
        border: Border.all(
            color: isActive ? Colors.green[600]! : Color(0xFF30363D), width: 2),
      ),
      child: Center(
        child: Text(step,
            style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold)),
      ),
    );
  }
}