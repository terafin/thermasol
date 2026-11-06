package com.thermasol.touchsteam2.util;

import android.app.Activity;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.ServiceConnection;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.content.res.Resources;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.ColorMatrix;
import android.graphics.ColorMatrixColorFilter;
import android.graphics.Paint;
import android.graphics.drawable.Drawable;
import android.media.AudioManager;
import android.net.Uri;
import android.net.wifi.WifiManager;
import android.os.Build;
import android.os.Environment;
import android.os.IBinder;
import android.provider.Settings;
import android.util.Log;
import android.util.TypedValue;
import android.view.View;
import android.view.Window;
import androidx.appcompat.app.AppCompatDelegate;
import androidx.core.content.FileProvider;
import androidx.preference.PreferenceManager;
import com.google.gson.Gson;
import com.thermasol.thermatouchservice.IHardwareService;
import com.thermasol.touchsteam2.GV;
import com.thermasol.touchsteam2.LocalConstants;
import com.thermasol.touchsteam2.R;
import com.thermasol.touchsteam2.activities.MainControl;
import com.thermasol.touchsteam2.activities.VideoPlayerActivity;
import com.thermasol.touchsteam2.comm.HardwareServicePersist;
import com.thermasol.touchsteam2.fragments.DigitalShowerScreenFragment;
import com.thermasol.touchsteam2.fragments.OverheadLightFragment;
import com.thermasol.touchsteam2.fragments.overhead.ChromaLightFragment;
import com.thermasol.touchsteam2.services.SimulatedHardwareService;
import com.thermasol.touchsteam2.shared.IHardwareTouchingContext;
import com.thermasol.utils.AppDetail;
import com.thermasol.utils.ServerResponse;
import com.thermasol.utils.SystemConstants;
import com.thermasol.utils.Utility;
import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.ByteArrayOutputStream;
import java.io.CharArrayReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileWriter;
import java.io.IOException;
import java.io.InputStreamReader;
import java.math.BigInteger;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.TimeUnit;
import org.eclipse.paho.client.mqttv3.MqttTopic;

/* JADX INFO: loaded from: classes2.dex */
public class Utils {
    private static final int REQUEST_TRUST_EXTERNAL_SOURCE = 1;
    private static List<AppDetail> mDetails = new ArrayList();

    public static boolean AndroidBluetoothSupported() {
        return false;
    }

    public static void handleException(Exception e) {
    }

    public static class ExecutionResult {
        private int mResult = -1;
        private String mOutput = "";

        static /* synthetic */ String access$184(ExecutionResult executionResult, Object obj) {
            String str = executionResult.mOutput + obj;
            executionResult.mOutput = str;
            return str;
        }

        public int getResult() {
            return this.mResult;
        }

        public String getOutput() {
            return this.mOutput;
        }
    }

    public static ExecutionResult sendLinuxCommand(String command) {
        ExecutionResult executionResult = new ExecutionResult();
        try {
            Process processExec = Runtime.getRuntime().exec(command);
            if (processExec != null) {
                executionResult.mResult = processExec.waitFor();
                BufferedReader bufferedReader = new BufferedReader(new InputStreamReader(processExec.getInputStream()));
                ExecutionResult.access$184(executionResult, bufferedReader.readLine());
                bufferedReader.close();
                processExec.destroy();
            }
        } catch (IOException e) {
            if (e.toString().contains("Try again")) {
                sendLinuxCommand(command);
            }
        } catch (Exception e2) {
            e2.printStackTrace();
        }
        return executionResult;
    }

    public static int getHardwareRevision(Context context) {
        return IsSevenInch(context) ? 2 : 1;
    }

    public static int BoundsCheck(int ivalue, int minvalue, int maxvalue) {
        return ivalue > maxvalue ? maxvalue : Math.max(ivalue, minvalue);
    }

    /* JADX WARN: Failed to restore switch over string. Please report as a decompilation issue */
    public static void playVideo(MainControl activity, String videoPath, String videoName, boolean demo) {
        String str = videoPath + MqttTopic.TOPIC_LEVEL_SEPARATOR + videoName;
        File file = new File(str);
        videoName.hashCode();
        boolean z = true;
        byte b = -1;
        switch (videoName.hashCode()) {
            case -553084883:
                if (videoName.equals(ChromaLightFragment.BLUE_VIDEO)) {
                    b = 0;
                }
                break;
            case -111710766:
                if (videoName.equals(ChromaLightFragment.VIOLET_VIDEO)) {
                    b = 1;
                }
                break;
            case 0:
                if (videoName.equals("")) {
                    b = 2;
                }
                break;
            case 195898038:
                if (videoName.equals(ChromaLightFragment.GREEN_VIDEO)) {
                    b = 3;
                }
                break;
            case 205396918:
                if (videoName.equals(LocalConstants.MOOD_VIDEO)) {
                    b = 4;
                }
                break;
            case 1070567425:
                if (videoName.equals(ChromaLightFragment.ORANGE_VIDEO)) {
                    b = 5;
                }
                break;
            case 1589197639:
                if (videoName.equals(ChromaLightFragment.YELLOW_VIDEO)) {
                    b = 6;
                }
                break;
            case 1633823044:
                if (videoName.equals(ChromaLightFragment.RED_VIDEO)) {
                    b = 7;
                }
                break;
            case 1689679525:
                if (videoName.equals(ChromaLightFragment.INDIGO_VIDEO)) {
                    b = 8;
                }
                break;
        }
        float f = 1.0f;
        switch (b) {
            case 4:
                f = 0.3333f;
            case 0:
            case 1:
            case 2:
            case 3:
            case 5:
            case 6:
            case 7:
            case 8:
                z = false;
                break;
        }
        if (z) {
            PersistPauseAndKillBluetooth(activity);
        }
        Intent intent = new Intent(activity, (Class<?>) VideoPlayerActivity.class);
        if (file.exists()) {
            intent.setData(Uri.parse(str));
        } else {
            intent.setData(Uri.parse("android.resource://" + activity.getPackageName() + MqttTopic.TOPIC_LEVEL_SEPARATOR + R.raw.video_not_found));
        }
        intent.putExtra("demo", demo);
        intent.putExtra("speed", f);
        activity.getLauncher().launch(intent);
    }

