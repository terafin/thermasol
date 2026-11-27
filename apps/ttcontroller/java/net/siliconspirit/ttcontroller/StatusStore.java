package net.siliconspirit.ttcontroller;

import android.content.Context;
import android.os.Process;
import java.io.File;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;
import org.json.JSONObject;

final class StatusStore {
    private static final String COMPONENT = "net.siliconspirit.ttcontroller/.ControllerKeeperService";
    private static final String EXPECTED_DESCRIPTOR = "com.thermasol.thermatouchservice.IHardwareService";
    static final String FILE_NAME = "controller-keeper-status.json";
    private static final String TARGET_COMPONENT = "com.thermasol.thermatouchservice/com.thermasol.thermatouchservice.HardwareService";
    private int bindAttempts;
    private int connectedCount;
    private int deathCount;
    private final File dir;
    private int disconnectedCount;
    private final JSONObject status = new JSONObject();
    private final File target;

    StatusStore(Context context) {
        this.dir = context.getFilesDir();
        this.target = new File(this.dir, FILE_NAME);
        long jCurrentTimeMillis = System.currentTimeMillis();
        put("component", COMPONENT);
        put("target_component", TARGET_COMPONENT);
        put("target_intent", "explicit component only; no action");
        put("binder_descriptor_expected", EXPECTED_DESCRIPTOR);
        put("binder_descriptor_actual", "");
        put("binder_descriptor_verified", false);
        put("retry_delay_ms", Long.valueOf(BindingPolicy.RETRY_MS));
        put("pid", Integer.valueOf(Process.myPid()));
        put("state", "created");
        put("created_at_ms", Long.valueOf(jCurrentTimeMillis));
        flush(jCurrentTimeMillis);
    }

    synchronized String path() {
        return this.target.getAbsolutePath();
    }

    synchronized String read() {
        try {
            return this.status.toString(2);
        } catch (Throwable th) {
            return "{\"status\":\"render_failed\"}";
        }
    }

    synchronized void started() {
        long jCurrentTimeMillis = System.currentTimeMillis();
        put("state", "starting");
        put("started_at_ms", Long.valueOf(jCurrentTimeMillis));
        flush(jCurrentTimeMillis);
    }

    synchronized void bindAttempt() {
        long jCurrentTimeMillis = System.currentTimeMillis();
        this.bindAttempts++;
        put("state", "binding");
        put("bind_attempts", Integer.valueOf(this.bindAttempts));
        put("last_bind_attempt_ms", Long.valueOf(jCurrentTimeMillis));
        flush(jCurrentTimeMillis);
    }

    synchronized void bindError(String str) {
        if (str == null) {
            str = "";
        }
        put("last_bind_error", str);
    }

    synchronized void bindFailed() {
        long jCurrentTimeMillis = System.currentTimeMillis();
        put("state", "retry_wait");
        put("last_bind_failure_ms", Long.valueOf(jCurrentTimeMillis));
        flush(jCurrentTimeMillis);
    }

    synchronized void connected(String str, boolean z) {
        long jCurrentTimeMillis = System.currentTimeMillis();
        this.connectedCount++;
        put("state", "connected");
        if (str == null) {
            str = "";
        }
        put("binder_descriptor_actual", str);
        put("binder_descriptor_verified", Boolean.valueOf(z));
        put("connected_count", Integer.valueOf(this.connectedCount));
        put("last_connected_ms", Long.valueOf(jCurrentTimeMillis));
        flush(jCurrentTimeMillis);
    }

    synchronized void descriptorMismatch(String str) {
        long jCurrentTimeMillis = System.currentTimeMillis();
        put("state", "retry_wait");
        if (str == null) {
            str = "";
        }
        put("binder_descriptor_actual", str);
        put("binder_descriptor_verified", false);
        put("last_descriptor_mismatch_ms", Long.valueOf(jCurrentTimeMillis));
        flush(jCurrentTimeMillis);
    }

    synchronized void bindTimeout() {
        long jCurrentTimeMillis = System.currentTimeMillis();
        put("state", "retry_wait");
        put("last_bind_timeout_ms", Long.valueOf(jCurrentTimeMillis));
        flush(jCurrentTimeMillis);
    }

    synchronized void disconnected() {
        long jCurrentTimeMillis = System.currentTimeMillis();
        this.disconnectedCount++;
        put("state", "retry_wait");
        put("connected_count", Integer.valueOf(this.connectedCount));
        put("disconnected_count", Integer.valueOf(this.disconnectedCount));
        put("last_disconnected_ms", Long.valueOf(jCurrentTimeMillis));
        flush(jCurrentTimeMillis);
    }

    synchronized void binderDied() {
        long jCurrentTimeMillis = System.currentTimeMillis();
        this.deathCount++;
        put("state", "retry_wait");
        put("death_count", Integer.valueOf(this.deathCount));
        put("last_death_ms", Long.valueOf(jCurrentTimeMillis));
        flush(jCurrentTimeMillis);
    }

    synchronized void nullBinding() {
        long jCurrentTimeMillis = System.currentTimeMillis();
        put("state", "retry_wait");
        put("last_null_binding_ms", Long.valueOf(jCurrentTimeMillis));
        flush(jCurrentTimeMillis);
    }

    synchronized void retryScheduled(long j) {
        long jCurrentTimeMillis = System.currentTimeMillis();
        put("state", "retry_wait");
        put("last_retry_scheduled_ms", Long.valueOf(jCurrentTimeMillis));
        put("retry_delay_ms", Long.valueOf(j));
        flush(jCurrentTimeMillis);
    }

    synchronized void destroyed() {
        long jCurrentTimeMillis = System.currentTimeMillis();
        put("state", "destroyed");
        put("last_destroyed_ms", Long.valueOf(jCurrentTimeMillis));
        flush(jCurrentTimeMillis);
    }

    private void put(String str, Object obj) {
        try {
            this.status.put(str, obj);
        } catch (Throwable th) {
        }
    }

    private void flush(long j) {
        put("updated_at_ms", Long.valueOf(j));
        put("status_file", this.target.getAbsolutePath());
        File file = new File(this.dir, "controller-keeper-status.json.tmp");
        try {
            FileOutputStream fileOutputStream = new FileOutputStream(file);
            try {
                fileOutputStream.write(this.status.toString(2).getBytes(StandardCharsets.UTF_8));
                fileOutputStream.getFD().sync();
                fileOutputStream.close();
                if (!file.renameTo(this.target)) {
                    file.delete();
                }
            } catch (Throwable th) {
                try {
                    fileOutputStream.close();
                } catch (Throwable th2) {
                    th.addSuppressed(th2);
                }
                throw th;
            }
        } catch (Throwable th3) {
        }
    }
}
