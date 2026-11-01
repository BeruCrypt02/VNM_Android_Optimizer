package com.mkvenompro.optimizer

import android.content.Context
import android.content.res.AssetManager
import java.io.File

/**
 * The boot-time parts (kernel/sysfs tweaks, props, SELinux rules, FOD/brightness/OTG daemons, overlays)
 * cannot run from a normal app, so they ship inside the APK as two small modules that this class
 * copies to /data/adb/modules. The UI in the app drives them.
 */
object EngineInstaller {
    /** Bump when anything under assets/engine changes. */
    const val VERSION = 2
    private const val VERSION_FILE = "/data/adb/mkvp_engine_version"

    fun isCurrent(): Boolean {
        val r = Shell.run(
            "[ -f /data/adb/modules/mkvp_thermal/module.prop ] && [ -f /data/adb/modules/mkvp_tools/module.prop ] && cat $VERSION_FILE"
        )
        return r.code == 0 && r.out.trim() == VERSION.toString()
    }

    fun install(ctx: Context): ShellResult {
        val stage = File(ctx.cacheDir, "engine_stage")
        stage.deleteRecursively()
        stage.mkdirs()
        copyAssets(ctx.assets, "engine", File(stage, "engine"))
        copyAssets(ctx.assets, "installer", File(stage, "installer"))
        val r = Shell.run("sh '${stage.absolutePath}/installer/install_engine.sh' '${stage.absolutePath}/engine' $VERSION", 180)
        stage.deleteRecursively()
        return r
    }

    private fun copyAssets(am: AssetManager, path: String, dest: File) {
        val children = am.list(path) ?: emptyArray()
        if (children.isEmpty()) {
            dest.parentFile?.mkdirs()
            am.open(path).use { input -> dest.outputStream().use { input.copyTo(it) } }
        } else {
            dest.mkdirs()
            for (c in children) copyAssets(am, "$path/$c", File(dest, c))
        }
    }
}
