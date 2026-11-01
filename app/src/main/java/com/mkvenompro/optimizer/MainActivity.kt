package com.mkvenompro.optimizer

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.mkvenompro.optimizer.ui.OptimizerApp
import com.mkvenompro.optimizer.ui.theme.OptimizerTheme
import com.mkvenompro.optimizer.ui.theme.ThemeMode

class MainActivity : ComponentActivity() {
    private val preferences by lazy { getSharedPreferences("optimizer_preferences", MODE_PRIVATE) }
    private var themeMode by mutableStateOf(ThemeMode.SYSTEM)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Load the saved mode before the first Compose frame to avoid a white/dark flash.
        themeMode = runCatching {
            ThemeMode.valueOf(preferences.getString("theme_mode", "SYSTEM") ?: "SYSTEM")
        }.getOrDefault(ThemeMode.SYSTEM)
        setContent {
            OptimizerTheme(themeMode) {
                OptimizerApp(
                    themeMode = themeMode,
                    onThemeModeChange = { mode ->
                        themeMode = mode
                        preferences.edit().putString("theme_mode", mode.name).apply()
                    }
                )
            }
        }
    }
}
