package com.mkvenompro.optimizer

import android.os.Bundle
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.widget.ImageView
import androidx.compose.ui.viewinterop.AndroidView
import androidx.compose.ui.platform.LocalContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
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
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mkvenompro.optimizer.core.DeviceInspector
import com.mkvenompro.optimizer.core.DeviceSnapshot

private val Bg = Color(0xFF080D13)
private val Panel = Color(0xFF111B25)
private val Green = Color(0xFF9BEA35)
private val Cyan = Color(0xFF39D6D0)
private val Muted = Color(0xFF91A1B2)

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { OptimizerApp() }
    }
}

private data class Feature(val title: String, val subtitle: String, val icon: ImageVector, val group: String, val state: String = "Compatibility scan")

@Composable
private fun OptimizerApp() {
    var tab by remember { mutableStateOf(0) }
    var snapshot by remember { mutableStateOf<DeviceSnapshot?>(null) }
    LaunchedEffect(Unit) { snapshot = DeviceInspector.inspect() }
    val tabs = listOf("Home", "Performance", "Battery", "Debloat", "Device")
    Scaffold(containerColor = Bg, bottomBar = {
        NavigationBar(containerColor = Color(0xFF0D151E), contentColor = Green) {
            val icons = listOf(Icons.Default.Dashboard, Icons.Default.Speed, Icons.Default.BatteryChargingFull, Icons.Default.Apps, Icons.Default.Memory)
            tabs.forEachIndexed { i, label ->
                NavigationBarItem(selected = tab == i, onClick = { tab = i }, icon = { Icon(icons[i], null) }, label = { Text(label, fontSize = 10.sp) }, colors = NavigationBarItemDefaults.colors(selectedIconColor = Green, selectedTextColor = Green, indicatorColor = Color(0xFF263B2A), unselectedIconColor = Muted, unselectedTextColor = Muted))
            }
        }
    }) { padding ->
        Column(Modifier.fillMaxSize().background(Bg).padding(padding)) {
            Header()
            when (tab) {
                0 -> HomeScreen(snapshot, onRefresh = { snapshot = DeviceInspector.inspect() }, onNavigate = { tab = it })
                1 -> FeatureScreen("Performance", "CPU, GPU, scheduler and storage controls", performanceFeatures)
                2 -> FeatureScreen("Battery & Cooling", "Battery care and thermal-aware controls", batteryFeatures)
                3 -> DebloatScreen()
                else -> DeviceScreen(snapshot, onRefresh = { snapshot = DeviceInspector.inspect() })
            }
        }
    }
}

@Composable
private fun Header() {
    Row(Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 14.dp), verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.size(42.dp).background(Brush.linearGradient(listOf(Green, Cyan)), RoundedCornerShape(13.dp)), contentAlignment = Alignment.Center) {
            Icon(Icons.Default.Bolt, null, tint = Bg, modifier = Modifier.size(27.dp))
        }
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Text("MkVenomPro", color = Color.White, fontWeight = FontWeight.Black, fontSize = 19.sp)
            Text("ANDROID OPTIMIZER", color = Green, fontSize = 9.sp, letterSpacing = 2.sp, fontWeight = FontWeight.Bold)
        }
        Icon(Icons.Default.Settings, null, tint = Muted)
    }
}

