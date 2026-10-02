package com.arinco.horas_hombre_mobile

import android.content.pm.ActivityInfo
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

    override fun onDestroy() {
        super.onDestroy()
        // La licencia 3DiVi permite un solo face_detector por proceso.
        // Si la Activity muere y el proceso sigue, el cupo queda ocupado
        // y el siguiente arranque falla con available 0, used 1.
        if (!isChangingConfigurations) {
            android.os.Process.killProcess(android.os.Process.myPid())
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getNativeLibDir" -> result.success(getNativeLibDir())
                    "moveTaskToBack" -> result.success(moveTaskToBack(true))
                    "setSensorOrientation" -> {
                        requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
