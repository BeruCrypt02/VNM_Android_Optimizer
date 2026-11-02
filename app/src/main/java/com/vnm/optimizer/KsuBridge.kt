package com.vnm.optimizer

import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.webkit.JavascriptInterface
import android.webkit.WebView
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.Executors

/**
 * Same surface as the KernelSU WebUI bridge (window.ksu), so both UIs run unchanged.
 * Only pages served from the app's own assets can reach it.
 */
class KsuBridge(private val ctx: Context, private val web: WebView) {
    private val pool = Executors.newCachedThreadPool()
    private val cbName = Regex("^[A-Za-z0-9_]{1,80}$")

    @JavascriptInterface
    fun exec(cmd: String, options: String?, callback: String) {
        if (!cbName.matches(callback)) return
        pool.execute {
            val r = Shell.run(cmd)
            val js = "try{window[${JSONObject.quote(callback)}](${r.code},${JSONObject.quote(r.out)},${JSONObject.quote(r.err)})}catch(e){}"
            web.post { web.evaluateJavascript(js, null) }
        }
    }

    @JavascriptInterface
    fun listPackages(type: String): String {
        val pm = ctx.packageManager
        val arr = JSONArray()
        for (ai in pm.getInstalledApplications(0)) {
            val isSystem = (ai.flags and ApplicationInfo.FLAG_SYSTEM) != 0
            if (type == "system" && !isSystem) continue
            if (type == "user" && isSystem) continue
            arr.put(ai.packageName)
        }
        return arr.toString()
    }

    @JavascriptInterface
    fun getPackagesInfo(json: String): String {
        val pm = ctx.packageManager
        val out = JSONArray()
        try {
            val names = JSONArray(json)
            for (i in 0 until names.length()) {
                val pkg = names.optString(i)
                try {
                    val ai = pm.getApplicationInfo(pkg, 0)
                    val o = JSONObject()
                    o.put("packageName", pkg)
                    o.put("appLabel", pm.getApplicationLabel(ai).toString())
                    o.put("isSystem", (ai.flags and ApplicationInfo.FLAG_SYSTEM) != 0)
                    out.put(o)
                } catch (e: PackageManager.NameNotFoundException) {
                    // package not visible: skip
                }
            }
        } catch (e: Exception) {
            // bad input: return what we have
        }
        return out.toString()
    }
}
