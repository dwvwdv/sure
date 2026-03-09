package am.sure.mobile

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.ComponentName
import android.widget.RemoteViews
import android.app.PendingIntent
import android.content.Intent
import android.graphics.Color
import org.json.JSONObject
import org.json.JSONArray
import java.util.*

class CalendarWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val PREFS_NAME = "HomeWidgetPreferences"
        const val ACTION_PREV_MONTH = "am.sure.mobile.ACTION_PREV_MONTH"
        const val ACTION_NEXT_MONTH = "am.sure.mobile.ACTION_NEXT_MONTH"
        const val ACTION_PREV_ACCOUNT = "am.sure.mobile.ACTION_PREV_ACCOUNT"
        const val ACTION_NEXT_ACCOUNT = "am.sure.mobile.ACTION_NEXT_ACCOUNT"

        private val monthNames = arrayOf(
            "January", "February", "March", "April", "May", "June",
            "July", "August", "September", "October", "November", "December"
        )

        fun updateAllWidgets(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, CalendarWidgetProvider::class.java)
            )
            for (id in ids) {
                updateWidget(context, manager, id)
            }
        }

        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val views = RemoteViews(context.packageName, R.layout.calendar_widget_layout)

            // Read widget navigation state
            val now = Calendar.getInstance()
            val viewYear = prefs.getInt("widget_view_year", now.get(Calendar.YEAR))
            val viewMonth = prefs.getInt("widget_view_month", now.get(Calendar.MONTH) + 1)
            val selectedAccountIndex = prefs.getInt("widget_selected_account_index", 0)

            // Read account list
            val accountsJson = prefs.getString("widget_accounts", "[]") ?: "[]"
            val accounts = try { JSONArray(accountsJson) } catch (e: Exception) { JSONArray() }
            val accountCount = accounts.length()

            // Get current account info
            var accountName = "No accounts"
            var accountCurrency = ""
            if (accountCount > 0) {
                val safeIndex = selectedAccountIndex.coerceIn(0, accountCount - 1)
                val account = accounts.getJSONObject(safeIndex)
                accountName = account.optString("name", "Unknown")
                accountCurrency = account.optString("currency", "")
            }

            // Read daily totals
            val dailyTotalsJson = prefs.getString("widget_daily_totals", "{}") ?: "{}"
            val dailyTotals = try { JSONObject(dailyTotalsJson) } catch (e: Exception) { JSONObject() }

            // Override with stored account name and currency if available
            val storedAccountName = prefs.getString("widget_account_name", null)
            val storedCurrency = prefs.getString("widget_currency", null)
            if (storedAccountName != null) accountName = storedAccountName
            if (storedCurrency != null) accountCurrency = storedCurrency

            // --- Set up click actions ---

            // Prev/Next account
            views.setOnClickPendingIntent(R.id.btn_prev_account,
                makeBroadcastIntent(context, ACTION_PREV_ACCOUNT, 1))
            views.setOnClickPendingIntent(R.id.btn_next_account,
                makeBroadcastIntent(context, ACTION_NEXT_ACCOUNT, 2))

            // Prev/Next month
            views.setOnClickPendingIntent(R.id.btn_prev_month,
                makeBroadcastIntent(context, ACTION_PREV_MONTH, 3))
            views.setOnClickPendingIntent(R.id.btn_next_month,
                makeBroadcastIntent(context, ACTION_NEXT_MONTH, 4))

            // Tap calendar grid to open app
            val launchIntent = Intent(context, MainActivity::class.java)
            val launchPending = PendingIntent.getActivity(
                context, 0, launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            // Set on each week row so tapping any day opens app
            val weekRowIds = intArrayOf(
                R.id.week_row_0, R.id.week_row_1, R.id.week_row_2,
                R.id.week_row_3, R.id.week_row_4, R.id.week_row_5
            )
            for (rowId in weekRowIds) {
                views.setOnClickPendingIntent(rowId, launchPending)
            }

            // --- Render header ---
            views.setTextViewText(R.id.widget_account_name, accountName)

            // Account counter (e.g., "2/5")
            if (accountCount > 0) {
                val safeIndex = selectedAccountIndex.coerceIn(0, accountCount - 1)
                views.setTextViewText(R.id.widget_account_balance,
                    "${safeIndex + 1}/$accountCount")
            } else {
                views.setTextViewText(R.id.widget_account_balance, "")
            }

            // Month/year
            val monthName = if (viewMonth in 1..12) monthNames[viewMonth - 1] else ""
            views.setTextViewText(R.id.widget_month_year, "$monthName $viewYear")

            // --- Calculate monthly total from daily totals ---
            val yearMonthPrefix = String.format("%04d-%02d", viewYear, viewMonth)
            var monthlyTotal = 0.0
            val keys = dailyTotals.keys()
            while (keys.hasNext()) {
                val key = keys.next()
                if (key.startsWith(yearMonthPrefix)) {
                    monthlyTotal += dailyTotals.getDouble(key)
                }
            }

            val totalSign = if (monthlyTotal >= 0) "+" else ""
            views.setTextViewText(R.id.widget_monthly_total,
                "$totalSign$accountCurrency${String.format("%.2f", kotlin.math.abs(monthlyTotal))}")
            views.setTextColor(R.id.widget_monthly_total,
                if (monthlyTotal >= 0) Color.parseColor("#15803D") else Color.parseColor("#DC2626"))

            // --- Build calendar grid ---
            val calendar = Calendar.getInstance()
            calendar.set(viewYear, viewMonth - 1, 1)
            val firstDayOfWeek = calendar.get(Calendar.DAY_OF_WEEK) - 1 // 0 = Sunday
            val daysInMonth = calendar.getActualMaximum(Calendar.DAY_OF_MONTH)

            val todayYear = now.get(Calendar.YEAR)
            val todayMonth = now.get(Calendar.MONTH) + 1
            val todayDay = now.get(Calendar.DAY_OF_MONTH)

            val dayCellIds = arrayOf(
                intArrayOf(R.id.day_0_0, R.id.day_0_1, R.id.day_0_2, R.id.day_0_3, R.id.day_0_4, R.id.day_0_5, R.id.day_0_6),
                intArrayOf(R.id.day_1_0, R.id.day_1_1, R.id.day_1_2, R.id.day_1_3, R.id.day_1_4, R.id.day_1_5, R.id.day_1_6),
                intArrayOf(R.id.day_2_0, R.id.day_2_1, R.id.day_2_2, R.id.day_2_3, R.id.day_2_4, R.id.day_2_5, R.id.day_2_6),
                intArrayOf(R.id.day_3_0, R.id.day_3_1, R.id.day_3_2, R.id.day_3_3, R.id.day_3_4, R.id.day_3_5, R.id.day_3_6),
                intArrayOf(R.id.day_4_0, R.id.day_4_1, R.id.day_4_2, R.id.day_4_3, R.id.day_4_4, R.id.day_4_5, R.id.day_4_6),
                intArrayOf(R.id.day_5_0, R.id.day_5_1, R.id.day_5_2, R.id.day_5_3, R.id.day_5_4, R.id.day_5_5, R.id.day_5_6)
            )

            // Clear all cells
            for (week in 0..5) {
                for (day in 0..6) {
                    views.setTextViewText(dayCellIds[week][day], "")
                    views.setInt(dayCellIds[week][day], "setBackgroundResource", R.drawable.day_cell_bg)
                    views.setTextColor(dayCellIds[week][day], Color.parseColor("#374151"))
                }
            }

            // Fill in days
            for (dayNum in 1..daysInMonth) {
                val position = firstDayOfWeek + dayNum - 1
                val weekRow = position / 7
                val dayCol = position % 7
                if (weekRow > 5) break

                val dateKey = String.format("%04d-%02d-%02d", viewYear, viewMonth, dayNum)
                val dailyTotal = if (dailyTotals.has(dateKey)) dailyTotals.getDouble(dateKey) else null
                val isToday = viewYear == todayYear && viewMonth == todayMonth && dayNum == todayDay

                var displayText = dayNum.toString()
                if (dailyTotal != null && dailyTotal != 0.0) {
                    val sign = if (dailyTotal > 0) "+" else ""
                    displayText = "$dayNum\n${sign}${formatCompact(dailyTotal)}"
                }

                views.setTextViewText(dayCellIds[weekRow][dayCol], displayText)

                when {
                    isToday -> {
                        views.setInt(dayCellIds[weekRow][dayCol], "setBackgroundResource", R.drawable.day_cell_today)
                        views.setTextColor(dayCellIds[weekRow][dayCol], Color.parseColor("#4338CA"))
                    }
                    dailyTotal != null && dailyTotal > 0 -> {
                        views.setInt(dayCellIds[weekRow][dayCol], "setBackgroundResource", R.drawable.day_cell_positive)
                        views.setTextColor(dayCellIds[weekRow][dayCol], Color.parseColor("#15803D"))
                    }
                    dailyTotal != null && dailyTotal < 0 -> {
                        views.setInt(dayCellIds[weekRow][dayCol], "setBackgroundResource", R.drawable.day_cell_negative)
                        views.setTextColor(dayCellIds[weekRow][dayCol], Color.parseColor("#DC2626"))
                    }
                }
            }

            // Hide unused week rows
            val totalRows = (firstDayOfWeek + daysInMonth + 6) / 7
            for (i in 0..5) {
                views.setViewVisibility(
                    weekRowIds[i],
                    if (i < totalRows) android.view.View.VISIBLE else android.view.View.GONE
                )
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        private fun makeBroadcastIntent(context: Context, action: String, requestCode: Int): PendingIntent {
            val intent = Intent(context, CalendarWidgetProvider::class.java).apply {
                this.action = action
            }
            return PendingIntent.getBroadcast(
                context, requestCode, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }

        private fun formatCompact(value: Double): String {
            val abs = kotlin.math.abs(value)
            return when {
                abs >= 1000000 -> String.format("%.1fM", value / 1000000)
                abs >= 1000 -> String.format("%.1fK", value / 1000)
                abs >= 100 -> String.format("%.0f", value)
                else -> String.format("%.1f", value)
            }
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)

        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        when (intent.action) {
            ACTION_PREV_MONTH -> {
                val year = prefs.getInt("widget_view_year", Calendar.getInstance().get(Calendar.YEAR))
                val month = prefs.getInt("widget_view_month", Calendar.getInstance().get(Calendar.MONTH) + 1)
                val cal = Calendar.getInstance()
                cal.set(year, month - 2, 1) // month-2 because Calendar is 0-indexed
                prefs.edit()
                    .putInt("widget_view_year", cal.get(Calendar.YEAR))
                    .putInt("widget_view_month", cal.get(Calendar.MONTH) + 1)
                    .apply()
                updateAllWidgets(context)
            }
            ACTION_NEXT_MONTH -> {
                val year = prefs.getInt("widget_view_year", Calendar.getInstance().get(Calendar.YEAR))
                val month = prefs.getInt("widget_view_month", Calendar.getInstance().get(Calendar.MONTH) + 1)
                val cal = Calendar.getInstance()
                cal.set(year, month, 1) // month (not month+1) because Calendar is 0-indexed and we want next
                prefs.edit()
                    .putInt("widget_view_year", cal.get(Calendar.YEAR))
                    .putInt("widget_view_month", cal.get(Calendar.MONTH) + 1)
                    .apply()
                updateAllWidgets(context)
            }
            ACTION_PREV_ACCOUNT -> {
                val accountCount = prefs.getInt("widget_account_count", 0)
                if (accountCount > 0) {
                    val current = prefs.getInt("widget_selected_account_index", 0)
                    val newIndex = if (current <= 0) accountCount - 1 else current - 1
                    prefs.edit().putInt("widget_selected_account_index", newIndex).apply()
                    syncAccountSelection(context, prefs, newIndex)
                }
            }
            ACTION_NEXT_ACCOUNT -> {
                val accountCount = prefs.getInt("widget_account_count", 0)
                if (accountCount > 0) {
                    val current = prefs.getInt("widget_selected_account_index", 0)
                    val newIndex = if (current >= accountCount - 1) 0 else current + 1
                    prefs.edit().putInt("widget_selected_account_index", newIndex).apply()
                    syncAccountSelection(context, prefs, newIndex)
                }
            }
        }
    }

    /**
     * When account selection changes on the widget, update the displayed
     * account name and currency from the stored accounts list, then refresh.
     */
    private fun syncAccountSelection(context: Context, prefs: android.content.SharedPreferences, index: Int) {
        val accountsJson = prefs.getString("widget_accounts", "[]") ?: "[]"
        try {
            val accounts = JSONArray(accountsJson)
            if (index < accounts.length()) {
                val account = accounts.getJSONObject(index)
                prefs.edit()
                    .putString("widget_account_name", account.optString("name", "Unknown"))
                    .putString("widget_currency", account.optString("currency", ""))
                    .apply()
            }
        } catch (e: Exception) {
            // ignore parse errors
        }
        updateAllWidgets(context)
    }
}
