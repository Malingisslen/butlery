# Licenser · Butlery runtime-bundle

Den här filen ligger bredvid det som paketeras i appen och namnger allt tredjepartsmaterial. Uppdaterad **2026-07-30** (Butlery Sans 0.626).

---

## Butlery Sans 0.626 — SIL Open Font License 1.1

Butlery Sans är ett **modifierat och omdöpt OFL-1.1-derivat** med källmaterial från **Mona Sans**, **Albert Sans** och **DM Sans**. **Namnet och Butlerys egna ändringar tillhör Butlery**; fontprogramvaran — inklusive våra ändringar — distribueras fortsatt under OFL 1.1 och kan inte göras proprietär eller exklusiv. De reserverade familjenamnen används inte i derivatet: Mona Sans reserverar *Mona*, och Butlery Sans bär inget upstream-reserverat namn.

Formuleringen ”Butlery Sans är inte ett egenutvecklat typsnitt” stod här tidigare. Den var för kategorisk och är struken 2026-07-30 (beslut **B-42**).

### Vad som måste följa med varje distribuerad build

1. **Licenstexten.** `assets/fonts/OFL-1.1.txt` — den oförändrade OFL 1.1. En enda fil ersätter de tidigare tre kopiorna, som hade dubblerade inledningsrader.
2. **Upphovsrättsnoteringarna oförändrade.** `assets/fonts/THIRD_PARTY_NOTICES.txt` bär dem samlade:
   - Copyright 2022 The Mona Sans Project Authors (https://github.com/github/mona-sans), with Reserved Font Name "Mona"
   - Copyright 2021 The Albert Sans Project Authors (https://github.com/usted/Albert-Sans)
   - Copyright 2014 The DM Sans Project Authors (https://github.com/googlefonts/dm-fonts)
   - Copyright 2026 Butlery (modifications)
3. **En hittbar väg i appen.** Dokumenten ska nås via en verklig rutt — *Inställningar → Om → Licenser*. Att filerna finns i bundlen räcker inte om ingen kan öppna dem.

**Kopiera hela `app-assets`-katalogen, inte bara fontbinärerna.** Det var precis felet i 0.625: mappen innehöll sex stilar och noll licenstexter.

### Vad 0.626 rättade

Metadata-only, verifierat i `assets/fonts/VALIDATION-0.626.txt`: **18 av 18 filer** rapporterar version 0.626 och identisk attribution (kursivfilerna krediterade tidigare bara Mona Sans), licenstexten är konsoliderad, och `app-assets` bär nu licenser, versionsfil och manifest. **Inga glyfer, mått, spacing, kerning, OpenType-tabeller eller hinting är ändrade** — 24 av 24 referensrenderingar är pixelidentiska med 0.625 vid 10, 13, 26 och 64 px. Byte av version påverkar alltså ingen ritning i specen.

### Ordning och släktskap

`FONTLOG.txt` bär ändringsloggen och tackorden. Ingen av källprojekten stödjer eller godkänner den modifierade versionen — det är OFL:s krav och står i noteringarna.

---

## Ikoner

Egen familj, ritad för Butlery. Inget bibliotek, ingen extern licens — beslut **B-02**. Se `icons.json` → `decision`.

## Illustrationer och logotyper

Egenproducerade. Inga tredjepartsrättigheter.

## Varumärkesfärger i importkällor

YouTube, Instagram, TikTok och ICA används som **källmärkning** i importflödet. Färgerna och namnen tillhör respektive innehavare och används beskrivande, aldrig som Butlerys egna.
