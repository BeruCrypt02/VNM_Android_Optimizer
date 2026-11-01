package com.mkvenompro.optimizer.core

import android.os.Build
import java.io.File

/** Read-only hardware and kernel inspection. No sysfs nodes are modified here. */
data class DeviceSnapshot(
    val manufacturer: String,
    val model: String,
    val android: String,
    val chipset: String,
    val kernel: String,
    val rootAvailable: Boolean,
    val cpuPolicies: Int,
    val gpuInterface: Boolean,
    val thermalZones: Int,
    val ioSchedulers: List<String>,
    val notes: List<String>
)

object DeviceInspector {
    fun inspect(): DeviceSnapshot {
        val cpuPolicies = File("/sys/devices/system/cpu/cpufreq").listFiles()
            ?.count { it.name.startsWith("policy") } ?: 0
        val gpu = File("/sys/class/kgsl/kgsl-3d0").exists() ||
            File("/sys/class/devfreq").listFiles()?.any { it.name.contains("gpu", true) } == true
        val thermal = File("/sys/class/thermal").listFiles()
            ?.count { it.name.startsWith("thermal_zone") } ?: 0
        val schedulers = File("/sys/block").listFiles().orEmpty().mapNotNull { block ->
            val file = File(block, "queue/scheduler")
            if (file.canRead()) "${block.name}: ${file.readText().trim()}" else null
        }.take(6)
        val root = RootAccess.isAvailable()
        val soc = listOfNotNull(
            readProp("ro.soc.model"), readProp("ro.board.platform"),
            readProp("ro.hardware")
        ).firstOrNull { it.isNotBlank() } ?: "Not reported"
        val notes = buildList {
            if (!root) add("Root not detected — advanced tuning stays locked")
            if (cpuPolicies == 0) add("CPU frequency policies were not exposed")
            if (!gpu) add("GPU devfreq interface was not detected")
            if (thermal == 0) add("Thermal zones were not exposed")
        }
        return DeviceSnapshot(
            manufacturer = Build.MANUFACTURER,
            model = Build.MODEL,
            android = "${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})",
            chipset = soc,
            kernel = System.getProperty("os.version") ?: "Unknown",
            rootAvailable = root,
            cpuPolicies = cpuPolicies,
            gpuInterface = gpu,
            thermalZones = thermal,
            ioSchedulers = schedulers,
            notes = notes
        )
    }

    private fun readProp(key: String): String = try {
        val process = Runtime.getRuntime().exec(arrayOf("/system/bin/getprop", key))
        process.inputStream.bufferedReader().use { it.readText().trim() }
    } catch (_: Throwable) { "" }
}

object RootAccess {
    fun isAvailable(): Boolean = try {
        val process = Runtime.getRuntime().exec(arrayOf("su", "-c", "id"))
        val output = process.inputStream.bufferedReader().use { it.readText() }
        process.waitFor() == 0 && output.contains("uid=0")
    } catch (_: Throwable) { false }
}
