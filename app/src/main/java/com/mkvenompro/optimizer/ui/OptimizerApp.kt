package com.mkvenompro.optimizer.ui

import android.graphics.Bitmap
import android.graphics.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.mkvenompro.optimizer.core.*
import com.mkvenompro.optimizer.toolkit.*
import com.mkvenompro.optimizer.ui.theme.ThemeMode

private enum class Page(val label: String) { HOME("Home"), PERFORMANCE("Performance"), BATTERY("Battery"), APPS("Apps"), TOOLS("Tools"), DEVICE("Device") }

@Composable
fun OptimizerApp(themeMode: ThemeMode, onThemeModeChange: (ThemeMode) -> Unit) {
    var page by remember { mutableStateOf(Page.HOME) }
    var themeMenuExpanded by remember { mutableStateOf(false) }
    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        bottomBar = {
            // Floating capsule navigation: independent layout, no copied artwork/assets.
            Box(Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 10.dp), contentAlignment = Alignment.Center) {
                Surface(
                    shape = RoundedCornerShape(28.dp),
                    color = MaterialTheme.colorScheme.surface.copy(alpha = 0.97f),
                    tonalElevation = 8.dp,
                    shadowElevation = 10.dp,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Row(
                        Modifier.horizontalScroll(rememberScrollState()).padding(horizontal = 5.dp, vertical = 5.dp),
                        horizontalArrangement = Arrangement.spacedBy(3.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        listOf(Page.HOME, Page.PERFORMANCE, Page.BATTERY, Page.APPS, Page.TOOLS, Page.DEVICE).forEach { item ->
                            val selected = page == item
                            val icon = when(item) {
                                Page.HOME -> Icons.Default.Home
                                Page.PERFORMANCE -> Icons.Default.Speed
                                Page.BATTERY -> Icons.Default.BatteryFull
                                Page.APPS -> Icons.Default.Apps
                                Page.TOOLS -> Icons.Default.Build
                                Page.DEVICE -> Icons.Default.PhoneAndroid
                            }
                            Surface(
                                onClick = { page = item },
                                shape = RoundedCornerShape(22.dp),
                                color = if (selected) MaterialTheme.colorScheme.primaryContainer else Color.Transparent
                            ) {
                                Row(
                                    Modifier.padding(horizontal = if (selected) 13.dp else 12.dp, vertical = 10.dp),
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                                ) {
                                    Icon(icon, contentDescription = item.label, tint = if (selected) MaterialTheme.colorScheme.onPrimaryContainer else MaterialTheme.colorScheme.onSurfaceVariant)
                                    if (selected) Text(item.label, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onPrimaryContainer, fontWeight = FontWeight.Bold)
                                }
                            }
                        }
                    }
                }
            }
        }
    ) { padding ->
        Column(Modifier.fillMaxSize().padding(padding).padding(horizontal = 16.dp)) {
            Spacer(Modifier.height(10.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text("MKVENOMPRO  /  DEVICE LAB", color = MaterialTheme.colorScheme.primary, style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.Bold)
                    Text("Android Optimizer", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.ExtraBold)
                }
                Box {
                    IconButton(onClick = { themeMenuExpanded = true }) {
                        Icon(Icons.Default.Palette, contentDescription = "Appearance: ${themeMode.label}")
                    }
                    DropdownMenu(expanded = themeMenuExpanded, onDismissRequest = { themeMenuExpanded = false }) {
                        ThemeMode.values().forEach { mode ->
                            DropdownMenuItem(
                                text = { Text(if (themeMode == mode) "✓ ${mode.label}" else mode.label) },
                                onClick = { onThemeModeChange(mode); themeMenuExpanded = false },
                                leadingIcon = {
                                    Icon(when (mode) {
                                        ThemeMode.SYSTEM -> Icons.Default.SettingsSuggest
                                        ThemeMode.DARK -> Icons.Default.DarkMode
                                        ThemeMode.LIGHT -> Icons.Default.LightMode
                                    }, contentDescription = null)
                                }
                            )
                        }
                    }
                }
            }
            Spacer(Modifier.height(14.dp))
            when(page) {
                Page.HOME -> HomePage(onNavigate = { page = it })
                Page.PERFORMANCE -> PerformancePage()
                Page.BATTERY -> BatteryPage()
                Page.APPS -> AppsPage()
                Page.TOOLS -> ToolsPage()
                Page.DEVICE -> DevicePage()
            }
        }
    }
}

@Composable
private fun Panel(title: String, value: String, subtitle: String = "") {
    Card(Modifier.fillMaxWidth(), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), shape = RoundedCornerShape(18.dp)) {
        Column(Modifier.padding(16.dp)) {
            Text(title, color = MaterialTheme.colorScheme.primary, style = MaterialTheme.typography.labelLarge)
            Text(value, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
            if (subtitle.isNotBlank()) Text(subtitle, color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodySmall)
        }
    }
}

