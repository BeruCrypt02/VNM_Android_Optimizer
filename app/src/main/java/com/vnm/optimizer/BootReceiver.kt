package com.vnm.optimizer

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Fallback boot starter. The normal path is /data/adb/post-fs-data.d + service.d (hooks written by the
 * installer); if the root manager does not run those folders, the app itself (it has root) starts the
 * engine as soon as the phone has booted. boot.sh runs every stage only once per boot, so both paths
 * can coexist without doing the work twice.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        val pending = goAsync()
        Thread {
            try {
                if (Shell.detect() == Shell.Backend.ROOT) {
                    Shell.run("[ -f ${EngineInstaller.ENGINE_DIR}/boot.sh ] && sh ${EngineInstaller.ENGINE_DIR}/boot.sh late", 60)
                }
            } catch (t: Throwable) {
                // best effort
            } finally {
                pending.finish()
            }
        }.start()
    }
}
