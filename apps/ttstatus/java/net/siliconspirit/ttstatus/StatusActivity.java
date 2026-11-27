package net.siliconspirit.ttstatus;

import android.app.Activity;
import android.content.ComponentName;
import android.content.Intent;
import android.content.ServiceConnection;
import android.os.Bundle;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.os.Parcel;
import android.os.RemoteException;
import android.util.Log;
import android.view.ViewGroup;
import android.widget.ScrollView;
import android.widget.TextView;
import java.io.File;
import java.io.FileOutputStream;
import java.io.OutputStreamWriter;

public class StatusActivity extends Activity {
    private static final long BIND_TIMEOUT_MS = 15000;
    private static final String DESCRIPTOR = "com.thermasol.thermatouchservice.IHardwareService";
    private static final String OUT_NAME = "status.json";
    private static final String SVC_CLS = "com.thermasol.thermatouchservice.HardwareService";
    private static final String SVC_PKG = "com.thermasol.thermatouchservice";
    private static final String TAG = "TTStatus";
    private TextView mText;
    static final String[] Q_NAME = {"getServiceVersion", "psb_get_is_psb_active", "psb_get_errors", "psb_get_state", "psb_get_psb_temperature_setpoint", "psb_get_remaining_steam_time", "psb_get_psb_steam_timer", "psb_get_power_flush_timer", "psb_get_psb_run_hours", "esv_get_is_dongle_present", "esv_get_water_temperature", "slsr_is_active", "slsr_get_version", "slsr_is_slsr_bluetooth_present", "hvlsr_is_active", "hvlsr_get_fw_version", "hvlsr_get_bootloader_version"};
    static final int[] Q_CODE = {70, 19, 20, 21, 22, 24, 15, 28, 26, 36, 37, 54, 58, 90, 91, 114, 115};
    static final int K_STRING = 0;
    static final int K_BOOL = 2;
    static final int K_INT = 1;
    static final int[] Q_KIND = {K_STRING, K_BOOL, K_INT, K_INT, K_INT, K_INT, K_INT, K_INT, K_INT, K_BOOL, K_INT, K_BOOL, K_INT, K_BOOL, K_BOOL, K_INT, K_INT};
    private boolean mBound = false;
    private boolean mFinished = false;
    private String mSummary = "";
    private final Handler mHandler = new Handler(Looper.getMainLooper());
    private final Runnable mTimeout = new Runnable() {
        @Override // java.lang.Runnable
        public void run() {
            if (!StatusActivity.this.mFinished) {
                Log.w(StatusActivity.TAG, "bind timeout");
                StatusActivity.this.writeStatus(null, "timeout binding to com.thermasol.thermatouchservice");
                StatusActivity.this.finishOnce();
            }
        }
    };
    private final ServiceConnection mConn = new ServiceConnection() {
        @Override // android.content.ServiceConnection
        public void onServiceConnected(ComponentName componentName, IBinder iBinder) {
            StatusActivity.this.mBound = true;
            StatusActivity.this.writeStatus(StatusActivity.this.runQueries(iBinder), null);
            StatusActivity.this.finishOnce();
        }

        @Override // android.content.ServiceConnection
        public void onServiceDisconnected(ComponentName componentName) {
            StatusActivity.this.mBound = false;
        }
    };

    @Override // android.app.Activity
    protected void onCreate(Bundle bundle) {
        super.onCreate(bundle);
        this.mText = new TextView(this);
        this.mText.setText("shower-status-probe: binding com.thermasol.thermatouchservice/com.thermasol.thermatouchservice.HardwareService ...");
        ScrollView scrollView = new ScrollView(this);
        scrollView.addView(this.mText, new ViewGroup.LayoutParams(-1, -2));
        setContentView(scrollView);
        Intent intent = new Intent();
        intent.setComponent(new ComponentName(SVC_PKG, SVC_CLS));
        try {
            boolean zBindService = bindService(intent, this.mConn, K_INT);
            this.mHandler.postDelayed(this.mTimeout, BIND_TIMEOUT_MS);
            if (!zBindService) {
                Log.e(TAG, "bindService returned false");
                writeStatus(null, "bindService returned false for com.thermasol.thermatouchservice/com.thermasol.thermatouchservice.HardwareService");
                finishOnce();
            }
        } catch (Throwable th) {
            Log.e(TAG, "bindService threw", th);
            writeStatus(null, "bindService threw: " + String.valueOf(th));
            finishOnce();
        }
    }

