package com.birthdaycalendar.birthday_calendar

import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val handler = Handler(Looper.getMainLooper())
    private var entered = false
    private var waiting: MethodChannel.Result? = null
    private val finishEntry = Runnable {
        entered = true
        waiting?.success(null)
        waiting = null
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            setRecentsScreenshotEnabled(false)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            splashScreen.setOnExitAnimationListener { it.remove() }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "iyiki/launch").setMethodCallHandler { call, reply ->
            when (call.method) {
                "waitForEntry" -> if (entered) reply.success(null) else {
                    waiting = reply
                    // Some launchers do not deliver an enter-animation callback.
                    handler.postDelayed(finishEntry, 750)
                }
                "homeVisible" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        setRecentsScreenshotEnabled(true)
                    }
                    reply.success(null)
                }
                else -> reply.notImplemented()
            }
        }
    }

    override fun onEnterAnimationComplete() {
        super.onEnterAnimationComplete()
        handler.removeCallbacks(finishEntry)
        finishEntry.run()
    }

    override fun onDestroy() {
        handler.removeCallbacks(finishEntry)
        finishEntry.run()
        super.onDestroy()
    }
}
