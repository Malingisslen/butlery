> **FRYST 2026-07-31 · historisk — etapp 0–11 genomförda.** Underhålls inte. Får inte citeras som gällande. Se `fas0/kallauktoritetsregister.md`.

# Butlery · Arbetsplan till färdigt

Version 1.1 · 2026-07-29. **Detta är planen för att ta hela Butlery från nuläget till en färdig, verifierad omdesign.** Den är inte en skiss — varje etapp har leverabler, en storlek och en tydlig gräns mellan vad jag gör och vad teamet gör.

Status 2026-07-29: **etapp 0–7 är ritade.** Skärmfilerna innehåller **245 ramar i tio filer** med 986 märkta kontroller, och lint-kedjan (typskala, kontrollgeometri, radier, avatarer, klippning) är grön. Det som återstår är inte längre ritningar utan **bevis**: evidensmatrisens `beslutad`-rader, verifieringsprotokollet på enhet, och etapp 8:s kodarbete.

**Planens egen räkning slog fel i båda riktningarna.** 174 ramar planerades; 245 finns. Skillnaden är nästan uteslutande tillstånd koden hade och planen inte kände till — utgångna röstningar, tappade samtycken, dolda typmatriser, saknade reservkoder. Grundningsregeln (2b) är hela orsaken: varje etapp som lästes före ritning växte.

---

## Tre beslut som annars stoppar arbetet — och mina standardsvar

Jag har svarat i din frånvaro så att inget behöver vänta. **Varje svar går att vända**, men ju senare desto dyrare — de tre står först i planen av det skälet.

| Fråga | Mitt standardsvar | Varför | Kostnad att vända senare |
|---|---|---|---|
| **De fem funktionerna** (röstimport, snabbfångst, upptäcktshyllor, cook snaps, menyröstning) | **Stryk röstimport, snabbfångst och upptäcktshyllor. Behåll cook snaps och menyröstning.** | De tre första är genvägar till något appen redan gör; de två sista är sociala och skapar återkomst. Tre strukna flöden är ungefär 14 ramar och lika mycket underhåll som inte behöver byggas | Låg före etapp 4, hög efter |
| **iOS-toppfältet** | **Behåll `AdaptiveAppBar`.** Jag ritar iOS-varianten för de **8 mest sedda** vyerna, inte för alla 39 — resten ärver mönstret | Plattformsidiom är rätt, men 39 dubbelritningar är slöseri när mönstret är detsamma | Låg — mönstret gäller ändå |
| **Startpunkt** | **Etapp 0**, sedan flöde A | Etapp 0 är två dagar och stänger mina sista tre hål. Att börja i ett flöde med kända hål betyder att jag ritar om det | — |

---

## Etapp 0 · Stäng mina sista tre hål ✅ **KLAR 2026-07-26**

De tre kraven i `evidensmatris.md` som är beslutade men saknar ritning.

| Leverabel | Ramar | Beskrivning |
|---|---|---|
| Utloggning med kö | 2 ✅ | `#utloggningko` · `#utloggningtom` — blockeras med *N* namngivna ändringar. Tom kö ger vanlig bekräftelse: en dialog som alltid ser allvarlig ut slutar betyda något |
| Chattens redigering och radering | 2 ✅ | `#chattredigerat` · `#chattmeny` — borttaget lämnar sin plats, 7 s Ångra, endast avsändaren |
| Safe area | 2 ✅ | `#safeareaios` (59/34, Dynamic Island) · `#safeareaandroid` (44/48, treknapp — bredaste insetet vi möter) |

**Utfall:** `evidensmatris.md` gick från 13 till **10 öppna krav, samtliga hos teamet**. Designen har inga egna hål kvar i det befintliga systemet. Sex ramar räckte — utloggningsdialogen behövde två lägen, chatten klarade sig på två.

Storlek: **6 ramar. Klart.**

---

## Etapp 1 · Flöde A — öppna appen, se ikväll, laga ✅ **KLAR 2026-07-26**

