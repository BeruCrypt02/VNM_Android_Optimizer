package com.mkvenompro.optimizer

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import com.mkvenompro.optimizer.ui.OptimizerApp
import com.mkvenompro.optimizer.ui.theme.OptimizerTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { OptimizerTheme { OptimizerApp() } }
    }
}
