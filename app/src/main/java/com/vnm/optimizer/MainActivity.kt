package com.vnm.optimizer

import android.app.Activity
import android.app.AlertDialog
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.graphics.Bitmap
import android.graphics.Canvas
import org.json.JSONObject
import android.util.LruCache
import java.io.ByteArrayOutputStream
import android.net.Uri
import android.os.Bundle
import android.webkit.ConsoleMessage
import android.webkit.JsResult
import android.webkit.ValueCallback
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Toast
import androidx.webkit.WebViewAssetLoader
import java.io.ByteArrayInputStream
import rikka.shizuku.Shizuku
import java.util.concurrent.Executors

class MainActivity : Activity() {
    private lateinit var web: WebView
    private var chooser: ValueCallback<Array<Uri>>? = null
    private val bg = Executors.newSingleThreadExecutor()

    private val host = "appassets.androidplatform.net"
    private val dynPrefix = "/assets/web/dyn/"
    private val dynRoot = "${EngineInstaller.ENGINE_DIR}/tools/webroot/"
    private val safeRel = Regex("^[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)*$")

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.statusBarColor = 0xFF251A1E.toInt()
        window.navigationBarColor = 0xFF1A1114.toInt()

        web = WebView(this)
        web.setBackgroundColor(0xFF1A1114.toInt())
        setContentView(web)

        val loader = WebViewAssetLoader.Builder()
            .setDomain(host)
            .addPathHandler("/assets/", WebViewAssetLoader.AssetsPathHandler(this))
            .build()

        with(web.settings) {
            javaScriptEnabled = true
            domStorageEnabled = true
            allowFileAccess = false
            allowContentAccess = false
            cacheMode = WebSettings.LOAD_NO_CACHE
            setSupportZoom(false)
        }

        web.addJavascriptInterface(KsuBridge(this, web), "ksu")
        web.addJavascriptInterface(HostBridge(this, web), "mkvp")
        web.addJavascriptInterface(UiBridge(this), "mkvpui")

