package com.econatlas.econatlas_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import androidx.core.content.ContextCompat
import org.json.JSONArray
import org.json.JSONObject

class DashboardHomeWidgetRemoteViewsService : RemoteViewsService() {
  override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
    return DashboardHomeWidgetRemoteViewsFactory(applicationContext, intent)
  }
}

private class DashboardHomeWidgetRemoteViewsFactory(
    private val context: Context,
    intent: Intent,
) : RemoteViewsService.RemoteViewsFactory {
  private val appWidgetId: Int =
      intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
  private var items: List<DashboardWidgetRow> = emptyList()

  override fun onCreate() = Unit

  override fun onDataSetChanged() {
    val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
    val raw = prefs.getString("dashboard_widget_snapshot", null)
    val activeTab =
        prefs.getString(
            DashboardHomeWidgetProvider.PREF_ACTIVE_TAB,
            DashboardHomeWidgetProvider.TAB_MARKETS,
        ) ?: DashboardHomeWidgetProvider.TAB_MARKETS
    // The snapshot is a single flat list with section headers. For
    // the widget's tabbed UI we slice out just the segment whose
    // preceding section header matches the active tab.
    val all = DashboardWidgetRowParser.parse(raw)
    items = filterByTab(all, activeTab)
  }

  private fun filterByTab(
      all: List<DashboardWidgetRow>,
      activeTab: String,
  ): List<DashboardWidgetRow> {
    val targetSection =
        when (activeTab) {
          DashboardHomeWidgetProvider.TAB_MARKETS -> "Markets"
          DashboardHomeWidgetProvider.TAB_STOCKS -> "Stocks"
          DashboardHomeWidgetProvider.TAB_MFS -> "Mutual Funds"
          else -> "Markets"
        }
    val result = mutableListOf<DashboardWidgetRow>()
    var inTarget = false
    for (row in all) {
      if (row.type == DashboardWidgetRowType.SECTION) {
        inTarget = row.title.equals(targetSection, ignoreCase = true)
        // Skip the section header itself — the tab already tells the
        // user which section they're viewing.
        continue
      }
      if (inTarget) result.add(row)
    }
    return result
  }

  override fun onDestroy() {
    items = emptyList()
  }

  override fun getCount(): Int = items.size

  override fun getViewAt(position: Int): RemoteViews? {
    if (position < 0 || position >= items.size) return null
    val item = items[position]
    return when (item.type) {
      DashboardWidgetRowType.SECTION -> buildSectionView(item)
      DashboardWidgetRowType.EMPTY -> buildEmptyView(item)
      DashboardWidgetRowType.MARKET,
      DashboardWidgetRowType.STOCK,
      DashboardWidgetRowType.MUTUAL_FUND,
      -> buildDataView(item)
    }
  }

  override fun getLoadingView(): RemoteViews? = null

  override fun getViewTypeCount(): Int = 3

  override fun getItemId(position: Int): Long = "$appWidgetId-$position".hashCode().toLong()

  override fun hasStableIds(): Boolean = false

  private fun buildSectionView(item: DashboardWidgetRow): RemoteViews {
    return RemoteViews(context.packageName, R.layout.dashboard_home_widget_row_section).apply {
      setTextViewText(R.id.section_title, item.title)
      setTextViewText(R.id.section_count, item.count?.toString() ?: "0")
    }
  }

  private fun buildEmptyView(item: DashboardWidgetRow): RemoteViews {
    return RemoteViews(context.packageName, R.layout.dashboard_home_widget_row_empty).apply {
      setTextViewText(R.id.empty_text, item.title)
    }
  }

  private fun buildDataView(item: DashboardWidgetRow): RemoteViews {
    return RemoteViews(context.packageName, R.layout.dashboard_home_widget_row_data).apply {
      setTextViewText(R.id.row_title, item.title)
      setTextViewText(R.id.row_subtitle, item.subtitle)
      setTextViewText(R.id.row_footer, item.footer)
      setTextViewText(R.id.row_value, item.value)
      setTextViewText(R.id.row_change, item.change)

      setViewVisibility(
          R.id.row_subtitle,
          if (item.subtitle.isBlank()) View.GONE else View.VISIBLE,
      )
      setViewVisibility(
          R.id.row_footer,
          if (item.footer.isBlank()) View.GONE else View.VISIBLE,
      )
      setViewVisibility(
          R.id.row_value,
          if (item.value.isBlank()) View.GONE else View.VISIBLE,
      )
      setViewVisibility(
          R.id.row_change,
          if (item.change.isBlank()) View.GONE else View.VISIBLE,
      )

      val changeColor =
          when (item.changeTone) {
            "positive" -> R.color.widget_green
            "negative" -> R.color.widget_red
            else -> R.color.widget_neutral
          }
      setTextColor(R.id.row_change, ContextCompat.getColor(context, changeColor))

      if (!item.route.isNullOrBlank()) {
        val fillInIntent = Intent().apply { data = android.net.Uri.parse(item.route) }
        setOnClickFillInIntent(R.id.row_root, fillInIntent)
      }
    }
  }
}

private enum class DashboardWidgetRowType {
  SECTION,
  MARKET,
  STOCK,
  MUTUAL_FUND,
  EMPTY,
}

private data class DashboardWidgetRow(
    val type: DashboardWidgetRowType,
    val title: String,
    val subtitle: String = "",
    val footer: String = "",
    val value: String = "",
    val change: String = "",
    val changeTone: String = "neutral",
    val count: Int? = null,
    val route: String? = null,
)

private object DashboardWidgetRowParser {
  fun parse(raw: String?): List<DashboardWidgetRow> {
    if (raw.isNullOrBlank()) return emptyList()
    return try {
      val json = JSONObject(raw)
      val items = json.optJSONArray("items") ?: JSONArray()
      buildList {
        for (index in 0 until items.length()) {
          val item = items.optJSONObject(index) ?: continue
          add(
              DashboardWidgetRow(
                  type = parseType(item.optString("type")),
                  title = item.optString("title"),
                  subtitle = item.optString("subtitle"),
                  footer = item.optString("footer"),
                  value = item.optString("value"),
                  change = item.optString("change"),
                  changeTone = item.optString("changeTone", "neutral"),
                  count = if (item.has("count")) item.optInt("count") else null,
                  route = item.optString("route").ifBlank { null },
              ),
          )
        }
      }
    } catch (_: Exception) {
      emptyList()
    }
  }

  private fun parseType(raw: String): DashboardWidgetRowType {
    return when (raw) {
      "section" -> DashboardWidgetRowType.SECTION
      "market" -> DashboardWidgetRowType.MARKET
      "stock" -> DashboardWidgetRowType.STOCK
      "mutual_fund" -> DashboardWidgetRowType.MUTUAL_FUND
      else -> DashboardWidgetRowType.EMPTY
    }
  }
}
