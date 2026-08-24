package com.arinco.horas_hombre_mobile

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        init {
            System.loadLibrary("facerec")
        }

        private const val CHANNEL = "samples.flutter.dev/facesdk"
    }

    private fun getNativeLibDir(): String {
        return applicationInfo.nativeLibraryDir
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getNativeLibDir" -> result.success(getNativeLibDir())
                    else -> result.notImplemented()
                }
            }
    }
}
