# Butlery Academy — Onboarding-dossier

> En interaktiv introduktionskurs för dig som är ny på kod men ska bli andra utvecklare i Butlery (Flutter/Firebase) tillsammans med Claude Code. Kursspråk: svenska. Tekniska termer (ServiceLocator, ViewModel, hook, commit, repository...) lämnas på engelska, precis som i koden.

---

# DEL 1 — Claude Code & din setup

---

## Modul 1 — Vad är Claude Code & vibe coding (mental modell)

**Mål:** Efter den här modulen kan du förklara vad Claude Code är, vad "vibe coding" innebär i praktiken, och varför Butlery är byggt så att en AI gör nästan all kodning under skyddsräcken.

### Innehåll

Claude Code är en AI som sitter i din terminal och faktiskt *gör* saker i ditt projekt: läser filer, skriver kod, kör kommandon, committar. Den är inte en chattbot som bara svarar — den har verktyg och kan ta sig igenom en hel uppgift själv.

**Vibe coding** är arbetssättet runt detta: du beskriver *vad* du vill ha ("lägg till en rad i onboarding som säger att appen funkar på både dator och telefon"), och Claude tar reda på *hur* — vilka filer, vilket mönster, vilka tester. Du blir mer av en regissör än en maskinskrivare. Men — och det är hela poängen med Butlery — du regisserar inte en frilansare utan rutiner, utan en medarbetare som arbetar under ett tjockt lager av automatiska skyddsräcken.

Tänk på hela repot som **ett företag med en enda anställd, och den anställde är en AI.** Då blir alla de konstiga reglerna i `CLAUDE.md` och `.claude/rules/` begripliga: de är personalhandboken, skriven för AI:n, inte för en människa. Det är därför handboken säger saker som "logga lärdomen i `lessons.md` innan du gör något annat" — det är hur AI:n slutar göra om samma misstag.

Den återkommande rytmen (kärnan i kulturen) är en loop:

> **fråga → skriv en plan → implementera → klara review-gates → committa → pusha direkt till main**

Allt annat i kursen finns för att göra den loopen säker. Du kommer inte att jobba med feature branches eller pull requests — det här är en solo-utvecklares repo, så koden går rakt till main. "Granskningen" görs av automatiska gates och specialist-agenter, inte av en kollega.

En köks-analogi (passande för en receptapp): plan mode är att skriva receptkortet innan du börjar laga; review-gates är köksmästaren som smakar varje rätt innan den lämnar passet; `lessons.md` är den tummade anteckningsboken där du klottrar "salta inte soppan för mycket" efter att en gäst klagat — så du minns nästa gång.

### Riktiga referenser

- `C:/Butlery/butlery/CLAUDE.md` — den översta regelboken (10 Critical Rules, testfilosofi, agent-tiers)
- `C:/Butlery/butlery/CLAUDE.local.md` — privata solo-dev-regler (pusha direkt till main, expert-ton, svensk UI)
- `C:/Butlery/butlery/.claude/rules/workflow-discipline.md` — plan mode, self-improvement loop, verifiering
- `C:/Butlery/butlery/.claude/commands/sprint-execute.md` — den autonoma motorn som driver loopen

### Prompt-exempel

```
Läs CLAUDE.md och .claude/rules/ och sammanfatta för mig, på svenska och utan
jargong, de fem viktigaste reglerna jag måste känna till innan jag rör koden.
```

### Gotchas

- Reglerna i `CLAUDE.md` ser märkliga ut tills du inser att publiken är en AI, inte en människa.
- "Vibe coding" betyder inte "slarvigt" — i Butlery är det tvärtom hårt inramat av gates. Friheten ligger i *vad* du ber om, inte i att hoppa över kvalitet.
- Direkt-till-main är ett medvetet val *för det här repot* eftersom det bara finns en utvecklare. Det är inte en universell best practice.

### Prova nu

Öppna `C:/Butlery/butlery/CLAUDE.md` och leta upp avsnittet "Critical Rules". Läs regel #5 ("Plans = execute + verify") och #10 ("Honesty over completion"). Skriv en mening var om vad de skyddar mot.

### Checkpoint

**Fråga:** Varför finns det ingen pull request / feature branch i Butlery-flödet, och vad ersätter den mänskliga kodgranskningen?
**Svar:** Det är en solo-utvecklares repo, så det finns ingen andra människa att granska. Granskningen ersätts av automatiska review-gates och specialist-agenter (code-reviewer, testing-specialist m.fl.) som måste signera av innan en commit släpps igenom — koden går sedan rakt till main.

---

## Modul 2 — Komma igång (installera, öppna repot, första prompten)

**Mål:** Efter den här modulen kan du öppna Butlery-repot i Claude Code, ställa din första utforskande prompt och förstå vad miljön förväntar sig av dig.

### Innehåll

Du arbetar på **Windows** med **PowerShell** som standardskal (Bash finns också tillgängligt för POSIX-skript). Arbetskatalogen är `C:\Butlery\butlery`. Det är ett git-repo, och du jobbar på branchen `main`.

Tre saker att veta om miljön innan du skriver din första prompt:

1. **Plattform = Flutter + Firebase.** De viktigaste kommandona du kommer se är `flutter analyze` (kollar att koden kompilerar utan fel), `flutter test test/...` (kör tester) och `flutter run` (startar appen). Använd alltid framåtsnedstreck i testsökvägar.
2. **Det finns en känd Windows-fälla:** `flutter test` kan klaga "Unable to find git in your PATH" när det körs via git-bash. Lösningen finns dokumenterad i projektminnet — kör `flutter test` via en `cmd.bat` som sätter en native Windows-PATH. `analyze` och `pub get` funkar direkt; bara `flutter test` har problemet.
3. **Claude utforskar koden åt dig.** Du behöver inte läsa hela kodbasen själv. Den bästa första prompten är en där du ber Claude bygga din mentala karta.

Din allra första prompt bör vara utforskande, inte byggande. Du vill att Claude ritar kartan innan du börjar gå.

### Riktiga referenser

- `C:/Butlery/butlery/CLAUDE.md` — kommandolistan finns under "Commands"
- `C:/Butlery/butlery/lib/main.dart` — appens startpunkt (bra första fil att be Claude förklara)
- `C:/Butlery/butlery/lib/core/constants/routes.dart` — hela navigationsgrafen (appens "planritning")

### Prompt-exempel

Första utforskande prompten:
```
Jag är ny i det här repot. Ge mig en karta på svenska: vad är Butlery för app,
vilka är de fyra arkitekturlagren, och vilka är de 4 flikarna i bottennavigeringen?
Peka på de exakta filerna jag ska läsa för att förstå var och en. Skriv ingen kod.
```

Andra prompten (en konkret fil):
```
Förklara lib/main.dart för mig rad för rad i grova drag — vad händer från att
appen startar tills första skärmen visas?
```

### Gotchas

- `flutter test` på Windows/git-bash kan faila på PATH — kör det via `cmd.bat`-tricket; `flutter analyze` och `flutter pub get` har inte problemet.
- Be inte Claude börja bygga i din första prompt. Be om en karta först — det sparar dig från att gå vilse.
- Bash-skalets `cd` persisterar inte alltid som du tror mellan anrop; använd **absoluta sökvägar** och föredra dedikerade verktyg (Grep/Glob) framför `grep`/`find` i bash.

### Prova nu

Be Claude: "Lista de fyra primära navigeringsflikarna i Butlery och var de definieras." Verifiera svaret mot `C:/Butlery/butlery/lib/widgets/common/navigation/adaptive_navigation.dart` och `C:/Butlery/butlery/lib/core/constants/routes.dart`.

### Checkpoint

**Fråga:** Vilket kommando kollar att koden kompilerar utan fel, och vilket kör testerna — och vilket av dem har en känd Windows-PATH-fälla?
**Svar:** `flutter analyze` kollar kompilering; `flutter test test/...` kör tester. `flutter test` är det som kan faila med "Unable to find git in your PATH" på git-bash och behöver `cmd.bat`-tricket.

---

## Modul 3 — Dina skyddsnät: skills, agenter, hooks (vad de skyddar mot)

**Mål:** Efter den här modulen kan du skilja på de tre skyddslagren — skills, agenter och hooks — och säga vad var och en skyddar mot.

### Innehåll

Butlery har tre olika typer av skyddsnät. De är lätta att blanda ihop, så här är den enkla uppdelningen:

| Lager | Vad det är | När det händer | Analogi |
|---|---|---|---|
| **Skill** | En lamineral fusklapp (Markdown-fil med en YAML-header) som styr *hur* Claude skriver kod | Laddas automatiskt *medan* Claude skriver, när uppgiften matchar | En senior-utvecklares väggnotering som Claude tar ner i rätt ögonblick |
| **Agent** | En specialist-granskare med egen instruktion, som granskar en diff *efteråt* | Körs när du (eller en gate) skickar en diff till den | En besiktningsman som signerar innan du får committa |
| **Hook** | Ett litet bash-skript som körs automatiskt på en livscykelhändelse | *Innan* ett verktyg körs, *efter* en fil skrivs, när Claude försöker stanna | En dörrvakt som antingen vinkar in dig eller stoppar dig |

**Skills** (i `.claude/skills/`) faller i fyra familjer:
- **Generators** skapar ny kod som redan följer husreglerna (`repository-generator`, `viewmodel-generator`, `serialization-generator`, `permission-test-generator`).
- **Validators** fångar farliga mönster (`tri-state-validator`, `data-source-enforcer`, `responsive-layout-validator`, `facade-pattern-detector`, `mixin-advisor`).
- **Domain-knowledge** kodar affärsregler Claude inte får gissa om (`butlery-architecture`, `tagging-domain-knowledge`, `firebase-ingredient-patterns`).
- **Workflow** är medvetna ritualer (`verify`, `drift-migration`, `flag-cleanup`, `permission-audit`, `release-notes`).

Det enda fält som ändrar en skills beteende är `disable-model-invocation`. Saknas det (vanligast) → skillen tänds automatiskt när din uppgift matchar dess `description`. Är det satt till `true` → autotändning AV, och skillen blir ett manuellt `/slash-kommando` du själv skriver. Det är reserverat för riskabla eller "publicerande" handlingar (databasmigrering, flag-städning, säkerhetsaudit, release notes) där Claude aldrig ska börja på eget bevåg.

**Agenter** (i `.claude/agents/`) är organiserade i tiers:
- **Tier 1 (rekommenderad):** `debugger` — för buggar, fel, testfel.
- **Tier 2 (commit-tvingad via hook):** `code-reviewer`, `testing-specialist`, `firebase-backend-security`, `firestore-rules-tester`.
- **Tier 3 (på begäran):** `uiux-designer`, `performance-optimizer`, `flutter-developer`.

**Hooks** (i `.claude/hooks/`, kopplade i `.claude/settings.json`) är skripten som faktiskt *tvingar* fram allt. Vissa **blockerar** (du kommer inte vidare förrän du gör X); andra bara **varnar** på stderr (icke-blockerande knuffar). De blockerande sitter runt två flaskhalsar: `git commit` och `ExitPlanMode` (plan-granskning), plus `Stop`-händelsen (`dart analyze` måste vara ren).

Varför detta inte är byråkrati: `tri-state-validator` förhindrar bokstavligen att Claude säger till en glutenintolerant användare att ett recept är säkert när dess ingredienser aldrig fullt analyserades. Reglerna har riktiga insatser.

### Riktiga referenser

- `C:/Butlery/butlery/.claude/skills/` — alla 17 skills; t.ex. `butlery-architecture.md`, `data-source-enforcer.md`, `tri-state-validator.md`, `mixin-advisor.md`
- `C:/Butlery/butlery/.claude/agents/` — `code-reviewer.md`, `testing-specialist.md`, `firebase-backend-security.md`, `firestore-rules-tester.md`, `debugger.md`
- `C:/Butlery/butlery/.claude/hooks/` — t.ex. `require-review-before-commit.sh`, `file-size-guard.sh`, `regenerate-l10n.sh`, `safety-skill-trigger.sh`
- `C:/Butlery/butlery/.claude/settings.json` — kopplar varje hook till en händelse + matcher
- `C:/Butlery/butlery/CLAUDE.md` — avsnittet "Agent Usage Rules" och tabellen trigger → agent → marker

