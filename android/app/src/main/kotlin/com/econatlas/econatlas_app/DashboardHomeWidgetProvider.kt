package com.econatlas.econatlas_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONObject

class DashboardHomeWidgetProvider : HomeWidgetProvider() {

  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    val snapshot = DashboardWidgetHeaderSnapshot.from(widgetData)

    appWidgetIds.forEach { widgetId ->
      val serviceIntent =
          Intent(context, DashboardHomeWidgetRemoteViewsService::class.java).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
          }

      val views =
          RemoteViews(context.packageName, R.layout.dashboard_home_widget).apply {
            setTextViewText(R.id.widget_title, snapshot.title)
            setTextViewText(R.id.widget_subtitle, snapshot.subtitle)
            setTextViewText(R.id.widget_empty, snapshot.emptyMessage)

            setOnClickPendingIntent(
                R.id.widget_header,
                HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse(snapshot.launchRoute),
                ),
            )
            setOnClickPendingIntent(
                R.id.widget_refresh,
                HomeWidgetBackgroundIntent.getBroadcast(
                    context,
                    Uri.parse("econatlas://refresh"),
                ),
            )

            setRemoteAdapter(R.id.widget_list, serviceIntent)
            setEmptyView(R.id.widget_list, R.id.widget_empty)
            setPendingIntentTemplate(
                R.id.widget_list,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
            )
          }

      appWidgetManager.updateAppWidget(widgetId, views)
    }

    appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetIds, R.id.widget_list)
  }
}

private data class DashboardWidgetHeaderSnapshot(
    val title: String,
    val subtitle: String,
    val launchRoute: String,
    val emptyMessage: String,
) {
  companion object {
    private const val SNAPSHOT_KEY = "dashboard_widget_snapshot"

    fun from(prefs: SharedPreferences): DashboardWidgetHeaderSnapshot {
      val raw = prefs.getString(SNAPSHOT_KEY, null)
      if (raw.isNullOrBlank()) {
        return DashboardWidgetHeaderSnapshot(
            title = "EconAtlas Watchlist",
            subtitle = "Open the app to populate your home widget",
            launchRoute = "econatlas:///dashboard",
            emptyMessage = "Add watchlist items and favorites in the app.",
        )
      }

      return try {
        val json = JSONObject(raw)
        DashboardWidgetHeaderSnapshot(
            title = json.optString("title", "EconAtlas Watchlist"),
            subtitle = json.optString("subtitle", "Last refreshed recently"),
            launchRoute = json.optString("launchRoute", "econatlas:///dashboard"),
            emptyMessage = if ((json.optJSONArray("items")?.length() ?: 0) == 0) {
              "Add watchlist items and favorites in the app."
            } else {
              "No items yet"
            },
        )
      } catch (_: Exception) {
        DashboardWidgetHeaderSnapshot(
            title = "EconAtlas Watchlist",
            subtitle = "Open the app to populate your home widget",
            launchRoute = "econatlas:///dashboard",
            emptyMessage = "Add watchlist items and favorites in the app.",
        )
      }
    }
  }
}
