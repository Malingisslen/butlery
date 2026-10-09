> **FRYST 2026-07-31 · historisk — men bär tre beslut som ska föras in i beslutslogg.md.** Underhålls inte. Får inte citeras som gällande. Se `fas0/kallauktoritetsregister.md`.

# Butlery · Vad vi missat — och planen för att föra in det

Version 1.0 · 2026-07-29. Underlag: hela `lib/views/` (183 filer) och hela `lib/widgets/` (322 filer) i `Malingisslen/butlery@6509517` ställt mot de **248 ramar** som finns i de tio skärmfilerna.

## Slutsatsen först

Etapp 0–7 täcker appens **vyer**. Det som saknas ligger nästan uteslutande i två blinda fläckar:

1. **Tillstånd som inte bor i en vy** — underhållsläge, sessionstimeout, installationsbanner, ceremonier. De kan möta användaren i vilken vy som helst och har därför aldrig hamnat i en vylista.
2. **Hela produktfunktioner som bara finns som widgets** — knuffar, aktivitetsflödet, chattomröstningar, emoji-reaktioner, feedbackrapportering, inköpsmallar, röstassistans. `migration-gap.md` § B räknade vyer, inte widgetkataloger, så de här föll ur.

Utöver det finns **tre fall där vår egen spec säger något som koden motsäger** (flervalets omfattning, emoji, gestbanners) och **fyra vyer som helt enkelt glömdes** (hushållsstorlek, communityriktlinjer, delat-per-vän, chattens gruppinfo).

**34 luckor. Uppskattat 46 ramar.** Ingen av dem är en omritning — allt ärver mönster som redan finns.

---

## A · Globala tillstånd (6 ramar)

| # | Lucka | Källa | Vad koden gör |
|---|---|---|---|
| L-01 | **Underhållsläge** | `maintenance_mode_gate.dart`, `maintenance_mode_blocker.dart` | En blockerande helskärm kan läggas över hela appen från fjärrkonfiguration. Ingen ram, inget krav, ingen copy. |
| L-02 | **Sessionstimeout-varning** | `session_timeout_warning_dialog.dart` | Nedräkning innan utloggning. **Ingen koppling till offlinekön** — timeout kan alltså göra exakt det `#utloggningko` byggdes för att förhindra. |
| L-03 | **PWA-installationsbanner** | `pwa_install_banner.dart` | Webbanvändare möter en banner ovanpå huvudvyn. |
| L-04 | **Svep-tips** | `swipe_hint_banner.dart` | Lär ut en gest. Krockar med K-05: gesten ska ha ersatts av en synlig kontroll. |
| L-05 | **Första receptets ceremoni** | `first_recipe_celebration_overlay.dart` | Overlay efter första sparade receptet. Rörelsereferensen finns i `Butlery ceremonier rorelsereferens.dc.html`; ramen finns inte. |

**UX-hållning.** Underhållsläget får den enda helskärm i Butlery som inte är en vy: ink-bakgrund, wordmark, en mening om varför, klocktid för återkomst, ingen spinner (K-06), och den **skiljs från offline i ord, inte i färg** — `#hemoffline` säger *du* är borta, den här säger *vi* är borta. Timeoutvarningen ärver `#utloggningko` rakt av: har kön osparade ändringar räknar dialogen upp dem med namn och erbjuder *Fortsätt* som primär; är kön tom är det en vanlig bekräftelse. Installationsbannern och svep-tipset är samma komponentklass — engångsupplysning, avvisbar, aldrig ovanpå primärhandlingen — och svep-tipset bör hellre **strykas** än ritas.

---

## B · Feedback och rapportering (5 ramar)

| # | Lucka | Källa | Vad koden gör |
|---|---|---|---|
| L-06 | **Feedback-FAB + formulär** | `feedback_fab.dart`, `feedback_form_dialog.dart` | Skickar **skärmdump, enhetsinfo, e-post och de 20 senaste skärmarna** användaren besökt. |
| L-07 | **Admin feedback-inkorg** | `feedback_inbox_view.dart` | Triage i tre lägen, filterrad, lightbox, *Kopiera för Claude*. |
| L-08 | **Anmäl innehåll** | `report_content_dialog.dart` | Användarsidan av `#minaanmalningar`. |
| L-09 | **Blockerade användare** | `blocked_users_section.dart` | Lista + avblockering. Säger inget om vad blockering gör med redan delat innehåll. |