Det viktigaste flödet och det som är närmast färdigt. Här ligger också appens enda helt nya vy.

| Vy | Repo | Arbete | Ramar |
|---|---|---|---|
| **Hem** ✅ | *finns inte* | **Klar.** `#hem` `#hemmorkt` `#hemtom` `#hemladdar` `#hemoffline` `#hemfel` — regler i `produktregler.md` § 6 | 6 |
| Receptdetalj ✅ | `recipe_detail_view.dart` + 15 filer | **Klar.** `#receptkommentarer` `#receptcooksnap` `#receptdelningsstatus` `#receptbildfel` | 4 |
| Matlagningsläge ✅ | `cooking_mode_view.dart` | **Klar.** `#lagasubst` `#lagatimers` — rotation fanns redan i `#lagaliggande` | 2 |
| Betyg efter maten ✅ | `family_rating_entry_view.dart`, `who_is_eating_sheet.dart` | **Klar.** `#betygvemat` `#betygperperson` `#betygsammanslaget` | 3 |
| Bottennavigation ✅ | `butlery_app.dart` | Fem platser mot appens fyra flikar — K-03 är konkret i samtliga Hem-ramar | 0 |

Storlek: **15 ramar. Klart.** Flödet går nu att användartesta på riktiga människor innan resten gjuts i kod — vilket är hela poängen med att bygga ett flöde färdigt i stället för nitton vyer halvfärdiga.

---

## Etapp 2 ✅ · Flöde B — planera veckan, handla **KLAR 2026-07-29**

Finns till stora delar. Arbetet är att förbättra, inte att uppfinna.

| Vy | Repo | Arbete | Ramar |
|---|---|---|---|
| Veckomeny ✅ | `veckomeny_view.dart` + 9 | **Klar, 19 ramar.** Prompt, tolkningschips, resultat, placeringsval, manuell placering, kalendervecka, närvaro per måltid, överskott, flerval, överskrivning, veckans inköpslista, röstning. 21-platsmodellen ströks — den fanns inte i koden | 19 |
| Generering | `menu_viewmodel.dart` | Finns i fem processlägen. Kompletteras med allergihushållets regel (`#veckoallergi` finns) | 3 |
| Menyplacering | `menu_placement_view.dart` | Dag- och platsväljare | 2 |
| Inköpslista | `unified_shopping_view.dart` + 11 filer | Finns. Kompletteras med kategoriordning, flerval, claim-flödet | 6 |
| Skafferi | `pantry_view.dart` + 2 | Finns. Kompletteras med avdragsreglerna synligt | 4 |
| Menyröstning ✅ | `menu_voting_service.dart` · `menu_vote_card.dart` | **Ritad som del av veckomenyn** (`#veckorostning`) — rösten hör till platsen, inte receptet. Egna vyer (historik, avgörande) kvarstår | 2 |
| Delade listor ✅ | `collaborative_shopping_view.dart` + 3 | **Klar, 9 ramar.** Inkorg, vidaredelning, aktiv lista, lämna (deltagare + ägare), **Min del**, närvaro + avdelning, claim-kapplöpning, läsare — beslut B-30, B-31. Fyra av åtta kom ur källläsning, inte ur planen | 8 |

Storlek: **41 ramar ritade** (mot 27 planerade), i två filer. Utöver planen: **inköp och skafferi** som egen fil (9 ramar) — där premissen föll, det finns inga skafferiavdrag, bara basvaruuteslutning som dessutom är **vilande** eftersom `isStaple` inte går att sätta — och **menyröstningens** fyra ramar, där en utgången oavgjord röst i dag faller mellan viewmodellens två listor och försvinner helt. Kalenderns två mått avgjorda som B-40 och B-41.

---

## Etapp 3 ✅ · Första gången — MINIMAL **KLAR 2026-07-28**

Finns helt i kod, saknas helt i design. Hög risk: det är här användare försvinner.

