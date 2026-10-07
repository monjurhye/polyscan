package com.pickixo.polyscan_ocr

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.os.Handler
import android.os.Looper
import androidx.exifinterface.media.ExifInterface
import com.googlecode.tesseract.android.TessBaseAPI
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/** Runs Tesseract (Tesseract4Android) off the main thread; same channel contract as the iOS side. */
class PolyscanOcrPlugin :
    FlutterPlugin,
    MethodCallHandler {
    private lateinit var channel: MethodChannel
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private val mainHandler by lazy { Handler(Looper.getMainLooper()) }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "polyscan_ocr")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(
        call: MethodCall,
        result: Result
    ) {
        when (call.method) {
            "tesseractVersion" -> {
                val api = TessBaseAPI()
                try {
                    result.success(api.getVersion())
                } finally {
                    api.recycle()
                }
            }
            "recognize" -> {
                val imagePath = call.argument<String>("imagePath")
                val tessdataDir = call.argument<String>("tessdataDir")
                val languages = call.argument<String>("languages")
                if (imagePath == null || tessdataDir == null || languages == null) {
                    result.error("bad_args", "imagePath, tessdataDir and languages are required", null)
                    return
                }
                val config = EngineConfig(
                    imagePath, tessdataDir, languages,
                    call.argument<Int>("pageSegMode") ?: 3,
                    call.argument<Map<String, String>>("variables") ?: emptyMap(),
                )
                executor.execute {
                    val outcome = try {
                        Outcome.Success(recognize(config))
                    } catch (e: OcrException) {
                        Outcome.Failure(e)
                    }
                    mainHandler.post {
                        when (outcome) {
                            is Outcome.Success -> result.success(outcome.map)
                            is Outcome.Failure -> result.error(outcome.error.code, outcome.error.message, null)
                        }
                    }
                }
            }
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        executor.shutdown()
    }

    class OcrException(val code: String, override val message: String) : Exception(message)

    private sealed interface Outcome {
        class Success(val map: Map<String, Any>) : Outcome
        class Failure(val error: OcrException) : Outcome
    }

    data class EngineConfig(
        val imagePath: String,
        val tessdataDir: String,
        val languages: String,
        val pageSegMode: Int,
        val variables: Map<String, String>,
    )

    companion object {
        fun recognize(config: EngineConfig): Map<String, Any> {
            val bitmap = loadUpright(config.imagePath)
            try {
                val api = TessBaseAPI()
                try {
                    init(api, config)
                    for ((name, value) in config.variables) api.setVariable(name, value)
                    api.setPageSegMode(config.pageSegMode)
                    api.setImage(bitmap)
                    // Same as TessBaseAPISetSourceResolution(api, 300) on iOS.
                    api.setVariable("user_defined_dpi", "300")

                    // getUTF8Text runs recognition; the iterator below reads its results.
                    val text = api.getUTF8Text()
                        ?: throw OcrException("recognize_failed", "Tesseract could not read the image")
                    return mapOf(
                        "text" to text,
                        "meanConfidence" to api.meanConfidence(),
                        "words" to words(api),
                        "imageWidth" to bitmap.width,
                        "imageHeight" to bitmap.height,
                    )
                } finally {
                    api.recycle()
                }
            } finally {
                bitmap.recycle()
            }
        }

        /**
         * Tesseract4Android wants the folder that *contains* `tessdata`, and checks that every
         * requested `<lang>.traineddata` exists, so [EngineConfig.tessdataDir] must be named `tessdata`.
         */
        private fun init(api: TessBaseAPI, config: EngineConfig) {
            val dir = File(config.tessdataDir)
            val failure = "Could not load '${config.languages}' from ${config.tessdataDir}"
            if (dir.name != "tessdata") {
                throw OcrException("init_failed", "$failure (on Android the folder must be named 'tessdata')")
            }
            val ok = try {
                api.init(dir.parentFile!!.absolutePath, config.languages, TessBaseAPI.OEM_LSTM_ONLY)
            } catch (e: IllegalArgumentException) {
                throw OcrException("init_failed", "$failure: ${e.message}")
            }
            if (!ok) throw OcrException("init_failed", failure)
        }

        private fun words(api: TessBaseAPI): List<Map<String, Any>> {
            val words = mutableListOf<Map<String, Any>>()
            val iterator = api.getResultIterator() ?: return words
            try {
                iterator.begin()
                do {
                    val word = iterator.getUTF8Text(RIL_WORD) ?: continue
                    val box = iterator.getBoundingRect(RIL_WORD)
                    words.add(
                        mapOf(
                            "text" to word,
                            "left" to box.left, "top" to box.top, "right" to box.right, "bottom" to box.bottom,
                            "confidence" to iterator.confidence(RIL_WORD).toDouble(),
                        )
                    )
                } while (iterator.next(RIL_WORD))
            } finally {
                iterator.delete()
            }
            return words
        }

        /** TessBaseAPI.PageIteratorLevel.RIL_WORD. */
        private const val RIL_WORD = 3

        /** Decodes the image and rotates it upright according to its EXIF orientation. */
        private fun loadUpright(path: String): Bitmap {
            val options = BitmapFactory.Options().apply { inPreferredConfig = Bitmap.Config.ARGB_8888 }
            val bitmap = BitmapFactory.decodeFile(path, options)
                ?: throw OcrException("bad_image", "Cannot read image at $path")
            val orientation = try {
                ExifInterface(path).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)
            } catch (e: Exception) {
                ExifInterface.ORIENTATION_NORMAL
            }
            val matrix = Matrix()
            when (orientation) {
                ExifInterface.ORIENTATION_ROTATE_90 -> matrix.postRotate(90f)
                ExifInterface.ORIENTATION_ROTATE_180 -> matrix.postRotate(180f)
                ExifInterface.ORIENTATION_ROTATE_270 -> matrix.postRotate(270f)
                ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> matrix.postScale(-1f, 1f)
                ExifInterface.ORIENTATION_FLIP_VERTICAL -> matrix.postScale(1f, -1f)
                ExifInterface.ORIENTATION_TRANSPOSE -> { matrix.postRotate(90f); matrix.postScale(-1f, 1f) }
                ExifInterface.ORIENTATION_TRANSVERSE -> { matrix.postRotate(270f); matrix.postScale(-1f, 1f) }
                else -> return bitmap
            }
            val rotated = Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
            if (rotated !== bitmap) bitmap.recycle()
            return rotated
        }
    }
}