    public static boolean isOnline() {
        return sendLinuxCommand("/system/bin/ping -c 1 -W 1 8.8.8.8").getResult() == 0;
    }

    public static boolean isVantron() {
        return Build.DEVICE.equals("ipc_rk66_tms");
    }

    public static String computeAndReturnDeviceId(Context context) {
        String strSubstring = new BigInteger(Settings.Secure.getString(context.getContentResolver(), "android_id"), 16).toString(21).substring(0, 6);
        int coreCount = CoreCountProvider.getInstance().getCoreCount();
        if (coreCount == 1) {
            return strSubstring + "s";
        }
        if (coreCount != 2) {
            return coreCount != 4 ? strSubstring : strSubstring + "q";
        }
        return strSubstring + "d";
    }

    public static boolean IsSevenInch(Context context) {
        return context.getResources().getDisplayMetrics().widthPixels <= 1000;
    }

    /* JADX WARN: Multi-variable type inference failed */
    public static boolean IsLightTypeHv(Context context) {
        return OverheadLight.getType(((IHardwareTouchingContext) context).getInstance()) == OverheadLight.LightType.HVLSR;
    }

    /* JADX WARN: Multi-variable type inference failed */
    public static String GetBluetoothDeviceName(Context context) {
        HardwareServicePersist iHardwareTouchingContext = ((IHardwareTouchingContext) context).getInstance();
        if (AndroidBluetoothSupported()) {
            try {
                return iHardwareTouchingContext.getMNative().getConnectedDeviceInfo();
            } catch (Exception e) {
                handleException(e);
            }
        } else {
            iHardwareTouchingContext.slsr_request_sls_stats();
            if (OverheadLight.bluetoothIsPresent(context)) {
                int bluetoothState = OverheadLight.getBluetoothState(context);
                if (bluetoothState == 1) {
                    return context.getResources().getString(R.string.ready_to_pair);
                }
                if (bluetoothState == 2) {
                    return OverheadLight.bluetoothGetDeviceName(context);
                }
            }
        }
        return "";
    }

    /* JADX WARN: Multi-variable type inference failed */
    public static long GetBluetoothTimestamp(Context context) {
        HardwareServicePersist iHardwareTouchingContext = ((IHardwareTouchingContext) context).getInstance();
        if (AndroidBluetoothSupported()) {
            try {
                return iHardwareTouchingContext.getMNative().getPacketTimestamp();
            } catch (Exception e) {
                handleException(e);
            }
        } else if (OverheadLight.getBluetoothState(context) == 2) {
            return System.currentTimeMillis();
        }
        return 0L;
    }

    /* JADX WARN: Multi-variable type inference failed */
    public static void StartBluetooth(Context context) {
        int i = 1;
        FirebaseAnalyticEvents.logEvent(context, "bluetooth_session", "start_bluetooth", (Number) 1);
        PreferenceManager.getDefaultSharedPreferences(context).edit().putBoolean(LocalConstants.BLUETOOTH_STATE_KEY, true).apply();
        HardwareServicePersist iHardwareTouchingContext = ((IHardwareTouchingContext) context).getInstance();
        if (AndroidBluetoothSupported()) {
            try {
                iHardwareTouchingContext.getMNative().startBluetooth();
            } catch (Exception e) {
                handleException(e);
            }
        } else {
            i = 2;
        }
        toggleMusicAndSource(context, i);
    }

    /* JADX WARN: Multi-variable type inference failed */
    public static void ToggleBluetooth(Context context, boolean enable) {
        HardwareServicePersist iHardwareTouchingContext = ((IHardwareTouchingContext) context).getInstance();
        if (AndroidBluetoothSupported()) {
            try {
                iHardwareTouchingContext.getMNative().toggleBluetooth(enable);
                return;
            } catch (Exception e) {
                handleException(e);
                return;
            }
        }
        if (enable) {
            OverheadLight.powerOnBluetooth(context);
        } else {
            OverheadLight.powerOffBluetooth(context);
        }
    }

    /* JADX WARN: Multi-variable type inference failed */
    public static void RemoveBluetoothDeviceBonds(Context context) {
        HardwareServicePersist iHardwareTouchingContext = ((IHardwareTouchingContext) context).getInstance();
        if (AndroidBluetoothSupported()) {
            try {
                iHardwareTouchingContext.getMNative().removeBluetoothDeviceBonds();
            } catch (Exception e) {
                handleException(e);
            }
        }
    }

