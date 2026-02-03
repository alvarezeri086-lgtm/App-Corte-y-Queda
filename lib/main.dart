import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'auth_provider.dart';
import 'pages/login_page.dart';
import 'pages/registro_page.dart';
import 'pages/registration_page2.dart';
import 'pages/complet_profile_page.dart';
import 'pages/complet_profile_page2.dart';
import 'pages/profile_org_page.dart';
import 'pages/events_page.dart';
import 'pages/create_event_page.dart';
import 'pages/events_details_page.dart';
import 'pages/edit_event_page.dart';
import 'pages/create_posicion_page.dart';
import 'pagina_principal.dart';
import 'pages/activaciones_page.dart';
import 'pages/panel_page.dart';
import 'pages/portal_freelancer_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Cargar variables de entorno
  await dotenv.load(fileName: ".env");
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AuthProvider()),
      ],
      child: MaterialApp(
        title: 'Corte y Queda',
        theme: ThemeData(
          primaryColor: Color(0xFF0A0E1A),
          scaffoldBackgroundColor: Color(0xFF0A0E1A),
          fontFamily: 'Inter',
          colorScheme: ColorScheme.dark(
            primary: Colors.blue[600]!,
            secondary: Colors.blue[400]!,
            background: Color(0xFF0A0E1A),
          ),
        ),
        debugShowCheckedModeBanner: false,
        initialRoute: '/',
        routes: {
          
          '/': (context) {
            final authProvider = Provider.of<AuthProvider>(context, listen: false);
            if (authProvider.isAuthenticated) {
              // Verificar el estado del perfil para redirigir correctamente
              final redirectRoute = authProvider.getRedirectRoute();
              
              if (redirectRoute == '/complete_org_profile') {
                return ProfileOrgPage(userId: authProvider.userId ?? '');
              } else if (redirectRoute == '/complete_profile') {
                return CompleteProfilePage(userId: authProvider.userId ?? '');
              } else if (redirectRoute == '/complete_profile2') {
                return CompleteProfilePage2(userId: authProvider.userId ?? '');
              } else if (redirectRoute == '/events') {
                return EventsPage();
              }
              final userType = authProvider.userInfo?['user_type']?.toString() ?? '';
              if (userType.toLowerCase() == 'freelancer') {
                return FreelancerDashboardPage();
              } else {
                return CompanyDashboardPage();
              }
            } else {
              return LoginPage();
            }
          },
          '/login': (context) => LoginPage(),
          '/registro': (context) => RegistroPage(),
          '/registration2': (context) {
            final arguments = ModalRoute.of(context)!.settings.arguments;
            if (arguments != null && arguments is String) {
              return RegistrationPage2(accountType: arguments);
            }
            return RegistroPage(); 
          },
          '/complete_profile': (context) {
            final arguments = ModalRoute.of(context)!.settings.arguments;
            if (arguments != null && arguments is String) {
              return CompleteProfilePage(userId: arguments);
            }
            return LoginPage(); 
          },
          '/complete_profile2': (context) {
            final arguments = ModalRoute.of(context)!.settings.arguments;
            if (arguments != null && arguments is String) {
              return CompleteProfilePage2(userId: arguments);
            }
            return LoginPage(); 
          },
          '/complete_org_profile': (context) {
            final arguments = ModalRoute.of(context)!.settings.arguments;
            if (arguments != null && arguments is String) {
              return ProfileOrgPage(userId: arguments);
            }
            return LoginPage(); 
          },
          '/events': (context) => EventsPage(),
          '/create_event': (context) => CreateEventPage(),
          '/home': (context) => PaginaPrincipal(),
          '/event_details': (context) {
            final eventId = ModalRoute.of(context)!.settings.arguments as String;
            return EventDetailsPage(eventId: eventId);
          },
          '/edit_event': (context) {
            final eventId = ModalRoute.of(context)!.settings.arguments as String;
            return EditEventPage(eventId: eventId);
          },
          '/create_position': (context) {
            final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
            return CreatePositionPage(
              eventId: args['eventId'],
              eventTitle: args['eventTitle'],
            );
          },
          '/company_dashboard': (context) => CompanyDashboardPage(),
          '/activations': (context) => ActivationsPage(),
          '/freelancer_dashboard': (context) => FreelancerDashboardPage(),
        },
        onGenerateRoute: (settings) {
          return null;
        },
      ),
    );
  }
}