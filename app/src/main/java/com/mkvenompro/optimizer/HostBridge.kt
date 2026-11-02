package com.mkvenompro.optimizer

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbManager
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import android.webkit.JavascriptInterface
import android.webkit.WebView
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors

/**
 * window.mkvp: the phone is the USB host, the target phone must be plugged in (OTG).
 * Works without root or Shizuku.
 */
class HostBridge(private val act: MainActivity, private val web: WebView) {
    private val usb = act.getSystemService(Context.USB_SERVICE) as UsbManager
    private val pool = Executors.newCachedThreadPool()
    private val keys by lazy { AdbKeys(act) }
    private val adb = ConcurrentHashMap<String, AdbConnection>()
    private val fb = ConcurrentHashMap<String, FastbootConnection>()
    private val cbName = Regex("^[A-Za-z0-9_]{1,80}$")
    @Volatile private var picked: Uri? = null

    private fun reply(cb: String, o: JSONObject) {
        if (!cbName.matches(cb)) return
        val js = "try{window[${JSONObject.quote(cb)}](${JSONObject.quote(o.toString())})}catch(e){}"
        web.post { web.evaluateJavascript(js, null) }
    }

    private fun res(ok: Boolean, text: String) = JSONObject().put("ok", ok).put("out", text)

    private fun find(name: String): UsbDevice? = usb.deviceList.values.firstOrNull { it.deviceName == name }

    private fun kindOf(d: UsbDevice): String {
        var k = "other"
        for (i in 0 until d.interfaceCount) {
            val f = d.getInterface(i)
            if (f.interfaceClass == 0xFF && f.interfaceSubclass == 0x42) {
                if (f.interfaceProtocol == 1) return "adb"
                if (f.interfaceProtocol == 3) k = "fastboot"
            }
        }
        return k
    }

    @JavascriptInterface
    fun devices(): String {
        val arr = JSONArray()
        val names = usb.deviceList.values.map { it.deviceName }.toSet()
        adb.keys.filter { it !in names }.forEach { adb.remove(it)?.close() }
        fb.keys.filter { it !in names }.forEach { fb.remove(it)?.close() }
        for (d in usb.deviceList.values) {
            arr.put(
                JSONObject()
                    .put("name", d.deviceName)
                    .put("vid", d.vendorId)
                    .put("pid", d.productId)
                    .put("product", d.productName ?: "")
                    .put("kind", kindOf(d))
                    .put("perm", usb.hasPermission(d))
            )
        }
        return arr.toString()
    }

