package com.navoracloudsoft.medibook

import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // The device part of the app's User-Agent (lib/core/network/user_agent.dart),
        // so Signed-in Devices can tell one phone from another.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "medibook/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "describe" -> result.success(
                        mapOf(
                            "manufacturer" to Build.MANUFACTURER,
                            "model" to Build.MODEL,
                            "os" to "Android",
                            "osVersion" to Build.VERSION.RELEASE,
                        ),
                    )
                    else -> result.notImplemented()
                }
            }
    }
}
