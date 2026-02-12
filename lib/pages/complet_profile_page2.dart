import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import '../auth_provider.dart';
import 'dart:async';

class CompleteProfilePage2 extends StatefulWidget {
  final String userId;

  CompleteProfilePage2({required this.userId});

  @override
  _CompleteProfilePage2State createState() => _CompleteProfilePage2State();
}

class _CompleteProfilePage2State extends State<CompleteProfilePage2> {
  List<Map<String, dynamic>> _rolesDisponibles = [];
  List<Map<String, dynamic>> _habilidadesDisponibles = [];
  List<Map<String, dynamic>> _equiposDisponibles = [];

  List<Map<String, dynamic>> _rolesSeleccionados = [];
  List<String> _habilidadesSeleccionadasIds = [];
  List<Map<String, dynamic>> _equiposSeleccionados = [];

  final _nombreRolController = TextEditingController();
  final _aniosRolController = TextEditingController();
  final _nivelRolController = TextEditingController();
  final _nombreHabilidadController = TextEditingController();
  final _nombreEquipoController = TextEditingController();
  final _cantidadEquipoController = TextEditingController();
  final _notasEquipoController = TextEditingController();
  final _experienciaEquipoController = TextEditingController();

  bool _cargando = true;
  bool _poseoEquipo = false;
  bool _tengoExperiencia = false;
  String? _rolSeleccionadoId;
  String? _equipoSeleccionadoId;

  List<Map<String, dynamic>> _rolesUsuario = [];
  List<Map<String, dynamic>> _habilidadesUsuario = [];
  List<Map<String, dynamic>> _equiposUsuario = [];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _nombreRolController.dispose();
    _aniosRolController.dispose();
    _nivelRolController.dispose();
    _nombreHabilidadController.dispose();
    _nombreEquipoController.dispose();
    _cantidadEquipoController.dispose();
    _notasEquipoController.dispose();
    _experienciaEquipoController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    final urlBase = dotenv.env['API_BASE_URL'];
    if (urlBase == null) {
      print('ERROR: No se configuró API_BASE_URL');
      setState(() {
        _cargando = false;
      });
      return;
    }

    final proveedorAuth = Provider.of<AuthProvider>(context, listen: false);
    final token = proveedorAuth.accessToken;

    if (token == null) {
      print('ERROR: No hay token de autenticación');
      setState(() {
        _cargando = false;
      });
      return;
    }

