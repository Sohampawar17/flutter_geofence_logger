package com.geopulse.geofence_logger

import android.content.Context
import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URLEncoder
import java.net.URL
import java.time.Instant
import java.util.concurrent.TimeUnit
import javax.net.ssl.HttpsURLConnection

object NativeSyncBridge {
    const val channelName = "com.geopulse.geofence_logger/background"
    private const val oneOffName = "geopulse-sync"
    private const val periodicName = "geopulse-periodic-sync"

    private fun preferences(context: Context) = EncryptedSharedPreferences.create(
        context,
        "geopulse_secure_api",
        MasterKey.Builder(context).setKeyScheme(MasterKey.KeyScheme.AES256_GCM).build(),
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
    )

    fun handle(context: Context, call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "initializeSync" -> {
                    schedulePeriodic(context)
                    enqueue(context)
                    result.success(null)
                }
                "enqueueSync" -> {
                    enqueue(context)
                    result.success(null)
                }
                "readApiCredentials" -> {
                    val prefs = preferences(context)
                    result.success(mapOf(
                        "baseUrl" to (prefs.getString("baseUrl", "") ?: ""),
                        "apiKey" to (prefs.getString("apiKey", "") ?: ""),
                        "apiSecret" to (prefs.getString("apiSecret", "") ?: ""),
                    ))
                }
                "writeApiCredentials" -> {
                    val baseUrl = call.argument<String>("baseUrl")?.trim()?.trimEnd('/') ?: ""
                    if (!baseUrl.startsWith("https://")) {
                        result.error("invalid_url", "Only HTTPS Frappe URLs are accepted", null)
                        return
                    }
                    preferences(context).edit()
                        .putString("baseUrl", baseUrl)
                        .putString("apiKey", call.argument<String>("apiKey") ?: "")
                        .putString("apiSecret", call.argument<String>("apiSecret") ?: "")
                        .apply()
                    result.success(null)
                }
                "clearApiCredentials" -> {
                    preferences(context).edit()
                        .remove("baseUrl")
                        .remove("apiKey")
                        .remove("apiSecret")
                        .apply()
                    result.success(null)
                }
                "readEmployeeSession" -> {
                    val prefs = preferences(context)
                    result.success(mapOf(
                        "baseUrl" to (prefs.getString("employeeBaseUrl", "") ?: ""),
                        "apiKey" to (prefs.getString("employeeApiKey", "") ?: ""),
                        "apiSecret" to (prefs.getString("employeeApiSecret", "") ?: ""),
                        "employeeName" to (prefs.getString("employeeName", "") ?: ""),
                        "employeeId" to (prefs.getString("employeeId", "") ?: ""),
                        "designation" to (prefs.getString("employeeDesignation", "") ?: ""),
                        "dateOfJoining" to (prefs.getString("employeeDateOfJoining", "") ?: ""),
                        "dateOfBirth" to (prefs.getString("employeeDateOfBirth", "") ?: ""),
                        "gender" to (prefs.getString("employeeGender", "") ?: ""),
                        "companyEmail" to (prefs.getString("employeeCompanyEmail", "") ?: ""),
                        "personalEmail" to (prefs.getString("employeePersonalEmail", "") ?: ""),
                        "cellNumber" to (prefs.getString("employeeCellNumber", "") ?: ""),
                        "emergencyPhoneNumber" to (prefs.getString("employeeEmergencyPhone", "") ?: ""),
                        "employeeImage" to (prefs.getString("employeeImage", "") ?: ""),
                    ))
                }
                "writeEmployeeSession" -> {
                    preferences(context).edit()
                        .putString("employeeBaseUrl", call.argument<String>("baseUrl") ?: "")
                        .putString("employeeApiKey", call.argument<String>("apiKey") ?: "")
                        .putString("employeeApiSecret", call.argument<String>("apiSecret") ?: "")
                        .putString("employeeName", call.argument<String>("employeeName") ?: "")
                        .putString("employeeId", call.argument<String>("employeeId") ?: "")
                        .putString("employeeDesignation", call.argument<String>("designation") ?: "")
                        .putString("employeeDateOfJoining", call.argument<String>("dateOfJoining") ?: "")
                        .putString("employeeDateOfBirth", call.argument<String>("dateOfBirth") ?: "")
                        .putString("employeeGender", call.argument<String>("gender") ?: "")
                        .putString("employeeCompanyEmail", call.argument<String>("companyEmail") ?: "")
                        .putString("employeePersonalEmail", call.argument<String>("personalEmail") ?: "")
                        .putString("employeeCellNumber", call.argument<String>("cellNumber") ?: "")
                        .putString("employeeEmergencyPhone", call.argument<String>("emergencyPhoneNumber") ?: "")
                        .putString("employeeImage", call.argument<String>("employeeImage") ?: "")
                        .apply()
                    result.success(null)
                }
                "clearEmployeeSession" -> {
                    preferences(context).edit()
                        .remove("employeeBaseUrl").remove("employeeSid")
                        .remove("employeeApiKey").remove("employeeApiSecret")
                        .remove("employeeName").remove("employeeId")
                        .remove("employeeDesignation").remove("employeeDateOfJoining")
                        .remove("employeeDateOfBirth").remove("employeeGender")
                        .remove("employeeCompanyEmail").remove("employeePersonalEmail")
                        .remove("employeeCellNumber").remove("employeeEmergencyPhone")
                        .remove("employeeImage").apply()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (error: Exception) {
            result.error("native_sync", error.message, null)
        }
    }

    private fun constraints() = Constraints.Builder()
        .setRequiredNetworkType(NetworkType.CONNECTED)
        .setRequiresStorageNotLow(true)
        .build()

    fun schedulePeriodic(context: Context) {
        val request = PeriodicWorkRequestBuilder<GeofenceSyncWorker>(15, TimeUnit.MINUTES)
            .setConstraints(constraints())
            .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 10, TimeUnit.MINUTES)
            .build()
        WorkManager.getInstance(context).enqueueUniquePeriodicWork(
            periodicName, ExistingPeriodicWorkPolicy.KEEP, request,
        )
    }

