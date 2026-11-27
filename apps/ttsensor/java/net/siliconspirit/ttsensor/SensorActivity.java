package net.siliconspirit.ttsensor;

import android.app.Activity;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import java.io.File;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;
import org.json.JSONObject;

public final class SensorActivity extends Activity implements SensorEventListener {
    private int count;
    private boolean done;
    private SensorManager manager;
    private final Handler handler = new Handler(Looper.getMainLooper());
    private final JSONObject result = new JSONObject();

    @Override // android.app.Activity
    public void onCreate(Bundle bundle) {
        super.onCreate(bundle);
        try {
            this.result.put("generated_ms", System.currentTimeMillis());
            this.manager = (SensorManager) getSystemService("sensor");
            Sensor defaultSensor = this.manager.getDefaultSensor(13);
            if (defaultSensor == null) {
                finishReport("missing_sensor");
                return;
            }
            this.result.put("sensor_name", defaultSensor.getName());
            this.result.put("sensor_vendor", defaultSensor.getVendor());
            this.result.put("type", defaultSensor.getType());
            if (!this.manager.registerListener(this, defaultSensor, 3)) {
                finishReport("registration_failed");
            } else {
                this.handler.postDelayed(new Runnable() {
                    @Override // java.lang.Runnable
                    public final void run() {
                        SensorActivity.this.m0lambda$onCreate$0$netsiliconspiritttsensorSensorActivity();
                    }
                }, 12000L);
            }
        } catch (Exception e) {
            finishReport("error: " + e.toString());
        }
    }

    /* synthetic */ void m0lambda$onCreate$0$netsiliconspiritttsensorSensorActivity() {
        finishReport("event_timeout");
    }

    @Override // android.hardware.SensorEventListener
    public void onSensorChanged(SensorEvent sensorEvent) {
        if (this.done || sensorEvent.sensor.getType() != 13) {
            return;
        }
        float f = sensorEvent.values[0];
        if (Float.isNaN(f) || Float.isInfinite(f)) {
            return;
        }
        try {
            double d = f;
            this.result.put("temperature_c", d);
            this.result.put("temperature_f", (d * 1.8d) + 32.0d);
            this.result.put("sensor_timestamp_ns", sensorEvent.timestamp);
            JSONObject jSONObject = this.result;
            int i = this.count + 1;
            this.count = i;
            jSONObject.put("event_count", i);
            if (this.count >= 1) {
                finishReport("ok");
            }
        } catch (Exception e) {
            finishReport("serialization_failed");
        }
    }

    @Override // android.hardware.SensorEventListener
    public void onAccuracyChanged(Sensor sensor, int i) {
    }

    private void finishReport(String str) {
        if (this.done) {
            return;
        }
        this.done = true;
        this.handler.removeCallbacksAndMessages(null);
        if (this.manager != null) {
            this.manager.unregisterListener(this);
        }
        try {
            this.result.put("status", str);
            this.result.put("physical_calibration_verified", false);
            File file = new File(getFilesDir(), "sensor-status.json");
            File file2 = new File(getFilesDir(), "sensor-status.json.tmp");
            FileOutputStream fileOutputStream = new FileOutputStream(file2);
            try {
                fileOutputStream.write(this.result.toString(2).getBytes(StandardCharsets.UTF_8));
                fileOutputStream.getFD().sync();
                fileOutputStream.close();
                if (!file2.renameTo(file)) {
                    throw new Exception("atomic rename failed");
                }
                finish();
            } catch (Throwable th) {
                try {
                    fileOutputStream.close();
                } catch (Throwable th2) {
                    th.addSuppressed(th2);
                }
                throw th;
            }
        } catch (Exception e) {
            Log.e("TTSensorProbe", "report failed", e);
        }
    }

    @Override // android.app.Activity
    public void onDestroy() {
        this.handler.removeCallbacksAndMessages(null);
        if (this.manager != null) {
            this.manager.unregisterListener(this);
        }
        super.onDestroy();
    }
}