### Kodexempel

Frontmatter-fältet som avgör autotändning vs slash-kommando:
```yaml
disable-model-invocation: true
```

En hook som matchar en händelse (i `settings.json`, koncept):
```
PreToolUse  → matcher "Bash"  → require-review-before-commit.sh
PostToolUse → matcher "Write|Edit" → regenerate-l10n.sh
```

### Gotchas

- **Skill ≠ agent.** En *skill* styr skrivandet i stunden; en *agent* granskar resultatet efteråt. T.ex. `tri-state-validator` (skill) styr koden, `firebase-backend-security` (agent) granskar den.
- `disable-model-invocation: true` är det enda som skiljer ett manuellt `/slash`-skill från autotändande. Fyra skills är manuella: `drift-migration`, `flag-cleanup`, `permission-audit`, `release-notes`.
- Playbook-texten i skills är skriven **på svenska** (appens UI-språk) med engelska kodkommentarer — rubriker som "Nyckelfilar" (Key files), "Kritiska Fel" (Critical errors), "Varningssignaler" (Warning signals) är bara rubriker, inte kod.
- Generators producerar en **mall** med `{Entity}`-platshållare, inte färdig kod — du fyller i modellnamn och fält.
- Inte alla agent-filer är tvingade: `cloud-functions-specialist` och `e2e-test-specialist` har fulla filer men gateas *inte* av commit-hooken.

### Prova nu

Öppna `C:/Butlery/butlery/.claude/skills/viewmodel-generator.md` och `C:/Butlery/butlery/.claude/skills/drift-migration.md` sida vid sida och läs ENDAST frontmatter (mellan `---`-raderna). Hitta `disable-model-invocation: true` i den ena. Förutsäg: om du säger "skapa en ny ViewModel", vilken laddas automatiskt och vilken måste du anropa med `/drift-migration`?

### Checkpoint

**Fråga:** Två skill-filer ser identiska ut i format — en tänds automatiskt, den andra körs bara när du skriver dess slash-kommando. Vad i filen avgör vilket?
**Svar:** Raden `disable-model-invocation: true` i YAML-frontmatter. Närvarande = autotändning AV (manuellt `/kommando`); frånvarande = Claude autoladdar när `description` matchar din uppgift.

---

## Modul 4 — När det blockar: commit-gates, markers, plan mode, lessons.md

**Mål:** Efter den här modulen kan du, när som helst Claude blockeras, slå upp exakt vilken gate som stoppar dig och de exakta stegen för att låsa upp.

### Innehåll

De blockerande hookarna fungerar genom ett **marker-system** (en "tillståndslapp"). Att köra en granskning producerar en marker-fil under `.claude/state/<namn>-done.marker`. Hooken jämför markerns ändringstid (mtime) med den nyaste ändrade filens mtime:

- **Marker saknas** (granskning aldrig körd) → blockerad.
- **Marker föråldrad/STALE** (du redigerade en fil EFTER senaste granskning) → blockerad.

Därför är regeln alltid: **redigera → granska → `touch` markern → committa**, utan redigeringar emellan. Rör du koden igen efter att du touchat markern, är lappen ogiltig och du måste granska om.

Det finns **två oberoende commit-gates** som båda rör `.claude/state/`:
1. **Agent-review-gaten** (`require-review-before-commit.sh`) — kräver markers för de specialist-agenter vars sökvägsmönster matchar din staged diff.
2. **`/code-review`-gaten** (`require-simplify-before-commit.sh`) — kräver `simplify-done.marker` (legacy-namn behållet med flit för att inte krocka med agentens `code-review-done.marker`).

**Plan mode** har sin egen gate (`plan-review-gate.sh`) som är **två-anrops-stateful**: första `ExitPlanMode`-anropet skriver en marker och BLOCKERAR med en granskningsuppmaning; andra anropet (inom 30 min) raderar markern och TILLÅTER. Panikna inte vid första blocken — det är meningen att du ska bli stoppad första gången.

**Stop-hooken** (`stop-analyze.sh`) blockerar på `Stop`-händelsen: `dart analyze --fatal-infos` måste vara ren *i filer den här sessionen ändrade*. Den är session-medveten — den ignorerar fel från en parallell session.

**`lessons.md`** är inte en gate men en regel: efter VARJE användarrättelse ska Claude OMEDELBART lägga till en daterad post i `tasks/lessons.md` (format `### [Kategori] Titel` + Date, Trigger, Rule, Example) *innan* den gör något annat.

### "Du blev blockerad → gör så här"-tabell

| Du ser detta | Vilken hook | Vad det betyder | Lås upp så här |
|---|---|---|---|
| `MISSING: code-reviewer` | `require-review-before-commit.sh` | En `*.dart`-fil är staged, ingen färsk code-review | Skicka `code-reviewer` mot diffen → `touch .claude/state/code-review-done.marker` → committa igen |
| `MISSING: testing-specialist` | `require-review-before-commit.sh` | En `lib/**/*.dart`-fil är staged | Skicka `testing-specialist` → `touch .claude/state/testing-review-done.marker` |
| `MISSING: firebase-backend-security` | `require-review-before-commit.sh` | Diff rör `lib/repositories/`, `lib/services/{firebase\|firestore\|auth\|user\|gdpr}`, eller `functions/src/` | Skicka `firebase-backend-security` → `touch .claude/state/firebase-security-done.marker` |
| `MISSING: firestore-rules-tester` | `require-review-before-commit.sh` | `firestore.rules` eller `*-rules.test.ts` är staged | Skicka `firestore-rules-tester` (emulator allow+deny) → `touch .claude/state/rules-tester-done.marker` |
| `STALE: <agent>` | `require-review-before-commit.sh` | Du redigerade en fil EFTER att markern touchades | Granska om med den agenten → `touch` markern igen → committa |
| Commit blockas, nämner `/code-review` / `simplify` | `require-simplify-before-commit.sh` | En `.dart` är staged och ingen färsk `/code-review` | Kör `/code-review high` (eller `xhigh` för backend/security-diffar) → `touch .claude/state/simplify-done.marker` |
| Första `ExitPlanMode` blockar med granskningsuppmaning | `plan-review-gate.sh` | Förväntat första halvan av två-anrops-gaten | Gör granskningen den ber om (för high-stakes-planer: kör `/review-plan`), anropa sedan `ExitPlanMode` IGEN |
| Claude kan inte stanna, "dart analyze found issues" | `stop-analyze.sh` | Fel i filer DENNA session ändrade | Fixa felen; om samma fel två gånger i rad → eskalera till Linear-ticket (anti-loop) |
| Bash-kommando vägras (reset --hard, checkout ., clean -f, rm -rf, push --force) | `bash-firewall.sh` | Destruktivt git/rm-kommando | Kör `git status` först, fråga användaren; kör utanför Claudes Bash-verktyg om verkligen nödvändigt |
| stderr-varning "file exceeds 500 lines" | `file-size-guard.sh` | Icke-blockerande knuff | Splitta till facade + managers, ELLER allowlista, ELLER lägg `// claude:large-file-ok — <skäl>` i första 10 raderna |
| stderr "regenerate-l10n FAILED" | `regenerate-l10n.sh` | ARB-syntax/placeholder-fel | Fixa ARB-filen (matchande nycklar/placeholders i båda språkfilerna); markören är icke-blockerande |
| stderr om schemaVersion / drift | `drift-version-guard.sh` | Drift-tabell ändrad utan version-bump | Kör `/drift-migration` (icke-blockerande varning) |
| Inget händer på en doc-only commit | (alla gates) | Inga sökvägsmönster matchade | Hooken är tyst — committa fritt |

### Riktiga referenser

- `C:/Butlery/butlery/.claude/hooks/require-review-before-commit.sh` (sökvägsmönstren, rad ~93–127)
- `C:/Butlery/butlery/.claude/hooks/require-simplify-before-commit.sh`
- `C:/Butlery/butlery/.claude/hooks/plan-review-gate.sh` (rad 54–70, två-anrops-logiken)
- `C:/Butlery/butlery/.claude/hooks/stop-analyze.sh`
- `C:/Butlery/butlery/.claude/hooks/bash-firewall.sh`
- `C:/Butlery/butlery/lefthook.yml` — OS-git-lagrets pre-commit-koppling: `dart format` + `secret-scan:` (rad 24) + `dart analyze` körs här, oberoende av Claudes hooks
- `C:/Butlery/butlery/.claude/state/` — alla marker-filer
- `C:/Butlery/butlery/.claude/settings.json` — kopplingarna
- `C:/Butlery/butlery/tasks/lessons.md` — self-improvement-loggen

### Kodexempel

```bash
# Standard-upplåsningssekvens efter att en agent rapporterat rent:
touch .claude/state/code-review-done.marker

# /code-review-gaten:
touch .claude/state/simplify-done.marker
```

Markör-staleness i hooken (koncept):
```bash
block_reasons+=("STALE: $agent — files edited after review. Re-run, then: touch .claude/state/$marker")
```

### Gotchas

- **Första `ExitPlanMode` blockar ALLTID.** Det är design. Ge inte upp — anropa igen efter granskningen.
- **Redigering efter granskning ogiltigförklarar markern** via mtime. Alltid: edit → review → touch → commit, inget emellan.
- `/code-review`-markern heter `simplify-done.marker` (legacy), INTE `code-review-done.marker`. Det senare är `code-reviewer`-*agentens* marker. Två olika granskare, två olika markers.
- **Secret-scanning sker — men inte via en Claude-hook.** `secret-scan-precommit.sh` (Claude-hook-varianten) finns i repot men är **inte inkopplad** i `.claude/settings.json`, så den körs inte som en Claude PreToolUse-hook. MEN secret-scanning gateas ändå vid *varje* commit via lefthook pre-commit-hooken (`lefthook.yml` rad 24, `secret-scan:`). Hemligheter scannas alltså — bara av lefthook på OS-git-lagret, inte av en Claude-hook. Läs inte "inte inkopplad i settings.json" som "hemligheter scannas inte".
- Stop-hooken är session-medveten: fixa INTE analyze/test-fel i filer den här sessionen inte rörde — de tillhör en parallell session.
- Plan-markers ligger i `$HOME/.claude/state/` (inte repots) med 30 min TTL; commit-markers ligger i repots `.claude/state/`.
- Kör inte review-agenter på >3 filer samtidigt — de timeout:ar. Splitta commits eller batcha i 2–3.

### Prova nu

Öppna `C:/Butlery/butlery/.claude/hooks/require-review-before-commit.sh` och följ `has_match`-anropen. För dessa hypotetiska staged-filer, lista vilka markers hooken kräver: (1) `lib/views/recipe_detail.dart`, (2) `functions/src/index.ts`, (3) `firestore.rules`, (4) `docs/README.md`.
*(Facit: 1 → code-review + testing-review; 2 → firebase-security (`.ts` är inte `.dart`, så code-reviewer tänds INTE); 3 → rules-tester; 4 → ingen, hooken tystnar.)*

### Checkpoint

**Fråga:** Du körde `/code-review` och `testing-specialist`, touchade båda markers, upptäckte sedan ett stavfel och redigerade en staged `.dart`-fil igen. Du kör `git commit`. Vad händer och varför?
**Svar:** Den BLOCKERAR som STALE. Gaten jämför varje markers mtime mot den nyaste ändrade filens mtime; din redigering efter granskningen gjorde filen nyare än båda markers, så gaten kräver att du granskar om och touchar markers igen innan commit.

---

## Modul 5 — Att dirigera Claude bra: prompt, plan mode, läsa en diff

**Mål:** Efter den här modulen kan du skriva en prompt som ger rätt resultat, känna igen när plan mode bör starta, och läsa en diff tillräckligt för att godkänna eller avvisa en ändring.