    /* JADX WARN: Multi-variable type inference failed */
    public static boolean SendBluetoothAvrcpCommand(Context context, int command, int action) {
        try {
            boolean zSendAvrcpCommand = true;
            if (AndroidBluetoothSupported()) {
                zSendAvrcpCommand = ((IHardwareTouchingContext) context).getInstance().getMNative().sendAvrcpCommand(command, action);
            } else if (action == 1) {
                if (command == 68) {
                    OverheadLight.bluetoothPlay(context);
                } else if (command == 70) {
                    OverheadLight.bluetoothPause(context);
                } else if (command == 75) {
                    OverheadLight.bluetoothSkipForward(context);
                } else if (command == 76) {
                    OverheadLight.bluetoothSkipBack(context);
                }
            }
            return zSendAvrcpCommand;
        } catch (Exception e) {
            handleException(e);
            return false;
        }
    }

    public static void PauseBluetooth(Context context) {
        SendBluetoothAvrcpCommand(context, 70, 0);
        Utility.waitForHardwareReaction();
        SendBluetoothAvrcpCommand(context, 70, 1);
    }

    public static void PersistPauseAndKillBluetooth(Context context) {
        PersistBluetooth(context, false);
        PauseBluetooth(context);
        KillBluetooth(context);
    }

    public static void PersistBluetooth(Context context, boolean state) {
        PreferenceManager.getDefaultSharedPreferences(context).edit().putBoolean(LocalConstants.BLUETOOTH_STATE_KEY, state).apply();
    }

    /* JADX WARN: Multi-variable type inference failed */
    public static void KillBluetooth(Context context) {
        HardwareServicePersist iHardwareTouchingContext = ((IHardwareTouchingContext) context).getInstance();
        try {
            if (AndroidBluetoothSupported()) {
                iHardwareTouchingContext.getMNative().killBluetooth();
            } else if (OverheadLight.hasBluetoothCapability(iHardwareTouchingContext)) {
                OverheadLight.powerOffBluetooth(context);
                toggleMusicAndSource(context, 1);
            }
        } catch (Exception e) {
            handleException(e);
        }
    }

    /* JADX WARN: Multi-variable type inference failed */
    public static void TurnOnSteam(Context context) {
        HardwareServicePersist iHardwareTouchingContext = ((IHardwareTouchingContext) context).getInstance();
        toggleSteam(iHardwareTouchingContext, true);
        FirebaseAnalyticEvents.logEvent(context, MainControl.ANALYTICS_STEAM_SESSION_EVENT, "initial_temperature_set_point", Integer.valueOf(iHardwareTouchingContext.psb_get_psb_temperature_setpoint()));
        FirebaseAnalyticEvents.logEvent(context, MainControl.ANALYTICS_STEAM_SESSION_EVENT, "initial_timer_set_point", Integer.valueOf(iHardwareTouchingContext.psb_get_remaining_steam_time()));
        resetLightSettings(context);
    }

    /* JADX WARN: Multi-variable type inference failed */
    public static void TurnOffSteam(Context context) {
        HardwareServicePersist iHardwareTouchingContext = ((IHardwareTouchingContext) context).getInstance();
        int iPsb_get_remaining_steam_time = iHardwareTouchingContext.psb_get_remaining_steam_time();
        toggleSteam(iHardwareTouchingContext, false);
        iHardwareTouchingContext.psb_turn_off_steam();
        iHardwareTouchingContext.psb_set_load_user(GV.ActiveUser);
        if (iPsb_get_remaining_steam_time > 0) {
            iHardwareTouchingContext.psb_set_timer_setpoint(iPsb_get_remaining_steam_time);
        } else {
            iHardwareTouchingContext.psb_set_timer_setpoint(getRecoveryTimerSetpointForActiveUser(context));
        }
        resetLightSettings(context);
    }

    public static void handleHardwareError(Context context, int errors) {
        FirebaseAnalyticEvents.logEvent(context, "hardware_error", "errors", Integer.valueOf(errors));
        SharedPreferences.Editor editorEdit = PreferenceManager.getDefaultSharedPreferences(context).edit();
        editorEdit.putInt(MainControl.SYSTEM_ERRORS_KEY, errors);
        editorEdit.putInt(MainControl.REQUEST_LAYOUT_KEY, 6).commit();
    }

    /* JADX WARN: Multi-variable type inference failed */
    public static void resetLightSettings(final Context context) {
        final HardwareServicePersist iHardwareTouchingContext = ((IHardwareTouchingContext) context).getInstance();
        if (MainControl.getCurrentLayout() != 8) {
            new Thread(new Runnable() { // from class: com.thermasol.touchsteam2.util.-$$Lambda$Utils$svB1OsIIsCG0YV8NsWcI7JhBei4
                @Override // java.lang.Runnable
                public final void run() {
                    Utils.lambda$resetLightSettings$0(iHardwareTouchingContext, context);
                }
            }).start();
        }
    }

    static /* synthetic */ void lambda$resetLightSettings$0(HardwareServicePersist hardwareServicePersist, Context context) {
        hardwareServicePersist.slsr_voice_mute();
        loadLightSettings(context, GV.ActiveUser);
        try {
            Thread.sleep(5000L);
        } catch (Exception e) {
            handleException(e);
        }
        loadVoiceVolumeSettings(context, GV.ActiveUser);
    }

