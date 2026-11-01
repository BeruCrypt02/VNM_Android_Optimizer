// HyperOS Perfkeeper — WebUI logic (v3)
// Uses the standard KernelSU/APatch/Magisk WebUI bridge: window.ksu.exec()
// No Zygisk required — every action here is a plain root shell command.

const MODDIR = "/data/adb/modules/mkvenompro_android_optimizer";
let cbCounter = 0;

// ---------------- i18n ----------------
const I18N = {
  en: {
    tabDebloat: "Debloat", tabPerf: "Performance", tabRestore: "Restore", tabLogs: "Logs",
    debloatIntro1: "Every app installed on the device — system and user — is listed below. Pick whatever you want removed. Removal uses pm uninstall --user 0, which is fully reversible.",
    debloatWarnCore: "Packages marked 🔒 are core system components and are locked here to prevent bricking the device.",
    searchPlaceholder: "Search package name…",
    filterAll: "All", filterRecommended: "Recommended", filterSystem: "System", filterUser: "User",
    loadingApps: "Loading installed apps…",
    deleteUiLabel: "Remove the recommended-picks overlay after running (next time you'll just get the plain full app list)",
    runDebloatBtn: "Remove selected apps",
    perfIntro: "Each switch below applies immediately and is re-applied automatically on every boot / maintenance cycle.",
    logsIntro: "The log lives on internal storage (not /data), so you can open it with any file manager or send it over without root:",
    refreshLogBtn: "Refresh log", copyLogBtn: "Copy to clipboard",
    loadingLog: "Loading…",
    bridgeOk: "Root connected", bridgeBad: "No root connection",
    noSelection: "No app selected",
    removing: (n) => `Removing ${n} app(s)…`,
    done: "Done ✅", copied: "Log copied", copyFailed: "Copy failed",
    logEmpty: "Log is empty — wait a minute after first boot.",
    already: "✅ Debloat already ran before, and the picker overlay was removed as you chose. The module now runs as a background performance daemon only.",
    on: "ON", off: "OFF", locked: "Core",
    restoreTitle: "♻️ Restore Removed System Apps",
    restoreDesc: "Restore apps removed with pm uninstall --user 0.",
    restoreAllBtnLabel: "Restore All Removed Apps", restoreSelectedBtn: "Restore selected",
    restoring: "Restoring packages…", restoreDone: "Restore completed", restoreFailed: "Restore failed",
    detectedRom: "Detected ROM", rom_miui: "Xiaomi MIUI/HyperOS", rom_oneui: "Samsung OneUI", rom_coloros: "Oppo/Realme/OnePlus ColorOS", rom_generic: "Stock/AOSP-based",
    metaProgress: (d, t) => `Loading real icons/names… (${d}/${t})`, metaDone: "Icons & names cached ✅"
  },
  ar: {
    tabDebloat: "الديبلوت", tabPerf: "الأداء", tabRestore: "الاسترجاع", tabLogs: "اللوج",
    debloatIntro1: "كل تطبيق مثبت على الجهاز — نظام ومستخدم — موجود تحت. اختار اللي عايز تشيله. الحذف بـ pm uninstall --user 0 وهو قابل للاسترجاع بالكامل.",
    debloatWarnCore: "التطبيقات المعلّم عليها 🔒 مكونات نظام أساسية ومقفولة هنا عشان منبوظش الجهاز.",
    searchPlaceholder: "دور باسم الباكدج…",
    filterAll: "الكل", filterRecommended: "موصى بيها", filterSystem: "نظام", filterUser: "مستخدم",
    loadingApps: "جاري تحميل التطبيقات المثبتة…",
    deleteUiLabel: "احذف ليستة التوصيات بعد التنفيذ (المرة الجاية هتشوف الليستة الكاملة العادية بس)",
    runDebloatBtn: "احذف التطبيقات المختارة",
    perfIntro: "كل زرار تحت بيتطبق فورًا وبيترجع يتفعل لوحده مع كل بوت / دورة صيانة.",
    logsIntro: "اللوج محفوظ على الذاكرة الداخلية (مش /data) عشان تقدر تفتحه بأي مدير ملفات أو تبعته من غير روت:",
    refreshLogBtn: "تحديث اللوج", copyLogBtn: "نسخ للحافظة",
    loadingLog: "جاري التحميل…",
    bridgeOk: "متصلة بالروت", bridgeBad: "مفيش اتصال بالروت",
    noSelection: "محددتش أي تطبيق",
    removing: (n) => `بيشيل ${n} تطبيق…`,
    done: "تم ✅", copied: "اتنسخ اللوج", copyFailed: "فشل النسخ",
    logEmpty: "اللوج لسه فاضي — استنى دقيقة بعد أول بوت.",
    already: "✅ تم تنفيذ الديبلوت قبل كده، وليستة التوصيات اتحذفت زي ما اخترت. الاضافه دلوقتي بتشتغل بس كـ daemon أداء في الخلفية.",
    on: "شغال", off: "واقف", locked: "أساسي",
    restoreTitle: "♻️ استرجاع تطبيقات النظام المحذوفة",
    restoreDesc: "استرجاع التطبيقات اللي اتشالت بـ pm uninstall --user 0.",
    restoreAllBtnLabel: "استرجاع كل التطبيقات المحذوفة", restoreSelectedBtn: "استرجاع المحدد",
    restoring: "جاري الاسترجاع…", restoreDone: "تم الاسترجاع", restoreFailed: "فشل الاسترجاع",
    detectedRom: "الروم المكتشفة", rom_miui: "شاومي MIUI/HyperOS", rom_oneui: "سامسونج OneUI", rom_coloros: "أوبو/ريلمي/ون بلس ColorOS", rom_generic: "AOSP/خام",
    metaProgress: (d, t) => `جاري تحميل الأيقونات/الأسماء الحقيقية… (${d}/${t})`, metaDone: "تم حفظ الأيقونات والأسماء ✅"
  }
};
let LANG = localStorage.getItem("hpk_lang") || "en";
function t(key, ...args) {
  const v = I18N[LANG][key];
  return typeof v === "function" ? v(...args) : v;
}
function applyLang() {
  document.getElementById("htmlRoot").lang = LANG;
  document.getElementById("htmlRoot").dir = LANG === "ar" ? "rtl" : "ltr";
  document.querySelectorAll("[data-i18n]").forEach((el) => {
    el.textContent = t(el.dataset.i18n);
  });
  document.querySelectorAll("[data-i18n-ph]").forEach((el) => {
    el.placeholder = t(el.dataset.i18nPh);
  });
}
document.getElementById("langBtn").addEventListener("click", () => {
  LANG = LANG === "en" ? "ar" : "en";
  localStorage.setItem("hpk_lang", LANG);
  applyLang();
  renderPkgList();
  renderPerfList();
  const vb = document.getElementById("vendorBadge");
  if (vb && detectedVendor) vb.textContent = t("detectedRom") + ": " + t("rom_" + detectedVendor);
  if (document.getElementById("tab-restore").classList.contains("active")) {
    renderRestoreList();
  }
});

