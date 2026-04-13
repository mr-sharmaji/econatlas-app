package com.econatlas.econatlas_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.net.Uri
import android.view.View
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
    const val ACTION_REFRESH_START =
        "com.econatlas.econatlas_app.WIDGET_REFRESH_START"
    const val EXTRA_TAB = "tab"
    const val PREF_ACTIVE_TAB = "dashboard_widget_active_tab"
    const val PREF_REFRESHING = "dashboard_widget_refreshing"
    // One-shot flag set by ACTION_SELECT_TAB and consumed by the
    // very next onUpdate so the animated layout variant is used
    // only for tab switches. Refresh / periodic update / boot all
    // render via the noanim layout so the list doesn't re-animate
    // every time the Dart side republishes a snapshot.
    const val PREF_ANIMATE_NEXT = "dashboard_widget_animate_next"
    // Valid tab keys mirrored by the RemoteViewsFactory.
    const val TAB_MARKETS = "markets"
    const val TAB_STOCKS = "stocks"
    const val TAB_MFS = "mfs"
  }

  override fun onEnabled(context: Context) {
    super.onEnabled(context)
    try {
      WidgetRefreshService.start(context)
    } catch (e: Exception) {
      android.util.Log.w("WidgetProvider", "Service start failed: ${e.message}")
    }
  }

  override fun onDisabled(context: Context) {
    // Last widget removed — stop the refresh service.
    WidgetRefreshService.stop(context)
    super.onDisabled(context)
  }

  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    // Ensure the foreground service is running. Safe to call
    // repeatedly — onStartCommand only schedules the next alarm,
    // it does NOT trigger an immediate refresh (which would loop).
    try {
      WidgetRefreshService.start(context)
    } catch (_: Exception) { /* best-effort */ }
    _onUpdateImpl(context, appWidgetManager, appWidgetIds, widgetData)
  }

  private fun _onUpdateImpl(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    val snapshot = DashboardWidgetHeaderSnapshot.from(widgetData)
    val activeTab = widgetData.getString(PREF_ACTIVE_TAB, TAB_MARKETS) ?: TAB_MARKETS
    val isRefreshing = widgetData.getBoolean(PREF_REFRESHING, false)
    // Consume the animate-once flag so the layoutAnimation plays
    // exactly once — on the redraw that follows the tab tap.
    val animateNext = widgetData.getBoolean(PREF_ANIMATE_NEXT, false)
    if (animateNext) {
      widgetData.edit().putBoolean(PREF_ANIMATE_NEXT, false).apply()
    }
    val layoutId = if (animateNext) {
      R.layout.dashboard_home_widget
    } else {
      R.layout.dashboard_home_widget_noanim
    }

    appWidgetIds.forEach { widgetId ->
      val serviceIntent =
          Intent(context, DashboardHomeWidgetRemoteViewsService::class.java).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            // Force RemoteViews to treat each intent as unique so
            // the factory rebuilds its list when we change tabs.
            data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
          }

      val views =
          RemoteViews(context.packageName, layoutId).apply {
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
            // Refresh button: routes through our own
            // ACTION_REFRESH_START broadcast so we can set the
            // refreshing flag, swap in the spinner view, and THEN
            // fire the HomeWidget background intent that actually
            // triggers the Dart refresh pipeline. onUpdate running
            // again after publish() resets the flag + visibility.
            val refreshIntent = Intent(
                context,
                DashboardHomeWidgetProvider::class.java,
            ).apply {
              action = ACTION_REFRESH_START
              data = Uri.parse("econatlas://widget/$widgetId/refresh")
            }
            val refreshPi = PendingIntent.getBroadcast(
                context,
                widgetId * 10 + "refresh".hashCode(),
                refreshIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or
                    PendingIntent.FLAG_IMMUTABLE,
            )
            setOnClickPendingIntent(R.id.widget_refresh, refreshPi)
            setOnClickPendingIntent(
                R.id.widget_refresh_spinner,
                refreshPi,
            )

            // Visibility swap: while a refresh is in flight we show
            // the indeterminate ProgressBar in place of the Refresh
            // button.
            setViewVisibility(
                R.id.widget_refresh,
                if (isRefreshing) View.GONE else View.VISIBLE,
            )
            setViewVisibility(
                R.id.widget_refresh_spinner,
                if (isRefreshing) View.VISIBLE else View.GONE,
            )

            // --- Tab buttons ---
            applyTabState(context, this, R.id.widget_tab_markets, TAB_MARKETS, activeTab, widgetId)
            applyTabState(context, this, R.id.widget_tab_stocks, TAB_STOCKS, activeTab, widgetId)
            applyTabState(context, this, R.id.widget_tab_mfs, TAB_MFS, activeTab, widgetId)

            setRemoteAdapter(R.id.widget_list, serviceIntent)
            setEmptyView(R.id.widget_list, R.id.widget_empty)
            // IMPORTANT: setPendingIntentTemplate requires the
            // PendingIntent to be MUTABLE on Android 12+ so the
            // framework can merge each row's fill-in intent data
            // URI into the template. HomeWidgetLaunchIntent
            // builds its PendingIntent with FLAG_IMMUTABLE, which
            // silently drops the fill-in URIs and sends every
            // tap to /dashboard instead of the item's detail
            // page. Build the template directly so we control
            // the flags.
            val templateIntent = Intent(
                context,
                MainActivity::class.java,
            ).apply {
              action = "es.antonborri.home_widget.action.LAUNCH"
            }
            val templatePi = PendingIntent.getActivity(
                context,
                widgetId,
                templateIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or
                    PendingIntent.FLAG_MUTABLE,
            )
            setPendingIntentTemplate(R.id.widget_list, templatePi)
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
    // IMPORTANT: for ACTION_APPWIDGET_UPDATE we must clear the
    // refreshing flag BEFORE super.onReceive() dispatches onUpdate,
    // otherwise onUpdate reads the stale `true` value and keeps
    // the spinner visible forever (the button stays GONE and the
    // user sees a permanent loading state). Clearing here and
    // then letting super run fixes the stuck spinner.
    // NOTE: Do NOT auto-start the refresh service here. Every
    // Dart HomeWidget.updateWidget fires ACTION_APPWIDGET_UPDATE
    // → onReceive → start service → triggerWidgetRefresh →
    // Dart publish → ACTION_APPWIDGET_UPDATE → infinite loop.
    // The service starts only from onEnabled (first widget added)
    // and the WorkManager periodic task handles restarts.

    if (intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE) {
      val prefs = context.getSharedPreferences(
          "HomeWidgetPreferences",
          Context.MODE_PRIVATE,
      )
      if (prefs.getBoolean(PREF_REFRESHING, false)) {
        prefs.edit().putBoolean(PREF_REFRESHING, false).apply()
      }
    }
    super.onReceive(context, intent)
    when (intent.action) {
      ACTION_SELECT_TAB -> {
        val tab = intent.getStringExtra(EXTRA_TAB) ?: return
        val prefs = context.getSharedPreferences(
            "HomeWidgetPreferences",
            Context.MODE_PRIVATE,
        )
        prefs.edit()
            .putString(PREF_ACTIVE_TAB, tab)
            .putBoolean(PREF_ANIMATE_NEXT, true)
            .apply()
        redrawAllWidgets(context, prefs)
      }
      ACTION_REFRESH_START -> {
        val prefs = context.getSharedPreferences(
            "HomeWidgetPreferences",
            Context.MODE_PRIVATE,
        )
        // Persist the refreshing flag so the next full redraw
        // (after Dart publishes) is aware, but apply the spinner
        // swap via partiallyUpdateAppWidget — a minimal
        // RemoteViews patch that ONLY flips visibility of the
        // refresh pill and spinner. This avoids calling
        // updateAppWidget/setRemoteAdapter which would rebind
        // the RemoteViewsFactory and flicker the list.
        prefs.edit().putBoolean(PREF_REFRESHING, true).apply()
        applyRefreshingState(context, showSpinner = true)

        // Step 2: kick the Dart side's refresh pipeline via
        // HomeWidget's background intent. This is the same path
        // the old refresh tap used; once it finishes publishing
        // a new snapshot the Dart side calls HomeWidget.updateWidget
        // → our onUpdate runs again and unsets the refreshing flag.
        try {
          val bgIntent = HomeWidgetBackgroundIntent.getBroadcast(
              context,
              Uri.parse("econatlas://refresh"),
          )
          bgIntent.send()
        } catch (_: Exception) {
          // If the background intent fails (pending-intent canceled,
          // killed service, etc.), clear the refreshing flag so the
          // spinner doesn't get stuck on.
          prefs.edit().putBoolean(PREF_REFRESHING, false).apply()
          redrawAllWidgets(context, prefs)
        }
      }
      // ACTION_APPWIDGET_UPDATE is handled above super.onReceive()
      // so the refreshing flag is cleared before onUpdate runs.
    }
  }

  private fun redrawAllWidgets(
      context: Context,
      prefs: SharedPreferences,
  ) {
    val manager = AppWidgetManager.getInstance(context)
    val ids = manager.getAppWidgetIds(
        ComponentName(context, DashboardHomeWidgetProvider::class.java),
    )
    if (ids.isEmpty()) return
    _onUpdateImpl(context, manager, ids, prefs)
  }

  /**
   * Minimal patch that swaps the refresh pill / spinner
   * visibility without touching the list at all. Uses
   * [AppWidgetManager.partiallyUpdateAppWidget] so the existing
   * RemoteAdapter binding is preserved — no call to
   * updateAppWidget, setRemoteAdapter, or
   * notifyAppWidgetViewDataChanged, which means the ListView
   * doesn't flicker between its loading view and the stale rows
   * while Dart refreshes in the background.
   */
  private fun applyRefreshingState(context: Context, showSpinner: Boolean) {
    val manager = AppWidgetManager.getInstance(context)
    val ids = manager.getAppWidgetIds(
        ComponentName(context, DashboardHomeWidgetProvider::class.java),
    )
    if (ids.isEmpty()) return
    ids.forEach { widgetId ->
      val patch = RemoteViews(
          context.packageName,
          R.layout.dashboard_home_widget_noanim,
      ).apply {
        // Header: swap Refresh pill ↔ spinner
        setViewVisibility(
            R.id.widget_refresh,
            if (showSpinner) View.GONE else View.VISIBLE,
        )
        setViewVisibility(
            R.id.widget_refresh_spinner,
            if (showSpinner) View.VISIBLE else View.GONE,
        )
        // Body: when refreshing, hide the list and show a centered
        // "Loading..." message. When done, hide the message and
        // restore the list (onUpdate handles that on data arrival).
        setViewVisibility(
            R.id.widget_list,
            if (showSpinner) View.GONE else View.VISIBLE,
        )
        setViewVisibility(
            R.id.widget_empty,
            if (showSpinner) View.VISIBLE else View.GONE,
        )
        if (showSpinner) {
          setTextViewText(R.id.widget_empty, "Loading...")
        }
      }
      manager.partiallyUpdateAppWidget(widgetId, patch)
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