**Det som gör L-06 mer än en ritning:** skärmdumpen kan innehålla familjemedlemmars namn och allergener — art. 9-uppgifter — och skärmvägen är ett beteendespår. Ramen måste därför visa **vad som följer med**, med skärmdumpen som en avbockningsbar rad och en förhandsvisning, inte som tyst bilaga. Det är samma princip som `#familjmedlemsamtycke` redan bär. L-09 ärver `#vanprofildelning`s obesvarade fråga: blockering återkallar ingenting.

---

## C · Socialt som aldrig ritats (9 ramar)

| # | Lucka | Källa | Vad koden gör |
|---|---|---|---|
| L-10 | **Aktivitetsflödet** | `friends_list/feed_tab.dart` | En av fyra flikar i Vänner. Filterchips, datumrubriker, cook-snap-karusell, och *receptet är inte delat → be om det* som dialog. Noll ramar. |
| L-11 | **Aktivitetsdelningens integritet** | `user_profile_edit/privacy_section.dart` | Huvudreglage + **fyra typreglage** (kokade, delade, började laga, knuff). Samma tre-nivåfälla som notiserna (KI-12). |
| L-12 | **Knuffar** | `ping_compose_sheet.dart`, `activity_pings_feed.dart` | Hel funktion: skicka och ta emot knuffar. |
| L-13 | **Omröstning i chatt** | `poll_creation_dialog.dart`, `poll_message_widget.dart` | Skild från menyröstningen — men samma öppna frågor: ändra röst, oavgjort, utgång. |
| L-14 | **Emoji-reaktioner** | `emoji_reaction_picker.dart`, `emoji_reaction_display.dart` | Reaktioner på meddelanden. **Direkt konflikt med designsystemets emoji-regel.** |
| L-15 | **Chattens gruppinfo** | `messaging/group_detail_view.dart` | Egen vy, inte `social/group_detail`. Byt namn, lägg till, ta bort medlem, lämna — borttagningen går via en generisk raderingsdialog med fel ord (K-11). |
| L-16 | **Ägarskapsöverlåtelse** | `groups/ownership_transfer_dialog.dart` | Finns för **grupper** men inte för listor (D-07b). Asymmetrin är osynlig för användaren. |
| L-17 | **Delat per vän** | `shared_with_me/shared_recipes_by_friend_view.dart` | Filtrerad vy per delare. |

**UX-hållning.** Flödet ritas som den fjärde fliken det är, med `#hemtom`s tomma läge i två varianter (inga vänner → uppmaning; vänner men tyst → ingen uppmaning) — koden skiljer dem redan. Typreglagen i L-11 ritas som notismatrisen i `#notisertyp`: den dolda nivån görs synlig, annars är den en fälla vi redan dokumenterat en gång. L-13 **ärver MR-01…MR-09 istället för att uppfinna om** — en oavgjord chattomröstning får inte försvinna som menyrösten gör. L-14 är ett beslut, inte en ritning: antingen skrivs emoji-regeln om för reaktioner (de är användarens ord, inte vår typografi) eller så ersätts de av en namngiven reaktionsuppsättning. **Jag lutar mot det första** — att förbjuda emoji i en chatt är att designa mot mediet.

---

## D · Flerval — specens fyra år gamla hål (4 ramar)

K-05 står fortfarande som *specen saknar svar*. Vi har ritat flervalet i **inköp** och **skafferi**; kvar är tre ytor och själva ingången.

| # | Lucka | Källa | Vad koden gör |
|---|---|---|---|
| L-18 | **Receptlistans flerval** | `mina_recept/selection_app_bar.dart` | **Sex samlade handlingar:** dela, tagga, lägg i menyn, exportera, radera, markera alla. Överskott vid meny-tillägg spiller till nästa vecka via en snackbar-åtgärd, en gång. |
| L-19 | **Taggarnas flerval** | `personal_tags/personal_tag_bulk_dialogs.dart` | Sammanslagning (välj vilken tagg som blir kvar) och bulkradering — **båda utan Ångra**. |
| L-20 | **Gruppmedlemmars flerval** | `group_members_list.dart`, `add_members_to_group_view.dart` | Fjärde ytan i BUT-948. |
| L-21 | **Ingången till flerval** | — | Den fråga K-05 faktiskt ställer. Fortfarande obesvarad. |