// ---------------- root bridge ----------------
function hasBridge() {
  return typeof window.ksu !== "undefined" && typeof window.ksu.exec === "function";
}
function exec(cmd) {
  return new Promise((resolve) => {
    if (!hasBridge()) { resolve({ errno: -1, stdout: "", stderr: "no-bridge" }); return; }
    const cbName = "hpk_cb_" + (cbCounter++);
    window[cbName] = (errno, stdout, stderr) => {
      delete window[cbName];
      resolve({ errno, stdout: stdout || "", stderr: stderr || "" });
    };
    try { window.ksu.exec(cmd, "{}", cbName); }
    catch (e) { resolve({ errno: -1, stdout: "", stderr: String(e) }); }
  });
}
function toast(msg) {
  const el = document.getElementById("toast");
  el.textContent = msg;
  el.classList.add("show");
  clearTimeout(toast._t);
  toast._t = setTimeout(() => el.classList.remove("show"), 2200);
}

(async function initBridgeBadge() {
  const el = document.getElementById("bridgeStatus");
  if (!hasBridge()) { el.textContent = t("bridgeBad"); el.className = "badge bad"; return; }
  const r = await exec("echo ok");
  if (r.stdout.trim() === "ok") { el.textContent = t("bridgeOk"); el.className = "badge ok"; }
  else { el.textContent = t("bridgeBad"); el.className = "badge bad"; }
})();