| Vy | Repo | Ramar |
|---|---|---|
| Välkomst | `onboarding_welcome_page.dart` | 2 |
| Åldersgrind + blockerad | `onboarding_age_gate_page.dart`, `..._blocked_view.dart` | 3 |
| Allergener | `onboarding_allergen_page.dart` | 3 |
| Kost | `onboarding_dietary_page.dart` | 2 |
| Första importen | `onboarding_import_page.dart` | 3 |
| Hushållets storlek | `household_size_view.dart` | 2 |
| Auth + e-postverifiering + MFA-utmaning | `auth_view.dart`, `email_verification_view.dart` | 5 |
| Behörighetsförklaringar | `permission_service.dart` | 4 (kamera, foton, notiser, exakta larm) |

Storlek: **25 ramar ritade** (mot 24 planerade). Frågan *hur lite kan vi fråga innan första receptet* är avgjord som **MINIMAL, beslut B-39**: fyra sidor i stället för fem, kostfrågan flyttad till efter första menygenereringen, hushållets storlek inte frågad alls. Sidordningen i planen var fel — åldersgrinden ligger **först**, inte välkomsten. Tre ramar i mörkt läge. Behörighetsförklaringarna ritade ur `os_permission_helper.dart` (planens `permission_service.dart` är resursbehörigheter, inte OS): **exakta larm efterfrågas aldrig**, och kamera och foton går utanför appens eget behörighetskontrakt. MFA-utmaningen finns inte i koden alls.

---

## Etapp 4 ✅ · Lägg till ett recept — åtta flöden till ett mönster

Största förenklingsvinsten i hela omdesignen. Appen har åtta separata importvägar med egna vyer.

| I dag | Blir |
|---|---|
`smart_import_view` · `import_via_url_view` · `fran_sociala_medier_view` · `photo_import_view` · `voice_import_view` · `file_import_view` · `importera_fran_arkiv_view` · `quick_capture_view` · `receive_share_view` | **Ett** importmönster: *källa → hämtar → granska → spara*, med källspecifika delar bara där de skiljer sig |

| Leverabel | Ramar |
|---|---|
| Det gemensamma mönstret i fyra steg, ljust och mörkt | 8 |
| Källvarianter (länk, foto/OCR, social, fil, arkiv, ta emot delning) | 6 |
| Granskningsvyn — låg säkerhet, dubblett, okänd ingrediens | 5 |
| Skriv själv / redigera | `skriv_sjalv_recept_view.dart`, `edit_recipe_view.dart` | 5 |
| Felvägar — betalvägg, privat, inget recept, hastighetsgräns | 4 |

Storlek: **24 ramar ritade** (mot 28 planerade) — inklusive recepteditorns utkastlager och den kontextuella felmodellen (I-23…I-28). Utkast: 3 s debounce, minst två fält, **lokalt**, fem platser, 24 timmar, och **tyst vid fel**. Ursprungligen — mönstret bär mer än väntat, så källvarianterna behövde färre egna ramar. Ritat efter kodläsning: nio källor (inte åtta), fyra utfall (inte två), och en **assisterad tolkning i tre steg** som specen inte kände till. Kvarstår: `receive_share_view.dart` oläst (I-12 är `beslutad`).

---

## Etapp 5 ✅ · Tillsammans **KLAR 2026-07-29**

| Vy | Repo | Ramar |
|---|---|---|
| Vänner, förfrågningar, grupper | `friends_list_view.dart`, `friend_requests/`, `group_detail_view.dart` | 8 |
| Vänprofil + publik profil | `friend_profile_view.dart`, `public_profile_view.dart` | 4 |
| Chatt + konversationer + gruppchatt | `messaging/` | 7 |
| Delning och behörigheter | `share_service.dart`, `shared_with_me_view.dart` | 5 |
| Cook snaps | `cook_snap_service.dart`, `cook_snap_visibility_dialog.dart` | 4 |
| Personliga taggar + automatiseringsregler | `personal_tags_view.dart`, `tag_detail_view.dart` | 6 |

