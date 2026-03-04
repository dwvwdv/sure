package am.sure.mobile

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import java.text.DecimalFormat
import java.text.DecimalFormatSymbols
import java.util.Calendar
import java.util.Locale
import kotlin.math.abs

/**
 * AppWidget provider for the Sure Finances calendar home screen widget.
 *
 * Displays a monthly calendar grid where each day shows transaction amounts
 * (green = income, red = expense), matching the app's Calendar screen.
 * Supports month and account navigation via button taps.
 *
 * Data flow:
 *   Flutter → HomeWidgetService → HomeWidgetPreferences (SharedPrefs)
 *   CalendarWidgetProvider reads HomeWidgetPreferences + manages its own
 *   display state in CalendarWidgetState (month offset, account index).
 */
class CalendarWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_PREV_MONTH    = "am.sure.mobile.widget.PREV_MONTH"
        const val ACTION_NEXT_MONTH    = "am.sure.mobile.widget.NEXT_MONTH"
        const val ACTION_PREV_ACCOUNT  = "am.sure.mobile.widget.PREV_ACCOUNT"
        const val ACTION_NEXT_ACCOUNT  = "am.sure.mobile.widget.NEXT_ACCOUNT"

        // SharedPrefs written by Flutter via home_widget package
        const val PREFS_HOME_WIDGET  = "HomeWidgetPreferences"
        const val KEY_ACCOUNT_LIST   = "widget_account_list"  // "Name:id|Name:id"
        const val KEY_CURRENCY       = "widget_currency"
        const val KEY_DAYS_PREFIX    = "widget_days_"          // widget_days_{accountId}_{YYYY-MM}

        // Widget's own display state (independent of Flutter)
        const val PREFS_WIDGET_STATE = "CalendarWidgetState"
        const val KEY_MONTH_OFFSET   = "month_offset"          // int, months relative to today
        const val KEY_ACCOUNT_IDX    = "account_idx"           // int

        fun forceUpdate(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, CalendarWidgetProvider::class.java)
            )
            if (ids.isNotEmpty()) {
                val intent = Intent(context, CalendarWidgetProvider::class.java).apply {
                    action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                }
                context.sendBroadcast(intent)
            }
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (id in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, id)
        }
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
                val count = parseAccountList(homePrefs.getString(KEY_ACCOUNT_LIST, "") ?: "").size.coerceAtLeast(1)
                val idx = statePrefs.getInt(KEY_ACCOUNT_IDX, 0)
                statePrefs.edit().putInt(KEY_ACCOUNT_IDX, (idx - 1 + count) % count).apply()
                forceUpdate(context)
            }
            ACTION_NEXT_ACCOUNT -> {
                val homePrefs = context.getSharedPreferences(PREFS_HOME_WIDGET, Context.MODE_PRIVATE)
                val count = parseAccountList(homePrefs.getString(KEY_ACCOUNT_LIST, "") ?: "").size.coerceAtLeast(1)
                val idx = statePrefs.getInt(KEY_ACCOUNT_IDX, 0)
                statePrefs.edit().putInt(KEY_ACCOUNT_IDX, (idx + 1) % count).apply()
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
        val homePrefs  = context.getSharedPreferences(PREFS_HOME_WIDGET,  Context.MODE_PRIVATE)
        val statePrefs = context.getSharedPreferences(PREFS_WIDGET_STATE, Context.MODE_PRIVATE)

        val monthOffset = statePrefs.getInt(KEY_MONTH_OFFSET, 0)
        val accountIdx  = statePrefs.getInt(KEY_ACCOUNT_IDX, 0)

        // Resolve display month
        val cal = Calendar.getInstance()
        cal.add(Calendar.MONTH, monthOffset)
        val displayYear  = cal.get(Calendar.YEAR)
        val displayMonth = cal.get(Calendar.MONTH) + 1
        val monthKey     = "%04d-%02d".format(displayYear, displayMonth)

        // Resolve account
        val accountList = parseAccountList(homePrefs.getString(KEY_ACCOUNT_LIST, "") ?: "")
        val safeIdx     = if (accountList.isEmpty()) 0 else accountIdx % accountList.size
        val accountName = accountList.getOrNull(safeIdx)?.first ?: "No accounts"
        val accountId   = accountList.getOrNull(safeIdx)?.second ?: ""

        // Read daily data for this account + month
        val daysKey = "${KEY_DAYS_PREFIX}${accountId}_${monthKey}"
        val daysRaw = homePrefs.getString(daysKey, "") ?: ""

        // Monthly total
        val dailyData    = parseDailyData(daysRaw)
        val monthlyTotal = dailyData.values.sum()
        val currency     = homePrefs.getString(KEY_CURRENCY, "") ?: ""

        val views = RemoteViews(context.packageName, R.layout.calendar_widget)

        // Header
        views.setTextViewText(R.id.widget_account_name, accountName)
        views.setTextViewText(R.id.widget_month_label, monthKey)
        views.setTextViewText(R.id.widget_monthly_total, formatAmount(monthlyTotal, currency))
        views.setTextColor(
            R.id.widget_monthly_total,
            if (monthlyTotal >= 0) 0xFF00C853.toInt() else 0xFFFF1744.toInt()
        )

        // Navigation buttons
        views.setOnClickPendingIntent(R.id.btn_prev_month,   buildBroadcast(context, ACTION_PREV_MONTH,   appWidgetId))
        views.setOnClickPendingIntent(R.id.btn_next_month,   buildBroadcast(context, ACTION_NEXT_MONTH,   appWidgetId))
        views.setOnClickPendingIntent(R.id.btn_prev_account, buildBroadcast(context, ACTION_PREV_ACCOUNT, appWidgetId))
        views.setOnClickPendingIntent(R.id.btn_next_account, buildBroadcast(context, ACTION_NEXT_ACCOUNT, appWidgetId))

        // GridView via RemoteViewsService
        val serviceIntent = Intent(context, CalendarWidgetService::class.java).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            putExtra(CalendarWidgetService.EXTRA_YEAR,     displayYear)
            putExtra(CalendarWidgetService.EXTRA_MONTH,    displayMonth)
            putExtra(CalendarWidgetService.EXTRA_DAYS_RAW, daysRaw)
        }
        views.setRemoteAdapter(R.id.widget_calendar_grid, serviceIntent)

        // Tap on widget opens app to Calendar tab
        val openApp = PendingIntent.getActivity(
            context, 0,
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_root, openApp)

        appWidgetManager.updateAppWidget(appWidgetId, views)
        appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_calendar_grid)
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

    companion object Helpers {
        /** Parses "AccountName:accountId|AccountName2:accountId2" */
        fun parseAccountList(raw: String): List<Pair<String, String>> {
            if (raw.isBlank()) return emptyList()
            return raw.split("|").mapNotNull { entry ->
                val idx = entry.lastIndexOf(':')
                if (idx < 0) null else Pair(entry.substring(0, idx), entry.substring(idx + 1))
            }
        }

        /** Parses "01:-110.5|04:-30|15:820" into dayNumber → amount */
        fun parseDailyData(raw: String): Map<Int, Double> {
            if (raw.isBlank()) return emptyMap()
            return raw.split("|").mapNotNull { entry ->
                val parts = entry.split(":")
                if (parts.size != 2) null
                else parts[0].toIntOrNull()?.let { day ->
                    parts[1].toDoubleOrNull()?.let { amt -> day to amt }
                }
            }.toMap()
        }

        fun formatAmount(amount: Double, currency: String): String {
            val symbol = when (currency.uppercase(Locale.US)) {
                "USD", "TWD" -> "$"
                "EUR" -> "€"
                "GBP" -> "£"
                "JPY", "CNY" -> "¥"
                "BTC" -> "₿"
                else -> if (currency.isBlank()) "" else "$currency "
            }
            val fmt = DecimalFormat("#,##0.##", DecimalFormatSymbols(Locale.US))
            return "${if (amount >= 0) "+" else "-"}$symbol${fmt.format(abs(amount))}"
        }
    }
}
