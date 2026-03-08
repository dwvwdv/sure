package am.sure.mobile

import android.content.Intent
import android.widget.RemoteViewsService

/**
 * Service that provides the RemoteViewsFactory for the calendar GridView widget.
 * Android requires a bound service to supply data for collection widgets (ListView/GridView).
 */
class CalendarWidgetService : RemoteViewsService() {

    companion object {
        const val EXTRA_YEAR     = "extra_year"
        const val EXTRA_MONTH    = "extra_month"
        const val EXTRA_DAYS_RAW = "extra_days_raw"
    }

    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        CalendarWidgetFactory(applicationContext, intent)
}
