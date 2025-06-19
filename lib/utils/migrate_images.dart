// lib/utils/migrate_images.dart
// TEMPORÄR FIL - Kör en gång sedan ta bort!

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/utils/logger.dart';

/// Engångsmigration från imageUrl till imageUrls
/// KÖR DETTA EN GÅNG sedan ta bort filen!
class ImageMigration {
  static Future<void> migrateToMultipleImages() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        AppLogger.error('Ingen användare inloggad!');
        return;
      }

      AppLogger.info('🔄 Startar bildmigrering för användare: ${user.email}');

      // Hämta alla användarens recept
      final recipesRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('recipes');

      final snapshot = await recipesRef.get();

      AppLogger.info('📦 Hittade ${snapshot.docs.length} recept att migrera');

      int migratedCount = 0;
      int skippedCount = 0;

      // Migrera varje recept
      for (final doc in snapshot.docs) {
        final data = doc.data();

        // Om receptet redan har imageUrls, skippa
        if (data['imageUrls'] != null) {
          skippedCount++;
          AppLogger.info('⏭️ Skippar ${data['title']} - redan migrerat');
          continue;
        }

        // Migrera från imageUrl till imageUrls
        final imageUrl = data['imageUrl'] as String?;
        final imageUrls =
            imageUrl != null && imageUrl.isNotEmpty ? [imageUrl] : <String>[];

        // Uppdatera dokumentet
        await doc.reference.update({
          'imageUrls': imageUrls,
          'imageUrl': FieldValue.delete(), // Ta bort gamla fältet
          'updatedAt': FieldValue.serverTimestamp(),
        });

        migratedCount++;
        AppLogger.success(
          '✅ Migrerade "${data['title']}" med ${imageUrls.length} bilder',
        );
      }

      // Migrera även arkivrecept om du vill
      AppLogger.info('\n🔄 Migrerar arkivrecept...');

      final archiveRef = FirebaseFirestore.instance.collection(
        'butlery_archive',
      );
      final archiveSnapshot = await archiveRef.get();

      int archiveMigratedCount = 0;

      for (final doc in archiveSnapshot.docs) {
        final data = doc.data();

        if (data['imageUrls'] != null) {
          continue;
        }

        final imageUrl = data['imageUrl'] as String?;
        final imageUrls =
            imageUrl != null && imageUrl.isNotEmpty ? [imageUrl] : <String>[];

        await doc.reference.update({
          'imageUrls': imageUrls,
          'imageUrl': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        archiveMigratedCount++;
      }

      AppLogger.info('\n📊 Migrering klar!');
      AppLogger.info(
        '- Användarrecept: $migratedCount migrerade, $skippedCount skippade',
      );
      AppLogger.info('- Arkivrecept: $archiveMigratedCount migrerade');
      AppLogger.success('✅ Total migrering slutförd!');
    } catch (e) {
      AppLogger.error('❌ Fel vid migrering', e);
    }
  }
}

// EXEMPEL PÅ HUR DU KÖR MIGRERINGEN:
// 
// 1. Lägg till en temporär knapp någonstans i appen:
//
// ElevatedButton(
//   onPressed: () async {
//     await ImageMigration.migrateToMultipleImages();
//   },
//   child: Text('Migrera bilder'),
// ),
//
// 2. Kör appen och tryck på knappen
// 3. Vänta tills migreringen är klar
// 4. Ta bort denna fil och knappen!