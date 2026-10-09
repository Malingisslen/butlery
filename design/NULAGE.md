# Nuläge

Den här filen säger var arbetet står **i dag**. Den är kort med avsikt: om du
läser äldre sessioner, arbetsplaner eller granskningsanteckningar först får du
en föråldrad bild.

Senast uppdaterad: 2026-10-09.

---

## De tre frysningarna

Underlaget är fryst i tre skilda lager. De räknar aldrig om varandra.

| Lager | Vad det binder | Commit | Artefakt |
|---|---|---|---|
| **Krav** (Block 287) | skärmkorpusens element och de 772 produktkraven | `04f7f59` | `fas2/block287k-frysning.json` |
| **Beteende** (Block 288) | 82 tillämpliga vytillstånd, 81 krävda övergångar i åtta flöden, 33 krävda interaktionstillstånd | `b5fcf5c` | `fas2/block288-uxfrysning.json` |
| **Leverans** (Block 289) | tokens, mappning, generatorer och de genererade Flutter-filerna, plus kontrastkontraktet | fryses om med varje leverans till appen; gällande bindning står i artefakten | `fas2/block289-visuell-leverans.json` |

Alla tre reproducerar byteidentiskt ur en ren utcheckning. Kör proven med:

```
node tools/block287/frysningsprov.mjs --root=<rot> --bygge=<byggkatalog>
node tools/block288/uxprov.mjs --root=<rot>
node tools/block289/visuellprov.mjs --root=<rot>
```

Malins 20 produktbeslut från 2026-09-23 ligger i `fas2/produktbeslut-2026-09-23.json` och styr paket 3–8. Senare beslutsrundor ligger i `fas2/produktbeslut-<datum>.json`, en fil per runda; den senaste är runda 8 (2026-10-05). Det som skjuts upp ligger i Linear.

UX-besluten i Block 288 är avgjorda och nedtecknade i `fas2/ux-beslut.json`
— en överstyrd rad raderas aldrig, den behåller sin tidigare status och pekar
ut sitt beslut. Ett öppet designbeslut: om Block 287 ska frysas om för att
rita mörka varianter av reglage, rullningslist och radio i komponentarket
(BUT-2252). Komponentarket hör till skärmkorpusen, som är orörd sedan
frysningen.

---

## Migrationen till appen

Designsystemet ligger sedan 2026-10-09 i **appens repo**, i mappen `design/`
(BUT-2202), med hela historiken från `Malingisslen/butlery-design-system`.
Appen är byggd *mot* ritningen, inte *ur* den; de avsedda kopplingarna är
temafilerna, som `tools/design_theme.dart` i appen skriver ur generatorerna
här, och ikonmastrarna i `design/assets/icons/`, som appen läser direkt. Proven körs
i appens CI-flöde *Design system*.

Migrationen är **82 enheter i 8 paket**, mekaniskt härledda.

| Paket | Innehåll | Status |
|---|---|---|
| 1 | grunden: färg, typografi, typsnitt, mått | **klar och på main** (PR #259, `22bb399`) |
| 2 | komponenter: fel, laddning, sidhuvud, radie, fokus, avstängt, nedtryckt | **klar och på main** (PR #261) |
| 3 | interaktionsmönster: ångra, offline, konflikt | **klar och på main** (PR #261 ångra, PR #262 offline, konflikt, kvitto) |
| 4 | vyerna tar in det nya | **klar och på main** (PR #263) |
| 5 | tillstånd: 22 ändrade + 7 nya | **klar och på main** (PR #264, rättad i #265) |
| 6 | flödena | **klar och på main** (PR #269) — tvåstegsverifiering byggd men dold (BUT-2142); offlinekön byggd men inte inkopplad (BUT-2162); regler måste driftsättas (BUT-2164) |
| 7 | bortstädning av gammal yta och gammal UX | **klar och på main** (PR #270) — inkl. typografi, mått, radier och ikoner (Q7-02 = B); 392 ikonanvändningar väntar på ritade glyfer (BUT-2166) |
| 8 | verifiering | **klar och på main** (PR #274, `7c2faf8`) — varje känd brist har en biljett i Linear (BUT-2140…2199); Linux-jämförelsebilder av nyckelvyerna jämförs i CI |

Ordningen är bunden. Paket 2 börjar inte förrän paket 1 är oberoende granskat.

---

## Vad appen klarar i dag

Räknat i appen av `tools/design_migration_census.dart`; hela listan står i
appens `docs/design-migration/census.md` (genereras, redigeras aldrig för hand).

Talen nedan är censusen på appens main 2026-10-05 (`ea4b867`).

- **Paket 8 klart** (Q8-01 = A): testerna är gröna och varje känd brist har en registrerad biljett. Ingen brist saknar biljett.
- **Migrationen är inte klar:** 63 kända brister (flödesövergångar 31, tillgänglighet 12, interaktionskontroller 10, kontrast 5, interaktion 5) och 393 ikonanvändningar utan ritad glyf (BUT-2166). De fem kontrastbristerna är dataskalans par, som designrepot strök 2026-10-05 (BUT-2191); de försvinner när appen vendrar om tokens.
- **50 av 81** flödesövergångar är testade. 11 är halvfärdiga, 15 är byggda men går inte att nå (bland annat tvåstegsverifiering BUT-2142, offlinekö BUT-2162, realtidssynk BUT-2151) och 5 saknas.
- **53 av 53** rent visuella vytillstånd klarar både ljust och mörkt läge.
- Migrationen är klar först när listorna över kända brister är tomma.

---

## Regler som gäller framåt

- **En kanonisk färgkälla.** `lib/theme/app_colors.dart` och
  `app_colors_dark.dart` i appen är genererade — redigera dem aldrig för hand.
  `ButleryColors` är en kompatibilitetsyta utan egna värden och pensioneras i
  paket 7. De enda färger appen äger själv är fyra dekorativa kategorifärger.
- **Ordningen är alltid** källbevis → semantisk klass → krav. Aldrig tvärtom.
- **Identitet kommer aldrig ur** position, radnummer, synlig text, färg,
  geometri, valt värde eller tillstånd.
- **Produktskrivning i appen** sker paketvis och kräver ett uttryckligt
  godkännande per paket.

---

## Vanliga missuppfattningar

| Påstående man kan stöta på | Läget |
|---|---|
| "det tokeniserade sökfältet är oavgjort" | avgjort i Block 286: sammansatt visuellt läge, inget eget tillstånd |
| "fas 2-mätningen behöver granskas" | passerad; Block 287–289 är frysta ovanpå den |
| "designsystemet är två av sju faser in" | tre frysningar klara och alla åtta paket på appens main |
| `fas2/block287-frysning.json` (utan `k`) | **ogiltigförklarad**, bygger på den gamla positionsidentiteten |

Detaljerna om Block 287 står i `fas2/BLOCK287.md`.
