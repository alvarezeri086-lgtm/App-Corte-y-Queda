import 'package:flutter/material.dart';
import '../pages/panel_page.dart';
import '../pages/activaciones_page.dart';
import '../pages/perfil_company.dart';
import '../pages/exports.dart'; // Asumiendo que EventsPage está aquí

class CompanyMainLayout extends StatefulWidget {
  final int initialIndex;

  const CompanyMainLayout({Key? key, this.initialIndex = 0}) : super(key: key);

  @override
  _CompanyMainLayoutState createState() => _CompanyMainLayoutState();
}

class _CompanyMainLayoutState extends State<CompanyMainLayout> {
  late int _currentIndex;
  
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pages = [
      CompanyDashboardPage(),
      ActivationsPage(),
      EventsPage(), 
      CompanyProfileScreen(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      backgroundColor: Color(0xFF0D1117),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: isMobile
          ? Container(
              decoration: BoxDecoration(
                color: Color(0xFF161B22),
                border: Border(
                  top: BorderSide(color: Color(0xFF30363D), width: 1),
                ),
              ),
              child: BottomNavigationBar(
                backgroundColor: Color(0xFF161B22),
                selectedItemColor: Colors.blue[400],
                unselectedItemColor: Colors.grey[500],
                currentIndex: _currentIndex,
                type: BottomNavigationBarType.fixed,
                showSelectedLabels: true,
                showUnselectedLabels: true,
                selectedFontSize: 11,
                unselectedFontSize: 11,
                onTap: _onItemTapped,
                items: const [
                  BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Resumen operativo'),
                  BottomNavigationBarItem(icon: Icon(Icons.bolt_outlined), activeIcon: Icon(Icons.bolt), label: 'Activaciones'),
                  BottomNavigationBarItem(icon: Icon(Icons.event_outlined), activeIcon: Icon(Icons.event), label: 'Llamados'),
                  BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Perfil'),
                ],
              ),
            )
          : null, // En escritorio asumimos que usas el sidebar lateral
    );
  }
}