// ======================= Touchpad tab =======================
// This phone's screen = a mouse for the phone plugged into its OTG port.
//   ADB pointer : one persistent `adb shell` on the other phone (mouse_daemon.sh keeps it open); a pointer is drawn
//                 on a live preview, taps/scrolls/keys are sent as `input ...`.  Needs USB debugging only.
// The WebUI never waits on USB/adb: it appends a line to a FIFO that a root worker drains (mouse_ctl.sh / mouse_daemon.sh).
// Loaded after app.js and uses its globals: exec, execT, usbRun, usbScan, usbSer, kvParse, shq, SC, $, say, toast, t, tabIs.

const TP_DIR = "/data/adb/spinel_toolkit";
const TP_FIFO = TP_DIR + "/mouse.fifo", TP_PID = TP_DIR + "/mouse.pid";
const lsGet = (k, d) => { try { const v = localStorage.getItem(k); return v === null ? d : v; } catch (_) { return d; } };
const lsSet = (k, v) => { try { localStorage.setItem(k, String(v)); } catch (_) {} };

Object.assign(I18N.en, {
  tabTp: "Touchpad",
  tpTitle: "Touchpad", tpDesc: "Use this phone's screen as a mouse for the phone plugged into its USB-C (OTG) port.",
  tpHintAdb: "Works with any phone that has USB debugging ON and this phone's key accepted. A pointer is drawn over a live preview of the other screen.",
  tpStatus: "Status", tpTarget: "Link", tpConnect: "Connect", tpStop: "Disconnect",
  tpSt_stopped: "Stopped", tpSt_connecting: "Connecting…", tpSt_ready: "Ready", tpSt_other: "Other mode active",
  tpConnecting: "Connecting…", tpStopped: "Disconnected.", tpNeed: "Press Connect first",
  tpBack: "Back", tpHome: "Home", tpRecents: "Recents", tpSens: "Speed",
  tpNatural: "Natural scrolling (content follows your fingers)", tpDirectLbl: "Direct mode: tap where you touch (instead of a relative pointer)",
  tpAutoLbl: "Refresh the preview every 2.5 s", tpPreviewBtn: "Refresh preview now",
  tpL_adb: "Click", tpM_adb: "Long press", tpR_adb: "Back",
  tpPadAdb: "Move: one finger · Click: tap · Back: two-finger tap · Scroll: two fingers · Drag: double-tap and hold",
  tpPadOff: "Press Connect to start",
  tpDenied: "The other phone refuses injected input. Turn ON Developer options → “USB debugging (Security settings)” (Xiaomi/HyperOS), then Connect again.",
  tpLost: "The session ended", tpNoPrev: "No preview yet - the pointer still works",
});
Object.assign(I18N.ar, {
  tabTp: "تتش باد",
  tpTitle: "تتش باد", tpDesc: "استخدم شاشة هذا الهاتف كماوس للهاتف الموصول بمنفذ USB-C (OTG).",
  tpHintAdb: "يشتغل مع أي هاتف عليه USB debugging ومفتاح هذا الهاتف مقبول. يظهر مؤشر فوق معاينة مباشرة لشاشة الهاتف الآخر.",
  tpStatus: "الحالة", tpTarget: "الاتصال", tpConnect: "اتصال", tpStop: "قطع الاتصال",
  tpSt_stopped: "متوقف", tpSt_connecting: "جاري الاتصال…", tpSt_ready: "جاهز", tpSt_other: "وضع آخر شغّال",
  tpConnecting: "جاري الاتصال…", tpStopped: "تم قطع الاتصال.", tpNeed: "اضغط اتصال أولاً",
  tpBack: "رجوع", tpHome: "الرئيسية", tpRecents: "الأخيرة", tpSens: "السرعة",
  tpNatural: "سكرول طبيعي (المحتوى يتبع أصابعك)", tpDirectLbl: "وضع مباشر: المس المكان المطلوب مباشرة (بدل المؤشر النسبي)",
  tpAutoLbl: "تحديث المعاينة كل 2.5 ث", tpPreviewBtn: "تحديث المعاينة الآن",
  tpL_adb: "نقر", tpM_adb: "ضغط مطوّل", tpR_adb: "رجوع",
  tpPadAdb: "تحريك: إصبع · نقر: لمسة · رجوع: لمسة بإصبعين · سكرول: إصبعين · سحب: لمسة مزدوجة مع الإبقاء",
  tpPadOff: "اضغط اتصال للبدء",
  tpDenied: "الهاتف الآخر يرفض الإدخال. فعّل خيارات المطور ← «USB debugging (Security settings)» ثم اتصل مرة أخرى.",
  tpLost: "انتهت الجلسة", tpNoPrev: "لا توجد معاينة بعد - المؤشر يعمل",
});

