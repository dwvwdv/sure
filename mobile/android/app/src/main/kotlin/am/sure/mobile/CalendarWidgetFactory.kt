package am.sure.mobile

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import java.util.Calendar
import kotlin.math.abs

/**
 * Provides the calendar day cells for the GridView in the home screen widget.
 *
 * The grid is 7 columns × up to 6 rows = 42 cells total.
 * Leading/trailing empty cells are rendered as blank so the layout aligns correctly.
 * Each active day cell shows the day number and, if available, the daily amount
 * colour-coded green (positive) or red (negative).
 */
class CalendarWidgetFactory(
    private val context: Context,
    intent: Intent
) : RemoteViewsService.RemoteViewsFactory {

    private val year: Int     = intent.getIntExtra(CalendarWidgetService.EXTRA_YEAR, 2026)
    private val month: Int    = intent.getIntExtra(CalendarWidgetService.EXTRA_MONTH, 1)  // 1-based
    private val daysRaw: String = intent.getStringExtra(CalendarWidgetService.EXTRA_DAYS_RAW) ?: ""

    // Each item: Pair(dayNumber or null for blank, amount or null)
    private var items: List<Pair<Int?, Double?>> = emptyList()

    override fun onCreate()         { buildItems() }
    override fun onDataSetChanged() { buildItems() }
    override fun onDestroy()        {}

    override fun getCount(): Int = items.size
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = false
    override fun getViewTypeCount(): Int = 1

    override fun getLoadingView(): RemoteViews =
        RemoteViews(context.packageName, R.layout.calendar_widget_cell)

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.calendar_widget_cell)
        val (day, amount) = items.getOrNull(position) ?: return views

        if (day == null) {
            // Empty leading/trailing cell
            views.setTextViewText(R.id.cell_day, "")
            views.setTextViewText(R.id.cell_amount, "")
            views.setInt(R.id.cell_root, "setBackgroundResource", android.R.color.transparent)
            return views
        }

        views.setTextViewText(R.id.cell_day, day.toString())

        if (amount != null && amount != 0.0) {
            val isPositive = amount > 0
            views.setTextViewText(R.id.cell_amount, formatShort(amount))
            views.setTextColor(
                R.id.cell_amount,
                if (isPositive) Color.parseColor("#00C853") else Color.parseColor("#FF1744")
            )
            views.setInt(
                R.id.cell_root, "setBackgroundResource",
                if (isPositive) R.drawable.widget_cell_positive else R.drawable.widget_cell_negative
            )
        } else {
            views.setTextViewText(R.id.cell_amount, "")
            views.setInt(R.id.cell_root, "setBackgroundResource", R.drawable.widget_cell_background)
        }

        // Highlight today
        val today = Calendar.getInstance()
        if (today.get(Calendar.YEAR) == year &&
            today.get(Calendar.MONTH) + 1 == month &&
            today.get(Calendar.DAY_OF_MONTH) == day
        ) {
            views.setTextColor(R.id.cell_day, Color.parseColor("#FFD740"))
        } else {
            views.setTextColor(R.id.cell_day, Color.WHITE)
        }

        return views
    }

    // --- Private helpers ---

    private fun buildItems() {
        val dailyData = CalendarWidgetProvider.parseDailyData(daysRaw)

        val cal = Calendar.getInstance()
        cal.set(year, month - 1, 1)
        val daysInMonth  = cal.getActualMaximum(Calendar.DAY_OF_MONTH)
        val firstWeekday = cal.get(Calendar.DAY_OF_WEEK) - 1  // 0 = Sunday

        val list = mutableListOf<Pair<Int?, Double?>>()

        // Leading blanks
        repeat(firstWeekday) { list.add(Pair(null, null)) }

        // Day cells
        for (day in 1..daysInMonth) {
            list.add(Pair(day, dailyData[day]))
        }

        // Trailing blanks to complete last row
        val remainder = list.size % 7
        if (remainder != 0) {
            repeat(7 - remainder) { list.add(Pair(null, null)) }
        }

        items = list
    }

    /** Short compact amount: +1.2K, -830, +12.5K etc. */
    private fun formatShort(amount: Double): String {
        val sign = if (amount >= 0) "+" else "-"
        val abs  = abs(amount)
        return when {
            abs >= 1_000_000 -> "$sign${"%.1f".format(abs / 1_000_000)}M"
            abs >= 1_000     -> "$sign${"%.1f".format(abs / 1_000)}K"
            else             -> "$sign${"%.0f".format(abs)}"
        }
    }
}