    try {
      final resultados = await Future.wait([
        http.get(
          Uri.parse('$urlBase/job-roles/'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
        http.get(
          Uri.parse('$urlBase/tags/'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
        http.get(
          Uri.parse('$urlBase/equipment/'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      ]).timeout(Duration(seconds: 30));

      final respuestaRoles = resultados[0];
      final respuestaHabilidades = resultados[1];
      final respuestaEquipos = resultados[2];

      if (!mounted) return;

      setState(() {
        if (respuestaRoles.statusCode == 200) {
          final datosRoles = jsonDecode(respuestaRoles.body);
          if (datosRoles is List) {
            _rolesDisponibles =
                datosRoles.map((item) => item as Map<String, dynamic>).toList();
          }
        }

        if (respuestaHabilidades.statusCode == 200) {
          final datosHabilidades = jsonDecode(respuestaHabilidades.body);
          if (datosHabilidades is List) {
            _habilidadesDisponibles = datosHabilidades
                .map((item) => item as Map<String, dynamic>)
                .toList();
          }
        }

        if (respuestaEquipos.statusCode == 200) {
          final datosEquipos = jsonDecode(respuestaEquipos.body);
          if (datosEquipos is List) {
            _equiposDisponibles = datosEquipos
                .map((item) => item as Map<String, dynamic>)
                .toList();
          }
        }

        _cargando = false;
      });

    } catch (e) {
      print('ERROR al cargar datos: $e');
      if (!mounted) return;
      setState(() {
        _cargando = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos del servidor')),
        );
      }
    }
  }

  Future<void> _crearRol(String nombre) async {
    final urlBase = dotenv.env['API_BASE_URL'];
    if (urlBase == null) return;

    final proveedorAuth = Provider.of<AuthProvider>(context, listen: false);
    final token = proveedorAuth.accessToken;
    if (token == null) return;

    try {
      final respuesta = await http.post(
        Uri.parse('$urlBase/job-roles/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
        body: jsonEncode({'name': nombre}),
      );

      if (respuesta.statusCode == 200) {
        final nuevoRol = jsonDecode(respuesta.body);
        setState(() {
          _rolesDisponibles.add(nuevoRol);
          _rolSeleccionadoId = nuevoRol['id'];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rol creado exitosamente')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al crear rol')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de conexión')),
      );
    }
  }

  Future<void> _crearHabilidad(String nombre) async {
    final urlBase = dotenv.env['API_BASE_URL'];
    if (urlBase == null) return;

    final proveedorAuth = Provider.of<AuthProvider>(context, listen: false);
    final token = proveedorAuth.accessToken;
    if (token == null) return;

    try {
      final respuesta = await http.post(
        Uri.parse('$urlBase/tags/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
        body: jsonEncode({'name': nombre}),
      );

      if (respuesta.statusCode == 200) {
        final nuevaHabilidad = jsonDecode(respuesta.body);
        setState(() {
          _habilidadesDisponibles.add(nuevaHabilidad);
          _agregarHabilidad(nuevaHabilidad['id'], nuevaHabilidad['name']);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Habilidad creada exitosamente')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al crear habilidad')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de conexión')),
      );
    }
  }

  Future<void> _crearEquipo(String nombre) async {
    final urlBase = dotenv.env['API_BASE_URL'];
    if (urlBase == null) return;

    final proveedorAuth = Provider.of<AuthProvider>(context, listen: false);
    final token = proveedorAuth.accessToken;
    if (token == null) return;

    try {
      final respuesta = await http.post(
        Uri.parse('$urlBase/equipment/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
        body: jsonEncode({'name': nombre}),
      );

      if (respuesta.statusCode == 200) {
        final nuevoEquipo = jsonDecode(respuesta.body);
        setState(() {
          _equiposDisponibles.add(nuevoEquipo);
          _equipoSeleccionadoId = nuevoEquipo['id'];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Equipo creado exitosamente')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al crear equipo')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de conexión')),
      );
    }
  }

  void _agregarHabilidad(String idHabilidad, String nombreHabilidad) {
    if (_habilidadesSeleccionadasIds.contains(idHabilidad)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Esta habilidad ya fue agregada')),
      );
      return;
    }

    setState(() {
      _habilidadesSeleccionadasIds.add(idHabilidad);
      _habilidadesUsuario.add({'id': idHabilidad, 'name': nombreHabilidad});
    });
  }

  void _agregarHabilidadManual() async {
    if (_nombreHabilidadController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Por favor ingresa una habilidad')),
      );
      return;
    }

    final nombreHabilidad = _nombreHabilidadController.text.trim();
    _nombreHabilidadController.clear();

    await _crearHabilidad(nombreHabilidad);
  }

  void _quitarHabilidad(int indice) {
    setState(() {
      _habilidadesSeleccionadasIds.removeAt(indice);
      _habilidadesUsuario.removeAt(indice);
    });
  }

  void _agregarRol() async {
    if (_rolesDisponibles.isEmpty ||
        (_nombreRolController.text.trim().isNotEmpty &&
            _rolSeleccionadoId == null)) {
      if (_nombreRolController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Por favor ingresa el nombre del rol')),
        );
        return;
      }

      final anios = int.tryParse(_aniosRolController.text);
      final nivel = int.tryParse(_nivelRolController.text);

      if (anios == null || nivel == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Por favor ingresa años y nivel válidos')),
        );
        return;
      }

      if (nivel < 1 || nivel > 5) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('El nivel debe estar entre 1 y 5')),
        );
        return;
      }

      final nombreRol = _nombreRolController.text.trim();
      await _crearRol(nombreRol);

      if (_rolSeleccionadoId != null) {
        setState(() {
          _rolesSeleccionados.add({
            'job_role_id': _rolSeleccionadoId!,
            'years': anios,
            'level': nivel,
          });

          _rolesUsuario.add({
            'name': nombreRol,
            'years': anios,
            'level': nivel,
          });

          _nombreRolController.clear();
          _aniosRolController.clear();
          _nivelRolController.clear();
          _rolSeleccionadoId = null;
        });
      }

      return;
    }

    if (_rolSeleccionadoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Por favor selecciona un rol')),
      );
      return;
    }

    final anios = int.tryParse(_aniosRolController.text);
    final nivel = int.tryParse(_nivelRolController.text);

    if (anios == null || nivel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Por favor ingresa años y nivel válidos')),
      );
      return;
    }

    if (nivel < 1 || nivel > 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('El nivel debe estar entre 1 y 5')),
      );
      return;
    }

    final rolSeleccionado = _rolesDisponibles.firstWhere(
      (rol) => rol['id'] == _rolSeleccionadoId,
    );

    setState(() {
      _rolesSeleccionados.add({
        'job_role_id': _rolSeleccionadoId!,
        'years': anios,
        'level': nivel,
      });

      _rolesUsuario.add({
        'name': rolSeleccionado['name'] ?? 'Rol',
        'years': anios,
        'level': nivel,
      });

      _rolSeleccionadoId = null;
      _aniosRolController.clear();
      _nivelRolController.clear();
    });
  }