@Composable
private fun HomeScreen(device: DeviceSnapshot?, onRefresh: () -> Unit, onNavigate: (Int) -> Unit) {
    LazyColumn(contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        item {
            Box(Modifier.fillMaxWidth().background(Brush.linearGradient(listOf(Color(0xFF1A3024), Color(0xFF10202A), Color(0xFF111B25))), RoundedCornerShape(22.dp)).padding(20.dp)) {
                Column {
                    Text("DEVICE OVERVIEW", color = Green, fontSize = 10.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.8.sp)
                    Spacer(Modifier.height(8.dp))
                    Text(device?.model ?: "Scanning device…", color = Color.White, fontSize = 24.sp, fontWeight = FontWeight.Bold)
                    Text(device?.let { "${it.manufacturer} • Android ${it.android}" } ?: "Reading hardware and kernel interfaces", color = Muted, fontSize = 12.sp)
                    Spacer(Modifier.height(18.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        StatusChip(if (device?.rootAvailable == true) "ROOT READY" else "ROOT NOT FOUND", device?.rootAvailable == true)
                        StatusChip("THERMAL SAFE", true)
                    }
                    Spacer(Modifier.height(15.dp))
                    OutlinedButton(onClick = onRefresh, colors = ButtonDefaults.outlinedButtonColors(contentColor = Green)) { Icon(Icons.Default.Refresh, null, modifier = Modifier.size(16.dp)); Spacer(Modifier.width(6.dp)); Text("Rescan device") }
                }
            }
        }
        item { Text("OPTIMIZATION CENTER", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 14.sp) }
        item {
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                QuickCard("Performance", "CPU • GPU • I/O", Icons.Default.Speed, Modifier.weight(1f)) { onNavigate(1) }
                QuickCard("Battery care", "Cooling • Doze", Icons.Default.BatteryChargingFull, Modifier.weight(1f)) { onNavigate(2) }
            }
        }
        item {
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                QuickCard("Debloater", "Review installed apps", Icons.Default.DeleteSweep, Modifier.weight(1f)) { onNavigate(3) }
                QuickCard("Device scan", "Kernel • capabilities", Icons.Default.Memory, Modifier.weight(1f)) { onNavigate(4) }
            }
        }
        item { Text("DESIGN PRINCIPLES", color = Green, fontWeight = FontWeight.Bold, fontSize = 11.sp, letterSpacing = 1.2.sp) }
        item { InfoRow(Icons.Default.Security, "Thermal protections stay enabled", "No feature will disable Android or kernel thermal safety.") }
        item { InfoRow(Icons.Default.Restore, "Backup before changing values", "Original values and restore points are part of the tuning engine design.") }
        item { InfoRow(Icons.Default.Tune, "Device-aware controls", "A feature appears as supported only when its required interface is detected.") }
    }
}

@Composable
private fun StatusChip(label: String, good: Boolean) {
    Surface(color = if (good) Color(0x3323C879) else Color(0x33DDA34D), shape = RoundedCornerShape(50)) {
        Text(label, Modifier.padding(horizontal = 10.dp, vertical = 6.dp), color = if (good) Green else Color(0xFFFFC36B), fontSize = 9.sp, fontWeight = FontWeight.Bold)
    }
}

@Composable
private fun QuickCard(title: String, sub: String, icon: ImageVector, modifier: Modifier, onClick: () -> Unit) {
    Card(onClick = onClick, modifier = modifier.height(112.dp), colors = CardDefaults.cardColors(containerColor = Panel), shape = RoundedCornerShape(18.dp)) {
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.SpaceBetween) {
            Icon(icon, null, tint = Green, modifier = Modifier.size(23.dp))
            Column { Text(title, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 13.sp); Text(sub, color = Muted, fontSize = 10.sp) }
        }
    }
}

@Composable
private fun InfoRow(icon: ImageVector, title: String, detail: String) {
    Row(Modifier.fillMaxWidth().background(Panel, RoundedCornerShape(15.dp)).padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
        Icon(icon, null, tint = Cyan, modifier = Modifier.size(23.dp)); Spacer(Modifier.width(12.dp))
        Column { Text(title, color = Color.White, fontWeight = FontWeight.SemiBold, fontSize = 12.sp); Text(detail, color = Muted, fontSize = 10.sp) }
    }
}

