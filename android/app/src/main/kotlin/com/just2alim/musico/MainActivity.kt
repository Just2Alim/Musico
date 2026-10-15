package com.just2alim.musico

import android.content.Context
import android.os.BatteryManager
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private val channelName = "app.musico/device"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method == "getBatteryLevel") {
                    val manager = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
                    result.success(manager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY))
                } else {
                    result.notImplemented()
                }
            }
    }
}
