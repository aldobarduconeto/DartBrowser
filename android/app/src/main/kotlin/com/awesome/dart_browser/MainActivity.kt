package com.awesome.dart_browser

import android.app.PictureInPictureParams
import android.content.res.Configuration
import android.content.pm.PackageManager
import android.os.Build
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsController
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pictureInPictureChannel: MethodChannel? = null
    private var deviceChannel: MethodChannel? = null
    private var windowChannel: MethodChannel? = null
    private var restoreSystemBars: (() -> Unit)? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        windowChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, "dart_browser/window"
        ).apply {
            setMethodCallHandler { call, result ->
                if (call.method == "setVideoFullscreen") {
                    setVideoFullscreen(call.arguments == true)
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
        }
        deviceChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dart_browser/device").apply {
            setMethodCallHandler { call, result ->
                if (call.method == "isTv") {
                    val mode = resources.configuration.uiMode and Configuration.UI_MODE_TYPE_MASK
                    result.success(mode == Configuration.UI_MODE_TYPE_TELEVISION)
                } else {
                    result.notImplemented()
                }
            }
        }
        pictureInPictureChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "dart_browser/picture_in_picture"
        ).apply {
            setMethodCallHandler { call, result ->
                if (call.method != "enter") {
                    result.notImplemented()
                } else {
                    result.success(enterBrowserPictureInPicture())
                }
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        setVideoFullscreen(false)
        windowChannel?.setMethodCallHandler(null)
        windowChannel = null
        deviceChannel?.setMethodCallHandler(null)
        deviceChannel = null
        pictureInPictureChannel?.setMethodCallHandler(null)
        pictureInPictureChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    @Suppress("DEPRECATION")
    private fun setVideoFullscreen(enabled: Boolean) {
        if (!enabled) {
            restoreSystemBars?.invoke()
            restoreSystemBars = null
            return
        }
        if (restoreSystemBars != null) return

        val decor = window.decorView
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val controller = window.insetsController ?: return
            val previousBehavior = controller.systemBarsBehavior
            val status = WindowInsets.Type.statusBars()
            val navigation = WindowInsets.Type.navigationBars()
            val previousInsets = decor.rootWindowInsets
            val visibleBars =
                (if (previousInsets?.isVisible(status) != false) status else 0) or
                (if (previousInsets?.isVisible(navigation) != false) navigation else 0)
            val bars = status or navigation
            restoreSystemBars = {
                controller.systemBarsBehavior = previousBehavior
                controller.show(visibleBars)
                controller.hide(bars and visibleBars.inv())
            }
            controller.systemBarsBehavior =
                WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            controller.hide(bars)
        } else {
            val previousVisibility = decor.systemUiVisibility
            restoreSystemBars = { decor.systemUiVisibility = previousVisibility }
            decor.systemUiVisibility = previousVisibility or
                View.SYSTEM_UI_FLAG_FULLSCREEN or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
        }
    }

    private fun enterBrowserPictureInPicture(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
            !packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
        ) {
            return false
        }
        return try {
            enterPictureInPictureMode(PictureInPictureParams.Builder().build())
        } catch (_: IllegalStateException) {
            false
        }
    }
}