### Innehåll

**Skriva en bra prompt.** Det bästa du kan göra är att vara konkret om *vad* och låta Claude lösa *hur* — men ge den ankarpunkter. En vag prompt ("fixa onboarding") ger gissningar; en förankrad prompt ("i `lib/l10n/app_sv.arb`, lägg till nyckeln X efter Y med värdet Z, och spegla den i `app_en.arb`") ger exakt det du ville. Mönstret att kopiera är ofta: *peka på en befintlig fil som redan gör det rätt och säg "härma den".*

**Plan mode.** Triggas automatiskt för komplext arbete: 3+ filer, nya services/viewmodels, arkitekturändringar, eller varje "refactor"/"migrate"-begäran. Claude skriver planen till `tasks/todo.md`, får godkännande, och implementerar sedan. Varje plan MÅSTE sluta med en sektion `## What this means in plain language` (5–8 punkter, noll jargong) som förklarar vad du kommer märka och vad som kan gå sönder. Den sektionen är din gåva som icke-kodare: läs den för att förstå vad som händer.

**Läsa en diff.** En diff visar `-` (borttaget) och `+` (tillagt). Du behöver inte förstå varje rad — du behöver svara på tre frågor:
1. Rör ändringen bara de filer den borde? (En l10n-ändring som plötsligt rör en repository är en varningsflagga.)
2. Följer den husreglerna? (Svenska UI-strängar, `withValues` inte `withOpacity`, inga rundade hörn, ingen `FirebaseFirestore.instance` utanför en repository.)
3. Stämmer "plain language"-sammanfattningen med vad diffen faktiskt gör?

**Riktning i en trace.** Lär dig läsa uppifrån-ned för en knapptryckning (View → ViewModel → Service → Repository → Firebase) och nerifrån-upp för data som anländer (Firestore-stream → Repository → Service → ViewModel hör via stream → View ritas om). Mer om detta i Modul 7.

### Riktiga referenser

- `C:/Butlery/butlery/.claude/rules/workflow-discipline.md` — plan mode-triggers, obligatorisk plain-language-sektion
- `C:/Butlery/butlery/tasks/todo.md` — där planen skrivs (sprint-scratchpad)
- `C:/Butlery/butlery/.claude/plan-review-checklist.md` — checklistan planer granskas mot

### Prompt-exempel

Förankrad bygg-prompt (bra):
```
I lib/l10n/app_sv.arb, lägg till nyckeln onboardingWelcomeCrossPlatform direkt efter
onboardingWelcomeNote med värdet "Planera på datorn, laga från telefonen — Butlery
funkar överallt." Spegla den i app_en.arb med engelsk text. Härma exakt stilen på
den befintliga onboardingWelcomeNote-raden (bara nyckel/värde, ingen @-metadata).
```

Be om en plan:
```
Det här rör flera filer och en ny service. Gå in i plan mode, skriv planen till
tasks/todo.md, och avsluta med plain-language-sektionen så jag förstår vad som händer.
```

Läsa en diff:
```
Visa mig diffen för det du nyss ändrade. För varje fil, säg i en mening varför den
behövde röras, och bekräfta att inga UI-strängar är på engelska och att ingen kod
använder withOpacity eller FirebaseFirestore.instance.
```

### Gotchas

- Vag prompt → gissningar. Förankra alltid i en fil eller ett befintligt mönster.
- Efter att en plan godkänts: be inte Claude "läsa filerna igen" — plan mode har redan utforskat. Hoppa rakt in i steg 1.
- `tasks/todo.md` skrivs över av nästa sprint. Allt som måste överleva måste till Linear som en egen ticket.
- Erbjud aldrig "branch + PR vs pusha till main" — det är solo-flöde, pusha alltid till main.

### Prova nu

Öppna `C:/Butlery/butlery/tasks/todo.md` och läs den aktuella sprinten. Hitta en tasks tier-tagg (`[Tier A]` / `[Tier B]`). Förklara med egna ord varför en Tier A-task stängdes rakt till Done medan en Tier B-task parkerades i "In Review".

### Checkpoint

**Fråga:** Vilken sektion måste varje plan sluta med, och varför är den särskilt värdefull för dig som inte är van vid kod?
**Svar:** `## What this means in plain language` — 5–8 jargongfria punkter om vad du kommer märka och vad som kan gå sönder. Den låter dig förstå och godkänna en ändring utan att kunna Flutter.

---

# DEL 2 — Butlery-appen (kartan)

---

## Modul 6 — Vad är Butlery (produkten)

**Mål:** Efter den här modulen kan du beskriva vad Butlery gör för en användare och rita huvudresan från "jag hittade ett recept" till "jag lagade det och handlade ingredienserna".

### Innehåll

Butlery är en svenskspråkig matlagnings-/receptapp som förvandlar "jag hittade ett recept" till "jag lagade det och handlade varorna". Hela appen hänger på en **fyr-fliks bottennavigering**:

- **Recept** (Mina recept) — `/`
- **Meny** (Veckomeny) — `/veckomeny`
- **Inköp** (Inköpslista) — `/inkopslista`
- **Lägg till** (importera/skapa recept)

Kärnresan är en pipeline (tänk fabrikslinje, inte lista): råmaterial (en receptlänk) kommer in vid **Lägg till**, bearbetas (import), lagras i ett lager (**Mina recept**), monteras till en order (**Veckomeny**), plockas till en kundvagn (**Inköpslista**), och används till slut (**Cooking Mode**). Varje flik är en station på linjen.

Runt den ryggraden sitter stödfunktioner: **Skafferi** (vad du har hemma), **Ingredienssök** (vad kan jag laga av detta?), **Personliga taggar** (egna etiketter/samlingar), **Onboarding** (allergener + diet + första import), **Konto/Inställningar**, och **Notiser**.

En andra hel dimension är **Socialt**: vänner, grupper, delning av recept och menyer, realtids-kollaborativa inköpslistor och menyer, direktmeddelanden och offentliga profiler. Ett recept kan flöda från en persons samling in i en väns.

### Riktiga referenser

- `C:\Butlery\butlery\lib\widgets\common\navigation\adaptive_navigation.dart` — de 4 navigeringsdestinationerna
- `C:\Butlery\butlery\lib\core\constants\routes.dart` — hela navigationsgrafen ("planritningen")
- `C:\Butlery\butlery\lib\views\mina_recept_view.dart` — receptsamlingens nav
- `C:\Butlery\butlery\lib\views\veckomeny_view.dart` — veckomenyplaneraren
- `C:\Butlery\butlery\lib\views\cooking_mode_view.dart` — fullskärms cooking mode (resans sista steg)

### Kodexempel

```dart
static const String weeklyMenu = '/veckomeny';
static const String shoppingList = '/inkopslista';
static const String cookingMode = '/cooking-mode';
```

### Gotchas

- Bottennavigeringen är exakt **fyra** flikar. Allt annat nås genom att pusha rutter ovanpå dessa.
- Butlery är medvetet **inte ett socialt nätverk** — discovery-dashboarden är borttagen; men vänner/delning/kommentarer/betyg/grupper finns kvar.
- Det finns ännu **inga monetiseringsbeslut** och ingen app-store-inlämning — fokus är att bygga.

### Prova nu

Öppna `C:/Butlery/butlery/lib/core/constants/routes.dart` och hitta `weeklyMenu`, `shoppingList` och `cookingMode`. Bekräfta vilka stränger de mappar till (`/veckomeny`, `/inkopslista`, `/cooking-mode`).

### Checkpoint

**Fråga:** Vilka är de fyra primära flikarna, och vilken är resans terminalsteg (där du faktiskt lagar)?
**Svar:** Recept (`/`), Meny (`/veckomeny`), Inköp (`/inkopslista`), Lägg till. Terminalsteget är Cooking Mode (`cooking_mode_view.dart`), nås från receptdetalj eller meny.

---

## Modul 7 — Arkitekturen: Views → ViewModels → Services → Repositories → Firebase

**Mål:** Efter den här modulen kan du följa en knapptryckning genom alla fyra lager och förklara varför bara repository:t får röra databasen.

### Innehåll

Butlery är organiserat i fyra staplade lager, och data flödar bara mellan angränsande lager — aldrig hoppande. **Restaurang-analogin:**

- **View** = matsalen (vad du ser och rör — widgets, knappar)
- **ViewModel** = servitören (tar din beställning, bär ut maten, men lagar inget)
- **Service** = köksmästaren (bestämmer vad som ska göras, koordinerar)
- **Repository** = kocken som faktiskt går in i skafferiet (Firebase/Firestore)

Den gyllene regeln: varje lager pratar bara med det direkt under. En knapp skriver aldrig till databasen direkt; det går View → ViewModel → Service → Repository → Firebase.

**Dependency injection (DI):** hur får en widget de objekt den behöver (sin servitör, sin kock)? Vid appstart (`lib/main.dart`) registreras varje service/repository/viewmodel i en central container (GetIt, omsluten av DIContainer). Senare frågar vilken widget som helst efter vad den behöver per typ: `ServiceLocator.get<SomeType>()` — den bygger aldrig objekten själv med `new`. Garderobs-analogin: vid start lämnar du alla verktyg till garderobs-disken (containern). Senare säger du bara "ge mig recept-servicen".

**En konkret trace (favorit-hjärtat — den VERKLIGA favorit-skrivvägen):**
1. View anropar `viewModel.toggleFavorite()`.
2. ViewModel (`recipe_detail_viewmodel.dart:369–379`) vänder den lokala flaggan optimistiskt, anropar `notifyListeners()` så hjärtat ritas om direkt, frågar sedan Service: `recipeService.toggleFavorite(id, nyttVärde)`.
3. Service (`unified_recipe_service.dart:816`) bygger en hel uppdaterad receptkopia (`copyWith(isFavorite: ...)`) och delegerar persistensen till Repository via `updateRecipe(updated)` — en **full-dokument-update**, inte en fält-inkrement.
4. Repository (`FirebaseRecipeRepository.updateRecipe`) kollar permissions och utför Firestore-skrivningen (`getCollectionForUser(userId).doc(recipeId).update(updated.toFirestore())`) genom basklassens skyddade `firestore`-getter.
5. Failar skrivningen vänder ViewModel tillbaka flaggan (rollback).

**Viktigt — en ANNAN repository-skrivning:** `incrementCookCount()` (`firebase_recipe_repository.dart:549–573`) är INTE favorit-vägen. Den backar cook-count-/"Lagat idag"-handlingen (en separat knapp), och skriver bara två fält (`core.cookCount` + `core.lastCookedAt`) som ett riktat `update`. Vi visar den nedan som ett rent exempel på en *minimal, fält-riktad* repository-skrivning — kontrasten mot favorit-vägens full-dokument-`updateRecipe` är själva poängen.

**Interface vs implementation:** containern registrerar `RecipeRepository` (abstrakt interface) och ger tillbaka en `FirebaseRecipeRepository` (konkret). Vägguttags-analogin: din lampa (ViewModel) ansluter till uttagsformen (interfacet); bakom väggen kan det vara sol eller kol (Firebase eller en mock) — lampan varken vet eller bryr sig.

**`notifyListeners()` är dörrklockan:** ViewModel:n ringer på, och varje widget som prenumererar (Consumer/Selector) vaknar och ritar om. Ingen klocka = skärmen ser frusen ut även om datan ändrades.

**Optimistisk uppdatering:** som att kryssa av en vara på inköpslistan innan kassörskan bekräftat — känns direkt. Avvisas kortet (skrivningen failar) okryssar du.

**Var bor den enda `FirebaseFirestore.instance`?** Du kommer i Modul 9/10 läsa regeln "rör aldrig `FirebaseFirestore.instance` inuti en repository". Det är sant för *subklasserna*. Men öppnar du basklassen `base_firebase_repository.dart` ser du den litterala `FirebaseFirestore.instance` i konstruktorn (rad 29) — det är den ENDA sanktionerade instansieringen i hela datalagret. Den exponeras vidare via den `@protected firestore`-gettern (rad 36) som alla subklasser använder. Poängen: instansen skapas på exakt ETT ställe (basklassen) så att ingen subklass någonsin behöver röra `FirebaseFirestore.instance` själv. Blir du förvirrad av att se den i basklassen — det är meningen att den ska bo just där.