        web.webViewClient = object : WebViewClient() {
            override fun shouldInterceptRequest(view: WebView, request: WebResourceRequest): WebResourceResponse? {
                val u = request.url
                if (u.host == host && u.path?.startsWith(dynPrefix) == true) {
                    return serveDynamic(u.path!!.removePrefix(dynPrefix))
                }
                return loader.shouldInterceptRequest(u)
            }

            override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
                val u = request.url
                if (u.host == host) return false
                if (u.scheme == "https" || u.scheme == "http") {
                    try {
                        startActivity(Intent(Intent.ACTION_VIEW, u))
                    } catch (e: ActivityNotFoundException) {
                        Toast.makeText(this@MainActivity, u.toString(), Toast.LENGTH_LONG).show()
                    }
                }
                return true
            }
        }

        web.webChromeClient = object : WebChromeClient() {
            override fun onJsAlert(view: WebView, url: String, message: String, result: JsResult): Boolean {
                AlertDialog.Builder(this@MainActivity).setMessage(message)
                    .setPositiveButton(android.R.string.ok) { _, _ -> result.confirm() }
                    .setOnCancelListener { result.cancel() }.show()
                return true
            }

            override fun onJsConfirm(view: WebView, url: String, message: String, result: JsResult): Boolean {
                AlertDialog.Builder(this@MainActivity).setMessage(message)
                    .setPositiveButton(android.R.string.ok) { _, _ -> result.confirm() }
                    .setNegativeButton(android.R.string.cancel) { _, _ -> result.cancel() }
                    .setOnCancelListener { result.cancel() }.show()
                return true
            }

            override fun onShowFileChooser(
                view: WebView,
                callback: ValueCallback<Array<Uri>>,
                params: FileChooserParams
            ): Boolean {
                chooser?.onReceiveValue(null)
                chooser = callback
                return try {
                    val i = Intent(Intent.ACTION_GET_CONTENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "*/*"
                    }
                    startActivityForResult(i, 77)
                    true
                } catch (e: ActivityNotFoundException) {
                    chooser = null
                    false
                }
            }

            override fun onConsoleMessage(m: ConsoleMessage): Boolean = true
        }

        web.loadUrl("https://$host/assets/web/index.html")
        checkEngine()
    }

    /** Files that the root scripts write at runtime (app names, icons, screenshots, status). */
    private val iconCache = LruCache<String, ByteArray>(400)
    private val pkgRe = Regex("^[A-Za-z0-9._]+$")
    private var labelsAt = 0L
    private var labelsJson = "{}"

    private fun nativeIcon(pkg: String): ByteArray? {
        if (!pkgRe.matches(pkg)) return null
        iconCache.get(pkg)?.let { return it }
        return try {
            val pm = packageManager
            // 0x2000 = MATCH_UNINSTALLED_PACKAGES: also apps already removed for this user
            val ai = pm.getApplicationInfo(pkg, 0x00002000)
            val d = ai.loadIcon(pm)
            val size = 112
            val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            val c = Canvas(bmp)
            d.setBounds(0, 0, size, size)
            d.draw(c)
            val out = ByteArrayOutputStream()
            bmp.compress(Bitmap.CompressFormat.PNG, 100, out)
            bmp.recycle()
            val b = out.toByteArray()
            iconCache.put(pkg, b)
            b
        } catch (e: Exception) {
            null
        }
    }

    @Synchronized
    private fun nativeLabels(): ByteArray {
        val now = System.currentTimeMillis()
        if (now - labelsAt > 30000) {
            val pm = packageManager
            val o = JSONObject()
            try {
                for (ai in pm.getInstalledApplications(0x00002000)) {
                    try { o.put(ai.packageName, ai.loadLabel(pm).toString()) } catch (e: Exception) { }
                }
            } catch (e: Exception) { }
            labelsJson = o.toString()
            labelsAt = now
        }
        return labelsJson.toByteArray(Charsets.UTF_8)
    }

    private fun serveDynamic(rel: String): WebResourceResponse {
        val noStore = mapOf("Cache-Control" to "no-store")
        if (rel == "app_labels.json") {
            return WebResourceResponse("application/json", null, 200, "OK", noStore, ByteArrayInputStream(nativeLabels()))
        }
        if (rel.startsWith("icons/") && rel.endsWith(".png")) {
            val b = nativeIcon(rel.substring(6, rel.length - 4))
            if (b != null) {
                return WebResourceResponse("image/png", null, 200, "OK", mapOf("Cache-Control" to "max-age=600"), ByteArrayInputStream(b))
            }
        }
        val bytes = if (safeRel.matches(rel) && !rel.contains("..")) Shell.readBytes(dynRoot + rel) else null
        val mime = when {
            rel.endsWith(".json") -> "application/json"
            rel.endsWith(".png") -> "image/png"
            else -> "application/octet-stream"
        }
        val headers = mapOf("Cache-Control" to "no-store")
        return if (bytes != null) {
            WebResourceResponse(mime, null, 200, "OK", headers, ByteArrayInputStream(bytes))
        } else {
            WebResourceResponse(mime, null, 404, "Not Found", headers, ByteArrayInputStream(ByteArray(0)))
        }
    }

    private val shizukuListener =
        Shizuku.OnRequestPermissionResultListener { _, grant ->
            if (grant == android.content.pm.PackageManager.PERMISSION_GRANTED) {
                Shell.backend = Shell.Backend.SHIZUKU
                runOnUiThread {
                    Toast.makeText(this, "Shizuku connected (shell mode: root-only features are unavailable)", Toast.LENGTH_LONG).show()
                    web.reload()
                }
            }
        }

    private fun checkEngine() {
        bg.execute {
            when (Shell.detect()) {
                Shell.Backend.ROOT -> {
                    if (EngineInstaller.isCurrent()) return@execute
                    runOnUiThread {
                        AlertDialog.Builder(this)
                            .setTitle("Install engine")
                            .setMessage(
                                "The boot-time parts (thermal tweaks, FOD, brightness, OTG, overlays) are installed by " +
                                    "this app itself, using its root access, into /data/adb/mkvp. No Magisk / KernelSU / APatch " +
                                    "module is created. Install now? A reboot is needed afterwards."
                            )
                            .setPositiveButton("Install") { _, _ -> runInstall() }
                            .setNegativeButton("Later", null)
                            .show()
                    }
                }
                Shell.Backend.SHIZUKU -> runOnUiThread {
                    Toast.makeText(this, "Running through Shizuku (shell). Root-only features are unavailable.", Toast.LENGTH_LONG).show()
                }
                Shell.Backend.NONE -> runOnUiThread {
                    if (Shell.shizukuBinderAlive()) {
                        // Shizuku is running but this app has no permission yet
                        Shizuku.addRequestPermissionResultListener(shizukuListener)
                        Shizuku.requestPermission(100)
                    } else {
                        AlertDialog.Builder(this)
                            .setTitle("Root or Shizuku required")
                            .setMessage(
                                "Grant root to this app, or start Shizuku and reopen the app. " +
                                    "ADB / Fastboot over OTG works without either."
                            )
                            .setPositiveButton("Retry") { _, _ -> checkEngine() }
                            .setNegativeButton("Close", null)
                            .show()
                    }
                }
            }
        }
    }

    private var pickCb: ((Uri?) -> Unit)? = null

    fun pickFile(cb: (Uri?) -> Unit) {
        pickCb = cb
        try {
            val i = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "*/*"
            }
            startActivityForResult(i, 78)
        } catch (e: ActivityNotFoundException) {
            pickCb = null
            cb(null)
        }
    }

    override fun onDestroy() {
        try { Shizuku.removeRequestPermissionResultListener(shizukuListener) } catch (t: Throwable) { }
        super.onDestroy()
    }

    private fun runInstall() {
        Toast.makeText(this, "Installing…", Toast.LENGTH_SHORT).show()
        bg.execute {
            val r = EngineInstaller.install(this)
            runOnUiThread {
                if (r.code == 0) {
                    AlertDialog.Builder(this)
                        .setTitle("Engine installed")
                        .setMessage("Reboot now to activate it?")
                        .setPositiveButton("Reboot") { _, _ -> bg.execute { Shell.run("sync; reboot") } }
                        .setNegativeButton("Later", null)
                        .show()
                } else {
                    val tail = (r.out + "\n" + r.err).trim().takeLast(600)
                    AlertDialog.Builder(this).setTitle("Install failed").setMessage(tail)
                        .setPositiveButton(android.R.string.ok, null).show()
                }
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == 77) {
            val uri = data?.data
            chooser?.onReceiveValue(if (resultCode == RESULT_OK && uri != null) arrayOf(uri) else null)
            chooser = null
        } else if (requestCode == 78) {
            val cb = pickCb
            pickCb = null
            cb?.invoke(if (resultCode == RESULT_OK) data?.data else null)
        } else {
            super.onActivityResult(requestCode, resultCode, data)
        }
    }

    override fun onBackPressed() {
        if (web.canGoBack()) web.goBack() else finish()
    }
}
