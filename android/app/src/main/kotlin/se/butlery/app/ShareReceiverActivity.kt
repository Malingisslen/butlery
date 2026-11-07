package se.butlery.app

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.util.Log

/**
 * BUT-2469: the share sheet launches its target with NEW_DOCUMENT and
 * MULTIPLE_TASK, so a share aimed at MainActivity always created a new task
 * and a whole new Flutter engine, even with Butlery already open. The share
 * waited for a full app start and each one left another Butlery in Recents.
 *
 * This activity takes the share instead and hands it to MainActivity as a
 * NEW_TASK launch, which reaches the running app through onNewIntent
 * (or starts it once, when it is not running), then finishes without drawing.
 *
 * Only the fields MainActivity reads are copied over, onto an explicit intent
 * for our own activity: the share comes from any app.
 */
class ShareReceiverActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (savedInstanceState == null) {
            // A sender can hand over a malformed extras bundle or a photo it
            // never granted us; either must end here, not crash the share.
            try {
                forward(intent)?.let { startActivity(it) }
            } catch (e: Exception) {
                Log.w("ShareReceiver", "Could not hand the share on", e)
            }
        }
        finish()
    }

    private fun forward(source: Intent?): Intent? {
        if (source == null) return null
        val action = source.action
        if (action != Intent.ACTION_SEND && action != Intent.ACTION_SEND_MULTIPLE) {
            return null
        }
        val target = Intent(this, MainActivity::class.java)
            .setAction(action)
            .setType(source.type)
            // CLEAR_TOP with SINGLE_TOP reaches the running MainActivity even
            // when another activity, such as the camera, sits above it.
            .addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP,
            )
        source.getCharSequenceExtra(Intent.EXTRA_TEXT)?.let {
            target.putExtra(Intent.EXTRA_TEXT, it)
        }
        // A shared photo is a content Uri the sender granted to us for this
        // launch; the read grant is passed on with it, or MainActivity could
        // not open the file.
        @Suppress("DEPRECATION")
        when (action) {
            Intent.ACTION_SEND -> source.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
                ?.let { target.putExtra(Intent.EXTRA_STREAM, it) }
            Intent.ACTION_SEND_MULTIPLE ->
                source.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
                    ?.let { target.putParcelableArrayListExtra(Intent.EXTRA_STREAM, it) }
        }
        if (target.hasExtra(Intent.EXTRA_STREAM)) {
            target.clipData = source.clipData
            target.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        return target
    }
}
