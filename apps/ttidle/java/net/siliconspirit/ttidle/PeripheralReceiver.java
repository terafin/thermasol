package net.siliconspirit.ttidle;

import android.content.BroadcastReceiver;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.ServiceConnection;
import android.content.SharedPreferences;
import android.media.AudioPlaybackConfiguration;
import android.media.IAudioService;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.os.Parcel;
import android.os.ServiceManager;
import android.os.SystemClock;
import android.util.Log;
import java.io.File;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;

public final class PeripheralReceiver extends BroadcastReceiver {
    @Override // android.content.BroadcastReceiver
    public void onReceive(Context context, Intent intent) {
        new Worker(context.getApplicationContext(), goAsync()).start(intent);
    }

    static final class Worker implements ServiceConnection {
        private static final String DESCRIPTOR = "com.thermasol.thermatouchservice.IHardwareService";
        private boolean bound;
        private final Context context;
        private boolean finished;
        private final Handler handler = new Handler(Looper.getMainLooper());
        private IBinder hardware;
        private String operation;
        private final BroadcastReceiver.PendingResult pending;
        private Intent request;

        Worker(Context context, BroadcastReceiver.PendingResult pendingResult) {
            this.context = context;
            this.pending = pendingResult;
        }

        public void start(Intent intent) {
            this.request = intent;
            this.operation = intent == null ? null : intent.getAction();
            if (!"net.siliconspirit.ttidle.STANDBY".equals(this.operation) && !"net.siliconspirit.ttidle.STATUS".equals(this.operation) && !"net.siliconspirit.ttidle.OFF".equals(this.operation) && !"net.siliconspirit.ttidle.RESUME".equals(this.operation)) {
                finish("invalid_action");
                return;
            }
            try {
                this.bound = this.context.bindService(new Intent("com.thermasol.thermatouchservice.HardwareService").setComponent(new ComponentName("com.thermasol.thermatouchservice", "com.thermasol.thermatouchservice.HardwareService")), this, 1);
                if (this.bound) {
                    this.handler.postDelayed(new Runnable() {
                        @Override // java.lang.Runnable
                        public final void run() {
                            Worker.this.m0xc7c9aece();
                        }
                    }, 5000L);
                } else {
                    finish("existing_controller_unavailable");
                }
            } catch (Exception e) {
                finish("bind_error:" + String.valueOf(e));
            }
        }

        /* synthetic */ void m0xc7c9aece() {
            finish("bind_timeout");
        }

        @Override // android.content.ServiceConnection
        public void onServiceConnected(ComponentName componentName, IBinder iBinder) {
            if (this.finished) {
                return;
            }
            this.hardware = iBinder;
            try {
                if (!DESCRIPTOR.equals(iBinder.getInterfaceDescriptor())) {
                    throw new Exception("wrong_controller");
                }
                IAudioService iAudioServiceAsInterface = IAudioService.Stub.asInterface(ServiceManager.getService("audio"));
                if (iAudioServiceAsInterface == null) {
                    throw new Exception("no_audio_service");
                }
                List activePlaybackConfigurations = iAudioServiceAsInterface.getActivePlaybackConfigurations();
                if (activePlaybackConfigurations == null) {
                    throw new Exception("unknown_playback");
                }
                Iterator it = activePlaybackConfigurations.iterator();
                boolean z = false;
                while (it.hasNext()) {
                    if (((AudioPlaybackConfiguration) it.next()).getPlayerState() == 2) {
                        z = true;
                    }
                }
                if ("net.siliconspirit.ttidle.STATUS".equals(this.operation)) {
                    finish("playback_known=" + z + "_controller_present=" + read(91));
                    return;
                }
                Map<String, String> status = readStatus();
                boolean z2 = IdlePeripheralPolicy.fresh(SystemClock.uptimeMillis(), Long.parseLong(status.get("heartbeat_ms")), 5000L) && "dim".equals(status.get("state")) && "idle".equals(status.get("playback")) && "1".equals(status.get("input_open")) && status.get("boot_id") != null;
                SharedPreferences sharedPreferences = this.context.getSharedPreferences("ownership", 0);
                boolean z3 = sharedPreferences.getBoolean("muted_by_idle", false);
                String stringExtra = this.request.getStringExtra("cycle_id");
                boolean z4 = (stringExtra == null || stringExtra.equals(sharedPreferences.getString("completed_cycle", null))) ? false : true;
                IdlePeripheralPolicy.Action next = new IdlePeripheralPolicy(z3).next(true, z2, z);
                if ("net.siliconspirit.ttidle.STANDBY".equals(this.operation) && z2 && !z) {
                    if (read(91) != 1) {
                        throw new Exception("HydroVive_not_present");
                    }
                    call(38);
                    finish("speaker_standby_command_sent");
                } else if ("net.siliconspirit.ttidle.OFF".equals(this.operation) && z2 && !z && (z4 || !z3 || !sharedPreferences.getBoolean("light_off_completed", false) || !sharedPreferences.getBoolean("speaker_standby_completed", false))) {
                    if (read(91) == 1) {
                        call(98);
                        if (sharedPreferences.edit().putBoolean("muted_by_idle", true).putBoolean("light_off_completed", false).putBoolean("speaker_standby_completed", false).commit()) {
                            call(97);
                            if (sharedPreferences.edit().putBoolean("light_off_completed", true).commit()) {
                                call(38);
                                if (sharedPreferences.edit().putBoolean("speaker_standby_completed", true).putString("completed_cycle", stringExtra).commit()) {
                                    finish("idle_light_off_speaker_standby");
                                } else {
                                    throw new Exception("standby_commit_failed");
                                }
                            } else {
                                throw new Exception("light_commit_failed");
                            }
                        } else {
                            throw new Exception("ownership_commit_failed");
                        }
                    } else {
                        throw new Exception("HydroVive_not_present");
                    }
                } else if (!"net.siliconspirit.ttidle.RESUME".equals(this.operation) || next != IdlePeripheralPolicy.Action.UNMUTE) {
                    finish("no_action_required");
                } else if (read(91) == 1) {
                    call(99);
                    if (sharedPreferences.edit().putBoolean("muted_by_idle", false).putBoolean("light_off_completed", false).putBoolean("speaker_standby_completed", false).commit()) {
                        finish("media_resumed_owned_mute_cleared");
                    } else {
                        throw new Exception("ownership_commit_failed");
                    }
                } else {
                    throw new Exception("HydroVive_not_present");
                }
            } catch (Exception e) {
                finish("policy_error:" + String.valueOf(e));
            }
        }

