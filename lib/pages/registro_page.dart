import 'package:flutter/material.dart';
import 'registration_page2.dart';
import 'login_page.dart'; 

class RegistroPage extends StatefulWidget {
  @override
  _RegistroPageState createState() => _RegistroPageState();
}

class _RegistroPageState extends State<RegistroPage> {
  String? _selectedAccountType;

  void _navigateToNextPage() {
    if (_selectedAccountType != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RegistrationPage2(
            accountType: _selectedAccountType!,
          ),
        ),
      );
    }
  }

  void _navigateToLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LoginPage(), 
      ),
    );
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                 
                  Row(
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
                  
                  if (!isMobile)
                    Row(
                      children: [
                        Text('¿Ya tienes una cuenta?',
                            style: TextStyle(
                                color: Colors.grey[400], fontSize: 14)),
                        SizedBox(width: 12),
                        
                        GestureDetector(
                          onTap: _navigateToLogin,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: Color(0xFF2D3748), width: 1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('Iniciar sesión',
                                style: TextStyle(
                                    color: Colors.blue[300],
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500)),
                          ),
                        ),
                      ],
                    )
                  else
                    GestureDetector(
                      onTap: _navigateToLogin,
                      child: Text('¿Ya tienes una cuenta?',
                          style:
                              TextStyle(color: Colors.grey[400], fontSize: 12)),
                    ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 900),
                  padding: EdgeInsets.all(isMobile ? 20 : 40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isMobile) SizedBox(height: 20),
                   
                      Text(
                        '¿Cómo planeas usar Corte y Queda?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isMobile ? 24 : 32,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 12),
                      Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 0 : 40),
                        child: Text(
                          'Elige el tipo de cuenta que mejor se adapte a tu rol en la industria audiovisual.',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: isMobile ? 14 : 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(height: isMobile ? 30 : 60),
                      if (isMobile)
                        Column(
                          children: [
                            _buildAccountTypeCard(
                              icon: Icons.person_outline,
                              title: 'Profesional',
                              description:
                                  'Soy freelance o contratista independiente buscando proyectos.',
                              value: 'FREELANCER',
                            ),
                            SizedBox(height: 16),
                            _buildAccountTypeCard(
                              icon: Icons.business_outlined,
                              title: 'Empresa',
                              description:
                                  'Represento una productora que necesita coordinar equipos.',
                              value: 'ADMIN',
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: _buildAccountTypeCard(
                                icon: Icons.person_outline,
                                title: 'Profesional',
                                description:
                                    'Soy freelance o contratista independiente buscando proyectos.',
                                value: 'FREELANCER',
                              ),
                            ),
                            SizedBox(width: 24),
                            Expanded(
                              child: _buildAccountTypeCard(
                                icon: Icons.business_outlined,
                                title: 'Empresa',
                                description:
                                    'Represento una productora que necesita coordinar equipos.',
                                value: 'ADMIN',
                              ),
                            ),
                          ],
                        ),
                      SizedBox(height: isMobile ? 30 : 48),
                      SizedBox(
                        width: isMobile ? double.infinity : 300,
                        child: TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: Text(
                            'Regresar al inicio',
                            style: TextStyle(
                              color: Colors.blue[400],
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      if (isMobile) SizedBox(height: 20),
                    ],
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
                            '© 2026 Corte y Queda SYSTEMS. TODOS LOS DERECHOS RESERVADOS.',
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
                        Text('© 2026 Corte y Queda SYSTEMS. TODOS LOS DERECHOS RESERVADOS.',
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

  Widget _buildAccountTypeCard({
    required IconData icon,
    required String title,
    required String description,
    required String value,
  }) {
    bool isSelected = _selectedAccountType == value;
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedAccountType = value;
        });
        Future.delayed(Duration(milliseconds: 100), _navigateToNextPage);
      },
      child: Container(
        height: isMobile ? 240 : 320,
        decoration: BoxDecoration(
          color: Color(0xFF161B22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue[500]! : Color(0xFF2D3748),
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 24,
                    spreadRadius: 0,
                  )
                ]
              : null,
        ),
        child: Column(
          children: [
            Container(
              height: isMobile ? 140 : 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Color(0xFF1C2432),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(10),
                  topRight: Radius.circular(10),
                ),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Icon(
                      icon,
                      size: isMobile ? 100 : 140,
                      color: Colors.white.withOpacity(0.05),
                    ),
                  ),
                  Positioned(
                    top: isMobile ? 12 : 20,
                    left: isMobile ? 12 : 20,
                    child: Container(
                      padding: EdgeInsets.all(isMobile ? 8 : 10),
                      decoration: BoxDecoration(
                        color: Colors.blue[600],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon,
                          color: Colors.white, size: isMobile ? 16 : 20),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: isMobile ? 18 : 22,
                      ),
                    ),
                    SizedBox(height: isMobile ? 6 : 12),
                    Flexible(
                      child: Text(
                        description,
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: isMobile ? 12 : 14,
                          height: 1.5,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}