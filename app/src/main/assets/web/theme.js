/* Shared by every page: wallpaper-adaptive colours, light/dark/AMOLED, palettes, smart haptics. */
(function () {
  'use strict';
  var UI = window.mkvpui, LS;
  try { LS = window.localStorage; } catch (e) { LS = null; }
  function get(k, d) { try { var v = LS.getItem('mkvp.' + k); return v === null ? d : v; } catch (e) { return d; } }
  function set(k, v) { try { LS.setItem('mkvp.' + k, v); } catch (e) { } }

  var sys = {};
  try { if (UI) sys = JSON.parse(UI.theme()); } catch (e) { sys = {}; }

  /* ---------------- colour helpers ---------------- */
  function hsl(h, s, l) {
    h = ((h % 360) + 360) % 360; s = Math.max(0, Math.min(100, s)) / 100; l = Math.max(0, Math.min(100, l)) / 100;
    var a = s * Math.min(l, 1 - l);
    function f(n) { var k = (n + h / 30) % 12; var c = l - a * Math.max(-1, Math.min(k - 3, Math.min(9 - k, 1))); return Math.round(255 * c).toString(16).padStart(2, '0'); }
    return '#' + f(0) + f(8) + f(4);
  }
  function hexToHsl(hex) {
    var r = parseInt(hex.substr(1, 2), 16) / 255, g = parseInt(hex.substr(3, 2), 16) / 255, b = parseInt(hex.substr(5, 2), 16) / 255;
    var mx = Math.max(r, g, b), mn = Math.min(r, g, b), l = (mx + mn) / 2, h = 0, s = 0, d = mx - mn;
    if (d) {
      s = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn);
      if (mx === r) h = (g - b) / d + (g < b ? 6 : 0); else if (mx === g) h = (b - r) / d + 2; else h = (r - g) / d + 4;
      h *= 60;
    }
    return [h, s * 100, l * 100];
  }

  var PALETTES = [
    ['dynamic', 'Dynamic', null],
    ['rose', 'Rose', 335], ['coral', 'Coral', 12], ['amber', 'Amber', 38], ['forest', 'Forest', 140],
    ['mint', 'Mint', 168], ['ocean', 'Ocean', 207], ['violet', 'Violet', 268], ['mono', 'Mono', -1]
  ];

  var STATUS = {
    dark: { ok: '#8fd6a4', okc: '#1e4a2c', warn: '#f3c56b', warnc: '#4f3a10', bad: '#ffb4ab', badc: '#5e1a17', info: '#b7c8ff', infoc: '#2a3a6b', cool: '#9ad8e6', hot: '#ffb68f' },
    light: { ok: '#1b6b3a', okc: '#c8f0d4', warn: '#7a5600', warnc: '#ffe7b0', bad: '#ba1a1a', badc: '#ffdad6', info: '#2f4fa0', infoc: '#dbe1ff', cool: '#006a74', hot: '#8a4a00' }
  };

  function fromSeed(h, s, mode) {
    var mono = h < 0; if (mono) { h = 0; s = 0; }
    var k = mono ? 0 : 1, sp = mono ? 0 : 78;
    if (mode === 'light') return {
      bg: hsl(h, 22 * k, 97.5), bar: hsl(h, 22 * k, 94), surf: hsl(h, 22 * k, 94.5), surf2: hsl(h, 20 * k, 91), surf3: hsl(h, 18 * k, 87), line: hsl(h, 14 * k, 80),
      on: hsl(h, 20 * k, 11), on2: hsl(h, 12 * k, 27), dim: hsl(h, 8 * k, 41), outline: hsl(h, 8 * k, 50),
      pri: hsl(h, sp * 0.72, 38), onpri: '#ffffff', pricont: hsl(h, sp * 0.95, 90), onpricont: hsl(h, sp * 0.9, 14)
    };
    var amo = mode === 'amoled';
    return {
      bg: amo ? '#000000' : hsl(h, 14 * k, 7), bar: hsl(h, 14 * k, amo ? 6 : 10), surf: hsl(h, 13 * k, amo ? 9 : 13), surf2: hsl(h, 12 * k, amo ? 13 : 17), surf3: hsl(h, 11 * k, amo ? 18 : 22),
      line: hsl(h, 10 * k, 27), on: hsl(h, 22 * k, 90), on2: hsl(h, 14 * k, 77), dim: hsl(h, 8 * k, 61), outline: hsl(h, 8 * k, 55),
      pri: hsl(h, sp, 80), onpri: hsl(h, sp * 0.9, 17), pricont: hsl(h, sp * 0.55, 28), onpricont: hsl(h, sp, 90)
    };
  }
  function fromSystem(mode) {
    var a = sys.a1, n = sys.n1, n2 = sys.n2 || sys.n1;
    if (!a || !n) return null;
    if (mode === 'light') return {
      bg: n['10'], bar: n['50'], surf: n['50'], surf2: n['100'], surf3: n['200'], line: n2['300'],
      on: n['900'], on2: n2['700'], dim: n2['600'], outline: n2['500'],
      pri: a['600'], onpri: a['0'], pricont: a['100'], onpricont: a['900']
    };
    var amo = mode === 'amoled';
    return {
      bg: amo ? '#000000' : n['900'], bar: amo ? n['900'] : n['800'], surf: amo ? n['900'] : n['800'], surf2: amo ? n['800'] : n['700'], surf3: amo ? n['700'] : n['600'], line: n['600'],
      on: n['100'], on2: n2['200'], dim: n2['300'], outline: n2['400'],
      pri: a['200'], onpri: a['800'], pricont: a['700'], onpricont: a['100']
    };
  }

  function currentMode() {
    var m = get('mode', 'auto');
    if (m === 'auto') {
      var dark = window.matchMedia ? window.matchMedia('(prefers-color-scheme: dark)').matches : (sys.night !== false);
      if (sys.night === true || sys.night === false) dark = sys.night;
      return dark ? 'dark' : 'light';
    }
    return m;
  }

  function build() {
    var mode = currentMode(), pal = get('palette', 'dynamic'), c = null;
    if (pal === 'dynamic') {
      c = fromSystem(mode);
      if (!c) {
        var seed = sys.wallpaper ? hexToHsl(sys.wallpaper) : [335, 60, 50];
        c = fromSeed(seed[0], Math.min(seed[1], 70), mode);
      }
    } else {
      var p = PALETTES.filter(function (x) { return x[0] === pal; })[0] || PALETTES[1];
      c = fromSeed(p[2], 70, mode);
    }
    var st = STATUS[mode === 'light' ? 'light' : 'dark'];
    for (var k in st) c[k] = st[k];
    c._mode = mode;
    return c;
  }

  function apply() {
    var c = build(), r = document.documentElement.style, light = c._mode === 'light';
    var V = {
      '--bg': c.bg, '--bar': c.bar, '--surf': c.surf, '--surf2': c.surf2, '--surf3': c.surf3, '--on': c.on, '--on2': c.on2, '--dim': c.dim, '--outline': c.outline, '--line': c.line,
      '--pri': c.pri, '--onpri': c.onpri, '--pricont': c.pricont, '--onpricont': c.onpricont,
      '--ok': c.ok, '--okc': c.okc, '--warn': c.warn, '--warnc': c.warnc, '--bad': c.bad, '--badc': c.badc, '--info': c.info, '--infoc': c.infoc, '--cool': c.cool, '--hot': c.hot,
      /* aliases used by the tools pages */
      '--surface': c.surf, '--surface-2': c.surf2, '--line-soft': c.surf3, '--red': c.pri, '--red-dark': c.pricont, '--red-soft': c.pricont,
      '--text': c.on, '--muted': c.dim, '--onred': c.onpri
    };
    for (var k in V) r.setProperty(k, V[k]);
    r.setProperty('color-scheme', light ? 'light' : 'dark');
    document.documentElement.setAttribute('data-theme', light ? 'light' : 'dark');
    try { if (UI) UI.setBars(c.bar, light); } catch (e) { }
  }
  apply();
  if (window.matchMedia) {
    try { window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', apply); } catch (e) { }
  }

  /* ---------------- haptics ---------------- */
  var HAP = parseInt(get('haptic', '2'), 10), lastH = 0;
  function hap(kind) {
    if (!HAP || !UI || !UI.haptic) return;
    var now = Date.now(); if (now - lastH < 70) return; lastH = now;
    try { UI.haptic(kind, HAP); } catch (e) { }
  }
  window.mkvpHaptic = hap;
  var SEL = 'button,a.hchip,a.lang-btn,.chip,.tab,.ftab,.tab-btn,.item.press,.pkg-item,summary,select,input[type=checkbox],input[type=radio],.seg-toggle button,label.sw,.swatch';
  document.addEventListener('click', function (e) {
    var t = e.target && e.target.closest ? e.target.closest(SEL) : null;
    if (!t || t.disabled || t.getAttribute('aria-disabled') === 'true') return;
    var cls = ' ' + t.className + ' ', id = (t.id || '').toLowerCase();
    if (/ (warn|danger|bad) /.test(cls) || /reboot|erase|wipe|unlock|flash|remove|delete|uninstall/.test(id)) return hap('heavy');
    if (t.matches('input[type=checkbox],input[type=radio],.pkg-item,.chip,.tab,.ftab,.tab-btn,summary,select,.seg-toggle button,.swatch')) return hap('tick');
    if (/ (primary-btn|fill) /.test(cls) || t.classList.contains('primary-btn')) return hap('click');
    hap('click');
  }, true);
  document.addEventListener('DOMContentLoaded', function () {
    var seen = '';
    var obs = new MutationObserver(function (list) {
      list.forEach(function (m) {
        var el = m.target.nodeType === 3 ? m.target.parentNode : m.target;
        if (!el || !el.closest) return;
        var toast = el.closest('#toast,#snack,.toast,.snack'); if (!toast) return;
        var txt = (toast.textContent || '').trim(); if (!txt || txt === seen) return;
        seen = txt; setTimeout(function () { seen = ''; }, 1500);
        if (/fail|error|denied|cannot|can't|unable|invalid|not found|✗|⚠|refus/i.test(txt)) hap('error');
        else if (/done|success|saved|applied|copied|installed|granted|restored|removed|✅|✓|enabled|disabled/i.test(txt)) hap('success');
      });
    });
    obs.observe(document.body, { subtree: true, childList: true, characterData: true });
  });

  /* ---------------- appearance sheet ---------------- */
  var CSS = '.tsb{position:fixed;inset:0;z-index:100;background:rgba(0,0,0,.45);display:none;align-items:flex-end;justify-content:center}' +
    '.tsb.on{display:flex}.tsp{width:100%;max-width:560px;background:var(--surf);color:var(--on);border-radius:28px 28px 0 0;padding:18px 18px calc(22px + env(safe-area-inset-bottom,0px));animation:tsu .22s ease}' +
    '@keyframes tsu{from{transform:translateY(40px);opacity:0}to{transform:none;opacity:1}}' +
    '.tsp h3{margin:2px 0 14px;font-size:18px;font-weight:600;color:var(--on)}.tsp h4{margin:16px 0 8px;font-size:13px;font-weight:600;color:var(--dim);letter-spacing:.4px;text-transform:uppercase}' +
    '.tsr{display:flex;gap:8px;flex-wrap:wrap}.tsr button{border:0;border-radius:999px;padding:9px 15px;font:inherit;font-size:14px;background:var(--surf2);color:var(--on2)}' +
    '.tsr button.on{background:var(--pricont);color:var(--onpricont);font-weight:600}' +
    '.tsw{display:flex;gap:10px;flex-wrap:wrap}.swatch{width:46px;height:46px;border-radius:50%;border:2px solid transparent;display:flex;align-items:center;justify-content:center;padding:0;font-size:10px;color:#fff}' +
    '.swatch.on{border-color:var(--on)}.swatch.dyn{width:auto;border-radius:999px;padding:0 14px;font-size:13px;height:46px;background:var(--surf2);color:var(--on2)}.swatch.dyn.on{background:var(--pricont);color:var(--onpricont)}' +
    '.tsb-btn{border:0;background:var(--surf2);color:var(--on2);width:40px;height:40px;border-radius:50%;display:inline-flex;align-items:center;justify-content:center;flex:none;padding:0;margin-left:6px}' +
    '.tsb-btn svg{width:22px;height:22px}';
  var st = document.createElement('style'); st.textContent = CSS; (document.head || document.documentElement).appendChild(st);

  function swatchColor(p) {
    if (p[0] === 'dynamic') return null;
    return p[2] < 0 ? '#8d8d92' : hsl(p[2], 70, 52);
  }
  function row(items, cur, onPick) {
    var d = document.createElement('div'); d.className = 'tsr';
    items.forEach(function (it) {
      var b = document.createElement('button'); b.textContent = it[1]; if (it[0] === cur) b.className = 'on';
      b.onclick = function () { onPick(it[0]); build2(); }; d.appendChild(b);
    });
    return d;
  }
  var overlay, panel;
  function build2() {
    if (!panel) return;
    panel.innerHTML = '';
    var h = document.createElement('h3'); h.textContent = 'Appearance'; panel.appendChild(h);
    var a = document.createElement('h4'); a.textContent = 'Mode'; panel.appendChild(a);
    panel.appendChild(row([['auto', 'Auto'], ['light', 'Light'], ['dark', 'Dark'], ['amoled', 'AMOLED']], get('mode', 'auto'), function (v) { set('mode', v); apply(); }));
    var b = document.createElement('h4'); b.textContent = 'Colour'; panel.appendChild(b);
    var w = document.createElement('div'); w.className = 'tsw';
    PALETTES.forEach(function (p) {
      var s = document.createElement('button'); var cur = get('palette', 'dynamic') === p[0];
      if (p[0] === 'dynamic') { s.className = 'swatch dyn' + (cur ? ' on' : ''); s.textContent = sys.a1 ? 'Wallpaper (Material You)' : 'Wallpaper'; }
      else { s.className = 'swatch' + (cur ? ' on' : ''); s.style.background = swatchColor(p); s.title = p[1]; }
      s.onclick = function () { set('palette', p[0]); apply(); build2(); };
      w.appendChild(s);
    });
    panel.appendChild(w);
    var c = document.createElement('h4'); c.textContent = 'Vibration'; panel.appendChild(c);
    panel.appendChild(row([['0', 'Off'], ['1', 'Light'], ['2', 'Normal']], String(HAP), function (v) { HAP = parseInt(v, 10); set('haptic', v); hap('click'); }));
  }
  function open() {
    if (!overlay) {
      overlay = document.createElement('div'); overlay.className = 'tsb';
      panel = document.createElement('div'); panel.className = 'tsp';
      overlay.appendChild(panel); document.body.appendChild(overlay);
      overlay.addEventListener('click', function (e) { if (e.target === overlay) overlay.classList.remove('on'); });
    }
    build2(); overlay.classList.add('on');
  }
  document.addEventListener('DOMContentLoaded', function () {
    var host = document.querySelector('.topbar-right') || (document.querySelector('.state') && document.querySelector('.state').parentNode) || document.querySelector('.topbar');
    if (!host) return;
    var btn = document.createElement('button'); btn.className = 'tsb-btn'; btn.setAttribute('aria-label', 'Appearance');
    btn.innerHTML = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3a9 9 0 1 0 0 18c1.4 0 2-1 2-2 0-.6-.3-1.1-.5-1.6-.3-.6-.2-1.4.5-1.9.5-.4 1.1-.5 1.7-.5H18a3 3 0 0 0 3-3A9 9 0 0 0 12 3z"/><circle cx="7.5" cy="11" r="1"/><circle cx="10.5" cy="7" r="1"/><circle cx="15" cy="7.5" r="1"/></svg>';
    btn.onclick = open; host.appendChild(btn);
  });
})();