### Riktiga referenser

- `C:/Butlery/butlery/lib/main.dart` — startpunkt, bygger DI
- `C:/Butlery/butlery/lib/core/di/di_container.dart` — DI-containern (omsluter GetIt)
- `C:/Butlery/butlery/lib/core/providers/application_provider.dart` — `ServiceLocator`-klassen
- `C:/Butlery/butlery/lib/core/di/modules/ui_module.dart` — registrerar ViewModels
- `C:/Butlery/butlery/lib/core/di/modules/content_module.dart` — binder `RecipeRepository`-interface till impl (rad 355–357)
- `C:/Butlery/butlery/lib/views/recipe_detail_view.dart` — View (hjärtknapp ~rad 346)
- `C:/Butlery/butlery/lib/viewmodels/recipe_detail_viewmodel.dart` — ViewModel (`toggleFavorite` rad 369–379)
- `C:/Butlery/butlery/lib/services/unified/unified_recipe_service.dart` — Service-facade (`toggleFavorite` rad 816 → `updateRecipe`)
- `C:/Butlery/butlery/lib/repositories/interfaces/recipe_repository.dart` — kontraktet
- `C:/Butlery/butlery/lib/repositories/firebase/firebase_recipe_repository.dart` — impl; `incrementCookCount` rad 549–573 (SEPARAT cook-count-skrivning, ej favorit)
- `C:/Butlery/butlery/lib/repositories/firebase/base_firebase_repository.dart` — konstruktorns `FirebaseFirestore.instance` (rad 29) + den sanktionerade `firestore`-gettern (rad 36)

### Kodexempel

```dart
// View → ViewModel (recipe_detail_view.dart:346)
onPressed: () async { await viewModel.toggleFavorite(); ... }

// FAVORIT-vägen: optimistisk uppdatering + rollback (recipe_detail_viewmodel.dart:369-379)
_recipe = _recipe.copyWith(isFavorite: newValue);
notifyListeners();
final success = await _recipeService.toggleFavorite(...);   // unified_recipe_service.dart:816
if (!success) {
  _recipe = _recipe.copyWith(isFavorite: !newValue);
  notifyListeners();
}

// FAVORIT-vägens VERKLIGA skrivning: service bygger en full kopia och kör updateRecipe
// (unified_recipe_service.dart:816 → repository.updateRecipe(updated))
final updated = recipe.copyWith(isFavorite: value);
await _recipeRepository.updateRecipe(updated);   // full-dokument-update

// EN ANNAN repository-skrivning (INTE favorit): cook-count-/"Lagat idag"-handlingen
// (firebase_recipe_repository.dart:549-573) — minimal, fält-riktad update
await getCollectionForUser(userId).doc(recipeId).update({
  'core.cookCount': FieldValue.increment(1),
  'core.lastCookedAt': Timestamp.fromDate(cookedAt),
});

// Den enda sanktionerade FirebaseFirestore.instance bor i basklassen:
// base_firebase_repository.dart:29 (konstruktor) → exponeras via gettern:
@protected FirebaseFirestore get firestore => _firestore;   // rad 36
```

### Gotchas

- **Favorit ≠ cook-count.** Hjärtat går via service `toggleFavorite()` → `updateRecipe(updated)` (full-dokument-skrivning). `incrementCookCount()` är "Lagat idag"-handlingen (riktad tvåfälts-skrivning) — en helt separat operation. Blanda inte ihop dem.
- **`RecipeDetailViewModel` är undantaget som bekräftar regeln:** den är INTE registrerad i DI (`ui_module.dart`) eftersom den behöver en specifik Recipe-instans. View:n skapar den direkt med `ChangeNotifierProvider(create: ...)`. Andra VM:er (SocialRecipeViewModel m.fl.) hämtas med `ServiceLocator.get`.
- Singleton-VM:er måste använda `ChangeNotifierProvider.value` (aldrig `create:`) för att undvika dubbel-dispose.
- **Två olika "aktuell användare"-accessorer får inte blandas:** `userService.currentUserProfile` (full data/inställningar) vs `permissionService.currentUserId` (auth/permission-checks). Mer i Modul 9 & 10.
- Data som flödar UPP från Firestore når UI:t via Service:ns RxDart `stateStream` (BehaviorSubject), inte via en direkt ChangeNotifier.
- På webben är receptcachen stubbad — `UnifiedRecipeService` tar en annan kodväg (`kIsWeb`-grenar).
- Den litterala `FirebaseFirestore.instance` du ser i `base_firebase_repository.dart:29` är sanktionerad och unik — kopiera den INTE in i en subklass; subklasser använder `firestore`-gettern.

### Prova nu

Öppna `C:/Butlery/butlery/lib/views/recipe_detail_view.dart` och hitta hjärtknappen (~rad 346). Följ tryckningen ner: `toggleFavorite()` i ViewModel (rad 369–379) → i Service (rad 816), där den anropar `updateRecipe(updated)` (favoritens VERKLIGA skrivning). Öppna sedan `incrementCookCount()` (rad 549–573) och bekräfta att det är en SEPARAT operation (cook-count, inte hjärtat). Sök till sist View- och ViewModel-filerna efter `FirebaseFirestore` och bekräfta NOLL träffar — och öppna `base_firebase_repository.dart:29` för att se var den enda instansen faktiskt bor.

### Checkpoint

**Fråga:** När användaren trycker på favorit-hjärtat, vilket lager utför den verkliga Firestore-skrivningen, vilken repository-metod är det, och varför görs det inte i ViewModel:n?
**Svar:** Repository:t (`FirebaseRecipeRepository`) utför skrivningen, via `updateRecipe(updated)` — service-lagrets `toggleFavorite()` bygger en full receptkopia med `copyWith(isFavorite: ...)` och skickar ner den. (Det är INTE `incrementCookCount()`, som backar den separata "Lagat idag"-handlingen.) Repository:t är det enda lagret som får röra Firestore, via basklassens skyddade `firestore`-getter — vars enda `FirebaseFirestore.instance` lever i `base_firebase_repository.dart`. ViewModel:n uppdaterar bara lokal state + `notifyListeners` och delegerar nedåt. Att centralisera DB-access i repository:t håller permission-validering, ägarcheck och audit-loggning på ett granskningsbart ställe.

---

## Modul 8 — Feature-kartan: alla features och hur de hänger ihop

**Mål:** Efter den här modulen kan du spåra hur ett recept rör sig mellan flikarna och var två features kopplas ihop i koden.

### Innehåll

Tänk på appen som en fabrikslinje med två axlar:

**Vertikal axel (din egen pipeline):** import → samling → meny → inköp → laga.
**Horisontell axel (socialt):** vänner/grupper → dela recept & menyer → realtids-kollaborativa listor/menyer → meddelanden.

**Import-tratten → samling:** sex importvägar konvergerar alla på samma utfall — ett Recept sparat i Mina recept. `lagg_till_recept_view` erbjuder 4 (smartImport, manuell, foto, arkiv); `smart_import` absorberar själv URL + text + sociala medier; `receive_share_view` är en OS-nivå-ingång; quick capture är en snabb stub-save. Sex olika dörrar, samma lobby.

**Recept → meny → inköp-pipelinen (kärnvärdesslingan):** ett recept i samlingen kan läggas till veckomenyn. Menyns dialog (`showShoppingListSelector`) genererar en inköpslista från alla menyns ingredienser och navigerar till inköpsfliken. Alternativt genererar ett enskilt recepts detaljsida en inköpslista direkt. Båda trattas in i `UnifiedShoppingViewModel.addItemsToList`.

**Allergen/diet-preferenser som tvärgående flöde:** sätts vid onboarding, propageras framåt — allergen-banner dyker upp i foto/text/smart-import, allergen-badges på receptdetalj, och menygenerering filtrerar på dem.

**Skafferi + ingredienssök-slingan:** skafferiet spårar vad som finns hemma; ingredienssök gör omvänd query (välj ingredienser → rankade recept), och stänger en slinga från "vad jag har" tillbaka till "vad ska jag laga".

### Riktiga referenser

- `C:\Butlery\butlery\lib\views\lagg_till_recept_view.dart` — add-launcher (2x2-grid)
- `C:\Butlery\butlery\lib\views\smart_import_view.dart` — enad import-ingång
- `C:\Butlery\butlery\lib\widgets\menu\veckomeny_dialogs.dart` — `showShoppingListSelector` (~rad 144), meny→inköp-bryggan
- `C:\Butlery\butlery\lib\views\recipe_detail\handlers\recipe_shopping_handler.dart` — recept→inköp-kanten
- `C:\Butlery\butlery\lib\views\unified_shopping_view.dart` — inköpslistehanteraren (konvergenspunkt)
- `C:\Butlery\butlery\lib\views\pantry\pantry_view.dart` — Skafferiet (sub-tab)
- `C:\Butlery\butlery\lib\views\ingredient_search\ingredient_search_view.dart` — omvänd uppslagning
- `C:\Butlery\butlery\lib\views\social\shared_with_me_view.dart` — person-till-person-kanten
- `C:\Butlery\butlery\lib\views\onboarding\onboarding_view.dart` — onboarding-wizard

### Kodexempel

```dart
// Meny → inköp-bryggan (veckomeny_dialogs.showShoppingListSelector)
Navigator.pushNamed(context, Routes.shoppingList);

// Konvergenspunkten där båda vägarna landar
Future<bool> addItemsToList(...) => _shoppingService.addItemsBatch(items);
```

### Gotchas

- De namngivna import-features är mest enskilda filer i `lib/views/`-roten, INTE undermappar. `fran_sociala_medier_view.dart` är faktiskt TEXT-importen (parsar klistrad text), trots namnet — inte en live social-media-scraper.
- `cooking_mode`, `menu/veckomeny` och import-varianterna är INTE kataloger — förvänta dig inte `lib/views/cooking_mode/`.
- Meny→inköp-kopplingen är INTE en metod på `MenuViewModel` — bryggan ligger i UI-lagret (`veckomeny_dialogs.showShoppingListSelector`) och går genom `UnifiedShoppingViewModel`.
- `pantry_view` har ingen egen Scaffold/AppBar — den är en sub-tab och går sönder om den renderas fristående.
- Två parallella `group_detail_view.dart` finns: `lib/views/social/` (delningsgrupper) och `lib/views/messaging/` (chattgrupper) — samma filnamn, olika feature.
- Det finns realtids-tvillingar (`realtime_menu_viewmodel`, `collaborative_shopping_viewmodel`) — kollaboration är en separat kodväg, inte en flagga på den personliga vyn.

### Prova nu

Öppna `C:\Butlery\butlery\lib\widgets\menu\veckomeny_dialogs.dart` och hitta `showShoppingListSelector` (~rad 144). Följ `Navigator.pushNamed(context, Routes.shoppingList)` och bekräfta i `routes.dart` att `Routes.shoppingList = '/inkopslista'`. Du har då bevisat hur Meny-fliken lämnar en genererad inköpslista till Inköp-fliken.

### Checkpoint

**Fråga:** Ett importerat recept ska bli en inköpslista. Spåra de två möjliga vägarna och var de konvergerar.
**Svar:** Väg 1 (via meny): recept → veckomeny → `veckomeny_dialogs.showShoppingListSelector` aggregerar ingredienser → pushar `Routes.shoppingList`. Väg 2 (enskilt recept): receptdetalj → `recipe_shopping_handler`. Båda konvergerar på `UnifiedShoppingViewModel.addItemsToList`.

---

## Modul 9 — Firebase & datalagret: Firestore, repositories, dataflöde, kostnadstänk

**Mål:** Efter den här modulen kan du förklara hur en repository pratar med Firestore, skillnaden på top-level och user-scoped collections, och varför kostnadsreglerna (batch 450, cache, whereIn 30) finns.