        private Map<String, String> readStatus() throws Exception {
            long longExtra = this.request.getLongExtra("heartbeat_ms", -1L);
            String stringExtra = this.request.getStringExtra("boot_id");
            HashMap map = new HashMap();
            map.put("heartbeat_ms", Long.toString(longExtra));
            map.put("boot_id", stringExtra);
            map.put("state", this.request.getStringExtra("state"));
            map.put("playback", this.request.getStringExtra("playback"));
            map.put("input_open", this.request.getStringExtra("input_open"));
            return map;
        }

        private int read(int i) throws Exception {
            if (i != 91) {
                throw new Exception("getter_not_allowed");
            }
            Parcel parcelObtain = Parcel.obtain();
            Parcel parcelObtain2 = Parcel.obtain();
            try {
                parcelObtain.writeInterfaceToken(DESCRIPTOR);
                if (!this.hardware.transact(i, parcelObtain, parcelObtain2, 0)) {
                    throw new Exception("unhandled_getter");
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
            if (i != 38 && i != 97 && i != 98 && i != 99) {
                throw new Exception("command_not_allowed");
            }
            Parcel parcelObtain = Parcel.obtain();
            Parcel parcelObtain2 = Parcel.obtain();
            try {
                parcelObtain.writeInterfaceToken(DESCRIPTOR);
                if (!this.hardware.transact(i, parcelObtain, parcelObtain2, 0)) {
                    throw new Exception("unhandled_audio_light_command");
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
            this.hardware = null;
            finish("controller_disconnected");
        }

        private void finish(String str) {
            if (this.finished) {
                return;
            }
            this.finished = true;
            this.handler.removeCallbacksAndMessages(null);
            try {
                String str2 = "operation=" + this.operation + "\nstatus=" + str + "\nuptime_ms=" + SystemClock.uptimeMillis() + "\n";
                File file = new File(this.context.getFilesDir(), "status.tmp");
                FileOutputStream fileOutputStream = new FileOutputStream(file);
                try {
                    fileOutputStream.write(str2.getBytes(StandardCharsets.UTF_8));
                    fileOutputStream.getFD().sync();
                    fileOutputStream.close();
                    if (!file.renameTo(new File(this.context.getFilesDir(), "status"))) {
                        throw new Exception("report_rename");
                    }
                } catch (Throwable th) {
                    try {
                        fileOutputStream.close();
                        throw th;
                    } catch (Throwable th2) {
                        th.addSuppressed(th2);
                        throw th;
                    }
                }
            } catch (Exception e) {
                Log.e("TTIdlePeripheral", "report", e);
            }
            if (this.bound) {
                this.context.unbindService(this);
                this.bound = false;
            }
            this.pending.finish();
        }
    }
}
