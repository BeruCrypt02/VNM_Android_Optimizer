package com.mkvenompro.optimizer.ui

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.mkvenompro.optimizer.core.*
import com.mkvenompro.optimizer.toolkit.*

private enum class Page(val label: String) { HOME("Home"), PERFORMANCE("Performance"), BATTERY("Battery"), APPS("Apps"), TOOLS("Tools"), DEVICE("Device") }

@Composable
fun OptimizerApp() {
    var page by remember { mutableStateOf(Page.HOME) }
    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        bottomBar = {
            NavigationBar(containerColor = Color(0xFF101923)) {
                listOf(Page.HOME, Page.PERFORMANCE, Page.BATTERY, Page.APPS, Page.TOOLS, Page.DEVICE).forEach { item ->
                    NavigationBarItem(
                        selected = page == item, onClick = { page = item },
                        icon = { Icon(when(item) {
                            Page.HOME -> Icons.Default.Home
                            Page.PERFORMANCE -> Icons.Default.Speed
                            Page.BATTERY -> Icons.Default.BatteryFull
                            Page.APPS -> Icons.Default.Apps
                            Page.TOOLS -> Icons.Default.Build
                            Page.DEVICE -> Icons.Default.PhoneAndroid
                        }, contentDescription = item.label) },
                        label = { Text(item.label) }
                    )
                }
            }
        }
    ) { padding ->
        Column(Modifier.fillMaxSize().padding(padding).padding(horizontal = 16.dp)) {
            Spacer(Modifier.height(14.dp))
            Text("MKVENOMPRO", color = MaterialTheme.colorScheme.primary, style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.Bold)
            Text("ANDROID OPTIMIZER", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.ExtraBold)
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
    val device = remember { DeviceInspector.inspect() }
    val battery = remember { BatteryInspector.read(context) }
    LazyColumn(verticalArrangement = Arrangement.spacedBy(12.dp), contentPadding = PaddingValues(bottom = 20.dp)) {
        item { Panel("DEVICE", "${device.manufacturer} ${device.model}", "Android ${device.android} · ${device.chipset}") }
        item { Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Box(Modifier.weight(1f)) { Panel("BATTERY", "${battery.percent}%", if (battery.charging) "Charging" else "Not charging") }
            Box(Modifier.weight(1f)) { Panel("ROOT", if (device.rootAvailable) "Detected" else "Not detected", "Detection only") }
        } }
        item { Panel("SYSTEM STATUS", "${device.cpuPolicies} CPU policies", "${device.thermalZones} thermal zones · GPU ${if(device.gpuInterface) "available" else "not exposed"}") }
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
    val d = remember { DeviceInspector.inspect() }
    LazyColumn(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        item { Panel("CPU POLICIES", d.cpuPolicies.toString(), "Read-only discovery under cpufreq") }
        item { Panel("GPU INTERFACE", if(d.gpuInterface) "Detected" else "Not exposed", "KGSL / devfreq visibility") }
        item { Panel("THERMAL ZONES", d.thermalZones.toString(), "Thermal protections are never modified") }
        item { Text("I/O SCHEDULERS", color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Bold) }
        if (d.ioSchedulers.isEmpty()) item { Text("No readable scheduler nodes were exposed.") }
        items(d.ioSchedulers) { Text(it, Modifier.fillMaxWidth().background(MaterialTheme.colorScheme.surface, RoundedCornerShape(12.dp)).padding(14.dp)) }
    }
}

@Composable
private fun BatteryPage() {
    val context = LocalContext.current
    val b = remember { BatteryInspector.read(context) }
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Panel("BATTERY LEVEL", "${b.percent}%", if(b.charging) "Charging" else "Not charging")
        Panel("HEALTH", b.health, "Reported by Android battery service")
        Panel("POWER", if(b.plugged) "External power connected" else "On battery", "Status snapshot")
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
        Text("${apps.size} installed apps · view and launch only", color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodySmall)
        LazyColumn(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            items(apps.filter { it.label.contains(query, true) || it.packageName.contains(query, true) }) { app ->
                Row(Modifier.fillMaxWidth().background(MaterialTheme.colorScheme.surface, RoundedCornerShape(12.dp)).clickable {
                    val launch = context.packageManager.getLaunchIntentForPackage(app.packageName)
                    if (launch != null) context.startActivity(launch)
                }.padding(10.dp), verticalAlignment = Alignment.CenterVertically) {
                    androidx.compose.foundation.Image(app.icon, null, Modifier.size(42.dp))
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
    val d = remember { DeviceInspector.inspect() }
    val usb = remember { readUsbHostStatus(context) }
    LazyColumn(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        item { Panel("MANUFACTURER / MODEL", "${d.manufacturer} ${d.model}") }
        item { Panel("ANDROID", d.android) }
        item { Panel("CHIPSET / PLATFORM", d.chipset) }
        item { Panel("KERNEL", d.kernel) }
        item { Panel("USB HOST", if(usb.supported) "Supported" else "Not supported", "${usb.connectedDevices} USB device(s) currently visible") }
        item { Panel("ROOT", if(d.rootAvailable) "su binary detected" else "Not detected", "No root commands are run") }
        item { Text("DIAGNOSTIC NOTES", color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Bold) }
        items(d.notes) { Text("• $it") }
    }
}
