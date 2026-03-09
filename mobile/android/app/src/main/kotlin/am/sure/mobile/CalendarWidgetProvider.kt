package am.sure.mobile

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import android.app.PendingIntent
import android.content.Intent
import android.graphics.Color
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*

class CalendarWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        private const val PREFS_NAME = "HomeWidgetPreferences"

        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val views = RemoteViews(context.packageName, R.layout.calendar_widget_layout)

            // Set click intent to open the app
            val intent = Intent(context, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            // Read data from shared preferences
            val year = prefs.getInt("widget_year", Calendar.getInstance().get(Calendar.YEAR))
            val month = prefs.getInt("widget_month", Calendar.getInstance().get(Calendar.MONTH) + 1)
            val accountName = prefs.getString("widget_account_name", "All Accounts") ?: "All Accounts"
            val currency = prefs.getString("widget_currency", "") ?: ""
            val monthlyTotalStr = prefs.getString("widget_monthly_total", "0.00") ?: "0.00"
            val dailyTotalsJson = prefs.getString("widget_daily_totals", "{}") ?: "{}"
            val lastUpdated = prefs.getString("widget_last_updated", "") ?: ""

            val monthlyTotal = monthlyTotalStr.toDoubleOrNull() ?: 0.0
            val dailyTotals = try {
                JSONObject(dailyTotalsJson)
            } catch (e: Exception) {
                JSONObject()
            }

            // Set header
            val monthNames = arrayOf(
                "January", "February", "March", "April", "May", "June",
                "July", "August", "September", "October", "November", "December"
            )
            val monthName = if (month in 1..12) monthNames[month - 1] else ""
            views.setTextViewText(R.id.widget_month_year, "$monthName $year")

            // Set account name
            views.setTextViewText(R.id.widget_account_name, accountName)

            // Set monthly total with color
            val totalSign = if (monthlyTotal >= 0) "+" else ""
            views.setTextViewText(
                R.id.widget_monthly_total,
                "$totalSign$currency${String.format("%.2f", kotlin.math.abs(monthlyTotal))}"
            )
            views.setTextColor(
                R.id.widget_monthly_total,
                if (monthlyTotal >= 0) Color.parseColor("#15803D") else Color.parseColor("#DC2626")
            )

            // Set last updated
            if (lastUpdated.isNotEmpty()) {
                try {
                    val sdf = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault())
                    val date = sdf.parse(lastUpdated)
                    val displayFormat = SimpleDateFormat("HH:mm", Locale.getDefault())
                    views.setTextViewText(
                        R.id.widget_last_updated,
                        "Updated ${displayFormat.format(date!!)}"
                    )
                } catch (e: Exception) {
                    views.setTextViewText(R.id.widget_last_updated, "")
                }
            }

            // Build calendar grid
            val calendar = Calendar.getInstance()
            calendar.set(year, month - 1, 1)
            val firstDayOfWeek = calendar.get(Calendar.DAY_OF_WEEK) - 1 // 0 = Sunday
            val daysInMonth = calendar.getActualMaximum(Calendar.DAY_OF_MONTH)

            val today = Calendar.getInstance()
            val todayYear = today.get(Calendar.YEAR)
            val todayMonth = today.get(Calendar.MONTH) + 1
            val todayDay = today.get(Calendar.DAY_OF_MONTH)

            // Day cell IDs grid
            val dayCellIds = arrayOf(
                intArrayOf(R.id.day_0_0, R.id.day_0_1, R.id.day_0_2, R.id.day_0_3, R.id.day_0_4, R.id.day_0_5, R.id.day_0_6),
                intArrayOf(R.id.day_1_0, R.id.day_1_1, R.id.day_1_2, R.id.day_1_3, R.id.day_1_4, R.id.day_1_5, R.id.day_1_6),
                intArrayOf(R.id.day_2_0, R.id.day_2_1, R.id.day_2_2, R.id.day_2_3, R.id.day_2_4, R.id.day_2_5, R.id.day_2_6),
                intArrayOf(R.id.day_3_0, R.id.day_3_1, R.id.day_3_2, R.id.day_3_3, R.id.day_3_4, R.id.day_3_5, R.id.day_3_6),
                intArrayOf(R.id.day_4_0, R.id.day_4_1, R.id.day_4_2, R.id.day_4_3, R.id.day_4_4, R.id.day_4_5, R.id.day_4_6),
                intArrayOf(R.id.day_5_0, R.id.day_5_1, R.id.day_5_2, R.id.day_5_3, R.id.day_5_4, R.id.day_5_5, R.id.day_5_6)
            )

            // Clear all cells first
            for (week in 0..5) {
                for (day in 0..6) {
                    views.setTextViewText(dayCellIds[week][day], "")
                    views.setInt(dayCellIds[week][day], "setBackgroundResource", R.drawable.day_cell_bg)
                    views.setTextColor(dayCellIds[week][day], Color.parseColor("#374151"))
                }
            }

            // Fill in the days
            for (dayNum in 1..daysInMonth) {
                val position = firstDayOfWeek + dayNum - 1
                val weekRow = position / 7
                val dayCol = position % 7

                if (weekRow > 5) break

                val dateKey = String.format("%04d-%02d-%02d", year, month, dayNum)
                val dailyTotal = if (dailyTotals.has(dateKey)) dailyTotals.getDouble(dateKey) else null

                val isToday = year == todayYear && month == todayMonth && dayNum == todayDay

                // Set day number text
                var displayText = dayNum.toString()
                if (dailyTotal != null && dailyTotal != 0.0) {
                    val sign = if (dailyTotal > 0) "+" else ""
                    displayText = "$dayNum\n${sign}${formatCompact(dailyTotal)}"
                }

                views.setTextViewText(dayCellIds[weekRow][dayCol], displayText)

                // Set background and text color
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
            val weekRowIds = intArrayOf(
                R.id.week_row_0, R.id.week_row_1, R.id.week_row_2,
                R.id.week_row_3, R.id.week_row_4, R.id.week_row_5
            )
            for (i in 0..5) {
                views.setViewVisibility(
                    weekRowIds[i],
                    if (i < totalRows) android.view.View.VISIBLE else android.view.View.GONE
                )
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
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
}
