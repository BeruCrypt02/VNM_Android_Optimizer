package com.mkvenompro.optimizer.ui

import android.graphics.drawable.Drawable
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.mkvenompro.optimizer.core.*
import com.mkvenompro.optimizer.ui.theme.ThemeMode
import kotlinx.coroutines.launch

private enum class Page(val label: String) { HOME("Home"), PERFORMANCE("Performance"), BATTERY("Battery"), APPS("Apps"), TOOLS("Toolkit") }

@Composable
fun OptimizerApp(themeMode: ThemeMode, onThemeModeChange: (ThemeMode) -> Unit) {
    var page by remember { mutableStateOf(Page.HOME) }
    var themeMenu by remember { mutableStateOf(false) }
    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        bottomBar = {
            Surface(color = MaterialTheme.colorScheme.surface, tonalElevation = 8.dp, shape = RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp)) {
                NavigationBar(containerColor = Color.Transparent, tonalElevation = 0.dp) {
                    Page.values().forEach { p ->
                        NavigationBarItem(selected = page == p, onClick = { page = p },
                            icon = { Icon(when (p) { Page.HOME -> Icons.Default.Dashboard; Page.PERFORMANCE -> Icons.Default.Speed; Page.BATTERY -> Icons.Default.BatteryChargingFull; Page.APPS -> Icons.Default.Apps; Page.TOOLS -> Icons.Default.Terminal }, null) },
                            label = { Text(p.label) })
                    }
                }
            }
        }
    ) { inset ->
        Column(Modifier.fillMaxSize().padding(inset)) {
            Row(Modifier.fillMaxWidth().padding(start = 20.dp, end = 12.dp, top = 12.dp, bottom = 10.dp), verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text("MKVENOMPRO", color = MaterialTheme.colorScheme.primary, style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.ExtraBold)
                    Text("Optimizer", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Black)
                }
                Box {
                    IconButton(onClick = { themeMenu = true }) { Icon(Icons.Default.Palette, "Appearance") }
                    DropdownMenu(themeMenu, { themeMenu = false }) {
                        ThemeMode.values().forEach { mode -> DropdownMenuItem(text = { Text(mode.label) }, onClick = { onThemeModeChange(mode); themeMenu = false }) }
                    }
                }
            }
            when (page) {
                Page.HOME -> HomeScreen({ page = it })
                Page.PERFORMANCE -> PerformanceScreen()
                Page.BATTERY -> BatteryScreen()
                Page.APPS -> AppsScreen()
                Page.TOOLS -> ToolkitScreen()
            }
        }
    }
}

@Composable private fun Hero(title: String, subtitle: String, icon: androidx.compose.ui.graphics.vector.ImageVector = Icons.Default.Bolt) {
    Card(Modifier.fillMaxWidth(), shape = RoundedCornerShape(26.dp), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer)) {
        Row(Modifier.padding(20.dp), verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text(title, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Black, color = MaterialTheme.colorScheme.onPrimaryContainer)
                Spacer(Modifier.height(5.dp)); Text(subtitle, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onPrimaryContainer)
            }
            Icon(icon, null, Modifier.size(42.dp), tint = MaterialTheme.colorScheme.primary)
        }
    }
}