// ---------------- Tabs ----------------
document.querySelectorAll(".tab-btn").forEach((btn) => {
  btn.addEventListener("click", () => {
    document.querySelectorAll(".tab-btn").forEach((b) => b.classList.remove("active"));
    document.querySelectorAll(".tab").forEach((tb) => tb.classList.remove("active"));
    btn.classList.add("active");
    document.getElementById("tab-" + btn.dataset.tab).classList.add("active");
    if (btn.dataset.tab === "logs") loadLog();
    if (btn.dataset.tab === "restore") loadRestoreList();
  });
});

// ---------------- Debloat: full app list ----------------
// Core packages that stay locked regardless of what the user picks,
// to prevent bricking the device.
const PROTECTED = [
  "android", "com.android.systemui", "com.android.phone", "com.android.settings",
  "com.android.providers.settings", "com.android.server.telecom", "com.android.shell",
  "com.miui.core", "com.miui.securitycenter", "com.xiaomi.xmsf", "com.android.vending",
  "com.google.android.gms", "com.android.providers.media", "com.android.providers.telephony",
  "com.android.bluetooth", "com.android.nfc", "com.android.systemui.plugin",
  "com.sec.android.app.launcher", "com.samsung.android.incallui", "com.sec.android.provider.badge",
  "com.samsung.android.mdx", "com.samsung.android.themecenter",
];

let curated = [];
let allApps = []; // {pkg, source: 'system'|'user'}
let curatedActive = true;
let detectedVendor = "generic";
let appLabels = {}; // pkg -> real display name, once extracted

async function loadAppLabels() {
  try {
    const res = await fetch("app_labels.json", { cache: "no-store" });
    if (res.ok) appLabels = await res.json();
  } catch (e) { /* not built yet */ }
}

function labelFor(pkg) {
  return appLabels[pkg] || pkg;
}

