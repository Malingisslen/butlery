// Renders one of the legal documents the app itself bundles. The page is a
// shell: the text lives in assets/legal/*.md in the repo, which the
// deploy-hosting workflow copies to /assets/legal/ on the legal site, so the
// hosted page and the in-app view are the same bytes.
(function () {
  'use strict';

  var DOCS = {
    'privacy-sv': { file: 'privacy_policy_sv.md', lang: 'sv', title: 'Integritetspolicy' },
    'privacy-en': { file: 'privacy_policy_en.md', lang: 'en', title: 'Privacy Policy' },
    'terms-sv': { file: 'terms_of_service_sv.md', lang: 'sv', title: 'Användarvillkor' },
    'terms-en': { file: 'terms_of_service_en.md', lang: 'en', title: 'Terms of Service' }
  };

  function escapeHtml(s) {
    return s
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }

  // Inline markdown on already-escaped text: code, bold, links. Only http(s)
  // and mailto links are rendered as links; anything else stays text.
  function inline(s) {
    s = s.replace(/`([^`]+)`/g, '<code>$1</code>');
    s = s.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
    s = s.replace(/(^|[^*\w])\*([^*\n]+)\*(?!\w)/g, '$1<em>$2</em>');
    s = s.replace(/\[([^\]]+)\]\(([^)\s]+)\)/g, function (m, text, href) {
      if (!/^(https?:\/\/|mailto:)/i.test(href)) return m;
      return '<a href="' + href + '" rel="noopener">' + text + '</a>';
    });
    s = s.replace(/(^|[\s(])(https?:\/\/[^\s)<]+)/g, function (m, pre, url) {
      return pre + '<a href="' + url + '" rel="noopener">' + url + '</a>';
    });
    return s;
  }

  function isTableSeparator(line) {
    return /^\|?\s*:?-{2,}:?\s*(\|\s*:?-{2,}:?\s*)*\|?\s*$/.test(line);
  }

  function splitRow(line) {
    var t = line.trim();
    if (t.charAt(0) === '|') t = t.slice(1);
    if (t.charAt(t.length - 1) === '|') t = t.slice(0, -1);
    return t.split('|').map(function (c) { return c.trim(); });
  }

  function render(md) {
    var lines = md.replace(/\r\n?/g, '\n').split('\n');
    var out = [];
    var i = 0;
    var para = [];

    function flushPara() {
      if (para.length) {
        out.push('<p>' + inline(escapeHtml(para.join(' '))) + '</p>');
        para = [];
      }
    }

    var sawText = false;
    while (i < lines.length) {
      var line = lines[i];
      var trimmed = line.trim();

      if (trimmed === '') { flushPara(); i++; continue; }

      // The terms files carry no markdown heading; their first line is the
      // title in capitals.
      if (!sawText && trimmed === trimmed.toUpperCase() && /[A-ZÅÄÖ]{4,}/.test(trimmed) && !/^[#|\-*\d]/.test(trimmed)) {
        out.push('<h1>' + inline(escapeHtml(trimmed)) + '</h1>');
        sawText = true; i++; continue;
      }
      sawText = true;

      var h = /^(#{1,6})\s+(.*)$/.exec(trimmed);
      if (h) {
        flushPara();
        var level = h[1].length;
        out.push('<h' + level + '>' + inline(escapeHtml(h[2])) + '</h' + level + '>');
        i++; continue;
      }

      if (/^(-{3,}|\*{3,})$/.test(trimmed)) { flushPara(); out.push('<hr>'); i++; continue; }

      if (trimmed.charAt(0) === '|' && i + 1 < lines.length && isTableSeparator(lines[i + 1])) {
        flushPara();
        var header = splitRow(trimmed);
        var rows = [];
        i += 2;
        while (i < lines.length && lines[i].trim().charAt(0) === '|') {
          rows.push(splitRow(lines[i]));
          i++;
        }
        var t = '<table><thead><tr>';
        header.forEach(function (c) { t += '<th>' + inline(escapeHtml(c)) + '</th>'; });
        t += '</tr></thead><tbody>';
        rows.forEach(function (r) {
          t += '<tr>';
          r.forEach(function (c) { t += '<td>' + inline(escapeHtml(c)) + '</td>'; });
          t += '</tr>';
        });
        t += '</tbody></table>';
        out.push(t);
        continue;
      }

      if (/^[-*]\s+/.test(trimmed)) {
        flushPara();
        var items = [];
        while (i < lines.length && /^[-*]\s+/.test(lines[i].trim())) {
          items.push(lines[i].trim().replace(/^[-*]\s+/, ''));
          i++;
          // A hard-wrapped item continues on indented lines.
          while (i < lines.length && /^\s+\S/.test(lines[i]) && !/^\s*[-*]\s+/.test(lines[i])) {
            items[items.length - 1] += ' ' + lines[i].trim();
            i++;
          }
        }
        out.push('<ul>' + items.map(function (it) {
          return '<li>' + inline(escapeHtml(it)) + '</li>';
        }).join('') + '</ul>');
        continue;
      }

      if (/^\d+\.\s+/.test(trimmed)) {
        flushPara();
        // Terms use "1. HEADING" lines as section titles; a numbered line
        // followed by a blank line is a heading, a run of them is a list.
        var next = lines[i + 1] === undefined ? '' : lines[i + 1].trim();
        if (next === '' || !/^\d+\.\s+/.test(next)) {
          out.push('<h2>' + inline(escapeHtml(trimmed)) + '</h2>');
          i++; continue;
        }
        var nitems = [];
        while (i < lines.length && /^\d+\.\s+/.test(lines[i].trim())) {
          nitems.push(lines[i].trim().replace(/^\d+\.\s+/, ''));
          i++;
          while (i < lines.length && /^\s+\S/.test(lines[i]) && !/^\s*\d+\.\s+/.test(lines[i])) {
            nitems[nitems.length - 1] += ' ' + lines[i].trim();
            i++;
          }
        }
        out.push('<ol>' + nitems.map(function (it) {
          return '<li>' + inline(escapeHtml(it)) + '</li>';
        }).join('') + '</ol>');
        continue;
      }

      para.push(trimmed);
      i++;
    }
    flushPara();
    return out.join('\n');
  }

  function show(message) {
    var el = document.getElementById('doc');
    el.textContent = message;
  }

  function load() {
    var key = document.body.getAttribute('data-doc');
    var doc = DOCS[key];
    if (!doc) { show('Okänt dokument.'); return; }
    var url = '/assets/legal/' + doc.file;
    fetch(url, { credentials: 'omit' })
      .then(function (r) {
        if (!r.ok) throw new Error('HTTP ' + r.status);
        return r.text();
      })
      .then(function (md) {
        document.getElementById('doc').innerHTML = render(md);
        var first = document.querySelector('#doc h1');
        if (first) document.title = first.textContent + ' – Butlery';
      })
      .catch(function () {
        show(doc.lang === 'sv'
          ? 'Dokumentet kunde inte läsas in. Råtexten finns på ' + url
          : 'The document could not be loaded. The plain text is at ' + url);
      });
  }

  if (typeof module !== 'undefined' && module.exports) {
    module.exports = { render: render };
  } else {
    document.addEventListener('DOMContentLoaded', load);
  }
})();
