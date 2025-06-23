🤝 Butlerys Sociala Platform - Teamgenomgång
📋 Vad är den sociala delen?
Den sociala delen av Butlery låter användare dela recept och veckomeny med varandra, precis som man delar bilder på Instagram eller inlägg på Facebook. Men istället för att dela foton delar våra användare mat-innehåll som hjälper varandra i vardagen.

👥 Hur fungerar vänskap i appen?
Steg 1: Hitta vänner

Användare kan söka på andra användare med namn
Man ser en lista med personer som matchar sökningen
Varje person visas med namn och profilbild

Steg 2: Skicka vänskapsförfrågan

Klicka på "Lägg till vän" på någons profil
Frivilligt: Skriv ett meddelande (t.ex. "Hej! Vi träffades på barnkalaset förra veckan")
Förfrågan skickas till den andra personen

Steg 3: Acceptera eller avböja

Mottagaren får en notifikation (röd prick på profilikonen)
De kan se vem som skickade förfrågan + eventuellt meddelande
Väljer "Acceptera" eller "Avböj"
Om accepterad: Nu är ni vänner! 🎉


🍳 Dela recept med vänner
När du vill dela ett recept:

Öppna vilket recept som helst från din samling
Tryck på "personer-ikonen" (bredvid den vanliga delnings-knappen)
Välj vilka vänner du vill dela med (kan välja flera)
Skriv ett meddelande (valfritt): "Provade detta ikväll - så gott!"
Tryck "Dela"

Vad händer då:

Dina valda vänner får en notifikation
Receptet hamnar i deras "Delat med mig"-sektion
De kan se vem som delade det och ditt meddelande
De kan importera receptet till sin egen samling eller dölja det


📅 Dela veckomeny med vänner
När du har skapat en veckomeny:

Gå till Veckomeny-fliken och skapa/ladda en meny
Tryck på "personer-ikonen" (bredvid vanliga delnings-knappen)
Välj vänner att dela med
Anpassa meny-titel (t.ex. "Marias vintermeny 2025")
Skriv meddelande: "Här är min favoritveckomeny för vintern!"
Tryck "Dela"

Vad får mottagarna:

De ser hela din veckomeny med alla recept organiserade per dag
De kan bläddra genom alla rätter för varje dag
De kan importera hela menyn (alla recept läggs till i deras samling)
Eller dölja menyn om den inte intresserar dem


📥 Ta emot delat innehåll
Var hittar jag det som delats med mig?

Hemskärmen: Röd siffra på din profilbild visar antal nya delningar
"Delat med mig": Egen sektion nåbar via profilmenyn
Två flikar: "Recept" och "Menyer"

Vad kan jag göra med delat innehåll?
För varje delat recept/meny kan du:

✅ Visa: Titta på receptet/menyn i detalj
✅ Importera: Lägg till i din egen samling (kopieras, original påverkas inte)
✅ Dölja: Ta bort från din lista (syns inte längre för dig, men andra påverkas inte)

"Dölja" vs "Importera" - Vad är skillnaden?

Importera = "Ja tack! Jag vill ha detta recept/meny i min samling"
Dölja = "Nej tack, inte intresserad" (försvinner från din lista)
Inget val = Ligger kvar i "Delat med mig" tills du bestämmer dig


🔔 Notifikationssystem
Vad ger notifikationer?

Nya vänskapsförfrågningar
Nya delade recept från vänner
Nya delade menyer från vänner

Var syns notifikationer?

Röd siffra på din profilbild (hemskärmen)
Uppdelat per typ i respektive sektion
"Notiser" i profilmenyn samlar vänskapsförfrågningar


🎯 Praktiska exempel
Exempel 1: Vardagsdelning

Maria har provat ett nytt recept på laxpasta som blev superpopulärt hos familjen. Hon delar det med sina 3 vänner med meddelandet "Barnen åt upp allt - måste testa!"
Anna och Lisa importerar receptet direkt, medan Sara döjer det eftersom hennes familj inte äter fisk.

Exempel 2: Veckoplanering

Johan har planerat en hel vecka med vegetariska rätter inför januari. Han delar sin "Veggie-januari veckomeny" med 5 vänner.
3 vänner importerar hela menyn för att kopiera hans planering, medan 2 vänner bara tittar på några specifika recept och importerar bara dem.

Exempel 3: Säsongsdelning

