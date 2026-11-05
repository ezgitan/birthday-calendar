package com.birthdaycalendar.birthday_calendar

import android.net.Uri
import android.view.View
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import java.time.LocalDate
import java.time.temporal.ChronoUnit

open class BirthdayWidgetProvider : HomeWidgetProvider() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action in setOf("com.birthdaycalendar.NEXT", "com.birthdaycalendar.PREV")) {
            val id = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, -1)
            val manager = AppWidgetManager.getInstance(context)
            if (manager.getAppWidgetInfo(id)?.provider?.className != javaClass.name) return
            val prefs = context.getSharedPreferences("widget_pages", Context.MODE_PRIVATE)
            prefs.edit().putInt(id.toString(), prefs.getInt(id.toString(), 0) + (if (intent.action == "com.birthdaycalendar.PREV") -1 else 1)).apply()
            onUpdate(context, manager, intArrayOf(id))
        } else super.onReceive(context, intent)
    }

    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: android.os.Bundle) {
        super.onAppWidgetOptionsChanged(context, manager, id, options)
        onUpdate(context, manager, intArrayOf(id))
    }

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray, data: SharedPreferences) {
        val today = LocalDate.now()
        val events = widgetEvents(data).map { event ->
            fun occurrence(year: Int): LocalDate {
                val first = LocalDate.of(year, event.getInt("month"), 1)
                return first.withDayOfMonth(minOf(event.getInt("day"), first.lengthOfMonth()))
            }
            val date = occurrence(today.year)
            (if (date < today) occurrence(today.year + 1) else date) to event
        }.sortedBy { it.first }
        val prefs = context.getSharedPreferences("widget_pages", Context.MODE_PRIVATE)
        for (id in ids) {
            val small = this is SquareBirthdayWidgetProvider
            val compact = !small && manager.getAppWidgetOptions(id).getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 300) < 260
            val pinned = prefs.getString("pin$id", "")
            val person = prefs.getString("person$id", "")
            val pool = if (!person.isNullOrEmpty()) events.filter { personKey(it.second) == person } else events.filter { it.second.optString("id") == pinned }.ifEmpty { events }
            val cards = pool.takeWhile { it.first == pool.first().first }
            val index = if (cards.isEmpty()) 0 else Math.floorMod(prefs.getInt(id.toString(), 0), cards.size)
            val card = cards.getOrNull(index)
            val event = card?.second
            val theme = prefs.getInt("theme$id", if (prefs.getBoolean("dark$id",false)) 3 else 0).coerceIn(0,3)
            val dark = theme == 3
            val rv = RemoteViews(context.packageName, if (small) R.layout.square_card else if(compact) R.layout.compact_birthday_widget else R.layout.birthday_widget)
            val ink = android.graphics.Color.parseColor(if (dark) "#FCF7FF" else "#42364F")
            val accent = android.graphics.Color.parseColor(if (dark) "#DDC5FA" else "#70538E")
            rv.setInt(R.id.widget_root, "setBackgroundResource", listOf(R.drawable.widget_lavender,R.drawable.widget_blush,R.drawable.widget_cream,R.drawable.widget_dark)[theme])
            rv.setTextViewText(R.id.art, listOf("🎂","🎁","🎈","🎂")[theme])
            for (view in listOf(R.id.widget_countdown,R.id.dots,R.id.widget_prev,R.id.widget_next)) rv.setTextColor(view,accent)
            if (!small) {
                rv.setTextColor(R.id.kind,ink)
                rv.setInt(R.id.widget_call,"setBackgroundResource",listOf(R.drawable.call_lavender,R.drawable.call_blush,R.drawable.call_cream,R.drawable.call_dark)[theme])
            }
            rv.setTextColor(R.id.widget_name,ink)
            rv.setTextViewTextSize(R.id.widget_name, android.util.TypedValue.COMPLEX_UNIT_SP, if(event == null) (if(small) 14f else if(compact) 16f else 18f) else (if(small) 17f else if(compact) 16f else 20f))
            rv.setBoolean(R.id.widget_name, "setSingleLine", small && event != null)
            rv.setInt(R.id.widget_name, "setMaxLines", if(event == null || !small) 2 else 1)
            val type = event?.optString("type","Doğum Günü") ?: ""
            if (!small) {
                rv.setTextViewText(R.id.kind, if(type=="Diğer") event?.optString("customType") else type)
                rv.setViewVisibility(R.id.kind, if(event == null) View.GONE else View.VISIBLE)
                rv.setViewVisibility(R.id.nav, if(event == null || (compact && cards.size < 2)) View.GONE else View.VISIBLE)
            }
            rv.setTextViewText(R.id.widget_name,event?.optString("personName", event.optString("name")) ?: "Güzel günler biriktir")
            val days = card?.let { ChronoUnit.DAYS.between(today,it.first) }
            rv.setTextViewText(R.id.widget_countdown, when(days) {
                null -> "İlk tarihini ekle  +"
                0L -> "Bugün! 🎉"
                1L -> "Yarın! 🎈"
                else -> "$days gün kaldı"
            })
            for (view in listOf(R.id.widget_prev,R.id.widget_next,R.id.dots)) rv.setViewVisibility(view, if(cards.size>1) View.VISIBLE else View.GONE)
            val first = (index-2).coerceIn(0,(cards.size-5).coerceAtLeast(0))
            rv.setTextViewText(R.id.dots,if(cards.size < 2) "" else if(!small) "${index+1}/${cards.size}" else (first until minOf(first+5,cards.size)).joinToString(" ") { if(it==index) "●" else "○" })
            for ((view,action) in listOf(R.id.widget_prev to "PREV",R.id.widget_next to "NEXT")) {
                val intent = Intent(context,javaClass).setAction("com.birthdaycalendar.$action").putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID,id)
                rv.setOnClickPendingIntent(view,PendingIntent.getBroadcast(context,id,intent,PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
            }
            val open = Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            rv.setOnClickPendingIntent(R.id.widget_root,PendingIntent.getActivity(context,id,open,flags))
            if (!small) {
                val phone = event?.optString("phone").orEmpty()
                rv.setViewVisibility(R.id.widget_actions,if(phone.isBlank()) View.GONE else View.VISIBLE)
                if(phone.isNotBlank()){
                    rv.setOnClickPendingIntent(R.id.widget_call,PendingIntent.getActivity(context,id,Intent(Intent.ACTION_DIAL,Uri.fromParts("tel",phone,null)),flags))
                    rv.setOnClickPendingIntent(R.id.widget_chat,PendingIntent.getActivity(context,id,Intent(Intent.ACTION_VIEW,Uri.parse("https://wa.me/"+phone.removePrefix("+"))),flags))
                }
            }
            manager.updateAppWidget(id,rv)
        }
    }
    override fun onDeleted(context: Context, ids: IntArray) {
        val prefs=context.getSharedPreferences("widget_pages",Context.MODE_PRIVATE).edit()
        ids.forEach { prefs.remove(it.toString()).remove("pin$it").remove("dark$it").remove("theme$it").remove("person$it") }
        prefs.apply()
        super.onDeleted(context,ids)
    }
}
internal fun widgetEvents(data: SharedPreferences): List<org.json.JSONObject> {
    val array=JSONArray(data.getString("birthdays","[]"))
    return (0 until array.length()).map { array.getJSONObject(it) }
}
class SquareBirthdayWidgetProvider : BirthdayWidgetProvider()

internal fun personKey(e: org.json.JSONObject): String = e.optString("phone").ifBlank { e.optString("personName",e.optString("name")) }
