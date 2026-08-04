# fas0 · reporotens rapportkatalog

**Reporoten är den här katalogens förälder** — paketet som bär `tools/`, `fas0/`, `.github/` och dokumenten. Det finns ingen andra rot sedan Fas 0.5.

## Kör

```
bash fas0/run-verify.sh
```

Ordning: manifestkontroll → hela kedjan. Slutlig exitkod är 1 om någon del faller.

## Grindarna

```
node tools/gate.mjs --phase=0    # FAS 0-GRINDEN · verktygsintegritet (8 kontroller)
node tools/gate.mjs --phase=1    # FAS 1-GRINDEN · en källa, en version (18 kontroller)
```

Talen räknas om ur `tools/controls.mjs` av metatest **M-34** — de får inte skrivas för hand någon annanstans. Fas 1-grinden innehåller hela Fas 0-grinden, så verktygsintegriteten kan inte regressera obemärkt.

## Filer

| Fil | Roll |
|---|---|
| `run-verify.sh` | kanoniskt kommando |
| `check-manifest.mjs` | hash + set-likhet mot reporotens artefakter |
| `andrade-filer.md` | artefaktmanifestet |
| `kallauktoritetsregister.md` | vilken fil som är normativ per domän |
| `blockerar-fas1.md` | kvarvarande arbete |
| `verify.log` · `manifest.log` · `verify-report.json` · `kontrollstatus.md` | **genereras av körningen** — undantagna ur manifestet |