    private static Bitmap applyColorFilter(Bitmap original) {
        Bitmap bitmapCreateBitmap = Bitmap.createBitmap(original.getWidth(), original.getHeight(), Bitmap.Config.ARGB_8888);
        Canvas canvas = new Canvas(bitmapCreateBitmap);
        Paint paint = new Paint();
        ColorMatrix colorMatrix = new ColorMatrix();
        colorMatrix.setSaturation(0.5f);
        paint.setColorFilter(new ColorMatrixColorFilter(colorMatrix));
        canvas.drawBitmap(original, 0.0f, 0.0f, paint);
        return bitmapCreateBitmap;
    }

    public static byte[] captureViewImageData(Activity activity) {
        View decorView = activity.getWindow().getDecorView();
        decorView.setDrawingCacheEnabled(true);
        decorView.buildDrawingCache();
        Bitmap bitmapApplyColorFilter = applyColorFilter(decorView.getDrawingCache());
        decorView.setDrawingCacheEnabled(false);
        ByteArrayOutputStream byteArrayOutputStream = new ByteArrayOutputStream();
        bitmapApplyColorFilter.compress(Bitmap.CompressFormat.PNG, 100, byteArrayOutputStream);
        bitmapApplyColorFilter.recycle();
        return byteArrayOutputStream.toByteArray();
    }

    public static void InitializeThermaCan(HardwareServicePersist service) {
        service.thermacan_close();
        service.psb_set_error(0);
        service.psb_set_temperature_setpoint(90);
        service.psb_set_timer_setpoint(LocalConstants.DEFAULT_TIMER_SETPOINT);
        service.thermacan_open();
        service.psb_get_faststart_mode();
    }

    /* JADX WARN: Multi-variable type inference failed */
    public static void ShutdownAll(Context context) {
        HardwareServicePersist iHardwareTouchingContext = ((IHardwareTouchingContext) context).getInstance();
        /* From here until loadUserSettings() runs again, no unmute and no B6
         * volume frame may leave the panel: the ceiling unit unmutes on both,
         * and the point of shutting down is that the speaker goes quiet. */
        OverheadLight.sShutdownMuted = true;
        iHardwareTouchingContext.slsr_voice_mute();
        OverheadLight.mute(context);
        iHardwareTouchingContext.esv_turn_off();
        iHardwareTouchingContext.esv_clear_flow_counter();
        iHardwareTouchingContext.psb_turn_off_power_flush();
        try {
            iHardwareTouchingContext.getMNative().slsr_turn_off_light();
            iHardwareTouchingContext.getMNative().hvlsr_light_off();
            iHardwareTouchingContext.getMNative().hvlsr_bluetooth_disconnect();
        } catch (Exception e) {
            handleException(e);
        }
        Utility.waitForHardwareReaction();
        iHardwareTouchingContext.psb_user_logout();
        iHardwareTouchingContext.slsr_voice_mute();
        OverheadLight.mute(context);
        iHardwareTouchingContext.slsr_request_sls_standby();
        iHardwareTouchingContext.psb_turn_off_steam();
        PersistPauseAndKillBluetooth(context);
        ToggleBluetooth(context, false);
        /* Last word: everything above may have re-selected source or volume,
         * and any of those would have unmuted. Mute once more, now that nothing
         * further can run. */
        OverheadLight.mute(context);
    }

    private static String buildSteamPreferenceKey(HardwareServicePersist ThermaCan, String key) {
        return ThermaCan.psb_get_state() == 2 ? HardwareServicePersist.STEAM_KEY_PREFIX + key : key;
    }

    /* JADX WARN: Multi-variable type inference failed */
    public static Object getSteamBasedSetting(Context context, String key, Object defValue, Class<?> type) {
        SharedPreferences defaultSharedPreferences = PreferenceManager.getDefaultSharedPreferences(context);
        String strBuildSteamPreferenceKey = buildSteamPreferenceKey(((IHardwareTouchingContext) context).getInstance(), key);
        String string = type.toString();
        string.hashCode();
        if (string.equals("int")) {
            return Integer.valueOf(defaultSharedPreferences.getInt(strBuildSteamPreferenceKey + GV.ActiveUser, ((Integer) defValue).intValue()));
        }
        if (string.equals("class java.lang.String")) {
            return defaultSharedPreferences.getString(strBuildSteamPreferenceKey + GV.ActiveUser, (String) defValue);
        }
        Log.v("DEBUG_TYPE_DEF", type.toString());
        return null;
    }

    /* JADX WARN: Multi-variable type inference failed */
    public static void putSteamBasedSetting(Context context, String key, Object value, Class<?> type, boolean commit) {
        SharedPreferences.Editor editorEdit = PreferenceManager.getDefaultSharedPreferences(context).edit();
        String strBuildSteamPreferenceKey = buildSteamPreferenceKey(((IHardwareTouchingContext) context).getInstance(), key);
        String string = type.toString();
        string.hashCode();
        if (string.equals("int")) {
            editorEdit.putInt(strBuildSteamPreferenceKey + GV.ActiveUser, ((Integer) value).intValue());
        } else if (string.equals("class java.lang.String")) {
            editorEdit.putString(strBuildSteamPreferenceKey + GV.ActiveUser, (String) value);
        } else {
            Log.v("DEBUG_TYPE_DEF", type.toString());
        }
        if (commit) {
            editorEdit.commit();
        } else {
            editorEdit.apply();
        }
    }

