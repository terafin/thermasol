package com.ghost.showercast

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.opus.airvia.LogBus

/**
 * Auto-start after boot ONLY if the user has selected a real output (Sonos). If the
 * selection is the local default, do nothing — the panel plays through its own amp and
 * this app stays completely dormant, so fleet units that never opt in are unaffected.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != Intent.ACTION_BOOT_COMPLETED) return
        val sel = context.getSharedPreferences(ShowerCastService.PREFS, Context.MODE_PRIVATE)
            .getString(ShowerCastService.KEY_SEL, "local") ?: "local"
        if (!sel.contains("sonos")) {
            LogBus.log("BootReceiver: local-only selection, staying dormant")
            return
        }
        val i = Intent(context, ShowerCastService::class.java)
        context.startForegroundService(i)
        LogBus.log("BootReceiver: auto-started ShowerCastService (sel=$sel)")
    }
}
