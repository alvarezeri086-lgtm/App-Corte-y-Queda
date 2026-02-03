import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_provider.dart';

class PaginaPrincipal extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Página Principal'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () {
            Provider.of<AuthProvider>(context, listen: false).logout();
            },
          ),
        ],
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          final userInfo = authProvider.userInfo;
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('¡Bienvenido a la página principal!'),
                SizedBox(height: 20),
                if (userInfo != null)
                  if (userInfo['freelancer_profile'] != null)
                    Column(
                      children: [
                        Text('Perfil de Freelancer:'),
                        Text('Nombre: ${userInfo['full_name'] ?? 'N/A'}'),
                        Text('Email: ${userInfo['email'] ?? 'N/A'}'),
                        Text('Teléfono: ${userInfo['phone'] ?? 'N/A'}'),
                        Text('Bio: ${userInfo['freelancer_profile']['bio'] ?? 'N/A'}'),
                        Text('Años de Experiencia: ${userInfo['freelancer_profile']['years_experience'] ?? 'N/A'}'),
                        Text('Rating: ${userInfo['freelancer_profile']['rating'] ?? 'N/A'}'),
                        Text('Ubicación: ${userInfo['freelancer_profile']['location'] ?? 'N/A'}'),
                      ],
                    )
                  else if (userInfo['organization'] != null)
                    Column(
                      children: [
                        Text('Información de la Organización:'),
                        Text('Nombre Legal: ${userInfo['organization']['legal_name'] ?? 'N/A'}'),
                        Text('Nombre Comercial: ${userInfo['organization']['trade_name'] ?? 'N/A'}'),
                        Text('RFC: ${userInfo['organization']['rfc'] ?? 'N/A'}'),
                        Text('País: ${userInfo['organization']['country_code'] ?? 'N/A'}'),
                        Text('Descripción: ${userInfo['organization']['description'] ?? 'N/A'}'),
                        Text('Verificado: ${userInfo['organization']['verification_badge'] ?? false}'),
                      ],
                    )
                  else
                    Text('No se encontró información del perfil.')
                else
                  Text('Cargando información del usuario...'),
              ],
            ),
          );
        },
      ),
    );
  }
}