@Composable
private fun HomePage(onNavigate: (Page) -> Unit) {
    val context = LocalContext.current
    var device by remember { mutableStateOf<DeviceSnapshot?>(null) }
    var battery by remember { mutableStateOf<BatterySnapshot?>(null) }
    LaunchedEffect(Unit) {
        val result = withContext(Dispatchers.IO) { DeviceInspector.inspect() to BatteryInspector.read(context) }
        device = result.first
        battery = result.second
    }
    LazyColumn(verticalArrangement = Arrangement.spacedBy(12.dp), contentPadding = PaddingValues(bottom = 20.dp)) {
        item { Panel("DEVICE", device?.let { "${it.manufacturer} ${it.model}" } ?: "Reading device…", device?.let { "Android ${it.android} · ${it.chipset}" } ?: "Inspecting hardware interfaces off the UI thread") }
        item { Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Box(Modifier.weight(1f)) { Panel("BATTERY", battery?.let { "${it.percent}%" } ?: "—", battery?.let { if (it.charging) "Charging" else "Not charging" } ?: "Reading status") }
            Box(Modifier.weight(1f)) { Panel("ROOT", device?.let { if (it.rootAvailable) "Detected" else "Not detected" } ?: "Checking", "Detection only") }
        } }
        item { Panel("SYSTEM STATUS", device?.let { "${it.cpuPolicies} CPU policies" } ?: "Checking interfaces", device?.let { "${it.thermalZones} thermal zones · GPU ${if(it.gpuInterface) "available" else "not exposed"}" } ?: "Availability depends on the device") }
        item { Text("QUICK ACCESS", color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Bold) }
        items(listOf(Page.PERFORMANCE, Page.BATTERY, Page.APPS, Page.TOOLS, Page.DEVICE)) { target ->
            Card(Modifier.fillMaxWidth().clickable { onNavigate(target) }, colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text(target.label, Modifier.weight(1f), fontWeight = FontWeight.SemiBold)
                    Icon(Icons.Default.ChevronRight, contentDescription = null)
                }
            }
        }
    }
}

@Composable
private fun PerformancePage() {
    var d by remember { mutableStateOf<DeviceSnapshot?>(null) }
    LaunchedEffect(Unit) { d = withContext(Dispatchers.IO) { DeviceInspector.inspect() } }
    LazyColumn(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        item { Panel("CPU POLICIES", d?.cpuPolicies?.toString() ?: "Reading…", "Read-only discovery under cpufreq") }
        item { Panel("GPU INTERFACE", d?.let { if(it.gpuInterface) "Detected" else "Not exposed" } ?: "Checking…", "KGSL / devfreq visibility") }
        item { Panel("THERMAL ZONES", d?.thermalZones?.toString() ?: "Reading…", "Thermal protections are never modified") }
        item { Text("I/O SCHEDULERS", color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Bold) }
        if (d != null && d!!.ioSchedulers.isEmpty()) item { Text("No readable scheduler nodes were exposed.") }
        items(d?.ioSchedulers ?: emptyList()) { Text(it, Modifier.fillMaxWidth().background(MaterialTheme.colorScheme.surface, RoundedCornerShape(12.dp)).padding(14.dp)) }
    }
}