    private static void delayMusicVolume(final Context context, final int volume, final int delay) {
        new Thread(new Runnable() { // from class: com.thermasol.touchsteam2.util.-$$Lambda$Utils$q_hQ287_rT8SvwrN8-OgSwqt7yA
            @Override // java.lang.Runnable
            public final void run() {
                Utils.lambda$delayMusicVolume$1(delay, context, volume);
            }
        }).start();
    }

    static /* synthetic */ void lambda$delayMusicVolume$1(int i, Context context, int i2) {
        try {
            Thread.sleep(i);
        } catch (Exception e) {
            handleException(e);
        }
        OverheadLight.setMasterVolume(context, i2);
    }

    /* JADX WARN: Multi-variable type inference failed */
    private static void setMusicSource(Context context, int requested) {
        if (OverheadLight.hasBluetoothCapability(((IHardwareTouchingContext) context).getInstance())) {
            if (requested == 1) {
                requested = 2;
            } else if (requested == 2) {
                requested = 1;
            }
        }
        OverheadLight.setSource(context, requested);
    }

    public static void toggleMusicAndSource(Context context, int source) {
        int i;
        SharedPreferences defaultSharedPreferences = PreferenceManager.getDefaultSharedPreferences(context);
        int i2 = defaultSharedPreferences.getInt(OverheadLight.MUSIC_VOLUME_KEY + GV.ActiveUser, 10);
        int i3 = defaultSharedPreferences.getInt(OverheadLight.MUSIC_SOURCE_KEY + GV.ActiveUser, 1);
        OverheadLight.mute(context);
        Utility.waitForHardwareReaction();
        OverheadLight.unmute(context);
        if (i3 != source && source == 1) {
            setMusicSource(context, source);
            i = 2000;
        } else {
            setMusicSource(context, source);
            i = 0;
        }
        delayMusicVolume(context, i2, i);
    }

    /* JADX WARN: Multi-variable type inference failed */
    public static void loadUserSettings(Context context, int user) {
        HardwareServicePersist iHardwareTouchingContext = ((IHardwareTouchingContext) context).getInstance();
        /* A user session is starting: release the shutdown mute so the volume
         * and source calls below can restore normal audio. */
        OverheadLight.sShutdownMuted = false;
        SharedPreferences defaultSharedPreferences = PreferenceManager.getDefaultSharedPreferences(context);
        GV.ActiveUser = BoundsCheck(user, 0, 2);
        setRoutedVolume(context, defaultSharedPreferences.getInt(OverheadLight.MUSIC_VOLUME_KEY + GV.ActiveUser, 10));
        OverheadLight.setTrebleVolume(context, defaultSharedPreferences.getInt(OverheadLight.TREBLE_FORMAT_KEY + GV.ActiveUser, OverheadLight.getDefaultTrebleVolume()));
        OverheadLight.setMidVolume(context, defaultSharedPreferences.getInt(OverheadLight.MID_FORMAT_KEY + GV.ActiveUser, OverheadLight.getDefaultMidVolume()));
        OverheadLight.setBassVolume(context, defaultSharedPreferences.getInt(OverheadLight.BASS_FORMAT_KEY + GV.ActiveUser, OverheadLight.getDefaultBassVolume(context)));
        iHardwareTouchingContext.psb_set_load_user(user);
        loadSteamSettings(context, user);
        loadOverheadLightSettings(context, user);
        toggleMusicAndSource(context, 1);
        if (iHardwareTouchingContext.esv_get_is_dongle_present()) {
            iHardwareTouchingContext.esv_turn_off();
        }
        defaultSharedPreferences.edit().putInt(MainControl.REQUEST_LAYOUT_KEY, 9).apply();
        iHardwareTouchingContext.getMTemperature();
        FirebaseAnalyticEvents.logEvent(context, "hardware", "hardware_revision", Integer.valueOf(getHardwareRevision(context)));
        try {
            FirebaseAnalyticEvents.logEvent(context, "hardware", "ethernet", Integer.valueOf(iHardwareTouchingContext.getMNative().networkInterfaceIsUp("eth0") && iHardwareTouchingContext.getMNative().getEthernetIpValue() != 0 ? 1 : 0));
            FirebaseAnalyticEvents.logEvent(context, "hardware", "wifi", Integer.valueOf(iHardwareTouchingContext.getMNative().networkInterfaceIsUp("wlan0") && ((WifiManager) context.getSystemService("wifi")).getConnectionInfo().getIpAddress() != 0 ? 1 : 0));
        } catch (Exception e) {
            handleException(e);
        }
    }

    /* JADX WARN: Multi-variable type inference failed */
    public static void loadLightSettings(Context context, int user) {
        boolean z = ((Integer) getSteamBasedSetting(context, OverheadLight.LIGHT_STATE_KEY, 0, Integer.TYPE)).intValue() == 1;
        int iIntValue = ((Integer) getSteamBasedSetting(context, OverheadLight.LIGHT_INTENSITY_KEY, 80, Integer.TYPE)).intValue();
        HardwareServicePersist iHardwareTouchingContext = ((IHardwareTouchingContext) context).getInstance();
        if (iHardwareTouchingContext.psb_get_is_psb_active()) {
            iHardwareTouchingContext.slsr_set_temperature_format(PreferenceManager.getDefaultSharedPreferences(context).getInt(HardwareServicePersist.TEMP_FORMAT_KEY + user, 0));
        }
        OverheadLight.setIntensity(context, iIntValue);
        if (z) {
            OverheadLight.turnOn(context);
        } else {
            OverheadLight.turnOff(context);
        }
        if (z) {
            int iIntValue2 = ((Integer) getSteamBasedSetting(context, OverheadLight.LIGHT_MODE_KEY, 1, Integer.TYPE)).intValue();
            OverheadLight.setMode(context, iIntValue2);
            if (iIntValue2 == 4) {
                OverheadLight.setChromaState(context, ((Integer) getSteamBasedSetting(context, OverheadLightFragment.LIGHT_CHROM_COLOR_KEY, 0, Integer.TYPE)).intValue());
            }
        }
    }