    public String runQueries(IBinder iBinder) {
        StringBuilder sb = new StringBuilder(2048);
        StringBuilder sb2 = new StringBuilder();
        sb.append("{\n");
        sb.append("  \"probe\": \"net.siliconspirit.ttstatus\",\n");
        sb.append("  \"generated_ms\": ").append(System.currentTimeMillis()).append(",\n");
        sb.append("  \"service_component\": ").append(esc("com.thermasol.thermatouchservice/com.thermasol.thermatouchservice.HardwareService")).append(",\n");
        sb.append("  \"binder_descriptor\": ").append(esc(DESCRIPTOR)).append(",\n");
        sb.append("  \"read_only\": true,\n");
        sb.append("  \"mode\": \"getter-only\",\n");
        sb.append("  \"hardware_changed\": false,\n");
        sb.append("  \"safe_unsafe_calls\": false,\n");
        sb.append("  \"results\": [\n");
        for (int i = K_STRING; i < Q_NAME.length; i += K_INT) {
            long jNanoTime = System.nanoTime();
            String status;
            String value;
            Parcel data = Parcel.obtain();
            Parcel reply = Parcel.obtain();
            try {
                data.writeInterfaceToken(DESCRIPTOR);
                if (!iBinder.transact(Q_CODE[i], data, reply, K_STRING)) {
                    throw new RemoteException("transact returned false");
                }
                reply.readException();
                switch (Q_KIND[i]) {
                    case K_STRING:
                        value = esc(reply.readString());
                        break;
                    case K_BOOL:
                        value = reply.readInt() != 0 ? "true" : "false";
                        break;
                    case K_INT:
                    default:
                        value = Integer.toString(reply.readInt());
                        break;
                }
                status = "ok";
            } catch (Throwable th) {
                String message = th.getMessage();
                status = "error: " + th.getClass().getSimpleName() + (message == null ? "" : ": " + message);
                value = "null";
            } finally {
                reply.recycle();
                data.recycle();
            }
            long elapsedUs = (System.nanoTime() - jNanoTime) / 1000;
            sb.append("    {\"method\": ").append(esc(Q_NAME[i])).append(", \"id\": ").append(Q_CODE[i]).append(", \"kind\": ").append(esc(kindName(Q_KIND[i]))).append(", \"status\": ").append(esc(status)).append(", \"value\": ").append(value).append(", \"time_us\": ").append(elapsedUs).append("}");
            sb.append(i < Q_NAME.length - 1 ? "," : "").append("\n");
            sb2.append(Q_NAME[i]).append(" = ").append(value).append("  [").append(status).append(", ").append(elapsedUs).append("us]\n");
        }
        sb.append("  ]\n}\n");
        this.mSummary = sb2.toString();
        return sb.toString();
    }

    private static String kindName(int i) {
        switch (i) {
            case K_STRING /* 0 */:
                return "string";
            case K_INT /* 1 */:
            default:
                return "int";
            case K_BOOL /* 2 */:
                return "bool";
        }
    }

    public void writeStatus(String str, String str2) {
        if (str == null) {
            StringBuilder sb = new StringBuilder(512);
            sb.append("{\n");
            sb.append("  \"probe\": \"net.siliconspirit.ttstatus\",\n");
            sb.append("  \"generated_ms\": ").append(System.currentTimeMillis()).append(",\n");
            sb.append("  \"service_component\": ").append(esc("com.thermasol.thermatouchservice/com.thermasol.thermatouchservice.HardwareService")).append(",\n");
            sb.append("  \"binder_descriptor\": ").append(esc(DESCRIPTOR)).append(",\n");
            sb.append("  \"read_only\": true,\n");
            sb.append("  \"mode\": \"getter-only\",\n");
            sb.append("  \"hardware_changed\": false,\n");
            sb.append("  \"results\": [],\n");
            sb.append("  \"error\": ").append(esc(str2)).append("\n}\n");
            str = sb.toString();
        }
        File file = new File(getFilesDir(), OUT_NAME);
        try (FileOutputStream out = new FileOutputStream(file);
             OutputStreamWriter writer = new OutputStreamWriter(out, "UTF-8")) {
            writer.write(str);
            writer.flush();
            out.getFD().sync();
        } catch (Throwable th) {
            Log.e(TAG, "write failed", th);
        }
        Log.i(TAG, "wrote " + file.getAbsolutePath());
    }

    public void finishOnce() {
        if (this.mFinished) {
            return;
        }
        this.mFinished = true;
        this.mHandler.removeCallbacks(this.mTimeout);
        if (this.mText != null) {
            this.mText.setText("shower-status-probe: done\nfiles/status.json\n\n" + this.mSummary);
        }
        if (this.mBound) {
            try {
                unbindService(this.mConn);
            } catch (Throwable th) {
            }
            this.mBound = false;
        }
        finish();
    }

    private static String esc(String str) {
        if (str == null) {
            return "null";
        }
        StringBuilder sb = new StringBuilder(str.length() + K_BOOL);
        sb.append('\"');
        for (int i = K_STRING; i < str.length(); i += K_INT) {
            char cCharAt = str.charAt(i);
            switch (cCharAt) {
                case '\t':
                    sb.append("\\t");
                    break;
                case '\n':
                    sb.append("\\n");
                    break;
                case '\r':
                    sb.append("\\r");
                    break;
                case '\"':
                    sb.append("\\\"");
                    break;
                case '\\':
                    sb.append("\\\\");
                    break;
                default:
                    if (cCharAt < ' ') {
                        sb.append(String.format("\\u%04x", Integer.valueOf(cCharAt)));
                    } else {
                        sb.append(cCharAt);
                    }
                    break;
            }
        }
        sb.append('\"');
        return sb.toString();
    }
}
