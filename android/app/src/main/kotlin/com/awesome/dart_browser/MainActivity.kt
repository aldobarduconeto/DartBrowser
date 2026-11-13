package com.awesome.dart_browser

import android.app.PictureInPictureParams
import android.content.res.Configuration
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pictureInPictureChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dart_browser/device")
            .setMethodCallHandler { call, result ->
                if (call.method == "isTv") {
                    val mode = resources.configuration.uiMode and Configuration.UI_MODE_TYPE_MASK
                    result.success(mode == Configuration.UI_MODE_TYPE_TELEVISION)
                } else {
                    result.notImplemented()
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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dart_browser/device")
            .setMethodCallHandler(null)
        pictureInPictureChannel?.setMethodCallHandler(null)
        pictureInPictureChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
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