function iconHtml(pkg) {
  // Real icon if the cache has one; falls back to the generated avatar
  // client-side via onerror, so a missing/failed extraction never breaks
  // the layout.
  const fallback = avatarFor(pkg).replace(/"/g, "&quot;");
  return `<img class="app-icon" src="icons/${pkg}.png" loading="lazy"
    onerror="this.outerHTML='${fallback}'">`;
}

async function detectVendor() {
  const r = await exec(
    "getprop ro.miui.ui.version.name; " +
    "getprop ro.mi.os.version.name; " +
    "getprop ro.build.version.oneui; " +
    "getprop ro.config.samsung.custom; " +
    "getprop ro.build.version.opporom; " +
    "getprop ro.product.brand"
  );
  const [miuiVer, hyperosVer, oneUiVer, samsungCustom, opporom, brand] = r.stdout.split("\n");
  if ((miuiVer && miuiVer.trim()) || (hyperosVer && hyperosVer.trim())) return "miui";
  if ((oneUiVer && oneUiVer.trim()) || (samsungCustom && samsungCustom.trim())) return "oneui";
  const b = (brand || "").trim().toLowerCase();
  if ((opporom && opporom.trim()) || ["oppo", "realme", "oneplus"].includes(b)) return "coloros";
  return "generic";
}

async function loadCuratedOverlay() {
  detectedVendor = await detectVendor();
  const files = ["curated_common.json"];
  if (detectedVendor === "miui") files.push("curated_miui.json");
  else if (detectedVendor === "oneui") files.push("curated_oneui.json");
  else if (detectedVendor === "coloros") files.push("curated_coloros.json");
  else files.push("curated_generic.json");

  const lists = await Promise.all(files.map(async (f) => {
    try {
      const res = await fetch(f, { cache: "no-store" });
      if (!res.ok) return [];
      return await res.json();
    } catch (e) { return []; }
  }));
  curated = lists.flat();
  curatedActive = curated.length > 0;
}

async function loadAllApps() {
  const [sys, usr] = await Promise.all([
    exec("pm list packages -s"),
    exec("pm list packages -3"),
  ]);
  const parse = (out, source) => out.split("\n")
    .map((l) => l.replace("package:", "").trim())
    .filter(Boolean)
    .map((pkg) => ({ pkg, source }));
  allApps = [...parse(sys.stdout, "system"), ...parse(usr.stdout, "user")]
    .sort((a, b) => a.pkg.localeCompare(b.pkg));
}

let currentFilter = "all";
let currentSearch = "";

function curatedFor(pkg) {
  return curated.find((c) => c.pkg === pkg);
}

function renderPkgList() {
  const listEl = document.getElementById("pkgList");
  const loadingEl = document.getElementById("pkgLoading");
  const introEl = document.querySelector("#tab-debloat .card");
  const toggleRow = document.querySelector("#tab-debloat .card.row");
  const runBtn = document.getElementById("runDebloat");

  if (!curatedActive && allApps.length && curated.length === 0 && window.__hpkAlreadyRan) {
    introEl.innerHTML = `<p>${t("already")}</p>`;
  }

  const q = currentSearch.toLowerCase();
  const filtered = allApps.filter((a) => {
    if (q && !a.pkg.toLowerCase().includes(q) && !labelFor(a.pkg).toLowerCase().includes(q)) return false;
    const rec = curatedFor(a.pkg);
    if (currentFilter === "recommended") return !!rec;
    if (currentFilter === "system") return a.source === "system";
    if (currentFilter === "user") return a.source === "user";
    return true;
  });

  listEl.innerHTML = filtered.map((a) => {
    const rec = curatedFor(a.pkg);
    const locked = PROTECTED.includes(a.pkg);
    const checked = rec && rec.default && !locked ? "checked" : "";
    const cat = rec ? (LANG === "ar" ? rec.cat_ar : rec.cat_en) : "";
    const desc = rec ? (LANG === "ar" ? rec.desc_ar : rec.desc_en) : "";
    return `
      <label class="pkg-item ${locked ? "locked" : ""}">
        <input type="checkbox" data-pkg="${a.pkg}" ${checked} ${locked ? "disabled" : ""}>
        ${iconHtml(a.pkg)}
        <div class="pkg-meta">
          <div class="pkg-tags">
            ${locked ? `<span class="pkg-tag">🔒 ${t("locked")}</span>` : ""}
            ${rec ? `<span class="pkg-tag rec">${cat}</span>` : ""}
            <span class="pkg-tag ${a.source === "system" ? "sys" : "usr"}">${a.source === "system" ? t("filterSystem") : t("filterUser")}</span>
          </div>
          <span class="app-label">${labelFor(a.pkg)}</span>
          <span class="pkg-name">${a.pkg}</span>
          ${desc ? `<span class="pkg-desc">${desc}</span>` : ""}
        </div>
      </label>
    `;
  }).join("");

  loadingEl.style.display = "none";
  listEl.style.display = "block";
}

document.getElementById("pkgSearch").addEventListener("input", (e) => {
  currentSearch = e.target.value;
  renderPkgList();
});
document.querySelectorAll(".chip").forEach((chip) => {
  chip.addEventListener("click", () => {
    document.querySelectorAll(".chip").forEach((c) => c.classList.remove("active"));
    chip.classList.add("active");
    currentFilter = chip.dataset.filter;
    renderPkgList();
  });
});

let metaLoadRunning = false;
async function autoLoadIconsAndNames() {
  if (metaLoadRunning) return;
  metaLoadRunning = true;
  const statusEl = document.getElementById("metaStatus");
  statusEl.style.display = "block";

  const pkgs = allApps.map((a) => a.pkg);
  let done = 0, extracted = 0, unsupported = false;

  for (const pkg of pkgs) {
    // One exec() call per app, awaited -- the root-exec bridge blocks the
    // WebView for the duration of whatever it runs, so a single call that
    // looped over every app froze the UI for the whole scan. Awaiting many
    // small calls keeps each one sub-second and lets the WebView breathe
    // (re-render, handle taps) between them.
    const r = await exec(`sh ${MODDIR}/scripts/extract_one.sh ${pkg}`);
    const result = r.stdout.trim();
    done++;
    if (result === "UNSUPPORTED") { unsupported = true; break; }
    if (result === "OK") extracted++;

    if (done % 8 === 0 || done === pkgs.length) {
      statusEl.textContent = t("metaProgress", done, pkgs.length);
      renderPkgList(); // progressive reveal as icons land
      if (document.getElementById("tab-restore").classList.contains("active")) renderRestoreList();
    }
  }

  if (unsupported) {
    statusEl.style.display = "none";
  } else {
    await exec(`sh ${MODDIR}/scripts/rebuild_labels.sh`);
    await loadAppLabels();
    renderPkgList();
    if (document.getElementById("tab-restore").classList.contains("active")) renderRestoreList();
    statusEl.textContent = t("metaDone");
    setTimeout(() => { statusEl.style.display = "none"; }, 4000);
  }
  metaLoadRunning = false;
}

async function initDebloatTab() {
  await loadCuratedOverlay();
  await loadAllApps();
  await loadAppLabels();
  window.__hpkAlreadyRan = !curatedActive;
  const vb = document.getElementById("vendorBadge");
  if (vb) vb.textContent = t("detectedRom") + ": " + t("rom_" + detectedVendor);
  renderPkgList();
  autoLoadIconsAndNames(); // fires in the background, one tiny exec() per app -- never awaited here
}
initDebloatTab();

document.getElementById("runDebloat").addEventListener("click", async () => {
  const checked = [...document.querySelectorAll('#pkgList input[type=checkbox]:checked')]
    .map((c) => c.dataset.pkg);
  if (checked.length === 0) { toast(t("noSelection")); return; }

  const deleteUi = document.getElementById("deleteUiAfter").checked ? "1" : "0";
  const btn = document.getElementById("runDebloat");
  const statusEl = document.getElementById("debloatStatus");
  btn.disabled = true;
  statusEl.style.display = "block";
  statusEl.textContent = t("removing", checked.length);

  const cmd = `sh ${MODDIR}/scripts/debloat_run.sh ${deleteUi} ${checked.join(" ")}`;
  await exec(cmd);

  let tries = 0;
  const poll = setInterval(async () => {
    tries++;
    try {
      const r = await fetch("status.json", { cache: "no-store" });
      const s = await r.json();
      statusEl.textContent = `${s.done}/${s.total} — ` +
        s.results.map((x) => (x.ok ? "✅" : "⚠️") + " " + x.pkg).join("\n");
      if (s.state === "done") {
        clearInterval(poll);
        toast(t("done"));
        if (deleteUi === "1") {
          setTimeout(() => { initDebloatTab(); btn.disabled = false; btn.textContent = t("runDebloatBtn"); }, 1500);
        } else {
          btn.disabled = false;
          btn.textContent = t("runDebloatBtn");
        }
      }
    } catch (e) { /* not written yet */ }
    if (tries > 60) clearInterval(poll);
  }, 1000);
});

// ---------------- Performance tab (redesigned ON/OFF segmented toggle) ----------------
const PERF_TOGGLES = [
  { key: "IO_SCHEDULER_ENABLE", en: ["I/O scheduler (deadline)", "Faster random access on flash storage"], ar: ["جدولة I/O (deadline)", "أسرع في الوصول العشوائي للفلاش"] },
  { key: "SWAPPINESS_ENABLE", en: ["Swappiness tuning", "Prefers RAM over swap"], ar: ["ضبط Swappiness", "يقلل الاعتماد على الـ swap ويفضّل الرام"] },
  { key: "DIRTY_RATIO_ENABLE", en: ["Dirty ratio tuning", "Controls when writes actually hit flash"], ar: ["ضبط Dirty Ratio", "يتحكم في وقت الكتابة الفعلية للفلاش"] },
  { key: "F2FS_GC_ENABLE", en: ["Periodic F2FS GC", "Cleans up old flash blocks (gc_urgent)"], ar: ["F2FS GC دوري", "تنضيف بلوكات الفلاش القديمة"] },
  { key: "FSTRIM_ENABLE", en: ["Daily fstrim", "Full TRIM for /data and /cache"], ar: ["fstrim يومي", "TRIM كامل لـ /data و /cache"] },
  { key: "DB_VACUUM_ENABLE", en: ["System DB vacuum", "Less fragmentation in system databases"], ar: ["VACUUM لقواعد البيانات", "تفتيت أقل لقواعد بيانات النظام"] },
  { key: "JUNK_CLEAN_ENABLE", en: ["Temp file cleanup", "Clears tmp/anr files older than 7 days"], ar: ["تنظيف ملفات مؤقتة", "يمسح tmp/anr الأقدم من 7 أيام"] },
];

let perfConf = {};

async function loadPerf() {
  const r = await exec(`cat ${MODDIR}/perfkeeper.conf 2>/dev/null`);
  perfConf = {};
  r.stdout.split("\n").forEach((line) => {
    const m = line.match(/^([A-Z0-9_]+)=(.*)$/);
    if (m) perfConf[m[1]] = m[2];
  });
  renderPerfList();
}

function renderPerfList() {
  const el = document.getElementById("perfList");
  el.innerHTML = PERF_TOGGLES.map((tg) => {
    const [label, sub] = LANG === "ar" ? tg.ar : tg.en;
    const isOn = perfConf[tg.key] === "1";
    return `
      <div class="perf-item">
        <div>
          <div class="label">${label}</div>
          <div class="sub">${sub}</div>
        </div>
        <div class="seg-toggle" data-key="${tg.key}">
          <button class="on-btn ${isOn ? "active" : ""}" data-val="1">${t("on")}</button>
          <button class="off-btn ${!isOn ? "active" : ""}" data-val="0">${t("off")}</button>
        </div>
      </div>
    `;
  }).join("");

  el.querySelectorAll(".seg-toggle").forEach((group) => {
    const key = group.dataset.key;
    group.querySelectorAll("button").forEach((btn) => {
      btn.addEventListener("click", async () => {
        const val = btn.dataset.val;
        perfConf[key] = val;
        group.querySelectorAll(".on-btn, .off-btn").forEach((b) => b.classList.remove("active"));
        group.querySelector(val === "1" ? ".on-btn" : ".off-btn").classList.add("active");
        await exec(
          `sed -i "s/^${key}=.*/${key}=${val}/" ${MODDIR}/perfkeeper.conf && ` +
          `sh ${MODDIR}/scripts/apply_perf.sh`
        );
        toast((val === "1" ? "✅ " : "⏸ ") + key);
      });
    });
  });
}
loadPerf();

// ---------------- Logs tab ----------------
let lastLogText = "";
async function loadLog() {
  const el = document.getElementById("logView");
  el.textContent = t("loadingLog");
  const r = await exec("tail -n 300 /sdcard/HyperOSPerfKeeper/perfkeeper.log 2>/dev/null");
  lastLogText = r.stdout.trim();
  el.textContent = lastLogText || t("logEmpty");
}
document.getElementById("refreshLog").addEventListener("click", loadLog);

document.getElementById("copyLog").addEventListener("click", async () => {
  if (!lastLogText) { await loadLog(); }
  try {
    if (navigator.clipboard && navigator.clipboard.writeText) {
      await navigator.clipboard.writeText(lastLogText);
    } else {
      const ta = document.createElement("textarea");
      ta.value = lastLogText;
      ta.style.position = "fixed";
      ta.style.opacity = "0";
      document.body.appendChild(ta);
      ta.focus(); ta.select();
      document.execCommand("copy");
      document.body.removeChild(ta);
    }
    toast(t("copied"));
  } catch (e) {
    toast(t("copyFailed"));
  }
});

// ---------------- Restore tab: per-app selection ----------------
let removedApps = []; // {pkg}
let restoreSearch = "";

function avatarFor(pkg) {
  const label = pkg.split(".").pop() || pkg;
  const initial = (label.charAt(0) || "?").toUpperCase();
  let hash = 0;
  for (let i = 0; i < pkg.length; i++) hash = pkg.charCodeAt(i) + ((hash << 5) - hash);
  const hue = Math.abs(hash) % 360;
  return `<div class="avatar" style="background:hsl(${hue},45%,35%)">${initial}</div>`;
}

async function loadRestoreList() {
  const loadingEl = document.getElementById("restoreLoading");
  const emptyEl = document.getElementById("restoreEmpty");
  const listEl = document.getElementById("restoreList");
  loadingEl.style.display = "block";
  emptyEl.style.display = "none";
  listEl.style.display = "none";

  // `pm list packages -u` returns installed AND uninstalled packages (it's
  // a union, not a filter) -- so the actually-removed set is the difference
  // against the plain (installed-only) list.
  const [allR, instR] = await Promise.all([
    exec("pm list packages -u"),
    exec("pm list packages"),
  ]);
  const parse = (out) => out.split("\n").map((l) => l.replace("package:", "").trim()).filter(Boolean);
  const installedSet = new Set(parse(instR.stdout));
  removedApps = parse(allR.stdout).filter((p) => !installedSet.has(p)).sort();

  loadingEl.style.display = "none";
  renderRestoreList();
}

function renderRestoreList() {
  const emptyEl = document.getElementById("restoreEmpty");
  const listEl = document.getElementById("restoreList");

  if (removedApps.length === 0) {
    emptyEl.style.display = "block";
    listEl.style.display = "none";
    return;
  }
  emptyEl.style.display = "none";

  const q = restoreSearch.toLowerCase();
  const filtered = removedApps.filter((p) => !q || p.toLowerCase().includes(q) || labelFor(p).toLowerCase().includes(q));

  listEl.style.display = "block";
  listEl.innerHTML = filtered.map((pkg) => {
    const rec = curatedFor(pkg);
    const cat = rec ? (LANG === "ar" ? rec.cat_ar : rec.cat_en) : "";
    return `
      <label class="pkg-item">
        <input type="checkbox" data-restore-pkg="${pkg}">
        ${iconHtml(pkg)}
        <div class="pkg-meta">
          ${rec ? `<div class="pkg-tags"><span class="pkg-tag rec">${cat}</span></div>` : ""}
          <span class="app-label">${labelFor(pkg)}</span>
          <span class="pkg-name">${pkg}</span>
        </div>
      </label>
    `;
  }).join("");
}

document.getElementById("restoreSearch").addEventListener("input", (e) => {
  restoreSearch = e.target.value;
  renderRestoreList();
});
document.getElementById("refreshRestore").addEventListener("click", loadRestoreList);

async function runRestore(pkgs) {
  const out = document.getElementById("restoreView");
  const selBtn = document.getElementById("restoreSelectedBtn");
  const allBtn = document.getElementById("restoreAllBtn");
  selBtn.disabled = true; allBtn.disabled = true;
  out.style.display = "block";
  out.textContent = t("restoring");
  try {
    const cmd = pkgs.length
      ? `sh ${MODDIR}/scripts/restore_pkg.sh ${pkgs.join(" ")}`
      : `sh ${MODDIR}/scripts/restore_pkg.sh`;
    const r = await exec(cmd);
    out.textContent = r.stdout.trim() || r.stderr.trim() || t("restoreDone");
    toast(t("restoreDone"));
    await loadAllApps();
    renderPkgList();
    await loadRestoreList();
  } catch (e) {
    out.textContent = String(e);
    toast(t("restoreFailed"));
  } finally {
    selBtn.disabled = false; allBtn.disabled = false;
  }
}

document.getElementById("restoreSelectedBtn").addEventListener("click", () => {
  const picked = [...document.querySelectorAll('#restoreList input[data-restore-pkg]:checked')]
    .map((c) => c.dataset.restorePkg);
  if (picked.length === 0) { toast(t("noSelection")); return; }
  runRestore(picked);
});
document.getElementById("restoreAllBtn").addEventListener("click", () => runRestore([]));

// Per-app delete button, if present anywhere in the UI (wired generically
// so it works even if a future template adds .delete-btn items).
document.addEventListener("click", function (e) {
  if (e.target && e.target.matches(".delete-btn")) {
    const pkg = e.target.dataset.pkg;
    if (pkg) exec("pm uninstall --user 0 " + pkg).then(() => {
      loadAllApps().then(renderPkgList);
      toast("✅ " + pkg);
    });
  }
});

// ---------------- init ----------------
applyLang();
