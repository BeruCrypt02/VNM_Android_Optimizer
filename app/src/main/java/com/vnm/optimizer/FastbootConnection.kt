package com.vnm.optimizer

import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbEndpoint
import android.hardware.usb.UsbInterface
import android.hardware.usb.UsbManager
import java.io.InputStream

/** Minimal fastboot client over Android USB host. */
class FastbootConnection(
    private val usb: UsbManager,
    private val dev: UsbDevice
) {
    private var conn: UsbDeviceConnection? = null
    private var intf: UsbInterface? = null
    private var inEp: UsbEndpoint? = null
    private var outEp: UsbEndpoint? = null
    @Volatile var alive = false
        private set

    fun connect(): String? {
        for (i in 0 until dev.interfaceCount) {
            val f = dev.getInterface(i)
            if (f.interfaceClass == 0xFF && f.interfaceSubclass == 0x42 && f.interfaceProtocol == 3) intf = f
        }
        val f = intf ?: return "This USB device is not in fastboot mode"
        for (i in 0 until f.endpointCount) {
            val e = f.getEndpoint(i)
            if (e.type == UsbConstants.USB_ENDPOINT_XFER_BULK) {
                if (e.direction == UsbConstants.USB_DIR_IN) inEp = e else outEp = e
            }
        }
        if (inEp == null || outEp == null) return "Fastboot endpoints not found"
        val c = usb.openDevice(dev) ?: return "Cannot open the device (USB permission missing?)"
        if (!c.claimInterface(f, true)) { c.close(); return "Cannot claim the fastboot interface" }
        conn = c
        alive = true
        return null
    }

    fun close() {
        alive = false
        try { intf?.let { conn?.releaseInterface(it) } } catch (e: Exception) { }
        try { conn?.close() } catch (e: Exception) { }
        conn = null
    }

    private fun write(b: ByteArray, len: Int = b.size, timeout: Int = 10000): Boolean {
        val n = conn!!.bulkTransfer(outEp, b, len, timeout)
        return n == len
    }

    private fun readResp(timeout: Int): String? {
        val buf = ByteArray(4096)
        val n = conn!!.bulkTransfer(inEp, buf, buf.size, timeout)
        return if (n < 0) null else String(buf, 0, n, Charsets.UTF_8)
    }

    /** CLI-style input ("getvar all", "reboot bootloader") -> protocol command ("getvar:all", "reboot-bootloader"). */
    fun normalize(c: String): String {
        val s = c.trim()
        val head = s.substringBefore(' ')
        val rest = s.substringAfter(' ', "").trim()
        return when {
            head == "getvar" && rest.isNotEmpty() -> "getvar:$rest"
            head == "erase" && rest.isNotEmpty() -> "erase:$rest"
            head == "set_active" && rest.isNotEmpty() -> "set_active:$rest"
            head == "reboot" && rest.isNotEmpty() -> "reboot-$rest"
            else -> s
        }
    }

    /** Sends one command, collects INFO lines, returns (ok, text). */
    @Synchronized
    fun command(raw: String, timeout: Int = 20000): Pair<Boolean, String> {
        val cmd = normalize(raw)
        if (cmd.toByteArray().size > 64) return false to "Command longer than 64 bytes"
        if (!write(cmd.toByteArray())) return false to "USB write failed"
        val sb = StringBuilder()
        while (true) {
            val r = readResp(timeout) ?: return false to (sb.toString() + "\n(timeout)").trim()
            when {
                r.startsWith("INFO") -> sb.append(r.substring(4)).append('\n')
                r.startsWith("TEXT") -> sb.append(r.substring(4))
                r.startsWith("OKAY") -> { sb.append(r.substring(4)); return true to sb.toString().trim() }
                r.startsWith("FAIL") -> { sb.append(r.substring(4)); return false to ("FAIL: " + sb.toString().trim()) }
                else -> return false to (sb.toString() + r).trim()
            }
        }
    }

    fun maxDownload(): Long {
        val (ok, t) = command("getvar:max-download-size")
        if (!ok) return 0x10000000L
        val v = t.substringAfter(':').trim().removePrefix("0x")
        return try { java.lang.Long.parseLong(v, 16) } catch (e: Exception) { 0x10000000L }
    }

    /** download + flash one image (must fit in max-download-size). */
    @Synchronized
    fun flash(partition: String, input: InputStream, size: Long, progress: (Int) -> Unit): Pair<Boolean, String> {
        if (size <= 0 || size > Int.MAX_VALUE) return false to "Bad file size"
        val max = maxDownload()
        if (size > max) {
            return false to "Image is ${size / 1048576} MB but the bootloader accepts at most ${max / 1048576} MB per download. " +
                "Use a sparse/split image or flash it from a PC."
        }
        if (!write(String.format("download:%08x", size.toInt()).toByteArray())) return false to "USB write failed"
        val r = readResp(10000) ?: return false to "No answer to download"
        if (!r.startsWith("DATA")) return false to r
        val buf = ByteArray(16384)
        var sent = 0L
        while (sent < size) {
            val want = minOf(buf.size.toLong(), size - sent).toInt()
            val n = input.read(buf, 0, want)
            if (n <= 0) return false to "File ended early"
            if (!write(buf, n, 15000)) return false to "USB write failed at ${sent / 1024} KB"
            sent += n
            progress((sent * 100 / size).toInt())
        }
        val done = readResp(60000) ?: return false to "No answer after download"
        if (!done.startsWith("OKAY")) return false to done
        return command("flash:$partition", 180000)
    }
}
