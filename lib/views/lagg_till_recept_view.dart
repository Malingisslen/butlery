import 'package:flutter/material.dart';
import '../widgets/main_layout_menu.dart';
import '../theme/app_theme.dart';

class LaggTillReceptView extends StatelessWidget {
  const LaggTillReceptView({super.key});

  void _navigate(BuildContext context, String routeName) {
    Navigator.pushNamed(context, routeName);
  }

  ButtonStyle _buttonStyle() {
    return ElevatedButton.styleFrom(
      padding: EdgeInsets.symmetric(
        vertical: AppTheme.spacingMd,
      ), // ✅ 16px från theme
      textStyle: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600, // ✅ Standardiserad font weight
      ),
      minimumSize: Size(double.infinity, 56), // ✅ Konsistent knapp-höjd
    );
  }

  @override
  Widget build(BuildContext context) {
    return MainLayoutMenu(
      currentIndex: 1,
      body: Padding(
        padding: EdgeInsets.all(AppTheme.spacingLg), // ✅ 24px från theme
        child: ListView(
          children: [
            Text(
              'Hur vill du lägga till ditt recept?',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                // ✅ Theme typography
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            SizedBox(height: AppTheme.spacingXl), // ✅ 32px från theme

            ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: const Text('INSTAGRAM'),
              onPressed: () => _navigate(context, '/franSocialaMedier'),
              style: _buttonStyle(),
            ),
            SizedBox(height: AppTheme.spacingMd), // ✅ 16px från theme

            ElevatedButton.icon(
              icon: const Icon(Icons.facebook),
              label: const Text('FACEBOOK'),
              onPressed: () => _navigate(context, '/franSocialaMedier'),
              style: _buttonStyle(),
            ),
            SizedBox(height: AppTheme.spacingMd), // ✅ 16px från theme

            ElevatedButton.icon(
              icon: const Icon(Icons.music_note),
              label: const Text('TIKTOK'),
              onPressed: () => _navigate(context, '/franSocialaMedier'),
              style: _buttonStyle(),
            ),
            SizedBox(height: AppTheme.spacingMd), // ✅ 16px från theme

            ElevatedButton.icon(
              icon: const Icon(Icons.photo),
              label: const Text('FOTO'),
              onPressed: () => _navigate(context, '/photoImport'),
              style: _buttonStyle(),
            ),
            SizedBox(height: AppTheme.spacingMd), // ✅ 16px från theme

            ElevatedButton.icon(
              icon: const Icon(Icons.link),
              label: const Text('LÄNK'),
              onPressed: () => _navigate(context, '/importViaUrl'),
              style: _buttonStyle(),
            ),
            SizedBox(height: AppTheme.spacingMd), // ✅ 16px från theme

            ElevatedButton.icon(
              icon: const Icon(Icons.edit),
              label: const Text('SKRIV SJÄLV'),
              onPressed: () => _navigate(context, '/skrivSjalv'),
              style: _buttonStyle(),
            ),
            SizedBox(height: AppTheme.spacingMd), // ✅ 16px från theme

            ElevatedButton.icon(
              icon: const Icon(Icons.archive),
              label: const Text('FRÅN BUTLERYS ARKIV'),
              onPressed: () => _navigate(context, '/importFranArkiv'),
              style: _buttonStyle(),
            ),
          ],
        ),
      ),
    );
  }
}
