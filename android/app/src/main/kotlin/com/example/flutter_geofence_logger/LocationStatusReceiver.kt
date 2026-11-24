package com.geopulse.geofence_logger

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.location.LocationManager
import android.os.Build
import androidx.core.app.NotificationCompat

class LocationStatusReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val manager = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val locationEnabled = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            manager.isLocationEnabled
        } else {
            manager.isProviderEnabled(LocationManager.GPS_PROVIDER) ||
                manager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
        }
        if (locationEnabled) return
        val notifications = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            notifications.createNotificationChannel(NotificationChannel(
                "monitoring_alerts", "Attendance monitoring alerts", NotificationManager.IMPORTANCE_HIGH
            ).apply { description = "Alerts when attendance location requirements are disabled" })
        }
        val settings = Intent(android.provider.Settings.ACTION_LOCATION_SOURCE_SETTINGS)
        val pending = PendingIntent.getActivity(
            context, 91, settings,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        notifications.notify(9101, NotificationCompat.Builder(context, "monitoring_alerts")
            .setSmallIcon(context.applicationInfo.icon)
            .setContentTitle("Location is turned off")
            .setContentText("Turn on Location to record Check In or Check Out.")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pending)
            .build())
    }
}
