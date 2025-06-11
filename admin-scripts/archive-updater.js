const admin = require('firebase-admin');
const fs = require('fs').promises;
const path = require('path');

// Initiera Firebase Admin SDK
// OBS: Du behöver ladda ner service account key från Firebase Console
const serviceAccount = require('./service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// Funktioner för arkivhantering
async function exportArchive(outputFile) {
  console.log('📥 Exporterar arkiv från Firestore...');
  
  try {
    const snapshot = await db.collection('butlery_archive').get();
    const recipes = [];
    
    snapshot.forEach(doc => {
      recipes.push({
        id: doc.id,
        ...doc.data()
      });
    });
    
    await fs.writeFile(outputFile, JSON.stringify(recipes, null, 2));
    console.log(`✅ Exporterat ${recipes.length} recept till ${outputFile}`);
  } catch (error) {
    console.error('❌ Fel vid export:', error);
  }
}

async function importArchive(inputFile) {
  console.log('📤 Importerar arkiv till Firestore...');
  
  try {
    const data = await fs.readFile(inputFile, 'utf8');
    const recipes = JSON.parse(data);
    
    // Använd batch för effektivitet
    const batch = db.batch();
    
    recipes.forEach(recipe => {
      const docRef = db.collection('butlery_archive').doc(recipe.id);
      batch.set(docRef, recipe);
    });
    
    await batch.commit();
    console.log(`✅ Importerat ${recipes.length} recept till Firestore`);
  } catch (error) {
    console.error('❌ Fel vid import:', error);
  }
}

async function clearArchive() {
  console.log('🗑️  Rensar arkivet...');
  
  try {
    const snapshot = await db.collection('butlery_archive').get();
    const batch = db.batch();
    
    snapshot.forEach(doc => {
      batch.delete(doc.ref);
    });
    
    await batch.commit();
    console.log('✅ Arkivet rensat');
  } catch (error) {
    console.error('❌ Fel vid rensning:', error);
  }
}

async function updateArchiveFromDart() {
  console.log('🔄 Uppdaterar arkiv från archived_recipes.dart...');
  
  try {
    // Läs archived_recipes.dart filen
    const dartFile = path.join(__dirname, '../lib/data/archived_recipes.dart');
    const content = await fs.readFile(dartFile, 'utf8');
    
    // Extrahera Recipe-listan
    const listMatch = content.match(/final archivedRecipes = \[([\s\S]*?)\];/);
    
    if (!listMatch) {
      throw new Error('Kunde inte hitta receptdata i Dart-filen');
    }
    
    // Extrahera alla Recipe(...) objekt
    const recipeMatches = listMatch[1].matchAll(/Recipe\(([\s\S]*?)\),?(?=\s*(?:Recipe\(|$))/g);
    const recipes = [];
    
    for (const match of recipeMatches) {
      const recipeContent = match[1];
      
      // Bygg ett objekt från Recipe-parametrarna
      const recipe = {};
      
      // Matcha alla key: value par
      const fieldMatches = recipeContent.matchAll(/(\w+):\s*([^,]*?(?:\[[^\]]*\]|{[^}]*}|[^,])*?)(?=,\s*\w+:|$)/gs);
      
      for (const fieldMatch of fieldMatches) {
        const key = fieldMatch[1];
        let value = fieldMatch[2].trim();
        
        // Hantera olika värdetyper
        if (value.startsWith("'") || value.startsWith('"')) {
          // String - ta bort citattecken
          value = value.slice(1, -1);
        } else if (value.startsWith('[')) {
          // Lista - parsa som JSON efter fix av syntax
          value = value
            .replace(/'/g, '"')
            .replace(/,\s*]/, ']');
          try {
            value = JSON.parse(value);
          } catch (e) {
            console.warn(`Kunde inte parsa lista för ${key}:`, value);
            value = [];
          }
        } else if (value === 'true' || value === 'false') {
          // Boolean
          value = value === 'true';
        } else if (!isNaN(value)) {
          // Nummer
          value = Number(value);
        }
        
        recipe[key] = value;
      }
      
      if (recipe.id) {
        recipes.push(recipe);
      }
    }
    
    console.log(`📋 Hittade ${recipes.length} recept att importera`);
    
    // Importera till Firestore
    const batch = db.batch();
    
    recipes.forEach((recipe, index) => {
      const docRef = db.collection('butlery_archive').doc(recipe.id);
      batch.set(docRef, recipe);
      
      if ((index + 1) % 100 === 0) {
        console.log(`   Förbereder recept ${index + 1}/${recipes.length}...`);
      }
    });
    
    await batch.commit();
    console.log(`✅ Uppdaterat arkivet med ${recipes.length} recept från Dart-filen`);
  } catch (error) {
    console.error('❌ Fel vid uppdatering från Dart:', error);
    console.error('Stack trace:', error.stack);
  }
}

// CLI hantering
const command = process.argv[2];
const file = process.argv[3];

switch (command) {
  case 'export':
    if (!file) {
      console.error('❌ Ange filnamn: node archive-updater.js export output.json');
      process.exit(1);
    }
    exportArchive(file);
    break;
    
  case 'import':
    if (!file) {
      console.error('❌ Ange filnamn: node archive-updater.js import input.json');
      process.exit(1);
    }
    importArchive(file);
    break;
    
  case 'clear':
    clearArchive();
    break;
    
  case 'update-from-dart':
    updateArchiveFromDart();
    break;
    
  default:
    console.log(`
🔧 Butlery Arkiv Admin Tool
   
Användning:
  node archive-updater.js <kommando> [fil]
  
Kommandon:
  export <fil>         Exportera arkiv från Firestore till JSON
  import <fil>         Importera JSON till Firestore arkiv
  clear               Rensa hela arkivet
  update-from-dart    Uppdatera från archived_recipes.dart
  
Exempel:
  node archive-updater.js export backup.json
  node archive-updater.js import recipes.json
  node archive-updater.js update-from-dart
    `);
}