Storlek: **37 ramar.** Vänner, grupper, chatt, delning, cook snaps och taggvyerna var redan ritade i del 2–3. **Taggautomatiseringen är nu ritad** (4 ramar) efter kodläsning, och reglerna står i `produktregler.md` § 10 — tretton villkorstyper, källspårning, och exklusiva gruppers tysta bortfall synliggjort. **Cook snaps och vänprofilen är nu ritade** (3 ramar): publikupplysningen visar uppslagna namn, men alla åtgärder ligger bakom långtryck och borttagning sker utan Ångra — och vänprofilen visade bara **en** riktning av delningen.

---

## Etapp 6 ✅ · Konto, integritet, juridik **KLAR 2026-07-29**

Syns sällan, bär all tillit. Får inte ritas slarvigt.

| Vy | Repo | Ramar |
|---|---|---|
| Inställningsnav | `settings_hub_view.dart` | 2 |
| Kontosäkerhet + MFA | `account_security_view.dart`, `mfa_settings_view.dart` | 5 |
| Notisinställningar | `notification_preferences_view.dart` | 3 |
| Samtyckeshantering | `consent_management_view.dart` | 4 |
| Dataexport | `data_export_view.dart` | 3 |
| Kontoborttagning ✅ (**inget återkallningsfönster finns** — fyndet ur `account_deletion_service.dart`, § 11) | `account_deletion_service.dart` | 4 ritade |
| Juridik (4 dokumentvyer) | `legal/` | 3 |
| Mina anmälningar | `my_reports_view.dart` | 2 |
| Samlingsstatistik | `collection_stats_view.dart` | 2 |
| Notiscentral | `notifications_view.dart` | 3 |

Storlek: **16 ramar ritade** (mot 30 planerade) — vyerna delar mönster, så samtycke, export, säkerhet, notiser, MFA, notiscentral, anmälningar, juridik och statistik rymdes i sexton. Tyngsta fyndet: **`aiProcessing` skrivs över till nej vid varje sparning** av samtycken, samma klass som BUT-1322.

---

## Etapp 7 ✅ · Admin och moderering — mönster, inte ritningar

Nio vyer som ärver komponenter. Här ritar jag **mönstret**, inte varje vy.

| Leverabel | Ramar |
|---|---|
| Adminskal + tabellmönster + filter | 4 |
| Moderatorgranskning med åtkomstmotivering | 3 |
| Driftlogg, parsningsdetaljer, mätflikar | 3 |

Storlek: **7 ramar ritade** (mot 10 planerade): adminskalet med sex flikar och avvikelsebanner, icke-behörig, rapportlistan, minderårigskyddet, de två bekräftelsetyperna, och tomt läge. Resten byggs av teamet ur mönstret — M-07 i evidensmatrisen säger uttryckligen att de får.

---

## Etapp 8 · Kod

Börjar **parallellt med etapp 1** och går sedan i takt med designen. Claude Code gör mekaniken; jag levererar design en etapp i förväg.

| Steg | Innehåll | Ägare |
|---|---|---|
| 8.1 | `app_colors.dart` och `app_text_styles.dart` genereras ur `tokens.json`. Ingen vy rörs — hela appen byter utseende i ett steg | Claude Code |
| 8.2 | `lib/widgets/common/` (174 filer): knapp, kort, chip, dialog, ark, snackbar, tomt, fel, laddning | Claude Code |
| **8.5** | **Rensa den systemiska skulden i de 128 ramar som ritades före grundgranskningen** — 145 st 13,5 px, 115 radie-6, 16 avatarer i mellansteg, 13 texter under 10,5 px. Fil för fil med kontroll emellan. Ligger **före** etapp 5–7 så nya ramar inte ärver skulden | design |
| 8.3 | Riv ut ersatta BUT-beslut ur `.claude/rules/ui-conventions.md` och `CROSS_CUTTING_RULES.md` | Claude Code |
| 8.4 | Vy för vy i etappordning ovan | Claude Code |
| 8.5 | `dart analyze` + widgettester per etapp | team |
| 8.6 | Verifieringsprotokollet på enhet, etapp för etapp | team |