    /* JADX WARN: Multi-variable type inference failed */
    public static void loadVoiceVolumeSettings(Context context, int user) {
        HardwareServicePersist iHardwareTouchingContext = ((IHardwareTouchingContext) context).getInstance();
        SharedPreferences defaultSharedPreferences = PreferenceManager.getDefaultSharedPreferences(context);
        OverheadLight.LightType type = OverheadLight.getType(iHardwareTouchingContext);
        if (type == OverheadLight.LightType.SLSR_AUX || type == OverheadLight.LightType.SLSR_BLUETOOTH) {
            iHardwareTouchingContext.slsr_voice_mute();
            iHardwareTouchingContext.slsr_set_voice_volume(defaultSharedPreferences.getInt(HardwareServicePersist.VOICE_VOLUME_KEY + user, 10));
            iHardwareTouchingContext.slsr_voice_on_off(defaultSharedPreferences.getInt(new StringBuilder().append(HardwareServicePersist.VOICE_STATE_KEY).append(user).toString(), 0) == 1);
            iHardwareTouchingContext.slsr_voice_unmute();
        }
    }

    /* JADX WARN: Multi-variable type inference failed */
    private static void loadSteamSettings(Context context, int user) {
        HardwareServicePersist iHardwareTouchingContext = ((IHardwareTouchingContext) context).getInstance();
        if (iHardwareTouchingContext.psb_get_is_psb_active()) {
            iHardwareTouchingContext.psb_set_temperature_setpoint(PreferenceManager.getDefaultSharedPreferences(context).getInt(HardwareServicePersist.STEAM_TEMP_KEY + user, 90));
            iHardwareTouchingContext.psb_set_timer_setpoint(getRecoveryTimerSetpointForActiveUser(context));
        }
    }

    private static void loadOverheadLightSettings(Context context, int user) {
        if (OverheadLight.isActive(context)) {
            loadLightSettings(context, user);
            loadVoiceVolumeSettings(context, user);
        }
    }

    public static void toggleSteam(HardwareServicePersist ThermaCan, boolean on) {
        int iPsb_get_state = ThermaCan.psb_get_state();
        if (on) {
            if (iPsb_get_state == 2) {
                return;
            } else {
                ThermaCan.psb_turn_on_steam();
            }
        } else if (iPsb_get_state != 2) {
            return;
        } else {
            ThermaCan.psb_turn_off_steam();
        }
        while (ThermaCan.psb_get_state() == iPsb_get_state) {
            Utility.waitForHardwareReaction();
        }
    }

    public static void setRecoveryTimerSetpointForActiveUser(Context context, int setpoint) {
        SharedPreferences.Editor editorEdit = PreferenceManager.getDefaultSharedPreferences(context).edit();
        editorEdit.putInt(LocalConstants.RECOVERY_TIMER_SETPOINT_KEY + GV.ActiveUser, setpoint);
        editorEdit.apply();
    }

    public static int getRecoveryTimerSetpointForActiveUser(Context context) {
        return PreferenceManager.getDefaultSharedPreferences(context).getInt(LocalConstants.RECOVERY_TIMER_SETPOINT_KEY + GV.ActiveUser, LocalConstants.DEFAULT_TIMER_SETPOINT);
    }

    public static void changeOutputValveFromResource(HardwareServicePersist service, Context context, int resource) {
        DigitalShowerScreenFragment.PersistentStorageFixture persistentStorageFixture;
        if (resource == R.drawable.svg_rain_head) {
            persistentStorageFixture = DigitalShowerScreenFragment.PersistentStorageFixture.RAINHEAD;
        } else if (resource == R.drawable.svg_shower_head) {
            persistentStorageFixture = DigitalShowerScreenFragment.PersistentStorageFixture.SHOWERHEAD;
        } else if (resource == R.drawable.wand) {
            persistentStorageFixture = DigitalShowerScreenFragment.PersistentStorageFixture.HANDHELD;
        } else if (resource == R.drawable.svg_bathtub) {
            persistentStorageFixture = DigitalShowerScreenFragment.PersistentStorageFixture.BATH;
        } else if (resource == R.drawable.svg_bodyspray) {
            persistentStorageFixture = DigitalShowerScreenFragment.PersistentStorageFixture.BODYSPRAY;
        } else {
            persistentStorageFixture = DigitalShowerScreenFragment.PersistentStorageFixture.NOFIXTURE;
        }
        SharedPreferences defaultSharedPreferences = PreferenceManager.getDefaultSharedPreferences(context);
        String[] strArr = {"valve_0_drawable", "valve_1_drawable", "valve_2_drawable"};
        for (int i = 0; i < 3; i++) {
            if (defaultSharedPreferences.getInt(strArr[i], -1) == persistentStorageFixture.ordinal()) {
                service.esv_set_output(i);
                return;
            }
        }
    }