  void _quitarRol(int indice) {
    setState(() {
      _rolesSeleccionados.removeAt(indice);
      _rolesUsuario.removeAt(indice);
    });
  }

  void _agregarEquipo() async {
    final cantidad = int.tryParse(_cantidadEquipoController.text) ?? 0;
    final aniosExperiencia =
        int.tryParse(_experienciaEquipoController.text) ?? 0;

    if (_poseoEquipo && _tengoExperiencia) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Solo puedes seleccionar "Lo tengo" O "Tengo experiencia", no ambos')),
      );
      return;
    }

    if (_equiposDisponibles.isEmpty ||
        (_nombreEquipoController.text.trim().isNotEmpty &&
            _equipoSeleccionadoId == null)) {
      if (_nombreEquipoController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Por favor ingresa el nombre del equipo')),
        );
        return;
      }

      final nombreEquipo = _nombreEquipoController.text.trim();

      await _crearEquipo(nombreEquipo);

      if (_equipoSeleccionadoId != null) {
        setState(() {
          _equiposSeleccionados.add({
            'equipment_item_id': _equipoSeleccionadoId!,
            'quantity': cantidad,
            'notes': _notasEquipoController.text.trim(),
            'has_requirement': _poseoEquipo,
            'is_experienced': _tengoExperiencia,
            'experience_years': aniosExperiencia,
          });

          _equiposUsuario.add({
            'name': nombreEquipo,
            'quantity': cantidad,
            'notes': _notasEquipoController.text.trim(),
            'has_requirement': _poseoEquipo,
            'is_experienced': _tengoExperiencia,
            'experience_years': aniosExperiencia,
          });

          _nombreEquipoController.clear();
          _cantidadEquipoController.clear();
          _notasEquipoController.clear();
          _experienciaEquipoController.clear();
          _poseoEquipo = false;
          _tengoExperiencia = false;
          _equipoSeleccionadoId = null;
        });
      }

      return;
    }

    if (_equipoSeleccionadoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Por favor selecciona un equipo')),
      );
      return;
    }

    final equipoSeleccionado = _equiposDisponibles.firstWhere(
      (equipo) => equipo['id'] == _equipoSeleccionadoId,
    );

    setState(() {
      _equiposSeleccionados.add({
        'equipment_item_id': _equipoSeleccionadoId!,
        'quantity': cantidad,
        'notes': _notasEquipoController.text.trim(),
        'has_requirement': _poseoEquipo,
        'is_experienced': _tengoExperiencia,
        'experience_years': aniosExperiencia,
      });

      _equiposUsuario.add({
        'name': equipoSeleccionado['name'] ?? 'Equipo',
        'quantity': cantidad,
        'notes': _notasEquipoController.text.trim(),
        'has_requirement': _poseoEquipo,
        'is_experienced': _tengoExperiencia,
        'experience_years': aniosExperiencia,
      });

      _equipoSeleccionadoId = null;
      _cantidadEquipoController.clear();
      _notasEquipoController.clear();
      _experienciaEquipoController.clear();
      _poseoEquipo = false;
      _tengoExperiencia = false;
    });
  }

  void _quitarEquipo(int indice) {
    setState(() {
      _equiposSeleccionados.removeAt(indice);
      _equiposUsuario.removeAt(indice);
    });
  }

  Future<void> _guardarPerfil() async {
    final urlBase = dotenv.env['API_BASE_URL'];
    if (urlBase == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: No se configuró la URL base')),
      );
      return;
    }

    final proveedorAuth = Provider.of<AuthProvider>(context, listen: false);
    final token = proveedorAuth.accessToken;

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: No estás autenticado')),
      );
      return;
    }

    if (_habilidadesSeleccionadasIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Por favor agrega al menos una habilidad')),
      );
      return;
    }

    final url = Uri.parse('$urlBase/freelancer/profile/upsert-roles');

    try {
      final datos = {
        'job_roles': _rolesSeleccionados,
        'tag_ids': _habilidadesSeleccionadasIds,
        'equipment': _equiposSeleccionados,
      };

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(color: Colors.blue[600]),
        ),
      );

      final respuesta = await http
          .put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
        body: jsonEncode(datos),
      )
          .timeout(
        Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('El servidor tardó demasiado en responder');
        },
      );

      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      if (respuesta.statusCode == 200) {
        try {
          final datosRespuesta = jsonDecode(respuesta.body);
        } catch (e) {
          print('Error al parsear respuesta: $e');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Perfil guardado exitosamente!'),
            backgroundColor: Colors.green[600],
            duration: Duration(seconds: 3),
          ),
        );

        await Future.delayed(Duration(milliseconds: 1500));

        await proveedorAuth.refreshFreelancerProfile();

        await Future.delayed(Duration(milliseconds: 1000));

        final userInfo = proveedorAuth.userInfo;

        if (proveedorAuth.isFullProfileComplete) {
          Navigator.pushReplacementNamed(context, '/freelancer_dashboard');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Perfil guardado, pero aún faltan datos. Actualizando...'),
              backgroundColor: Colors.orange[600],
              duration: Duration(seconds: 4),
            ),
          );

          await Future.delayed(Duration(seconds: 2));
          await proveedorAuth.refreshFreelancerProfile();

          if (proveedorAuth.isFullProfileComplete) {
            Navigator.pushReplacementNamed(context, '/freelancer_dashboard');
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Error: No se pudieron cargar los datos. Intenta cerrar sesión y volver a iniciar.'),
                backgroundColor: Colors.red[600],
                duration: Duration(seconds: 5),
              ),
            );
          }
        }
      } else {
        String mensajeError =
            'Error al actualizar el perfil: ${respuesta.statusCode}';
        try {
          final datosError = jsonDecode(respuesta.body);
          if (datosError['detail'] != null) {
            mensajeError = datosError['detail'].toString();
          }
        } catch (e) {
          print('Error al parsear error: $e');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeError)),
        );
      }
    } catch (e) {
      print('Error: $e');

      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de conexión: Verifica tu internet')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final proveedorAuth = Provider.of<AuthProvider>(context);
    final datosUsuario = proveedorAuth.userInfo;
    final esMovil = MediaQuery.of(context).size.width < 900;

    if (_cargando) {
      return Scaffold(
        backgroundColor: Color(0xFF0D1117),
        body: Center(
          child: CircularProgressIndicator(color: Colors.blue[600]),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Color(0xFF0D1117),
      drawer: esMovil ? _construirMenuLateral(datosUsuario) : null,
      body: SafeArea(
        child: Row(
          children: [
            if (!esMovil) _construirBarraLateral(datosUsuario),
            Expanded(
              child: esMovil
                  ? _construirLayoutMovil()
                  : _construirLayoutEscritorio(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirMenuLateral(Map<String, dynamic>? datosUsuario) {
    return Drawer(
      backgroundColor: Color(0xFF161B22),
      child: _construirContenidoBarraLateral(datosUsuario),
    );
  }

  Widget _construirBarraLateral(Map<String, dynamic>? datosUsuario) {
    return Container(
      width: 200,
      color: Color(0xFF161B22),
      child: _construirContenidoBarraLateral(datosUsuario),
    );
  }

  Widget _construirContenidoBarraLateral(Map<String, dynamic>? datosUsuario) {
    return SafeArea(
      child: Column(
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
                    Text('Conekta',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    Text('SISTEMA AUDIOVISUAL',
                        style: TextStyle(color: Colors.grey[600], fontSize: 9)),
                  ],
                ),
              ],
            ),
          ),
          Divider(color: Colors.grey[800], height: 1),
          SizedBox(height: 20),
          _construirElementoMenu(
              Icons.dashboard_outlined, 'Panel de Control', false),
          _construirElementoMenu(Icons.person_outline, 'Perfil', true),
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
                        datosUsuario?['full_name']?.split(' ')[0] ?? 'Usuario',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text('Plan Pro',
                          style:
                              TextStyle(color: Colors.grey[500], fontSize: 10)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirLayoutMovil() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Builder(builder: (context) {
              return Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.menu, color: Colors.white, size: 24),
                    onPressed: () => Scaffold.of(context).openDrawer(),
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
                  Text('Corte y Queda',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold)),
                ],
              );
            }),
            SizedBox(height: 24),
            _construirContenidoFormulario(esMovil: true),
          ],
        ),
      ),
    );
  }

  Widget _construirLayoutEscritorio() {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: _construirContenidoFormulario(esMovil: false),
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: _construirVistaPreviaPortafolio(),
        ),
      ],
    );
  }

  Widget _construirContenidoFormulario({required bool esMovil}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _construirIndicadorPaso('1', false),
            Expanded(child: Container(height: 2, color: Colors.grey[800])),
            _construirIndicadorPaso('2', true),
          ],
        ),
        SizedBox(height: esMovil ? 24 : 32),
        Text('Paso 2: Detalles Profesionales',
            style: TextStyle(
                color: Colors.white,
                fontSize: esMovil ? 20 : 24,
                fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Text(
            'Agrega tus roles, habilidades y equipo para coincidir con proyectos.',
            style: TextStyle(
                color: Colors.grey[400], fontSize: esMovil ? 12 : 14)),
        SizedBox(height: esMovil ? 24 : 32),
        _construirSeccionRoles(esMovil),
        SizedBox(height: 24),
        _construirSeccionHabilidades(esMovil),
        SizedBox(height: 24),
        _construirSeccionEquipos(esMovil),
        SizedBox(height: 32),
        ElevatedButton(
          onPressed: _guardarPerfil,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[600],
            padding: EdgeInsets.symmetric(vertical: 14),
            minimumSize: Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            elevation: 0,
          ),
          child: Text('Completar Perfil y Guardar',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500)),
        ),
        if (esMovil) ...[
          SizedBox(height: 32),
          _construirVistaPreviaPortafolio(),
        ],
      ],
    );
  }

  Widget _construirSeccionRoles(bool esMovil) {
    return Container(
      padding: EdgeInsets.all(esMovil ? 16 : 24),
      decoration: BoxDecoration(
        color: Color(0xFF161B22),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0xFF30363D), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.work_outline, color: Colors.grey[400], size: 20),
              SizedBox(width: 8),
              Text('Roles Profesionales',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: esMovil ? 14 : 16,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          SizedBox(height: 16),
          if (_rolesDisponibles.isNotEmpty) ...[
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Color(0xFF0D1117),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Color(0xFF30363D), width: 1),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  hint: Text('Seleccionar rol existente...',
                      style: TextStyle(color: Colors.grey[600])),
                  value: _rolSeleccionadoId,
                  dropdownColor: Color(0xFF161B22),
                  style: TextStyle(color: Colors.white),
                  icon: Icon(Icons.arrow_drop_down, color: Colors.grey[500]),
                  items: _rolesDisponibles.map((rol) {
                    return DropdownMenuItem<String>(
                      value: rol['id'],
                      child: Text(rol['name'] ?? 'Sin nombre'),
                    );
                  }).toList(),
                  onChanged: (valor) {
                    setState(() {
                      _rolSeleccionadoId = valor;
                      _nombreRolController.clear();
                    });
                  },
                ),
              ),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _nombreRolController,
                    style: TextStyle(
                        color: Colors.white, fontSize: esMovil ? 13 : 14),
                    decoration:
                        _decoracionCampo('O crear nuevo rol...', esMovil),
                    onChanged: (valor) {
                      if (valor.isNotEmpty) {
                        setState(() {
                          _rolSeleccionadoId = null;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ] else ...[
            TextFormField(
              controller: _nombreRolController,
              style:
                  TextStyle(color: Colors.white, fontSize: esMovil ? 13 : 14),
              decoration: _decoracionCampo(
                  'Nombre del rol (ej: Director de fotografía)', esMovil),
            ),
          ],
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _aniosRolController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(
                      color: Colors.white, fontSize: esMovil ? 13 : 14),
                  decoration: _decoracionCampo('Años', esMovil),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _nivelRolController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(
                      color: Colors.white, fontSize: esMovil ? 13 : 14),
                  decoration: _decoracionCampo('Nivel (1-5)', esMovil),
                ),
              ),
              SizedBox(width: 8),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.green[600],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: IconButton(
                  icon: Icon(Icons.add, color: Colors.white, size: 20),
                  onPressed: _agregarRol,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          if (_rolesUsuario.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No has agregado roles aún',
                    style: TextStyle(
                        color: Colors.grey[600], fontSize: esMovil ? 11 : 12)),
              ),
            )
          else
            ..._rolesUsuario.asMap().entries.map((entrada) {
              int indice = entrada.key;
              var rol = entrada.value;
              return Container(
                margin: EdgeInsets.only(bottom: 8),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFF2D3748),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Color(0xFF4A5568), width: 1),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(rol['name'],
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text('${rol['years']} años • Nivel ${rol['level']}',
                              style: TextStyle(
                                  color: Colors.grey[400], fontSize: 11)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon:
                          Icon(Icons.close, color: Colors.grey[400], size: 18),
                      onPressed: () => _quitarRol(indice),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _construirSeccionHabilidades(bool esMovil) {
    return Container(
      padding: EdgeInsets.all(esMovil ? 16 : 24),
      decoration: BoxDecoration(
        color: Color(0xFF161B22),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0xFF30363D), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_offer_outlined,
                  color: Colors.grey[400], size: 20),
              SizedBox(width: 8),
              Text('Habilidades',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: esMovil ? 14 : 16,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _nombreHabilidadController,
                  style: TextStyle(
                      color: Colors.white, fontSize: esMovil ? 13 : 14),
                  decoration:
                      _decoracionCampo('Agregar nueva habilidad...', esMovil),
                  onFieldSubmitted: (_) => _agregarHabilidadManual(),
                ),
              ),
              SizedBox(width: 8),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.green[600],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: IconButton(
                  icon: Icon(Icons.add, color: Colors.white, size: 20),
                  onPressed: _agregarHabilidadManual,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          if (_habilidadesDisponibles.isNotEmpty) ...[
            Text('O selecciona de la lista:',
                style: TextStyle(
                    color: Colors.grey[500], fontSize: esMovil ? 11 : 12)),
            SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: _habilidadesDisponibles.map((habilidad) {
                final estaSeleccionada =
                    _habilidadesSeleccionadasIds.contains(habilidad['id']);
                return GestureDetector(
                  onTap: () {
                    if (estaSeleccionada) {
                      final indice =
                          _habilidadesSeleccionadasIds.indexOf(habilidad['id']);
                      _quitarHabilidad(indice);
                    } else {
                      _agregarHabilidad(
                          habilidad['id'], habilidad['name'] ?? 'Sin nombre');
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: estaSeleccionada
                          ? Colors.blue[600]
                          : Color(0xFF2D3748),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: estaSeleccionada
                            ? Colors.blue[400]!
                            : Color(0xFF4A5568),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (estaSeleccionada)
                          Icon(Icons.check, color: Colors.white, size: 14),
                        if (estaSeleccionada) SizedBox(width: 4),
                        Text(habilidad['name'] ?? 'Sin nombre',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: esMovil ? 11 : 13)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 16),
          ],
          if (_habilidadesUsuario.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No has agregado habilidades aún',
                    style: TextStyle(
                        color: Colors.grey[600], fontSize: esMovil ? 11 : 12)),
              ),
            )
          else ...[
            Text('Habilidades agregadas:',
                style: TextStyle(
                    color: Colors.grey[400], fontSize: esMovil ? 11 : 12)),
            SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: _habilidadesUsuario.asMap().entries.map((entrada) {
                int indice = entrada.key;
                var habilidad = entrada.value;
                return Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green[700],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green[500]!, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(habilidad['name'],
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: esMovil ? 11 : 13)),
                      SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => _quitarHabilidad(indice),
                        child: Icon(Icons.close, color: Colors.white, size: 14),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _construirSeccionEquipos(bool esMovil) {
    return Container(
      padding: EdgeInsets.all(esMovil ? 16 : 24),
      decoration: BoxDecoration(
        color: Color(0xFF161B22),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0xFF30363D), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.camera_alt_outlined,
                  color: Colors.grey[400], size: 20),
              SizedBox(width: 8),
              Text('Equipos (Opcional)',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: esMovil ? 14 : 16,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          SizedBox(height: 16),
          if (_equiposDisponibles.isNotEmpty) ...[
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Color(0xFF0D1117),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Color(0xFF30363D), width: 1),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  hint: Text('Seleccionar equipo existente...',
                      style: TextStyle(color: Colors.grey[600])),
                  value: _equipoSeleccionadoId,
                  dropdownColor: Color(0xFF161B22),
                  style: TextStyle(color: Colors.white),
                  icon: Icon(Icons.arrow_drop_down, color: Colors.grey[500]),
                  items: _equiposDisponibles.map((equipo) {
                    return DropdownMenuItem<String>(
                      value: equipo['id'],
                      child: Text(equipo['name'] ?? 'Sin nombre'),
                    );
                  }).toList(),
                  onChanged: (valor) {
                    setState(() {
                      _equipoSeleccionadoId = valor;
                      _nombreEquipoController.clear();
                    });
                  },
                ),
              ),
            ),
            SizedBox(height: 12),
            TextFormField(
              controller: _nombreEquipoController,
              style:
                  TextStyle(color: Colors.white, fontSize: esMovil ? 13 : 14),
              decoration: _decoracionCampo('O crear nuevo equipo...', esMovil),
              onChanged: (valor) {
                if (valor.isNotEmpty) {
                  setState(() {
                    _equipoSeleccionadoId = null;
                  });
                }
              },
            ),
          ] else ...[
            TextFormField(
              controller: _nombreEquipoController,
              style:
                  TextStyle(color: Colors.white, fontSize: esMovil ? 13 : 14),
              decoration: _decoracionCampo('Nombre del equipo', esMovil),
            ),
          ],
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _cantidadEquipoController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(
                      color: Colors.white, fontSize: esMovil ? 13 : 14),
                  decoration: _decoracionCampo('Cantidad', esMovil),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _notasEquipoController,
                  style: TextStyle(
                      color: Colors.white, fontSize: esMovil ? 13 : 14),
                  decoration: _decoracionCampo('Notas', esMovil),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: CheckboxListTile(
                  title: Text('Lo tengo',
                      style: TextStyle(
                          color: Colors.white, fontSize: esMovil ? 12 : 13)),
                  value: _poseoEquipo,
                  onChanged: (valor) {
                    setState(() {
                      _poseoEquipo = valor ?? false;
                      if (_poseoEquipo) _tengoExperiencia = false;
                    });
                  },
                  activeColor: Colors.blue[600],
                  contentPadding: EdgeInsets.zero,
                  dense: true, // Hace más compacto
                  controlAffinity: ListTileControlAffinity
                      .leading, // Checkbox a la izquierda
                ),
              ),
              Expanded(
                child: CheckboxListTile(
                  title: Text('Tengo experiencia',
                      style: TextStyle(
                          color: Colors.white, fontSize: esMovil ? 12 : 13)),
                  value: _tengoExperiencia,
                  onChanged: (valor) {
                    setState(() {
                      _tengoExperiencia = valor ?? false;
                      if (_tengoExperiencia) _poseoEquipo = false;
                    });
                  },
                  activeColor: Colors.blue[600],
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.green[600],
                borderRadius: BorderRadius.circular(6),
              ),
              child: IconButton(
                icon: Icon(Icons.add, color: Colors.white, size: 20),
                onPressed: _agregarEquipo,
              ),
            ),
          ),
          SizedBox(height: 16),
          if (_equiposUsuario.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No has agregado equipo aún',
                    style: TextStyle(
                        color: Colors.grey[600], fontSize: esMovil ? 11 : 12)),
              ),
            )
          else
            ..._equiposUsuario.asMap().entries.map((entrada) {
              int indice = entrada.key;
              var equipo = entrada.value;
              return Container(
                margin: EdgeInsets.only(bottom: 8),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFF2D3748),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Color(0xFF4A5568), width: 1),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(equipo['name'],
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text(
                              'Cantidad: ${equipo['quantity']}${equipo['notes'].isNotEmpty ? ' • ${equipo['notes']}' : ''}',
                              style: TextStyle(
                                  color: Colors.grey[400], fontSize: 11)),
                          if (equipo['has_requirement'])
                            Text('✓ Lo tengo',
                                style: TextStyle(
                                    color: Colors.green[400], fontSize: 11)),
                          if (equipo['is_experienced'])
                            Text(
                                '✓ Experiencia: ${equipo['experience_years']} años',
                                style: TextStyle(
                                    color: Colors.blue[400], fontSize: 11)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon:
                          Icon(Icons.close, color: Colors.grey[400], size: 18),
                      onPressed: () => _quitarEquipo(indice),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  InputDecoration _decoracionCampo(String hint, bool esMovil) {
    return InputDecoration(
      hintText: hint,
      hintStyle:
          TextStyle(color: Colors.grey[600], fontSize: esMovil ? 12 : 13),
      fillColor: Color(0xFF0D1117),
      filled: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
    );
  }

  Widget _construirVistaPreviaPortafolio() {
    return Container(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
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
        ],
      ),
    );
  }

  Widget _construirElementoMenu(
      IconData icono, String titulo, bool estaActivo) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: estaActivo
            ? Color(0xFF1F6FEB).withOpacity(0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: estaActivo
            ? Border.all(color: Color(0xFF1F6FEB).withOpacity(0.4), width: 1)
            : null,
      ),
      child: ListTile(
        dense: true,
        leading: Icon(icono,
            color: estaActivo ? Colors.blue[400] : Colors.grey[500], size: 20),
        title: Text(titulo,
            style: TextStyle(
                color: estaActivo ? Colors.blue[300] : Colors.grey[400],
                fontSize: 13,
                fontWeight: estaActivo ? FontWeight.w500 : FontWeight.normal)),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      ),
    );
  }

  Widget _construirIndicadorPaso(String paso, bool estaActivo) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: estaActivo ? Colors.green[600] : Color(0xFF161B22),
        shape: BoxShape.circle,
        border: Border.all(
            color: estaActivo ? Colors.green[600]! : Color(0xFF30363D),
            width: 2),
      ),
      child: Center(
        child: Text(paso,
            style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold)),
      ),
    );
  }
}
