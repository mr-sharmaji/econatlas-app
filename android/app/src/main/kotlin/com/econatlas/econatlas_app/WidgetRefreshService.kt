package com.econatlas.econatlas_app

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.IBinder
import android.os.SystemClock
import android.util.Log
import androidx.core.app.NotificationCompat
import es.antonborri.home_widget.HomeWidgetBackgroundIntent

/**
 * Foreground service that refreshes the home-screen widget every
 * 2 minutes.  Android requires a persistent notification for any
 * service running longer than ~10 seconds in the background.
 *
 * The notification doubles as a glanceable market summary:
 *   Title:  "Nifty 23,840 (-0.87%)"
 *   Body:   "Sensex 76,847 · Gold ₹93,400 · Crude ₹9,336"
 *
 * Updated on every 2-min tick from the widget snapshot data in
 * HomeWidgetPreferences.
 */
class WidgetRefreshService : Service() {

    companion object {
        private const val TAG = "WidgetRefreshSvc"
        private const val CHANNEL_ID = "widget_refresh_channel"
        private const val NOTIFICATION_ID = 9001
        private const val REFRESH_INTERVAL_MS = 2L * 60 * 1000  // 2 minutes
        private const val ACTION_ALARM_TICK = "com.econatlas.econatlas_app.WIDGET_ALARM_TICK"

        fun start(context: Context) {
            val intent = Intent(context, WidgetRefreshService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, WidgetRefreshService::class.java))
        }
    }

    // AlarmManager fires reliably even in doze (setExactAndAllowWhileIdle).
    // Handler.postDelayed gets deferred when the screen is off, causing
    // "Synced 12 min ago" at midnight instead of "Synced just now".
    private val alarmReceiver = object : BroadcastReceiver() {
        override fun onReceive(ctx: Context?, intent: Intent?) {
            if (intent?.action == ACTION_ALARM_TICK) {
                triggerWidgetRefresh()
                scheduleNextAlarm()
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        try {
            createNotificationChannel()
            startForeground(NOTIFICATION_ID, buildNotification())
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(alarmReceiver, IntentFilter(ACTION_ALARM_TICK), RECEIVER_NOT_EXPORTED)
            } else {
                registerReceiver(alarmReceiver, IntentFilter(ACTION_ALARM_TICK))
            }
            Log.i(TAG, "Widget refresh service started")
        } catch (e: Exception) {
            Log.e(TAG, "Service onCreate failed: ${e.message}", e)
            stopSelf()
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        try {
            triggerWidgetRefresh()
            scheduleNextAlarm()
        } catch (e: Exception) {
            Log.e(TAG, "onStartCommand failed: ${e.message}", e)
        }
        return START_STICKY
    }

    override fun onDestroy() {
        cancelAlarm()
        try { unregisterReceiver(alarmReceiver) } catch (_: Exception) {}
        Log.i(TAG, "Widget refresh service stopped")
        super.onDestroy()
    }

    private fun scheduleNextAlarm() {
        try {
            val am = getSystemService(AlarmManager::class.java) ?: return
            // Android 12+ requires SCHEDULE_EXACT_ALARM permission.
            // If not granted, fall back to inexact alarm.
            val pi = PendingIntent.getBroadcast(
                this, NOTIFICATION_ID,
                Intent(ACTION_ALARM_TICK),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            val trigger = SystemClock.elapsedRealtime() + REFRESH_INTERVAL_MS
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (am.canScheduleExactAlarms()) {
                    am.setExactAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, trigger, pi)
                } else {
                    // Fallback: inexact alarm (may be batched by OS)
                    am.set(AlarmManager.ELAPSED_REALTIME_WAKEUP, trigger, pi)
                }
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                am.setExactAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, trigger, pi)
            } else {
                am.setExact(AlarmManager.ELAPSED_REALTIME_WAKEUP, trigger, pi)
            }
        } catch (e: Exception) {
            Log.w(TAG, "AlarmManager scheduling failed, using Handler fallback: ${e.message}")
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                triggerWidgetRefresh()
                scheduleNextAlarm()
            }, REFRESH_INTERVAL_MS)
        }
    }

    private fun cancelAlarm() {
        val am = getSystemService(AlarmManager::class.java) ?: return
        val pi = PendingIntent.getBroadcast(
            this, NOTIFICATION_ID,
            Intent(ACTION_ALARM_TICK),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        am.cancel(pi)
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private var _lastSyncMs: Long = 0L

    private fun triggerWidgetRefresh() {
        try {
            val bgIntent = HomeWidgetBackgroundIntent.getBroadcast(
                this,
                android.net.Uri.parse("econatlas://refresh"),
            )
            bgIntent.send()

            // Mark the actual sync time
            _lastSyncMs = System.currentTimeMillis()

            // Update the notification
            val nm = getSystemService(NotificationManager::class.java)
            nm?.notify(NOTIFICATION_ID, buildNotification())

            Log.d(TAG, "Widget refresh triggered")
        } catch (e: Exception) {
            Log.w(TAG, "Widget refresh trigger failed: ${e.message}")
        }
    }

    private fun buildNotification(): Notification {
        val syncText = if (_lastSyncMs == 0L) {
            "Starting sync..."
        } else {
            val elapsed = (System.currentTimeMillis() - _lastSyncMs) / 1000
            when {
                elapsed < 60 -> "Synced just now"
                elapsed < 3600 -> "Synced ${elapsed / 60} min ago"
                else -> {
                    // Show absolute time instead of vague "Nh ago"
                    val fmt = java.text.SimpleDateFormat("h:mm a", java.util.Locale.getDefault())
                    "Last sync ${fmt.format(java.util.Date(_lastSyncMs))}"
                }
            }
        }

        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Market Sync Active")
            .setContentText(syncText)
            .setOngoing(true)
            .setSilent(true)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setWhen(_lastSyncMs.takeIf { it > 0 } ?: System.currentTimeMillis())
            .setShowWhen(true)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Market Widget Sync",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Keeps market data fresh for the home-screen widget"
                setShowBadge(false)
            }
            val nm = getSystemService(NotificationManager::class.java)
            nm?.createNotificationChannel(channel)
        }
    }

    private fun parseNiftyLine(@Suppress("UNUSED_PARAMETER") raw: String?): String {
        return "Market Sync Active"
    }
}
