package com.example.neet_app

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	companion object {
		private const val SCREEN_SECURITY_CHANNEL = "neet_app/screen_security"
	}

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		MethodChannel(
			flutterEngine.dartExecutor.binaryMessenger,
			SCREEN_SECURITY_CHANNEL
		).setMethodCallHandler { call, result ->
			when (call.method) {
				"setScreenCaptureProtection" -> {
					val enabled = call.argument<Boolean>("enabled") ?: false
					if (enabled) {
						window.setFlags(
							WindowManager.LayoutParams.FLAG_SECURE,
							WindowManager.LayoutParams.FLAG_SECURE
						)
					} else {
						window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
					}
					result.success(null)
				}
				else -> result.notImplemented()
			}
		}
	}
}
