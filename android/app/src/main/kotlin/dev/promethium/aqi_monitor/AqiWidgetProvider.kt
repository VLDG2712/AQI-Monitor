package dev.promethium.aqi_monitor

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.app.PendingIntent
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import android.net.Uri
import es.antonborri.home_widget.HomeWidgetBackgroundIntent

class AqiWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val widgetData = HomeWidgetPlugin.getData(context)

            val views = RemoteViews(context.packageName, R.layout.aqi_widget)

            val aqi       = widgetData.getInt("aqi", 0)
            val aqiLabel  = widgetData.getString("aqi_label", "—") ?: "—"
            val temp      = widgetData.getString("temp", "—") ?: "—"
            val humidity  = widgetData.getString("humidity", "—") ?: "—"
            val eco2      = widgetData.getString("eco2", "—") ?: "—"
            val tvoc      = widgetData.getString("tvoc", "—") ?: "—"
            val updated   = widgetData.getString("updated", "—") ?: "—"
            val connected = widgetData.getBoolean("connected", false)

            views.setTextViewText(R.id.widget_aqi, if (connected && aqi > 0) "$aqi" else "—")
            views.setTextViewText(R.id.widget_aqi_label, aqiLabel)
            views.setTextViewText(R.id.widget_temp, temp)
            views.setTextViewText(R.id.widget_humidity, humidity)
            views.setTextViewText(R.id.widget_eco2, eco2)
            views.setTextViewText(R.id.widget_tvoc, tvoc)
            views.setTextViewText(R.id.widget_updated, updated)

            // AQI color
            val aqiColor = when (aqi) {
                1 -> 0xFF00E676.toInt()
                2 -> 0xFF76FF03.toInt()
                3 -> 0xFFFFD740.toInt()
                4 -> 0xFFFF6D00.toInt()
                5 -> 0xFFD50000.toInt()
                else -> 0xFF627082.toInt()
            }
            views.setTextColor(R.id.widget_aqi, aqiColor)

            // Refresh button
            val refreshIntent = HomeWidgetBackgroundIntent.getBroadcast(
                context, 
                Uri.parse("aqi://refresh")
            )
            views.setOnClickPendingIntent(R.id.widget_refresh, refreshIntent)

            // Open app on tap
            val openIntent = Intent(context, MainActivity::class.java)
            val openPending = PendingIntent.getActivity(
                context, 0, openIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_aqi, openPending)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