private val performanceFeatures = listOf(
    Feature("CPU frequency & governors", "Inspect policies, governors and available frequency ranges", Icons.Default.Memory, "CPU"),
    Feature("GPU performance", "Detect Adreno / Mali devfreq and power interfaces", Icons.Default.DeveloperBoard, "GPU"),
    Feature("WALT & scheduler", "Check scheduler and schedutil interfaces", Icons.Default.Timeline, "Scheduler"),
    Feature("I/O scheduler", "Inspect storage queue policies and supported schedulers", Icons.Default.Storage, "Storage"),
    Feature("RAM & background apps", "Review memory pressure and app standby controls", Icons.Default.Memory, "Memory"),
    Feature("Refresh rate", "Read supported display modes before offering a cap", Icons.Default.DisplaySettings, "Display")
)
private val batteryFeatures = listOf(
    Feature("Thermal monitor", "Read thermal zones and temperature sensors", Icons.Default.Thermostat, "Thermal"),
    Feature("CPU / GPU heat limits", "Conservative caps only; thermal throttling remains enabled", Icons.Default.DeviceThermostat, "Cooling"),
    Feature("Charging care", "Detect charge-control nodes and battery limits", Icons.Default.BatteryChargingFull, "Charging"),
    Feature("Doze & app standby", "Review supported Android idle and standby controls", Icons.Default.Bedtime, "Battery"),
    Feature("Cached app freezer", "Check whether the platform exposes cached-app freezing", Icons.Default.AcUnit, "Background"),
    Feature("Battery saver", "Inspect built-in battery saver settings", Icons.Default.BatterySaver, "Battery")
)

@Composable
private fun FeatureScreen(title: String, subtitle: String, features: List<Feature>) {
    LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        item { Text(title, color = Color.White, fontSize = 23.sp, fontWeight = FontWeight.Bold); Text(subtitle, color = Muted, fontSize = 12.sp) }
        items(features) { feature ->
            Row(Modifier.fillMaxWidth().background(Panel, RoundedCornerShape(16.dp)).padding(15.dp), verticalAlignment = Alignment.CenterVertically) {
                Icon(feature.icon, null, tint = Green, modifier = Modifier.size(25.dp)); Spacer(Modifier.width(13.dp))
                Column(Modifier.weight(1f)) { Text(feature.title, color = Color.White, fontWeight = FontWeight.SemiBold, fontSize = 13.sp); Text(feature.subtitle, color = Muted, fontSize = 10.sp); Spacer(Modifier.height(5.dp)); Text("PLANNED • DEVICE CHECK REQUIRED", color = Color(0xFFFFC36B), fontSize = 8.sp, fontWeight = FontWeight.Bold) }
                Icon(Icons.Default.ChevronRight, null, tint = Muted)
            }
        }
        item { Text("Controls are intentionally not writable in this foundation build. Each tuning action will be enabled only after its safety checks, backup and restore path are implemented.", color = Muted, fontSize = 11.sp) }
    }
}

private data class InstalledApp(
    val label: String,
    val packageName: String,
    val applicationInfo: ApplicationInfo,
    val isSystem: Boolean
)

