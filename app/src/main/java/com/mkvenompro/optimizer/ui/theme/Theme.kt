package com.mkvenompro.optimizer.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

/** Persisted by MainActivity; SYSTEM follows Android's current appearance setting. */
enum class ThemeMode(val label: String) {
    SYSTEM("System"), DARK("Dark"), LIGHT("Light")
}

private val DarkScheme = darkColorScheme(
    primary = Color(0xFF55E6C1),
    onPrimary = Color(0xFF002019),
    secondary = Color(0xFF8DB7FF),
    tertiary = Color(0xFFFFC96B),
    background = Color(0xFF070B10),
    onBackground = Color(0xFFE7EEF5),
    surface = Color(0xFF101820),
    onSurface = Color(0xFFE7EEF5),
    surfaceVariant = Color(0xFF1A2732),
    onSurfaceVariant = Color(0xFFB6C5D1)
)

private val LightScheme = lightColorScheme(
    primary = Color(0xFF006B56),
    onPrimary = Color.White,
    secondary = Color(0xFF315F9B),
    tertiary = Color(0xFF805600),
    background = Color(0xFFF4F7F8),
    onBackground = Color(0xFF101820),
    surface = Color(0xFFFFFFFF),
    onSurface = Color(0xFF101820),
    surfaceVariant = Color(0xFFE5ECEF),
    onSurfaceVariant = Color(0xFF45545E)
)

@Composable
fun OptimizerTheme(mode: ThemeMode, content: @Composable () -> Unit) {
    val dark = when (mode) {
        ThemeMode.SYSTEM -> isSystemInDarkTheme()
        ThemeMode.DARK -> true
        ThemeMode.LIGHT -> false
    }
    MaterialTheme(colorScheme = if (dark) DarkScheme else LightScheme, content = content)
}