Eva delar sin "Sommargrill-meny" i juni med 8 vänner. Menyn innehåller 12 olika grillrecept organiserade för en hel vecka.
Hennes vänner kan antingen ta hela menyn eller bara plocka ut de grillrecept som verkar intressanta.


🛡️ Integritet och säkerhet
Vem kan se vad?

Endast dina vänner kan se recept/menyer du delar socialt
Dina original-recept påverkas aldrig av vad andra gör
Du bestämmer själv vad du delar och med vem

Vad händer om jag tar bort en vän?

Tidigare delningar försvinner inte automatiskt
Framtida delningar kommer inte fram till varandra
Importerade recept påverkas inte (de har redan kopierats)


📱 Var i appen?
Huvudnavigation:

Hemskärm → Din profilbild (övre högra hörnet)
Profilmeny öppnas → Olika alternativ:

"Vänner" (hantera vänskaper)
"Notiser" (vänskapsförfrågningar)
"Delat med mig" (mottaget innehåll)



I recept/meny-vyer:

Recept-detaljvy → "Personer-ikon" för social delning
Veckomeny-vy → "Personer-ikon" för meny-delning


🎉 Fördelar för användarna
✅ Inspiration: Få nya receptidéer från vänner istället för att googla
✅ Tidsbesparande: Kopiera hela veckomenyer från andra
✅ Social gemenskap: Dela matglädje med familj och vänner
✅ Kvalitetsfilter: Recept från vänner känns mer pålitliga än slumpmässiga från nätet
✅ Anpassning: Ta bara det du vill ha, dölja resten

🏗️ Teknisk Arkitektur
Databasstruktur (Firebase Firestore)
├── users/{userId}
│   ├── profile/               # Användarprofilsn
│   ├── recipes/{recipeId}     # Användarens egna recept
│   └── friends/{friendId}     # Vänrelationer
│
├── friend_requests/{requestId} # Vänskapsförfrågningar
├── shared_recipes/{shareId}    # Delade recept med metadata
├── shared_menus/{shareId}      # Delade menyer med metadata
└── user_profiles/{userId}      # Publika profiler för sökning
Huvudkomponenter
Services (Affärslogik):

UserService - Hantera användarprofilsn och sökning
FriendsService - Vänskaper och förfrågningar
SocialRecipeService - Delning av recept och menyer
RecipeService - CRUD för recept (befintlig, utökad)

ViewModels (Presentation):

FriendsViewModel - UI-logik för vänhantering
SocialRecipeViewModel - UI-logik för social delning
SharedContentViewModel - UI-logik för mottaget innehåll
UserProfileViewModel - UI-logik för profil-redigering

Views (Användargränssnitt):

FriendsListView - Vänlista och sök
FriendRequestsView - Hantera förfrågningar
SharedWithMeView - Mottaget innehåll
UserProfileEditView - Redigera profil

Dataflöde och Säkerhet

Autentisering: Firebase Authentication
Användarspecifik data: Alla recept/menyer kopplade till userId
Åtkomstkontroll: Firestore Security Rules säkerställer att användare bara kan:

Läsa sina egna recept/menyer
Läsa delade recept/menyer där de är mottagare
Söka publika användarprofiler
Skicka vänskapsförfrågningar



Performance-optimeringar

Caching: Användarprofiler cachas lokalt (30 min TTL)
Batch-operationer: Flera recept importeras samtidigt
Indexerad sökning: displayNameLower för case-insensitive sökning
Lazy loading: Kommentarer laddas bara när de expanderas


