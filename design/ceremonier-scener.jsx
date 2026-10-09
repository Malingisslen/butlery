/* Butlery — clocheceremonierna i rörelse. Scener för animations-v2.
   Två ceremonier, samma hand: Uppdukningen (startskärmen) och Clochelyftet (i appen). */
const { useScene } = window;

/* Gemensamt för båda — det är detta som gör dem till samma lock. */
const GEM = {
  pivot: [43, 104],   // rotationscentrum i märkets 160-rutnät: kupolens vänstra fäste
  riktning: '+',      // medurs. Förflyttningen anges i LOCKETS EGNA led (rotate före translate,
                      // precis som CSS-transformlistan i startskärmen) — nettot går uppåt-höger.
  mask: 113,          // maskkant = tallrikslinjen
};

const bez = (p1x, p1y, p2x, p2y) => (t) => {
  let lo = 0, hi = 1, u = t;
  for (let i = 0; i < 24; i++) {
    u = (lo + hi) / 2;
    const x = 3 * (1 - u) * (1 - u) * u * p1x + 3 * (1 - u) * u * u * p2x + u * u * u;
    if (x < t) lo = u; else hi = u;
  }
  return 3 * (1 - u) * (1 - u) * u * p1y + 3 * (1 - u) * u * u * p2y + u * u * u;
};
const ceremoni = bez(0.3, 0, 0.15, 1);
const utgang = bez(0.4, 0, 1, 1);
const clamp01 = (v) => Math.max(0, Math.min(1, v));
const mix = (a, b, k) => a + (b - a) * k;
const ramp = (t, a, b) => clamp01((t - a) / (b - a));

/* ---------- gemensamma delar ---------- */

function Marke({ rot, dx, dy, kupolOpacitet, ratt, anga, stroke, angaFran }) {
  return (
    <svg width="500" height="500" viewBox="0 0 160 160" fill="none">
      <path d="M0 113H160" stroke="#ccd1c2" strokeWidth="0.75" strokeDasharray="3 4" />
      <circle cx={GEM.pivot[0]} cy={GEM.pivot[1]} r="2.4" fill="#ce7c1e" />
      <circle cx={GEM.pivot[0]} cy={GEM.pivot[1]} r="6" stroke="#ce7c1e" strokeWidth="0.75" />

      <clipPath id="ovanTallrik">
        <rect x="-60" y="-120" width="280" height={GEM.mask + 120} />
      </clipPath>

      {/* rätten under locket */}
      <g opacity={ratt}>
        <path d="M46 110 C46 97 57 90 66 90 C75 90 86 97 86 110 Z" fill="#ce7c1e" />
        <path d="M80 110 C80 99 89 92 98 92 C107 92 116 99 116 110 Z" fill="#a15a0a" />
      </g>

      {/* ånga */}
      <g opacity={anga} stroke="#93a48d" strokeWidth="1.8" strokeLinecap="round" fill="none">
        <path d={`M64 ${angaFran} c-3 -5 3 -7 0 -${8 + anga * 8}`} />
        <path d={`M80 ${angaFran - 3} c-3 -6 3 -8 0 -${10 + anga * 10}`} />
        <path d={`M96 ${angaFran} c-3 -5 3 -7 0 -${8 + anga * 8}`} />
      </g>

      {/* kupol + knopp */}
      <g clipPath="url(#ovanTallrik)">
        <g opacity={kupolOpacitet} transform={`rotate(${rot} ${GEM.pivot[0]} ${GEM.pivot[1]}) translate(${dx} ${dy})`}>
          <path d="M40.5 104 C40.5 81.09 57.88 64.5 80 64.5 C102.12 64.5 119.5 81.09 119.5 104" stroke={stroke} strokeWidth="7" strokeLinecap="butt" />
          <path d="M80 55V60" stroke="#ce7c1e" strokeWidth="3.5" strokeLinecap="round" />
          <rect x="72" y="48" width="16" height="8" rx="4" fill="#ce7c1e" />
        </g>
      </g>

      <path d="M28 113H132" stroke={stroke} strokeWidth="7" strokeLinecap="round" />
    </svg>
  );
}

