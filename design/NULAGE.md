# Nuläge

Den här filen säger var arbetet står **i dag**. Den är kort med avsikt: om du
läser äldre sessioner, arbetsplaner eller granskningsanteckningar först får du
en föråldrad bild.

Senast uppdaterad: 2026-09-23.

---

## De tre frysningarna

Underlaget är fryst i tre skilda lager. De räknar aldrig om varandra.

| Lager | Vad det binder | Commit | Artefakt |
|---|---|---|---|
| **Krav** (Block 287) | skärmkorpusens element och de 772 produktkraven | `04f7f59` | `fas2/block287k-frysning.json` |
| **Beteende** (Block 288) | 82 tillämpliga vytillstånd, 81 krävda övergångar i åtta flöden, 33 krävda interaktionstillstånd | `b5fcf5c` | `fas2/block288-uxfrysning.json` |
| **Leverans** (Block 289) | tokens, mappning, generatorer och de genererade Flutter-filerna, plus kontrastkontraktet | `2c5da67` | `fas2/block289-visuell-leverans.json` |

Alla tre reproducerar byteidentiskt ur en ren utcheckning. Kör proven med:

```
node tools/block287/frysningsprov.mjs --root=<rot> --bygge=<byggkatalog>
node tools/block288/uxprov.mjs --root=<rot>
node tools/block289/visuellprov.mjs --root=<rot>
```

Noll öppna designbeslut. De fyra som fanns är avgjorda och nedtecknade i
`fas2/ux-beslut.json` — en överstyrd rad raderas aldrig, den behåller sin
tidigare status och pekar ut sitt beslut.

---

## Migrationen till appen

Appen ligger i ett **eget repo**, `C:\Butlery\butlery`. Den är byggd *mot*
ritningen, inte *ur* den; enda avsedda kopplingen är de genererade temafilerna.

Migrationen är **82 enheter i 8 paket**, mekaniskt härledda.

| Paket | Innehåll | Status |
|---|---|---|
| 1 | grunden: färg, typografi, typsnitt, mått | **klar och på main** (PR #259, `22bb399`) |
| 2 | komponenter: fel, laddning, sidhuvud, radie, fokus, avstängt, nedtryckt | **klar och på main** (PR #261) |
| 3 | interaktionsmönster: ångra, offline, konflikt | ångra klar och på main (PR #261); offline och konflikt ej påbörjade |
| 4 | vyerna tar in det nya | ej påbörjad |
| 5 | tillstånd: 22 ändrade + 7 nya | ej påbörjad |
| 6 | flödena | ej påbörjad |
| 7 | bortstädning av gammal yta och gammal UX | ej påbörjad |
| 8 | verifiering | ej påbörjad |

Ordningen är bunden. Paket 2 börjar inte förrän paket 1 är oberoende granskat.

---

## Vad appen klarar i dag

Mätt mot den frysta beteendemodellen, i en läsande kopia av appen:

- **44 av 81** krävda flödesövergångar finns i appens källa. 37 saknas — tyngst i offline/synk (10), konto (9) och behörigheter (5).
- **75 av 82** vytillstånd har en motsvarighet i koden. Sju saknas helt.
- **Noll** av dem är bevisade att bete sig som designen kräver. Källkod kan visa att ett läge *hanteras*, inte att det gör rätt. Den bevisningen ligger i paket 8.

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
| "designsystemet är två av sju faser in" | tre frysningar klara och paket 1 av 8 committat |
| `fas2/block287-frysning.json` (utan `k`) | **ogiltigförklarad**, bygger på den gamla positionsidentiteten |

Detaljerna om Block 287 står i `fas2/BLOCK287.md`.
