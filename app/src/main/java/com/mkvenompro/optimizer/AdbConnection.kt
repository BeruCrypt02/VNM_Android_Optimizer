package com.mkvenompro.optimizer

import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbEndpoint
import android.hardware.usb.UsbInterface
import android.hardware.usb.UsbManager
import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder

/** Minimal ADB client over Android USB host (phone = host, target = device). */
class AdbConnection(
    private val usb: UsbManager,
    private val dev: UsbDevice,
    private val keys: AdbKeys
) {
    private class Msg(val cmd: Int, val arg0: Int, val arg1: Int, val data: ByteArray)

    private var conn: UsbDeviceConnection? = null
    private var intf: UsbInterface? = null
    private var inEp: UsbEndpoint? = null
    private var outEp: UsbEndpoint? = null
    private var maxData = 4096
    private var nextId = 1
    @Volatile var alive = false
        private set

    companion object {
        const val A_CNXN = 0x4e584e43
        const val A_AUTH = 0x48545541
        const val A_OPEN = 0x4e45504f
        const val A_OKAY = 0x59414b4f
        const val A_CLSE = 0x45534c43
        const val A_WRTE = 0x45545257
        private const val OUT_CAP = 1 shl 20
    }

    /** Returns null on success, otherwise an error text. */
    fun connect(): String? {
        for (i in 0 until dev.interfaceCount) {
            val f = dev.getInterface(i)
            if (f.interfaceClass == 0xFF && f.interfaceSubclass == 0x42 && f.interfaceProtocol == 1) intf = f
        }
        val f = intf ?: return "This USB device has no ADB interface (is USB debugging on?)"
        for (i in 0 until f.endpointCount) {
            val e = f.getEndpoint(i)
            if (e.type == UsbConstants.USB_ENDPOINT_XFER_BULK) {
                if (e.direction == UsbConstants.USB_DIR_IN) inEp = e else outEp = e
            }
        }
        if (inEp == null || outEp == null) return "ADB endpoints not found"
        val c = usb.openDevice(dev) ?: return "Cannot open the device (USB permission missing?)"
        if (!c.claimInterface(f, true)) { c.close(); return "Cannot claim the ADB interface" }
        conn = c

        send(A_CNXN, 0x01000001, 256 * 1024, "host::\u0000".toByteArray())
        var sentSig = false
        while (true) {
            // generous timeout: the target shows an "Allow USB debugging?" prompt
            val m = read(30000) ?: run { close(); return "No answer. Accept the USB-debugging prompt on the target and retry." }
            when (m.cmd) {
                A_CNXN -> { maxData = m.arg1.coerceIn(256, 16384); alive = true; return null }
                A_AUTH -> if (m.arg0 == 1) {
                    if (!sentSig) { send(A_AUTH, 2, 0, keys.sign(m.data)); sentSig = true }
                    else send(A_AUTH, 3, 0, keys.publicKeyAdb())
                }
            }
        }
    }

    fun close() {
        alive = false
        try { intf?.let { conn?.releaseInterface(it) } } catch (e: Exception) { }
        try { conn?.close() } catch (e: Exception) { }
        conn = null
    }

    private fun send(cmd: Int, a0: Int, a1: Int, data: ByteArray = ByteArray(0)) {
        val h = ByteBuffer.allocate(24).order(ByteOrder.LITTLE_ENDIAN)
        h.putInt(cmd); h.putInt(a0); h.putInt(a1); h.putInt(data.size); h.putInt(0); h.putInt(cmd xor -1)
        writeAll(h.array(), 24)
        if (data.isNotEmpty()) writeAll(data, data.size)
    }

    private fun writeAll(b: ByteArray, len: Int) {
        var off = 0
        while (off < len) {
            val n = len - off
            val chunk = if (n > 16384) 16384 else n
            val part = if (off == 0 && chunk == len) b else b.copyOfRange(off, off + chunk)
            val w = conn!!.bulkTransfer(outEp, part, chunk, 10000)
            if (w < 0) throw java.io.IOException("USB write failed")
            off += chunk
        }
    }

    private fun readFully(len: Int, timeout: Int): ByteArray? {
        val buf = ByteArray(len)
        var off = 0
        while (off < len) {
            val tmp = ByteArray(minOf(len - off, 16384))
            val n = conn!!.bulkTransfer(inEp, tmp, tmp.size, timeout)
            if (n <= 0) return null
            System.arraycopy(tmp, 0, buf, off, n)
            off += n
        }
        return buf
    }

    private fun read(timeout: Int): Msg? {
        val h = readFully(24, timeout) ?: return null
        val bb = ByteBuffer.wrap(h).order(ByteOrder.LITTLE_ENDIAN)
        val cmd = bb.getInt(0); val a0 = bb.getInt(4); val a1 = bb.getInt(8); val len = bb.getInt(12)
        if (len < 0 || len > (1 shl 20)) return null
        val data = if (len > 0) (readFully(len, timeout) ?: return null) else ByteArray(0)
        return Msg(cmd, a0, a1, data)
    }

    /** Opens [service] (e.g. "shell:ls", "reboot:bootloader"), optionally streams [input], returns the text output. */
    @Synchronized
    fun stream(service: String, input: InputStream? = null, timeout: Int = 15000, onProgress: ((Long) -> Unit)? = null): String {
        val local = nextId++
        send(A_OPEN, local, 0, (service + "\u0000").toByteArray())
        var remote = 0
        while (true) {
            val m = read(timeout) ?: throw java.io.IOException("No answer from the target")
            if (m.cmd == A_OKAY && m.arg1 == local) { remote = m.arg0; break }
            if (m.cmd == A_CLSE) return "(service refused or closed)"
        }
        if (input != null) {
            val buf = ByteArray(maxData)
            var total = 0L
            while (true) {
                val n = input.read(buf)
                if (n <= 0) break
                send(A_WRTE, local, remote, buf.copyOf(n))
                total += n
                onProgress?.invoke(total)
                while (true) {
                    val m = read(timeout) ?: throw java.io.IOException("No answer from the target")
                    if (m.cmd == A_OKAY && m.arg1 == local) break
                    if (m.cmd == A_CLSE) return "(closed by target)"
                }
            }
        }
        val out = ByteArrayOutputStream()
        while (true) {
            val m = read(timeout) ?: break
            when (m.cmd) {
                A_WRTE -> {
                    if (out.size() < OUT_CAP) out.write(m.data)
                    send(A_OKAY, local, remote)
                }
                A_CLSE -> { send(A_CLSE, local, remote); break }
            }
        }
        return out.toString("UTF-8")
    }
}
