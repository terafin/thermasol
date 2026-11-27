package net.siliconspirit.ttcontroller;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Service;
import android.content.ComponentName;
import android.content.Intent;
import android.content.ServiceConnection;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.util.Log;
import java.io.FileDescriptor;
import java.io.PrintWriter;

public final class ControllerKeeperService extends Service implements ServiceConnection {
    static final String CHANNEL_ID = "controller_keeper";
    private static final long CONNECT_TIMEOUT_MS = 5000;
    static final String EXPECTED_DESCRIPTOR = "com.thermasol.thermatouchservice.IHardwareService";
    static final int NOTIFICATION_ID = 1725;
    private static final long RETRY_MS = 5000;
    static final String TAG = "TTControllerKeeper";
    static final String TARGET_CLASS = "com.thermasol.thermatouchservice.HardwareService";
    static final String TARGET_PACKAGE = "com.thermasol.thermatouchservice";
    private boolean bound;
    private boolean connectTimeoutScheduled;
    private boolean retryScheduled;
    private StatusStore status;
    private final Handler handler = new Handler(Looper.getMainLooper());
    private final BindingPolicy policy = new BindingPolicy();
    private final Runnable retryTick = new Runnable() {
        @Override // java.lang.Runnable
        public void run() {
            ControllerKeeperService.this.retryScheduled = false;
            ControllerKeeperService.this.apply(ControllerKeeperService.this.policy.retryElapsed());
        }
    };
    private final Runnable connectTimeout = new Runnable() {
        @Override // java.lang.Runnable
        public void run() {
            ControllerKeeperService.this.connectTimeoutScheduled = false;
            Log.w(ControllerKeeperService.TAG, "binding callback timeout");
            ControllerKeeperService.this.status.bindTimeout();
            ControllerKeeperService.this.apply(ControllerKeeperService.this.policy.bindTimedOut());
        }
    };

    @Override // android.app.Service
    public void onCreate() {
        super.onCreate();
        this.status = new StatusStore(this);
    }

    @Override // android.app.Service
    public int onStartCommand(Intent intent, int i, int i2) {
        startInForeground();
        this.status.started();
        apply(this.policy.start());
        return 1;
    }

    @Override // android.app.Service
    public IBinder onBind(Intent intent) {
        return null;
    }

    public void apply(BindingPolicy.Action action) {
        switch (action) {
            case BIND:
                cancelRetry();
                doBind();
                break;
            case UNBIND_THEN_BIND:
                cancelRetry();
                doUnbind();
                doBind();
                break;
            case UNBIND_AND_SCHEDULE_RETRY:
                cancelRetry();
                doUnbind();
                scheduleRetry();
                break;
            case SCHEDULE_RETRY:
                scheduleRetry();
                break;
            case CANCEL_RETRY:
                cancelRetry();
                break;
            case CANCEL_RETRY_AND_UNBIND:
                cancelRetry();
                doUnbind();
                break;
        }
    }

    private void doBind() {
        boolean zBindService;
        Intent component = new Intent().setComponent(new ComponentName(TARGET_PACKAGE, TARGET_CLASS));
        this.status.bindAttempt();
        try {
            zBindService = bindService(component, this, 65);
        } catch (Throwable th) {
            Log.e(TAG, "bindService threw", th);
            this.status.bindError(String.valueOf(th));
            zBindService = false;
        }
        this.bound = zBindService;
        if (!zBindService) {
            Log.e(TAG, "bindService returned false for com.thermasol.thermatouchservice/com.thermasol.thermatouchservice.HardwareService");
            this.status.bindFailed();
            apply(this.policy.bindFailed());
        } else {
            Log.i(TAG, "binding com.thermasol.thermatouchservice/com.thermasol.thermatouchservice.HardwareService");
            scheduleConnectTimeout();
        }
    }

    private void doUnbind() {
        cancelConnectTimeout();
        if (this.bound) {
            try {
                unbindService(this);
                Log.i(TAG, "unbound com.thermasol.thermatouchservice/com.thermasol.thermatouchservice.HardwareService");
            } catch (Throwable th) {
                Log.e(TAG, "unbindService failed", th);
            }
            this.bound = false;
        }
    }

