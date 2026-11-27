package net.siliconspirit.ttstop;

import android.app.Activity;
import android.content.ComponentName;
import android.content.Intent;
import android.content.ServiceConnection;
import android.os.Bundle;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.os.Parcel;
import android.util.Log;
import java.io.File;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;
import org.json.JSONObject;

public final class StopActivity extends Activity implements ServiceConnection {
    private static final String DESCRIPTOR = "com.thermasol.thermatouchservice.IHardwareService";
    private boolean bound;
    private boolean done;
    private final Handler handler = new Handler(Looper.getMainLooper());
    private final JSONObject result = new JSONObject();
    private IBinder service;

    @Override // android.app.Activity
    public void onCreate(Bundle bundle) {
        super.onCreate(bundle);
        Intent component = new Intent().setComponent(new ComponentName("com.thermasol.thermatouchservice", "com.thermasol.thermatouchservice.HardwareService"));
        try {
            this.result.put("generated_ms", System.currentTimeMillis());
            this.result.put("energizing_commands", 0);
            this.result.put("stop_sent", false);
            this.bound = bindService(component, this, 0);
            if (this.bound) {
                this.handler.postDelayed(new Runnable() {
                    @Override // java.lang.Runnable
                    public final void run() {
                        StopActivity.this.m0lambda$onCreate$0$netsiliconspiritttstopStopActivity();
                    }
                }, 10000L);
            } else {
                finishReport("existing_service_not_bound");
            }
        } catch (Exception e) {
            finishReport("bind_error: " + String.valueOf(e));
        }
    }

    /* synthetic */ void m0lambda$onCreate$0$netsiliconspiritttstopStopActivity() {
        finishReport("timeout");
    }

    @Override // android.content.ServiceConnection
    public void onServiceConnected(ComponentName componentName, IBinder iBinder) {
        this.service = iBinder;
        try {
            if (!DESCRIPTOR.equals(this.service.getInterfaceDescriptor())) {
                throw new Exception("wrong binder");
            }
            int i = read(21);
            int i2 = read(20);
            int i3 = read(15);
            int i4 = read(28);
            this.result.put("before_state", i);
            this.result.put("before_errors", i2);
            this.result.put("before_steam_timer", i3);
            this.result.put("before_flush_timer", i4);
            if (i == 255 && i2 == 0 && i3 == 0 && i4 == 0) {
                call(8);
                this.result.put("stop_sent", true);
                this.handler.postDelayed(new Runnable() {
                    @Override // java.lang.Runnable
                    public final void run() {
                        StopActivity.this.m1x47f3df7();
                    }
                }, 1500L);
                return;
            }
            finishReport("precondition_not_standby");
        } catch (Exception e) {
            finishReport("command_error: " + String.valueOf(e));
        }
    }

    /* synthetic */ void m1x47f3df7() {
        try {
            int i = read(21);
            int i2 = read(20);
            int i3 = read(15);
            int i4 = read(28);
            this.result.put("after_state", i);
            this.result.put("after_errors", i2);
            this.result.put("after_steam_timer", i3);
            this.result.put("after_flush_timer", i4);
            finishReport((i == 255 && i2 == 0 && i3 == 0 && i4 == 0) ? "off_in_standby_no_reported_change" : "unexpected_controller_state");
        } catch (Exception e) {
            finishReport("query_error: " + String.valueOf(e));
        }
    }

    private int read(int i) throws Exception {
        if (i != 21 && i != 20 && i != 15 && i != 28) {
            throw new Exception("getter not allowed");
        }
        Parcel parcelObtain = Parcel.obtain();
        Parcel parcelObtain2 = Parcel.obtain();
        try {
            parcelObtain.writeInterfaceToken(DESCRIPTOR);
            if (!this.service.transact(i, parcelObtain, parcelObtain2, 0)) {
                throw new Exception("unhandled getter");
            }
            parcelObtain2.readException();
            int i2 = parcelObtain2.readInt();
            parcelObtain.recycle();
            parcelObtain2.recycle();
            return i2;
        } catch (Throwable th) {
            parcelObtain.recycle();
            parcelObtain2.recycle();
            throw th;
        }
    }

    private void call(int i) throws Exception {
        if (i != 8) {
            throw new Exception("command not allowed");
        }
        Parcel parcelObtain = Parcel.obtain();
        Parcel parcelObtain2 = Parcel.obtain();
        try {
            parcelObtain.writeInterfaceToken(DESCRIPTOR);
            if (!this.service.transact(i, parcelObtain, parcelObtain2, 0)) {
                throw new Exception("unhandled stop");
            }
            parcelObtain2.readException();
            parcelObtain.recycle();
            parcelObtain2.recycle();
        } catch (Throwable th) {
            parcelObtain.recycle();
            parcelObtain2.recycle();
            throw th;
        }
    }

    @Override // android.content.ServiceConnection
    public void onServiceDisconnected(ComponentName componentName) {
        this.service = null;
    }

    private void finishReport(String str) {
        if (this.done) {
            return;
        }
        this.done = true;
        this.handler.removeCallbacksAndMessages(null);
        try {
            this.result.put("status", str);
            this.result.put("physical_steam_stop_verified", false);
            File file = new File(getFilesDir(), "stop-status.json.tmp");
            File file2 = new File(getFilesDir(), "stop-status.json");
            FileOutputStream fileOutputStream = new FileOutputStream(file);
            try {
                fileOutputStream.write(this.result.toString(2).getBytes(StandardCharsets.UTF_8));
                fileOutputStream.getFD().sync();
                fileOutputStream.close();
                if (!file.renameTo(file2)) {
                    throw new Exception("rename failed");
                }
                if (this.bound) {
                    unbindService(this);
                    this.bound = false;
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
            Log.e("TTStop", "report failed", e);
        }
    }

    @Override // android.app.Activity
    public void onDestroy() {
        this.handler.removeCallbacksAndMessages(null);
        if (this.bound) {
            unbindService(this);
            this.bound = false;
        }
        super.onDestroy();
    }
}
