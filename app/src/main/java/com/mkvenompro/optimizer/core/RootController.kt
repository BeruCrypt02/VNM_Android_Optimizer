package com.mkvenompro.optimizer.core

import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.util.concurrent.TimeUnit
import java.io.File

/** Root-backed device operations. Every write is limited to known tuning/sysfs namespaces. */
data class ShellResult(val exitCode: Int, val stdout: String, val stderr: String) {
    val ok: Boolean get() = exitCode == 0
}

data class CpuPolicy(
    val name: String,
    val governor: String,
    val availableGovernors: List<String>,
    val minFrequency: String,
    val maxFrequency: String,
    val currentFrequency: String
)

object RootController {
    suspend fun run(command: String, root: Boolean = true, timeoutSeconds: Long = 20): ShellResult = withContext(Dispatchers.IO) {
        if (command.isBlank()) return@withContext ShellResult(2, "", "Command is empty")
        if (command.length > 8192 || command.contains('\u0000')) return@withContext ShellResult(2, "", "Command is too long or invalid")
        runCatching {
            val prefix = if (root) arrayOf("su", "-c", command) else arrayOf("sh", "-c", command)
            val process = ProcessBuilder(*prefix).redirectErrorStream(true).start()
            val outputFuture = java.util.concurrent.CompletableFuture.supplyAsync {
                process.inputStream.bufferedReader().use { reader ->
                    val kept = StringBuilder()
                    val buffer = CharArray(4096)
                    while (true) {
                        val count = reader.read(buffer)
                        if (count < 0) break
                        if (kept.length < 256 * 1024) {
                            val remaining = 256 * 1024 - kept.length
                            kept.append(buffer, 0, minOf(count, remaining))
                        }
                    }
                    kept.toString()
                }
            }
            if (!process.waitFor(timeoutSeconds.coerceIn(1, 60), TimeUnit.SECONDS)) {
                process.destroyForcibly()
                return@withContext ShellResult(124, outputFuture.getNow(""), "Command timed out after ${timeoutSeconds.coerceIn(1, 60)} seconds")
            }
            ShellResult(process.exitValue(), outputFuture.get(2, TimeUnit.SECONDS).trim(), "")
        }.getOrElse { ShellResult(-1, "", it.message ?: it.javaClass.simpleName) }
    }

    suspend fun rootAvailable(): Boolean = run("id", true).let { it.ok && it.stdout.contains("uid=0") }

    suspend fun read(path: String): String = withContext(Dispatchers.IO) {
        runCatching { File(path).takeIf { it.isFile && it.canRead() }?.readText()?.trim().orEmpty() }.getOrDefault("")
    }

    suspend fun cpuPolicies(): List<CpuPolicy> = withContext(Dispatchers.IO) {
        File("/sys/devices/system/cpu/cpufreq").listFiles().orEmpty()
            .filter { it.isDirectory && it.name.startsWith("policy") }
            .sortedBy { it.name }
            .map { dir ->
                fun value(name: String) = runCatching { File(dir, name).readText().trim() }.getOrDefault("")
                CpuPolicy(dir.name, value("scaling_governor"), value("scaling_available_governors").split(' ').filter(String::isNotBlank),
                    value("scaling_min_freq"), value("scaling_max_freq"), value("scaling_cur_freq"))
            }
    }

    private fun validTuningPath(path: String): Boolean {
        val normalized = path.removeSuffix("/")
        return normalized.startsWith("/sys/devices/system/cpu/cpufreq/policy") &&
            normalized.substringAfterLast('/').let { it in setOf("scaling_governor", "scaling_min_freq", "scaling_max_freq") } ||
            (normalized.startsWith("/sys/block/") && normalized.endsWith("/queue/scheduler")) ||
            (normalized.startsWith("/sys/class/devfreq/") && normalized.substringAfterLast('/').let { it in setOf("governor", "min_freq", "max_freq") })
    }

    suspend fun writeTuningValue(context: Context, path: String, value: String): ShellResult {
        if (!validTuningPath(path) || value.isBlank() || value.any { it == '\n' || it == '\r' || it == '\u0000' }) {
            return ShellResult(2, "", "Unsupported tuning path or value")
        }
        val old = read(path)
        if (old.isBlank()) return ShellResult(2, "", "Cannot read current value; refusing to change it")
        val prefs = context.getSharedPreferences("tuning_backups", Context.MODE_PRIVATE)
        if (!prefs.contains(path)) prefs.edit().putString(path, old).apply()
        val escaped = value.replace("'", "'\\''")
        return run("printf '%s' '$escaped' > '${path}' && cat '${path}'")
    }

    suspend fun restoreTuning(context: Context): List<Pair<String, ShellResult>> = withContext(Dispatchers.IO) {
        val prefs = context.getSharedPreferences("tuning_backups", Context.MODE_PRIVATE)
        prefs.all.mapNotNull { (path, raw) ->
            val value = raw as? String ?: return@mapNotNull null
            if (!validTuningPath(path)) return@mapNotNull null
            val escaped = value.replace("'", "'\\''")
            path to run("printf '%s' '$escaped' > '$path' && cat '$path'")
        }.also { if (it.all { pair -> pair.second.ok }) prefs.edit().clear().apply() }
    }

    suspend fun selinuxStatus(): String = run("getenforce", true).let { if (it.ok) it.stdout else "Unavailable: ${it.stderr}" }

    suspend fun packageAction(packageName: String, action: String): ShellResult {
        if (!packageName.matches(Regex("[A-Za-z0-9_]+(\\.[A-Za-z0-9_]+)+"))) return ShellResult(2, "", "Invalid package name")
        val cmd = when (action) {
            "disable" -> "pm disable-user --user 0 '$packageName'"
            "enable" -> "pm enable '$packageName'"
            "uninstall" -> "pm uninstall --user 0 '$packageName'"
            "restore" -> "cmd package install-existing --user 0 '$packageName'"
            else -> return ShellResult(2, "", "Unsupported package action")
        }
        return run(cmd)
    }
}
