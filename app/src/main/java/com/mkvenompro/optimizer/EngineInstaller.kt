package com.mkvenompro.optimizer

import android.content.Context
import android.content.res.AssetManager
import java.io.File

/**
 * The boot-time parts (kernel/sysfs tweaks, props, SELinux rules, FOD/brightness/OTG daemons, overlays)
 * cannot run from a normal app process, so they ship inside the APK as an add-on of the app itself.
 * The app (which already has root) writes them to /data/adb/mkvp/engine; nothing is installed as a
 * Magisk / KernelSU / APatch module. boot.sh is started at boot by the standard post-fs-data.d /
 * service.d hooks and, as a fallback, by [BootReceiver].
 */
object EngineInstaller {
    /** Bump when anything under assets/engine changes. */
    const val VERSION = 4
    const val ENGINE_DIR = "/data/adb/mkvp/engine"
    private const val VERSION_FILE = "/data/adb/mkvp_engine_version"

    fun isCurrent(): Boolean {
        val r = Shell.run(
            "[ -f $ENGINE_DIR/thermal/module.prop ] && [ -f $ENGINE_DIR/tools/module.prop ] && " +
                "[ -f $ENGINE_DIR/boot.sh ] && [ -x /data/adb/service.d/mkvp_engine.sh ] && cat $VERSION_FILE"
        )
        return r.code == 0 && r.out.trim() == VERSION.toString()
    }

    fun isInstalled(): Boolean =
        Shell.run("[ -f $ENGINE_DIR/boot.sh ]").code == 0

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

    /** Gives every ROM change back and removes the engine, hooks and settings. */
    fun uninstall(): ShellResult = Shell.run("sh $ENGINE_DIR/engine_ctl.sh uninstall", 120)

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