📊 Detaljerat Flödeschema: Social Platform med Kodfiler
mermaidgraph TD
    %% App Start & Auth
    A[main.dart<br/>App Start] --> B[auth_service.dart<br/>Firebase Auth]
    B --> C[mina_recept_view.dart<br/>Hemskärm]
    
    %% Notification System
    C --> AVATAR[user_avatar.dart<br/>Avatar + Badge]
    AVATAR --> NOTIF_COUNT{Notification Count}
    
    %% Friend System Sources
    FRIENDS_VM[friends_viewmodel.dart] --> NOTIF_COUNT
    SHARED_VM[shared_content_viewmodel.dart] --> NOTIF_COUNT
    
    NOTIF_COUNT --> BADGE[🔴 Badge Number<br/>friends + shared content]
    
    %% User Profile Management
    C --> PROFILE_EDIT[user_profile_edit_view.dart<br/>Skapa/Redigera profil]
    PROFILE_EDIT --> USER_SVC[user_service.dart<br/>Profile CRUD]
    USER_SVC --> FIRESTORE_USERS[(users/{userId}/profile)]
    
    %% Friend Discovery & Management
    C --> FRIEND_NAV[Tryck på Avatar<br/>→ Vänner]
    FRIEND_NAV --> FRIENDS_VIEW[friends_list_view.dart<br/>Vänlista + Sök]
    FRIENDS_VIEW --> FRIENDS_VM
    
    %% Friend Search Flow
    FRIENDS_VM --> SEARCH_USERS[user_service.dart<br/>searchUsers()]
    SEARCH_USERS --> FIRESTORE_SEARCH[(user_profiles/{userId}<br/>displayNameLower index)]
    FIRESTORE_SEARCH --> SEARCH_RESULTS[Sökresultat visas]
    
    %% Friend Request Flow
    SEARCH_RESULTS --> SEND_REQUEST[Skicka vänskapsförfrågan]
    SEND_REQUEST --> FRIEND_SVC[friends_service.dart<br/>sendFriendRequest()]
    FRIEND_SVC --> FIRESTORE_REQUESTS[(friend_requests/{requestId})]
    FIRESTORE_REQUESTS --> RECIPIENT_NOTIF[🔔 Mottagare får notifikation]
    
    %% Friend Request Management
    RECIPIENT_NOTIF --> REQUEST_VIEW[friend_requests_view.dart<br/>Hantera förfrågningar]
    REQUEST_VIEW --> FRIENDS_VM2[friends_viewmodel.dart<br/>loadUserProfilesForRequests()]
    FRIENDS_VM2 --> REAL_USER_DATA[Visa riktig användardata<br/>namn + avatar]
    
    REAL_USER_DATA --> ACCEPT_REJECT{Acceptera/Avböj?}
    ACCEPT_REJECT -->|Acceptera| BECOME_FRIENDS[friends_service.dart<br/>acceptFriendRequest()]
    ACCEPT_REJECT -->|Avböj| REJECT_REQUEST[friends_service.dart<br/>rejectFriendRequest()]
    
    BECOME_FRIENDS --> FIRESTORE_FRIENDS[(users/{userId}/friends)]
    
    %% Recipe Sharing Flow
    C --> RECIPE_DETAIL[recipe_detail_view.dart<br/>Recept-detaljvy]
    RECIPE_DETAIL --> SOCIAL_SHARE[Tryck personer-ikon]
    SOCIAL_SHARE --> RECIPE_VM[social_recipe_viewmodel.dart<br/>Share with friends]
    
    RECIPE_VM --> SHARE_DIALOG[social_share_dialog.dart<br/>Välj vänner + meddelande]
    SHARE_DIALOG --> SOCIAL_SVC[social_recipe_service.dart<br/>shareRecipeToFriends()]
    
    SOCIAL_SVC --> CREATE_SHARED[shared_recipe.dart<br/>SharedRecipe.create()]
    CREATE_SHARED --> FIRESTORE_SHARED_RECIPES[(shared_recipes/{shareId})]
    FIRESTORE_SHARED_RECIPES --> SHARE_NOTIF[🔔 Vänner får notifikationer]
    
    %% Menu Sharing Flow
    C --> MENU_VIEW[veckomeny_view.dart<br/>Veckomeny]
    MENU_VIEW --> MENU_VM[menu_viewmodel.dart<br/>Menu management]
    MENU_VIEW --> MENU_SOCIAL_SHARE[Tryck personer-ikon för meny]
    MENU_SOCIAL_SHARE --> MENU_SHARE_DIALOG[menu_share_dialog.dart<br/>Dela meny med vänner]
    
    MENU_SHARE_DIALOG --> SOCIAL_SVC2[social_recipe_service.dart<br/>shareMenuToFriends()]
    SOCIAL_SVC2 --> CREATE_SHARED_MENU[shared_menu.dart<br/>SharedMenu.create()]
    CREATE_SHARED_MENU --> FIRESTORE_SHARED_MENUS[(shared_menus/{shareId})]
    FIRESTORE_SHARED_MENUS --> MENU_SHARE_NOTIF[🔔 Vänner får meny-notifikationer]
    
    %% Receiving Shared Content
    SHARE_NOTIF --> SHARED_WITH_ME[Tryck Avatar → Delat med mig]
    MENU_SHARE_NOTIF --> SHARED_WITH_ME
    
    SHARED_WITH_ME --> SHARED_VIEW[shared_with_me_view.dart<br/>Shared Content Hub]
    SHARED_VIEW --> SHARED_CONTENT_VM[shared_content_viewmodel.dart<br/>Load & manage shared content]
    
    SHARED_CONTENT_VM --> LOAD_SHARED[social_recipe_service.dart<br/>getSharedContent()]
    LOAD_SHARED --> FIRESTORE_SHARED_RECIPES
    LOAD_SHARED --> FIRESTORE_SHARED_MENUS
    
    %% Shared Content Actions
    SHARED_VIEW --> CONTENT_TABS[📋 Flikar: Recept | Menyer]
    CONTENT_TABS --> RECIPE_TAB[Recept Tab]
    CONTENT_TABS --> MENU_TAB[Menyer Tab]
    
    RECIPE_TAB --> RECIPE_ACTIONS{Recept Actions}
    MENU_TAB --> MENU_PREVIEW[menu_preview_view.dart<br/>Menu Preview]
    MENU_PREVIEW --> MENU_ACTIONS{Meny Actions}
    
    RECIPE_ACTIONS -->|Visa| VIEW_RECIPE[recipe_detail_view.dart<br/>Visa recept]
    RECIPE_ACTIONS -->|Importera| IMPORT_RECIPE[shared_content_viewmodel.dart<br/>importSharedRecipe()]
    RECIPE_ACTIONS -->|Dölja| DISMISS_RECIPE[shared_content_viewmodel.dart<br/>dismissSharedRecipe()]
    
    MENU_ACTIONS -->|Visa| MENU_PREVIEW
    MENU_ACTIONS -->|Importera| IMPORT_MENU[shared_content_viewmodel.dart<br/>importSharedMenu()]
    MENU_ACTIONS -->|Dölja| DISMISS_MENU[shared_content_viewmodel.dart<br/>dismissSharedMenu()]
    
    %% Import Actions
    IMPORT_RECIPE --> RECIPE_IMPORT[social_recipe_service.dart<br/>importSharedRecipe()]
    IMPORT_MENU --> MENU_IMPORT[social_recipe_service.dart<br/>importSharedMenu()]
    
    RECIPE_IMPORT --> ADD_TO_COLLECTION[recipe_service.dart<br/>addRecipe()]
    MENU_IMPORT --> BATCH_IMPORT[Batch import alla<br/>recept från meny]
    BATCH_IMPORT --> ADD_TO_COLLECTION
    
    ADD_TO_COLLECTION --> FIRESTORE_USER_RECIPES[(users/{userId}/recipes)]
    
    %% Dismiss Actions
    DISMISS_RECIPE --> UPDATE_DISMISSED[social_recipe_service.dart<br/>markDismissedBy()]
    DISMISS_MENU --> UPDATE_DISMISSED_MENU[social_recipe_service.dart<br/>markDismissedBy()]
    
    UPDATE_DISMISSED --> FIRESTORE_SHARED_RECIPES
    UPDATE_DISMISSED_MENU --> FIRESTORE_SHARED_MENUS
    
    %% Models & Data
    FIRESTORE_SHARED_RECIPES -.-> SHARED_RECIPE_MODEL[shared_recipe.dart<br/>Model with dismiss]
    FIRESTORE_SHARED_MENUS -.-> SHARED_MENU_MODEL[shared_menu.dart<br/>Model with dismiss]
    FIRESTORE_REQUESTS -.-> FRIEND_REQUEST_MODEL[friend_request.dart<br/>Model]
    FIRESTORE_USERS -.-> USER_PROFILE_MODEL[user_profile.dart<br/>Model]
    
    %% Dependency Injection
    ALL_SERVICES[injection.dart<br/>Service Registration] -.-> FRIENDS_VM
    ALL_SERVICES -.-> SHARED_VM
    ALL_SERVICES -.-> USER_SVC
    ALL_SERVICES -.-> FRIEND_SVC
    ALL_SERVICES -.-> SOCIAL_SVC
    
    %% Styling
    classDef userAction fill:#e1f5fe,stroke:#0277bd,stroke-width:2px
    classDef viewFile fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px
    classDef viewModelFile fill:#fff3e0,stroke:#f57f17,stroke-width:2px
    classDef serviceFile fill:#e8f5e8,stroke:#388e3c,stroke-width:2px
    classDef modelFile fill:#fce4ec,stroke:#c2185b,stroke-width:2px
    classDef database fill:#f1f8e9,stroke:#689f38,stroke-width:3px
    classDef notification fill:#ffebee,stroke:#d32f2f,stroke-width:2px
    classDef decision fill:#fff8e1,stroke:#ffa000,stroke-width:2px
    classDef injection fill:#e3f2fd,stroke:#1976d2,stroke-width:2px
    
    %% View Files
    class C,FRIENDS_VIEW,REQUEST_VIEW,SHARED_VIEW,RECIPE_DETAIL,MENU_VIEW,PROFILE_EDIT,MENU_PREVIEW viewFile
    
    %% ViewModel Files  
    class FRIENDS_VM,FRIENDS_VM2,SHARED_CONTENT_VM,RECIPE_VM,MENU_VM viewModelFile
    
    %% Service Files
    class USER_SVC,FRIEND_SVC,SOCIAL_SVC,SOCIAL_SVC2,RECIPE_IMPORT,MENU_IMPORT,LOAD_SHARED,SEARCH_USERS,BECOME_FRIENDS,REJECT_REQUEST,ADD_TO_COLLECTION serviceFile
    
    %% Model Files
    class SHARED_RECIPE_MODEL,SHARED_MENU_MODEL,FRIEND_REQUEST_MODEL,USER_PROFILE_MODEL,CREATE_SHARED,CREATE_SHARED_MENU modelFile
    
    %% Database
    class FIRESTORE_USERS,FIRESTORE_REQUESTS,FIRESTORE_SHARED_RECIPES,FIRESTORE_SHARED_MENUS,FIRESTORE_USER_RECIPES,FIRESTORE_FRIENDS,FIRESTORE_SEARCH database
    
    %% Notifications
    class RECIPIENT_NOTIF,SHARE_NOTIF,MENU_SHARE_NOTIF,BADGE,NOTIF_COUNT notification
    
    %% Decisions
    class ACCEPT_REJECT,RECIPE_ACTIONS,MENU_ACTIONS decision
    
    %% User Actions
    class FRIEND_NAV,SOCIAL_SHARE,MENU_SOCIAL_SHARE,SEND_REQUEST,SHARED_WITH_ME,AVATAR userAction
    
    %% Injection
    class ALL_SERVICES injection