@Composable
private fun BatteryPage() {
    val context = LocalContext.current
    var b by remember { mutableStateOf<BatterySnapshot?>(null) }
    LaunchedEffect(Unit) { b = withContext(Dispatchers.IO) { BatteryInspector.read(context) } }
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Panel("BATTERY LEVEL", b?.let { "${it.percent}%" } ?: "Reading…", b?.let { if(it.charging) "Charging" else "Not charging" } ?: "Battery service snapshot")
        Panel("HEALTH", b?.health ?: "Checking…", "Reported by Android battery service")
        Panel("POWER", b?.let { if(it.plugged) "External power connected" else "On battery" } ?: "Checking…", "Status snapshot")
        Text("Battery health reporting differs by device manufacturer. This screen does not estimate battery capacity or promise cycle-life predictions.", color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
private fun AppsPage() {
    val context = LocalContext.current
    var query by remember { mutableStateOf("") }
    var apps by remember { mutableStateOf(emptyList<InstalledApp>()) }
    LaunchedEffect(Unit) { apps = loadInstalledApps(context) }
    Column {
        OutlinedTextField(query, { query = it }, Modifier.fillMaxWidth(), label = { Text("Search apps or package names") }, singleLine = true)
        Text("${apps.size} installed apps · inventory and launch", color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodySmall)
        LazyColumn(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            items(apps.filter { it.label.contains(query, true) || it.packageName.contains(query, true) }) { app ->
                Row(Modifier.fillMaxWidth().background(MaterialTheme.colorScheme.surface, RoundedCornerShape(12.dp)).clickable {
                    val launch = context.packageManager.getLaunchIntentForPackage(app.packageName)
                    if (launch != null) context.startActivity(launch)
                }.padding(10.dp), verticalAlignment = Alignment.CenterVertically) {
                    Image(bitmap = app.icon.toBitmap().asImageBitmap(), contentDescription = app.label, modifier = Modifier.size(42.dp))
                    Column(Modifier.weight(1f).padding(start = 10.dp)) {
                        Text(app.label, fontWeight = FontWeight.SemiBold)
                        Text(app.packageName, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    if(app.system) Text("SYSTEM", color = MaterialTheme.colorScheme.tertiary, style = MaterialTheme.typography.labelSmall)
                }
            }
        }
    }
}

@Composable
private fun ToolsPage() {
    var tab by remember { mutableIntStateOf(0) }
    Column {
        TabRow(selectedTabIndex = tab) {
            Tab(tab == 0, { tab = 0 }, text = { Text("ADB") })
            Tab(tab == 1, { tab = 1 }, text = { Text("Fastboot") })
            Tab(tab == 2, { tab = 2 }, text = { Text("Partitions") })
        }
        when(tab) {
            0 -> CommandList(ToolkitCatalog.adb)
            1 -> CommandList(ToolkitCatalog.fastboot)
            else -> PartitionNotes()
        }
    }
}

@Composable
private fun CommandList(commands: List<ReferenceCommand>) {
    LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp), contentPadding = PaddingValues(vertical = 12.dp)) {
        item { Text("Reference only — commands are not executed by this app.", color = MaterialTheme.colorScheme.tertiary) }
        items(commands) { cmd ->
            Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
                Column(Modifier.padding(12.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(cmd.title, Modifier.weight(1f), fontWeight = FontWeight.Bold)
                        Text(cmd.risk.name.replace('_', ' '), color = when(cmd.risk) {
                            Risk.READ_ONLY -> MaterialTheme.colorScheme.primary
                            Risk.STATE_CHANGE -> MaterialTheme.colorScheme.tertiary
                            Risk.DESTRUCTIVE -> MaterialTheme.colorScheme.error
                        }, style = MaterialTheme.typography.labelSmall)
                    }
                    Text(cmd.command, color = MaterialTheme.colorScheme.secondary, style = MaterialTheme.typography.bodyMedium)
                    Text(cmd.detail, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
    }
}

@Composable
private fun PartitionNotes() {
    val context = LocalContext.current
    val store = remember { CustomPartitionStore(context) }
    var name by remember { mutableStateOf("") }
    var entries by remember { mutableStateOf(store.all()) }
    Column {
        Text("Save partition-name notes locally. Names are not verified against a connected device.", color = MaterialTheme.colorScheme.onSurfaceVariant)
        Row(verticalAlignment = Alignment.CenterVertically) {
            OutlinedTextField(name, { name = it }, Modifier.weight(1f), label = { Text("Partition name") }, singleLine = true)
            IconButton(onClick = { if(store.add(name)) { entries = store.all(); name = "" } }) { Icon(Icons.Default.Add, "Add") }
        }
        entries.forEach { item ->
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Text(item, Modifier.weight(1f))
                IconButton(onClick = { store.remove(item); entries = store.all() }) { Icon(Icons.Default.Delete, "Remove") }
            }
        }
    }
}

@Composable
private fun DevicePage() {
    val context = LocalContext.current
    var d by remember { mutableStateOf<DeviceSnapshot?>(null) }
    var usb by remember { mutableStateOf<UsbHostStatus?>(null) }
    LaunchedEffect(Unit) {
        val result = withContext(Dispatchers.IO) { DeviceInspector.inspect() to readUsbHostStatus(context) }
        d = result.first
        usb = result.second
    }
    LazyColumn(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        item { Panel("MANUFACTURER / MODEL", d?.let { "${it.manufacturer} ${it.model}" } ?: "Reading…") }
        item { Panel("ANDROID", d?.android ?: "Reading…") }
        item { Panel("CHIPSET / PLATFORM", d?.chipset ?: "Reading…") }
        item { Panel("KERNEL", d?.kernel ?: "Reading…") }
        item { Panel("USB HOST", usb?.let { if(it.supported) "Supported" else "Not supported" } ?: "Checking…", usb?.let { "${it.connectedDevices} USB device(s) currently visible" } ?: "USB host capability only; no ADB transport") }
        item { Panel("ROOT", d?.let { if(it.rootAvailable) "su binary detected" else "Not detected" } ?: "Checking…", "No root commands are run") }
        item { Text("DIAGNOSTIC NOTES", color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Bold) }
        items(d?.notes ?: listOf("Collecting device diagnostics…")) { Text("• $it") }
    }
}


private fun android.graphics.drawable.Drawable.toBitmap(): Bitmap {
    val drawable = mutate()
    val width = intrinsicWidth.coerceAtLeast(1)
    val height = intrinsicHeight.coerceAtLeast(1)
    val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bitmap)
    drawable.setBounds(0, 0, width, height)
    drawable.draw(canvas)
    return bitmap
}