const tp = {
  mode: "adb",
  sens: parseFloat(lsGet("tp_sens", "1.6")) || 1.6,
  natural: lsGet("tp_nat", "1") === "1", direct: lsGet("tp_dir", "0") === "1", auto: lsGet("tp_auto", "0") === "1",
  ready: false, alive: false, starting: false, polling: false, m: {}, state: "stopped", warn: "",
  scr: { w: 1080, h: 2400 }, ptr: { x: 540, y: 1200 }, hasPrev: false,
  q: [], inflight: false, sacc: { x: 0, y: 0 }, sTimer: null, dragFrom: null,
  pv: false, pvAgain: false, pvTimer: null, autoTimer: null, noteT: 0,
};
const tpPad = () => $("tpPad");
const tpLog = (txt) => { const o = $("tpLog"); o.style.display = txt ? "block" : "none"; o.textContent = txt || ""; };
const tpWarn = (txt) => { const o = $("tpWarn"); o.style.display = txt ? "block" : "none"; o.textContent = txt || ""; };
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));

// ------------------------------------------------------------ render
function tpRender() {
  const key = tp.starting ? "connecting" : tp.ready ? "ready"
    : tp.alive ? "other" : "stopped";
  tp.state = key;
  $("tpState").textContent = t("tpSt_" + key);
  $("tpTarget").textContent = usbSer || "-";
  $("tpModeHint").textContent = t("tpHintAdb");
  $("tpL").textContent = t("tpL_adb"); $("tpM").textContent = t("tpM_adb"); $("tpR").textContent = t("tpR_adb");
  $("tpConnect").disabled = tp.starting; $("tpStop").disabled = tp.starting || !tp.alive;
  const pad = tpPad(); pad.classList.toggle("off", !tp.ready);
  const showPrev = tp.hasPrev;
  $("tpImg").style.display = showPrev ? "block" : "none";
  $("tpDot").style.display = tp.ready ? "block" : "none";
  $("tpHint").textContent = !tp.ready ? t("tpPadOff") : t("tpPadAdb") + (!tp.hasPrev ? "\n" + t("tpNoPrev") : "");
  $("tpHint").style.whiteSpace = "pre-line";
  tpLayout(); tpDot();
}
function tpLayout() {
  const pad = tpPad(), card = pad.parentElement; if (!card) return;
  if (tp.hasPrev) {
    const maxW = card.clientWidth - 28 > 0 ? card.clientWidth - 28 : 300, maxH = Math.max(230, window.innerHeight * 0.56);
    const ratio = tp.scr.h / tp.scr.w;
    let h = Math.min(maxH, maxW * ratio), w = h / ratio;
    pad.style.width = Math.round(w) + "px"; pad.style.height = Math.round(h) + "px";
  } else { pad.style.width = ""; pad.style.height = ""; }
}
function tpDot() {
  const d = $("tpDot"); d.style.left = (tp.ptr.x / tp.scr.w * 100) + "%"; d.style.top = (tp.ptr.y / tp.scr.h * 100) + "%";
}
function tpNote(msg) { if (Date.now() - tp.noteT > 1500) { tp.noteT = Date.now(); toast(msg); } }

// ------------------------------------------------------------ status polling
async function tpTick() {
  if (tp.starting || tp.polling || !tabIs("tp")) return;
  tp.polling = true;
  try {
    const r = await execT(`${SC("mouse_ctl.sh")} status`, 6000);
    const m = kvParse(r.stdout); if (!m.mode) return;
    const wasReady = tp.ready;
    tp.m = m; tp.alive = m.alive === "1"; tp.ready = tp.alive && m.ready === "1" && m.mode === "adb";
    if (m.size && /^\d+x\d+$/.test(m.size) && !tp.hasPrev) { const [w, h] = m.size.split("x").map(Number); tp.scr = { w, h }; tp.ptr = { x: w / 2, y: h / 2 }; }
    if (wasReady && !tp.alive) { tpWarn(t("tpLost") + (m.log ? ": " + m.log : "")); tpLog(m.out || ""); }
    if (wasReady && !tp.ready) tp.q.length = 0;
    tpRender();
  } finally { tp.polling = false; }
}