@Composable
private fun DebloatScreen() {
    val context = LocalContext.current
    var apps by remember { mutableStateOf<List<InstalledApp>>(emptyList()) }
    var loading by remember { mutableStateOf(true) }
    var query by remember { mutableStateOf("") }
    var showSystem by remember { mutableStateOf(true) }
    var showUser by remember { mutableStateOf(true) }

    LaunchedEffect(Unit) {
        loading = true
        apps = withContext(Dispatchers.IO) {
            val pm = context.packageManager
            @Suppress("DEPRECATION")
            pm.getInstalledApplications(PackageManager.GET_META_DATA)
                .filter { it.packageName != context.packageName }
                .map { info ->
                    val label = runCatching { pm.getApplicationLabel(info).toString() }.getOrDefault(info.packageName)
                    val system = (info.flags and ApplicationInfo.FLAG_SYSTEM) != 0 ||
                        (info.flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) != 0
                    InstalledApp(label, info.packageName, info, system)
                }
                .sortedBy { it.label.lowercase() }
        }
        loading = false
    }

    val visibleApps = apps.filter { app ->
        (if (app.isSystem) showSystem else showUser) &&
            (app.label.contains(query, ignoreCase = true) || app.packageName.contains(query, ignoreCase = true))
    }

    Column(Modifier.fillMaxSize().padding(horizontal = 16.dp, vertical = 12.dp)) {
        Text("App Manager", color = Color.White, fontSize = 23.sp, fontWeight = FontWeight.Bold)
        Text("Real installed-app icons and package details. Read-only in this build.", color = Muted, fontSize = 12.sp)
        Spacer(Modifier.height(12.dp))
        OutlinedTextField(
            value = query, onValueChange = { query = it }, modifier = Modifier.fillMaxWidth(),
            singleLine = true, placeholder = { Text("Search app or package…") },
            leadingIcon = { Icon(Icons.Default.Search, null) },
            colors = OutlinedTextFieldDefaults.colors(
                focusedTextColor = Color.White, unfocusedTextColor = Color.White,
                focusedBorderColor = Green, unfocusedBorderColor = Muted, cursorColor = Green
            )
        )
        Spacer(Modifier.height(8.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            FilterChip(selected = showUser, onClick = { showUser = !showUser }, label = { Text("User apps") })
            FilterChip(selected = showSystem, onClick = { showSystem = !showSystem }, label = { Text("System apps") })
        }
        Spacer(Modifier.height(8.dp))
        Text(if (loading) "Scanning packages…" else "${visibleApps.size} apps shown • No changes applied", color = Green, fontSize = 11.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.height(8.dp))
        if (loading) {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator(color = Green) }
        } else if (visibleApps.isEmpty()) {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { Text("No matching apps", color = Muted) }
        } else {
            LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                items(visibleApps, key = { it.packageName }) { app ->
                    Row(
                        Modifier.fillMaxWidth().background(Panel, RoundedCornerShape(14.dp)).padding(12.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        AndroidView(
                            factory = { viewContext -> ImageView(viewContext).apply { scaleType = ImageView.ScaleType.FIT_CENTER } },
                            update = { imageView ->
                                imageView.setImageDrawable(runCatching { app.applicationInfo.loadIcon(context.packageManager) }.getOrNull())
                            },
                            modifier = Modifier.size(44.dp)
                        )
                        Spacer(Modifier.width(12.dp))
                        Column(Modifier.weight(1f)) {
                            Text(app.label, color = Color.White, fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
                            Text(app.packageName, color = Muted, fontSize = 10.sp)
                        }
                        Spacer(Modifier.width(8.dp))
                        StatusChip(if (app.isSystem) "SYSTEM" else "USER", app.isSystem)
                    }
                }
            }
        }
    }
}

@Composable
private fun DeviceScreen(device: DeviceSnapshot?, onRefresh: () -> Unit) {
    LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        item { Text("Device capabilities", color = Color.White, fontSize = 23.sp, fontWeight = FontWeight.Bold); Text("Read-only inspection", color = Muted, fontSize = 12.sp) }
        val rows = listOf(
            "Manufacturer / model" to (device?.let { "${it.manufacturer} ${it.model}" } ?: "Scanning"),
            "Android" to (device?.android ?: "—"), "SoC" to (device?.chipset ?: "—"),
            "Kernel" to (device?.kernel ?: "—"), "Root" to (if (device?.rootAvailable == true) "Available" else "Not detected"),
            "CPU policies" to (device?.cpuPolicies?.toString() ?: "—"), "GPU interface" to (if (device?.gpuInterface == true) "Detected" else "Not detected"),
            "Thermal zones" to (device?.thermalZones?.toString() ?: "—")
        )
        items(rows) { (label, value) -> Row(Modifier.fillMaxWidth().background(Panel, RoundedCornerShape(13.dp)).padding(14.dp), horizontalArrangement = Arrangement.SpaceBetween) { Text(label, color = Muted, fontSize = 12.sp); Text(value, color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.SemiBold) } }
        item { Button(onClick = onRefresh, colors = ButtonDefaults.buttonColors(containerColor = Green, contentColor = Bg)) { Icon(Icons.Default.Refresh, null); Spacer(Modifier.width(6.dp)); Text("Scan again") } }
        device?.notes?.forEach { note -> item { Text("• $note", color = Color(0xFFFFC36B), fontSize = 11.sp) } }
    }
}
