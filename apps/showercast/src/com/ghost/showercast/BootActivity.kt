package com.ghost.showercast

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.RadioButton
import android.widget.RadioGroup
import android.widget.ScrollView
import android.widget.TextView
import com.opus.airvia.LogBus

/**
 * Tap-to-configure UI. Pick an output — Local amp (the stock default, no added output)
 * or Sonos (the shower) — set the Sonos host/gain, then START. The choice is persisted
 * so boot auto-start uses it; other users who never open this keep the local default.
 */
class BootActivity : Activity() {

    private lateinit var sonosRadio: RadioButton
    private lateinit var localRadio: RadioButton
    private lateinit var hostField: EditText
    private lateinit var gainField: EditText

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val p = getSharedPreferences(ShowerCastService.PREFS, Context.MODE_PRIVATE)
        val savedSel = p.getString(ShowerCastService.KEY_SEL, "local") ?: "local"
        val savedHost = p.getString(ShowerCastService.KEY_HOST, ShowerCastService.DEFAULT_HOST) ?: ShowerCastService.DEFAULT_HOST
        val savedGain = p.getFloat(ShowerCastService.KEY_GAIN, ShowerCastService.DEF_GAIN)

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(48, 40, 48, 40)
        }
        val title = TextView(this).apply { text = "Shower Cast"; textSize = 26f }

        val selLabel = TextView(this).apply { text = "Output:"; textSize = 16f }
        val group = RadioGroup(this).apply { orientation = RadioGroup.HORIZONTAL }
        localRadio = RadioButton(this).apply { id = View.generateViewId(); text = "Local amp (default)" }
        sonosRadio = RadioButton(this).apply { id = View.generateViewId(); text = "Sonos (shower)" }
        group.addView(localRadio); group.addView(sonosRadio)
        group.check(if (savedSel.contains("sonos")) sonosRadio.id else localRadio.id)

        val hostRow = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        hostRow.addView(TextView(this).apply { text = "Sonos host: "; textSize = 15f })
        hostField = EditText(this).apply { setText(savedHost); hint = "10.0.1.179" }
        hostRow.addView(hostField)

        val gainRow = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        gainRow.addView(TextView(this).apply { text = "Gain: "; textSize = 15f })
        gainField = EditText(this).apply { setText(savedGain.toString()); hint = "x (24 = near full scale)" }
        gainRow.addView(gainField)

        val startBtn = Button(this).apply {
            text = "START"
            setOnClickListener {
                val sel = if (sonosRadio.isChecked) "sonos" else "local"
                val host = hostField.text.toString().trim().ifEmpty { ShowerCastService.DEFAULT_HOST }
                val gain = gainField.text.toString().trim().toFloatOrNull() ?: ShowerCastService.DEF_GAIN
                getSharedPreferences(ShowerCastService.PREFS, Context.MODE_PRIVATE).edit()
                    .putString(ShowerCastService.KEY_SEL, sel)
                    .putString(ShowerCastService.KEY_HOST, host)
                    .putFloat(ShowerCastService.KEY_GAIN, gain)
                    .apply()
                val i = Intent(this@BootActivity, ShowerCastService::class.java)
                i.putExtra("sinks", sel); i.putExtra("host", host); i.putExtra("gain", gain)
                startForegroundService(i)
                LogBus.log("BootActivity: started sel=$sel host=$host gain=${gain}x")
            }
        }
        val stopBtn = Button(this).apply {
            text = "STOP"
            setOnClickListener { stopService(Intent(this@BootActivity, ShowerCastService::class.java)) }
        }
        val logView = TextView(this).apply {
            textSize = 12f
            typeface = android.graphics.Typeface.MONOSPACE
        }
        LogBus.addListener { line -> runOnUiThread { logView.append(line + "\n") } }

        root.addView(title)
        root.addView(selLabel)
        root.addView(group)
        root.addView(hostRow)
        root.addView(gainRow)
        root.addView(startBtn)
        root.addView(stopBtn)
        root.addView(ScrollView(this).apply { addView(logView) })
        setContentView(root)
    }
}