📝 Kodfilernas Roller i Flödet:
🔵 Views (UI-filer):

mina_recept_view.dart - Hemskärm med notification badge
friends_list_view.dart - Vänlista och användarsökning
friend_requests_view.dart - Hantera vänskapsförfrågningar
shared_with_me_view.dart - Hub för delat innehåll
recipe_detail_view.dart - Receptdetaljer med social delning
veckomeny_view.dart - Veckomeny med meny-delning
user_profile_edit_view.dart - Profil-redigering
menu_preview_view.dart - Förhandsvisning av delade menyer

🟣 ViewModels (Presentation Logic):

friends_viewmodel.dart - Hantera vänskap UI-logik
shared_content_viewmodel.dart - Hantera delat innehåll UI-logik
social_recipe_viewmodel.dart - Social delning UI-logik
menu_viewmodel.dart - Meny UI-logik med social integration

🟢 Services (Business Logic):

user_service.dart - Användarprofilsn och sökning
friends_service.dart - Vänskapshantering och förfrågningar
social_recipe_service.dart - Delning av recept och menyer
recipe_service.dart - CRUD för recept (befintlig, utökad)

🟡 Models (Data):

user_profile.dart - Användardata
friend_request.dart - Vänskapsförfrågningar
shared_recipe.dart - Delade recept med metadata
shared_menu.dart - Delade menyer med metadata

