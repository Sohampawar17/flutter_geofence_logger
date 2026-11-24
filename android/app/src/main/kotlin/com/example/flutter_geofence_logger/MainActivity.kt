package com.geopulse.geofence_logger

import android.content.Context
import android.content.Intent
import android.os.PowerManager
import android.provider.Settings
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val channelName = "com.geopulse.geofence_logger/diagnostics"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> {
                    val playServices = GoogleApiAvailability.getInstance()
                        .isGooglePlayServicesAvailable(this)
                    val power = getSystemService(Context.POWER_SERVICE) as PowerManager
                    result.success(mapOf(
                        "googlePlayServicesAvailable" to (playServices == ConnectionResult.SUCCESS),
                        "googlePlayServicesMessage" to GoogleApiAvailability.getInstance()
                            .getErrorString(playServices),
                        "ignoringBatteryOptimizations" to power.isIgnoringBatteryOptimizations(packageName),
                        // WorkManager scheduling is verified through ADB/diagnostics;
                        // do not claim an in-app state that is not synchronously observable.
                        "workManagerState" to "UNKNOWN",
                    ))
                }
                "openBatteryOptimizationSettings" -> {
                    startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NativeSyncBridge.channelName)
            .setMethodCallHandler { call, result -> NativeSyncBridge.handle(this, call, result) }
    }
}