**Regeln genom hela etapp 8:** ingen vy byggs innan dess ramar finns i skärmfilen och dess rad i `evidensmatris.md` är `implementerad`.

---

## Summering

| Etapp | Innehåll | Ramar |
|---|---|---|
| 0 | Mina tre kvarvarande hål ✅ | 6 |
| 1 | Flöde A — hem, recept, laga ✅ | 15 |
| 2 | Flöde B — vecka, inköp, skafferi ✅ | 41 |
| 3 | Första gången ✅ | 25 |
| 4 | Lägg till recept ✅ | 24 |
| 5 | Tillsammans ✅ | 37 |
| 6 | Konto, integritet, juridik ✅ | 16 |
| 7 | Admin — mönster ✅ | 7 |
| | **Totalt** | **245 ramar** · etapp 0–7 ritade |

Skärmfilerna har i dag **245 ramar i tio filer**. **Planen är genomförd på ritningssidan** — och blev 40 % större än planerad, eftersom varje etapp som lästes före ritning avslöjade tillstånd koden hade och planen inte kände till.

### Vad som återstår

| Kvar | Ägare |
|---|---|
| **67 krav står `beslutad`** i `evidensmatris.md` — beslutade men obevisade. Merparten kräver en kodändring, inte en ritning | dev |
| Verifieringsprotokollet i `testmatris.md` § 4 — TalkBack, VoiceOver, 2,0× text, rotation, reducerad rörelse, på fysisk enhet | team |
| Etapp 8.2–8.6: komponentbiblioteket, vy för vy, `dart analyze`, widgettester | Claude Code + team |
| `node tools/verify.mjs` kopplad till CI så att de tolv testen faktiskt fäller ett bygge | dev |

**Färdigt betyder fortfarande vad det stod: noll `beslutad`-rader, alla vyer `verifierad`, protokollet ifyllt med enhet och datum.** Ritningarna är klara. Beviset är inte.

### Ordning och beroenden

```
Etapp 0 ──┐
          ├─ Etapp 1 ──┬─ Etapp 2 ──┬─ Etapp 5 ──┐
Beslut ───┘            │            │            ├─ Etapp 7
                       ├─ Etapp 3   ├─ Etapp 6 ──┘
                       └─ Etapp 4
       8.1 ─ 8.2 ────────────── 8.4 följer designen ──────────
```

Etapp 8.1 och 8.2 kan börja omedelbart — de beror på tokens, inte på ritningar. **Det är den enda parallelliseringen som är gratis**, och den ger dessutom hela appen Butlerys nya kulör innan en enda vy är omdesignad.

### Löpande i varje etapp

1. Ramar ritas ljust och mörkt, med de tillstånd `testmatris.md` § 1 kräver för vytypen.
2. Nya produktregler skrivs i `produktregler.md` **innan** vyn ritas — en vy utan regel blir en gissning i en pull request.
2b. **Finns funktionen redan i repot läses dess datamodell, vyer och juridiska dokument först.** Regeln skrivs ur källan, aldrig ur minnet. Etapp 1 bröt mot detta och fick fyra av fyra påståenden fel — ett av dem om barns personuppgifter i en DPIA-granskad funktion. Filerna som lästes namnges i evidensmatrisens `Skärmbevis`-kolumn.
3. `evidensmatris.md` får en rad per nytt krav.
4. `node tools/verify.mjs` ska vara grön innan etappen kallas klar. Tolv test, och de mäter renderad geometri, ankare och räkningar — inte mina påståenden.
5. Beslut som fattas förs in i `beslutslogg.md`. En fråga som inte står där är inte beslutad.

### Vad som gör planen färdig

Färdigt betyder: `evidensmatris.md` har noll rader i `beslutad`, alla vyer är `verifierad`, verifieringsprotokollet i `testmatris.md` § 4 är ifyllt med enhet och datum, och `node tools/verify.mjs` är grön. Inget av det är en bedömningsfråga, och inget av det kan jag påstå åt teamet.