    private void scheduleRetry() {
        if (this.retryScheduled) {
            return;
        }
        this.retryScheduled = true;
        this.handler.postDelayed(this.retryTick, BindingPolicy.RETRY_MS);
        this.status.retryScheduled(BindingPolicy.RETRY_MS);
        Log.i(TAG, "retry scheduled in 5000 ms");
    }

    private void cancelRetry() {
        if (this.retryScheduled) {
            this.handler.removeCallbacks(this.retryTick);
            this.retryScheduled = false;
        }
    }

    private void scheduleConnectTimeout() {
        cancelConnectTimeout();
        this.connectTimeoutScheduled = true;
        this.handler.postDelayed(this.connectTimeout, BindingPolicy.RETRY_MS);
    }

    private void cancelConnectTimeout() {
        if (this.connectTimeoutScheduled) {
            this.handler.removeCallbacks(this.connectTimeout);
            this.connectTimeoutScheduled = false;
        }
    }

    @Override // android.content.ServiceConnection
    public void onServiceConnected(ComponentName componentName, IBinder iBinder) {
        cancelConnectTimeout();
        String interfaceDescriptor = null;
        if (iBinder != null) {
            try {
                interfaceDescriptor = iBinder.getInterfaceDescriptor();
            } catch (Throwable th) {
                Log.e(TAG, "descriptor read failed", th);
            }
        }
        boolean zEquals = EXPECTED_DESCRIPTOR.equals(interfaceDescriptor);
        this.bound = true;
        if (zEquals) {
            this.status.connected(interfaceDescriptor, true);
            Log.i(TAG, "binder connected descriptor=" + interfaceDescriptor);
            apply(this.policy.connected());
        } else {
            this.status.descriptorMismatch(interfaceDescriptor);
            Log.w(TAG, "binder descriptor mismatch actual=" + interfaceDescriptor + " expected=com.thermasol.thermatouchservice.IHardwareService; unbinding and backing off");
            apply(this.policy.descriptorMismatch());
        }
    }

    @Override // android.content.ServiceConnection
    public void onServiceDisconnected(ComponentName componentName) {
        cancelConnectTimeout();
        Log.w(TAG, "service disconnected " + String.valueOf(componentName));
        this.status.disconnected();
        apply(this.policy.disconnected());
    }

    @Override // android.content.ServiceConnection
    public void onBindingDied(ComponentName componentName) {
        cancelConnectTimeout();
        Log.w(TAG, "binding died " + String.valueOf(componentName));
        this.status.binderDied();
        apply(this.policy.binderDied());
    }

    @Override // android.content.ServiceConnection
    public void onNullBinding(ComponentName componentName) {
        cancelConnectTimeout();
        Log.w(TAG, "null binding " + String.valueOf(componentName));
        this.status.nullBinding();
        apply(this.policy.nullBinding());
    }

    @Override // android.app.Service
    public void onDestroy() {
        this.handler.removeCallbacksAndMessages(null);
        this.retryScheduled = false;
        this.connectTimeoutScheduled = false;
        this.status.destroyed();
        apply(this.policy.destroy());
        super.onDestroy();
    }

    private void startInForeground() {
        NotificationManager notificationManager = (NotificationManager) getSystemService("notification");
        NotificationChannel notificationChannel = new NotificationChannel(CHANNEL_ID, "Controller link", 2);
        notificationChannel.setSound(null, null);
        notificationChannel.enableVibration(false);
        notificationChannel.setShowBadge(false);
        notificationManager.createNotificationChannel(notificationChannel);
        Notification notificationBuild = new Notification.Builder(this, CHANNEL_ID).setSmallIcon(android.R.drawable.stat_notify_sync).setContentTitle("Shower controller link").setContentText("Maintaining the controller connection").setOngoing(true).setShowWhen(false).setCategory("service").build();
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(NOTIFICATION_ID, notificationBuild, 1073741824);
        } else {
            startForeground(NOTIFICATION_ID, notificationBuild);
        }
    }

    @Override // android.app.Service
    protected void dump(FileDescriptor fileDescriptor, PrintWriter printWriter, String[] strArr) {
        printWriter.println("component=com.thermasol.thermatouchservice/com.thermasol.thermatouchservice.HardwareService");
        if (this.status == null) {
            printWriter.println("status=unavailable");
            return;
        }
        printWriter.println("status_file=" + this.status.path());
        printWriter.println(this.status.read());
    }
}
