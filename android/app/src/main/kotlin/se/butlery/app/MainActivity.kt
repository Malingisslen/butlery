package se.butlery.app

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * BUT-941: receive shared photos (single ACTION_SEND or multi SEND_MULTIPLE)
 * from the OS share sheet and hand the image file paths to Flutter.
 *
 * NOTE: avoid writing the bare
 * image-slash-star glob here — Kotlin nests block comments, so a literal
 * slash-star inside this comment opens a nested comment and swallows the file.
 * ACTION_VIEW deep-links stay with app_links.
 *
 * BUT-2241: a text SEND (a link or recipe text shared from another app) is
 * read here too, from EXTRA_TEXT.
 *
 * Content Uris (content://) are transient and not readable as plain paths, so
 * each is copied into cacheDir and the absolute file path is returned — that's
 * what the Dart OCR import pipeline consumes.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "se.butlery.app/incoming_share"
    private var channel: MethodChannel? = null

    /** Cold-start paths captured before the Dart channel was ready. */
    private var pendingInitialPaths: List<String>? = null

    /** Cold-start shared text captured before the Dart channel was ready. */
    private var pendingInitialText: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                // Cold-start: Dart pulls the launch intent's images once on
                // init. Captured in onCreate; consume so a re-query is empty.
                "getInitialMedia" -> {
                    result.success(pendingInitialPaths ?: emptyList<String>())
                    pendingInitialPaths = null
                }
                "getInitialText" -> {
                    result.success(pendingInitialText)
                    pendingInitialText = null
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // SINGLE cold-start capture. extractImagePaths copies the shared
        // image(s) into cacheDir (OS-managed, reclaimed under storage
        // pressure), so it must run exactly once per launch intent — running
        // it again in configureFlutterEngine would double-copy every photo.
        // A recreated activity (restored state, or reopened from Recents)
        // carries the launch intent of a share that was already handled;
        // reading it again would import the same share twice.
        if (savedInstanceState != null ||
            (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY) != 0
        ) {
            return
        }
        pendingInitialPaths = extractImagePaths(intent)
        pendingInitialText = extractSharedText(intent)
    }

    // Warm-start: app already running when the user shares. Push straight to Dart.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val paths = extractImagePaths(intent)
        if (paths.isNotEmpty()) {
            channel?.invokeMethod("onMedia", paths)
        }
        val text = extractSharedText(intent)
        if (text != null) {
            channel?.invokeMethod("onText", text)
        }
    }

    /** The text of a text SEND intent, or null when this isn't one. */
    private fun extractSharedText(intent: Intent?): String? {
        if (intent == null || intent.action != Intent.ACTION_SEND) return null
        val type = intent.type ?: return null
        if (!type.startsWith("text/")) return null
        val text = intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()
        return text?.takeIf { it.isNotBlank() }
    }

    /**
     * Returns absolute cache-file paths for the image(s) in a SEND/SEND_MULTIPLE
     * intent, or an empty list when this isn't an image share.
     */
    private fun extractImagePaths(intent: Intent?): List<String> {
        if (intent == null) return emptyList()
        val type = intent.type ?: return emptyList()
        if (!type.startsWith("image/")) return emptyList()

        val uris: List<Uri> = when (intent.action) {
            Intent.ACTION_SEND -> {
                @Suppress("DEPRECATION")
                val uri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
                if (uri != null) listOf(uri) else emptyList()
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                @Suppress("DEPRECATION")
                intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
                    ?: emptyList()
            }
            else -> emptyList()
        }

        return uris.mapNotNull { copyUriToCache(it) }
    }

    /**
     * Copy a content:// (or file://) Uri's bytes into a private cache file and
     * return its absolute path. Returns null on any IO failure so one bad
     * attachment never aborts the rest of the batch.
     */
    private fun copyUriToCache(uri: Uri): String? {
        return try {
            val ext = when (contentResolver.getType(uri)) {
                "image/png" -> "png"
                "image/webp" -> "webp"
                else -> "jpg"
            }
            val outFile = File(
                cacheDir,
                "shared_${System.currentTimeMillis()}_${uri.hashCode()}.$ext",
            )
            contentResolver.openInputStream(uri).use { input ->
                if (input == null) return null
                outFile.outputStream().use { output -> input.copyTo(output) }
            }
            outFile.absolutePath
        } catch (e: Exception) {
            null
        }
    }
}
