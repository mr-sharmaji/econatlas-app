package com.econatlas.econatlas_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONObject

/**
 * Home-screen watchlist widget.
 *
 * Renders 3 tabs (Markets / Stocks / Funds) as a horizontal pill row
 * in the header. Tapping a tab broadcasts a [ACTION_SELECT_TAB]
 * intent back into this provider which persists the selection in
 * SharedPreferences and triggers a re-render + data reload — the
 * [DashboardHomeWidgetRemoteViewsService] reads the active tab in
 * onDataSetChanged() and returns only that section's rows.
 *
 * The underlying snapshot JSON (produced by the Flutter
 * DashboardHomeWidgetService) is the single source of truth; we
 * never fetch on the Kotlin side. This keeps the widget purely
 * presentational and avoids duplicate API clients in two languages.
 */
class DashboardHomeWidgetProvider : HomeWidgetProvider() {

  companion object {
    const val ACTION_SELECT_TAB =
        "com.econatlas.econatlas_app.WIDGET_SELECT_TAB"
    const val EXTRA_TAB = "tab"
    const val PREF_ACTIVE_TAB = "dashboard_widget_active_tab"
    // Valid tab keys mirrored by the RemoteViewsFactory.
    const val TAB_MARKETS = "markets"
    const val TAB_STOCKS = "stocks"
    const val TAB_MFS = "mfs"
  }

  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    val snapshot = DashboardWidgetHeaderSnapshot.from(widgetData)
    val activeTab = widgetData.getString(PREF_ACTIVE_TAB, TAB_MARKETS) ?: TAB_MARKETS

    appWidgetIds.forEach { widgetId ->
      val serviceIntent =
          Intent(context, DashboardHomeWidgetRemoteViewsService::class.java).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            // Force RemoteViews to treat each intent as unique so
            // the factory rebuilds its list when we change tabs.
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

            // --- Tab buttons ---
            applyTabState(context, this, R.id.widget_tab_markets, TAB_MARKETS, activeTab, widgetId)
            applyTabState(context, this, R.id.widget_tab_stocks, TAB_STOCKS, activeTab, widgetId)
            applyTabState(context, this, R.id.widget_tab_mfs, TAB_MFS, activeTab, widgetId)

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

  /**
   * Set a tab's background + text colour to the selected or
   * unselected state, and wire its click to a pending intent that
   * broadcasts [ACTION_SELECT_TAB] back to this provider.
   */
  private fun applyTabState(
      context: Context,
      views: RemoteViews,
      viewId: Int,
      tabKey: String,
      activeTab: String,
      widgetId: Int,
  ) {
    val isActive = activeTab == tabKey
    views.setInt(
        viewId,
        "setBackgroundResource",
        if (isActive) {
          R.drawable.dashboard_home_widget_tab_bg_selected
        } else {
          R.drawable.dashboard_home_widget_tab_bg
        },
    )
    views.setTextColor(
        viewId,
        if (isActive) Color.WHITE else 0xFFB8C5D6.toInt(),
    )

    val intent =
        Intent(context, DashboardHomeWidgetProvider::class.java).apply {
          action = ACTION_SELECT_TAB
          putExtra(EXTRA_TAB, tabKey)
          putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
          // Unique data per (widget, tab) so the PendingIntent
          // doesn't collide with the others.
          data = Uri.parse("econatlas://widget/$widgetId/tab/$tabKey")
        }
    val pi =
        PendingIntent.getBroadcast(
            context,
            widgetId * 10 + tabKey.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    views.setOnClickPendingIntent(viewId, pi)
  }

  override fun onReceive(context: Context, intent: Intent) {
    super.onReceive(context, intent)
    if (intent.action == ACTION_SELECT_TAB) {
      val tab = intent.getStringExtra(EXTRA_TAB) ?: return
      val prefs =
          context.getSharedPreferences(
              "HomeWidgetPreferences",
              Context.MODE_PRIVATE,
          )
      prefs.edit().putString(PREF_ACTIVE_TAB, tab).apply()

      val manager = AppWidgetManager.getInstance(context)
      val ids =
          manager.getAppWidgetIds(
              ComponentName(context, DashboardHomeWidgetProvider::class.java),
          )
      onUpdate(context, manager, ids, prefs)
    }
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
