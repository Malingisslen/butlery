import 'package:flutter/material.dart';

class MainLayoutMenu extends StatelessWidget {
  final Widget body;
  final int? currentIndex;
  final String? title;

  const MainLayoutMenu({
    super.key,
    required this.body,
    this.currentIndex,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: title != null ? AppBar(title: Text(title!)) : null,
      body: body,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex ?? 0, // fallback om null
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.pushNamed(context, '/');
              break;
            case 1:
              Navigator.pushNamed(context, '/laggTill');
              break;
            case 2:
              Navigator.pushNamed(context, '/veckomeny');
              break;
            case 3:
              Navigator.pushNamed(context, '/inkopslista');
              break;
          }
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Mina recept'),
          BottomNavigationBarItem(icon: Icon(Icons.add), label: 'Lägg till'),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Veckomeny',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Inköpslista',
          ),
        ],
      ),
    );
  }
}
