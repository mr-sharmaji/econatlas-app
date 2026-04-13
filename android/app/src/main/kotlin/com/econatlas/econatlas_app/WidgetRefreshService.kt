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
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
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

    // WakeLock + Handler: holds a partial wake lock so the CPU stays
    // awake and Handler.postDelayed fires exactly every 2 minutes,
    // even with screen off / doze. AlarmManager was limited to 1
    // exact alarm per 9 min in doze — too slow for live markets.
    private var wakeLock: PowerManager.WakeLock? = null
    private val handler = Handler(Looper.getMainLooper())
    private val refreshRunnable = object : Runnable {
        override fun run() {
            triggerWidgetRefresh()
            handler.postDelayed(this, REFRESH_INTERVAL_MS)
        }
    }

    override fun onCreate() {
        super.onCreate()
        try {
            createNotificationChannel()
            startForeground(NOTIFICATION_ID, buildNotification())

            // Acquire partial WakeLock — keeps CPU running but
            // allows screen to turn off. Released in onDestroy.
            val pm = getSystemService(PowerManager::class.java)
            wakeLock = pm?.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "EconAtlas::WidgetRefresh",
            )?.apply { acquire() }

            Log.i(TAG, "Service started — WakeLock acquired, first refresh now")
            triggerWidgetRefresh()
            handler.postDelayed(refreshRunnable, REFRESH_INTERVAL_MS)
        } catch (e: Exception) {
            Log.e(TAG, "Service onCreate failed: ${e.message}", e)
            stopSelf()
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // No-op — handler already running from onCreate.
        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(refreshRunnable)
        try {
            wakeLock?.let { if (it.isHeld) it.release() }
        } catch (_: Exception) {}
        wakeLock = null
        Log.i(TAG, "Service destroyed — WakeLock released")
        super.onDestroy()
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
        val syncText: String? = null  // no subtitle

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