function Etikett({ children }) {
  return <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: 1.5, textTransform: 'uppercase', color: '#627061' }}>{children}</div>;
}

function Matvarde({ namn, varde, enhet }) {
  return (
    <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', padding: '8px 0', borderBottom: '1px solid #ccd1c2' }}>
      <span style={{ fontSize: 13, color: '#37453a' }}>{namn}</span>
      <span style={{ fontSize: 15, fontWeight: 700, color: '#24382c', fontVariantNumeric: 'tabular-nums' }}>
        {varde}<span style={{ fontSize: 11, fontWeight: 600, color: '#627061', marginLeft: 3 }}>{enhet}</span>
      </span>
    </div>
  );
}

function Blad({ titel, ingress, morkt, marke, fas, ms, varden, last }) {
  const bg = morkt ? '#24382c' : '#F5F4ED';
  const txt = morkt ? '#f5f4ed' : '#24382c';
  const dampad = morkt ? '#93a48d' : '#627061';
  return (
    <div style={{ width: 1280, height: 720, background: bg, color: txt, fontFamily: "'Butlery Sans','Albert Sans',sans-serif", display: 'grid', gridTemplateColumns: '1fr 430px', boxSizing: 'border-box' }}>
      <div style={{ position: 'relative', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        {marke}
        <div style={{ position: 'absolute', left: 56, top: 48 }}>
          <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: 1.5, textTransform: 'uppercase', color: morkt ? '#e0c9a8' : '#627061' }}>Butlery · ceremonier</div>
          <div style={{ fontSize: 34, fontWeight: 700, letterSpacing: -0.8, marginTop: 8 }}>{titel}</div>
          <div style={{ fontSize: 13, color: dampad, marginTop: 6, maxWidth: 320, lineHeight: 1.5 }}>{ingress}</div>
        </div>
        <div style={{ position: 'absolute', left: 56, bottom: 44, display: 'flex', alignItems: 'center', gap: 12 }}>
          <span style={{ width: 22, height: 4, background: '#ce7c1e', borderRadius: 2 }} />
          <span style={{ fontSize: 12, color: dampad }}>Saffransring = rotationscentrum 43 · 104, gemensamt för båda ceremonierna</span>
        </div>
      </div>

      <div style={{ background: '#e6ead9', color: '#24382c', padding: '52px 44px', boxSizing: 'border-box' }}>
        <Etikett>Fas</Etikett>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 10, marginTop: 6 }}>
          <span style={{ fontSize: 28, fontWeight: 700, letterSpacing: -0.6 }}>{fas}</span>
          <span style={{ fontSize: 14, color: '#627061', fontVariantNumeric: 'tabular-nums' }}>{ms}</span>
        </div>
        <div style={{ marginTop: 22 }}>
          <Etikett>Live</Etikett>
          <div style={{ marginTop: 4, borderTop: '1px solid #24382c' }}>
            {varden.map((v) => <Matvarde key={v.namn} {...v} />)}
          </div>
        </div>
        <div style={{ marginTop: 26 }}>
          <Etikett>Låst</Etikett>
          <div style={{ marginTop: 10, fontSize: 12.5, color: '#37453a', lineHeight: 1.8 }}>{last}</div>
        </div>
      </div>
    </div>
  );
}

/* ---------- 1. Uppdukningen — produktens 400 ms lyft, visad som 5 s demoloop ---------- */

