'use strict';
// Key figures, common mistakes and sources per Råd topic, plus the glossary. Merged into ADVICE by
// designlabb-advice-ui.js. Figures come from Material Design 3, Apples Human Interface Guidelines
// and WCAG 2.2; a source is named so it can be looked up, never linked, since the lab has no network.

const ADVICE_MORE = {
  farg: {
    nums: [['Grundfärg', 'cirka 60 %'], ['Stödfärg', 'cirka 30 %'], ['Accent', 'cirka 10 %']],
    mistakes: ['Flera likvärdiga accentfärger som slåss om blicken.', 'Rött och grönt som enda skillnad (en av tolv män ser dem inte åtskilda).', 'Ändra en färg som används på många ställen utan att se var den slår igenom.'],
    src: 'Allmän designpraxis; WCAG 1.4.1 (färg ensam får inte bära information)',
  },
  kontrast: {
    nums: [['Brödtext (WCAG AA)', '4,5:1'], ['Stor text och ikoner (AA)', '3:1'], ['Förstärkt nivå (AAA)', '7:1']],
    mistakes: ['Ljusgrå text på vit bakgrund för att det "ser lugnt ut".', 'Text över ett foto utan mörk toning eller platta bakom.', 'Mäta bara i ljust läge och glömma mörkt.'],
    src: 'WCAG 2.2: 1.4.3 Kontrast (minimum), 1.4.11 Kontrast för icke-text',
  },
  morkt: {
    nums: [['Bakgrund', 'mörkgrön eller mörkgrå, inte #000'], ['Text', 'dämpat vitt, inte #fff'], ['Ytor högre upp', 'ljusare än de under']],
    mistakes: ['Samma skuggor som i ljust läge (de syns inte).', 'Mättade färger som "lyser" mot mörkt.', 'Glömma att kontrollera ikoner och kanter.'],
    src: 'Material Design 3 (dark theme), Apple HIG (Dark Mode)',
  },
  typsnitt: {
    nums: [['Typsnitt i appen', '1–2'], ['Tyngder', '2–3 räcker'], ['Brödtext', 'regular 400'], ['Rubriker', 'semibold 600 eller bold 700']],
    mistakes: ['Tre eller fler typsnitt.', 'Mycket tunn text (200–300) i små storlekar.', 'Versaler i långa texter (svårläst).'],
    src: 'Material Design 3 (typography), Apple HIG (typography)',
  },
  textstorlek: {
    nums: [['Brödtext', '16 sp'], ['Minsta text', '12 sp'], ['Appen ska tåla', 'upp till 200 % större text']],
    mistakes: ['Fast textstorlek som struntar i telefonens inställning.', 'Behållare med fast höjd som klipper större text.', 'Allt i samma storlek, så att inget syns som viktigast.'],
    src: 'WCAG 2.2: 1.4.4 Ändra textstorlek; Material 3 type scale',
  },
  radavstand: {
    nums: [['Brödtext', '1,4–1,6 ×'], ['Rubriker', '1,1–1,3 ×'], ['Ska tåla enligt WCAG', '1,5 ×']],
    mistakes: ['Radavstånd under 1,2 på brödtext.', 'Samma radavstånd på rubriker och brödtext.'],
    src: 'WCAG 2.2: 1.4.12 Textavstånd',
  },
  form: {
    nums: [['Kort (Material 3)', '12 dp'], ['Knappar (Material 3)', 'helt runda'], ['Inmatningsfält', '4–12 dp'], ['Skillnad kort/knapp', 'tydlig men inte slumpmässig']],
    mistakes: ['Olika rundning på likadana kort.', 'En liten knapp med stor rundning som blir en boll.', 'Ett barn (innehåll) som är rundare än sin förälder.'],
    src: 'Material Design 3 (shape)',
  },
  marginal: {
    nums: [['Telefon', '16 dp (Material), ofta 20–24'], ['Större skärm', '24 dp eller mer']],
    mistakes: ['Olika marginal på olika sidor av samma vy.', 'Text som ligger mot kanten på smala telefoner.'],
    src: 'Material Design 3 (layout)',
  },
  avstand: {
    nums: [['Rutnät', '4 eller 8 dp'], ['Inom en grupp', '4–8 dp'], ['Mellan grupper', '16–24 dp']],
    mistakes: ['Slumpmässiga mått (13, 17, 22) i stället för ett rutnät.', 'Samma avstånd överallt, så att inget visar vad som hör ihop.'],
    src: 'Material Design 3 (spacing), 8-punktsrutnätet',
  },
  tathet: {
    nums: [['Luftig lista', 'rad 56–72 dp'], ['Tät lista', 'rad 40–48 dp'], ['Absolut minimum', 'trycksyta 44–48 dp']],
    mistakes: ['Gör allt tätt för att få plats utan att kontrollera trycksytor.', 'Bläddrarvyer i admin-täthet.'],
    src: 'Material Design 3 (density)',
  },
  trycksyta: {
    nums: [['Android (Material)', '48 × 48 dp'], ['Apple (HIG)', '44 × 44 pt'], ['WCAG 2.2 AA', 'minst 24 × 24 px'], ['Luft mellan ytor', 'minst 8 dp']],
    mistakes: ['Små kryssrutor med bara själva rutan som yta.', 'Två tätt liggande knappar utan luft.', 'Ikonknappar som är lika stora som ikonen.'],
    src: 'Material 3 (accessibility), Apple HIG (layout), WCAG 2.2: 2.5.8 Målstorlek',
  },
  avdelare: {
    nums: [['Tjocklek', '1 px'], ['Färg', 'dämpad, 10–20 % mörkare än ytan']],
    mistakes: ['Linje under varje rad och dessutom luft och kort (tre signaler för samma sak).'],
    src: 'Material Design 3 (divider)',
  },
  skugga: {
    nums: [['Mjuk skugga', 'suddighet 8–16 px'], ['Styrka', '10–25 %'], ['Höjd (y)', '2–8 px'], ['Dialog/meny', 'större och mjukare']],
    mistakes: ['Svart, hård skugga på allt.', 'Skuggor i mörkt läge som aldrig syns.', 'Olika skuggriktning på olika kort.'],
    src: 'Material Design 3 (elevation)',
  },
  glas: {
    nums: [['Suddning', '8–20 px'], ['Täckning', '60–85 %'], ['Kontroll', 'mät mot ljusaste och mörkaste bakom']],
    mistakes: ['Glas på stora ytor som scrollar (dyrt).', 'Text direkt på glas utan kontrollerad kontrast.'],
    src: 'Apple HIG (materials); Flutter: BackdropFilter kostar prestanda',
  },
  rorelse: {
    nums: [['Små rörelser', '100–250 ms'], ['Större rörelser', '250–400 ms'], ['Loopande', 'pausbar efter 5 s (WCAG)']],
    mistakes: ['Evig puls på flera element samtidigt.', 'Linjär rörelse (känns mekanisk, använd ease).', 'Ingen hänsyn till "minska rörelse".'],
    src: 'Material Design 3 (motion), WCAG 2.2: 2.2.2 Pausa, stoppa, dölj',
  },
  hovring: {
    nums: [['Telefon', 'finns inte'], ['Dator och webb', 'ofta'], ['Tid', '100–200 ms']],
    mistakes: ['Hovring som enda sättet att visa en funktion.', 'Hovring som flyttar layouten.'],
    src: 'Allmän webbpraxis; Material 3 (states)',
  },
  tryck: {
    nums: [['Reaktionstid', 'inom 100 ms'], ['Krympning', '3–6 %'], ['Tid', '80–150 ms']],
    mistakes: ['Ingen reaktion alls (knappen känns död).', 'Kraftig krympning som ser studsig ut.'],
    src: 'Material 3 (states: pressed), Apple HIG (feedback)',
  },
  kant: {
    nums: [['Tunn kant', '1 px'], ['Kontrast mot bakgrund', 'minst 3:1 för fält'], ['Fokusring', '2 px']],
    mistakes: ['Kantlinje som är för svag för att synas.', 'Kant plus skugga plus fyllning på samma sak.'],
    src: 'WCAG 2.2: 1.4.11 Kontrast för icke-text',
  },
  ikonbibliotek: {
    nums: [['Bibliotek per app', '1'], ['Stil per bibliotek', '1'], ['Rutnät', '24 × 24 px']],
    mistakes: ['Blanda linje- och fyllda ikoner.', 'Ikoner från tre olika källor.', 'Ikoner utan text när betydelsen är oklar.'],
    src: 'Material Symbols, Apple SF Symbols, Lucide, Phosphor',
  },
  ikonstil: {
    nums: [['Runda ändar', 'mjukt, vänligt'], ['Kantiga ändar', 'tekniskt, exakt']],
    mistakes: ['Ikoner med runda ändar bredvid ett typsnitt med skarpa hörn.'],
    src: 'Allmän designpraxis',
  },
  ikonstorlek: {
    nums: [['Standard', '24 px'], ['Små', '16–20 px'], ['Stora', '32–48 px'], ['Trycksyta runt', '48 px']],
    mistakes: ['Ikoner under 16 px.', 'Olika storlek på ikoner i samma rad.'],
    src: 'Material Design 3 (icons)',
  },
  ikonlinje: {
    nums: [['24 px-ikon', '1,5–2 px linje'], ['Matchar texten', 'ungefär samma tjocklek']],
    mistakes: ['Hårfina linjer (1 px) som försvinner i solsken.'],
    src: 'Lucide och Phosphor har olika standardlinje; kontrollera i labbet',
  },
  layout: {
    nums: [['Viktigast', 'nära tummen, nedtill'], ['Vänsterkant', 'en gemensam linje'], ['Grupper', 'rubrik + tre till sju poster']],
    mistakes: ['Många lika viktiga saker på samma nivå.', 'Stora hopp mellan vyer så att man tappar bort sig.'],
    src: 'Allmän interaktionsdesign; "tumzonen" (Hoober, 2013)',
  },
  bottenmeny: {
    nums: [['Antal flikar', '3–5'], ['Höjd (Material 3)', '80 dp'], ['Per flik', 'ikon + text ≥ 11–12 sp']],
    mistakes: ['Sex eller fler flikar.', 'Bara ikoner utan text.', 'Aktiv flik som knappt syns.'],
    src: 'Material Design 3 (navigation bar), Apple HIG (tab bars)',
  },
  varianter: {
    nums: [['Jämför', '2–3 åt gången'], ['Ändra', 'en sak i taget']],
    mistakes: ['Ändra fem saker och sedan inte veta vad som gjorde skillnad.'],
    src: 'A/B-tänk',
  },
};