🔶 Widgets (UI Components):

user_avatar.dart - Avatar med notification badge
social_share_dialog.dart - Dialog för att dela recept
menu_share_dialog.dart - Dialog för att dela menyer

💾 Database Collections:

users/{userId}/profile - Användarprofilsn
friend_requests/{requestId} - Vänskapsförfrågningar
shared_recipes/{shareId} - Delade recept
shared_menus/{shareId} - Delade menyer
user_profiles/{userId} - Publika profiler för sökning

Detta flöde visar exakt vilka kodfiler som används i varje steg av den sociala plattformen och hur de arbetar tillsammans för att skapa en komplett social upplevelse.

🔧 Teknisk status

✅ Fullständigt implementerad och produktionsklar
✅ Robust felhantering och offline-stöd
✅ Svenska lokaliseringar för alla texter
✅ Comprehensive analytics för att förstå hur funktionen används
✅ Performance-optimerad för smooth användarupplevelse


🎯 Sammanfattning: Den sociala delen förvandlar Butlery från en personlig receptapp till en social matplanerings-plattform där vänner hjälper varandra med vardagsmaten!

📊 Förklaring av Flödesschemat: Butlerys Sociala Platform
🎨 Färgkodning och Symboler
Flödesschemat använder olika färger för att visa vilken typ av kod som körs:

🔵 Blå (User Actions): Saker som användaren gör - klicka, trycka, navigera
🟣 Lila (Views): UI-filer som visar skärmar och knappar för användaren
🟠 Orange (ViewModels): Filer som hanterar logik mellan UI och tjänster
🟢 Grön (Services): Affärslogik-filer som gör det tunga arbetet
🔴 Rosa (Models): Datafiler som definierar hur information lagras
💚 Mörkgrön (Database): Firebase Firestore databas-samlingar
🔴 Röd (Notifications): Notifikationer och badges som visas för användaren
🟡 Gul (Decisions): Punkter där användaren eller systemet gör val
💙 Ljusblå (Injection): Central fil som kopplar samman alla tjänster


🚀 App Start & Grundläggande Flöde
main.dart → auth_service.dart → mina_recept_view.dart
Vad händer:

Appen startar (main.dart)
Kontrollerar om användaren är inloggad (auth_service.dart)
Visar hemskärmen (mina_recept_view.dart)


🔔 Notifikationssystem
friends_viewmodel.dart + shared_content_viewmodel.dart → Notification Count → Badge
Vad händer:

Två olika ViewModels räknar notifikationer:

friends_viewmodel.dart - Räknar vänskapsförfrågningar
shared_content_viewmodel.dart - Räknar nya delade recept/menyer


Dessa summeras till en röd siffra på avataren
När användaren ser "5" på avataren kan det betyda: 2 vänskapsförfrågningar + 3 nya delade recept


👤 Profilhantering
user_profile_edit_view.dart → user_service.dart → Firebase users/{userId}/profile
Vad händer:

Användaren trycker "Redigera profil"
user_profile_edit_view.dart visar formulär för namn, bild, etc.
user_service.dart sparar ändringarna
Data lagras i Firebase under users/{userId}/profile


👥 Vänskapsflödet
Steg 1: Söka vänner
friends_list_view.dart → friends_viewmodel.dart → user_service.dart → Firebase user_profiles
Vad händer:

Användaren skriver ett namn i sökrutan
friends_list_view.dart visar sökgränssnittet
friends_viewmodel.dart hanterar söklogiken
user_service.dart söker i databasen
Resultaten hämtas från Firebase user_profiles samlingen (optimerad för sökning)

Steg 2: Skicka vänskapsförfrågan
Skicka förfrågan → friends_service.dart → Firebase friend_requests → Mottagare får notifikation
Vad händer:

Användaren trycker "Lägg till vän"
friends_service.dart skapar en förfrågan
Förfrågan sparas i Firebase friend_requests samlingen
Mottagaren får automatiskt en notifikation (röd siffra på avatar)

Steg 3: Hantera förfrågningar
friend_requests_view.dart → friends_viewmodel.dart med real user data → Acceptera/Avböj
Vad händer:

Mottagaren öppnar friend_requests_view.dart
friends_viewmodel.dart laddar verkliga användaruppgifter (namn, bild)
Mottagaren ser vem som skickat förfrågan och kan acceptera/avböja
Om accepterad: friends_service.dart skapar vänskap i Firebase users/{userId}/friends


🍳 Receptdelning
Steg 1: Dela ett recept
recipe_detail_view.dart → social_share_dialog.dart → social_recipe_service.dart → Firebase shared_recipes
Vad händer:

Användaren öppnar ett recept (recipe_detail_view.dart)
Trycker på "personer-ikonen" för social delning
social_share_dialog.dart öppnas med lista på vänner
Användaren väljer vänner och skriver meddelande
social_recipe_service.dart skapar delningen
Data sparas i Firebase shared_recipes med metadata om vem som delade vad

Steg 2: Skapa delad data
shared_recipe.dart model → Firebase shared_recipes → Vänner får notifikationer
Vad händer:

