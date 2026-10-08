package com.pickixo.polyscan_scanner

import android.app.Activity
import android.content.Intent
import android.net.Uri
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions
import com.google.mlkit.vision.documentscanner.GmsDocumentScanning
import com.google.mlkit.vision.documentscanner.GmsDocumentScanningResult
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import java.io.File
import java.util.concurrent.Executors

/**
 * Opens Google ML Kit's document scanner (runs on the device through Google Play
 * services; needs no camera permission) and copies the scanned pages to JPEG files.
 */
class PolyscanScannerPlugin :
    FlutterPlugin,
    MethodCallHandler,
    ActivityAware,
    PluginRegistry.ActivityResultListener {
    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var binding: ActivityPluginBinding? = null
    private var pending: Result? = null
    private val io = Executors.newSingleThreadExecutor()

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "polyscan_scanner")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        io.shutdown()
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "isAvailable" -> result.success(playServicesAvailable())
            "scan" -> scan(call.argument<Int>("pageLimit") ?: 50, result)
            else -> result.notImplemented()
        }
    }

    private fun playServicesAvailable(): Boolean {
        val context = activity ?: return false
        return GoogleApiAvailability.getInstance().isGooglePlayServicesAvailable(context) == ConnectionResult.SUCCESS
    }

    private fun scan(pageLimit: Int, result: Result) {
        val activity = this.activity
        if (activity == null) {
            result.error("scan_failed", "No activity to start the scanner from", null)
            return
        }
        if (pending != null) {
            result.error("busy", "A scan is already open", null)
            return
        }
        if (!playServicesAvailable()) {
            result.error("unavailable", "Google Play services is not available", null)
            return
        }
        val options = GmsDocumentScannerOptions.Builder()
            .setGalleryImportAllowed(false)
            .setPageLimit(pageLimit.coerceIn(1, 100))
            .setResultFormats(GmsDocumentScannerOptions.RESULT_FORMAT_JPEG)
            .setScannerMode(GmsDocumentScannerOptions.SCANNER_MODE_FULL)
            .build()
        pending = result
        GmsDocumentScanning.getClient(options).getStartScanIntent(activity)
            .addOnSuccessListener { sender ->
                try {
                    activity.startIntentSenderForResult(sender, REQUEST_CODE, null, 0, 0, 0)
                } catch (e: Exception) {
                    finish { it.error("scan_failed", e.message, null) }
                }
            }
            .addOnFailureListener { e ->
                // Usually the scanner module could not be installed by Play services.
                finish { it.error("unavailable", e.message, null) }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CODE) return false
        val activity = this.activity
        if (resultCode != Activity.RESULT_OK || activity == null) {
            finish { it.success(emptyList<String>()) }
            return true
        }
        val uris = GmsDocumentScanningResult.fromActivityResultIntent(data)?.pages?.map { it.imageUri }.orEmpty()
        io.execute {
            try {
                val paths = copyPages(activity, uris)
                activity.runOnUiThread { finish { it.success(paths) } }
            } catch (e: Exception) {
                activity.runOnUiThread { finish { it.error("scan_failed", e.message, null) } }
            }
        }
        return true
    }

    /** Copies the scanner's page images into our own cache folder. */
    private fun copyPages(activity: Activity, uris: List<Uri>): List<String> {
        val dir = File(activity.cacheDir, "polyscan_scanner").apply { mkdirs() }
        val stamp = System.currentTimeMillis()
        return uris.mapIndexed { i, uri ->
            val out = File(dir, "scan-$stamp-${i + 1}.jpg")
            val input = activity.contentResolver.openInputStream(uri)
                ?: throw IllegalStateException("Cannot read page ${i + 1}")
            input.use { src -> out.outputStream().use { src.copyTo(it) } }
            out.absolutePath
        }
    }

    private fun finish(reply: (Result) -> Unit) {
        val result = pending ?: return
        pending = null
        reply(result)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        this.binding = binding
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = onAttachedToActivity(binding)

    override fun onDetachedFromActivity() {
        binding?.removeActivityResultListener(this)
        binding = null
        activity = null
    }

    companion object {
        private const val REQUEST_CODE = 0x5ca7
    }
}