function Uppdukning() {
  const { progress } = useScene();
  const p = progress;

  /* DOKUMENTATIONSDEMO — 5 000 ms loop. Detta är INTE produktens tidslinje.
     Produktmotionen är: lyft 400 ms (0,3 0 0,15 1) → navigation. Demon sträcker
     lyftet 4× så att formen går att läsa; se PRODUKT nedan för mappningen. */
  const T = { vila: 0.14, avvinkel: 0.46, lamnar: 0.56, rattIn: 0.60, hall: 0.78, rattUt: 0.86, ater: 1.0 };

  let rot = 0, dx = 0, dy = 0, kupol = 1, fas = 'Vila';
  if (p < T.vila) {
    fas = 'Vila';
  } else if (p < T.avvinkel) {
    const k = ceremoni(ramp(p, T.vila, T.avvinkel));
    rot = mix(0, 20, k); dx = mix(0, -5, k); dy = mix(0, -34, k);
    fas = 'Locket vinklas av';
  } else if (p < T.lamnar) {
    const k = ramp(p, T.avvinkel, T.lamnar);
    rot = mix(20, 34, k); dx = mix(-5, -12, k); dy = mix(-34, -64, k); kupol = 1 - k;
    fas = 'Locket lämnar';
  } else if (p < T.rattUt) {
    rot = 34; dx = -12; dy = -64; kupol = 0;
    fas = p < T.rattIn ? 'Locket borta' : p < T.hall ? 'Rätten dukad' : 'Rätten tonar ut';
  } else {
    /* clocheReturn — 200 ms i produkten. Locket färdas TILLBAKA samma bana,
       det hoppar inte. Opaciteten tonar in under första tredjedelen av banan. */
    const k = utgang(ramp(p, T.rattUt, T.ater));
    rot = mix(34, 0, k); dx = mix(-12, 0, k); dy = mix(-64, 0, k);
    kupol = clamp01(k / 0.34);
    fas = 'Locket åter (clocheReturn)';
  }

  /* Rätten tonar in FÖRST när kupolen är helt borta (p ≥ 0,56), aldrig före. */
  const ratt = p < T.lamnar ? 0
    : p < T.rattIn ? ramp(p, T.lamnar, T.rattIn)
    : p < T.hall ? 1
    : 1 - ramp(p, T.hall, T.rattUt);
  const anga = p < T.rattIn ? 0
    : p < 0.68 ? ramp(p, T.rattIn, 0.68) * 0.5
    : p < T.hall ? mix(0.5, 0, ramp(p, 0.68, T.hall)) : 0;

  return (
    <Blad
      morkt
      titel="Uppdukningen"
      ingress="Endast startskärmen. Locket lyfts av och lämnar bilden, rätten avslöjas, locket färdas tillbaka samma bana. Demon är en långsam loop — produkten navigerar efter 400 ms."
      marke={<Marke rot={rot} dx={dx} dy={dy} kupolOpacitet={kupol} ratt={ratt} anga={anga} angaFran={92} stroke="#F5F4ED" />}
      fas={fas}
      ms={`${Math.round(p * 5000)} ms av 5000 (demo)`}
      varden={[
        { namn: 'Rotation', varde: rot.toFixed(1), enhet: '°' },
        { namn: 'Förflyttning (lokal)', varde: `${dx.toFixed(1)} · ${dy.toFixed(1)}`, enhet: '/160' },
        { namn: 'Kupolens opacitet', varde: Math.round(kupol * 100), enhet: '%' },
        { namn: 'Rätten', varde: Math.round(ratt * 100), enhet: '%' },
        { namn: 'Produkttid', varde: Math.round(p * 5000 / 4), enhet: 'ms' },
      ]}
      last={<>
        <b style={{ color: '#9c3b23' }}>Två tidslinjer — blanda dem aldrig.</b><br />
        <b>PRODUKT:</b> lyft <b>400 ms</b> (0,3 0 0,15 1) → navigation sker <b>vid lyftets slut</b>, inte efter rätten. Rätten och återgången är kallstartens fortsättning och visas bara om appen fortfarande laddar. clocheReturn <b>200 ms</b> (0,4 0 1 1). Ingen loop i produkten — cykeln körs en gång.<br />
        <b>DEMO:</b> 5 000 ms loop, tidsskala <b>4×</b> långsammare, så att banan går att läsa. Demon är illustrativ och aldrig normativ.<br />
        <b>Rotationscentrum</b> 43 · 104 — samma som clochelyftet.<br />
        <b>Riktning</b> medurs. Locket vinklas av <b>uppåt-höger</b>, aldrig åt vänster.<br />
        <b>Bana</b> i lockets egna led: 0 → +20° / (−5 · −34) → +34° / (−12 · −64). <b>Återgången följer samma bana baklänges</b> — inget hopp till startläget.<br />
        <b>Rätten</b> tonar in först när kupolens opacitet är 0 (56 % av demon), aldrig medan locket syns.<br />
        <b>Reducerad rörelse</b> — stillbild: märket utan lock, rätten synlig, ingen ånga.
      </>}
    />
  );
}