    public static void adjustFlow(HardwareServicePersist service, Context context, boolean increase) {
        int i = PreferenceManager.getDefaultSharedPreferences(context).getInt(HardwareServicePersist.SHOWER_FLOW_KEY + GV.ActiveUser, 1);
        service.esv_set_flow(BoundsCheck(increase ? i + 1 : i - 1, 0, 2));
    }

    public static void applyFullscreenOptions(Window window) {
        if (window == null) {
            return;
        }
        AppCompatDelegate.setDefaultNightMode(2);
        window.getDecorView().setSystemUiVisibility(4102);
    }

    public static List<AppDetail> parseServerResponse(Context context, File index, boolean filter) throws IOException {
        List<AppDetail> appDetails = Utility.buildAppsServerResponse(new BufferedReader(new InputStreamReader(new FileInputStream(index)))).getAppDetails();
        ArrayList arrayList = new ArrayList();
        for (int i = 0; i < appDetails.size(); i++) {
            AppDetail appDetail = appDetails.get(i);
            if (Utility.internalApp(appDetail)) {
                arrayList.add(appDetail);
            }
            try {
                context.getPackageManager().getApplicationInfo(appDetail.getPackageName(), 0);
            } catch (PackageManager.NameNotFoundException unused) {
                if (filter) {
                    arrayList.add(appDetail);
                }
            }
        }
        appDetails.removeAll(arrayList);
        return appDetails;
    }

    /* JADX WARN: Multi-variable type inference failed */
    public static void enableExternalApp(Context context, String packageName) {
        try {
            ((IHardwareTouchingContext) context).getInstance().getMNative().setApplicationEnabled(packageName, 1);
        } catch (Exception e) {
            handleException(e);
        }
    }

    /* JADX WARN: Multi-variable type inference failed */
    public static void killExternalApps(Context context, String ignore) {
        HardwareServicePersist iHardwareTouchingContext = ((IHardwareTouchingContext) context).getInstance();
        try {
            for (AppDetail appDetail : parseServerResponse(context, getAppListCacheFile(context), true)) {
                if (ignore != null && appDetail.getPackageName().equals(ignore)) {
                    iHardwareTouchingContext.getMNative().setApplicationEnabled(appDetail.getPackageName(), 1);
                } else {
                    iHardwareTouchingContext.getMNative().setApplicationEnabled(appDetail.getPackageName(), 2);
                }
            }
        } catch (Exception e) {
            handleException(e);
        }
    }