### Innehåll

Datan bor i **Firestore** (Googles moln-NoSQL: collections av documents). Appen pratar aldrig med Firestore direkt från skärmarna — allt går genom en **repository** (en klass vars enda jobb är att läsa/skriva en sorts sak: recept, användare, kommentarer...).

**Lager-analogi:** Firestore är ett jättelager, en repository är den enda expediten som får gå bakom disken för en viss hylla. Skärmarna vandrar inte runt i lagret; de lämnar en lapp till expediten ("ge mig recept #42"). Expediten kollar ID (permission), loggar, hämtar lådan och packar upp den till något du kan använda.

**Hur en repository pratar med Firestore:** via den skyddade `firestore`-gettern på basklassen (aldrig den globala `FirebaseFirestore.instance`). Den bygger en `CollectionReference`, anropar `.doc(id).set/get/update/delete`, och översätter mellan Firestores `Map<String, dynamic>` och typade modeller via `fromFirestore`/`toFirestore` (två översättare, en åt varje håll). (Den enda riktiga `FirebaseFirestore.instance` i hela datalagret skapas i basklassens konstruktor — se Modul 7 — så att ingen subklass behöver röra den.)

**Collections vs documents:** en collection är en namngiven hink ("recipes"); inuti är varje sak ett document (en JSON-liknande map) med ett id. Documents kan ha subcollections, t.ex. `users/{uid}/recipes/{recipeId}`. Inga rader/tabeller/joins.

**Top-level vs user-scoped:** top-level (`recipes`, `public_profiles`, `conversations`...) håller globalt adresserbar/delad data. User-scoped data bor under `users/{uid}/...` (egna recept, settings, vänner, inköpslistor, skafferi). Repositories med user-scoped data mixar in `UserScopedFirebaseRepository`, vars override silent ruttar varje operation till `getUserCollection(currentUid)`.

**`BaseFirebaseRepository` (mallen, Template Method):** en abstrakt generisk klass som implementerar create/read/readAll/update/delete EN gång, och slår in varje operation i permission-check + audit-logg. En ny repository svarar bara på fyra frågor: vilken collection? hur (de)serialiserar jag? vad är id:t? vem får göra vad?

**Kostnadstänk (Firestore tar betalt per läsning och skrivning):**
- **Batching:** bunta många skrivningar i en `WriteBatch` (en nätverksresa). MEN max **500** operationer per batch (`kFirestoreBatchOpLimit`). Projektet chunkar vid **450** (`kFirestoreBatchSafeChunkSize`) för 50 ops marginal. Brev-analogi: 500 brev i en postsäck = en resa; en i taget = 500 resor. Säcken rymmer 500, Butlery fyller till 450.
- **Caching:** cache-first-läsningar (`getDocCacheFirst`), in-memory LRU (1h TTL) för site configs, permission-cache. Bibliotek-analogi: kör inte till biblioteket för en fakta du redan skrev på en post-it.
- **Bounded queries:** `.limit`, `readAll`s 10000-tak, och `whereIn` cappad till **30** ids per query (`kFirestoreWhereInLimit`) — stora id-listor fanas ut i flera chunkade queries.

### Riktiga referenser

- `C:\Butlery\butlery\lib\repositories\CLAUDE.md` — repository-kontraktet
- `C:\Butlery\butlery\lib\repositories\interfaces\repository.dart` — `Repository<T>` (5 metoder)
- `C:\Butlery\butlery\lib\repositories\firebase\base_firebase_repository.dart` — hjärtat (CRUD + audit, `firestore`-getter rad 36, enda `FirebaseFirestore.instance` rad 29)
- `C:\Butlery\butlery\lib\core\constants\firestore_collections.dart` — alla collection-namn (snabbaste kartan över datan)
- `C:\Butlery\butlery\lib\repositories\firebase\firebase_recipe_repository.dart` — kanonisk user-scoped repository
- `C:\Butlery\butlery\lib\repositories\firebase\firebase_user_repository.dart` — `public_profiles` + `users/{uid}/settings/preferences`, whereIn-chunking
- `C:\Butlery\butlery\lib\repositories\firebase\firestore_batch_utils.dart` — `batchDeleteDocs`, chunkning vid 450
- `C:\Butlery\butlery\lib\core\extensions\iterable_extensions.dart` — kostnadskonstanterna + `.chunked()`
- `C:\Butlery\butlery\lib\repositories\site_config_repository.dart` — read-only, cachad, sanktionerad bypass (BUT-886)
- `C:\Butlery\butlery\lib\repositories\firestore_repository.dart` — låg-nivå untyped wrapper (GDPR-export/radering)

### Kodexempel

```dart
@protected FirebaseFirestore get firestore => _firestore; // den enda sanktionerade handlen (rad 36)
// _firestore tilldelas i konstruktorn med FirebaseFirestore.instance (rad 29) — enda gången i datalagret

const int kFirestoreBatchOpLimit = 500;     // Firestores hard cap
const int kFirestoreBatchSafeChunkSize = 450; // säker chunk
const int kFirestoreWhereInLimit = 30;       // whereIn-cap

final chunks = docs.chunked(kFirestoreBatchSafeChunkSize);
for (final batch in userIds.chunked(kFirestoreWhereInLimit)) {
  final query = await collection.where(FieldPath.documentId, whereIn: batch).get();
}
```

### Gotchas

- Använd ALDRIG `FirebaseFirestore.instance` eller `FirebaseAuth.instance.currentUser` inuti en repository-*subklass* — använd `firestore`-gettern och `requireCurrentUserId()`. (Basklassen är det enda stället där `FirebaseFirestore.instance` litterar — det är sanktionerat och unikt.)
- Registrera INTERFACE-typen i DI (`RecipeRepository`), inte impl (`FirebaseRecipeRepository`).
- Koda aldrig till 500 — chunka vid 450.
- `whereIn`/`in`/`arrayContainsAny` är cappade till 30 ids — fana ut, inte en jätte-query.
- User settings (allergener, FCM-token, notisprefs, locale) bor i `users/{uid}/settings/preferences`, INTE på `public_profiles`-doc:et — för vem som helst inloggad kan läsa publika profiler.
- Cache-first-läsningar är OK för visning men INTE för permission-checks eller pre-update-validering — de behöver färsk serverdata.
- Inte varje repository extendar basklassen — `firestore_repository.dart`, `site_config_repository.dart`, `collaborative_recipe_repository.dart` är sanktionerade undantag, var och en med en daterad `BUT-###`-kommentar. Kopiera inte bypassen utan motsvarande motivering.
- `batchDeleteDocs` har ett partial-write-kontrakt: failar chunk N+1 är de N första redan committade. Kör om är säkert (idempotent).

### Prova nu

Öppna `C:\Butlery\butlery\lib\repositories\firebase\firebase_user_repository.dart` och hitta `updateAllergenPreferences` (~rad 561). Notera att den INTE skriver till den publika profilen utan till `_settingsDoc(userId)` = `users/{uid}/settings/preferences` med `SetOptions(merge: true)`. Svara: varför ligger settings i ett separat privat doc? (Ledtråd: `validateReadPermission` för profilen returnerar true för vilken inloggad användare som helst.)

### Checkpoint

**Fråga:** Du ska radera 1 200 documents i en logisk operation. Varför kan du inte lägga alla i en `WriteBatch`, och vad gör Butlery istället?
**Svar:** En `WriteBatch` är cappad till 500 ops (`kFirestoreBatchOpLimit`). Butlery splittar i chunkar om 450 (`kFirestoreBatchSafeChunkSize`) via `.chunked()` och committar varje chunk som egen batch (`batchDeleteDocs`). Raderingen är idempotent, så om en mitt-chunk failar fullföljer en omkörning resten.

---

## Modul 10 — Säkerhet: PermissionValidationMixin, firestore.rules, GDPR, data sources

**Mål:** Efter den här modulen kan du förklara de två säkerhetsväggarna, varför "göm en knapp" inte är säkerhet, och hur GDPR-rättigheterna mappar till tre services.

### Innehåll

Butlery skyddar data med **TVÅ oberoende väggar**, inte en.

**Vägg 1 (i Dart-appen):** varje repository mixar in `PermissionValidationMixin` och implementerar fyra checks — `validateCreatePermission`, `validateReadPermission`, `validateUpdatePermission`, `validateDeletePermission`. Basklassen anropar dem före varje CRUD, loggar resultatet för audit, och kastar `PermissionDeniedException` vid nekande. Detta ger snabb, vänlig in-app-blockering och en enhetlig audit-trail. Dörrvakts-analogin: den artiga dörrvakten i lobbyn som stoppar dig med ett tydligt meddelande.

**Vägg 2 (på Googles servrar):** `firestore.rules` om-kollar VARJE läsning och skrivning oavsett vad app-koden gör. Detta är bankvalvs-dörren. En angripare kan smita förbi dörrvakten (curl Firebase REST-API, patchad APK, stulen token) — men valvsdörren sitter på Googles servrar och kan inte pratas förbi. **Den gyllene Firebase-regeln: lita aldrig på klienten.** Att gömma en knapp i Flutter gör ingenting för säkerheten — datan är en HTTP-request bort.

**Fail closed (default deny):** varje permission-helper returnerar deny vid osäkerhet — null user, tomt id, saknad repository, eller ett kastat undantag löses alla till false/null. Smart-lås-analogin: om strömmen dör eller mjukvaran kraschar, förblir låset LÅST. En bugg ska låsa ute, aldrig in.

**Abstrakta metoder tvingar grinden:** `BaseFirebaseRepository` deklarerar de fyra `validate*`-metoderna som abstrakta. Dart kompilerar inte en subklass som inte implementerar dem, och bas-CRUD anropar dem alltid. Att "glömma" en permission-check är strukturellt svårt.

**Server-side dataintegritet:** `firestore.rules` gör mer än ägarskap — validerar dokument-SHAPE (`isValidTagResult` skyddar allergen-data från klient-tampering, säkerhetskritiskt), cappar fältstorlekar (kommentar ≤ 2000), gör fält oföränderliga (`cannotModify`), rate-limitar skrivningar, och har en GDPR-åldersgräns (`birthYear <= year-13`).

**GDPR mappar till tre services:**
- `consent_service` (Artikel 7 — vad gick du med på)
- `data_export_service` (Artikel 20 — ge mig min data)
- `account_deletion_service` (Artikel 17 — radera mig; går genom en Cloud Function med Admin-rättigheter eftersom en vanlig user inte får radera cross-collection-rader; kräver re-auth inom 5 min)

**Att bevisa vs granska rules:** `firebase-backend-security` GRANSKAR rule-diffar genom att läsa dem; `firestore-rules-tester` BEVISAR dem genom att köra emulator-tester. Båda en allow- OCH en deny-väg krävs per gren — att testa att rätt person kommer in bevisar inget om att fel person hålls ute.

**Data-source-regeln:** `userService.currentUserProfile` (full profil/settings) vs `permissionService.currentUserId` (auth/permission-checks ENDAST). Att blanda dem är tyst — skriver till fel objekt och settings persisterar aldrig.

### Riktiga referenser

- `C:/Butlery/butlery/lib/repositories/mixins/permission_validation_mixin.dart` — Vägg 1-verktygslådan
- `C:/Butlery/butlery/lib/repositories/firebase/base_firebase_repository.dart` — där Vägg 1 tvingas (4 abstrakta metoder)
- `C:/Butlery/butlery/firestore.rules` — Vägg 2 (~2000 rader)
- `C:/Butlery/butlery/lib/services/permission_service.dart` — centraliserad auth-service (`currentUserId`)
- `C:/Butlery/butlery/lib/services/permissions/recipe_permission_module.dart` — fail-closed-exempel (`isRecipeOwner` ~rad 244–268)
- `C:/Butlery/butlery/lib/services/account/consent_service.dart` — GDPR Art. 7
- `C:/Butlery/butlery/lib/services/account/account_deletion_service.dart` — GDPR Art. 17
- `C:/Butlery/butlery/lib/services/account/data_export_service.dart` — GDPR Art. 20
- `C:/Butlery/butlery/.claude/agents/firestore-rules-tester.md` — agenten som bevisar rules
- `C:/Butlery/butlery/.claude/skills/data-source-enforcer.md` — data-source-regeln
- `C:/Butlery/butlery/.claude/skills/permission-audit.md` — kvartalssvep

