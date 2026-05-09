package com.vittara.finos

import android.os.Bundle
import android.view.KeyEvent
import android.view.WindowManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val aiButtonChannel = "com.vittara.finos/ai_button"
    private var methodChannel: MethodChannel? = null
    private var lastVolumeDownAt = 0L
    private val doublePressWindowMs = 450L

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Finance app default: block screenshots and screen recording.
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            aiButtonChannel
        )
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (event.keyCode == KeyEvent.KEYCODE_VOLUME_DOWN &&
            event.action == KeyEvent.ACTION_DOWN &&
            event.repeatCount == 0
        ) {
            val now = System.currentTimeMillis()
            if (now - lastVolumeDownAt <= doublePressWindowMs) {
                lastVolumeDownAt = 0L
                methodChannel?.invokeMethod("volumeDownDoublePress", null)
                return true
            }
            lastVolumeDownAt = now
        }
        return super.dispatchKeyEvent(event)
    }
}
