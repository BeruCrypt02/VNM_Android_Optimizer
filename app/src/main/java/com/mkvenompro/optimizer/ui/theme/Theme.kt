package com.mkvenompro.optimizer.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val NeonScheme = darkColorScheme(
    primary = Color(0xFF48E5C2),
    secondary = Color(0xFF72A7FF),
    tertiary = Color(0xFFFFC857),
    background = Color(0xFF080D13),
    surface = Color(0xFF111A24),
    surfaceVariant = Color(0xFF1B2937)
)

@Composable
fun OptimizerTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = NeonScheme, content = content)
}
