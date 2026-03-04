package am.sure.mobile

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import android.app.PendingIntent
import android.content.Intent
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

/**
 * AppWidget provider for the Sure Finances calendar home screen widget.
 * Displays the current date and the user's net worth, updated by the Flutter app
 * via the home_widget package's shared preferences bridge.
 */
class CalendarWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val PREFS_NAME = "HomeWidgetPreferences"
        private const val KEY_NET_WORTH = "widget_net_worth"
        private const val KEY_NET_WORTH_LABEL = "widget_net_worth_label"
        private const val KEY_UPDATED_AT = "widget_updated_at"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    private fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        val prefs: SharedPreferences =
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        val netWorth = prefs.getString(KEY_NET_WORTH, "--") ?: "--"
        val netWorthLabel = prefs.getString(KEY_NET_WORTH_LABEL, "Net Worth") ?: "Net Worth"
        val updatedAt = prefs.getString(KEY_UPDATED_AT, "") ?: ""

        // Build current date strings
        val now = Calendar.getInstance()
        val dayFormat = SimpleDateFormat("d", Locale.getDefault())
        val weekdayFormat = SimpleDateFormat("EEE", Locale.getDefault())
        val monthFormat = SimpleDateFormat("MMMM yyyy", Locale.getDefault())

        val dayText = dayFormat.format(now.time)
        val weekdayText = weekdayFormat.format(now.time).uppercase(Locale.getDefault())
        val monthText = monthFormat.format(now.time)

        val views = RemoteViews(context.packageName, R.layout.calendar_widget)

        // Set date values
        views.setTextViewText(R.id.widget_day, dayText)
        views.setTextViewText(R.id.widget_weekday, weekdayText)
        views.setTextViewText(R.id.widget_month, monthText)

        // Set financial values from Flutter shared prefs
        views.setTextViewText(R.id.widget_net_worth, netWorth)
        views.setTextViewText(R.id.widget_net_worth_label, netWorthLabel)
        views.setTextViewText(R.id.widget_updated_at, updatedAt)

        // Tap on widget opens the app
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
}
