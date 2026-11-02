/* MkVenomPro Hardware Info - Device Info HW style (all data read live on the device through root) */
(function () {
  'use strict';
  var LANG = 'en';
  try { LANG = localStorage.getItem('hpk_lang') || 'en'; } catch (e) { }
  var TT = function (e, a) { return LANG === 'ar' ? a : e; };
  var $ = function (id) { return document.getElementById(id); };

  var SECTIONS = [
    ['dashboard', 'Dashboard', 'الرئيسية'],
    ['monitor', 'Monitor', 'المراقبة'],
    ['cpu', 'CPU', 'المعالج'],
    ['gpu', 'GPU', 'كرت الشاشة'],
    ['display', 'Display', 'الشاشة'],
    ['memory', 'Memory', 'الرام'],
    ['storage', 'Storage', 'التخزين'],
    ['partitions', 'Partitions', 'البارتشنات'],
    ['battery', 'Battery', 'البطارية'],
    ['camera', 'Camera', 'الكاميرا'],
    ['sensors', 'Sensors', 'الحساسات'],
    ['network', 'Network', 'الشبكة'],
    ['audio', 'Audio', 'الصوت'],
    ['drivers', 'Drivers', 'الدرايفرات'],
    ['buses', 'I2C / SPI', 'I2C / SPI'],
    ['pmic', 'PMIC', 'PMIC'],
    ['thermal', 'Thermal', 'الحرارة'],
    ['usb', 'USB', 'USB'],
    ['system', 'System', 'النظام'],
    ['features', 'Features', 'الميزات'],
    ['props', 'Build props', 'الخصائص']
  ];
  var CMDS = null, cache = {}, cur = 'dashboard', timer = null, token = 0, busyLoad = false;

  function toast(m) { var t = $('toast'); t.textContent = m; t.classList.add('show'); clearTimeout(toast._t); toast._t = setTimeout(function () { t.classList.remove('show'); }, 2200); }
  function hasBridge() { return typeof window.ksu !== 'undefined' && typeof window.ksu.exec === 'function'; }
  var cbn = 0;
  function exec(cmd, ms) {
    return new Promise(function (res) {
      if (!hasBridge()) { res({ code: -1, out: '', err: 'no-bridge' }); return; }
      var n = 'inf_cb_' + (cbn++), done = false;
      var t = setTimeout(function () { if (!done) { done = true; delete window[n]; res({ code: -2, out: '', err: 'timeout' }); } }, ms || 40000);
      window[n] = function (c, o, e) { if (done) return; done = true; clearTimeout(t); delete window[n]; res({ code: c, out: o || '', err: e || '' }); };
      try { window.ksu.exec(cmd, '{}', n); } catch (e) { if (!done) { done = true; clearTimeout(t); delete window[n]; res({ code: -3, out: '', err: String(e) }); } }
    });
  }

  function loadCmds() {
    if (CMDS) return Promise.resolve(CMDS);
    return fetch('info_cmds.txt').then(function (r) { return r.text(); }).then(function (txt) {
      var o = {}, parts = txt.split(/^#### (\w+)\n/m);
      for (var i = 1; i < parts.length; i += 2) o[parts[i]] = parts[i + 1];
      CMDS = o; return o;
    });
  }
  function runSection(id, ms) {
    return loadCmds().then(function (c) {
      var body = c[id]; if (body == null) return { out: '' };
      var script = (id === 'monitor' ? '' : c.pre + '\n') + body;
      return exec(script, ms);
    });
  }

  /* ---- parsing / rendering ---- */
  function parse(out) {
    var items = [], lines = out.split('\n');
    for (var i = 0; i < lines.length; i++) {
      var l = lines[i].replace(/\r$/, '');
      if (!l.trim()) continue;
      if (l.indexOf('## ') === 0) { items.push({ t: 'g', v: l.slice(3) }); continue; }
      if (l.indexOf('!B|') === 0) { var p = l.split('|'); items.push({ t: 'b', k: p[1], p: parseInt(p[2], 10) || 0, v: p.slice(3).join('|') }); continue; }
      var ix = l.indexOf('|');
      if (ix > 0) { var k = l.slice(0, ix), v = l.slice(ix + 1).trim(); if (v === '') continue; items.push({ t: 'r', k: k, v: v }); }
      else items.push({ t: 'r', k: '.', v: l.trim() });
    }
    return items;
  }
  function esc(s) { return String(s).replace(/[&<>"]/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]; }); }
  function render(items, filter) {
    var f = (filter || '').toLowerCase(), html = '', grp = null, buf = '', gcount = 0;
    function flush() { if (grp !== null && buf) html += '<div class="grp">' + esc(grp) + '</div><div class="igroup">' + buf + '</div>'; else if (grp === null && buf) html += '<div class="igroup">' + buf + '</div>'; buf = ''; }
    items.forEach(function (it) {
      if (it.t === 'g') { flush(); grp = it.v; return; }
      if (f && (it.k + ' ' + it.v).toLowerCase().indexOf(f) < 0) return;
      gcount++;
      if (it.t === 'b') {
        var cls = it.p >= 90 ? 'd' : it.p >= 75 ? 'w' : '';
        buf += '<div class="ibar"><div class="t"><span>' + esc(it.k) + '</span><span>' + esc(it.v) + '</span></div><div class="trk"><i class="' + cls + '" style="width:' + Math.max(0, Math.min(100, it.p)) + '%"></i></div></div>';
      } else if (it.k === '.' || it.v.length > 70 || it.k.length > 34) {
        buf += '<div class="irow wide' + (it.k === '.' ? ' mono' : '') + '">' + (it.k === '.' ? '' : '<div class="ik">' + esc(it.k) + '</div>') + '<div class="iv">' + esc(it.v) + '</div></div>';
      } else {
        buf += '<div class="irow"><div class="ik">' + esc(it.k) + '</div><div class="iv">' + esc(it.v) + '</div></div>';
      }
    });
    flush();
    return gcount ? html : '<div class="empty">' + TT('No data (needs root, or not supported on this device)', 'مفيش بيانات (محتاج روت أو الجهاز مش داعمها)') + '</div>';
  }

  /* ---- navigation ---- */
  function buildNav() {
    var nav = $('secNav'); nav.innerHTML = '';
    SECTIONS.forEach(function (s) {
      var b = document.createElement('button');
      b.textContent = TT(s[1], s[2]); b.dataset.id = s[0];
      if (s[0] === cur) b.className = 'on';
      b.onclick = function () { show(s[0]); };
      nav.appendChild(b);
    });
  }
  function markNav() {
    var bs = $('secNav').children;
    for (var i = 0; i < bs.length; i++) { var on = bs[i].dataset.id === cur; bs[i].className = on ? 'on' : ''; if (on && bs[i].scrollIntoView) bs[i].scrollIntoView({ inline: 'center', block: 'nearest' }); }
  }
  function stopMon() { if (timer) { clearInterval(timer); timer = null; } }

  function show(id, force) {
    cur = id; stopMon(); markNav();
    var my = ++token, view = $('view');
    $('q').value = ''; $('q').parentNode.style.display = id === 'monitor' ? 'none' : '';
    renderActs();
    if (!hasBridge()) { view.innerHTML = '<div class="empty">' + TT('Open this from the MkVenomPro app (root bridge not found).', 'افتحها من تطبيق MkVenomPro (جسر الروت مش موجود).') + '</div>'; return; }
    if (id === 'monitor') { startMonitor(my); return; }
    if (cache[id] && !force) { view.innerHTML = render(cache[id], ''); return; }
    view.innerHTML = '<div class="busy">' + TT('Reading…', 'بيقرأ…') + '</div>';
    runSection(id, id === 'cpu' ? 20000 : 45000).then(function (r) {
      if (my !== token) return;
      cache[id] = parse(r.out || '');
      if (r.code === -2) cache[id] = [];
      view.innerHTML = render(cache[id], $('q').value);
    });
  }

  /* ---- live monitor ---- */
  var prevStat = null;
  function startMonitor(my) {
    prevStat = null;
    $('view').innerHTML = '<div id="mon"><div class="busy">' + TT('Reading…', 'بيقرأ…') + '</div></div>';
    var tick = function () {
      if (busyLoad || document.hidden) return; busyLoad = true;
      runSection('monitor', 8000).then(function (r) { busyLoad = false; if (my === token && cur === 'monitor') drawMonitor(r.out || ''); });
    };
    tick(); timer = setInterval(tick, 2000);
  }
  function bar(label, p, txt) {
    var cls = p >= 90 ? 'd' : p >= 75 ? 'w' : '';
    return '<div class="ibar"><div class="t"><span>' + esc(label) + '</span><span>' + esc(txt) + '</span></div><div class="trk"><i class="' + cls + '" style="width:' + Math.max(0, Math.min(100, p)) + '%"></i></div></div>';
  }
  function drawMonitor(out) {
    var stat = {}, freq = {}, mem = null, bat = null, gpu = null, zones = [];
    out.split('\n').forEach(function (l) {
      var p = l.split('|');
      if (p[0] === 'S') stat[p[1]] = [+p[2], +p[3]];
      else if (p[0] === 'F') freq[p[1]] = +p[2];
      else if (p[0] === 'M') mem = [+p[1], +p[2]];
      else if (p[0] === 'B') bat = p;
      else if (p[0] === 'G') gpu = p;
      else if (p[0] === 'Z') { var t = +p[2]; if (p[1] && !isNaN(t)) zones.push([p[1], t >= 1000 ? t / 1000 : t]); }
    });
    var html = '';
    var tot = stat.cpu, usage = {};
    if (prevStat) for (var k in stat) { var a = prevStat[k], b = stat[k]; if (a && b) { var dt = b[0] - a[0], di = b[1] - a[1]; usage[k] = dt > 0 ? Math.round((dt - di) * 100 / dt) : 0; } }
    prevStat = stat;
    html += '<div class="grp">CPU</div><div class="igroup">' + (usage.cpu != null ? bar(TT('Total', 'الإجمالي'), usage.cpu, usage.cpu + ' %') : '<div class="busy">…</div>') + '</div><div class="grp"></div><div class="mcore">';
    Object.keys(freq).sort(function (x, y) { return parseInt(x.slice(3)) - parseInt(y.slice(3)); }).forEach(function (c) {
      var u = usage[c], fr = freq[c];
      html += '<div class="mcell"><div class="t"><span>' + c + '</span><b>' + (fr ? Math.round(fr / 1000) + ' MHz' : 'off') + '</b></div><div class="trk"><i style="width:' + (u || 0) + '%"></i></div></div>';
    });
    html += '</div>';
    html += '<div class="grp">' + TT('Memory', 'الرام') + '</div><div class="igroup">';
    if (mem && mem[0]) { var used = mem[0] - mem[1]; html += bar('RAM', Math.round(used * 100 / mem[0]), Math.round(used / 1024) + ' / ' + Math.round(mem[0] / 1024) + ' MB'); }
    html += '</div>';
    if (gpu) { var gf = +gpu[1]; html += '<div class="grp">GPU</div><div class="igroup"><div class="irow"><div class="ik">' + TT('Clock', 'التردد') + '</div><div class="iv">' + (gf > 1e6 ? Math.round(gf / 1e6) : gf > 1e4 ? Math.round(gf / 1000) : gf) + ' MHz' + (gpu[2] ? ' · ' + esc(gpu[2].trim()) + ' %' : '') + '</div></div></div>'; }
    if (bat) {
      var cur2 = parseInt(bat[3], 10), vo = parseInt(bat[4], 10), tp = parseInt(bat[2], 10);
      html += '<div class="grp">' + TT('Battery', 'البطارية') + '</div><div class="igroup">' + bar(TT('Level', 'المستوى'), +bat[1] || 0, (bat[1] || '?') + ' % · ' + (bat[5] || ''));
      html += '<div class="irow"><div class="ik">' + TT('Temperature', 'الحرارة') + '</div><div class="iv">' + (isNaN(tp) ? '-' : (tp / 10).toFixed(1) + ' °C') + '</div></div>';
      html += '<div class="irow"><div class="ik">' + TT('Current', 'التيار') + '</div><div class="iv">' + (isNaN(cur2) ? '-' : Math.round(cur2 / 1000) + ' mA') + '</div></div>';
      html += '<div class="irow"><div class="ik">' + TT('Voltage', 'الفولت') + '</div><div class="iv">' + (isNaN(vo) ? '-' : (vo / 1e6).toFixed(2) + ' V') + '</div></div></div>';
    }
    if (zones.length) {
      zones.sort(function (a, b) { return b[1] - a[1]; });
      html += '<div class="grp">' + TT('Hottest zones', 'أسخن المناطق') + '</div><div class="igroup">' + zones.slice(0, 8).map(function (z) { return bar(z[0], Math.min(100, Math.round(z[1])), z[1].toFixed(1) + ' °C'); }).join('') + '</div>';
    }
    var m = $('mon'); if (m) m.innerHTML = html;
  }

  /* ---- actions: report / copy / LCD test ---- */
  function renderActs() {
    var a = $('acts');
    if (cur === 'monitor') { a.innerHTML = ''; return; }
    a.innerHTML = '<button id="aCopy">' + TT('Copy this page', 'نسخ الصفحة') + '</button><button id="aRep" class="p">' + TT('Save full report (.txt)', 'حفظ تقرير كامل (.txt)') + '</button>';
    $('aCopy').onclick = function () { copy(textOf(SECTIONS.filter(function (s) { return s[0] === cur; })[0], cache[cur] || [])); };
    $('aRep').onclick = fullReport;
  }
  var HIDE = /mac|bssid|ssid|serial|imei|android id|uid=/i;
  function textOf(s, items, mask) {
    var o = '=== ' + s[1] + ' ===\n';
    items.forEach(function (it) {
      if (it.t === 'g') o += '\n[' + it.v + ']\n';
      else if (it.t === 'b') o += it.k + ': ' + it.v + '\n';
      else o += (it.k === '.' ? '' : it.k + ': ') + (mask && HIDE.test(it.k) ? '(hidden)' : it.v) + '\n';
    });
    return o + '\n';
  }
  function copy(txt) {
    try { var ta = document.createElement('textarea'); ta.value = txt; ta.style.position = 'fixed'; ta.style.opacity = '0'; document.body.appendChild(ta); ta.select(); var ok = document.execCommand('copy'); document.body.removeChild(ta); toast(ok ? TT('Copied', 'اتنسخ') : TT('Copy failed', 'فشل النسخ')); }
    catch (e) { toast(TT('Copy failed', 'فشل النسخ')); }
  }
  function fullReport() {
    var list = SECTIONS.filter(function (s) { return s[0] !== 'monitor'; }), txt = '', i = 0;
    var view = $('view'); view.innerHTML = '<div class="busy" id="rp">0 / ' + list.length + '</div>';
    stopMon();
    (function next() {
      if (i >= list.length) { save(txt); return; }
      var s = list[i];
      $('rp').textContent = TT('Collecting ', 'بيجمع ') + (i + 1) + ' / ' + list.length + ' · ' + s[1];
      var go = cache[s[0]] ? Promise.resolve(cache[s[0]]) : runSection(s[0], 45000).then(function (r) { return (cache[s[0]] = parse(r.out || '')); });
      go.then(function (items) { txt += textOf(s, items, true); i++; next(); });
    })();
    function save(t) {
      var model = ((cache.dashboard || []).filter(function (x) { return x.k === 'Model'; })[0] || { v: 'device' }).v.replace(/[^A-Za-z0-9_-]+/g, '_');
      var d = new Date(), p2 = function (n) { return (n < 10 ? '0' : '') + n; };
      var name = 'DeviceInfo_' + model + '_' + d.getFullYear() + p2(d.getMonth() + 1) + p2(d.getDate()) + '_' + p2(d.getHours()) + p2(d.getMinutes()) + '.txt';
      var path = '/sdcard/MKVP LOGS/' + name;
      var b64 = btoa(unescape(encodeURIComponent('MkVenomPro Hardware Info report\n' + d.toString() + '\n\n' + t)));
      var chunks = []; for (var k = 0; k < b64.length; k += 24000) chunks.push(b64.slice(k, k + 24000));
      var tmp = '/data/local/tmp/.mkvp_rep.b64', seq = exec('mkdir -p "/sdcard/MKVP LOGS"; rm -f ' + tmp);
      chunks.forEach(function (c) { seq = seq.then(function () { return exec("printf %s '" + c + "' >> " + tmp); }); });
      seq.then(function () { return exec('base64 -d ' + tmp + ' > "' + path + '" && rm -f ' + tmp + ' && echo OK'); }).then(function (r) {
        show(cur);
        toast(r.out.indexOf('OK') >= 0 ? TT('Saved: ', 'اتحفظ: ') + path : TT('Save failed', 'فشل الحفظ'));
      });
    }
  }
  function lcdTest() {
    var el = $('lcd'), seq = ['#000', '#fff', '#f00', '#0f0', '#00f', '#808080', 'g', 'c'], i = 0;
    function paint() {
      var c = seq[i];
      if (c === 'g') el.style.background = 'linear-gradient(90deg,#000,#fff)';
      else if (c === 'c') el.style.background = 'repeating-conic-gradient(#fff 0 25%,#000 0 50%) 0 0/40px 40px';
      else el.style.background = c;
      el.textContent = (i + 1) + '/' + seq.length + ' - ' + TT('tap for next, last tap closes', 'اضغط للتالي، آخر ضغطة تقفل');
    }
    el.hidden = false; i = 0; paint();
    el.onclick = function () { i++; if (i >= seq.length) { el.hidden = true; return; } paint(); };
  }

  /* ---- wiring ---- */
  function applyLang() {
    document.documentElement.lang = LANG; document.documentElement.dir = LANG === 'ar' ? 'rtl' : 'ltr';
    $('ttl').textContent = TT('Hardware Info', 'معلومات الهاردوير');
    $('lcdBtn').textContent = TT('LCD test', 'اختبار الشاشة');
    $('q').placeholder = TT('Search…', 'بحث…');
    buildNav(); renderActs();
  }
  $('langBtn').onclick = function () { LANG = LANG === 'en' ? 'ar' : 'en'; try { localStorage.setItem('hpk_lang', LANG); } catch (e) { } applyLang(); };
  $('lcdBtn').onclick = lcdTest;
  $('refBtn').onclick = function () { delete cache[cur]; show(cur, true); };
  $('q').oninput = function () { if (cur !== 'monitor' && cache[cur]) $('view').innerHTML = render(cache[cur], $('q').value); };
  document.addEventListener('visibilitychange', function () { if (!document.hidden && cur === 'monitor') { prevStat = null; } });
  applyLang();
  var h = (location.hash || '').replace('#', ''); if (SECTIONS.some(function (s) { return s[0] === h; })) cur = h;
  show(cur);
})();