    fun enqueue(context: Context) {
        val request = OneTimeWorkRequestBuilder<GeofenceSyncWorker>()
            .setConstraints(constraints())
            .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 10, TimeUnit.MINUTES)
            .build()
        // A fresh app/manual request must not remain stuck behind an older
        // worker's long retry backoff after credentials or payloads are fixed.
        WorkManager.getInstance(context).enqueueUniqueWork(oneOffName, ExistingWorkPolicy.REPLACE, request)
    }
}

class GeofenceSyncWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        val prefs = EncryptedSharedPreferences.create(
            applicationContext,
            "geopulse_secure_api",
            MasterKey.Builder(applicationContext).setKeyScheme(MasterKey.KeyScheme.AES256_GCM).build(),
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
        )
        val baseUrl = prefs.getString("baseUrl", "")?.trimEnd('/') ?: ""
        val apiKey = prefs.getString("apiKey", "") ?: ""
        val apiSecret = prefs.getString("apiSecret", "") ?: ""
        if (!baseUrl.startsWith("https://") || apiKey.isBlank() || apiSecret.isBlank()) {
            return@withContext Result.success()
        }
        val file = applicationContext.getDatabasePath("geofence_events.db")
        if (!file.exists()) return@withContext Result.success()
        val db = SQLiteDatabase.openDatabase(file.path, null, SQLiteDatabase.OPEN_READWRITE)
        var claimedEvents: JSONArray? = null
        try {
            if (!tableExists(db, "geofence_events")) return@withContext Result.success()
            ensureSyncLeaseColumn(db)
            val events = claim(db)
            claimedEvents = events
            if (events.length() == 0) return@withContext Result.success()
            val connection = URL("$baseUrl/api/method/geofence_logger.api.ingest_events")
                .openConnection() as HttpsURLConnection
            try {
                connection.requestMethod = "POST"
                connection.connectTimeout = 15_000
                connection.readTimeout = 30_000
                connection.doOutput = true
                connection.setRequestProperty("Authorization", "token $apiKey:$apiSecret")
                connection.setRequestProperty("Content-Type", "application/x-www-form-urlencoded")
                val form = "events=${URLEncoder.encode(events.toString(), "UTF-8")}" 
                connection.outputStream.use { it.write(form.toByteArray()) }
                val code = connection.responseCode
                if (code == HttpURLConnection.HTTP_UNAUTHORIZED || code == HttpURLConnection.HTTP_FORBIDDEN) {
                    // Credentials can be refreshed by a later employee login. Keep
                    // the exact events eligible for that explicit recovery path,
                    // but do not spin indefinitely with known-invalid credentials.
                    release(db, "temporary: authentication rejected", events)
                    return@withContext Result.failure()
                }
                if (code !in 200..299) {
                    release(db, "temporary: HTTP $code", events)
                    return@withContext if (runAttemptCount < 8) Result.retry() else Result.failure()
                }
                val root = JSONObject(connection.inputStream.bufferedReader().use { it.readText() })
                val body = root.optJSONObject("message") ?: root
                val results = body.optJSONArray("results") ?: JSONArray()
                acknowledge(db, events, results)
                Result.success()
            } finally {
                connection.disconnect()
            }
        } catch (error: Exception) {
            // Only release the rows owned by this worker. Another foreground
            // sync may legitimately own different SYNCING rows.
            release(db, "temporary: ${error.javaClass.simpleName}", claimedEvents)
            if (runAttemptCount < 8) Result.retry() else Result.failure()
        } finally {
            db.close()
        }
    }

    private fun tableExists(db: SQLiteDatabase, table: String): Boolean =
        db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name=?", arrayOf(table)).use { it.moveToFirst() }

    private fun ensureSyncLeaseColumn(db: SQLiteDatabase) {
        val exists = db.rawQuery("PRAGMA table_info(geofence_events)", null).use { cursor ->
            var found = false
            while (cursor.moveToNext()) {
                if (cursor.getString(cursor.getColumnIndexOrThrow("name")) == "sync_started_at") {
                    found = true
                    break
                }
            }
            found
        }
        if (!exists) {
            db.execSQL("ALTER TABLE geofence_events ADD COLUMN sync_started_at TEXT")
        }
    }

    private fun claim(db: SQLiteDatabase): JSONArray {
        val rows = JSONArray()
        val ids = mutableListOf<String>()
        db.beginTransaction()
        try {
            val now = Instant.now().toString()
            val stale = Instant.now().minusSeconds(15 * 60).toString()
            db.execSQL("UPDATE geofence_events SET sync_status='failed',sync_started_at=NULL,last_error='temporary: recovered interrupted synchronization' WHERE sync_status='syncing' AND (sync_started_at IS NULL OR sync_started_at<?)", arrayOf(stale))
            val payloadColumns = "event_id,geofence_id,event_type,event_timestamp,latitude,longitude,accuracy_meters,radius_meters,distance_from_center_meters,battery_percentage,charging_status,network_type,internet_available,device_id,android_version,device_manufacturer,device_model,background_event,created_at"
            db.rawQuery("SELECT $payloadColumns FROM geofence_events WHERE sync_status='pending' OR (sync_status='failed' AND last_error LIKE 'temporary:%') ORDER BY event_timestamp LIMIT 50", null).use { cursor ->
                while (cursor.moveToNext()) {
                    val item = JSONObject()
                    for (i in 0 until cursor.columnCount) item.put(cursor.getColumnName(i), cursorValue(cursor, i))
                    rows.put(item)
                    ids.add(item.getString("event_id"))
                }
            }
            ids.forEach { db.execSQL("UPDATE geofence_events SET sync_status='syncing',sync_started_at=? WHERE event_id=?", arrayOf(now, it)) }
            db.setTransactionSuccessful()
        } finally { db.endTransaction() }
        return rows
    }

    private fun cursorValue(cursor: Cursor, index: Int): Any? = when (cursor.getType(index)) {
        Cursor.FIELD_TYPE_INTEGER -> cursor.getLong(index)
        Cursor.FIELD_TYPE_FLOAT -> cursor.getDouble(index)
        Cursor.FIELD_TYPE_STRING -> cursor.getString(index)
        Cursor.FIELD_TYPE_BLOB -> null
        else -> JSONObject.NULL
    }

    private fun acknowledge(db: SQLiteDatabase, sent: JSONArray, results: JSONArray) {
        val acknowledged = mutableSetOf<String>()
        db.beginTransaction()
        try {
            for (i in 0 until results.length()) {
                val row = results.getJSONObject(i)
                val id = row.optString("event_id")
                acknowledged.add(id)
                if (row.optBoolean("accepted") || row.optBoolean("duplicate")) {
                    val serverTime = row.optString("server_received_at").takeIf { it.isNotBlank() }
                        ?: Instant.now().toString()
                    db.execSQL("UPDATE geofence_events SET sync_status='synced',sync_started_at=NULL,last_error=NULL,synced_at=? WHERE event_id=?", arrayOf(serverTime, id))
                } else {
                    val retryable = row.optBoolean("retryable")
                    db.execSQL("UPDATE geofence_events SET sync_status='failed',sync_started_at=NULL,retry_count=retry_count+1,last_error=? WHERE event_id=?",
                        arrayOf("${if (retryable) "temporary" else "permanent"}: ${row.optString("error").take(250)}", id))
                }
            }
            for (i in 0 until sent.length()) {
                val id = sent.getJSONObject(i).getString("event_id")
                if (!acknowledged.contains(id)) db.execSQL("UPDATE geofence_events SET sync_status='failed',sync_started_at=NULL,retry_count=retry_count+1,last_error='temporary: missing acknowledgement' WHERE event_id=?", arrayOf(id))
            }
            db.setTransactionSuccessful()
        } finally { db.endTransaction() }
    }

    private fun release(db: SQLiteDatabase, reason: String, events: JSONArray?) {
        if (!db.isOpen) return
        if (events == null) return
        for (i in 0 until events.length()) {
            val id = events.getJSONObject(i).optString("event_id")
            if (id.isNotBlank()) {
                db.execSQL("UPDATE geofence_events SET sync_status='failed',sync_started_at=NULL,retry_count=retry_count+1,last_error=? WHERE sync_status='syncing' AND event_id=?", arrayOf(reason.take(300), id))
            }
        }
    }
}