**Detta korrigerar ett av våra egna påståenden.** SK-17 skrev att radera är den enda samlade handlingen — det gällde `selection_bulk_bar.dart` i inköpslistan, inte receptlistan, som har sex. Ramen måste bära sex handlingar utan att bli ett verktygsfält: **tre i baren, resten i en kebab**, ordnade efter hur ofta de används och hur svåra de är att ångra. Radera sist och ensam. Sammanslagningen i L-19 behöver Ångra eller en riktig förhandsvisning av vad som slås samman — den är i dag oåterkallelig och beskrivs med en siffra.

---

## E · Inställningar och juridik (5 ramar)

| # | Lucka | Källa | Vad koden gör |
|---|---|---|---|
| L-22 | **Hushållsstorlek** | `settings/household_size_view.dart` | MINIMAL tog frågan ur guiden — **vyn finns kvar**. Steppare där tomt = *receptets standard*, spara-knapp, exit-vakt med tre val. |
| L-23 | **Communityriktlinjer + juridisk fot** | `legal/community_guidelines_view.dart`, `legal_contact_footer.dart` | Tredje juridiska dokumentet, **samma markdown-som-källkod-fel** som KI-26. |
| L-24 | **Sök- och filterpanelen** | `search_filter_widget.dart` + 8 filer | Frisök, snabbfilter, taggfilter, träffstatistik. `#sortera` täcker bara sorteringen. |
| L-25 | **Portionsskalning** | `input/portion_scaler.dart` | Där hushållsstorleken möter receptet. Ritad ingenstans. |

**UX-hållning.** L-22 är den enda som riskerar att bli fel: efter B-39 finns *två* ställen som äger portionsstandarden (den här vyn och profilredigeringen) — samma sparväg i koden, men två sanningar för användaren. Ramen ska visa vilken den är, och hellre **peka från profilen hit** än att duplicera kontrollen. L-23 löses av samma markdownvisare KI-26 kräver — en fix, tre dokument.

---

## F · Admin utöver mönstret (3 ramar)

M-07 säger att teamet får bygga adminvyer ur mönstret. Tre av dem har dock innehåll mönstret inte beskriver: **driftloggen** (L-26, tre kolumner, medvetet gles före lansering), **parsningsdetaljerna** (L-27, per domän med *fältet som oftast blir fel*), och **mätflikarna** (L-28, `metric_renderer` + diagram + drilldown + CSV-export). Tabellmönstret från `#adminskal` räcker för de två första; diagrammen behöver en egen regel för hur en mätserie ritas i vår palett — den finns inte.

---

## G · Komponenter utan hemvist (8 ramar)

| # | Lucka | Källa |
|---|---|---|
| L-29 | **Bilduppladdning med förlopp** — flera bilder, primärmärkning, delvis misslyckad uppladdning | `image/upload_progress_widgets.dart`, `image_gallery_widget.dart` |
| L-30 | **Dubblettsammanslagning** — `#impdubblett` visar upptäckten, inte sammanslagningen | `recipe/duplicate_merge_sheet.dart` |
| L-31 | **Relaterade recept** | `related_recipes_editor.dart`, `related_recipes_picker_dialog.dart` |
| L-32 | **Inköpsmallar** | `shopping/shopping_template_browser.dart` |
| L-33 | **Röstassistans i matlagningsläget** — ett annat behov än röstimporten (som **inte** är struken: röst är en av nio `ImportSource`, ritad i `#imp1kalla`); det här är händerna-i-degen | `cooking/voice_assist_button.dart`, `voice_heard_chip.dart` |
| L-34 | **Säsongshero på hem** + slot-väljaren som flervalet öppnar | `home/seasonal_hero_header.dart`, `dialogs/slot_picker_dialog.dart` |

---

## Tre beslut jag behöver innan jag ritar

1. **Emoji-reaktioner (L-14).** Skriv om emoji-regeln för användarinnehåll, eller ersätt reaktionerna? Mitt svar: skriv om regeln, begränsa till reaktioner i chatt och kommentarer.
2. **Fyra strykningskandidater** — knuffar (L-12), chattomröstningar (L-13), inköpsmallar (L-32), svep-tips (L-04). Samma resonemang som förra gången: knuffar och chattomröstningar överlappar det menyröstningen och chatten redan gör. Stryks alla fyra sparas ~9 ramar och lika mycket kod.
3. **Röstassistans (L-33).** Röstimporten finns kvar som källa — men röststyrning *i matlagningsläget* är den enda ytan där händerna faktiskt är upptagna. Behåll? *(Formuleringen sa ursprungligen att röstimporten var struken. Det var fel och rättat 2026-07-30.)*

