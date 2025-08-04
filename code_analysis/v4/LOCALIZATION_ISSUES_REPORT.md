# Butlery Flutter App - Localization Issues Report

## Summary
After analyzing the Butlery Flutter app, I found several hardcoded Swedish strings that should be moved to the `AppStrings` constants file for better maintainability and potential future internationalization. The app generally follows good localization practices with most strings in `AppStrings`, but there are still many hardcoded strings in the view files.

## Issues Found

### 1. Hardcoded Swedish Strings Outside AppStrings

#### auth_view.dart
- Line 220: `'Smart recepthantering för din vardag'` - Should be in AppStrings
- Line 252: `'Logga in'` - Should use AppStrings constant
- Line 252: `'Skapa konto'` - Should use AppStrings constant  
- Line 319: `'Ditt namn'` - Should use AppStrings constant
- Line 320: `'Ange ditt namn'` - Should use AppStrings constant
- Line 349: `'Email'` - Inconsistent, AppStrings uses 'E-post'
- Line 350: `'din.email@exempel.se'` - Should use AppStrings.emailPlaceholder
- Line 376: `'Lösenord'` - Should use AppStrings constant
- Line 481: `'Logga in'` / `'Skapa konto'` - Duplicate hardcoded strings
- Line 507: `'Har du inget konto? '` - Should use AppStrings
- Line 508: `'Har du redan ett konto? '` - Should use AppStrings
- Line 512: `'Skapa konto'` / `'Logga in'` - More duplicates
- Line 611: `'Email'` - Inconsistent with AppStrings which uses 'E-post'
- Line 612: `'din.email@exempel.se'` - Should use AppStrings.emailPlaceholder
- Line 643: `'Email skickad! Kontrollera din inkorg.'` - Should use AppStrings
- Line 644: `'Kunde inte skicka email'` - Should use AppStrings

#### mina_recept_view.dart
- Line 496: `'Mina recept'` - Should use AppStrings constant
- Line 534: `'Filtrera'` - Should use AppStrings constant
- Line 544: `'Visa fel'` - Should use AppStrings constant
- Line 559-583: Sort menu items `'Titel'`, `'Tid'`, `'Betyg'`, `'Måltidstyp'` - Should use AppStrings
- Line 670: `'Försök igen'` - Should use AppStrings.retry
- Line 694: `'Rensa sökning'` - Should use AppStrings
- Line 695: `'Rensa filter'` - Should use AppStrings
- Line 709: `'Offline-läge - visar lokala recept'` - Should use AppStrings

#### skriv_sjalv_recept_view.dart
- Line 62: `'Recept sparat!'` - Should use AppStrings
- Line 67: `'Kunde inte spara recept'` - Should use AppStrings
- Line 116: `'Lägg till från URL'` - Should use AppStrings
- Line 117: `'För bilder från webben'` - Should use AppStrings
- Line 122: `'Avbryt'` - Should use AppStrings.cancel (already exists)
- Line 148: `'Lägg till bild från URL'` - Should use AppStrings
- Line 152: `'Bild-URL'` - Should use AppStrings
- Line 153: `'https://exempel.com/bild.jpg'` - Should use AppStrings
- Line 161: `'Avbryt'` - Should use AppStrings.cancel
- Line 165: `'Lägg till'` - Should use AppStrings.add
- Line 178: `'Ogiltig URL. Använd en fullständig URL som börjar med http:// eller https://'` - Should use AppStrings
- Line 193: `'Redigera recept'` / `'Skriv nytt recept'` - Should use AppStrings
- Line 210: `'Måltidstyp'` - Should use AppStrings
- Line 242: `'Titel'` - Should use AppStrings
- Line 257: `'Beskrivning'` - Should use AppStrings.recipeDescription
- Line 268: `'Portioner'` - Should use AppStrings.portions
- Line 281: `'Tid (min)'` - Should use AppStrings
- Line 290-318: `'Ingrediens'`, `'Instruktion'`, `'Tagg'` - Should use AppStrings
- Line 325: `'Betyg (0–5)'` - Should use AppStrings
- Line 340: `'Källa (URL)'` - Should use AppStrings
- Line 341: `'Valfritt: länk till originalreceptet'` - Should use AppStrings
- Line 343: `'Importerat från delning'` - Should use AppStrings
- Line 344: `'Länk till originalreceptet'` - Should use AppStrings
- Line 366: `'Sparar recept...'` - Should use AppStrings
- Line 377: `'Spara recept'` - Should use AppStrings
- Line 383: `'Sparar...'` - Should use AppStrings.saving
- Line 441: `'Lägg till {label}'` - Should use AppStrings pattern

#### veckomeny_view.dart
- Line 281: `'Skapa en meny först innan du kan spara den'` - Should use AppStrings
- Line 331: `'Veckomeny delad!'` - Should use AppStrings
- Line 351: `'Skapa en meny först innan du kan dela den'` - Should use AppStrings
- Line 361: `'Kunde inte hämta vänner: {e}'` - Should use AppStrings pattern
- Line 369: `'Kolla min veckomeny!'` - Should use AppStrings
- Line 392: `'Skapa en meny först innan du kan skapa inköpslista'` - Should use AppStrings
- Line 424: `'Avsluta Butlery?'` - Should use AppStrings.exitApp
- Line 425: `'Vill du verkligen avsluta appen?'` - Should use AppStrings.exitAppConfirmation
- Line 429: `'Avbryt'` - Should use AppStrings.cancel
- Line 436: `'Avsluta'` - Should use AppStrings.exit

#### importera_fran_arkiv_view.dart
- Line 45: `'Recept importerade!'` - Should use AppStrings
- Line 62: `'Importera från Butlerys arkiv'` - Should use AppStrings
- Line 72: `'Visa fel'` - Should use AppStrings
- Line 93: `'Sök i arkiv...'` - Should use AppStrings

### 2. Spelling Errors
No spelling errors were found in the Swedish text. The Swedish spelling appears to be correct throughout the codebase.

### 3. Inconsistent Terminology

#### Email vs E-post
- `auth_view.dart` uses "Email" in multiple places
- `AppStrings` defines `emailRequired = 'E-post krävs'`
- Should consistently use either "Email" or "E-post" throughout

#### Button Labels
- Some views use imperative form: "Spara", "Lägg till", "Ta bort"
- Others use noun form for actions
- Should maintain consistency in button label grammar

### 4. Missing AppStrings Constants
The following commonly used strings should be added to AppStrings:
- Login/registration prompts
- Menu-related messages
- Import/export success messages
- Offline mode messages
- URL validation messages
- Menu generation prompts

## Recommendations

1. **Create new AppStrings entries** for all hardcoded strings identified above
2. **Standardize terminology**: Decide on "Email" vs "E-post" and use consistently
3. **Group related strings** in AppStrings (e.g., all menu-related strings together)
4. **Add string formatter methods** to AppStrings for complex messages with variables
5. **Consider creating sub-classes** of AppStrings for different features (e.g., AppStrings.Menu, AppStrings.Auth)

## Example Improvements

```dart
// Instead of hardcoded:
'Skapa en meny först innan du kan spara den'

// Add to AppStrings:
static const String menuRequiredBeforeSave = 'Skapa en meny först innan du kan spara den';

// Or with better structure:
class MenuStrings {
  static const String requiredBeforeSave = 'Skapa en meny först innan du kan spara den';
  static const String requiredBeforeShare = 'Skapa en meny först innan du kan dela den';
  static const String requiredBeforeShoppingList = 'Skapa en meny först innan du kan skapa inköpslista';
}
```