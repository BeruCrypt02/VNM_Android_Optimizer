package com.mkvenompro.optimizer.toolkit

import android.content.Context

class CustomPartitionStore(context: Context) {
    private val prefs = context.getSharedPreferences("custom_partitions", Context.MODE_PRIVATE)
    fun all(): List<String> = prefs.getStringSet("items", emptySet()).orEmpty().sorted()
    fun add(name: String): Boolean {
        val clean = name.trim()
        if (!clean.matches(Regex("[A-Za-z0-9_.-]{1,64}"))) return false
        val updated = prefs.getStringSet("items", emptySet()).orEmpty().toMutableSet()
        updated.add(clean)
        prefs.edit().putStringSet("items", updated).apply()
        return true
    }
    fun remove(name: String) {
        val updated = prefs.getStringSet("items", emptySet()).orEmpty().toMutableSet()
        updated.remove(name)
        prefs.edit().putStringSet("items", updated).apply()
    }
}
