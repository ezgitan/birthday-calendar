package com.birthdaycalendar.birthday_calendar

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import android.widget.*
import es.antonborri.home_widget.HomeWidgetPlugin

class WidgetSetup: Activity() {
    private var selectedTheme=0
    override fun onSaveInstanceState(outState:Bundle) { super.onSaveInstanceState(outState);outState.putInt("theme",selectedTheme) }
    override fun onCreate(state: Bundle?) {
        super.onCreate(state)
        setResult(RESULT_CANCELED)
        val manager=AppWidgetManager.getInstance(this)
        val id=intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID,-1)
        val provider=manager.getAppWidgetInfo(id)?.provider
        if(provider?.packageName!=packageName){finish();return}
        val prefs=getSharedPreferences("widget_pages",MODE_PRIVATE)
        val events=widgetEvents(HomeWidgetPlugin.getData(this))
        val lavender = 0xff756098.toInt()
        val ink = 0xff3e354a.toInt()
        fun dp(value:Int) = (value * resources.displayMetrics.density).toInt()
        fun rounded(color:Int) = android.graphics.drawable.GradientDrawable().apply {
            setColor(color); cornerRadius=dp(18).toFloat()
        }
        val scroll=ScrollView(this).apply {
            setBackgroundColor(0xfffaf8fc.toInt())
            setOnApplyWindowInsetsListener { v, insets ->
                v.setPadding(insets.systemWindowInsetLeft,insets.systemWindowInsetTop,insets.systemWindowInsetRight,insets.systemWindowInsetBottom); insets
            }
        }
        val box=LinearLayout(this).apply { orientation=LinearLayout.VERTICAL;setPadding(dp(22),dp(28),dp(22),dp(24)) }
        scroll.addView(box);setContentView(scroll)
        fun label(title:String,size:Float,bold:Boolean=false) = TextView(this).apply {
            text=title;textSize=size;setTextColor(ink)
            if(bold) typeface=android.graphics.Typeface.create("sans-serif-medium",0)
        }
        fun space(n:Int) { box.addView(Space(this),1,dp(n)) }
        box.addView(label("iyi ki",22f,true).apply {setTextColor(lavender)})
        space(12);box.addView(label("Widget görünümü",28f,true))
        space(20);box.addView(label("Renk teması",17f,true));space(8)
        val names=listOf("Lavanta","Pudra","Krem","Gece")
        val colors=listOf(0xffeee4f9.toInt(),0xfffbe6ec.toInt(),0xfffbf1e4.toInt(),0xff38294c.toInt())
        var selection=(state?.getInt("theme") ?: prefs.getInt("theme$id",if(prefs.getBoolean("dark$id",false)) 3 else 0)).coerceIn(0,3)
        val themes=mutableListOf<Button>()
        fun paint() { themes.forEachIndexed { i,btn ->
            btn.text=(if(i==selection) "✓  " else "")+names[i]
            btn.isSelected=i==selection
            btn.background=rounded(colors[i]).apply {if(i==selection)setStroke(dp(2),lavender)}
            btn.setTextColor(if(i==3) android.graphics.Color.WHITE else ink)
        }; selectedTheme=selection }
        for(row in 0..1){
            val strip=LinearLayout(this)
            box.addView(strip)
            for(i in row*2..row*2+1){
                val btn=Button(this).apply {isAllCaps=false;setOnClickListener {selection=i;paint()} }
                strip.addView(btn,LinearLayout.LayoutParams(0,dp(48),1f).apply {setMargins(0,0,dp(6),dp(6))})
                themes.add(btn)
            }
        }
        paint()
        space(16);box.addView(label("Gösterilecek kişi",17f,true));space(4)
        box.addView(label("En yakın özel günü göster veya bir kişiyi sabitle.",14f));space(10)
        val people=events.distinctBy { personKey(it) }
        val legacy=events.firstOrNull { it.optString("id")==prefs.getString("pin$id","") }?.let { personKey(it) }
        val pin=Spinner(this).apply {
            adapter=ArrayAdapter(this@WidgetSetup,android.R.layout.simple_spinner_dropdown_item,listOf("Otomatik · En yakın özel gün")+people.map {it.optString("personName",it.optString("name"))})
            this.id=android.R.id.list
            background=rounded(android.graphics.Color.WHITE)
            setPadding(dp(12),0,dp(12),0)
            setSelection(1+people.indexOfFirst {personKey(it)==prefs.getString("person$id",legacy)})
        }
        box.addView(pin,LinearLayout.LayoutParams(-1,dp(52)))
        space(24)
        box.addView(Button(this).apply {
            text="Kaydet";isAllCaps=false;background=rounded(lavender);setTextColor(android.graphics.Color.WHITE)
            setOnClickListener {
                prefs.edit().putInt("theme$id",selection).remove("pin$id").putString("person$id",people.getOrNull(pin.selectedItemPosition-1)?.let { personKey(it) }.orEmpty()).putInt(id.toString(),0).apply()
                val receiver=if(provider.className.endsWith("SquareBirthdayWidgetProvider")) SquareBirthdayWidgetProvider() else BirthdayWidgetProvider()
                receiver.onUpdate(this@WidgetSetup,manager,intArrayOf(id))
                setResult(RESULT_OK,Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID,id)); finish()
            }
        })
    }
}