    @JavascriptInterface
    fun requestPermission(name: String, cb: String) {
        val d = find(name) ?: return reply(cb, res(false, "Device not found"))
        if (usb.hasPermission(d)) return reply(cb, res(true, "granted"))
        val action = "${act.packageName}.USB_PERMISSION"
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(c: Context, i: Intent) {
                try { act.unregisterReceiver(this) } catch (e: Exception) { }
                reply(cb, res(i.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false), "permission"))
            }
        }
        val filter = IntentFilter(action)
        if (Build.VERSION.SDK_INT >= 33) act.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        else act.registerReceiver(receiver, filter)
        val pi = PendingIntent.getBroadcast(
            act, 0, Intent(action).setPackage(act.packageName),
            PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        usb.requestPermission(d, pi)
    }

    private fun adbFor(name: String): Pair<AdbConnection?, String?> {
        adb[name]?.let { if (it.alive) return it to null; adb.remove(name) }
        val d = find(name) ?: return null to "Device not found"
        if (!usb.hasPermission(d)) return null to "USB permission not granted"
        val c = AdbConnection(usb, d, keys)
        val err = c.connect()
        if (err != null) return null to err
        adb[name] = c
        return c to null
    }

    private fun fbFor(name: String): Pair<FastbootConnection?, String?> {
        fb[name]?.let { if (it.alive) return it to null; fb.remove(name) }
        val d = find(name) ?: return null to "Device not found"
        if (!usb.hasPermission(d)) return null to "USB permission not granted"
        val c = FastbootConnection(usb, d)
        val err = c.connect()
        if (err != null) return null to err
        fb[name] = c
        return c to null
    }

    /** service examples: "shell:getprop", "reboot:bootloader", "root:", "tcpip:5555" */
    @JavascriptInterface
    fun adbService(name: String, service: String, cb: String) {
        pool.execute {
            val (c, err) = adbFor(name)
            if (c == null) return@execute reply(cb, res(false, err ?: "not connected"))
            try {
                val out = c.stream(service)
                reply(cb, res(true, out.ifEmpty { "(no output)" }))
            } catch (e: Exception) {
                c.close(); adb.remove(name)
                reply(cb, res(false, e.message ?: e.toString()))
            }
        }
    }

    @JavascriptInterface
    fun adbRun(name: String, cmd: String, cb: String) = adbService(name, "shell:$cmd", cb)

    @JavascriptInterface
    fun fbRun(name: String, cmd: String, cb: String) {
        pool.execute {
            val (c, err) = fbFor(name)
            if (c == null) return@execute reply(cb, res(false, err ?: "not connected"))
            try {
                val (ok, text) = c.command(cmd, 120000)
                reply(cb, res(ok, text.ifEmpty { "(done)" }))
            } catch (e: Exception) {
                c.close(); fb.remove(name)
                reply(cb, res(false, e.message ?: e.toString()))
            }
        }
    }

    /** Opens the system file picker; the chosen file is used by adbInstall / fbFlash. */
    @JavascriptInterface
    fun pickFile(cb: String) {
        act.runOnUiThread {
            act.pickFile { uri ->
                picked = uri
                if (uri == null) { reply(cb, res(false, "cancelled")); return@pickFile }
                var nm = uri.lastPathSegment ?: "file"
                var size = -1L
                act.contentResolver.query(uri, null, null, null, null)?.use { q ->
                    if (q.moveToFirst()) {
                        val ni = q.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        val si = q.getColumnIndex(OpenableColumns.SIZE)
                        if (ni >= 0) nm = q.getString(ni)
                        if (si >= 0) size = q.getLong(si)
                    }
                }
                reply(cb, res(true, nm).put("size", size).put("path", realPath(uri)))
            }
        }
    }

    /** Best-effort real path of a picked document (primary storage / raw downloads) so root tools can use it, "" otherwise. */
    private fun realPath(uri: android.net.Uri): String {
        return try {
            val id = android.provider.DocumentsContract.getDocumentId(uri)
            when {
                id.startsWith("primary:") -> "/storage/emulated/0/" + id.removePrefix("primary:")
                id.startsWith("raw:") -> id.removePrefix("raw:")
                else -> ""
            }
        } catch (e: Exception) { "" }
    }

    private fun progress(p: Int) {
        web.post { web.evaluateJavascript("try{window.mkvpProgress&&window.mkvpProgress($p)}catch(e){}", null) }
    }

    @JavascriptInterface
    fun adbInstall(name: String, cb: String) {
        val uri = picked ?: return reply(cb, res(false, "Pick an APK first"))
        pool.execute {
            val (c, err) = adbFor(name)
            if (c == null) return@execute reply(cb, res(false, err ?: "not connected"))
            try {
                val size = act.contentResolver.openFileDescriptor(uri, "r")?.use { it.statSize } ?: -1L
                if (size <= 0) return@execute reply(cb, res(false, "Cannot read the file size"))
                act.contentResolver.openInputStream(uri)!!.use { ins ->
                    val out = c.stream("exec:cmd package install -S $size", ins, 120000) { sent -> progress((sent * 100 / size).toInt()) }
                    reply(cb, res(out.contains("Success"), out.trim().ifEmpty { "(no output)" }))
                }
            } catch (e: Exception) {
                c.close(); adb.remove(name)
                reply(cb, res(false, e.message ?: e.toString()))
            }
        }
    }

    @JavascriptInterface
    fun fbFlash(name: String, partition: String, cb: String) {
        if (!Regex("^[A-Za-z0-9_.-]{1,40}$").matches(partition)) return reply(cb, res(false, "Bad partition name"))
        val uri = picked ?: return reply(cb, res(false, "Pick an image first"))
        pool.execute {
            val (c, err) = fbFor(name)
            if (c == null) return@execute reply(cb, res(false, err ?: "not connected"))
            try {
                val size = act.contentResolver.openFileDescriptor(uri, "r")?.use { it.statSize } ?: -1L
                act.contentResolver.openInputStream(uri)!!.use { ins ->
                    val (ok, text) = c.flash(partition, ins, size) { p -> progress(p) }
                    reply(cb, res(ok, text.ifEmpty { "flashed $partition" }))
                }
            } catch (e: Exception) {
                c.close(); fb.remove(name)
                reply(cb, res(false, e.message ?: e.toString()))
            }
        }
    }

    /** adb sideload of the picked zip to a target in sideload mode. */
    @JavascriptInterface
    fun adbSideload(name: String, cb: String) {
        val uri = picked ?: return reply(cb, res(false, "Pick a zip first"))
        pool.execute {
            val (c, err) = adbFor(name)
            if (c == null) return@execute reply(cb, res(false, err ?: "not connected"))
            try {
                val pfd = act.contentResolver.openFileDescriptor(uri, "r") ?: return@execute reply(cb, res(false, "Cannot open the file"))
                pfd.use {
                    val size = it.statSize
                    if (size <= 0) return@execute reply(cb, res(false, "Cannot read the file size"))
                    java.io.FileInputStream(it.fileDescriptor).channel.use { ch ->
                        val out = c.sideload(size, ch) { p -> progress(p) }
                        reply(cb, res(out.contains("finished"), out))
                    }
                }
            } catch (e: Exception) {
                c.close(); adb.remove(name)
                reply(cb, res(false, e.message ?: e.toString()))
            }
        }
    }
}
