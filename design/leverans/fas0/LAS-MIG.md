# fas0 i ZIP-roten är TOM sedan Fas 0.5

**Reporoten är paketet:**
`uploads/Butlery Skarmar etapp 3 onboarding/Butlery design uppdatering v12/`

Där ligger allt: `tools/`, `fas0/` (wrapper, manifest, checker, register), `.github/workflows/verify.yml` och rapporterna. Kör därifrån:

```
cd "uploads/Butlery Skarmar etapp 3 onboarding/Butlery design uppdatering v12"
bash fas0/run-verify.sh
```

Fas 0.4 hade två rötter — manifestet i ZIP-roten och workflowen i paketet — vilket gjorde att CI antingen inte hittade någon workflow eller alltid rapporterade manifestet som failed. Konsoliderat 2026-08-01.

## Grind och total är två frågor

```
bash fas0/run-verify.sh          # kedjan + manifest · TOTALEN, får vara röd
node tools/gate.mjs --phase=0    # FAS 0-GRINDEN · avgör om fasen kan stängas

BUTLERY_PHASE=1 bash fas0/run-verify.sh   # samma kedja, rapporten räknas för fas 1
node tools/finalize.mjs
node tools/gate.mjs --phase=1    # FAS 1-GRINDEN · en källa, en version (18 kontroller)
```

Grindkommandot läser den färdiga rapporten och kör inte kedjan igen. Innehållsfynd (kontrast, träffytor, geometri, skärmbevis) bär `requiredForGate: []` och blockerar ingen grind. Grinden bedömer bara en rapport som räknats för **samma** fas, därför är det två körningar — Fas 1-grinden innehåller hela Fas 0-grinden, så verktygsintegriteten kan inte regressera obemärkt.

## Leveransmarkör

`fas0/DELIVERY` i ZIP-roten säger att detta är en **leverans**, inte en repocheckout. Manifestkontrollen väljer då `delivery`-läge, där varje `zip:/`-post är obligatorisk.
