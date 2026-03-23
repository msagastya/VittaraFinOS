package com.example.finance_app

import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "com.example.finance_app/secure"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "enableSecure") {
                // FLAG_SECURE disabled — screenshots allowed for dev/personal use
                result.success(true)
            } else if (call.method == "disableSecure") {
                result.success(true)
            } else {
                result.notImplemented()
            }
        }
    }
}