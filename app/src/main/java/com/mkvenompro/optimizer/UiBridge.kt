package com.mkvenompro.optimizer

import android.app.WallpaperManager
import android.content.Context
import android.content.res.Configuration
import android.graphics.Color
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.view.View
import android.view.WindowInsetsController
import android.webkit.JavascriptInterface
import org.json.JSONObject

/** window.mkvpui: system colours (wallpaper-adaptive), system bars and haptics for the web UI. */
class UiBridge(private val act: MainActivity) {
    private val vib: Vibrator? = act.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
    private val shades = intArrayOf(0, 10, 50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 1000)

    private fun hex(c: Int) = String.format("#%06x", c and 0xFFFFFF)

    private fun palette(name: String): JSONObject {
        val o = JSONObject()
        for (s in shades) {
            val id = act.resources.getIdentifier("system_${name}_$s", "color", "android")
            if (id != 0) {
                try { o.put(s.toString(), hex(act.getColor(id))) } catch (e: Exception) { }
            }
        }
        return o
    }

    /** Material You tonal palettes (Android 12+) and the wallpaper's main colour (Android 8.1+). */
    @JavascriptInterface
    fun theme(): String {
        val o = JSONObject()
        o.put("sdk", Build.VERSION.SDK_INT)
        val night = (act.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
        o.put("night", night)
        if (Build.VERSION.SDK_INT >= 31) {
            val a1 = palette("accent1")
            if (a1.length() > 0) {
                o.put("a1", a1)
                o.put("n1", palette("neutral1"))
                o.put("n2", palette("neutral2"))
                o.put("a2", palette("accent2"))
            }
        }
        if (Build.VERSION.SDK_INT >= 27) {
            try {
                val wc = WallpaperManager.getInstance(act).getWallpaperColors(WallpaperManager.FLAG_SYSTEM)
                if (wc != null) o.put("wallpaper", hex(wc.primaryColor.toArgb()))
            } catch (e: Exception) { }
        }
        return o.toString()
    }

    @JavascriptInterface
    fun setBars(bgHex: String, lightIcons: Boolean) {
        val c = try { Color.parseColor(bgHex) } catch (e: Exception) { return }
        act.runOnUiThread {
            val w = act.window
            w.statusBarColor = c
            w.navigationBarColor = c
            if (Build.VERSION.SDK_INT >= 30) {
                val ic = w.insetsController
                val mask = WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS or WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS
                ic?.setSystemBarsAppearance(if (lightIcons) mask else 0, mask)
            } else {
                @Suppress("DEPRECATION")
                var f = w.decorView.systemUiVisibility
                @Suppress("DEPRECATION")
                f = if (lightIcons) f or View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR else f and View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR.inv()
                @Suppress("DEPRECATION")
                w.decorView.systemUiVisibility = f
            }
        }
    }

    /** kind: tick | click | heavy | success | error. level: 0 off, 1 light, 2 normal. */
    @JavascriptInterface
    fun haptic(kind: String, level: Int) {
        val v = vib ?: return
        if (level <= 0 || !v.hasVibrator()) return
        val k = if (level == 1) 0.45f else 1f
        try {
            when (kind) {
                "tick" -> one(v, 8, (70 * k).toInt(), VibrationEffect.EFFECT_TICK, level)
                "click" -> one(v, 14, (120 * k).toInt(), VibrationEffect.EFFECT_CLICK, level)
                "heavy" -> one(v, 28, (230 * k).toInt(), VibrationEffect.EFFECT_HEAVY_CLICK, level)
                "success" -> wave(v, longArrayOf(0, 12, 55, 20), intArrayOf(0, (110 * k).toInt(), 0, (200 * k).toInt()))
                "error" -> wave(v, longArrayOf(0, 28, 45, 28, 45, 60), intArrayOf(0, (200 * k).toInt(), 0, (200 * k).toInt(), 0, (255 * k).toInt()))
            }
        } catch (e: Exception) {
            // vibration is best effort
        }
    }

    private fun one(v: Vibrator, ms: Long, amp: Int, predefined: Int, level: Int) {
        if (Build.VERSION.SDK_INT >= 29 && level >= 2) {
            v.vibrate(VibrationEffect.createPredefined(predefined))
        } else if (v.hasAmplitudeControl()) {
            v.vibrate(VibrationEffect.createOneShot(ms, amp.coerceIn(1, 255)))
        } else {
            v.vibrate(VibrationEffect.createOneShot(ms, VibrationEffect.DEFAULT_AMPLITUDE))
        }
    }

    private fun wave(v: Vibrator, t: LongArray, a: IntArray) {
        if (v.hasAmplitudeControl()) v.vibrate(VibrationEffect.createWaveform(t, a.map { it.coerceIn(0, 255) }.toIntArray(), -1))
        else v.vibrate(VibrationEffect.createWaveform(t, -1))
    }
}