shared_recipe.dart modellen skapar strukturerad data
Inkluderar: original recept + vem som delade + meddelande + mottagarlista
Sparas i Firebase
Alla mottagare får automatiskt notifikationer


📅 Menydelning
Hela meny-delning
veckomeny_view.dart → menu_share_dialog.dart → social_recipe_service.dart → Firebase shared_menus
Vad händer:

Användaren har skapat en veckomeny
Trycker "personer-ikonen" för meny-delning
menu_share_dialog.dart visar meny-förhandsvisning + vän-val
social_recipe_service.dart skapar meny-delning
shared_menu.dart modellen lagrar HELA menyn med alla recept organiserade per dag
Sparas i Firebase shared_menus


📥 Ta emot delat innehåll
Huvudhub för delningar
shared_with_me_view.dart → shared_content_viewmodel.dart → social_recipe_service.dart → Firebase data
Vad händer:

Användaren trycker "Delat med mig" från avatar-menyn
shared_with_me_view.dart visar hub med två flikar: Recept | Menyer
shared_content_viewmodel.dart hanterar filtrering och sökning
social_recipe_service.dart hämtar data från Firebase
Visar allt som delats med användaren (minus det som dölts)

Hantera mottaget innehåll
För recept:
Recept Tab → 3 val: Visa | Importera | Dölja
För menyer:
Meny Tab → menu_preview_view.dart → 3 val: Visa | Importera | Dölja
Vad händer:

Visa: Öppnar receptet/menyn för att titta (ingen permanent förändring)
Importera: Kopierar receptet/alla recept i menyn till användarens egen samling
Dölja: Markerar som "dismissed" så det försvinner från listan (påverkar inte andra)


💾 Import-processen
Recept-import
importSharedRecipe() → recipe_service.dart → Firebase users/{userId}/recipes
Meny-import (batch)
importSharedMenu() → Batch import alla recept → recipe_service.dart → Firebase users/{userId}/recipes
Vad händer:

Användaren väljer "Importera"
Systemet kopierar receptet/alla recept från menyn
Lägger till i användarens egen recept-samling
Original-delningen påverkas inte
Användaren har nu en egen kopia att ändra som de vill


❌ Dölja-funktionen
dismissSharedRecipe/Menu() → Uppdatera "dismissedByUserIds" → Firebase
Vad händer:

Användaren väljer "Dölja"
Systemet lägger till användarens ID i "dismissedByUserIds" listan
Nästa gång data laddas filtreras denna delning bort för just denna användare
Andra som fått samma delning påverkas inte
Användaren kan "ångra" och få tillbaka delningen om de vill


🔧 Tekniska detaljer
Dependency Injection
injection.dart → Alla services registreras → ViewModels kan använda services
Varför detta är viktigt:

Alla services (affärslogik) registreras centralt
ViewModels (UI-logik) kan använda services utan att veta hur de fungerar
Gör koden testbar och modulär

Databas-optimering
displayNameLower index → Snabb sökning av användare
30min cache → Snabbare laddning av användaruppgifter
Batch operations → Effektiv import av menyer
Performance-tricks:

Användarnamn lagras både normalt och i små bokstäver för snabb sökning
Användaruppgifter cachas i 30 minuter för att minska databasfrågor
Meny-import görs i batchar istället för ett recept i taget


🔄 Hela flödet i praktiken
Exempel: Maria delar sin veckomeny med Anna

Maria: Skapar veckomeny i veckomeny_view.dart
Maria: Trycker personer-ikon → menu_share_dialog.dart öppnas
Maria: Väljer Anna från vänlista, skriver "Här är min vintermeny!"
System: social_recipe_service.dart skapar shared_menu.dart objekt
System: Sparar i Firebase shared_menus med hela menyn + metadata
Anna: Får notifikation (röd siffra på avatar)
Anna: Trycker avatar → "Delat med mig" → shared_with_me_view.dart
Anna: Ser "Menyer" tab med Marias meny
Anna: Trycker på menyn → menu_preview_view.dart visar alla recept per dag
Anna: Väljer "Importera hela menyn"
System: social_recipe_service.dart kopierar alla 7 recept till Anna
System: recipe_service.dart lägger till i Anna's users/{annaId}/recipes
Anna: Har nu alla Marias recept i sin egen samling

Resultat: Anna sparade tid på veckoplanering och Maria hjälpte en vän - perfekt social funktion! 🎉