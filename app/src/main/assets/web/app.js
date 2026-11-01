// MKVENOM Optimizer & Debloater — WebUI logic (v4)
// Uses the standard KernelSU/APatch/Magisk WebUI bridge: window.ksu.exec()
// No Zygisk required — every action here is a plain root shell command.

const MODDIR = "/data/adb/modules/mkvp_tools";
let cbCounter = 0;

// ---------------- i18n ----------------
const I18N = {
  en: {
    tabDebloat: "Debloat", tabPerf: "Perf", tabOtg: "OTG", tabMods: "Modules", tabDev: "Device", tabSens: "Sensors", tabTerm: "Terminal", tabRestore: "Restore", tabLogs: "Logs",
    byLabel: "by",
    refreshBtn: "Refresh",
    debloatWarnGame: "Gaming-performance services (joyose, migameservice, gamecenter.sdk.service, enhance.gameservice) are intentionally excluded from recommendations — removing them hurts gaming performance instead of helping it.",
    loadingRestore: "Checking removed apps…", restoreEmptyMsg: "Nothing removed right now — your trash bin is empty. 🎉",
    brTitle: "Brightness fix",
    brDesc: "Whole-slider brightness remap up to the panel maximum, with thermal derate. Switching applies immediately and is remembered after reboot.",
    brLabel: "Brightness module", brSub: "OFF stops the daemon and releases the backlight node",
    brSaved: "Saved", brRunning: "Daemon", brRunningYes: "RUNNING", brRunningNo: "STOPPED", brStarting: "STARTING…",
    brSetOn: "Brightness module ON", brSetOff: "Brightness module OFF", brFailed: "Brightness switch failed",
    termTitle: "Root terminal",
    termWarn: "Commands run as root. Each command is stopped after 60 s, and interactive programs (top, vi, …) do not work here. Be careful.",
    termPlaceholder: "command…", termRun: "Run", termClear: "Clear",
    loadingShort: "Reading…",
    stoTitle: "Storage", stoLeft: "free", stoFreeLbl: "Free", stoUsedLbl: "Used", stoTotalLbl: "Total",
    ramTitle: "Memory (RAM)", ramUsedOf: "used", ramTotal: "Total", ramAvail: "Available", ramUsedLbl: "Used", ramSwap: "Swap used",
    termModeTerm: "Terminal", termModeLogs: "Logs", tlogTitle: "Log viewer", tlogDesc: "Pick a log. Shows the last lines; refresh to update.",
    tlogEmpty: "This log is empty or does not exist yet.",
    lg_tools: "Tools", lg_otg: "OTG", lg_fod: "FOD", lg_bright: "Brightness", lg_dmesg: "Kernel (dmesg)", lg_logcat: "Logcat",
    senTitle: "Sensor check", senDesc: "Shows which sensors this GSI really exposes to Android. A sensor missing here means the GSI or vendor HAL does not see it — apps cannot use it either.",
    senHwTitle: "Hardware services", senOtherTitle: "All sensors found",
    senAllOk: "All core sensors are detected ✅", senMissing: "Not detected:", senNone: "No sensors reported at all — the sensor HAL is probably not working on this GSI.",
    senFound: "Detected", senMiss: "Missing", senCount: "sensors found",
    sn_accelerometer: "Accelerometer", sn_gyroscope: "Gyroscope", sn_magnetic_field: "Magnetometer (compass)", sn_proximity: "Proximity", sn_light: "Light (auto-brightness)",
    senHal: "Sensors HAL process", senFp: "Fingerprint HAL", senCam: "Cameras", senRunning: "running", senNotRunning: "not found",
    senNote: "Core sensors checked: accelerometer, gyroscope, compass, proximity and light. Others (barometer, step counter …) depend on the phone and are only listed.",
    otgRolesTitle: "USB-C port status", otgDevTitle: "Connected OTG devices", otgLogTitle: "OTG service log",
    otgDevHint: "Plug something into the USB-C port. Detection refreshes every 2 seconds.",
    otgNoDev: "Nothing connected over OTG.", otgRolePref: "Preferred role", otgRolePower: "Power role", otgRoleData: "Data role",
    otgRolePort: "Port type", otgRoleSw: "USB role switch", otgNode: "usb_otg node", otgOnline: "Charger/PC online",
    dt_mouse: "Mouse", dt_keyboard: "Keyboard", dt_storage: "OTG drive / storage", dt_phone: "Phone / camera (MTP-PTP-ADB)",
    dt_hub: "USB hub", dt_audio: "Audio device", dt_camera: "Webcam / video", dt_bluetooth: "Bluetooth adapter",
    dt_gamepad: "Game controller", dt_hid: "Input device", dt_printer: "Printer", dt_serial: "Serial / modem", dt_other: "USB device",
    yes: "Yes", no: "No",
    spTitle: "Game spoofer", spLabel: "Spoof as Galaxy S24 Ultra", spSub: "OFF puts the real device model back",
    spDesc: "Makes the phone report itself as a Samsung Galaxy S24 Ultra (SM-S928B) to unlock higher graphics and frame rates in supported games. Switching applies instantly and is remembered after reboot — close and reopen the game afterwards.",
    spModel: "Model now", spSaved: "Saved", spSetOn: "Spoofer ON — restart the game", spSetOff: "Spoofer OFF — real model restored", spFailed: "Could not change the spoofer",
    spNoRp: "resetprop was not found: the change applies after a reboot.",
    batTitle: "Battery", chgTitle: "Charger", scrTitle: "Screen", scrHz: "Current refresh rate",
    batLevel: "Level", batTemp: "Temperature", batHealth: "Health", batCycles: "Cycles", batVolt: "Voltage", batCurr: "Current", batPower: "Power",
    chgIn: "Input", chgVolt: "Charger voltage", chgCurr: "Charger current", chgPower: "Charger power", chgMax: "Negotiated max", chgType: "Type",
    chgNone: "No charger connected — plug one in to see watts, volts and amps.", chgOn: "Charging",
    st_Charging: "Charging", st_Discharging: "Discharging", st_Full: "Full", st_Not: "Not charging", st_Unknown: "Unknown",
    frTitle: "CPU cluster frequency", frDesc: "Set the lowest and highest clock for each CPU cluster. Saved, applied instantly and re-applied after every boot. Min can never be above max.",
    frWarn: "Locking min = max at the top speed is the fastest setting but runs hot and drains the battery. Thermal protection still applies.",
    frMax: "Max speed (lock)", frFull: "Full range", frMin: "Min", frMaxLbl: "Max", frNow: "now", frDetails: "see details below", frApplied: "Frequency applied", frFailed: "Frequency failed",
    frNone: "No CPU frequency nodes found.",
    govTitle: "CPU / GPU governors",
    govDesc: "Pick a governor per CPU cluster and for the GPU. Choices apply instantly, are saved, and are re-applied after every boot (and every 15 s if the system changes them back).",
    govWarn: "The performance governor pins clocks at maximum: faster, but hotter and heavier on the battery. Thermal protection still applies.",
    govPerfAll: "Performance (CPU + GPU)", govReset: "Restore defaults", govLoading: "Reading governors…",
    govAllCpu: "All CPU clusters", govCluster: "CPU cluster", govGpu: "GPU", govCurrent: "now", govNoGpu: "No GPU governor node found on this device.",
    govNoCpu: "No CPU governor nodes found.", govChoose: "— choose —",
    govApplied: "Applied", govResetDone: "Defaults restored", govFailed: "Failed",
    otgTitle: "USB OTG — Source mode",
    otgDesc: "ON forces the USB-C port to source (phone powers OTG devices) and keeps it there. OFF forces it off and keeps it off. A change applies immediately — no reboot needed.",
    otgLabel: "Source mode OTG", otgSub: "Applied live, re-read at every boot",
    otgSaved: "Saved", otgActive: "Running now",
    otgPending: "Waiting for the OTG service to pick up the change…",
    otgNa: "USB-C port not found on this device, OTG control is inactive.",
    otgUnknown: "starting…",
    otgSetOn: "OTG source mode ON", otgSetOff: "OTG source mode OFF",
    otgSetFailed: "Could not save the OTG setting",
    rebootBtn: "Reboot now", rebootConfirm: "Reboot the phone now?",
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
    bridgeOk: "Root OK", bridgeBad: "No root",
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
    tabDebloat: "الديبلوت", tabPerf: "الأداء", tabOtg: "OTG", tabMods: "الموديولات", tabDev: "الجهاز", tabSens: "السنسورز", tabTerm: "تيرمنال", tabRestore: "الاسترجاع", tabLogs: "اللوج",
    byLabel: "بواسطة",
    refreshBtn: "تحديث",
    debloatWarnGame: "خدمات أداء الألعاب (joyose, migameservice, gamecenter.sdk.service, enhance.gameservice) مستبعدة من التوصيات عمدًا — حذفها بيضر أداء الألعاب بدل ما يفيد.",
    loadingRestore: "بيتحقق من التطبيقات المحذوفة…", restoreEmptyMsg: "مفيش حاجة اتحذفت دلوقتي — سلة المهملات فاضية. 🎉",
    brTitle: "إصلاح السطوع",
    brDesc: "إعادة ضبط سطوع الشريط كله لحد أقصى سطوع للشاشة، مع تخفيف حراري. التبديل بيتطبق فورًا وبيتحفظ بعد الريستارت.",
    brLabel: "موديول السطوع", brSub: "واقف بيوقف الـ daemon ويفك عقدة الإضاءة الخلفية",
    brSaved: "المحفوظ", brRunning: "الـ daemon", brRunningYes: "شغال", brRunningNo: "واقف", brStarting: "بيبدأ…",
    brSetOn: "موديول السطوع شغال", brSetOff: "موديول السطوع واقف", brFailed: "تبديل السطوع فشل",
    termTitle: "تيرمنال الروت",
    termWarn: "الأوامر بتشتغل بصلاحية الروت. كل أمر بيتوقف بعد 60 ثانية، والبرامج التفاعلية (top, vi, …) مش شغالة هنا. خد بالك.",
    termPlaceholder: "اكتب أمر…", termRun: "تشغيل", termClear: "مسح",
    govTitle: "جفرنورات CPU / GPU",
    govDesc: "اختار governor لكل كلستر معالج وللـ GPU. الاختيار بيتطبق فورًا وبيتحفظ وبيترجع يتطبق بعد كل بوت (وكل 15 ثانية لو النظام غيّره).",
    govWarn: "جفرنور performance بيثبّت السرعات على الأقصى: أسرع بس أسخن وأكتر استهلاك للبطارية. الحماية الحرارية لسه شغالة.",
    govPerfAll: "أداء عالي (CPU + GPU)", govReset: "رجّع الافتراضي", govLoading: "بيقرأ الجفرنورات…",
    govAllCpu: "كل كلسترات المعالج", govCluster: "كلستر المعالج", govGpu: "GPU", govCurrent: "حاليًا", govNoGpu: "مفيش عقدة governor للـ GPU على الجهاز.",
    govNoCpu: "مفيش عقد governor للمعالج.", govChoose: "— اختار —",
    govApplied: "اتطبق", govResetDone: "الافتراضي اترجع", govFailed: "فشل",
    otgTitle: "USB OTG — وضع المصدر",
    otgDesc: "التشغيل يجبر منفذ USB-C على وضع المصدر (الهاتف يغذّي أجهزة OTG) ويبقيه كذلك. الإيقاف يطفئه ويبقيه مطفأً. التغيير فوري بدون إعادة تشغيل.",
    otgLabel: "OTG وضع المصدر", otgSub: "يُطبَّق مباشرة ويُقرأ عند كل إقلاع",
    otgSaved: "المحفوظ", otgActive: "شغال دلوقتي",
    otgPending: "بانتظار خدمة OTG لتطبيق التغيير…",
    otgNa: "منفذ USB-C مش موجود على الجهاز، تحكم OTG مش شغال.",
    otgUnknown: "بيبدأ…",
    otgSetOn: "OTG مصدر: تشغيل", otgSetOff: "OTG مصدر: إيقاف",
    otgSetFailed: "معرفتش أحفظ إعداد OTG",
    rebootBtn: "إعادة التشغيل الآن", rebootConfirm: "تعيد تشغيل الموبايل دلوقتي؟",
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
    bridgeOk: "روت شغال", bridgeBad: "مفيش روت",
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
  let v = I18N[LANG][key];
  if (v === undefined) v = I18N.en[key];
  if (v === undefined) return key;
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
  renderOtg();
  renderBr();
  renderGov();
  renderFreq();
  renderSpoof();
  renderDevice();
  renderOtgInfo();
  renderSensors();
  renderFlash();
  renderTLogChips();
  renderTermChips();
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
    stopPoll();
    if (btn.dataset.tab === "otg") { loadOtg(); startPoll(loadOtgInfo, 2000); }
    if (btn.dataset.tab === "mods") { loadBr(); loadFod(); loadRz(); loadCh(); }
    if (btn.dataset.tab === "dev") { startPoll(loadDevice, 2000); loadSel(); }
    if (btn.dataset.tab === "perf") { loadGov(); startPoll(loadFreq, 2000); }
    if (btn.dataset.tab === "sens") loadSensors();
    if (btn.dataset.tab === "flash") loadFlash();
    if (btn.dataset.tab === "term" && tlogMode) loadTLog();
    if (btn.dataset.tab === "term") setTimeout(() => document.getElementById("termInput").focus(), 50);
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
    const res = await fetch("dyn/app_labels.json", { cache: "no-store" });
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
  return `<img class="app-icon" src="dyn/icons/${pkg}.png" loading="lazy"
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

const NATIVE_META = !!window.mkvpui;     // icons + names come straight from the system in the app
const selected = new Set();
const TT = (en, ar) => (LANG === "ar" ? ar : en);
const escHtml = (x) => String(x).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));

function resetSelection() {
  selected.clear();
  const have = new Set(allApps.map((a) => a.pkg));
  curated.forEach((c) => {
    if (c.default && !PROTECTED.includes(c.pkg) && have.has(c.pkg)) selected.add(c.pkg);
  });
}

function updateSelBar() {
  const n = selected.size;
  const recAvail = allApps.filter((a) => curatedFor(a.pkg) && !PROTECTED.includes(a.pkg)).length;
  document.getElementById("selCount").textContent = TT(`${n} selected`, `${n} محدد`);
  document.getElementById("selSub").textContent = n ? "" : TT("Tap apps to select", "اضغط على التطبيقات لتحديدها");
  document.getElementById("chipSel").textContent = TT("Selected", "المحدد") + (n ? ` (${n})` : "");
  document.getElementById("dbStat").innerHTML =
    `<span><b>${allApps.length}</b> ${TT("apps", "تطبيق")}</span>` +
    (curatedActive ? `<span><b>${recAvail}</b> ${TT("recommended", "موصى")}</span>` : "");
  document.getElementById("runDebloat").disabled = n === 0;
}

function rowHtml(a) {
  const rec = curatedFor(a.pkg);
  const locked = PROTECTED.includes(a.pkg);
  const cat = rec ? (LANG === "ar" ? rec.cat_ar : rec.cat_en) : "";
  const desc = rec ? (LANG === "ar" ? rec.desc_ar : rec.desc_en) : "";
  return `
    <label class="pkg-item ${locked ? "locked" : ""}">
      ${iconHtml(a.pkg)}
      <div class="pkg-meta">
        <div class="pkg-tags">
          ${locked ? `<span class="pkg-tag">🔒 ${t("locked")}</span>` : ""}
          ${rec ? `<span class="pkg-tag rec">${escHtml(cat)}</span>` : ""}
          <span class="pkg-tag ${a.source === "system" ? "sys" : "usr"}">${a.source === "system" ? t("filterSystem") : t("filterUser")}</span>
        </div>
        <span class="app-label">${escHtml(labelFor(a.pkg))}</span>
        <span class="pkg-name">${a.pkg}</span>
        ${desc ? `<span class="pkg-desc">${escHtml(desc)}</span>` : ""}
      </div>
      <input type="checkbox" data-pkg="${a.pkg}" ${selected.has(a.pkg) ? "checked" : ""} ${locked ? "disabled" : ""}>
    </label>`;
}

function renderPkgList() {
  const listEl = document.getElementById("pkgList");
  const loadingEl = document.getElementById("pkgLoading");
  const q = currentSearch.toLowerCase();
  const filtered = allApps.filter((a) => {
    if (q && !a.pkg.toLowerCase().includes(q) && !labelFor(a.pkg).toLowerCase().includes(q)) return false;
    if (currentFilter === "recommended") return !!curatedFor(a.pkg);
    if (currentFilter === "system") return a.source === "system";
    if (currentFilter === "user") return a.source === "user";
    if (currentFilter === "selected") return selected.has(a.pkg);
    return true;
  });
  filtered.sort((x, y) => {
    const rx = curatedFor(x.pkg) ? 1 : 0, ry = curatedFor(y.pkg) ? 1 : 0;
    if (rx !== ry) return ry - rx;
    return labelFor(x.pkg).localeCompare(labelFor(y.pkg));
  });
  listEl.innerHTML = filtered.length
    ? filtered.map(rowHtml).join("")
    : `<div class="card sub" style="text-align:center">${TT("No apps match", "مفيش تطبيقات مطابقة")}</div>`;
  loadingEl.style.display = "none";
  listEl.style.display = "block";
  updateSelBar();
}

let searchTimer = null;
document.getElementById("pkgSearch").addEventListener("input", (e) => {
  currentSearch = e.target.value;
  clearTimeout(searchTimer);
  searchTimer = setTimeout(renderPkgList, 120);
});
document.querySelectorAll("#tab-debloat .chip").forEach((chip) => {
  chip.addEventListener("click", () => {
    document.querySelectorAll("#tab-debloat .chip").forEach((c) => c.classList.remove("active"));
    chip.classList.add("active");
    currentFilter = chip.dataset.filter;
    renderPkgList();
  });
});
document.getElementById("pkgList").addEventListener("change", (e) => {
  const el = e.target;
  if (!el.matches || !el.matches("input[data-pkg]")) return;
  if (el.checked) selected.add(el.dataset.pkg); else selected.delete(el.dataset.pkg);
  updateSelBar();
});
document.getElementById("selRec").addEventListener("click", () => { resetSelection(); renderPkgList(); });
document.getElementById("selClear").addEventListener("click", () => { selected.clear(); renderPkgList(); });

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
  resetSelection();
  const vb = document.getElementById("vendorBadge");
  if (vb) vb.textContent = t("detectedRom") + ": " + t("rom_" + detectedVendor);
  renderPkgList();
  if (!NATIVE_META) autoLoadIconsAndNames(); // browser fallback only: the app reads icons/names natively
}
initDebloatTab();

document.getElementById("runDebloat").addEventListener("click", async () => {
  const checked = [...selected];
  if (checked.length === 0) { toast(t("noSelection")); return; }
  const names = checked.slice(0, 6).map((p) => "• " + labelFor(p)).join("\n") + (checked.length > 6 ? `\n… +${checked.length - 6}` : "");
  if (!window.confirm(TT(
    `Remove ${checked.length} app(s) for the current user?\n\n${names}\n\nYou can bring them back from the Restore tab.`,
    `إزالة ${checked.length} تطبيق للمستخدم الحالي؟\n\n${names}\n\nتقدر ترجعهم من تبويب الاستعادة.`))) return;

  const deleteUi = document.getElementById("deleteUiAfter").checked ? "1" : "0";
  const btn = document.getElementById("runDebloat");
  const statusEl = document.getElementById("debloatStatus");
  btn.disabled = true;
  statusEl.style.display = "block";
  statusEl.innerHTML = `<div class="prog"><i style="width:3%"></i></div><div class="sub">${t("removing", checked.length)}</div>`;
  statusEl.scrollIntoView({ behavior: "smooth", block: "nearest" });

  await exec(`sh ${MODDIR}/scripts/debloat_run.sh ${deleteUi} ${checked.join(" ")}`);

  let tries = 0;
  const poll = setInterval(async () => {
    tries++;
    try {
      const r = await fetch("dyn/status.json", { cache: "no-store" });
      const s = await r.json();
      const pct = s.total ? Math.round((s.done * 100) / s.total) : 0;
      statusEl.innerHTML =
        `<div class="prog"><i style="width:${Math.max(pct, 3)}%"></i></div><div class="sub">${s.done}/${s.total}</div>` +
        s.results.map((x) => `<div class="resrow ${x.ok ? "ok" : "bad"}"><span class="m">${x.ok ? "✓" : "!"}</span>${escHtml(labelFor(x.pkg))}</div>`).join("");
      if (s.state === "done") {
        clearInterval(poll);
        const failed = s.results.filter((x) => !x.ok).length;
        toast(failed ? TT(`Done, ${failed} failed`, `تم، فشل ${failed}`) : t("done"));
        setTimeout(() => { initDebloatTab(); btn.textContent = t("runDebloatBtn"); }, 1200);
      }
    } catch (e) { /* not written yet */ }
    if (tries > 90) { clearInterval(poll); btn.disabled = false; }
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
  const r = await exec(`cat ${MODDIR}/systemperf.conf 2>/dev/null`);
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
          `sed -i "s/^${key}=.*/${key}=${val}/" ${MODDIR}/systemperf.conf && ` +
          `sh ${MODDIR}/scripts/apply_perf.sh`
        );
        toast((val === "1" ? "✅ " : "⏸ ") + key);
      });
    });
  });
}
loadPerf();

// ---------------- OTG tab (source mode ON / OFF, applied at next boot) ----------------
const OTG_DIR = "/data/adb/mkvp_tools";
let otgSaved = "on";   // what is stored in otg_mode (applies at next boot)
let otgActive = "";    // what the running service is enforcing: on | off | na | "" (not started yet)

async function loadOtg() {
  const r = await exec(`cat ${OTG_DIR}/otg_mode 2>/dev/null; echo "|"; cat ${OTG_DIR}/otg_active 2>/dev/null`);
  const parts = r.stdout.split("|");
  const clean = (v) => (v || "").trim();
  const saved = clean(parts[0]);
  otgSaved = saved === "off" ? "off" : "on";
  const act = clean(parts[1]);
  otgActive = ["on", "off", "na"].includes(act) ? act : "";
  renderOtg();
}

function renderOtg() {
  const tg = document.getElementById("otgToggle");
  if (!tg) return;
  tg.querySelector(".on-btn").classList.toggle("active", otgSaved === "on");
  tg.querySelector(".off-btn").classList.toggle("active", otgSaved === "off");
  document.getElementById("otgSaved").textContent = t(otgSaved);
  document.getElementById("otgActive").textContent =
    otgActive === "on" || otgActive === "off" ? t(otgActive) : (otgActive === "na" ? "—" : t("otgUnknown"));
  const pending = (otgActive === "on" || otgActive === "off") && otgActive !== otgSaved;
  document.getElementById("otgPending").style.display = pending ? "block" : "none";
  document.getElementById("otgNa").style.display = otgActive === "na" ? "block" : "none";
}

document.querySelectorAll("#otgToggle button").forEach((btn) => {
  btn.addEventListener("click", async () => {
    const val = btn.dataset.val;
    if (val !== "on" && val !== "off") return;
    if (btn._busy) return; btn._busy = true;
    // temp file + rename, so a half-written value can never be read
    const r = await exec(
      `mkdir -p ${OTG_DIR} && echo ${val} > ${OTG_DIR}/otg_mode.tmp && mv -f ${OTG_DIR}/otg_mode.tmp ${OTG_DIR}/otg_mode`
    );
    await loadOtg();
    if (r.errno !== 0 || otgSaved !== val) { toast(t("otgSetFailed")); btn._busy = false; return; }
    // the service re-reads the mode every second; wait for it to confirm
    await new Promise((res) => setTimeout(res, 1800));
    await loadOtg();
    if (otgActive !== val) {
      // service not running (crashed / never started): start it now, no reboot needed
      await exec(`(nohup sh ${MODDIR}/otg/service.sh >/dev/null 2>&1 &) ; sleep 1`);
      for (let i = 0; i < 8 && otgActive !== val; i++) { await new Promise((res) => setTimeout(res, 1500)); await loadOtg(); }
    }
    toast(otgActive === val ? t(val === "on" ? "otgSetOn" : "otgSetOff") : t("otgSetFailed"));
    btn._busy = false;
  });
});

document.getElementById("otgReboot").addEventListener("click", () => {
  if (window.confirm(t("rebootConfirm"))) exec("sync; reboot");
});
loadOtg();

// ---------------- Brightness module ON / OFF (applies immediately) ----------------
const BR_CTL = `sh ${MODDIR}/scripts/brightness_ctl.sh`;
let brState = { mode: "on", running: false, info: "", busy: "" };

async function loadBr() {
  const r = await exec(`${BR_CTL} status`);
  const kv = {};
  r.stdout.split("\n").forEach((l) => { const i = l.indexOf("="); if (i > 0) kv[l.slice(0, i)] = l.slice(i + 1).trim(); });
  brState.mode = kv.mode === "off" ? "off" : "on";
  brState.running = kv.running === "1";
  brState.info = kv.info || "";
  renderBr();
}

function renderBr() {
  const tg = document.getElementById("brToggle");
  if (!tg) return;
  tg.querySelector(".on-btn").classList.toggle("active", brState.mode === "on");
  tg.querySelector(".off-btn").classList.toggle("active", brState.mode === "off");
  tg.querySelectorAll("button").forEach((b) => { b.disabled = !!brState.busy; });
  document.getElementById("brSaved").textContent = t(brState.mode);
  document.getElementById("brRunning").textContent =
    brState.busy === "on" ? t("brStarting") : (brState.running ? t("brRunningYes") : t("brRunningNo"));
  document.getElementById("brInfo").textContent = brState.running ? brState.info : "";
}

document.querySelectorAll("#brToggle button").forEach((btn) => {
  btn.addEventListener("click", async () => {
    const val = btn.dataset.val;
    if ((val !== "on" && val !== "off") || val === brState.mode || brState.busy) return;
    brState.busy = val; brState.mode = val; renderBr();
    const r = await exec(`${BR_CTL} ${val}`);
    let ok = r.stdout.includes("OK");
    if (ok && val === "on") {
      // the daemon needs a few seconds (boot-safe warm-up); wait until it really is up
      ok = false;
      for (let i = 0; i < 12 && !ok; i++) {
        await new Promise((res) => setTimeout(res, 1000));
        const s = await exec(`${BR_CTL} status`);
        ok = s.stdout.includes("running=1");
      }
    }
    brState.busy = "";
    await loadBr();
    toast(ok ? t(val === "on" ? "brSetOn" : "brSetOff") : t("brFailed"));
  });
});


// ---------------- FOD fix ON / OFF (Modules tab) ----------------
const FOD_CTL = `sh ${MODDIR}/scripts/fod_ctl.sh`;
Object.assign(I18N.en, { fodTitle: "FOD fix", fodDesc: "Under-display fingerprint fix: sensor position, fingerprint watcher and overlay. Switching applies right away; the boot-time parts are fully reverted after a reboot.",
  fodLabel: "FOD fix", fodSub: "OFF stops the fingerprint watcher and disables the overlay", fodWatcher: "Watcher", fodSetOn: "FOD fix ON", fodSetOff: "FOD fix OFF — reboot to fully revert", fodFailed: "FOD switch failed", fodStarting: "STARTING…" });
Object.assign(I18N.ar, { fodTitle: "إصلاح FOD", fodDesc: "إصلاح بصمة الشاشة: موقع الحساس ومراقب البصمة والأوفرلاي. التبديل فوري، وأجزاء الإقلاع تتراجع كلياً بعد إعادة التشغيل.",
  fodLabel: "إصلاح FOD", fodSub: "الإيقاف يوقف مراقب البصمة ويعطّل الأوفرلاي", fodWatcher: "المراقب", fodSetOn: "تم تشغيل FOD", fodSetOff: "تم إيقاف FOD — أعد التشغيل للتراجع الكامل", fodFailed: "فشل تبديل FOD", fodStarting: "جاري البدء…" });
let fodState = { mode: "on", running: false, info: "", busy: "" };
async function loadFod() {
  const r = await exec(`${FOD_CTL} status`);
  const o = {}; r.stdout.split("\n").forEach((l) => { const i = l.indexOf("="); if (i > 0) o[l.slice(0, i)] = l.slice(i + 1).trim(); });
  fodState.mode = o.mode === "off" ? "off" : "on"; fodState.running = o.running === "1"; fodState.info = o.overlay || "";
  renderFod();
}
function renderFod() {
  const tg = document.getElementById("fodToggle"); if (!tg) return;
  tg.querySelector(".on-btn").classList.toggle("active", fodState.mode === "on");
  tg.querySelector(".off-btn").classList.toggle("active", fodState.mode === "off");
  tg.querySelectorAll("button").forEach((b) => { b.disabled = !!fodState.busy; });
  document.getElementById("fodSaved").textContent = t(fodState.mode);
  document.getElementById("fodRunning").textContent = fodState.busy === "on" ? t("fodStarting") : (fodState.running ? t("brRunningYes") : t("brRunningNo"));
  document.getElementById("fodInfo").textContent = fodState.info;
}
document.querySelectorAll("#fodToggle button").forEach((btn) => {
  btn.addEventListener("click", async () => {
    const val = btn.dataset.val;
    if ((val !== "on" && val !== "off") || val === fodState.mode || fodState.busy) return;
    fodState.busy = val; fodState.mode = val; renderFod();
    const r = await exec(`${FOD_CTL} ${val}`);
    let ok = r.stdout.includes("OK");
    if (ok && val === "on") {   // service.sh waits ~8 s before starting the watcher
      ok = false;
      for (let i = 0; i < 16 && !ok; i++) { await new Promise((res) => setTimeout(res, 1000)); ok = (await exec(`${FOD_CTL} status`)).stdout.includes("running=1"); }
    }
    fodState.busy = ""; await loadFod();
    toast(ok ? t(val === "on" ? "fodSetOn" : "fodSetOff") : t("fodFailed"));
  });
});


// ---------------- Fast charge fix ON / OFF (Modules tab) ----------------
const CH_CTL = `sh ${MODDIR}/scripts/charge_ctl.sh`;
Object.assign(I18N.en, { chTitle: "Fast charge fix", chDesc: "Removes the charge throttle that held the phone at about 11 W and keeps it removed. ON by default and re-applied after every boot. OFF stops it, puts the original value back and it stays off after reboot. Pauses itself above 42 °C.",
  chLabel: "Fast charge fix", chSub: "OFF restores the stock charge limit", chLoop: "Loop", chLimit: "Limit", chTemp: "Temp", chSetOn: "Fast charge fix ON", chSetOff: "Fast charge fix OFF", chFailed: "Fast charge switch failed", chHot: "paused (hot)" });
Object.assign(I18N.ar, { chTitle: "إصلاح الشحن السريع", chDesc: "يزيل قيد الشحن الذي كان يحصر الهاتف عند 11 واط ويبقيه مزالاً. مفعّل افتراضياً ويُطبَّق بعد كل إقلاع. الإيقاف يعيد القيمة الأصلية ويبقى متوقفاً بعد إعادة التشغيل. يتوقف تلقائياً فوق 42 °م.",
  chLabel: "إصلاح الشحن السريع", chSub: "الإيقاف يعيد حد الشحن الأصلي", chLoop: "الحلقة", chLimit: "الحد", chTemp: "الحرارة", chSetOn: "تم تشغيل الشحن السريع", chSetOff: "تم إيقاف الشحن السريع", chFailed: "فشل تبديل الشحن السريع", chHot: "متوقف (سخونة)" });
let chState = { mode: "on", running: false, limit: "", temp: "", watts: "", busy: false };
async function loadCh() {
  const r = await exec(`${CH_CTL} status`);
  const o = {}; r.stdout.split("\n").forEach((l) => { const i = l.indexOf("="); if (i > 0) o[l.slice(0, i)] = l.slice(i + 1).trim(); });
  chState.mode = o.mode === "off" ? "off" : "on"; chState.running = o.running === "1";
  chState.limit = o.limit || ""; chState.temp = o.temp || ""; chState.watts = o.watts || "";
  renderCh();
}
function renderCh() {
  const tg = document.getElementById("chToggle"); if (!tg) return;
  tg.querySelector(".on-btn").classList.toggle("active", chState.mode === "on");
  tg.querySelector(".off-btn").classList.toggle("active", chState.mode === "off");
  tg.querySelectorAll("button").forEach((b) => { b.disabled = chState.busy; });
  document.getElementById("chSaved").textContent = t(chState.mode);
  document.getElementById("chRunning").textContent = chState.running ? t("brRunningYes") : t("brRunningNo");
  document.getElementById("chLimit").textContent = chState.limit || "?";
  const tn = parseInt(chState.temp, 10);
  document.getElementById("chTemp").textContent = isNaN(tn) ? "?" : (tn / 10).toFixed(1) + " °C" + (chState.mode === "on" && tn >= 420 ? " — " + t("chHot") : "");
  document.getElementById("chInfo").textContent = chState.watts ? "≈ " + chState.watts + " W" : "";
}
document.querySelectorAll("#chToggle button").forEach((btn) => {
  btn.addEventListener("click", async () => {
    const val = btn.dataset.val;
    if ((val !== "on" && val !== "off") || val === chState.mode || chState.busy) return;
    chState.busy = true; chState.mode = val; renderCh();
    const r = await exec(`${CH_CTL} ${val}`);
    const ok = r.stdout.includes("OK");
    chState.busy = false; await loadCh();
    toast(ok ? t(val === "on" ? "chSetOn" : "chSetOff") : t("chFailed"));
  });
});
setInterval(() => { const el = document.getElementById("tab-mods"); if (el && el.classList.contains("active") && !chState.busy) loadCh(); }, 3000);

// ---------------- SELinux mode (Device tab) ----------------
const SEL_CTL = `sh ${MODDIR}/scripts/selinux_ctl.sh`;
let selState = { mode: "", saved: "none", busy: false, info: "" };
async function loadSel() {
  const r = await exec(`${SEL_CTL} status`);
  const o = {}; r.stdout.split("\n").forEach((l) => { const i = l.indexOf("="); if (i > 0) o[l.slice(0, i)] = l.slice(i + 1).trim(); });
  selState.mode = o.mode || ""; selState.saved = o.saved || "none";
  renderSel();
}
function renderSel() {
  const tg = document.getElementById("selToggle"); if (!tg) return;
  tg.querySelector(".on-btn").classList.toggle("active", selState.mode === "enforcing");
  tg.querySelector(".off-btn").classList.toggle("active", selState.mode === "permissive");
  tg.querySelectorAll("button").forEach((b) => { b.disabled = selState.busy || (selState.mode !== "enforcing" && selState.mode !== "permissive"); });
  const cap = (x) => (x && x !== "none" ? x.charAt(0).toUpperCase() + x.slice(1) : (x === "none" ? "Not changed" : "?"));
  document.getElementById("selNow").textContent = cap(selState.mode) || "?";
  document.getElementById("selSaved").textContent = cap(selState.saved);
  document.getElementById("selInfo").textContent = selState.info;
}
document.querySelectorAll("#selToggle button").forEach((btn) => {
  btn.addEventListener("click", async () => {
    const val = btn.dataset.val;
    if ((val !== "enforcing" && val !== "permissive") || val === selState.mode || selState.busy) return;
    selState.busy = true; selState.info = ""; renderSel();
    const r = await exec(`${SEL_CTL} ${val}`);
    const ok = /^OK/m.test(r.stdout);
    selState.busy = false; selState.info = ok ? "" : r.stdout.replace(/^ERR /gm, "").trim();
    await loadSel();
    toast(ok ? "SELinux: " + val : "SELinux: failed");
  });
});

// ---------------- ReZygisk (bundled, default OFF) ----------------
const RZ_CTL = `sh ${MODDIR}/scripts/rezygisk_ctl.sh`;
let rzState = { mode: "off", installed: false, leftover: 0, running: false, version: "", bundled: "", info: "", busy: "" };
async function loadRz() {
  const r = await exec(`${RZ_CTL} status`);
  const o = {}; r.stdout.split("\n").forEach((l) => { const i = l.indexOf("="); if (i > 0) o[l.slice(0, i)] = l.slice(i + 1).trim(); });
  rzState = Object.assign(rzState, { mode: o.mode === "on" ? "on" : "off", installed: o.installed === "1", leftover: parseInt(o.leftover, 10) || 0, running: o.running === "1", version: o.version || "", bundled: o.bundled || "" });
  renderRz();
}
function renderRz() {
  const tg = document.getElementById("rzToggle"); if (!tg) return;
  tg.querySelector(".on-btn").classList.toggle("active", rzState.mode === "on");
  tg.querySelector(".off-btn").classList.toggle("active", rzState.mode === "off");
  tg.querySelectorAll("button").forEach((b) => { b.disabled = !!rzState.busy; });
  document.getElementById("rzSaved").textContent = t(rzState.mode);
  let st = "Not installed (no files)";
  if (rzState.busy === "on") st = "Flashing…";
  else if (rzState.busy === "off") st = "Deleting…";
  else if (rzState.installed) st = rzState.running ? "Running" : "Flashed (reboot to start)";
  else if (rzState.leftover > 0) st = "Leftover files: " + rzState.leftover;
  else if (rzState.running) st = "Deleted (reboot to unload)";
  document.getElementById("rzState").textContent = st;
  document.getElementById("rzInfo").textContent = rzState.info || (rzState.installed ? rzState.version : "Bundled: " + rzState.bundled);
}
document.querySelectorAll("#rzToggle button").forEach((btn) => {
  btn.addEventListener("click", async () => {
    const val = btn.dataset.val;
    if ((val !== "on" && val !== "off") || val === rzState.mode || rzState.busy) return;
    rzState.busy = val; rzState.info = ""; renderRz();
    const r = await execT(`${RZ_CTL} ${val}`, 200000);
    const ok = /^OK/m.test(r.stdout);
    rzState.busy = ""; rzState.info = r.stdout.trim();
    await loadRz();
    toast(ok ? (val === "on" ? "ReZygisk flashed - reboot to apply" : "ReZygisk deleted - reboot to unload it") : "ReZygisk: failed");
  });
});

// ---------------- CPU / GPU governors ----------------
const GOV_CTL = `sh ${MODDIR}/scripts/gov.sh`;
const GOV_NAME = /^[A-Za-z0-9_.-]+$/;
let govData = { cpu: [], gpu: null, loaded: false };
let govBusy = false;

async function loadGov() {
  const r = await exec(`${GOV_CTL} status`);
  govData = { cpu: [], gpu: null, loaded: true };
  r.stdout.split("\n").forEach((line) => {
    const p = line.trim().split("|");
    if (p[0] === "CPU" && p.length >= 5) {
      govData.cpu.push({ name: p[1], cpus: p[2], cur: p[3], avail: p[4].split(" ").filter((g) => GOV_NAME.test(g)), saved: p[5] || "" });
    } else if (p[0] === "GPU" && p[1] && p[1] !== "none" && p.length >= 4) {
      govData.gpu = { name: p[1], cur: p[2], avail: p[3].split(" ").filter((g) => GOV_NAME.test(g)), saved: p[4] || "" };
    }
  });
  renderGov();
}

function govSelect(id, avail, cur, withChoose) {
  const opts = (withChoose ? `<option value="">${t("govChoose")}</option>` : "") +
    avail.map((g) => `<option value="${g}" ${g === cur ? "selected" : ""}>${g}</option>`).join("");
  return `<select class="gov-select" data-gov="${id}" ${govBusy ? "disabled" : ""}>${opts}</select>`;
}

function renderGov() {
  const el = document.getElementById("govList");
  if (!el) return;
  if (!govData.loaded) return;
  // union of governors every cluster supports, for the "all clusters" row
  let common = null;
  govData.cpu.forEach((c) => { common = common ? common.filter((g) => c.avail.includes(g)) : c.avail.slice(); });
  let html = "";
  if (govData.cpu.length) {
    html += `<div class="perf-item"><div><div class="label">${t("govAllCpu")}</div></div>${govSelect("cpu:all", common || [], "", true)}</div>`;
    html += govData.cpu.map((c) => `
      <div class="perf-item"><div><div class="label">${t("govCluster")} ${c.name.replace(/^policy/, "")}</div>
        <div class="sub">cpu ${c.cpus || "?"} · ${t("govCurrent")}: <b>${c.cur}</b></div></div>
        ${govSelect("cpu:" + c.name, c.avail, c.cur, false)}</div>`).join("");
  } else {
    html += `<div class="sub">${t("govNoCpu")}</div>`;
  }
  if (govData.gpu) {
    const g = govData.gpu;
    html += `<div class="perf-item"><div><div class="label">${t("govGpu")}</div>
      <div class="sub">${g.name} · ${t("govCurrent")}: <b>${g.cur}</b></div></div>${govSelect("gpu", g.avail, g.cur, false)}</div>`;
  } else {
    html += `<div class="sub">${t("govNoGpu")}</div>`;
  }
  el.innerHTML = html;
  el.querySelectorAll(".gov-select").forEach((sel) => {
    sel.addEventListener("change", () => { if (sel.value) setGov(sel.dataset.gov, sel.value); else renderGov(); });
  });
  ["govPerfAll", "govReset", "govRefresh"].forEach((id) => { const b = document.getElementById(id); if (b) b.disabled = govBusy; });
}

async function setGov(target, gov) {
  if (govBusy || !GOV_NAME.test(gov)) return;
  const [kind, which] = target.split(":");
  const cmd = kind === "gpu" ? `${GOV_CTL} set gpu ${gov}` : `${GOV_CTL} set cpu ${which} ${gov}`;
  govBusy = true; renderGov();
  const r = await exec(cmd);
  govBusy = false;
  await loadGov();
  toast(r.stdout.includes("OK") ? `${t("govApplied")}: ${gov}` : `${t("govFailed")}: ${r.stdout.trim().split("\n").pop() || gov}`);
}

document.getElementById("govPerfAll").addEventListener("click", async () => {
  if (govBusy) return;
  govBusy = true; renderGov();
  const out = [];
  if (govData.cpu.length) out.push((await exec(`${GOV_CTL} set cpu all performance`)).stdout);
  if (govData.gpu) out.push((await exec(`${GOV_CTL} set gpu performance`)).stdout);
  govBusy = false;
  await loadGov();
  toast(out.some((o) => o.includes("OK")) ? `${t("govApplied")}: performance` : t("govFailed"));
});
document.getElementById("govReset").addEventListener("click", async () => {
  if (govBusy) return;
  govBusy = true; renderGov();
  await exec(`${GOV_CTL} reset`);
  govBusy = false;
  await loadGov();
  await loadFreq();
  toast(t("govResetDone"));
});
document.getElementById("govRefresh").addEventListener("click", loadGov);

// ---------------- shared helpers for the new tabs ----------------
function esc(x) { return String(x).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c])); }
let pollTimer = null;
function stopPoll() { if (pollTimer) { clearInterval(pollTimer); pollTimer = null; } }
function startPoll(fn, ms) { stopPoll(); fn(); pollTimer = setInterval(() => { if (!document.hidden) fn(); }, ms); }
function parseLines(out) { return out.split("\n").map((l) => l.trim().split("|")).filter((p) => p.length > 1); }
function kv(label, val) { return `<div><span class="k">${esc(label)}</span><b>${esc(val)}</b></div>`; }
const nV = (x) => { x = Number(x); if (!isFinite(x) || x === 0) return null; const a = Math.abs(x); return a >= 100000 ? a / 1e6 : (a >= 1000 ? a / 1000 : a); };
const nA = (x) => { x = Number(x); if (!isFinite(x)) return null; const a = Math.abs(x); return a >= 20000 ? a / 1e6 : a / 1000; };
const f2 = (x) => (x === null ? "—" : x.toFixed(2));

// ---------------- Device tab: spoofer, battery, charger, screen Hz ----------------
const SP_CTL = `sh ${MODDIR}/scripts/spoof_ctl.sh`;
let spState = { mode: "off", model: "", rp: "1", loaded: false, busy: false };
async function loadSpoof() {
  const r = await exec(`${SP_CTL} status`);
  const o = {}; r.stdout.split("\n").forEach((l) => { const i = l.indexOf("="); if (i > 0) o[l.slice(0, i).trim()] = l.slice(i + 1).trim(); });
  spState.mode = o.mode === "off" ? "off" : "on"; spState.model = o.model || ""; spState.rp = o.rp || "0"; spState.loaded = true;
  renderSpoof();
}
function renderSpoof() {
  const tg = document.getElementById("spToggle"); if (!tg) return;
  tg.querySelector(".on-btn").classList.toggle("active", spState.mode === "on");
  tg.querySelector(".off-btn").classList.toggle("active", spState.mode === "off");
  document.getElementById("spModel").textContent = spState.model || "…";
  document.getElementById("spSaved").textContent = t(spState.mode);
  document.getElementById("spInfo").textContent = spState.loaded && spState.rp !== "1" ? t("spNoRp") : "";
}
document.querySelectorAll("#spToggle button").forEach((btn) => {
  btn.addEventListener("click", async () => {
    const val = btn.dataset.val;
    if (spState.busy || val === spState.mode) return;
    spState.busy = true;
    const r = await exec(`${SP_CTL} ${val}`);
    spState.busy = false;
    await loadSpoof();
    toast(r.stdout.includes("OK") && spState.mode === val ? t(val === "on" ? "spSetOn" : "spSetOff") : t("spFailed"));
  });
});

let devData = null, devBusy = false;
async function loadDevice() {
  if (devBusy) return; devBusy = true;
  const r = await exec(`sh ${MODDIR}/scripts/dev_info.sh`);
  devBusy = false;
  const d = {};
  parseLines(r.stdout).forEach((p) => { d[p[0]] = p; });
  devData = d;
  renderDevice();
}
function statusKey(s) {
  if (/^charging/i.test(s)) return "st_Charging";
  if (/^discharging/i.test(s)) return "st_Discharging";
  if (/^full/i.test(s)) return "st_Full";
  if (/not/i.test(s)) return "st_Not";
  return "st_Unknown";
}
function renderDevice() {
  if (!devData) return;
  const b = devData.BAT || [], u = devData.USB || [];
  const pct = Number(b[1]);
  const status = b[2] || "";
  document.getElementById("batPct").textContent = isFinite(pct) && b[1] !== "" ? pct + "%" : "–";
  document.getElementById("batState").textContent = t(statusKey(status));
  document.getElementById("batFill").style.width = (isFinite(pct) ? Math.max(0, Math.min(100, pct)) : 0) + "%";
  const bv = nV(b[3]), ba = nA(b[4]);
  const temp = Number(b[5]);
  let g = "";
  g += kv(t("batVolt"), bv === null ? "—" : f2(bv) + " V");
  g += kv(t("batCurr"), ba === null ? "—" : f2(ba) + " A");
  g += kv(t("batPower"), bv === null || ba === null ? "—" : f2(bv * ba) + " W");
  g += kv(t("batTemp"), isFinite(temp) && b[5] !== "" ? (temp / 10).toFixed(1) + " °C" : "—");
  g += kv(t("batHealth"), b[6] || "—");
  g += kv(t("batCycles"), b[8] || "—");
  document.getElementById("batGrid").innerHTML = g;

  const online = u[1] === "1" || (devData.AC && devData.AC[1] === "1") || /^charging/i.test(status);
  const cc = document.getElementById("chgCard");
  const cg = document.getElementById("chgGrid");
  if (online) {
    const uv = nV(u[2]), ua = nA(u[3]);
    const mv = nV(u[4]), ma = nA(u[5]);
    let c = "";
    c += kv(t("chgVolt"), uv === null ? "—" : f2(uv) + " V");
    c += kv(t("chgCurr"), ua === null || Number(u[3]) === 0 ? "—" : f2(ua) + " A");
    c += kv(t("chgPower"), uv === null || ua === null || Number(u[3]) === 0 ? "—" : f2(uv * ua) + " W");
    c += kv(t("batPower") + " (" + t("batCurr").toLowerCase() + " × " + t("batVolt").toLowerCase() + ")", bv === null || ba === null ? "—" : f2(bv * ba) + " W");
    if (mv !== null || ma !== null) c += kv(t("chgMax"), (mv === null ? "—" : f2(mv) + " V") + " / " + (ma === null ? "—" : f2(ma) + " A"));
    if (u[6]) c += kv(t("chgType"), u[6]);
    cg.innerHTML = c;
    document.getElementById("chgNote").textContent = "";
  } else {
    cg.innerHTML = "";
    document.getElementById("chgNote").textContent = t("chgNone");
  }
  cc.classList.toggle("chg-on", online);
  const m = devData.MEM || [];
  const tot = Number(m[1]), av = Number(m[2]), st = Number(m[3]), sf = Number(m[4]);
  if (isFinite(tot) && tot > 0 && isFinite(av)) {
    const used = tot - av, gb = (kb) => (kb / 1048576).toFixed(2) + " GB";
    const p = Math.round((used / tot) * 100);
    document.getElementById("ramPct").textContent = p + "%";
    document.getElementById("ramUsed").textContent = gb(used) + " / " + gb(tot);
    document.getElementById("ramFill").style.width = p + "%";
    let r = kv(t("ramUsedLbl"), gb(used)) + kv(t("ramAvail"), gb(av)) + kv(t("ramTotal"), gb(tot));
    if (isFinite(st) && st > 0) r += kv(t("ramSwap"), gb(st - (isFinite(sf) ? sf : 0)) + " / " + gb(st));
    document.getElementById("ramGrid").innerHTML = r;
  }
  const so = devData.STO || [];
  const sTot = Number(so[1]), sUsed = Number(so[2]), sAv = Number(so[3]);
  if (isFinite(sTot) && sTot > 0 && isFinite(sAv)) {
    const gbd = (kb) => ((kb * 1024) / 1e9).toFixed(1) + " GB";   // decimal GB, like Android Settings
    const usedAll = sTot - sAv;
    const p = Math.round((usedAll / sTot) * 100);
    document.getElementById("stoFree").textContent = gbd(sAv) + " " + t("stoLeft");
    document.getElementById("stoUsed").textContent = p + "% · " + gbd(usedAll) + " / " + gbd(sTot);
    document.getElementById("stoFill").style.width = Math.max(0, Math.min(100, p)) + "%";
    document.getElementById("stoGrid").innerHTML = kv(t("stoFreeLbl"), gbd(sAv)) + kv(t("stoUsedLbl"), gbd(usedAll)) + kv(t("stoTotalLbl"), gbd(sTot));
  }
  const hz = devData.HZ && devData.HZ[1] ? Number(devData.HZ[1]) : NaN;
  document.getElementById("scrHz").textContent = isFinite(hz) ? Math.round(hz) + " Hz" : "—";
}

// ---------------- OTG tab: port status + connected device detection ----------------
let otgInfo = null, otgInfoBusy = false;
async function loadOtgInfo() {
  if (otgInfoBusy) return; otgInfoBusy = true;
  const r = await exec(`sh ${MODDIR}/scripts/otg_info.sh`);
  otgInfoBusy = false;
  const info = { role: null, dev: [], log: [] };
  parseLines(r.stdout).forEach((p) => {
    if (p[0] === "ROLE") info.role = p;
    else if (p[0] === "DEV") info.dev.push(p);
    else if (p[0] === "LOG") info.log.push(p.slice(1).join("|"));
  });
  otgInfo = info;
  renderOtgInfo();
}
function renderOtgInfo() {
  if (!otgInfo) return;
  const r = otgInfo.role || [];
  const cur = (x) => { const m = /\[([^\]]+)\]/.exec(x || ""); return m ? m[1] : (x || "—"); };
  let g = "";
  g += kv(t("otgRolePref"), r[1] || "—");
  g += kv(t("otgRolePower"), cur(r[2]));
  g += kv(t("otgRoleData"), cur(r[3]));
  g += kv(t("otgRolePort"), cur(r[4]));
  g += kv(t("otgRoleSw"), r[5] || "—");
  g += kv(t("otgNode"), r[6] || "—");
  g += kv(t("otgOnline"), r[7] === "1" ? t("yes") : t("no"));
  document.getElementById("otgRoles").innerHTML = g;

  const el = document.getElementById("otgDevices");
  if (!otgInfo.dev.length) { el.innerHTML = `<div class="sub">${t("otgNoDev")}</div>`; }
  else {
    const ICON = { mouse: "🖱️", keyboard: "⌨️", storage: "💾", phone: "📱", hub: "🔀", audio: "🎧", camera: "📷", bluetooth: "🔵", gamepad: "🎮", hid: "🕹️", printer: "🖨️", serial: "🔌", other: "🔌" };
    el.innerHTML = otgInfo.dev.map((p) => {
      const type = ICON[p[2]] ? p[2] : "other";
      const name = [p[4], p[5]].map((x) => (x || "").trim()).filter(Boolean).join(" ") || "—";
      return `<div class="dev-item"><div class="dev-ico">${ICON[type]}</div>
        <div class="dev-meta"><div class="label">${esc(t("dt_" + type))}</div>
        <div class="sub">${esc(name)}</div>
        <div class="sub mono">${esc(p[3] || "")} · ${esc(p[1] || "")}${p[6] ? " · " + esc(p[6]) + " Mb/s" : ""}</div></div></div>`;
    }).join("");
  }
  document.getElementById("otgLog").textContent = otgInfo.log.join("\n") || "—";
}

// ---------------- CPU cluster frequency ----------------
let freqData = [], freqLoaded = false;
async function loadFreq() {
  const r = await exec(`${GOV_CTL} fstatus`);
  freqData = [];
  parseLines(r.stdout).forEach((p) => {
    if (p[0] === "FREQ" && p.length >= 9) {
      const toN = (x) => (/^\d+$/.test(x) ? Number(x) : null);
      freqData.push({
        name: p[1], cpus: p[2], cur: toN(p[3]), smin: toN(p[4]), smax: toN(p[5]), hmin: toN(p[6]), hmax: toN(p[7]),
        avail: (p[8] || "").split(" ").filter((x) => /^\d+$/.test(x)).map(Number),
      });
    }
  });
  freqLoaded = true;
  renderFreq();
}
const mhz = (k) => (k === null ? "—" : Math.round(k / 1000) + " MHz");
function renderFreq() {
  const el = document.getElementById("freqList"); if (!el || !freqLoaded) return;
  if (!freqData.length) { el.innerHTML = `<div class="sub">${t("frNone")}</div>`; return; }
  el.innerHTML = freqData.map((c) => `
    <div class="perf-item freq-row">
      <div><div class="label">${t("govCluster")} ${esc(c.name.replace(/^policy/, ""))}</div>
        <div class="sub">cpu ${esc(c.cpus || "?")}</div>
        <div class="sub">${esc(mhz(c.smin) || "?")} - ${esc(mhz(c.smax) || "?")}${c.hmax !== null ? "  (hw " + esc(mhz(c.hmin)) + " - " + esc(mhz(c.hmax)) + ")" : ""}</div></div>
      <div class="freq-now"><b>${c.cur === null ? "-" : mhz(c.cur)}</b></div>
    </div>`).join("");
}
document.getElementById("frRefresh").addEventListener("click", loadFreq);

// ---------------- Terminal tab: Terminal | Logs switch ----------------
const TLOGS = [
  { id: "tools", key: "lg_tools", cmd: "tail -n 300 '/sdcard/MKVP LOGS/MKVP LOGS.log' 2>/dev/null" },
  { id: "otg",     key: "lg_otg",     cmd: "tail -n 300 /data/local/tmp/usb_otg_enable.log 2>/dev/null" },
  { id: "fod",     key: "lg_fod",     cmd: "tail -n 300 /data/local/tmp/spinel-fod.log 2>/dev/null" },
  { id: "bright",  key: "lg_bright",  cmd: `tail -n 300 ${MODDIR}/brightness/brightnessd.log 2>/dev/null` },
  { id: "dmesg",   key: "lg_dmesg",   cmd: "dmesg 2>/dev/null | tail -n 250" },
  { id: "logcat",  key: "lg_logcat",  cmd: "logcat -d -t 250 2>/dev/null" },
];
let tlogMode = false, tlogSel = "tools", tlogText = "", tlogBusy = false;
function renderTLogChips() {
  const el = document.getElementById("tlogChips"); if (!el) return;
  el.innerHTML = TLOGS.map((l) => `<button class="chip ${l.id === tlogSel ? "active" : ""}" data-lg="${l.id}">${esc(t(l.key))}</button>`).join("");
  el.querySelectorAll(".chip").forEach((c) => c.addEventListener("click", () => { tlogSel = c.dataset.lg; renderTLogChips(); loadTLog(); }));
}
async function loadTLog() {
  if (tlogBusy) return; tlogBusy = true;
  const l = TLOGS.find((x) => x.id === tlogSel) || TLOGS[0];
  const out = document.getElementById("tlogOut");
  out.textContent = t("loadingShort");
  const r = await exec(l.cmd);
  tlogBusy = false;
  tlogText = r.stdout.trim();
  out.textContent = tlogText || t("tlogEmpty");
  out.scrollTop = out.scrollHeight;
}
function setTermMode(logs) {
  tlogMode = logs;
  document.querySelectorAll("#termMode button").forEach((b) => b.classList.toggle("active", (b.dataset.val === "logs") === logs));
  document.getElementById("termPane").style.display = logs ? "none" : "";
  document.getElementById("tlogPane").style.display = logs ? "" : "none";
  if (logs) { renderTLogChips(); loadTLog(); }
}
document.querySelectorAll("#termMode button").forEach((b) => b.addEventListener("click", () => setTermMode(b.dataset.val === "logs")));
document.getElementById("tlogRefresh").addEventListener("click", loadTLog);
document.getElementById("tlogCopy").addEventListener("click", async () => {
  if (!tlogText) { await loadTLog(); }
  try {
    if (navigator.clipboard && navigator.clipboard.writeText) await navigator.clipboard.writeText(tlogText);
    else {
      const ta = document.createElement("textarea"); ta.value = tlogText; document.body.appendChild(ta); ta.select();
      const ok = document.execCommand("copy"); document.body.removeChild(ta); if (!ok) throw new Error("copy");
    }
    toast(t("copied"));
  } catch (e) { toast(t("copyFailed")); }
});

// ---------------- Sensors tab ----------------
const SENSOR_CORE = ["accelerometer", "gyroscope", "magnetic_field", "proximity", "light"];
let senData = null, senBusy = false;
async function loadSensors() {
  if (senBusy) return; senBusy = true;
  const r = await exec(`sh ${MODDIR}/scripts/sensors_info.sh`);
  senBusy = false;
  const d = { sensors: [], hal: "", fp: null, cam: null };
  parseLines(r.stdout).forEach((p) => {
    if (p[0] === "S") d.sensors.push({ name: p[1] || "", vendor: p[2] || "", type: (p[3] || "").replace(/^android\.sensor\./, "") });
    else if (p[0] === "HAL") d.hal = (p[1] || "").trim();
    else if (p[0] === "FP") d.fp = p[1] === "1";
    else if (p[0] === "CAM") d.cam = Number(p[1]);
  });
  senData = d;
  renderSensors();
}
function renderSensors() {
  if (!senData) return;
  const d = senData;
  const byType = {};
  d.sensors.forEach((s) => { (byType[s.type] = byType[s.type] || []).push(s); });
  const missing = SENSOR_CORE.filter((c) => !byType[c]);
  const sum = document.getElementById("senSummary");
  if (!d.sensors.length) { sum.textContent = t("senNone"); sum.className = "sen-summary bad"; }
  else if (!missing.length) { sum.textContent = t("senAllOk") + " (" + d.sensors.length + " " + t("senCount") + ")"; sum.className = "sen-summary ok"; }
  else { sum.textContent = "⚠️ " + t("senMissing") + " " + missing.map((m) => t("sn_" + m)).join(", "); sum.className = "sen-summary bad"; }

  document.getElementById("senCore").innerHTML = SENSOR_CORE.map((c) => {
    const got = byType[c];
    const names = got ? Array.from(new Set(got.map((x) => x.name))).join(", ") : "";
    return `<div class="sen-row"><span class="sen-ico ${got ? "ok" : "bad"}">${got ? "✓" : "✗"}</span>
      <div class="sen-meta"><div class="label">${esc(t("sn_" + c))}</div><div class="sub">${got ? esc(names) : esc(t("senMiss"))}</div></div></div>`;
  }).join("") + `<div class="sub">${t("senNote")}</div>`;

  const row = (ok, label, detail) => `<div class="sen-row"><span class="sen-ico ${ok ? "ok" : "bad"}">${ok ? "✓" : "✗"}</span>
    <div class="sen-meta"><div class="label">${esc(label)}</div><div class="sub">${esc(detail)}</div></div></div>`;
  document.getElementById("senHw").innerHTML =
    row(!!d.hal, t("senHal"), d.hal || t("senNotRunning")) +
    row(d.fp === true, t("senFp"), d.fp === true ? t("senRunning") : t("senNotRunning")) +
    row(d.cam > 0, t("senCam"), d.cam > 0 ? String(d.cam) : t("senNotRunning"));

  const others = Object.keys(byType).sort().map((k) =>
    `<div class="sen-other"><b>${esc(k)}</b> — ${esc(Array.from(new Set(byType[k].map((x) => x.name))).join(", "))}</div>`).join("");
  document.getElementById("senOther").innerHTML = others || "—";
}
document.getElementById("senRefresh").addEventListener("click", loadSensors);

// ---------------- Root terminal ----------------
const TERM_CHIPS = ["id", "getprop ro.product.device", "uname -a", "cat /proc/version", "ls /data/adb/modules", "df -h /data", "dmesg | tail -n 40", "logcat -d -t 40"];
let termCwd = "/data/local/tmp";
let termHist = [];
let termHistPos = 0;
let termBusy = false;
try { termHist = JSON.parse(localStorage.getItem("mkv_term_hist") || "[]").slice(-100); } catch (e) { termHist = []; }
termHistPos = termHist.length;

const shq = (s) => "'" + String(s).replace(/'/g, "'\\''") + "'";

function termPrint(text, cls) {
  const out = document.getElementById("termOut");
  const span = document.createElement("span");
  if (cls) span.className = cls;
  span.textContent = text;
  out.appendChild(span);
  // keep the DOM small
  while (out.childNodes.length > 400) out.removeChild(out.firstChild);
  out.scrollTop = out.scrollHeight;
}
function termSetPrompt() {
  document.getElementById("termPrompt").textContent = termCwd.length > 22 ? "…" + termCwd.slice(-21) + " #" : termCwd + " #";
}
function renderTermChips() {
  const el = document.getElementById("termChips");
  if (!el) return;
  el.innerHTML = "";
  TERM_CHIPS.forEach((c) => {
    const b = document.createElement("button");
    b.className = "chip"; b.textContent = c;
    b.addEventListener("click", () => { document.getElementById("termInput").value = c; document.getElementById("termInput").focus(); });
    el.appendChild(b);
  });
}

async function termRunLine() {
  if (termBusy) return;
  const inp = document.getElementById("termInput");
  const line = inp.value.trim();
  if (!line) return;
  inp.value = "";
  if (termHist[termHist.length - 1] !== line) termHist.push(line);
  termHist = termHist.slice(-100); termHistPos = termHist.length;
  try { localStorage.setItem("mkv_term_hist", JSON.stringify(termHist)); } catch (e) { /* optional */ }
  termPrint(`${termCwd} # ${line}\n`, "term-cmd");

  termBusy = true;
  document.getElementById("termRun").disabled = true;
  let cmd;
  const cdm = line.match(/^cd(?:\s+(.*))?$/);
  if (cdm) {
    // cd is handled here so the working directory survives between commands
    const target = (cdm[1] || "").trim() || "/data/local/tmp";
    cmd = `cd ${shq(termCwd)} 2>/dev/null; cd ${target} 2>&1 && echo "__CWD__$(pwd)"`;
  } else {
    cmd = `cd ${shq(termCwd)} 2>/dev/null; T=""; command -v timeout >/dev/null 2>&1 && T="timeout 60"; $T sh -c ${shq(line)} 2>&1`;
  }
  const r = await exec(cmd);
  let text = r.stdout;
  const m = text.match(/__CWD__(.*)\n?$/m);
  if (m) { termCwd = m[1].trim() || termCwd; text = text.replace(/__CWD__.*\n?/, ""); termSetPrompt(); }
  if (r.stderr && r.stderr !== "no-bridge") text += (text && !text.endsWith("\n") ? "\n" : "") + r.stderr;
  if (r.stderr === "no-bridge") text = "No root connection.\n";
  if (text.length > 60000) text = "… (output cut)\n" + text.slice(-60000);
  if (text) termPrint(text.endsWith("\n") ? text : text + "\n");
  if (r.errno !== 0 && r.errno !== -1) termPrint(`[exit ${r.errno}]\n`, "term-err");
  termBusy = false;
  document.getElementById("termRun").disabled = false;
  inp.focus();
}

document.getElementById("termRun").addEventListener("click", termRunLine);
document.getElementById("termInput").addEventListener("keydown", (e) => {
  if (e.key === "Enter") { e.preventDefault(); termRunLine(); }
  else if (e.key === "ArrowUp") { e.preventDefault(); document.getElementById("termHistUp").click(); }
  else if (e.key === "ArrowDown") { e.preventDefault(); document.getElementById("termHistDown").click(); }
});
document.getElementById("termHistUp").addEventListener("click", () => {
  if (!termHist.length) return;
  termHistPos = Math.max(0, termHistPos - 1);
  document.getElementById("termInput").value = termHist[termHistPos] || "";
});
document.getElementById("termHistDown").addEventListener("click", () => {
  termHistPos = Math.min(termHist.length, termHistPos + 1);
  document.getElementById("termInput").value = termHist[termHistPos] || "";
});
document.getElementById("termClear").addEventListener("click", () => { document.getElementById("termOut").textContent = ""; });
termSetPrompt();
renderTermChips();
termPrint("MKVENOM root terminal — type a command and press Enter.\n", "term-dim");

// ---------------- Logs tab ----------------
let lastLogText = "";
async function loadLog() {
  const el = document.getElementById("logView");
  el.textContent = t("loadingLog");
  const r = await exec("tail -n 300 '/sdcard/MKVP LOGS/MKVP LOGS.log' 2>/dev/null");
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

// ---------------- Flash tab: ADB + fastboot over OTG ----------------
const FL_CTL = `sh ${MODDIR}/scripts/flash_ctl.sh`;
Object.assign(I18N.en, {
  tabFlash: "Flash",
  flTitle: "ADB & Fastboot",
  flDesc: "Flash, sideload and manage ANOTHER Android device plugged into this phone's USB-C port over OTG. This never touches this phone.",
  flWarn: "Flashing the wrong image can brick the target device. Double-check the device, partition and file before you run anything.",
  flToolsTitle: "Tools", flImport: "Import tools from storage", flRemove: "Remove",
  flNotInstalled: "not installed", flBroken: "will not run",
  flToolsHelp: "adb / fastboot are not bundled. Easiest: install Termux, run its adb/fastboot installer (pkg platform-tools), then tap Refresh - they are used in place. Or import your own ARM64 Android builds: put both files in /sdcard/Download/spinel_tools/ and tap Import (desktop platform-tools will NOT run on a phone).",
  flImporting: "Importing…", flImportDone: "Import finished", flImportFail: "Import failed", flRemoved: "Tools removed",
  flDevTitle: "Connected device", flNoDev: "No device found. Plug the target in with an OTG cable, put it in fastboot / enable USB debugging, then Refresh.",
  flUsbSeen: "USB devices the kernel sees:", flUsbNone: "nothing on the USB port",
  flRoleWarn: "This phone is not in USB host mode. Turn the OTG fix ON in the OTG tab and plug the cable in with an OTG adapter.",
  flKill: "Restart adb server", flKilled: "adb server stopped",
  flFileTitle: "File", flFileDesc: "Pick an image / zip / apk from Download, or type a full path.", flFilesRefresh: "Rescan storage",
  flNoFiles: "No .img / .zip / .apk files found in Download.",
  flFbTitle: "Fastboot actions", flFbHint: "Target must be in bootloader / fastboot mode (Vol-Down + Power on most phones).",
  flVerity: "Disable verity + verification (vbmeta)",
  flFlash: "Flash file to partition", flBootOnce: "Boot image (no flash)", flErase: "Erase partition", flWipe: "Wipe data (-w)",
  flSlotA: "Active slot A", flSlotB: "Active slot B", flGetvar: "getvar all", flRebootSys: "Reboot",
  flUnlock: "Unlock bootloader", flLock: "Lock bootloader",
  flAdbTitle: "ADB actions", flAdbHint: "Target needs USB debugging ON and must accept this phone's RSA key the first time.",
  flSideload: "Sideload zip", flInstall: "Install apk", flModel: "Model", flFingerprint: "Build fingerprint",
  flRawTitle: "Custom command",
  flOutTitle: "Output", flStatus: "Status", flCancel: "Cancel",
  flRunning: "running…", flFinished: "finished ✓", flExit: (c) => `failed (exit ${c})`, flIdle: "idle",
  flTapAgain: "Tap again to confirm",
  flNeedPart: "Enter a valid partition name", flNeedFile: "Pick a file that exists", flNoTool: "Tool not installed — import it first",
  flStarted: "Started", flFailedStart: "Could not start",
  flCancelled: "Cancelled",
  flKindAdb: "ADB", flKindFb: "FASTBOOT"
});
Object.assign(I18N.ar, {
  tabFlash: "فلاش",
  flTitle: "ADB و Fastboot",
  flDesc: "فلاش وسايدلود وإدارة موبايل أندرويد تاني متوصل بمنفذ USB-C بتاع الموبايل ده عن طريق OTG. ومش بيلمس الموبايل ده خالص.",
  flWarn: "فلاش ملف غلط ممكن يبوّظ الجهاز التاني. راجع الجهاز والبارتيشن والملف كويس قبل أي أمر.",
  flToolsTitle: "الأدوات", flImport: "استيراد الأدوات من الذاكرة", flRemove: "حذف",
  flNotInstalled: "مش متسطب", flBroken: "مش بيشتغل",
  flToolsHelp: "adb / fastboot مش متضمنين. الأسهل: سطّب Termux وشغّل مثبّت adb/fastboot بتاعه (pkg platform-tools) وبعدين داس تحديث - بيتستخدموا مكانهم. أو استورد نسخ ARM64 أندرويد: حط الملفين في /sdcard/Download/spinel_tools/ وداس استيراد (نسخ الكمبيوتر مش هتشتغل على موبايل).",
  flImporting: "جاري الاستيراد…", flImportDone: "خلص الاستيراد", flImportFail: "فشل الاستيراد", flRemoved: "اتمسحت الأدوات",
  flDevTitle: "الجهاز المتوصل", flNoDev: "مفيش جهاز. وصّل الجهاز بكابل OTG، ودخله fastboot أو فعّل USB debugging، وبعدين داس تحديث.",
  flUsbSeen: "أجهزة USB اللي النواة شايفاها:", flUsbNone: "مفيش حاجة على منفذ USB",
  flRoleWarn: "الموبايل ده مش في وضع USB host. شغّل إصلاح OTG من تاب OTG ووصّل الكابل بمحول OTG.",
  flKill: "إعادة تشغيل adb server", flKilled: "اتقفل adb server",
  flFileTitle: "الملف", flFileDesc: "اختار صورة / zip / apk من Download أو اكتب المسار كامل.", flFilesRefresh: "إعادة فحص الذاكرة",
  flNoFiles: "مفيش ملفات .img / .zip / .apk في Download.",
  flFbTitle: "أوامر Fastboot", flFbHint: "لازم الجهاز يكون في وضع bootloader / fastboot (Vol-Down + Power في أغلب الموبايلات).",
  flVerity: "تعطيل verity + verification (vbmeta)",
  flFlash: "فلاش الملف على البارتيشن", flBootOnce: "بوت من الصورة (من غير فلاش)", flErase: "مسح بارتيشن", flWipe: "مسح الداتا (-w)",
  flSlotA: "تفعيل Slot A", flSlotB: "تفعيل Slot B", flGetvar: "getvar all", flRebootSys: "إعادة تشغيل",
  flUnlock: "فتح البوتلودر", flLock: "قفل البوتلودر",
  flAdbTitle: "أوامر ADB", flAdbHint: "الجهاز لازم USB debugging يكون شغال، ولازم يوافق على مفتاح RSA بتاع الموبايل ده أول مرة.",
  flSideload: "سايدلود zip", flInstall: "تسطيب apk", flModel: "الموديل", flFingerprint: "بصمة البيلد",
  flRawTitle: "أمر مخصص",
  flOutTitle: "المخرجات", flStatus: "الحالة", flCancel: "إلغاء",
  flRunning: "شغال…", flFinished: "خلص ✓", flExit: (c) => `فشل (exit ${c})`, flIdle: "فاضي",
  flTapAgain: "داس تاني للتأكيد",
  flNeedPart: "اكتب اسم بارتيشن صح", flNeedFile: "اختار ملف موجود", flNoTool: "الأداة مش متسطبة — استوردها الأول",
  flStarted: "بدأ", flFailedStart: "ماقدرش يبدأ",
  flCancelled: "اتلغى",
  flKindAdb: "ADB", flKindFb: "FASTBOOT"
});

const FL_PARTS = ["boot", "init_boot", "vendor_boot", "recovery", "dtbo", "vbmeta", "vbmeta_system", "super", "userdata", "metadata", "system", "vendor", "product", "cache"];
const FL_PART_RE = /^[A-Za-z0-9_.-]+$/;
let fl = { tools: {}, devices: [], usb: [], files: [], sel: "", mode: "fastboot", jobTimer: null, jobBusy: false, running: false, text: "" };

function flKv(out) {
  const o = {};
  out.split("\n").forEach((l) => { const i = l.indexOf("="); if (i > 0) o[l.slice(0, i)] = l.slice(i + 1).trim(); });
  return o;
}

function renderFlashTools() {
  const el = document.getElementById("flTools"); if (!el) return;
  const one = (name, path, ok, ver) => {
    let v;
    if (!path) v = t("flNotInstalled");
    else if (ok !== "1") v = t("flBroken");
    else v = (ver || "OK").replace(/\s+/g, " ").slice(0, 60);
    return kv(name, v);
  };
  el.innerHTML = one("adb", fl.tools.adb, fl.tools.adbok, fl.tools.adbver) + one("fastboot", fl.tools.fastboot, fl.tools.fbok, fl.tools.fbver);
  const missing = !fl.tools.adb || !fl.tools.fastboot || fl.tools.adbok === "0" || fl.tools.fbok === "0";
  const help = document.getElementById("flToolsHelp");
  help.style.display = missing ? "block" : "none";
  help.textContent = t("flToolsHelp");
  const warn = document.getElementById("flRoleWarn");
  warn.style.display = (fl.tools.datarole && !/\[host\]/.test(fl.tools.datarole)) ? "block" : "none";
}

function renderFlashDevices() {
  const el = document.getElementById("flDevices"); if (!el) return;
  if (!fl.devices.length) {
    el.innerHTML = `<div class="sub">${esc(t("flNoDev"))}</div>`;
  } else {
    el.innerHTML = fl.devices.map((d) => `
      <div class="fl-dev ${d.serial === fl.sel ? "sel" : ""}" data-ser="${esc(d.serial)}">
        <span class="dot"></span>
        <div class="meta"><b>${esc(d.serial)}</b><span>${esc(d.state)}${d.info ? " · " + esc(d.info) : ""}</span></div>
        <span class="kind">${esc(t(d.kind === "FB" ? "flKindFb" : "flKindAdb"))}</span>
      </div>`).join("");
    el.querySelectorAll(".fl-dev").forEach((row) => row.addEventListener("click", () => {
      fl.sel = fl.sel === row.dataset.ser ? "" : row.dataset.ser;
      renderFlashDevices();
    }));
  }
  const u = document.getElementById("flUsb");
  u.innerHTML = fl.usb.length
    ? fl.usb.map((p) => `<div style="direction:ltr;text-align:left;font-family:monospace;font-size:11px">${esc(p[3])} · ${esc(p[5] || p[4] || "USB")} · ${esc(p[2])}</div>`).join("")
    : esc(t("flUsbNone"));
}

function renderFlashFiles() {
  const el = document.getElementById("flFiles"); if (!el) return;
  if (!fl.files.length) { el.innerHTML = `<span class="sub">${esc(t("flNoFiles"))}</span>`; return; }
  el.innerHTML = fl.files.map((f) => {
    const name = f.path.split("/").pop();
    const mb = f.size ? (f.size / 1048576).toFixed(f.size > 10485760 ? 0 : 1) + "M" : "";
    return `<button class="chip ${f.path === document.getElementById("flFile").value ? "active" : ""}" data-p="${esc(f.path)}">${esc(name)} ${esc(mb)}</button>`;
  }).join("");
  el.querySelectorAll(".chip").forEach((c) => c.addEventListener("click", () => {
    document.getElementById("flFile").value = c.dataset.p;
    renderFlashFiles();
  }));
}

function renderFlashParts() {
  const el = document.getElementById("flPartChips"); if (!el) return;
  el.innerHTML = FL_PARTS.map((p) => `<button class="chip" data-p="${p}">${p}</button>`).join("");
  el.querySelectorAll(".chip").forEach((c) => c.addEventListener("click", () => { document.getElementById("flPart").value = c.dataset.p; }));
}

function renderFlash() {
  renderFlashTools(); renderFlashDevices(); renderFlashFiles(); renderFlashParts();
  flRenderJobState();
}

async function loadFlashStatus() {
  const r = await exec(`${FL_CTL} status`);
  fl.tools = flKv(r.stdout);
  renderFlashTools();
}
let flDevBusy = null;
function loadFlashDevices() {
  if (flDevBusy) return flDevBusy;          // never stack scans
  flDevBusy = (async () => {
    try {
      const [d, u] = await Promise.all([execT(`${FL_CTL} devices`, 25000), execT(`${FL_CTL} usb`, 8000)]);
      fl.devices = d.stdout.split("\n").map((l) => l.trim().split("|")).filter((p) => (p[0] === "ADB" || p[0] === "FB") && p[1])
        .map((p) => ({ kind: p[0], serial: p[1], state: p[2] || "", info: p[3] || "" }));
      fl.usb = u.stdout.split("\n").map((l) => l.trim().split("|")).filter((p) => p[0] === "DEV");
      if (fl.devices.length === 1) fl.sel = fl.devices[0].serial;
      else if (!fl.devices.some((x) => x.serial === fl.sel)) fl.sel = "";
      renderFlashDevices();
    } finally { flDevBusy = null; }
  })();
  return flDevBusy;
}
async function loadFlashFiles() {
  const r = await exec(`${FL_CTL} files`);
  fl.files = r.stdout.split("\n").map((l) => l.trim().split("|")).filter((p) => p[0] === "FILE" && p[2])
    .map((p) => ({ size: Number(p[1]) || 0, path: p.slice(2).join("|") }));
  renderFlashFiles();
}
async function loadFlash() {
  await loadFlashStatus();
  loadFlashFiles();
  await flPollJob(true);
  if (!fl.running) await loadFlashDevices();
}

// ----- job output (fastboot / adb run in the background so long flashes survive) -----
function flRenderJobState(rc) {
  const el = document.getElementById("flJobState"); if (!el) return;
  if (fl.running) el.textContent = t("flRunning");
  else if (rc === undefined || rc === "") el.textContent = fl.text ? t("flFinished") : t("flIdle");
  else el.textContent = rc === "0" ? t("flFinished") : t("flExit", rc);
  document.getElementById("flOut").classList.toggle("run", fl.running);
  document.getElementById("flCancel").disabled = !fl.running;
}
async function flPollJob(once) {
  if (fl.jobBusy) return; fl.jobBusy = true;
  const r = await exec(`${FL_CTL} job`);
  fl.jobBusy = false;
  const i = r.stdout.indexOf("\n---\n");
  const head = flKv(i >= 0 ? r.stdout.slice(0, i) : r.stdout);
  const log = i >= 0 ? r.stdout.slice(i + 5) : "";
  fl.running = head.running === "1";
  fl.text = log.trim();
  const out = document.getElementById("flOut");
  const stick = out.scrollTop + out.clientHeight >= out.scrollHeight - 30;
  out.textContent = fl.text;
  if (stick) out.scrollTop = out.scrollHeight;
  flRenderJobState(head.rc);
  if (fl.running && !fl.jobTimer) fl.jobTimer = setInterval(() => flPollJob(false), 1000);
  if (!fl.running && fl.jobTimer) { clearInterval(fl.jobTimer); fl.jobTimer = null; if (!once) loadFlashDevices(); }
}

async function flStart(cmdTail, toolKey) {
  const ok = toolKey === "adb" ? fl.tools.adbok === "1" : fl.tools.fbok === "1";
  if (!ok) { toast(t("flNoTool")); return; }
  if (fl.running) return;
  const out = document.getElementById("flOut");
  out.textContent = "…";
  const r = await exec(`${FL_CTL} ${cmdTail}`);
  if (!r.stdout.includes("OK")) { out.textContent = r.stdout.trim() || r.stderr.trim(); toast(t("flFailedStart")); return; }
  toast(t("flStarted"));
  fl.running = true; flRenderJobState();
  await new Promise((res) => setTimeout(res, 400));
  await flPollJob(false);
}
function flRun(tool, args) {
  return flStart(`run ${tool} ${shq(fl.sel || "-")} ${args.map(shq).join(" ")}`, tool);
}

async function flFile() {
  const p = document.getElementById("flFile").value.trim();
  if (!p) { toast(t("flNeedFile")); return null; }
  const r = await exec(`[ -f ${shq(p)} ] && echo y`);
  if (r.stdout.trim() !== "y") { toast(t("flNeedFile")); return null; }
  return p;
}
function flPart() {
  const p = document.getElementById("flPart").value.trim();
  if (!FL_PART_RE.test(p)) { toast(t("flNeedPart")); return null; }
  return p;
}

// two-tap confirm for anything destructive (window.confirm is not reliable in WebUI webviews)
function flArm(btn, fn) {
  btn.addEventListener("click", () => {
    if (btn._armed) { clearTimeout(btn._t); btn.textContent = btn._orig; btn._armed = false; fn(); return; }
    btn._armed = true; btn._orig = btn.textContent; btn.textContent = t("flTapAgain");
    btn._t = setTimeout(() => { btn.textContent = btn._orig; btn._armed = false; }, 4000);
  });
}

flArm(document.getElementById("flFbFlash"), async () => {
  const part = flPart(); if (!part) return;
  const file = await flFile(); if (!file) return;
  const pre = (document.getElementById("flVerity").checked && /^vbmeta/.test(part)) ? ["--disable-verity", "--disable-verification"] : [];
  flRun("fastboot", [...pre, "flash", part, file]);
});
document.getElementById("flFbBoot").addEventListener("click", async () => {
  const file = await flFile(); if (!file) return;
  flRun("fastboot", ["boot", file]);
});
flArm(document.getElementById("flFbErase"), () => { const part = flPart(); if (part) flRun("fastboot", ["erase", part]); });
flArm(document.getElementById("flFbWipe"), () => flRun("fastboot", ["-w"]));
flArm(document.getElementById("flUnlock"), () => flRun("fastboot", ["flashing", "unlock"]));
flArm(document.getElementById("flLock"), () => flRun("fastboot", ["flashing", "lock"]));
document.querySelectorAll("[data-fb]").forEach((b) => b.addEventListener("click", () => flRun("fastboot", b.dataset.fb.split(" "))));
document.querySelectorAll("[data-adb]").forEach((b) => b.addEventListener("click", () => flRun("adb", b.dataset.adb.split(" "))));
document.getElementById("flAdbSideload").addEventListener("click", async () => {
  const file = await flFile(); if (file) flRun("adb", ["sideload", file]);
});
document.getElementById("flAdbInstall").addEventListener("click", async () => {
  const file = await flFile(); if (file) flRun("adb", ["install", "-r", file]);
});

document.getElementById("flRawRun").addEventListener("click", () => {
  const line = document.getElementById("flRaw").value.trim();
  if (!line) return;
  flStart(`raw ${fl.mode} ${shq(fl.sel || "-")} ${shq(line)}`, fl.mode);
});
document.getElementById("flRaw").addEventListener("keydown", (e) => { if (e.key === "Enter") { e.preventDefault(); document.getElementById("flRawRun").click(); } });

document.querySelectorAll("#flMode button").forEach((b) => b.addEventListener("click", () => {
  fl.mode = b.dataset.val;
  document.querySelectorAll("#flMode button").forEach((x) => x.classList.toggle("active", x === b));
  document.getElementById("flPaneFb").style.display = fl.mode === "fastboot" ? "" : "none";
  document.getElementById("flPaneAdb").style.display = fl.mode === "adb" ? "" : "none";
  document.getElementById("flRawPrompt").textContent = fl.mode;
}));

document.getElementById("flRefresh").addEventListener("click", async () => { await loadFlashStatus(); await loadFlashDevices(); });
document.getElementById("flFilesRefresh").addEventListener("click", loadFlashFiles);
document.getElementById("flKill").addEventListener("click", async () => { await exec(`${FL_CTL} killserver`); toast(t("flKilled")); loadFlashDevices(); });
document.getElementById("flCancel").addEventListener("click", async () => { await exec(`${FL_CTL} cancel`); toast(t("flCancelled")); flPollJob(false); });
document.getElementById("flCopy").addEventListener("click", async () => {
  try {
    if (navigator.clipboard && navigator.clipboard.writeText) await navigator.clipboard.writeText(fl.text);
    else {
      const ta = document.createElement("textarea"); ta.value = fl.text; ta.style.position = "fixed"; ta.style.opacity = "0";
      document.body.appendChild(ta); ta.focus(); ta.select(); document.execCommand("copy"); document.body.removeChild(ta);
    }
    toast(t("copied"));
  } catch (e) { toast(t("copyFailed")); }
});

document.getElementById("flImport").addEventListener("click", async () => {
  const out = document.getElementById("flImportOut");
  const btn = document.getElementById("flImport");
  btn.disabled = true; out.textContent = t("flImporting");
  const r = await exec(`${FL_CTL} import`);
  out.textContent = r.stdout.trim() || r.stderr.trim();
  btn.disabled = false;
  toast(/^ERR/m.test(r.stdout) ? t("flImportFail") : t("flImportDone"));
  await loadFlashStatus();
  loadFlashDevices();
});
document.getElementById("flRemove").addEventListener("click", async () => {
  await exec(`${FL_CTL} remove`);
  document.getElementById("flImportOut").textContent = "";
  toast(t("flRemoved"));
  loadFlashStatus();
});
renderFlashParts();


// ======================= v1.1: Manage / States / Control / ROM / live flash state / MiTool =======================
const SC = (n) => `sh ${MODDIR}/scripts/${n}`;
// exec that can never wait forever: gives up after `ms` so the UI always comes back
function execT(cmd, ms) {
  return Promise.race([exec(cmd), new Promise((res) => setTimeout(() => res({ errno: -2, stdout: "", stderr: "timeout" }), ms || 20000))]);
}
Object.assign(I18N.en, {
  tabUsb: "USB",
  usbTitle: "USB management", usbDesc: "Read the files and the information of the phone plugged into this one over OTG (needs USB debugging ON there and this phone's key accepted).", usbInfoTitle: "Phone information", usbFilesTitle: "Files", mgPullHint: "Pulled files land in /sdcard/Download/OTG_Pulled.",
  flStateTitle: "Device state", flStateHint: "Live: updates every 3 s (device / unauthorized / recovery / sideload / fastboot / rebooting / disconnected).",
  st_disc: "Disconnected", st_reboot: "Rebooting…", st_android: "Android (booted)", st_unauth: "Unauthorized — accept the key on the other phone",
  st_offline: "Offline", st_recovery: "Recovery", st_sideload: "Sideload mode", st_fastboot: "Fastboot / bootloader", st_busy: "Busy — job running", st_nodev: "No device. Plug it in over OTG.",
  st_noadb: "adb/fastboot not installed", st_seen: "last seen",
  miDesc: "Installs MiForge MiTool through Termux (the same one-liner works inside Termux itself).", miInstall: "Install / update MiTool", miRun: "Run MiTool",
  miNoTermux: "Termux not found", miInstalled: "MiTool found", miMissing: "MiTool not found yet", miStarted: "Started — see the output below",
  
  mgOpen: "Open", mgUp: "⬆ Up", mgMkdir: "New folder", mgNone: "Connect a phone, then open a folder.", mgPushTitle: "Send a file to this folder", mgPush: "Push file",
  mgNoAdb: "No ADB device in 'device' state. Connect it, enable USB debugging and accept the key.", mgEmpty: "Empty folder (or no permission).", mgDev: "Device", mgPulling: "Pulling…", mgDone: "Done",
  stShot: "📸 Screenshot", stNone: "No device read yet.", stShotTitle: "Last screenshot", stReading: "Reading…", stShotOk: "Screenshot saved",
  rom: "ROM", romOf: "ROM of this phone"
});
Object.assign(I18N.ar, {
  tabUsb: "USB",
  usbTitle: "إدارة USB", usbDesc: "اقرأ ملفات ومعلومات الهاتف الموصول بهذا الهاتف عبر OTG (يلزم USB debugging وقبول المفتاح).", usbInfoTitle: "معلومات الهاتف", usbFilesTitle: "الملفات", mgPullHint: "الملفات المسحوبة في /sdcard/Download/OTG_Pulled.",
  flStateTitle: "حالة الجهاز", flStateHint: "مباشر: يتحدّث كل 3 ثواني.",
  st_disc: "غير متصل", st_reboot: "جاري إعادة التشغيل…", st_android: "أندرويد (شغّال)", st_unauth: "غير مصرّح — اقبل المفتاح على الهاتف الآخر",
  st_offline: "Offline", st_recovery: "ريكفري", st_sideload: "وضع Sideload", st_fastboot: "فاستبوت / بوتلودر", st_busy: "مشغول — مهمة شغّالة", st_nodev: "لا يوجد جهاز. وصّله عبر OTG.",
  st_noadb: "adb/fastboot غير مثبّتين", st_seen: "آخر ظهور",
  miDesc: "يثبّت MiTool من MiForge عبر Termux (نفس الأمر يشتغل داخل Termux).", miInstall: "تثبيت / تحديث MiTool", miRun: "تشغيل MiTool",
  miNoTermux: "Termux غير موجود", miInstalled: "MiTool موجود", miMissing: "MiTool غير موجود بعد", miStarted: "بدأ — شوف الناتج بالأسفل",
  
  mgOpen: "فتح", mgUp: "⬆ للأعلى", mgMkdir: "مجلد جديد", mgNone: "وصّل هاتفاً ثم افتح مجلداً", mgPushTitle: "ارسل ملفاً لهذا المجلد", mgPush: "رفع الملف",
  mgNoAdb: "لا يوجد جهاز ADB بحالة device. وصّله وفعّل USB debugging واقبل المفتاح.", mgEmpty: "مجلد فارغ (أو لا صلاحية).", mgDev: "الجهاز", mgPulling: "جاري السحب…", mgDone: "تم",
  stShot: "📸 لقطة شاشة", stNone: "لم تتم قراءة جهاز بعد.", stShotTitle: "آخر لقطة", stReading: "جاري القراءة…", stShotOk: "تم حفظ اللقطة",
  rom: "الروم", romOf: "روم هذا الهاتف"
});

const kvParse = (out) => { const o = {}; out.split("\n").forEach((l) => { const i = l.indexOf("="); if (i > 0) o[l.slice(0, i)] = l.slice(i + 1).trim(); }); return o; };
const tabIs = (n) => document.getElementById("tab-" + n).classList.contains("active");
function adbTarget() {   // the ADB device in "device" state that other tabs act on
  const ok = fl.devices.filter((d) => d.kind === "ADB" && d.state === "device");
  return ok.find((d) => d.serial === fl.sel) || ok[0] || null;
}

// ---- ROM of this phone (header badge) ----
(async function () {
  const r = await execT(SC("states_ctl.sh") + " local");
  const o = kvParse(r.stdout);
  if (o.ROM) { const b = document.getElementById("romBadge"); b.textContent = o.ROM + (o.ANDROID ? " · A" + o.ANDROID : ""); b.className = "badge ok"; b.title = o.ROMVER || ""; }
})();

// ---- Flash: live device state + reboot tracking ----
const flLive = { last: null, lastSeen: 0, reboot: 0, busy: false };
const _flStart = flStart;
flStart = async function (cmdTail, toolKey) {
  if (/\breboot\b/.test(cmdTail)) { flLive.reboot = Date.now(); }
  return _flStart(cmdTail, toolKey);
};
function flStateOf(d) {
  if (d.kind === "FB") return ["st_fastboot", "fastboot · " + d.serial];
  const m = { device: "st_android", unauthorized: "st_unauth", offline: "st_offline", recovery: "st_recovery", sideload: "st_sideload", rescue: "st_recovery", bootloader: "st_fastboot" };
  return [m[d.state] || "st_offline", d.serial + (d.info ? " · " + d.info : "")];
}
function renderLiveState() {
  const big = document.getElementById("flStateBig"), sub = document.getElementById("flStateSub");
  if (!big) return;
  let key, extra = "", cls = "";
  if (fl.running) { key = "st_busy"; }
  else if (fl.devices.length) {
    const d = fl.devices.find((x) => x.serial === fl.sel) || fl.devices[0];
    [key, extra] = flStateOf(d); flLive.lastSeen = Date.now(); flLive.last = d; flLive.reboot = 0;
  } else if (flLive.reboot && Date.now() - flLive.reboot < 180000) { key = "st_reboot"; extra = Math.round((Date.now() - flLive.reboot) / 1000) + " s"; }
  else if (flLive.last && Date.now() - flLive.lastSeen < 12000) { key = "st_reboot"; extra = t("st_seen") + ": " + flLive.last.serial; }
  else if (!fl.tools.adb && !fl.tools.fastboot) { key = "st_noadb"; }
  else { key = "st_disc"; extra = t("flUsbNone"); }
  big.textContent = t(key); sub.textContent = extra;
}
async function flLiveTick() {
  if (flLive.busy || !tabIs("flash")) return;
  flLive.busy = true;
  try { if (!fl.running) await loadFlashDevices(); } finally { flLive.busy = false; }
  renderLiveState();
}

// ---- USB tab: every adb action is a background job that we poll (the UI never waits on adb) ----
const UJ = (args) => `${SC("usb_ctl.sh")} ${args}`;
async function usbRun(script, args, maxMs) {
  const st = await execT(UJ(`start ${script} ${args}`), 8000);
  const m = /^OK (\d+)/m.exec(st.stdout);
  if (!m) return { ok: false, out: st.stdout.trim() || st.stderr || "could not start" };
  const t0 = Date.now();
  while (Date.now() - t0 < (maxMs || 40000)) {
    await new Promise((r) => setTimeout(r, 700));
    const p = await execT(UJ(`poll ${m[1]}`), 6000);
    if (/^state=done/m.test(p.stdout)) return { ok: true, out: p.stdout.slice(p.stdout.indexOf("---") + 4) };
  }
  return { ok: false, out: "timed out - the phone did not answer (unlock it / accept the USB debugging prompt)" };
}
let usbBusy = false, usbSer = "", usbToken = 0;
const mg = { path: "/sdcard", entries: [], shown: 0, sel: -1 };
const $ = (id) => document.getElementById(id);
const say = (id, txt) => { $(id).textContent = txt; };

async function usbScan() {
  const r = await usbRun("flash_ctl.sh", "devices", 30000);
  fl.devices = r.out.split("\n").map((l) => l.trim().split("|")).filter((p) => (p[0] === "ADB" || p[0] === "FB") && p[1])
    .map((p) => ({ kind: p[0], serial: p[1], state: p[2] || "", info: p[3] || "" }));
  const ok = fl.devices.filter((d) => d.kind === "ADB" && d.state === "device");
  const bad = fl.devices.find((d) => d.kind === "ADB" && d.state !== "device");
  usbSer = (ok.find((d) => d.serial === fl.sel) || ok[0] || {}).serial || "";
  if (usbSer) say("usbDev", t("mgDev") + ": " + usbSer);
  else say("usbDev", bad ? bad.serial + " - " + bad.state + " (" + t("st_unauth") + ")" : t("mgNoAdb"));
  return usbSer;
}

// ----- phone info: plain text lines -----
async function usbInfo() {
  say("stRom", t("stReading")); say("stInfo", "");
  const r = await usbRun("states_ctl.sh", `info ${shq(usbSer)}`, 40000);
  if (!r.ok || /^ERR/m.test(r.out)) { say("stRom", ""); say("stInfo", r.out.trim()); return; }
  const o = kvParse(r.out);
  say("stRom", (o.ROM || "?") + (o.ROMVER ? "  -  " + o.ROMVER : ""));
  const ram = (o.RAM || "").split(" "), df = (o.DF || "").split(" ");
  const gb = (kb) => (kb / 1048576).toFixed(1) + " GB";
  const rows = [["Model", [o.BRAND, o.MODEL].filter(Boolean).join(" ")], ["Device", o.DEVICE], ["Android", (o.ANDROID || "") + (o.SDK ? " (API " + o.SDK + ")" : "")],
    ["Patch", o.PATCH], ["Build", o.BUILD], ["SoC", (o.SOC || "").trim()], ["ABI", o.ABI], ["Screen", [o.SIZE, o.DENSITY && o.DENSITY + "dpi"].filter(Boolean).join(" ")],
    ["Battery", o.BAT ? o.BAT + "%" + (o.BATTEMP ? " " + (o.BATTEMP / 10).toFixed(1) + "C" : "") + (o.CHG === "yes" ? " charging" : "") : ""],
    ["RAM", ram[0] ? gb(+ram[0]) + " / free " + gb(+ram[1]) : ""], ["/data", df[0] ? gb(+df[0]) + " / free " + gb(+df[2]) : ""],
    ["Slot", o.SLOT], ["Verified boot", o.BOOTLOADER], ["Root", o.ROOT && o.ROOT.indexOf("uid=0") >= 0 ? "yes" : "no"], ["GSI", o.GSI], ["Uptime", o.UPTIME], ["Serial", o.SERIAL]];
  say("stInfo", rows.filter((x) => x[1]).map((x) => x[0].padEnd(13) + x[1]).join("\n"));
}

// ----- files: text rows built with the DOM, 150 at a time, tap a file to select it -----
const mgFull = (e) => (mg.path === "/" ? "" : mg.path) + "/" + e.name;
function mgLog(txt) { const o = $("mgOut"); o.style.display = "block"; o.textContent = txt; }
function mgRender() {
  const box = $("mgList"); box.textContent = "";
  if (!mg.entries.length) { const d = document.createElement("div"); d.className = "sub"; d.textContent = t("mgEmpty"); box.appendChild(d); return; }
  const frag = document.createDocumentFragment();
  mg.entries.slice(0, mg.shown).forEach((e, i) => {
    const row = document.createElement("div"); row.className = "mg-row" + (i === mg.sel ? " sel" : ""); row.dataset.i = i;
    row.textContent = (e.dir ? "[+] " : "    ") + e.name;
    frag.appendChild(row);
  });
  box.appendChild(frag);
  if (mg.entries.length > mg.shown) {
    const more = document.createElement("button"); more.className = "secondary-btn"; more.id = "mgMore";
    more.textContent = "+ " + (mg.entries.length - mg.shown); box.appendChild(more);
  }
  const bar = $("mgBar"); const e = mg.entries[mg.sel];
  bar.style.display = e && !e.dir ? "" : "none"; if (e) say("mgSelName", e.name);
}
async function mgOpen(p) {
  if (!usbSer) return;
  mg.path = (p || $("mgPath").value || "/sdcard").replace(/\/+$/, "") || "/";
  $("mgPath").value = mg.path; mg.sel = -1; say("mgList", t("loadingShort"));
  const r = await usbRun("manage_ctl.sh", `ls ${shq(usbSer)} ${shq(mg.path)}`, 30000);
  if (!r.ok || /^ERR/m.test(r.out)) { say("mgList", r.out.trim()); return; }
  mg.entries = r.out.split("\n").map((l) => l.split("|")).filter((q) => q[0] === "D" || q[0] === "F").map((q) => ({ dir: q[0] === "D", name: q.slice(1).join("|") }))
    .sort((a, b) => (b.dir - a.dir) || a.name.localeCompare(b.name));
  mg.shown = Math.min(150, mg.entries.length); mgRender();
}
$("mgList").addEventListener("click", (ev) => {
  if (ev.target.id === "mgMore") { mg.shown = Math.min(mg.entries.length, mg.shown + 150); mgRender(); return; }
  const row = ev.target.closest(".mg-row"); if (!row) return;
  const i = +row.dataset.i, e = mg.entries[i]; if (!e) return;
  if (e.dir) { mgOpen(mgFull(e)); return; }
  mg.sel = i; mgRender();
});
async function mgDo(kind, extra, label) {
  if (!usbSer || usbBusy) return; usbBusy = true; mgLog(label || t("mgPulling"));
  const r = await usbRun("manage_ctl.sh", `${kind} ${shq(usbSer)} ${extra}`, 650000);
  mgLog(r.out.trim()); usbBusy = false; return r;
}
$("mgPull").addEventListener("click", () => { const e = mg.entries[mg.sel]; if (e) mgDo("pull", shq(mgFull(e))); });
$("mgDel").addEventListener("click", async () => {
  const b = $("mgDel"), e = mg.entries[mg.sel]; if (!e) return;
  if (!b._armed) { b._armed = true; b.textContent = t("flTapAgain"); setTimeout(() => { b._armed = false; b.textContent = "Delete"; }, 3000); return; }
  b._armed = false; b.textContent = "Delete"; await mgDo("rm", shq(mgFull(e))); mgOpen(mg.path);
});
$("mgGo").addEventListener("click", () => mgOpen());
$("mgPath").addEventListener("keydown", (e) => { if (e.key === "Enter") mgOpen(); });
$("mgUp").addEventListener("click", () => mgOpen(mg.path.replace(/\/[^/]*$/, "") || "/"));
$("mgMk").addEventListener("click", async () => {
  const n = $("mgNew").value.trim(); if (!n || /[\/'"]/.test(n)) { toast("Type a folder name first"); return; }
  $("mgNew").value = ""; await mgDo("mkdir", shq(mgFull({ name: n })), "..."); mgOpen(mg.path);
});
$("mgPush").addEventListener("click", async () => {
  const f = $("mgLocal").value.trim(); if (!f) return;
  await mgDo("push", `${shq(f)} ${shq(mg.path)}`); mgOpen(mg.path);
});

$("usbShot").addEventListener("click", async () => {
  if (!usbSer || usbBusy) { toast(t("mgNoAdb")); return; }
  usbBusy = true; $("usbShot").disabled = true;
  const r = await usbRun("states_ctl.sh", `shot ${shq(usbSer)}`, 45000);
  usbBusy = false; $("usbShot").disabled = false;
  if (/^OK/m.test(r.out)) {
    $("stShotCard").style.display = ""; $("stImg").src = "dyn/shots/last.png?" + Date.now();
    say("stShotPath", r.out.trim().replace(/^OK /, "")); toast(t("stShotOk"));
  } else toast(r.out.trim() || "failed");
});

async function usbLoad() {
  if (usbBusy) return; usbBusy = true; const me = ++usbToken;
  try {
    say("usbDev", t("stReading"));
    const ser = await usbScan();
    if (me !== usbToken) return;
    if (!ser) { say("stRom", ""); say("stInfo", t("stNone")); say("mgList", t("mgNone")); return; }
    await usbInfo();
    await mgOpen();
  } finally { usbBusy = false; }
}
$("usbRefresh").addEventListener("click", usbLoad);

// ---- MiTool ----
let miTimer = null;
async function miStatus() {
  const o = kvParse((await execT(SC("mitool_ctl.sh") + " status")).stdout);
  document.getElementById("miStatus").textContent = o.termux !== "1" ? t("miNoTermux") : (o.bin ? t("miInstalled") + ": " + o.bin : t("miMissing"));
  return o;
}
async function miLog() {
  const r = await execT(SC("mitool_ctl.sh") + " log"); const o = document.getElementById("miOut");
  o.style.display = "block"; o.textContent = r.stdout; o.scrollTop = o.scrollHeight;
  const st = kvParse((await execT(SC("mitool_ctl.sh") + " status")).stdout);
  if (st.running !== "1") { clearInterval(miTimer); miTimer = null; miStatus(); }
}
async function miGo(cmd) {
  const r = await execT(cmd);
  if (/^ERR/m.test(r.stdout)) { const o = document.getElementById("miOut"); o.style.display = "block"; o.textContent = r.stdout; return; }
  toast(t("miStarted")); clearInterval(miTimer); miTimer = setInterval(miLog, 1500); miLog();
}
async function miSend() {
  const i = document.getElementById("miIn"); const v = i.value; i.value = "";
  const r = await execT(SC("mitool_ctl.sh") + " send " + shq(v));
  if (/^ERR/m.test(r.stdout)) { toast(r.stdout.trim()); return; }
  if (!miTimer) miTimer = setInterval(miLog, 1500);
  setTimeout(miLog, 400); i.focus();
}
document.getElementById("miSend").addEventListener("click", miSend);
document.getElementById("miIn").addEventListener("keydown", (e) => { if (e.key === "Enter") { e.preventDefault(); miSend(); } });
document.getElementById("miStop").addEventListener("click", async () => { await execT(SC("mitool_ctl.sh") + " stop"); setTimeout(miLog, 400); });
document.getElementById("miInstall").addEventListener("click", () => miGo(SC("mitool_ctl.sh") + " install"));
document.getElementById("miRun").addEventListener("click", () => {
  const a = document.getElementById("miArgs").value.replace(/[^A-Za-z0-9 ._=:\/@-]/g, "");
  miGo(SC("mitool_ctl.sh") + ' run "' + a + '"');
});

// ---- tab hooks (run after the original tab handler) ----
document.querySelectorAll(".tab-btn").forEach((btn) => btn.addEventListener("click", () => { try {
  const tb = btn.dataset.tab;
  if (tb === "flash") { miStatus(); startPoll(flLiveTick, 3000); renderLiveState(); }
  if (tb === "usb") usbLoad();
  if (tb === "mods") loadSpoof();
} catch (e) { toast("Error: " + (e && e.message)); } }));
window.addEventListener("error", (e) => { try { toast("Error: " + (e.message || e)); } catch (_) {} });
window.addEventListener("unhandledrejection", (e) => { try { toast("Error: " + ((e.reason && e.reason.message) || e.reason)); } catch (_) {} });

// ---------------- init ----------------
applyLang();
