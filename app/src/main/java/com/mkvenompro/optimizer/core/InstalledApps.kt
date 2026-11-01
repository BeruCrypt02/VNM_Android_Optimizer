package com.mkvenompro.optimizer.core

import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager

data class InstalledApp(val label: String, val packageName: String, val system: Boolean, val icon: android.graphics.drawable.Drawable)

@Suppress("DEPRECATION")
fun loadInstalledApps(context: Context): List<InstalledApp> {
    val pm = context.packageManager
    return pm.getInstalledApplications(PackageManager.GET_META_DATA)
        .map { info ->
            InstalledApp(
                pm.getApplicationLabel(info).toString(),
                info.packageName,
                (info.flags and ApplicationInfo.FLAG_SYSTEM) != 0,
                pm.getApplicationIcon(info)
            )
        }.sortedBy { it.label.lowercase() }
}
