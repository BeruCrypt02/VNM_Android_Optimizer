package com.mkvenompro.optimizer.core

import android.os.Build
import java.io.File

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
            if (file.canRead()) "${block.name}: ${runCatching { file.readText().trim() }.getOrNull()}" else null
        }.take(8)
        val socModel = if (Build.VERSION.SDK_INT >= 31) Build.SOC_MODEL else ""
        val soc = listOf(socModel, Build.HARDWARE, Build.BOARD)
            .firstOrNull { it.isNotBlank() } ?: "Not reported"
        val root = RootAccess.isAvailable()
        val notes = buildList {
            if (!root) add("Root not detected; privileged features are unavailable.")
            if (cpuPolicies == 0) add("CPU frequency policies are not exposed.")
            if (!gpu) add("GPU devfreq interface was not detected.")
            if (thermal == 0) add("Thermal zones are not exposed.")
        }
        return DeviceSnapshot(
            Build.MANUFACTURER, Build.MODEL,
            "${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})",
            soc, System.getProperty("os.version") ?: "Unknown",
            root, cpuPolicies, gpu, thermal, schedulers, notes
        )
    }
}

object RootAccess {
    fun isAvailable(): Boolean = runCatching {
        val process = Runtime.getRuntime().exec(arrayOf("/system/bin/which", "su"))
        process.inputStream.bufferedReader().use { it.readText() }.isNotBlank() &&
            process.waitFor() == 0
    }.getOrDefault(false)
}
