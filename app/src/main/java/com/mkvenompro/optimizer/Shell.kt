package com.mkvenompro.optimizer

import android.content.pm.PackageManager
import rikka.shizuku.Shizuku
import java.io.ByteArrayOutputStream
import java.util.concurrent.TimeUnit

data class ShellResult(val code: Int, val out: String, val err: String)

/**
 * Command backend: root (su) when available, otherwise Shizuku (adb shell uid).
 * Root-only features (engine install, /data/adb files, sysfs writes) need ROOT.
 */
object Shell {
    enum class Backend { NONE, ROOT, SHIZUKU }

    @Volatile var backend: Backend = Backend.NONE

    private const val ENV =
        "export PATH=/system/bin:/system/xbin:/vendor/bin:/data/adb/ksu/bin:/data/adb/ap/bin:/data/adb/magisk:\$PATH; "

    private fun spawnSu(): Process = ProcessBuilder("su").start()

    private fun spawnShizuku(): Process {
        val m = Class.forName("rikka.shizuku.Shizuku").getDeclaredMethod(
            "newProcess", Array<String>::class.java, Array<String>::class.java, String::class.java
        )
        m.isAccessible = true
        return m.invoke(null, arrayOf("sh"), null, null) as Process
    }

    private fun spawn(): Process = when (backend) {
        Backend.ROOT -> spawnSu()
        Backend.SHIZUKU -> spawnShizuku()
        Backend.NONE -> throw IllegalStateException("no root / Shizuku")
    }

    fun shizukuBinderAlive(): Boolean = try { Shizuku.pingBinder() } catch (t: Throwable) { false }

    fun shizukuGranted(): Boolean = try {
        Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED
    } catch (t: Throwable) { false }

    /** Picks ROOT if su gives uid 0, else SHIZUKU if its permission is granted. */
    fun detect(): Backend {
        val su = try {
            backend = Backend.ROOT
            run("id", 20)
        } catch (t: Throwable) {
            ShellResult(-1, "", t.toString())
        }
        if (su.code == 0 && su.out.contains("uid=0")) { backend = Backend.ROOT; return backend }
        backend = if (shizukuBinderAlive() && shizukuGranted()) Backend.SHIZUKU else Backend.NONE
        return backend
    }

    /** Runs [cmd] in the active backend (script is fed through stdin so multi-line commands work). */
    fun run(cmd: String, timeoutSec: Long = 0): ShellResult {
        return try {
            val p = spawn()
            val outBuf = ByteArrayOutputStream()
            val errBuf = ByteArrayOutputStream()
            val t1 = Thread { runCatching { p.inputStream.copyTo(outBuf) } }
            val t2 = Thread { runCatching { p.errorStream.copyTo(errBuf) } }
            t1.start(); t2.start()
            p.outputStream.use { os ->
                os.write((ENV + cmd).toByteArray())
                os.write("\nexit \$?\n".toByteArray())
                os.flush()
            }
            val finished = if (timeoutSec > 0) p.waitFor(timeoutSec, TimeUnit.SECONDS) else { p.waitFor(); true }
            if (!finished) p.destroyForcibly()
            // a background child may keep the pipes open: never wait for them forever
            t1.join(2000); t2.join(2000)
            val code = if (finished) p.exitValue() else 124
            ShellResult(code, outBuf.toString("UTF-8"), errBuf.toString("UTF-8"))
        } catch (e: Throwable) {
            ShellResult(-1, "", e.toString())
        }
    }

    /** Reads a root-only file as bytes (null when missing or when not running as root). */
    fun readBytes(path: String): ByteArray? {
        if (backend != Backend.ROOT) return null
        return try {
            val p = spawnSu()
            val buf = ByteArrayOutputStream()
            val t = Thread { runCatching { p.inputStream.copyTo(buf) } }
            t.start()
            p.outputStream.use { os ->
                os.write("[ -f '$path' ] && cat '$path'\nexit \$?\n".toByteArray())
                os.flush()
            }
            val code = p.waitFor()
            t.join(2000)
            if (code == 0) buf.toByteArray() else null
        } catch (e: Throwable) {
            null
        }
    }
}