/* ---------- 2. Clochelyftet — i appen, 400 ms ---------- */

const L = { vila: 0.5, lyft: 0.9, hall: 1.9, ater: 2.1 };
const LYFT = { rot: 6, dx: 2, dy: -16 }; // lokal led; netto ≈ (+3,7 · −15,7) i märkets rutnät

function Clochelyft() {
  const { localTime: t } = useScene();
  let k = 0, fas = 'Vila', ms = '0 ms';
  if (t < L.vila) { k = 0; }
  else if (t < L.lyft) { const p = ramp(t, L.vila, L.lyft); k = ceremoni(p); fas = 'Lyft'; ms = `${Math.round(p * 400)} ms av 400`; }
  else if (t < L.hall) { k = 1; fas = 'Håll'; ms = '400 ms'; }
  else if (t < L.ater) { const p = ramp(t, L.hall, L.ater); k = 1 - utgang(p); fas = 'Återgång'; ms = `${Math.round(p * 200)} ms av 200`; }

  const anga = clamp01((k - 0.55) / 0.45);

  return (
    <Blad
      titel="Clochelyftet"
      ingress="Onboardingens slut och veckan som blir komplett. Locket tippar och återgår — det lämnar aldrig bilden och märket blankas aldrig ut. 400 ms in, 200 ms ut."
      marke={<Marke rot={LYFT.rot * k} dx={LYFT.dx * k} dy={LYFT.dy * k} kupolOpacitet={1} ratt={0} anga={anga} angaFran={110} stroke="#24382c" />}
      fas={fas}
      ms={ms}
      varden={[
        { namn: 'Rotation', varde: (LYFT.rot * k).toFixed(1), enhet: '°' },
        { namn: 'Förflyttning (lokal)', varde: `${(LYFT.dx * k).toFixed(1)} · ${(LYFT.dy * k).toFixed(1)}`, enhet: '/160' },
        { namn: 'Ånga', varde: Math.round(anga * 100), enhet: '%' },
      ]}
      last={<>
        <b>Rotationscentrum</b> 43 · 104 — samma som uppdukningen.<br />
        <b>Riktning</b> medurs, samma hand — uppåt-höger. Toppläge <b>+6°</b> och lokal förflyttning <b>(+2 · −16)</b>, vilket ger (+3,7 · −15,7) i märkets rutnät.<br />
        <b>Kupolen stannar</b> — ingen opacitet, ingen rätt avslöjas. Detta är en gest, inte en avtäckning.<br />
        <b>Maskkant</b> y = 113 genom hela lyftet.<br />
        <b>Tid</b> 400 ms in · (0,3 0 0,15 1) — 200 ms ut · (0,4 0 1 1).<br />
        <b>Ånga</b> ur springan efter 55 % av lyftet, aldrig vid knoppen.<br />
        <b>Reducerad rörelse</b> — stillbild i toppläget, ingen ånga.
      </>}
    />
  );
}

window.Uppdukning = Uppdukning;
window.Clochelyft = Clochelyft;