@Composable private fun Metric(title: String, value: String, detail: String, modifier: Modifier = Modifier, icon: androidx.compose.ui.graphics.vector.ImageVector = Icons.Default.Info) {
    Card(modifier, shape = RoundedCornerShape(20.dp), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
        Column(Modifier.padding(15.dp)) {
            Icon(icon, null, tint = MaterialTheme.colorScheme.primary)
            Spacer(Modifier.height(10.dp)); Text(value, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
            Text(title, style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
            if (detail.isNotBlank()) Text(detail, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable private fun HomeScreen(navigate: (Page) -> Unit) {
    val context = LocalContext.current
    var device by remember { mutableStateOf<DeviceSnapshot?>(null) }
    var battery by remember { mutableStateOf<BatterySnapshot?>(null) }
    var root by remember { mutableStateOf("Checking root access…") }
    LaunchedEffect(Unit) {
        kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) { device = DeviceInspector.inspect() }
        battery = BatteryInspector.read(context)
        root = if (RootController.rootAvailable()) "Root granted" else "Root unavailable"
    }
    LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(horizontal = 18.dp, vertical = 8.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        item { Hero("Device control center", "Live device status · root-aware tools · reversible tuning") }
        item { Text("AT A GLANCE", style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Bold) }
        item { Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Metric("Battery", battery?.let { "${it.percent}%" } ?: "—", battery?.health ?: "Reading…", Modifier.weight(1f), Icons.Default.BatteryFull)
            Metric("Privileges", if (root == "Root granted") "ROOT" else "—", root, Modifier.weight(1f), Icons.Default.Security)
        } }
        item { Metric("Device", device?.let { "${it.manufacturer} ${it.model}" } ?: "Loading…", device?.let { "Android ${it.android} · ${it.chipset}" } ?: "", Modifier.fillMaxWidth(), Icons.Default.PhoneAndroid) }
        item { Text("QUICK TOOLS", style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Bold) }
        items(listOf(Page.PERFORMANCE, Page.BATTERY, Page.APPS, Page.TOOLS)) { p ->
            Card(Modifier.fillMaxWidth().clickable { navigate(p) }, shape = RoundedCornerShape(18.dp)) {
                Row(Modifier.padding(17.dp), verticalAlignment = Alignment.CenterVertically) {
                    Icon(when(p) { Page.PERFORMANCE -> Icons.Default.Speed; Page.BATTERY -> Icons.Default.BatteryChargingFull; Page.APPS -> Icons.Default.Apps; else -> Icons.Default.Terminal }, null, tint = MaterialTheme.colorScheme.primary)
                    Text(p.label, Modifier.weight(1f).padding(start = 14.dp), fontWeight = FontWeight.SemiBold)
                    Icon(Icons.Default.ChevronRight, null)
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable private fun PerformanceScreen() {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var policies by remember { mutableStateOf(emptyList<CpuPolicy>()) }
    var status by remember { mutableStateOf("Reading CPU policy nodes…") }
    var root by remember { mutableStateOf(false) }
    var selinux by remember { mutableStateOf("Checking…") }
    var result by remember { mutableStateOf("") }
    fun refresh() { scope.launch { root = RootController.rootAvailable(); policies = RootController.cpuPolicies(); selinux = RootController.selinuxStatus(); status = if (policies.isEmpty()) "No exposed CPU cpufreq policies" else "${policies.size} CPU policies detected" } }
    LaunchedEffect(Unit) { refresh() }
    LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(horizontal = 18.dp, vertical = 8.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item { Hero("Performance lab", "Inspect CPU policies and apply reversible settings", Icons.Default.Tune) }
        item { Row(verticalAlignment = Alignment.CenterVertically) { Text(if (root) "Root access available" else "Root access required", Modifier.weight(1f), color = if(root) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.error); TextButton(onClick = { refresh() }) { Text("Refresh") } } }
        item { Metric("SELinux", selinux, "Current enforcement state · read-only", Modifier.fillMaxWidth(), Icons.Default.Security) }
        item { Text(status, color = MaterialTheme.colorScheme.onSurfaceVariant) }
        items(policies) { policy ->
            var selected by remember(policy.name, policy.governor) { mutableStateOf(policy.governor) }
            Card(shape = RoundedCornerShape(20.dp)) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(policy.name.uppercase(), fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary)
                    Text("Current ${policy.currentFrequency} · min ${policy.minFrequency} · max ${policy.maxFrequency}", style = MaterialTheme.typography.bodySmall)
                    if (policy.availableGovernors.isNotEmpty()) {
                        var expanded by remember { mutableStateOf(false) }
                        ExposedDropdownMenuBox(expanded, { expanded = it }) {
                            OutlinedTextField(selected, {}, Modifier.menuAnchor().fillMaxWidth(), readOnly = true, label = { Text("Governor") }, trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded) })
                            ExposedDropdownMenu(expanded, { expanded = false }) { policy.availableGovernors.forEach { g -> DropdownMenuItem(text = { Text(g) }, onClick = { selected = g; expanded = false }) } }
                        }
                        Button(onClick = { scope.launch { val r = RootController.writeTuningValue(context, "/sys/devices/system/cpu/cpufreq/${policy.name}/scaling_governor", selected); result = if(r.ok) "${policy.name}: applied ${r.stdout}" else "Failed: ${r.stderr}"; refresh() } }, enabled = root && selected != policy.governor, modifier = Modifier.fillMaxWidth()) { Text("Apply governor · backup original") }
                    } else Text("Governor controls are not exposed by this kernel.")
                }
            }
        }
        item { OutlinedButton(onClick = { scope.launch { val outcomes = RootController.restoreTuning(context); result = if (outcomes.isEmpty()) "No saved tuning values" else "Restored ${outcomes.count { it.second.ok }} / ${outcomes.size} values"; refresh() } }, enabled = root, modifier = Modifier.fillMaxWidth()) { Icon(Icons.Default.Restore, null); Spacer(Modifier.width(8.dp)); Text("Restore saved tuning values") } }
        if (result.isNotBlank()) item { Text(result, color = MaterialTheme.colorScheme.secondary) }
        item { Text("Only discovered CPU governor nodes are writable here. Frequency limits and other kernel controls remain untouched unless explicitly implemented and verified for the device.", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant) }
    }
}

@Composable private fun BatteryScreen() {
    val context = LocalContext.current
    var b by remember { mutableStateOf<BatterySnapshot?>(null) }
    LaunchedEffect(Unit) { b = BatteryInspector.read(context) }
    LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item { Hero("Battery monitor", "Android-reported battery and charging status", Icons.Default.BatteryChargingFull) }
        item { Metric("Charge level", b?.let { "${it.percent}%" } ?: "—", if (b?.charging == true) "Charging" else "Not charging", Modifier.fillMaxWidth(), Icons.Default.BatteryFull) }
        item { Metric("Battery health", b?.health ?: "Reading…", "Reported by Android BatteryManager", Modifier.fillMaxWidth(), Icons.Default.HealthAndSafety) }
        item { Metric("Power source", if (b?.plugged == true) "External power" else "Battery", "Connection status", Modifier.fillMaxWidth(), Icons.Default.Power) }
        item { Text("Charge current/voltage and temperature depend on manufacturer-exposed battery nodes. Fast-charge controls are device-specific and will only be enabled after a supported node and safe range are detected.", color = MaterialTheme.colorScheme.onSurfaceVariant) }
    }
}

@Composable private fun AppsScreen() {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var query by remember { mutableStateOf("") }
    var apps by remember { mutableStateOf(emptyList<InstalledApp>()) }
    var selected by remember { mutableStateOf<InstalledApp?>(null) }
    var feedback by remember { mutableStateOf("") }
    LaunchedEffect(Unit) { apps = kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) { loadInstalledApps(context) } }
    Column(Modifier.fillMaxSize().padding(horizontal = 18.dp)) {
        Hero("App manager", "Search, launch, disable, enable or uninstall for current user", Icons.Default.Apps)
        Spacer(Modifier.height(10.dp))
        OutlinedTextField(query, { query = it }, Modifier.fillMaxWidth(), singleLine = true, label = { Text("Search app or package") }, leadingIcon = { Icon(Icons.Default.Search, null) })
        Text("${apps.size} packages visible · root needed for disable/uninstall", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        if (feedback.isNotBlank()) Text(feedback, color = MaterialTheme.colorScheme.secondary)
        LazyColumn(verticalArrangement = Arrangement.spacedBy(7.dp), contentPadding = PaddingValues(vertical = 8.dp)) {
            items(apps.filter { it.label.contains(query, true) || it.packageName.contains(query, true) }) { app ->
                Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(15.dp)).background(MaterialTheme.colorScheme.surface).clickable { selected = app }.padding(11.dp), verticalAlignment = Alignment.CenterVertically) {
                    Image(app.icon.toBitmap().asImageBitmap(), null, Modifier.size(40.dp))
                    Column(Modifier.weight(1f).padding(start = 10.dp)) { Text(app.label, fontWeight = FontWeight.SemiBold); Text(app.packageName, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant) }
                    if (app.system) Text("SYSTEM", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.tertiary)
                }
            }
        }
    }
    selected?.let { app ->
        AlertDialog(onDismissRequest = { selected = null }, title = { Text(app.label) }, text = { Text("${app.packageName}\n\nSystem app: ${app.system}. Disable/uninstall actions affect the current Android user and require root permission.") },
            confirmButton = { TextButton(onClick = { context.packageManager.getLaunchIntentForPackage(app.packageName)?.let { intent -> context.startActivity(intent) }; selected = null }) { Text("Launch") } },
            dismissButton = { Row { TextButton(onClick = { scope.launch { val r = RootController.packageAction(app.packageName, "disable"); feedback = if(r.ok) "Disabled ${app.packageName}" else "Disable failed: ${r.stderr}"; selected = null } }) { Text("Disable") }; TextButton(onClick = { scope.launch { val r = RootController.packageAction(app.packageName, "enable"); feedback = if(r.ok) "Enabled ${app.packageName}" else "Enable failed: ${r.stderr}"; selected = null } }) { Text("Enable") }; TextButton(onClick = { scope.launch { val r = RootController.packageAction(app.packageName, "uninstall"); feedback = if(r.ok) "Uninstalled for user: ${app.packageName}" else "Uninstall failed: ${r.stderr}"; selected = null } }) { Text("Uninstall") } } })
    }
}

@Composable private fun ToolkitScreen() {
    val scope = rememberCoroutineScope()
    var command by remember { mutableStateOf("") }
    var output by remember { mutableStateOf("Root shell is idle. Commands execute only after you press Run.") }
    var root by remember { mutableStateOf("Checking…") }
    var tab by remember { mutableIntStateOf(0) }
    LaunchedEffect(Unit) { root = if (RootController.rootAvailable()) "Root granted" else "Root unavailable" }
    LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(horizontal = 18.dp, vertical = 8.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item { Hero("System toolkit", "Root console · diagnostics · recovery", Icons.Default.Terminal) }
        item { Metric("Privilege state", root, "su permission is requested by Android when needed", Modifier.fillMaxWidth(), Icons.Default.Security) }
        item { TabRow(tab) { Tab(tab == 0, { tab = 0 }, text = { Text("Console") }); Tab(tab == 1, { tab = 1 }, text = { Text("Feature map") }) } }
        if (tab == 0) {
            item { OutlinedTextField(command, { command = it }, Modifier.fillMaxWidth(), label = { Text("Root shell command") }, minLines = 2) }
            item { Button(onClick = { scope.launch { output = RootController.run(command).let { "exit=${it.exitCode}\n${it.stdout}\n${it.stderr}" }; } }, enabled = command.isNotBlank() && root == "Root granted", modifier = Modifier.fillMaxWidth()) { Icon(Icons.Default.PlayArrow, null); Spacer(Modifier.width(8.dp)); Text("Run command") } }
            item { Card(Modifier.fillMaxWidth()) { Text(output, Modifier.padding(14.dp), style = MaterialTheme.typography.bodySmall) } }
            item { Text("Root commands can alter system software or make the device unstable. Review each command before running it. No command runs automatically.", color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall) }
        } else {
            item { FeatureGroup("Performance & thermal", "CPU/GPU governors and limits · I/O schedulers · memory profiles · thermal state · reversible profiles") }
            item { FeatureGroup("Battery & charging", "Charge current/voltage telemetry · fast-charge controls where supported · battery temperature and health") }
            item { FeatureGroup("Package management", "Curated debloat lists · package backup/restore · labels · per-user disable/enable/uninstall") }
            item { FeatureGroup("System tools", "SELinux state/control · ROM spoof profiles · ReZygisk integration status · MiTool compatibility · FOD diagnostics") }
            item { FeatureGroup("Diagnostics", "Sensors · fingerprint/camera availability · ROM/kernel/device information · logcat and process diagnostics") }
            item { FeatureGroup("ADB host", "USB ADB host transport and Wireless Debugging pairing/connect are separate transports and are not yet implemented in this build.") }
            item { Text("Feature map is a scope inventory, not a claim that every listed integration is active. Unsupported hardware must remain unavailable rather than showing fake controls.", color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodySmall) }
        }
    }
}

@Composable private fun FeatureGroup(title: String, description: String) {
    Card(shape = RoundedCornerShape(18.dp)) { Column(Modifier.padding(15.dp)) { Text(title, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary); Spacer(Modifier.height(4.dp)); Text(description, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant) } }
}

private fun Drawable.toBitmap(): android.graphics.Bitmap {
    val width = intrinsicWidth.coerceAtLeast(1); val height = intrinsicHeight.coerceAtLeast(1)
    return android.graphics.Bitmap.createBitmap(width, height, android.graphics.Bitmap.Config.ARGB_8888).also { bitmap ->
        val canvas = android.graphics.Canvas(bitmap); setBounds(0, 0, canvas.width, canvas.height); draw(canvas)
    }
}
