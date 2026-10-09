# `leverans/` — ZIP-rotlagret, versionshanterat

**Den här katalogen är leveransens yttre lager.** Varje fil här motsvarar exakt
en `zip:/`-post i manifestet: `leverans/<sökväg>` blir `zip:/<sökväg>` i den
byggda leveransen. Ingen mappningsfil behövs — spegling är hela modellen.

## Varför den finns

Fram till F1-U01 låg de nio filerna **utanför Git**, i en katalog på
utvecklarmaskinen. Bevispaketet för `a81b40a` visade vad det kostade:

- en färsk klon kunde köra hela kedjan men **inte bygga den verifierade
  leveransen**,
- GitHub Actions kunde bli grönt utan att någonsin ha sett leveransytan
  (`delivery`-läget kördes aldrig i CI),
- och tre dokument — bland dem **styrdokumentet, projektets normativa
  styrningskälla** — ändrades utan versionshistorik.

Beslutet att skjuta detta till före Fas 2 är därför återtaget. Allt som krävs
för att bygga leveransen är nu spårat i Git.

## Vad som ligger här

| Fil | Roll | Auktoritet |
|---|---|---|
| `Butlery styrdokument modulart designsystem.dc.html` | **Normativ** för styrning, fasmodell och grindar | domänen `governance` |
| `Butlery Fas 0 leverans.dc.html` · `Butlery Fas 1 leverans.dc.html` | Leveransbrev — vad som gjordes och vad körningen förväntas ge | ingen |
| `Butlery granskning och implementeringsplan.dc.html` | Historiskt underlag, `superseded` av styrdokumentet | ingen |
| `uploads/Butlery-arbetsorder-modulart-designsystem.md` | Historiskt underlag, `superseded` av styrdokumentet | ingen |
| `fas0/DELIVERY` | **Leveransmarkören.** Utan den finns inget `delivery`-läge | ingen |
| `fas0/LAS-MIG.md` | Läsanvisning i leveransroten | ingen |
| `support.js` | Dokumentruntime för de fyra rotdokumenten — **senare bygge** än reporotens | `runtimeInstances` |
| `.thumbnail` | Förhandsbild, se kontraktet nedan | ingen |

## Kontraktet för `.thumbnail`

`.thumbnail` är en **WebP-förhandsbild** (`RIFF … WEBP`, 639×387 i leveransroten,
400×383 i reporoten) som dokumentverktyget skriver bredvid ett `.dc.html`-paket.

**Den genereras inte av den här kedjan och kan inte genereras av den** — vi har
ingen renderare för `.dc.html`. Den är därför ett **spårat binärt indata**, inte
en genererad artefakt:

- den ligger i Git och har en historik som varje annan fil,
- den är manifestdeklarerad och hashad i båda ytorna,
- den bär **ingen auktoritet** och styr ingenting,
- den får bytas ut när dokumentverktyget skriver en ny — men bara som en
  synlig commit, aldrig genom att ärvas ur en gammal ZIP.

Om `.thumbnail` någon gång ska genereras av kedjan kräver det en renderare, och
då flyttas den till `generatedArtifacts`. Till dess är det här kontraktet dess
enda motivering, och T-20 kräver att den står i `packagedBinaries` i
`source-authority.json`.

## Bygga leveransen

```
node tools/build-delivery.mjs --out=<katalog>
```

Verktyget är versionshanterat och är den **enda** officiella vägen. Det
skriver ZIP-rotlagret från den här katalogen och reporoten från repot, i den
ordningen, och vägrar bygga om något saknas. Det ersätter det externa
`sync-delivery.sh`, som inte låg i Git.
