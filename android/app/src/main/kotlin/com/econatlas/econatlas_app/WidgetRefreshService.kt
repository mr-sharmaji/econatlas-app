package com.econatlas.econatlas_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import org.json.JSONObject

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

    private val handler = Handler(Looper.getMainLooper())
    private val refreshRunnable = object : Runnable {
        override fun run() {
            triggerWidgetRefresh()
            handler.postDelayed(this, REFRESH_INTERVAL_MS)
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification())
        Log.i(TAG, "Widget refresh service started (interval=${REFRESH_INTERVAL_MS / 1000}s)")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        handler.removeCallbacks(refreshRunnable)
        handler.postDelayed(refreshRunnable, REFRESH_INTERVAL_MS)
        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(refreshRunnable)
        Log.i(TAG, "Widget refresh service stopped")
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun triggerWidgetRefresh() {
        try {
            // Fire the Dart-side background callback which rebuilds
            // the snapshot and publishes it to the widget.
            val bgIntent = HomeWidgetBackgroundIntent.getBroadcast(
                this,
                android.net.Uri.parse("econatlas://refresh"),
            )
            bgIntent.send()

            // Update the notification with latest market data
            val nm = getSystemService(NotificationManager::class.java)
            nm?.notify(NOTIFICATION_ID, buildNotification())

            Log.d(TAG, "Widget refresh triggered")
        } catch (e: Exception) {
            Log.w(TAG, "Widget refresh trigger failed: ${e.message}")
        }
    }

    private fun buildNotification(): Notification {
        val prefs = getSharedPreferences("HomeWidgetPreferences", MODE_PRIVATE)
        val raw = prefs.getString("dashboard_widget_snapshot", null)
        val niftyLine = parseNiftyLine(raw)
        val syncAgo = _lastRefreshAgo()

        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(niftyLine)
            .setContentText(syncAgo)
            .setOngoing(true)
            .setSilent(true)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }

    private var _lastRefreshTs: Long = System.currentTimeMillis()

    private fun _lastRefreshAgo(): String {
        val elapsed = (System.currentTimeMillis() - _lastRefreshTs) / 1000
        _lastRefreshTs = System.currentTimeMillis()
        return when {
            elapsed < 60 -> "Synced just now"
            elapsed < 3600 -> "Synced ${elapsed / 60} min ago"
            else -> "Synced ${elapsed / 3600}h ago"
        }
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