### Kodexempel

```javascript
// firestore.rules — server-side ägarskap + allergen-dataintegritet
allow update: if isOwner(userId)
  && isValidTagResult(request.resource.data.get('core', {}).get('tagResult', null));

// firestore.rules — server-only audit-logg, aldrig klientåtkomst
match /deletion_audit_logs/{logId} { allow read, write: if false; }
```

```dart
// recipe_permission_module.dart — fail closed vid fel
try { final recipe = recipeService.getRecipeById(recipeId); ... }
catch (e) { return false; /* default till säkert (neka åtkomst) */ }
```

### Gotchas

- App-side-checks är INTE säkerhet på egen hand. Tas rules bort = öppen databas, oavsett hur grundlig Dart-koden ser ut.
- Firestore-rules ärvs INTE in i subcollections. Ett parent-`match`-block täcker inte `/votes/{voteId}` under det — varje subcollection-väg behöver eget `match`-block, annars faller den till default-deny tyst (se BUT-773-kommentaren).
- En grön rules-allow-test utan matchande deny-test behandlas som NOLL coverage.
- Account-radering får INTE göras client-side — går genom `requestAccountDeletion` Cloud Function (Admin SDK), kräver re-auth inom 5 min (BUT-788 tog bort det gamla client-side `user.delete()`).
- Commit-hooks tvingar: `firestore.rules`-ändring kräver rules-tester-markern; `lib/**/*.dart` kräver code-reviewer + testing-specialist; repository/service/functions kräver firebase-backend-security.
- Blanda inte data-sources: `PermissionService` = auth/`currentUserId` ENDAST; `UserService.currentUserProfile` = settings/avatar/social.

### Prova nu

Öppna `C:/Butlery/butlery/lib/services/permissions/recipe_permission_module.dart` och läs `isRecipeOwner` (~rad 244–268). Skriv ut, på vanlig svenska, de FEM villkoren under vilka den returnerar false (ej autentiserad, tomt recipeId, recept ej funnet, undantag kastat, ownerId ≠ currentUserId). Svara sedan: varför är false-vid-fel det säkra valet, och vad kunde gå fel om EN gren returnerade true istället?

### Checkpoint

**Fråga:** Du gömmer "Radera recept"-knappen i Flutter-UI för alla som inte är ägaren. Är receptet nu säkert från att raderas av andra?
**Svar:** Nej. Att gömma en knapp är bara UX. En user kan kringgå appen helt och anropa Firebase direkt med sin auth-token. Receptet är bara verkligt skyddat eftersom `firestore.rules` har `allow delete: if isOwner(userId)` som evalueras på Googles servrar — den server-side-regeln, inte den gömda knappen (eller ens Dart-side `validateDeletePermission`), är den icke-kringgångsbara väggen.

---

## Modul 11 — Konventionerna: svenska strängar, design system (fyrkantigt), 500-rader, mixins

**Mål:** Efter den här modulen kan du lägga till en ny UI-sträng korrekt, känna igen ett design-system-brott, och veta vilka mixins/basklasser ny kod måste använda.

### Innehåll

Fem konventioner fångar nykomlingar:

**1. Lokalisering — två ARB-filer + genererade bindningar.** Varje UI-sträng bor i `lib/l10n/app_sv.arb` (svenska, default) OCH `lib/l10n/app_en.arb` (engelska), läses i kod som `context.l10n.<nyckel>`. Varje nyckel måste finnas i BÅDA filerna med matchande `@description`/placeholders. De stora `app_localizations*.dart`-filerna är GENERERADE — redigera dem aldrig för hand. När du sparar en ARB kör en PostToolUse-hook (`regenerate-l10n.sh`) `flutter gen-l10n` automatiskt. **Frasbok-analogin:** ARB-filerna är två parallella frasböcker; din kod säger bara etiketten; en maskin trycker böckerna till en gigantisk uppslagsfil du aldrig rör.

**2. Svenska UI / engelska kommentarer.** Den vanligaste fällan, inverterad mot vad folk tror: användarsynlig text är **svenska** ("Spara", "Ta bort"); ALLA kodkommentarer är **engelska**. Engångsregel: "UI talar svenska, kod talar engelska."

