package com.mkvenompro.optimizer

import android.content.Context
import android.util.Base64
import java.io.File
import java.math.BigInteger
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.security.KeyFactory
import java.security.KeyPair
import java.security.KeyPairGenerator
import java.security.Signature
import java.security.interfaces.RSAPublicKey
import java.security.spec.PKCS8EncodedKeySpec
import java.security.spec.X509EncodedKeySpec

/** RSA key the target phone remembers after you tap "Always allow" on its USB-debugging prompt. */
class AdbKeys(ctx: Context) {
    val keyPair: KeyPair

    init {
        val priv = File(ctx.filesDir, "adbkey.pk8")
        val pub = File(ctx.filesDir, "adbkey.x509")
        var kp: KeyPair? = null
        if (priv.exists() && pub.exists()) {
            try {
                val kf = KeyFactory.getInstance("RSA")
                kp = KeyPair(
                    kf.generatePublic(X509EncodedKeySpec(pub.readBytes())),
                    kf.generatePrivate(PKCS8EncodedKeySpec(priv.readBytes()))
                )
            } catch (e: Exception) {
                kp = null
            }
        }
        if (kp == null) {
            val g = KeyPairGenerator.getInstance("RSA")
            g.initialize(2048)
            kp = g.generateKeyPair()
            priv.writeBytes(kp.private.encoded)
            pub.writeBytes(kp.public.encoded)
        }
        keyPair = kp!!
    }

    /** AUTH_SIGNATURE: PKCS#1 v1.5 over the SHA-1 DigestInfo prefix + the 20-byte token (token is already a digest). */
    fun sign(token: ByteArray): ByteArray {
        val prefix = byteArrayOf(
            0x30, 0x21, 0x30, 0x09, 0x06, 0x05, 0x2b, 0x0e, 0x03, 0x02, 0x1a, 0x05, 0x00, 0x04, 0x14
        )
        val s = Signature.getInstance("NONEwithRSA")
        s.initSign(keyPair.private)
        s.update(prefix)
        s.update(token)
        return s.sign()
    }

    /** Public key in the Android "adb" format (base64 of the 524-byte struct + label + NUL). */
    fun publicKeyAdb(): ByteArray {
        val pub = keyPair.public as RSAPublicKey
        val n = pub.modulus
        val two32 = BigInteger.ONE.shiftLeft(32)
        val n0inv = two32.subtract(n.mod(two32).modInverse(two32))
        val rr = BigInteger.ONE.shiftLeft(4096).mod(n)
        val bb = ByteBuffer.allocate(524).order(ByteOrder.LITTLE_ENDIAN)
        bb.putInt(64)
        bb.putInt(n0inv.toInt())
        for (i in 0 until 64) bb.putInt(n.shiftRight(32 * i).toInt())
        for (i in 0 until 64) bb.putInt(rr.shiftRight(32 * i).toInt())
        bb.putInt(pub.publicExponent.toInt())
        val b64 = Base64.encodeToString(bb.array(), Base64.NO_WRAP)
        return ("$b64 mkvp@android").toByteArray() + 0.toByte()
    }
}