// ------------------------------------------------------------ connect / disconnect
async function tpConnect() {
  if (tp.starting) return;
  tp.starting = true; tpWarn(""); tpLog(t("tpConnecting")); tpRender();
  try {
    const ser = await usbScan();                         // same adb device scan as the USB tab
    if (!ser) { tpLog(t("mgNoAdb")); return; }
    tp.hasPrev = false;
    const r = await usbRun("mouse_ctl.sh", `start adb ${shq(ser)}`, 40000);
    tpLog(r.out.trim());
    if (/RESULT=denied/.test(r.out)) tpWarn(t("tpDenied"));
  } finally {
    tp.starting = false;
    await tpTick(); tpRender();
    if (tp.ready) tpPreview();
  }
}
async function tpDisconnect() {
  tp.q.length = 0; tpWarn("");
  await execT(`${SC("mouse_ctl.sh")} stop`, 20000);
  tp.ready = false; tp.alive = false; tp.hasPrev = false;
  tpLog(t("tpStopped")); await tpTick(); tpRender();
}

// ------------------------------------------------------------ the one way out: append lines to the FIFO
function tpWrite(lines) {
  const body = lines.join("\n");
  if (/'/.test(body)) return Promise.resolve();          // never happens: only digits, escapes and plain words are generated
  return exec(`P=$(cat ${TP_PID} 2>/dev/null); [ -n "$P" ] && [ -d /proc/$P ] || exit 3; T=; command -v timeout >/dev/null 2>&1 && T="timeout 1"; $T sh -c 'printf "%s\\n" "$0" >> ${TP_FIFO}' '${body}'`);
}
function tpPush(item) { if (!tp.ready) return; tp.q.push(item); tpFlush(); }
async function tpFlush() {
  if (tp.inflight || !tp.q.length) return;
  if (!tp.ready) { tp.q.length = 0; return; }
  tp.inflight = true;
  const items = tp.q.splice(0, tp.q.length);                 // everything that piled up while the last write was running
  try { await tpWrite(items); }
  finally { tp.inflight = false; }
  if (tp.q.length) tpFlush();
}

// ------------------------------------------------------------ pointer actions (shared by pad + buttons)
const tpAccel = (dx, dy) => tp.sens * (1 + Math.min(Math.hypot(dx, dy) / 18, 1.5));
function tpScale() { const r = tpPad().getBoundingClientRect(); return { sx: tp.scr.w / Math.max(r.width, 1), sy: tp.scr.h / Math.max(r.height, 1), r }; }
const scrX = () => Math.round(tp.ptr.x), scrY = () => Math.round(tp.ptr.y);

function tpMove(dx, dy) {
  if (!tp.ready) return;
  const g = tpAccel(dx, dy);
  const s = tpScale();
  tp.ptr.x = clamp(tp.ptr.x + dx * g * s.sx, 0, tp.scr.w - 1); tp.ptr.y = clamp(tp.ptr.y + dy * g * s.sy, 0, tp.scr.h - 1);
  tpDot();
}
function tpDirect(e) {
  const r = tpPad().getBoundingClientRect();
  tp.ptr.x = clamp((e.clientX - r.left) / r.width * tp.scr.w, 0, tp.scr.w - 1); tp.ptr.y = clamp((e.clientY - r.top) / r.height * tp.scr.h, 0, tp.scr.h - 1); tpDot();
}
function tpClick() {
  if (!tp.ready) return tpNote(t("tpNeed"));
  tpPush(`input tap ${scrX()} ${scrY()}`); tpPreviewSoon();
}
function tpRight() {
  if (!tp.ready) return tpNote(t("tpNeed"));
  tpPush("input keyevent 4"); tpPreviewSoon();
}
function tpMiddle(down) {
  if (!tp.ready) return tpNote(t("tpNeed"));
  if (down) { tpPush(`input swipe ${scrX()} ${scrY()} ${scrX()} ${scrY()} 700`); tpPreviewSoon(); }
}
function tpDragStart() {
  if (!tp.ready) return;
  tp.dragFrom = { x: scrX(), y: scrY() };
}
function tpDragEnd(moved) {
  if (!tp.ready) return;
  const f = tp.dragFrom; tp.dragFrom = null;
  if (moved && f) tpPush(`input swipe ${f.x} ${f.y} ${scrX()} ${scrY()} 350`); else tpPush(`input tap ${scrX()} ${scrY()}`);
  tpPreviewSoon();
}
// two-finger scroll
function tpScroll(dx, dy) {
  if (!tp.ready) return;
  const sgn = tp.natural ? 1 : -1;
  const s = tpScale();
  tp.sacc.x += sgn * dx * s.sx * tp.sens; tp.sacc.y += sgn * dy * s.sy * tp.sens;
  if (!tp.sTimer) tp.sTimer = setTimeout(tpScrollEnd, 320);
}
function tpScrollEnd() {
  clearTimeout(tp.sTimer); tp.sTimer = null;
  if (!tp.ready) return;
  let { x, y } = tp.sacc; tp.sacc = { x: 0, y: 0 };
  if (Math.hypot(x, y) < 24) return;
  const x1 = scrX(), y1 = scrY();
  const x2 = clamp(x1 + x, 1, tp.scr.w - 2), y2 = clamp(y1 + y, 1, tp.scr.h - 2);
  tpPush(`input swipe ${x1} ${y1} ${Math.round(x2)} ${Math.round(y2)} ${Math.round(clamp(Math.hypot(x, y) / 3, 140, 420))}`);
  tpPreviewSoon();
}

// ------------------------------------------------------------ live preview (ADB mode)
async function tpPreview() {
  if (!usbSer || !tp.ready) return;
  if (tp.pv) { tp.pvAgain = true; return; }
  tp.pv = true;
  try {
    const r = await usbRun("states_ctl.sh", `preview ${shq(usbSer)}`, 15000);
    if (/^OK/m.test(r.out)) {
      const img = $("tpImg");
      img.onload = () => {
        if (img.naturalWidth > 0 && (img.naturalWidth !== tp.scr.w || img.naturalHeight !== tp.scr.h || !tp.hasPrev)) {
          const fx = tp.ptr.x / tp.scr.w, fy = tp.ptr.y / tp.scr.h;
          tp.scr = { w: img.naturalWidth, h: img.naturalHeight }; tp.ptr = { x: fx * tp.scr.w, y: fy * tp.scr.h };
        }
        tp.hasPrev = true; tpRender();
      };
      img.src = "shots/live.png?" + Date.now();
    } else if (!tp.hasPrev) { tpWarn(r.out.trim()); }
  } finally { tp.pv = false; if (tp.pvAgain) { tp.pvAgain = false; tpPreviewSoon(); } }
}
function tpPreviewSoon() { clearTimeout(tp.pvTimer); tp.pvTimer = setTimeout(tpPreview, 900); }
function tpAutoSet() {
  clearInterval(tp.autoTimer); tp.autoTimer = null;
  if (tp.auto) tp.autoTimer = setInterval(() => { if (!document.hidden && tabIs("tp") && tp.ready) tpPreview(); }, 2500);
}

// ------------------------------------------------------------ gestures on the pad
(function tpGestures() {
  const pad = tpPad(), pts = new Map();
  const G = { t0: 0, moved: false, maxN: 0, scrolled: false, lastUp: 0, lx: 0, ly: 0, drag: false, travel: 0, st: 0 };
  pad.addEventListener("pointerdown", (e) => {
    e.preventDefault();
    try { pad.setPointerCapture(e.pointerId); } catch (_) {}
    pts.set(e.pointerId, { x: e.clientX, y: e.clientY });
    if (pts.size === 1) {
      const now = performance.now();
      Object.assign(G, { t0: now, moved: false, maxN: 1, scrolled: false, travel: 0, st: 0, drag: false });
      if (!tp.ready) { tpNote(t("tpNeed")); return; }
      if (tp.direct) tpDirect(e);
      if (now - G.lastUp < 320 && Math.hypot(e.clientX - G.lx, e.clientY - G.ly) < 45) { G.drag = true; tpDragStart(); }
    } else G.maxN = Math.max(G.maxN, pts.size);
  });
  pad.addEventListener("pointermove", (e) => {
    const p = pts.get(e.pointerId); if (!p) return;
    e.preventDefault();
    const dx = e.clientX - p.x, dy = e.clientY - p.y; p.x = e.clientX; p.y = e.clientY;
    if (!tp.ready) return;
    if (pts.size === 1 && G.maxN === 1) {
      G.travel += Math.hypot(dx, dy); if (G.travel > 7) G.moved = true;
      if (tp.direct) tpDirect(e); else tpMove(dx, dy);
    } else if (pts.size >= 2) {
      G.st += Math.hypot(dx, dy); if (G.st > 10) G.scrolled = true;
      tpScroll(dx / pts.size, dy / pts.size);
    }
  });
  const up = (e) => {
    if (!pts.delete(e.pointerId) || pts.size > 0) return;
    if (!tp.ready) return;
    const dur = performance.now() - G.t0;
    if (G.drag) { tpDragEnd(G.moved); G.drag = false; G.lastUp = 0; }
    else if (G.maxN === 1 && !G.moved && dur < 260) { tpClick(); G.lastUp = performance.now(); G.lx = e.clientX; G.ly = e.clientY; }
    else if (G.maxN === 2 && !G.scrolled && dur < 350) tpRight();
    if (G.scrolled) tpScrollEnd();
  };
  pad.addEventListener("pointerup", up);
  pad.addEventListener("pointercancel", up);
  pad.addEventListener("contextmenu", (e) => e.preventDefault());
})();

// ------------------------------------------------------------ buttons + settings
function tpBindBtn(id, bit, down, upFn) {
  const b = $(id);
  b.addEventListener("pointerdown", (e) => { e.preventDefault(); b.classList.add("held"); try { b.setPointerCapture(e.pointerId); } catch (_) {} down(); });
  const rel = () => { if (b.classList.contains("held")) { b.classList.remove("held"); if (upFn) upFn(); } };
  b.addEventListener("pointerup", rel); b.addEventListener("pointercancel", rel);
}
tpBindBtn("tpL", 1, () => { if (!tp.ready) return tpNote(t("tpNeed")); tpPush(`input tap ${scrX()} ${scrY()}`); tpPreviewSoon(); });
tpBindBtn("tpM", 4, () => tpMiddle(true));
tpBindBtn("tpR", 2, () => { if (!tp.ready) return tpNote(t("tpNeed")); tpRight(); });
document.querySelectorAll("#tpKeys button").forEach((b) => b.addEventListener("click", () => {
  if (!tp.ready) return tpNote(t("tpNeed"));
  tpPush(`input keyevent ${parseInt(b.dataset.key, 10)}`); tpPreviewSoon();
}));
$("tpSens").value = tp.sens; $("tpNat").checked = tp.natural; $("tpDirect").checked = tp.direct; $("tpAuto").checked = tp.auto;
$("tpSens").addEventListener("input", (e) => { tp.sens = parseFloat(e.target.value) || 1.6; lsSet("tp_sens", tp.sens); });
$("tpNat").addEventListener("change", (e) => { tp.natural = e.target.checked; lsSet("tp_nat", tp.natural ? "1" : "0"); });
$("tpDirect").addEventListener("change", (e) => { tp.direct = e.target.checked; lsSet("tp_dir", tp.direct ? "1" : "0"); });
$("tpAuto").addEventListener("change", (e) => { tp.auto = e.target.checked; lsSet("tp_auto", tp.auto ? "1" : "0"); tpAutoSet(); });
$("tpShot").addEventListener("click", () => { if (!tp.ready) return tpNote(t("tpNeed")); tpPreview(); });
$("tpConnect").addEventListener("click", tpConnect);
$("tpStop").addEventListener("click", tpDisconnect);
window.addEventListener("resize", () => { tpLayout(); });
$("langBtn").addEventListener("click", () => setTimeout(tpRender, 0));

// ---- tab hook (runs after the original tab handler, like the v1.1 hooks) ----
document.querySelectorAll(".tab-btn").forEach((btn) => btn.addEventListener("click", () => { try {
  if (btn.dataset.tab === "tp") { tpRender(); startPoll(tpTick, 2000); tpAutoSet(); }
} catch (e) { toast("Error: " + (e && e.message)); } }));

tpAutoSet();
applyLang();
tpRender();