**Uppdragsgivarens svar (2026-07-30) — och det ändrar två av standardsvaren:** emoji-regeln skrivs om (B-44), **knuffar (L-12) och svep-tipset (L-04) behålls och ska ritas** (B-47, emot designens råd — svep-tipset kräver en regel för när det slutar visas), chattomröstningar och inköpsmallar behålls, röstassistansen behålls. Svep-tipsets strykning är ritad som beslutsram `#globsvep`.

Ursprunglig formulering: skriv om emoji-regeln, stryk knuffar och svep-tips, behåll chattomröstningar och inköpsmallar, behåll röstassistansen.

---

## Etapp 9 · planen

Ordnad efter **risk för användaren**, inte efter filstorlek. Varje bunt följer den löpande regeln från `arbetsplan.md`: källan läses först, produktregeln skrivs före ramen, evidensmatrisen får en rad, `verify.mjs` grön innan bunten stängs.

| Bunt | Innehåll | Ramar | Varför denna ordning |
|---|---|---|---|
| **9.1** ✅ | Globala tillstånd (A) + sessionstimeout kopplad till offlinekön — **ritad 2026-07-29**, `Butlery Skarmar v12 etapp 9 globala tillstand och flerval.dc.html`, krav GL-01…GL-12, § 16 | 6 | Kan möta användaren mitt i vad som helst, och L-02 är i dag en tyst dataförlust vi själva har regeln mot |
| **9.2** ✅ | Flervalet (D) — inklusive K-05:s ingång — **ritad 2026-07-29**, krav FL-01…FL-14 + I-29, § 17 | 5 | Stänger specens äldsta hål och rättar vårt eget SK-17-påstående |
| **9.3** ✅ | Feedback och rapportering (B) — **ritad 2026-07-29**, krav FB-01…FB-13, § 18 | 5 | L-06 skickar art. 9-uppgifter utan upplysning; det är den enda luckan med rättslig sida |
| **9.4** ✅ | Socialt (C) — **ritad 2026-07-29**, 9 ramar (knuffar strukna, delat-per-vän tillagd), krav SO-01…SO-18, § 19 | 9 | Störst yta, men ingen av dem blockerar en annan |
| **9.5** ✅ | Inställningar, juridik, admin, komponenter (E, F, G) — **ritad 2026-07-29**, krav KO-01…KO-23, § 20 | 16 | Ärver mönster; kan gå parallellt med kodarbetet i etapp 8 |
| | **Totalt ritat** | **41 ramar i två filer** — 9.1–9.3 i `Butlery Skarmar v12 etapp 9 globala tillstand och flerval.dc.html`, 9.4–9.5 i `Butlery Skarmar v12 etapp 9 socialt och komponenter.dc.html` | |

**Ny fil, inte en elfte.** 9.1–9.3 läggs i `Butlery Skarmar v12 etapp 9 globala tillstand och flerval.dc.html`; 9.4–9.5 i `Butlery Skarmar v12 etapp 9 socialt och komponenter.dc.html`. Två filer, inte sex — filsplitten kostade oss fyra döda länkar senast (T-14…T-17).

**Mekaniken som måste följa med, annars går verify-kedjan sönder som förra gången:** båda filerna in i `tools/gen-counts.mjs`, `tools/lint-core.mjs` **och** `tools/gen-icons.mjs` (den glömdes två gånger), ram-id prefixade `glob*`, `fler*`, `fb*`, `soc*`, `komp*` så de inte kolliderar med befintliga (sju dubbletter senast), nya krav som `L-01…L-34` i `evidensmatris.md` med `Skärmbevis` mot de filer som faktiskt lästs, och nya avsnitt i `produktregler.md`: § 16 globala tillstånd, § 17 flerval, § 18 feedback och rapportering, § 19 aktivitet och knuffar.

**Vad planen inte gör.** Den ritar inte om något befintligt, och den rör inte `tokens.json` — ingen av de 34 luckorna kräver en ny token. Om diagrammen i L-28 behöver en serieskala blir det den enda tokenändringen, och den tas som ett eget beslut.