**3. Design system — allt FYRKANTIGT.** Färger kommer från `AppColors` i `lib/theme/app_colors.dart`, inte rå `Color(0x...)`. Mockup-språket är fyrkantigt — `BorderRadius.zero`, inga rundade badges/knappar/FABs/kort. Receptrubriker renderas gemener (`.toLowerCase()`) på detaljsidan. Färg-fällan: `rust` (#8B5A3C) är DEKORATIV ENDAST och får ALDRIG användas för fel — fel har sin egen röd (`error` #C44536). `success` är alias för `forestGreen` (#4A7C59). Opacitet: `withValues(alpha: 0.3)`, ALDRIG deprecaterade `withOpacity(0.3)`.

**4. 500-radersgränsen + facade.** Ingen Dart-fil ska överstiga 500 rader. När logik växer extraherar du sammanhängande ansvar till "manager"-klasser i en undermapp och behåller en tunn facade (`recipe_form` splittas i 9 managers). Receptionist-analogin: en 500-radersfil är en person som gör nio jobb; fixet är nio specialister + en receptionist som vidarebefordrar. Guarden är en mjuk varning (exit 0); ~135 filer är medvetet allowlistade.

**5. Mixins och basklasser är obligatorisk infrastruktur.** Services får alltid `ErrorHandlingMixin` (100% adoption); Firebase-services lägger till `FirebaseServiceMixin`; realtime lägger till `StreamManagementMixin`. Repositories extendar `BaseFirebaseRepository<T>` och MÅSTE ha `PermissionValidationMixin`. ViewModels extendar `ChangeNotifier` + `ErrorHandlingMixin`. `mixin-advisor`-skillen är uppslagstabellen. Bult-på-verktygslåda-analogin: du återuppfinner inte verktyg, du bultar på standardverktygen.

### Riktiga referenser

- `C:\Butlery\butlery\.claude\rules\code-style.md` — 500-gränsen, withValues, kommentarregler
- `C:\Butlery\butlery\.claude\rules\ui-conventions.md` — responsiv layout, Semantics-mönster
- `C:\Butlery\butlery\lib\theme\app_colors.dart` — paletten (rust-vs-error, withValues-syntax)
- `C:\Butlery\butlery\lib\l10n\app_sv.arb` — svensk ARB (template)
- `C:\Butlery\butlery\lib\l10n\app_en.arb` — engelsk ARB
- `C:\Butlery\butlery\lib\l10n\app_localizations.dart` — GENERERAD, rör ej
- `C:\Butlery\butlery\.claude\hooks\regenerate-l10n.sh` — auto-gen-l10n
- `C:\Butlery\butlery\.claude\hooks\file-size-guard.sh` — 500-guarden
- `C:\Butlery\butlery\.claude\skills\mixin-advisor.md` — mixin-uppslagstabeller
- `C:\Butlery\butlery\lib\viewmodels\recipe_form\` — facade-exemplet (9 managers)
- `C:\Butlery\butlery\lib\views\recipe_detail\recipe_detail_shared_widgets.dart` — tre konventioner i en fil (`.toLowerCase()` rad 54, `.withValues(alpha: 0.3)` rad 161, fyrkantig border)
- `C:\Butlery\butlery\lib\views\CLAUDE.md` — views-lagrets mini-guide

### Kodexempel

```dart
recipe.title.toLowerCase(),  // recipe_detail_shared_widgets.dart:54
border: Border.all(color: cs.primary.withValues(alpha: 0.3)),  // rad 161
static const Color rust = Color(0xFF8B5A3C); // dekorativ ENDAST ... ALDRIG fel
```

```json
"recipeCommentVisibleTo": "Synlig för: {audience}"   // app_sv.arb:1816
"recipeCommentVisibleTo": "Visible to: {audience}"   // app_en.arb:1810
```

```dart
class CalculationService with ErrorHandlingMixin { }  // mixin-advisor
// claude:large-file-ok — <skäl>   (file-size-guard-sentinel, första 10 raderna)
```

### Gotchas

- Att redigera `app_localizations*.dart` för hand är bortkastat — de genereras och skrivs över.
- En ARB-nyckel tillagd i ENDAST en av filerna är en defekt — båda måste ha nyckeln med matchande placeholders.
- Svenska vs engelska är inverterat: UI stannar svenska, kommentarer stannar engelska.
- `rust` är INTE en felfärg trots att den ser rödaktig ut — använd `error`.
- FYRKANTIGT = inga rundade hörn någonstans.
- Receptrubriker måste vara gemener på detaljvyn.
- 500-guarden är icke-blockerande — lätt att ignorera; verklig enforcement är facade-konventionen + code review.
- `withOpacity()` kompilerar fortfarande (deprecaterad) — lintern stoppar dig kanske inte, men kodbasen har noll live-användningar.
- Repositories MÅSTE ha `PermissionValidationMixin`; services MÅSTE ha `ErrorHandlingMixin`.
- Genererade filer (`*.g.dart`, `*.freezed.dart`, `*app_localizations*`) är undantagna storleksguarden — behandla dem inte som prejudikat för handskrivna.

### Prova nu

Öppna `lib/views/recipe_detail/recipe_detail_shared_widgets.dart` och hitta tre konventioner som lever ihop: titel med `.toLowerCase()` (~rad 54), en fyrkantig border (`BorderSide`, ingen rundad radie), och en opacitet med `.withValues(alpha: 0.3)` (~rad 161). Öppna sedan `lib/theme/app_colors.dart` och bekräfta att `cs.primary` resolvar till `AppColors.forestGreen` (#4A7C59).

### Checkpoint

**Fråga:** Du behöver en ny knapp med texten "Spara recept". Var hamnar svenska texten, var engelska, vad anropar du i widgeten, och vilken fil får du INTE redigera för hand?
**Svar:** Lägg nyckeln (t.ex. `recipeSaveButton:"Spara recept"`) i `lib/l10n/app_sv.arb` OCH engelska ("Save recipe") i `lib/l10n/app_en.arb` med matchande `@description`/placeholders; referera som `context.l10n.recipeSaveButton`; redigera aldrig de genererade `app_localizations*.dart` för hand — `regenerate-l10n`-hooken bygger om dem via `flutter gen-l10n` när du sparar ARB:en.

---

# DEL 3 — Shippa på riktigt

---

## Modul 12 — Din första ticket: BUT-677 (uppvärmning) → BUT-722 (capstone)

**Mål:** Efter den här modulen har du gjort en hel loop två gånger: en enkel l10n+UI-ändring och en fullständig feature med service, modal, DI, test och alla gates.

### TICKET 1 (uppvärmning) — BUT-677: Lyft fram cross-platform i onboarding-copy

**Målet:** lägg till EN kort svensk värde-prop-rad på onboarding-välkomstskärmen som säger att appen funkar på dator OCH telefon. (Store-screenshots och webbsida är separata, icke-kod-ytor — utanför scope.)

**Mönster att kopiera:** den befintliga `onboardingWelcomeNote`-strängen + dess render.

**Filer som rörs:**
- `C:/Butlery/butlery/lib/l10n/app_sv.arb` (svensk ARB, template)
- `C:/Butlery/butlery/lib/l10n/app_en.arb` (engelsk)
- `C:/Butlery/butlery/lib/views/onboarding/onboarding_welcome_page.dart`
- `C:/Butlery/butlery/lib/l10n/app_localizations*.dart` (genereras automatiskt)

**Steg med exakta prompter:**

1. **Läs ticketen.** Den ber kalla ut att Butlery kör på telefon OCH dator (macOS/Windows/Web) — en arbetsflöde-fördel konkurrenter saknar. Hjälte-raden är "Skriv ut veckomenyn från datorn, laga från telefonen".

2. **Lägg till ARB-nycklarna.** Prompt:
   ```
   I lib/l10n/app_sv.arb, lägg till en ny nyckel onboardingWelcomeCrossPlatform direkt
   efter onboardingWelcomeNote med svenska värdet: "Planera på datorn, laga från
   telefonen — Butlery funkar överallt." Sedan i lib/l10n/app_en.arb, lägg till matchande
   nyckel efter onboardingWelcomeNote med engelska: "Plan on your computer, cook from your
   phone — Butlery works everywhere." Håll JSON-komma-syntaxen korrekt i båda. Lägg INTE
   till ett @-metadata-block — de närliggande onboarding-nycklarna är bara strängar.
   ```

3. **`regenerate-l10n.sh`-hooken tänds automatiskt** när en `app_*.arb` redigeras och kör `flutter gen-l10n`. Bevaka stderr: "✓ regenererad" = OK; "✗ FAILED" = ARB-syntax/placeholder-fel att fixa. (Är flutter inte på PATH skippar hooken med en varning — kör `flutter gen-l10n` manuellt då.)

4. **Lägg till raden i välkomstskärmen.** **Verifiera token-namnen mot den befintliga koden FÖRST** — lita inte på att prompten gissar rätt: prompten nedan antar `AppDimensions.spacingMd`, `AppTextStyles.bodyMedium` och en färg-token, men du måste grep:a `onboarding_welcome_page.dart` för de FAKTISKA tokens grannen `onboardingWelcomeNote` använder. Den befintliga noten använder `AppDimensions.spacingMd` + `AppTextStyles.bodyMedium` + `cs.outline` (INTE `cs.primary`). Bestäm medvetet: vill du att din nya rad ska smälta in (`cs.outline`, samma som noten) eller sticka ut som en differentiator (`cs.primary`)? Båda är giltiga — men välj utifrån vad koden faktiskt har, inte vad prompten råkar säga. Prompt:
   ```
   Öppna först onboarding_welcome_page.dart och visa mig de exakta tokens som
   onboardingWelcomeNote-Text-widgeten använder (spacing, textstil, färg). Lägg sedan,
   efter den widgeten (slutar ~rad 56): const SizedBox(height: <samma spacing som noten>),
   sedan Text(context.l10n.onboardingWelcomeCrossPlatform, style: <samma textstil som
   noten>.copyWith(color: <cs.outline för att matcha noten, ELLER cs.primary för att
   sticka ut — säg vilket du valde och varför>), textAlign: TextAlign.center).
   ```

5. **Verifiera:** `flutter analyze`. Eventuellt `flutter run -d chrome` för att se raden.

6. **Staga allt i ett Bash-anrop:**
   ```
   git add lib/l10n/app_sv.arb lib/l10n/app_en.arb lib/l10n/app_localizations.dart
   lib/l10n/app_localizations_sv.dart lib/l10n/app_localizations_en.dart
   lib/views/onboarding/onboarding_welcome_page.dart
   ```

7. **Försök committa — gates som tänds:**
   - `require-review-before-commit.sh` BLOCKAR: en `*.dart`-fil är staged → `code-reviewer` krävs; `lib/**/*.dart` → `testing-specialist` krävs. (Ingen repository/service/functions/rules → firebase-security & rules-tester tänds INTE.)
   - `require-simplify-before-commit.sh` BLOCKAR tills `/code-review` körts.

8. **Klara gates:**
   ```
   Skicka code-reviewer mot staged diff → touch .claude/state/code-review-done.marker
   Skicka testing-specialist mot staged diff → touch .claude/state/testing-review-done.marker
   Kör /code-review high → touch .claude/state/simplify-done.marker
   ```

9. **Försök committa igen.** Lefthook pre-commit (`lefthook.yml`) kör `dart format` (kan reformatera + re-staga — failar första commit på formatering, re-staga och kör SAMMA meddelande), secret-scan, och `dart analyze --fatal-infos`. Meddelande:
   ```
   feat(onboarding): highlight cross-platform plan-on-desktop-cook-on-phone in welcome copy (BUT-677)

   Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
   ```

10. **Pusha direkt till main** (solo). Flytta BUT-677 mot Done i Linear (notera att store-screenshots + webb-copy återstår som icke-kod-delen).

**Done-kriterier:** ny svensk värde-prop-rad renderas på onboarding-välkomst; nyckeln finns i båda ARB-filerna; genererade filer regenererade + committade; `flutter analyze` passerar; alla markers färska; `dart format` ren; commit på main.

---

### TICKET 2 (capstone) — BUT-722: "Vad är nytt"-release-notes-sheet en gång per version

**Målet:** efter en uppdatering och cold-start, visa ett one-time bottom sheet som listar vad som ändrats i denna version. Visa exakt en gång per version, aldrig på en ny förstagångsinstallation, och hämta changelog-texten från en versionerad lokaliseringsnyckel (`whats_new_1_2_0`) så den är översatt sv + en.

**Mönster att kopiera:** `lib/services/in_app_review_service.dart` rakt igenom (plain service, SharedPreferences-gatad one-time-action, `tryGetSharedPreferences`, injicerbar dependency + clock för test, kraschar aldrig caller, versionerad prefs-nyckel). För modalen: `lib/widgets/cooking/substitution_bottom_sheet.dart` (StatelessWidget + static `show(context)`, fyrkantiga hörn, `surfaceContainerHigh`, alla strängar via `context.l10n`). För build-numret: `lib/core/utils/version_info.dart` (`VersionInfo.buildNumber`).

**Filer som rörs:**
- NY `lib/services/release_notes_service.dart` — kärnlogiken
- NY `lib/widgets/whats_new_sheet.dart` — modalen
- EDIT `lib/l10n/app_en.arb` + `lib/l10n/app_sv.arb` — `whats_new_1_2_0`, `whatsNewTitle`, `whatsNewDismiss`
- EDIT `lib/views/mina_recept_view.dart` — cold-start-triggern (StatefulWidget ~rad 91)
- EDIT `lib/core/di/modules/core_module.dart` — registrera servicen (~rad 109/254)
- NY `test/unit/services/release_notes_service_test.dart`

**Steg med exakta prompter:**

1. **Steg 0 — premisskontroll.** Prompt:
   ```
   Grep lib efter release_notes, whats_new, WhatsNew. Bekräfta att ingen befintlig
   release-notes/changelog-mekanism finns. Bekräfta att VersionInfo.buildNumber populeras
   vid bootstrap och att MinaReceptView är Routes.home-landningsvyn.
   ```

2. **Skriv servicen.** Prompt:
   ```
   Skapa lib/services/release_notes_service.dart modellerad på
   lib/services/in_app_review_service.dart. Den ska INTE extenda BaseService (ren
   SharedPreferences, ingen Firebase). Använd tryGetSharedPreferences(logTag:
   "ReleaseNotesService"). Lagra senast-sedd build under versionerad nyckel
   release_notes_last_seen_build_v1. Lägg till async maybeShouldShow() som: läser
   aktuell build från VersionInfo.buildNumber; om ingen lagrad build finns -> behandla
   som förstagångsinstallation, skriv aktuell build, returnera null (skip); om lagrad
   build skiljer sig från aktuell OCH en lokaliserad changelog-nyckel finns för aktuell
   version -> persistera aktuell build och returnera changelog-nyckelns namn
   (whats_new_1_2_0); annars returnera null. Tillåt injicering av aktuell-build-sträng
   och prefs för test. Returnera null vid fel, kasta aldrig.
   ```

3. **Lägg till lokaliserade nycklar.** Prompt:
   ```
   I lib/l10n/app_en.arb och lib/l10n/app_sv.arb, lägg till tre nycklar enligt befintligt
   nyckel + @nyckel-med-description-format: whats_new_1_2_0 (changelog-body med punkter
   om cooking mode och socialt), whatsNewTitle, whatsNewDismiss. Kör sedan flutter gen-l10n.
   ```

4. **Bygg modalen.** Prompt:
   ```
   Skapa lib/widgets/whats_new_sheet.dart som StatelessWidget med static Future<void>
   show(BuildContext context, String changelogKey) som anropar showModalBottomSheet med
   fyrkantiga hörn (BorderRadius.zero) och surfaceContainerHigh-bakgrund, exakt som
   lib/widgets/cooking/substitution_bottom_sheet.dart. Rendera context.l10n.whatsNewTitle,
   changelog-body, och en dismiss-knapp (whatsNewDismiss) som poppar. Använd AppTextStyles,
   AppDimensions, context.butleryColors.
   ```

5. **Registrera i DI.** Prompt:
   ```
   I lib/core/di/modules/core_module.dart, registrera ReleaseNotesService som
   registerLazySingleton som speglar InAppReviewService-blocket ~rad 254, och lägg till
   den i typ-listan ~rad 109 om den listan används för eager-validering.
   ```

6. **Koppla cold-start-triggern.** Prompt:
   ```
   I lib/views/mina_recept_view.dart initState, lägg till
   WidgetsBinding.instance.addPostFrameCallback((_) async { final key = await
   ServiceLocator.get<ReleaseNotesService>().maybeShouldShow(); if (key != null && mounted)
   WhatsNewSheet.show(context, key); }). Följ addPostFrameCallback-mönstret som andra vyer
   använder; anropa inte ServiceLocator inuti build().
   ```

7. **Skriv unit-testet.** Prompt:
   ```
   Skapa test/unit/services/release_notes_service_test.dart genom att kopiera
   test/unit/services/in_app_review_service_test.dart-scaffoldingen (BaseUnitTest.setupUnit,
   SharedPreferences.setMockInitialValues per test). Täck: förstagångsinstallation ->
   maybeShouldShow returnerar null och lagrar aktuell build; uppgradering från äldre build
   -> returnerar changelog-nyckeln och persisterar aktuell build; redan-sedd aktuell build
   -> returnerar null; andra anrop efter ett show -> returnerar null (idempotent per version).
   ```

8. **Verifiera.** Prompt:
   ```
   Kör dart analyze --fatal-infos på ändrade filer, sedan flutter test
   test/unit/services/release_notes_service_test.dart. Kör dart format på de nya/ändrade
   filerna. Bekräfta allt grönt.
   ```

9. **Committa — gate-sekvensen.** Staga allt i ett Bash-anrop. Gates som tänds:
   - `code-reviewer` (Dart-filer rörda) → `touch .claude/state/code-review-done.marker`
   - `testing-specialist` (`lib/**/*.dart`) → `touch .claude/state/testing-review-done.marker`
   - `/code-review high` → `touch .claude/state/simplify-done.marker`
   - `dart format --set-exit-if-changed lib test` (Build Validation via `lefthook.yml`) — redan kört i steg 8
   - `flutter gen-l10n` måste ha körts efter ARB-redigeringen, annars saknas `context.l10n`-getters och analyze failar.

   **OBS:** `firebase-backend-security` tänds INTE (`release_notes_service.dart` är plain `lib/services/`, inte `firebase|firestore|auth|user|gdpr`). `firestore-rules-tester` tänds INTE (inga rules rörda). Pusha direkt till main.

**Done-kriterier:** `dart analyze --fatal-infos` ren på alla rörda filer; testet passerar med de fyra fallen (förstagångs-skip, uppgradering show + persist, samma-version-skip, idempotent-efter-show-skip); sheet-texten resolvar i sv + en efter `flutter gen-l10n`; cold-start efter en simulerad build-bump visar sheeten exakt en gång och aldrig igen för den buildens, ny installation visar den aldrig; alla fyra gates klarade; pushad till main.

### Riktiga referenser

- BUT-677: `lib/l10n/app_sv.arb`, `lib/l10n/app_en.arb`, `lib/views/onboarding/onboarding_welcome_page.dart`, `lib/l10n/app_localizations.dart`
- BUT-722: `lib/services/in_app_review_service.dart` (mönster), `lib/widgets/cooking/substitution_bottom_sheet.dart` (mönster), `lib/core/utils/version_info.dart`, `lib/utils/shared_preferences_safe.dart`, `lib/views/mina_recept_view.dart`, `lib/core/di/modules/core_module.dart`, `test/unit/services/in_app_review_service_test.dart`
- `lib/l10n/app_sv.arb` / `lib/l10n/app_en.arb` — grep:a befintliga grann-nycklar för faktiska token-/stilval innan du litar på en prompt

### Gotchas

- Lägg INTE `@`-metadata på BUT-677-nyckeln om grannarna inte har det — matcha omgivningens stil.
- **Lita inte på att en prompt gissar rätt token-namn.** BUT-677-prompten nämner `AppDimensions.spacingMd` / `AppTextStyles.bodyMedium` / en färg-token — grep:a `onboarding_welcome_page.dart` och bekräfta vad grannen `onboardingWelcomeNote` faktiskt använder. Noten använder `cs.outline`, inte `cs.primary`; väljer du `cs.primary` är det ett medvetet "stick ut"-val, inte en kopiering av grannen.
- Glömmer du `flutter gen-l10n` efter ARB-redigering saknas `context.l10n`-getters och analyze failar.
- Redigerar du en fil efter att ha touchat en marker → STALE → granska om.
- Kör inte review-agenter på >3 filer samtidigt (timeout) — BUT-722 rör ~6 filer, så batcha agenterna eller splitta committen och touch:a markern efter sista batchen.
- `release_notes_service.dart` triggar INTE firebase-security (det är inte i `firebase|firestore|auth|user|gdpr`-mönstret) — bra exempel på att veta vilka gates som faktiskt tänds.

### Prova nu

Gör BUT-677 från början till slut i repot. När commit blockar, läs blockmeddelandet, kör den agent det ber om, `touch` markern, och committa igen. Notera exakt vilka markers som krävdes (code-review, testing-review, simplify) och vilka som INTE krävdes (firebase-security, rules-tester) — och varför.

### Checkpoint

**Fråga:** I BUT-722, varför triggar `release_notes_service.dart` inte `firebase-backend-security`-gaten, medan en fil i `lib/repositories/` skulle göra det?
**Svar:** Gaten matchar sökvägsmönstret `lib/services/.*(firebase|firestore|auth|user|gdpr)` (och `lib/repositories/`, `functions/src/`). `release_notes_service.dart` är en plain service i `lib/services/` utan något av nyckelorden i namnet, så den matchar inte — bara `code-reviewer` (any `*.dart`) och `testing-specialist` (`lib/**/*.dart`) tänds. En fil i `lib/repositories/` matchar repository-mönstret och kräver dessutom firebase-security-markern.

---

## Modul 13 — Fusklapp & ordlista

**Mål:** Efter den här modulen har du en snabbreferens för kommandon, marker-flödet och alla vibe-coding-termer på svenska.

### Kommando-fusklapp

**Flutter:**
```
flutter analyze                                 # kollar kompilering/lint, inga fel
flutter test test/unit/<fil>_test.dart          # kör ett specifikt test (framåtsnedstreck!)
flutter test test/architecture/architecture_test.dart  # arkitekturguards (osynliga för analyze)
flutter run -d chrome                           # starta appen i webbläsaren
flutter gen-l10n                                # regenerera l10n efter ARB-ändring (auto via hook)
dart format lib test                            # formatera (gateas av Build Validation i lefthook.yml)
dart analyze --fatal-infos                      # strikt analyze (lefthook pre-commit)
```
*Windows-fälla: `flutter test` kan faila på PATH via git-bash — kör via `cmd.bat` som sätter native Windows-PATH.*

**Skills (auto-tändande, ingen åtgärd behövs — laddas när uppgiften matchar):**
`butlery-architecture`, `data-source-enforcer`, `tri-state-validator`, `mixin-advisor`, `repository-generator`, `viewmodel-generator`, `serialization-generator`, `permission-test-generator`, `responsive-layout-validator`, `facade-pattern-detector`, `tagging-domain-knowledge`, `firebase-ingredient-patterns`, `verify`

**Skills (manuella /slash-kommandon — `disable-model-invocation: true`):**
```
/drift-migration      # säker schema-migrering för lokala SQLCipher-DB
/flag-cleanup         # kvartals-audit av feature-flaggor
/permission-audit     # statisk säkerhetssvep av lib/repositories/
/release-notes        # changelog (svenska först + engelska)
```

**/code-review (commit-gate-skill):**
```
/code-review                  # endast triviala enfils-diffar
/code-review high             # default för Dart-diffar
/code-review xhigh            # backend/security: lib/repositories/, lib/services/{firebase|firestore|auth|user|gdpr}, functions/src/, firestore.rules
```

**Marker-flöde (commit-gate-upplåsning):**
```
# 1. Skicka rätt agent mot staged diff (max 3 filer åt gången)
# 2. När den rapporterar rent:
touch .claude/state/code-review-done.marker      # code-reviewer (any *.dart)
touch .claude/state/testing-review-done.marker   # testing-specialist (lib/**/*.dart)
touch .claude/state/firebase-security-done.marker # firebase-backend-security (repos/services/functions)
touch .claude/state/rules-tester-done.marker     # firestore-rules-tester (firestore.rules)
touch .claude/state/simplify-done.marker         # /code-review-gaten
# 3. Försök committa igen
```

**Git (solo-flöde):**
```
git status                    # ALLTID först
git add <filer>               # staga (i samma Bash-anrop som commit)
git commit -m "..."           # committa (gates tänds)
git push                      # pusha direkt till main, ingen branch/PR
```
*Aldrig `--amend`, aldrig `--no-verify`. Failar commit på lefthook-formatering: re-staga allt, committa igen med SAMMA meddelande.*

**Commit-meddelande-footer (obligatorisk):**
```
Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
```

### Vilka gates tänds för vilken diff (snabbtabell)

| Staged-fil | code-review | testing | firebase-sec | rules-tester | simplify |
|---|---|---|---|---|---|
| `lib/views/*.dart` | ✓ | ✓ | | | ✓ |
| `lib/repositories/*.dart` | ✓ | ✓ | ✓ | | ✓ |
| `lib/services/firebase_*.dart` | ✓ | ✓ | ✓ | | ✓ |
| `lib/services/release_notes_service.dart` | ✓ | ✓ | | | ✓ |
| `functions/src/*.ts` | | | ✓ | | |
| `firestore.rules` | | | | ✓ | |
| `docs/*.md` (doc-only) | | | | | |

### Ordlista (vibe-coding-termer på svenska)

- **Vibe coding** — att beskriva *vad* du vill och låta Claude lösa *hur*, inom skyddsräcken.
- **Hook** — litet bash-skript som körs automatiskt på en livscykelhändelse (före/efter ett verktyg, vid stopp). Kan blockera (exit 2) eller bara varna.
- **Gate** — en blockerande hook vid en flaskhals (`git commit`, `ExitPlanMode`).
- **Lefthook** — git pre-commit-hook (`lefthook.yml`) som kör `dart format`, secret-scan (rad 24) och `dart analyze` på OS-git-lagret, oberoende av Claudes egna hooks; kan reformatera filer så att första commit-försöket failar (re-staga, committa igen med samma meddelande).
- **Marker** — en tidsstämpel-fil i `.claude/state/` som bevisar att en granskning körts. Blir "stale" om du redigerar efter att ha touchat den.
- **STALE** — föråldrad marker: filen är nyare än granskningen → gaten blockar igen.
- **Skill** — en Markdown-fusklapp som styr *hur* Claude skriver kod; autoladdas eller `/slash`-anropas.
- **Agent** — en specialist-granskare som granskar en diff *efteråt* (code-reviewer, testing-specialist...).
- **Tier 1/2/3** — agent-nivåer: rekommenderad / commit-tvingad / på begäran.
- **Plan mode** — Claude skriver en plan till `tasks/todo.md` innan komplext arbete; två-anrops-gate.
- **ServiceLocator** — den globala accessorn (`ServiceLocator.get<T>()`) som hämtar en service ur DI-containern.
- **DI (dependency injection)** — objekt registreras centralt vid start; widgets frågar efter dem per typ istället för att bygga dem.
- **ViewModel** — skärmens "hjärna": håller data, kör metoder vid knapptryck, ropar `notifyListeners()`.
- **Repository** — det enda lagret som får röra databasen (Firestore); den enda `FirebaseFirestore.instance` skapas i basklassens konstruktor.
- **Facade** — en tunn koordinator som delegerar till fokuserade manager-filer (för 500-radersgränsen).
- **Mixin** — en "bult-på-verktygslåda" (t.ex. `ErrorHandlingMixin`, `PermissionValidationMixin`).
- **Optimistisk uppdatering** — ändra UI direkt, rulla tillbaka om skrivningen failar.
- **`notifyListeners()`** — "dörrklockan" som väcker prenumererande widgets att rita om.
- **Fail closed (default deny)** — vid osäkerhet, neka åtkomst (smart-lås som förblir låst vid strömavbrott).
- **Two walls / defense in depth** — Dart-checks (Vägg 1, UX/audit) + `firestore.rules` (Vägg 2, den verkliga server-side-väggen).
- **ARB** — JSON-ordbok för UI-strängar (`app_sv.arb` svensk, `app_en.arb` engelsk); genererar `app_localizations*.dart`.
- **l10n** — localization (lokalisering).
- **lessons.md** — den globala self-improvement-loggen; daterad post efter varje rättelse.
- **Knowledge file** — en agents egna append-only anteckningsbok (`<agent>.knowledge.md`).
- **Tier A/B/C/D** — sprint-execute-klassificering: full-auto→Done / UI→In Review / stor refactor→In Review / ops-blockerad→flagga.
- **In Review** — Linear-tillstånd där UI/refactor-arbete parkeras för mänsklig sign-off utan att stoppa loopen.

### Riktiga referenser

- `C:/Butlery/butlery/CLAUDE.md` — kommandolistan, agent-tier-tabellen, `/code-review`-effort-policyn
- `C:/Butlery/butlery/lefthook.yml` — OS-git-lagrets pre-commit: `dart format` + `secret-scan:` (rad 24) + `dart analyze`
- `C:/Butlery/butlery/.claude/state/` — alla markers
- `C:/Butlery/butlery/tasks/lessons.md` — self-improvement-loggen
- `C:/Butlery/butlery/.claude/commands/sprint-execute.md` — Tier A/B/C/D-definitionerna

### Gotchas

- `simplify-done.marker` (legacy-namn) = `/code-review`-gaten, INTE code-reviewer-agentens `code-review-done.marker`. Två olika gates.
- `git commit -a/--all` vidgar scope till staged ∪ modifierade-trackade; plain `git commit` kollar bara staged.
- Touch:a markern bara EFTER sista redigeringen, aldrig före.
- Doc-only-commits (`*.md`) tänder inga gates — hooken tystnar.
- Secret-scanning körs av lefthook (`lefthook.yml`), inte av en Claude PreToolUse-hook — `secret-scan-precommit.sh` är inte inkopplad i `settings.json`, men hemligheter scannas ändå vid varje commit.

### Prova nu

Skriv ner, utan att slå upp, vilka tre markers som krävs för en commit som stagar `lib/views/onboarding/onboarding_welcome_page.dart`. Verifiera sedan mot snabbtabellen ovan.
*(Facit: code-review-done, testing-review-done, simplify-done.)*

### Checkpoint

**Fråga:** Vad är skillnaden mellan `code-review-done.marker` och `simplify-done.marker`?
**Svar:** `code-review-done.marker` produceras av `code-reviewer`-*agenten* (Tier 2, tänds för any `*.dart`). `simplify-done.marker` produceras av `/code-review`-*skillen* via `require-simplify-before-commit.sh` (legacy-namn behållet för att inte krocka). De är två olika gates från två olika hooks som granskar olika saker — du behöver båda för en `.dart`-commit.