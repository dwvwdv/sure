package am.sure.mobile

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.widget.RemoteViews
import java.text.DecimalFormat
import java.text.DecimalFormatSymbols
import java.util.Calendar
import java.util.Locale
import kotlin.math.abs

class CalendarWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (id in appWidgetIds) updateAppWidget(context, appWidgetManager, id)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        updateAppWidget(context, appWidgetManager, appWidgetId)
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
    }

    override fun onReceive(context: Context, intent: Intent) {
        val statePrefs = context.getSharedPreferences(PREFS_WIDGET_STATE, Context.MODE_PRIVATE)
        when (intent.action) {
            ACTION_PREV_MONTH -> {
                val offset = statePrefs.getInt(KEY_MONTH_OFFSET, 0)
                statePrefs.edit().putInt(KEY_MONTH_OFFSET, offset - 1).apply()
                forceUpdate(context)
            }
            ACTION_NEXT_MONTH -> {
                val offset = statePrefs.getInt(KEY_MONTH_OFFSET, 0)
                statePrefs.edit().putInt(KEY_MONTH_OFFSET, offset + 1).apply()
                forceUpdate(context)
            }
            ACTION_PREV_ACCOUNT -> {
                val homePrefs = context.getSharedPreferences(PREFS_HOME_WIDGET, Context.MODE_PRIVATE)
                val count: Int = parseAccountList(homePrefs.getString(KEY_ACCOUNT_LIST, "") ?: "")
                    .size.coerceAtLeast(1)
                val idx = statePrefs.getInt(KEY_ACCOUNT_IDX, 0)
                statePrefs.edit().putInt(KEY_ACCOUNT_IDX, ((idx - 1 + count) % count)).apply()
                forceUpdate(context)
            }
            ACTION_NEXT_ACCOUNT -> {
                val homePrefs = context.getSharedPreferences(PREFS_HOME_WIDGET, Context.MODE_PRIVATE)
                val count: Int = parseAccountList(homePrefs.getString(KEY_ACCOUNT_LIST, "") ?: "")
                    .size.coerceAtLeast(1)
                val idx = statePrefs.getInt(KEY_ACCOUNT_IDX, 0)
                statePrefs.edit().putInt(KEY_ACCOUNT_IDX, ((idx + 1) % count)).apply()
                forceUpdate(context)
            }
            else -> super.onReceive(context, intent)
        }
    }

    private fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        try {
            updateAppWidgetInternal(context, appWidgetManager, appWidgetId)
        } catch (e: Exception) {
            try {
                // Fallback: use the ultra-minimal layout that can never fail to inflate
                val fallback = RemoteViews(context.packageName, R.layout.calendar_widget_minimal)
                fallback.setTextViewText(R.id.widget_account_name, "Widget Error")
                fallback.setTextViewText(R.id.widget_month_label, e.javaClass.simpleName)
                fallback.setTextViewText(R.id.widget_monthly_total, e.message ?: "unknown error")
                appWidgetManager.updateAppWidget(appWidgetId, fallback)
            } catch (_: Exception) { /* ignore secondary failure */ }
        }
    }

    private fun updateAppWidgetInternal(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        val homePrefs  = context.getSharedPreferences(PREFS_HOME_WIDGET,  Context.MODE_PRIVATE)
        val statePrefs = context.getSharedPreferences(PREFS_WIDGET_STATE, Context.MODE_PRIVATE)

        val monthOffset = statePrefs.getInt(KEY_MONTH_OFFSET, 0)
        val accountIdx  = statePrefs.getInt(KEY_ACCOUNT_IDX, 0)

        val cal = Calendar.getInstance()
        cal.add(Calendar.MONTH, monthOffset)
        val displayYear  = cal.get(Calendar.YEAR)
        val displayMonth = cal.get(Calendar.MONTH) + 1
        val monthKey     = "%04d-%02d".format(displayYear, displayMonth)

        val accountList  = parseAccountList(homePrefs.getString(KEY_ACCOUNT_LIST, "") ?: "")
        val count        = accountList.size
        val safeIdx      = if (count == 0) 0 else accountIdx % count
        val rawName      = accountList.getOrNull(safeIdx)?.first ?: "--"
        val accountLabel = if (count > 1) "$rawName (${safeIdx + 1}/$count)" else rawName
        val accountId    = accountList.getOrNull(safeIdx)?.second ?: ""

        val daysKey      = "${KEY_DAYS_PREFIX}${accountId}_${monthKey}"
        val daysRaw      = homePrefs.getString(daysKey, "") ?: ""
        val dailyData    = parseDailyData(daysRaw)
        val monthlyTotal = dailyData.values.sum()
        val currency     = homePrefs.getString(KEY_CURRENCY, "") ?: ""

        val compact  = isCompactWidget(appWidgetManager, appWidgetId)
        val layoutId = if (compact) R.layout.calendar_widget_compact else R.layout.calendar_widget
        val views    = RemoteViews(context.packageName, layoutId)

        views.setTextViewText(R.id.widget_account_name, accountLabel)
        views.setTextViewText(R.id.widget_month_label, monthKey)

        val totalColor = if (monthlyTotal >= 0) COLOR_GREEN else COLOR_RED
        views.setTextViewText(R.id.widget_monthly_total, formatAmount(monthlyTotal, currency))
        views.setTextColor(R.id.widget_monthly_total, totalColor)

        views.setOnClickPendingIntent(R.id.btn_prev_month,   buildBroadcast(context, ACTION_PREV_MONTH,   appWidgetId))
        views.setOnClickPendingIntent(R.id.btn_next_month,   buildBroadcast(context, ACTION_NEXT_MONTH,   appWidgetId))
        views.setOnClickPendingIntent(R.id.btn_prev_account, buildBroadcast(context, ACTION_PREV_ACCOUNT, appWidgetId))
        views.setOnClickPendingIntent(R.id.btn_next_account, buildBroadcast(context, ACTION_NEXT_ACCOUNT, appWidgetId))

        if (compact) {
            val today   = Calendar.getInstance()
            val dayFmt  = java.text.SimpleDateFormat("d",   Locale.getDefault())
            val wdayFmt = java.text.SimpleDateFormat("EEE", Locale.getDefault())
            views.setTextViewText(R.id.widget_day,     dayFmt.format(today.time))
            views.setTextViewText(R.id.widget_weekday, wdayFmt.format(today.time).uppercase(Locale.getDefault()))
        } else {
            val serviceIntent = Intent(context, CalendarWidgetService::class.java).apply {
                // Include year+month in URI so a new factory is created on each month
                // change. Same URI = cached factory = old month data / stale today highlight.
                data = Uri.parse("widget://calendar/$appWidgetId/$displayYear/$displayMonth")
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                putExtra(CalendarWidgetService.EXTRA_YEAR,     displayYear)
                putExtra(CalendarWidgetService.EXTRA_MONTH,    displayMonth)
                putExtra(CalendarWidgetService.EXTRA_DAYS_RAW, daysRaw)
            }
            views.setRemoteAdapter(R.id.widget_calendar_grid, serviceIntent)
        }

        val openApp = PendingIntent.getActivity(
            context, appWidgetId,
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_root, openApp)

        appWidgetManager.updateAppWidget(appWidgetId, views)
        if (!compact) {
            appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_calendar_grid)
        }
    }

    private fun isCompactWidget(appWidgetManager: AppWidgetManager, appWidgetId: Int): Boolean {
        val options   = appWidgetManager.getAppWidgetOptions(appWidgetId)
        val minHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 280)
        return minHeight < 180
    }

    private fun buildBroadcast(context: Context, action: String, widgetId: Int): PendingIntent =
        PendingIntent.getBroadcast(
            context,
            "$action$widgetId".hashCode(),
            Intent(context, CalendarWidgetProvider::class.java).apply {
                this.action = action
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

    companion object {
        const val ACTION_PREV_MONTH   = "am.sure.mobile.widget.PREV_MONTH"
        const val ACTION_NEXT_MONTH   = "am.sure.mobile.widget.NEXT_MONTH"
        const val ACTION_PREV_ACCOUNT = "am.sure.mobile.widget.PREV_ACCOUNT"
        const val ACTION_NEXT_ACCOUNT = "am.sure.mobile.widget.NEXT_ACCOUNT"

        const val PREFS_HOME_WIDGET  = "HomeWidgetPreferences"
        const val PREFS_WIDGET_STATE = "CalendarWidgetState"

        const val KEY_ACCOUNT_LIST = "widget_account_list"
        const val KEY_CURRENCY     = "widget_currency"
        const val KEY_DAYS_PREFIX  = "widget_days_"

        const val KEY_MONTH_OFFSET = "month_offset"
        const val KEY_ACCOUNT_IDX  = "account_idx"

        val COLOR_GREEN = 0xFF00C853.toInt()
        val COLOR_RED   = 0xFFFF1744.toInt()

        fun forceUpdate(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, CalendarWidgetProvider::class.java))
            if (ids.isNotEmpty()) {
                context.sendBroadcast(Intent(context, CalendarWidgetProvider::class.java).apply {
                    action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                })
            }
        }

        fun parseAccountList(raw: String): List<Pair<String, String>> {
            if (raw.isBlank()) return emptyList()
            return raw.split("|").mapNotNull { entry ->
                val idx = entry.lastIndexOf(':')
                if (idx < 0) null else Pair(entry.substring(0, idx), entry.substring(idx + 1))
            }
        }

        fun parseDailyData(raw: String): Map<Int, Double> {
            if (raw.isBlank()) return emptyMap()
            return raw.split("|").mapNotNull { entry ->
                val colonIdx = entry.indexOf(':')
                if (colonIdx < 0) return@mapNotNull null
                val day = entry.substring(0, colonIdx).trim().toIntOrNull() ?: return@mapNotNull null
                val amt = entry.substring(colonIdx + 1).trim().toDoubleOrNull() ?: return@mapNotNull null
                day to amt
            }.toMap()
        }

        fun formatAmount(amount: Double, currency: String): String {
            val symbol = currencySymbol(currency)
            val fmt    = DecimalFormat("#,##0.##", DecimalFormatSymbols(Locale.US))
            val sign   = if (amount >= 0) "+" else "-"
            return "$sign$symbol${fmt.format(abs(amount))}"
        }

        fun currencySymbol(currency: String): String = when (currency.uppercase(Locale.US)) {
            "USD"        -> "$"
            "TWD"        -> "NT$"
            "EUR"        -> "€"
            "GBP"        -> "£"
            "JPY", "CNY" -> "¥"
            "BTC"        -> "₿"
            "ETH"        -> "Ξ"
            else         -> if (currency.isBlank()) "" else "$currency "
        }
    }
}
