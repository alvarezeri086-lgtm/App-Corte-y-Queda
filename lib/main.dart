import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'auth_provider.dart';
import 'pagina_principal.dart';
import 'pages/exports.dart';
import 'componentes/company_main_layout.dart';
import 'componentes/freelancer_main_layout.dart';
import 'services/notification_service.dart';
import 'providers/notification_provider.dart';
import 'pages/detalles_activacion.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await dotenv.load(fileName: ".env");
  
  NotificationService? notificationService;
  
  try {
    await Firebase.initializeApp();
    
    notificationService = NotificationService(navigatorKey: navigatorKey);
    await notificationService.initialize();
    
  } catch (e) {
    print('Error inicializando Firebase o NotificationService: $e');
    notificationService = null;
  }
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AuthProvider()),
        if (notificationService != null)
          ChangeNotifierProvider<NotificationProvider>(
            create: (context) => NotificationProvider(notificationService!),
          ),
      ],
      child: MyApp(notificationService: notificationService),
    ),
  );
}

class MyApp extends StatelessWidget {
  final NotificationService? notificationService;
  
  MyApp({this.notificationService});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Corte y Queda',
      navigatorKey: navigatorKey,
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
      home: AuthWrapper(), 
      routes: {
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
        '/events': (context) => CompanyMainLayout(initialIndex: 2),
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
        '/candidates': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return CandidatesScreen(
            positionId: args['positionId'] as String,
            organizationId: args['organizationId'] as String,
            activationId: args['activationId'] as String,
            payRate: args['payRate'] as double,
            currency: args['currency'] as String,
          );
        },
        '/company_dashboard': (context) => CompanyMainLayout(initialIndex: 0),
        '/activations': (context) => CompanyMainLayout(initialIndex: 1),
        '/freelancer_dashboard': (context) => FreelancerMainLayout(initialIndex: 0),
        '/profile': (context) => FreelancerMainLayout(initialIndex: 2),
        '/perfil_company': (context) => CompanyMainLayout(initialIndex: 3),
        '/freelancer_activations': (context) => FreelancerMainLayout(initialIndex: 1),
      },
      builder: (context, child) {
        return child!;
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (authProvider.isLoading) {
          return Scaffold(
            backgroundColor: Color(0xFF0A0E1A),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Colors.blue[600],
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Cargando...',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          );
        }

        if (authProvider.isAuthenticated) {
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
            return FreelancerMainLayout(initialIndex: 0);
          } else {
            return CompanyMainLayout(initialIndex: 0);
          }
        }
        return LoginPage();
      },
    );
  }
}