    public static void handleInstall(Context context, File file) {
        if (isVantron()) {
            sendLinuxCommand("pm install " + Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS) + MqttTopic.TOPIC_LEVEL_SEPARATOR + file.getName());
            return;
        }
        Intent intent = new Intent("android.intent.action.INSTALL_PACKAGE", FileProvider.getUriForFile(context, "com.thermasol.touchsteam2.fileprovider", file));
        intent.setFlags(1);
        context.startActivity(intent);
    }

    public static void promptUninstall(Context context, String packageName) {
        context.startActivity(new Intent("android.intent.action.DELETE", Uri.parse("package:" + packageName)));
    }

    public static void setA2dpDirection(Context context, boolean shouldSink) {
        if (Utility.knownDevice(Build.DEVICE)) {
            Intent intent = new Intent();
            intent.setComponent(new ComponentName("com.android.bluetooth", "com.android.bluetooth.a2dp.A2dpEnablingActivity"));
            intent.putExtra("sink_bt_audio", shouldSink);
            context.startActivity(intent);
        }
    }

    public static void setupAppInstallPermissions(Activity activity) {
        Intent intent = new Intent();
        intent.setAction("android.settings.MANAGE_UNKNOWN_APP_SOURCES");
        intent.setData(Uri.parse("package:" + activity.getPackageName()));
        try {
            activity.startActivityForResult(intent, 1);
        } catch (Exception e) {
            handleException(e);
        }
    }

    public static boolean shouldAttachSecondaryService(Context context) {
        return Utility.knownDevice(Build.DEVICE) && PreferenceManager.getDefaultSharedPreferences(context).getBoolean(LocalConstants.SIMULATION_KEY, false);
    }

    /* JADX WARN: Multi-variable type inference failed */
    public static void attachSecondaryService(Context context, IBinder service, ServiceConnection connection) {
        ((SimulatedHardwareService) ((IHardwareTouchingContext) context).getInstance().getMNative()).setSecondaryService(IHardwareService.Stub.asInterface(service), connection);
    }

    public static Intent buildServiceIntent() {
        Intent intent = new Intent();
        intent.setComponent(new ComponentName(SystemConstants.HARDWARE_SERVICE_PACKAGE, SystemConstants.HARDWARE_SERVICE_NAME));
        return intent;
    }

    public static int getBoundedVolume(int volume) {
        return BoundsCheck(volume, 0, 15);
    }

    /* JADX WARN: Multi-variable type inference failed */
    public static int setRoutedVolume(Context context, int volume) {
        boolean zLightConnected = false;
        int iBoundsCheck = BoundsCheck(volume, 0, 15);
        boolean z = PreferenceManager.getDefaultSharedPreferences(context).getBoolean(LocalConstants.SIMULATION_KEY, false);
        try {
            zLightConnected = ((SimulatedHardwareService) ((IHardwareTouchingContext) context).getInstance().getMNative()).lightConnected();
        } catch (Exception e) {
            handleException(e);
        }
        if (zLightConnected || (!z && OverheadLight.isActive(context))) {
            OverheadLight.setMasterVolume(context, iBoundsCheck);
        } else {
            setAndroidVolume(context, iBoundsCheck);
        }
        return iBoundsCheck;
    }

    public static void setAndroidVolume(Context context, int volume) {
        ((AudioManager) context.getSystemService("audio")).setStreamVolume(3, getAndroidVolumeInterval(context) * volume, 0);
        PreferenceManager.getDefaultSharedPreferences(context).edit().putInt(OverheadLight.MUSIC_VOLUME_KEY + GV.ActiveUser, volume).apply();
    }

    public static void updateAvailableAppData(Context context) {
        List<AppDetail> appDetails = getAppDetails(SystemConstants.M_APP_INDEX_KEY);
        ArrayList arrayList = new ArrayList();
        List<AppDetail> appDetails2 = getAppDetails(SystemConstants.Q_APP_INDEX_KEY);
        for (int i = 0; i < appDetails2.size(); i++) {
            for (int i2 = 0; i2 < appDetails.size(); i2++) {
                AppDetail appDetail = appDetails.get(i2);
                if (appDetail.getPackageName().equals(appDetails2.get(i).getPackageName())) {
                    arrayList.add(appDetail);
                }
            }
        }
        appDetails.removeAll(arrayList);
        appDetails.addAll(appDetails2);
        Gson gson = new Gson();
        ServerResponse serverResponse = new ServerResponse();
        serverResponse.setAppDetails(appDetails);
        try {
            File file = new File(context.getExternalFilesDir(Environment.DIRECTORY_DOCUMENTS), "combined.json");
            BufferedWriter bufferedWriter = new BufferedWriter(new FileWriter(file.toString()));
            bufferedWriter.write(gson.toJson(serverResponse));
            bufferedWriter.close();
            sendLinuxCommand("mv " + file.toString() + " " + getAppListCacheFile(context).toString());
        } catch (Exception e) {
            handleException(e);
        }
    }

    public static File getAppListCacheFile(Context context) {
        return new File(context.getExternalFilesDir(Environment.DIRECTORY_DOCUMENTS), LocalConstants.APP_CACHE_FILE);
    }

    public static String trimUserName(String name) {
        return name.substring(0, Math.min(name.length(), 9));
    }

    private static List<AppDetail> getAppDetails(String listing) {
        mDetails.clear();
        mDetails = Utility.buildAppsServerResponse(new BufferedReader(new CharArrayReader(new String(Utility.getVerifiableFromServer(SystemConstants.UPDATE_SERVER_PATH + listing).getBinary()).toCharArray()))).getAppDetails();
        return new ArrayList(mDetails);
    }

    public static String secondsToCountdown(int value) {
        String string = Long.valueOf(TimeUnit.SECONDS.toMinutes(value)).toString();
        if (string.length() == 1) {
            string = "0" + string;
        }
        String string2 = Integer.valueOf(value % 60).toString();
        if (string2.length() == 1) {
            string2 = "0" + string2;
        }
        return string + ":" + string2;
    }

    public static Drawable getUserThemedDrawable(Context context, Drawable drawable) {
        Resources.Theme themeNewTheme = context.getResources().newTheme();
        themeNewTheme.applyStyle(getUserTheme(context), true);
        drawable.applyTheme(themeNewTheme);
        return drawable;
    }

    public static int getUserThemeColor(Context context) {
        Resources.Theme themeNewTheme = context.getResources().newTheme();
        themeNewTheme.applyStyle(getUserTheme(context), true);
        TypedValue typedValue = new TypedValue();
        themeNewTheme.resolveAttribute(R.attr.theme_color, typedValue, true);
        return typedValue.data;
    }

    public static int generateSecondaryUserThemeColor(Context context) {
        float[] fArr = new float[3];
        Color.colorToHSV(getUserThemeColor(context), fArr);
        fArr[1] = fArr[1] * 0.7f;
        return Color.HSVToColor(fArr);
    }

    public static int getScaledSize(Resources resources, int baseSize) {
        return (int) (baseSize / ((800.0f - resources.getDimensionPixelSize(R.dimen.minimum_button_size)) / (resources.getDisplayMetrics().heightPixels / resources.getDisplayMetrics().density)));
    }

    public static int calculateFrameHeight(Resources resources, int menus) {
        return (resources.getDisplayMetrics().heightPixels - (resources.getDimensionPixelSize(R.dimen.nav_bar_height) * menus)) + resources.getDimensionPixelSize(R.dimen.minimum_button_size);
    }

    private static int getAndroidVolumeInterval(Context context) {
        return ((AudioManager) context.getSystemService("audio")).getStreamMaxVolume(3) / 15;
    }

    private static int getUserTheme(Context context) {
        int i = Integer.parseInt(PreferenceManager.getDefaultSharedPreferences(context).getString(LocalConstants.USER_THEME_KEY, "-1"));
        if (i == 0) {
            return R.style.YellowUserAppTheme;
        }
        if (i != 1) {
            return i != 2 ? R.style.DefaultUserAppTheme : R.style.BlueUserAppTheme;
        }
        return R.style.FushsiaUserAppTheme;
    }
}
