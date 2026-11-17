package com.thermasol.touchsteam2.util;

import android.content.Context;
import android.content.SharedPreferences;
import android.os.RemoteException;
import androidx.core.app.NotificationCompat;
import androidx.core.content.ContextCompat;
import androidx.core.internal.view.SupportMenu;
import androidx.core.view.InputDeviceCompat;
import androidx.core.view.ViewCompat;
import androidx.preference.PreferenceManager;
import com.thermasol.touchsteam2.GV;
import com.thermasol.touchsteam2.R;
import com.thermasol.touchsteam2.comm.HardwareServicePersist;
import com.thermasol.touchsteam2.shared.IHardwareTouchingContext;
import com.thermasol.touchsteam2.widgets.ColorWheel;
import java.util.Objects;
import kotlin.Metadata;
import kotlin.jvm.JvmStatic;
import kotlin.jvm.internal.Intrinsics;

/* JADX INFO: compiled from: OverheadLight.kt */
/* JADX INFO: loaded from: classes2.dex */
@Metadata(d1 = {"\u0000>\n\u0002\u0018\u0002\n\u0002\u0010\u0000\n\u0002\b\u0002\n\u0002\u0010\u000e\n\u0000\n\u0002\u0010\b\n\u0002\b\r\n\u0002\u0018\u0002\n\u0002\b\u0002\n\u0002\u0010\u000b\n\u0000\n\u0002\u0010\u0002\n\u0002\b\u000b\n\u0002\u0018\u0002\n\u0000\n\u0002\u0018\u0002\n\u0002\b\u001b\bÆ\u0002\u0018\u00002\u00020\u0001:\u0001AB\u0007\b\u0002¢\u0006\u0002\u0010\u0002J\u0010\u0010\u0012\u001a\u00020\u00042\u0006\u0010\u0013\u001a\u00020\u0014H\u0007J\u0012\u0010\u0015\u001a\u0004\u0018\u00010\u00042\u0006\u0010\u0013\u001a\u00020\u0014H\u0007J\u0010\u0010\u0016\u001a\u00020\u00172\u0006\u0010\u0013\u001a\u00020\u0014H\u0007J\u0010\u0010\u0018\u001a\u00020\u00192\u0006\u0010\u0013\u001a\u00020\u0014H\u0007J\u0010\u0010\u001a\u001a\u00020\u00192\u0006\u0010\u0013\u001a\u00020\u0014H\u0007J\u0010\u0010\u001b\u001a\u00020\u00192\u0006\u0010\u0013\u001a\u00020\u0014H\u0007J\u0010\u0010\u001c\u001a\u00020\u00192\u0006\u0010\u0013\u001a\u00020\u0014H\u0007J\u0010\u0010\u001d\u001a\u00020\u00062\u0006\u0010\u0013\u001a\u00020\u0014H\u0007J\u0010\u0010\u001e\u001a\u00020\u00062\u0006\u0010\u0013\u001a\u00020\u0014H\u0007J\b\u0010\u001f\u001a\u00020\u0006H\u0007J\b\u0010 \u001a\u00020\u0006H\u0007J\u0010\u0010!\u001a\u00020\u00062\u0006\u0010\u0013\u001a\u00020\u0014H\u0007J\b\u0010\"\u001a\u00020\u0006H\u0007J\b\u0010#\u001a\u00020\u0006H\u0007J\u0010\u0010$\u001a\u00020%2\u0006\u0010&\u001a\u00020'H\u0007J\u0010\u0010(\u001a\u00020\u00172\u0006\u0010&\u001a\u00020'H\u0007J\u0010\u0010)\u001a\u00020\u00172\u0006\u0010&\u001a\u00020'H\u0007J\u0010\u0010*\u001a\u00020\u00172\u0006\u0010\u0013\u001a\u00020\u0014H\u0007J\u0010\u0010+\u001a\u00020\u00192\u0006\u0010\u0013\u001a\u00020\u0014H\u0007J\u0018\u0010,\u001a\u00020\u00192\u0006\u0010\u0013\u001a\u00020\u00142\u0006\u0010-\u001a\u00020\u0017H\u0002J\u0010\u0010.\u001a\u00020\u00192\u0006\u0010\u0013\u001a\u00020\u0014H\u0007J\u0010\u0010/\u001a\u00020\u00192\u0006\u0010\u0013\u001a\u00020\u0014H\u0007J\u0018\u00100\u001a\u00020\u00192\u0006\u0010\u0013\u001a\u00020\u00142\u0006\u00101\u001a\u00020\u0006H\u0007J\u0018\u00102\u001a\u00020\u00192\u0006\u0010\u0013\u001a\u00020\u00142\u0006\u0010-\u001a\u00020\u0006H\u0007J \u00103\u001a\u00020\u00192\u0006\u0010&\u001a\u00020'2\u0006\u0010\u0013\u001a\u00020\u00142\u0006\u00104\u001a\u00020\u0006H\u0007J\u0018\u00105\u001a\u00020\u00192\u0006\u0010\u0013\u001a\u00020\u00142\u0006\u00104\u001a\u00020\u0006H\u0007J\u0018\u00106\u001a\u00020\u00192\u0006\u0010\u0013\u001a\u00020\u00142\u0006\u00101\u001a\u00020\u0006H\u0007J\u0018\u00107\u001a\u00020\u00192\u0006\u0010\u0013\u001a\u00020\u00142\u0006\u00101\u001a\u00020\u0006H\u0007J\u0018\u00108\u001a\u00020\u00192\u0006\u0010\u0013\u001a\u00020\u00142\u0006\u00109\u001a\u00020\u0006H\u0007J\u0018\u0010:\u001a\u00020\u00192\u0006\u0010\u0013\u001a\u00020\u00142\u0006\u0010;\u001a\u00020\u0006H\u0007J\u0018\u0010<\u001a\u00020\u00192\u0006\u0010\u0013\u001a\u00020\u00142\u0006\u00101\u001a\u00020\u0006H\u0007J\u0018\u0010=\u001a\u00020\u00062\u0006\u0010\u0013\u001a\u00020\u00142\u0006\u0010-\u001a\u00020\u0006H\u0007J\u0010\u0010>\u001a\u00020\u00192\u0006\u0010\u0013\u001a\u00020\u0014H\u0007J\u0010\u0010?\u001a\u00020\u00192\u0006\u0010\u0013\u001a\u00020\u0014H\u0007J\u0010\u0010@\u001a\u00020\u00192\u0006\u0010\u0013\u001a\u00020\u0014H\u0007R\u000e\u0010\u0003\u001a\u00020\u0004X\u0086T¢\u0006\u0002\n\u0000R\u000e\u0010\u0005\u001a\u00020\u0006X\u0086T¢\u0006\u0002\n\u0000R\u000e\u0010\u0007\u001a\u00020\u0004X\u0086T¢\u0006\u0002\n\u0000R\u000e\u0010\b\u001a\u00020\u0004X\u0086T¢\u0006\u0002\n\u0000R\u000e\u0010\t\u001a\u00020\u0004X\u0086T¢\u0006\u0002\n\u0000R\u000e\u0010\n\u001a\u00020\u0004X\u0086T¢\u0006\u0002\n\u0000R\u000e\u0010\u000b\u001a\u00020\u0006X\u0086T¢\u0006\u0002\n\u0000R\u000e\u0010\f\u001a\u00020\u0004X\u0086T¢\u0006\u0002\n\u0000R\u000e\u0010\r\u001a\u00020\u0004X\u0086T¢\u0006\u0002\n\u0000R\u000e\u0010\u000e\u001a\u00020\u0006X\u0086T¢\u0006\u0002\n\u0000R\u000e\u0010\u000f\u001a\u00020\u0006X\u0082T¢\u0006\u0002\n\u0000R\u000e\u0010\u0010\u001a\u00020\u0006X\u0082T¢\u0006\u0002\n\u0000R\u000e\u0010\u0011\u001a\u00020\u0004X\u0086T¢\u0006\u0002\n\u0000¨\u0006B"}, d2 = {"Lcom/thermasol/touchsteam2/util/OverheadLight;", "", "()V", "BASS_FORMAT_KEY", "", "DEFAULT_VOLUME", "", "LIGHT_INTENSITY_KEY", "LIGHT_MODE_KEY", "LIGHT_STATE_KEY", "MID_FORMAT_KEY", "MIN_VOLUME", "MUSIC_SOURCE_KEY", "MUSIC_VOLUME_KEY", "NORMAL_MAX_VOLUME", "SLSR_BASS_MAX_VOLUME", "SUPPRESSED_MAX_VOLUME", "TREBLE_FORMAT_KEY", "bluetoothBroadcastReminder", "context", "Landroid/content/Context;", "bluetoothGetDeviceName", "bluetoothIsPresent", "", "bluetoothPause", "", "bluetoothPlay", "bluetoothSkipBack", "bluetoothSkipForward", "getBluetoothState", "getDefaultBassVolume", "getDefaultMidVolume", "getDefaultTrebleVolume", "getMaxBassVolume", "getMaxMidVolume", "getMaxTrebleVolume", "getType", "Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;", NotificationCompat.CATEGORY_SERVICE, "Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;", "hasBluetoothCapability", "hasVoiceCapability", "isActive", "mute", "persistLightState", "state", "powerOffBluetooth", "powerOnBluetooth", "setBassVolume", "volume", "setChromaState", "setHvlsrRgbAndIntensity", "value", "setIntensity", "setMasterVolume", "setMidVolume", "setMode", "mode", "setSource", "requested", "setTrebleVolume", "translateStateToColorHex", "turnOff", "turnOn", "unmute", "LightType", "com.thermasol.touchsteam2_release"}, k = 1, mv = {1, 5, 1}, xi = 48)
public final class OverheadLight {
    /* HydroVive: a power-off must not unmute the ceiling unit. ShutdownAll's
     * bluetooth teardown re-selects the music source and restores volume, and
     * BOTH of those unmute -- unmute() explicitly, and the B6 volume frame (the
     * DSP unmutes before it writes gain). sInShutdown is true only for the span
     * of that teardown, so user-initiated audio calls are never affected.
     * sAudioGen is bumped once per shutdown to invalidate any volume timer that
     * was already scheduled when the user pressed power off; a stale timer must
     * not fire into the powered-off session. Neither field is ever cleared by a
     * resume, so there is no latch that could strand audio. */
    public static volatile boolean sInShutdown = false;
    public static volatile int sAudioGen = 0;

    public static final String BASS_FORMAT_KEY = "bassVolumeUser";
    public static final int DEFAULT_VOLUME = 10;
    public static final OverheadLight INSTANCE = new OverheadLight();
    public static final String LIGHT_INTENSITY_KEY = "lightIntensityUser";
    public static final String LIGHT_MODE_KEY = "lightModeUser";
    public static final String LIGHT_STATE_KEY = "lightStateUser";
    public static final String MID_FORMAT_KEY = "midVolumeUser";
    public static final int MIN_VOLUME = 0;
    public static final String MUSIC_SOURCE_KEY = "musicSourceUser";
    public static final String MUSIC_VOLUME_KEY = "musicVolumeUser";
    public static final int NORMAL_MAX_VOLUME = 15;
    private static final int SLSR_BASS_MAX_VOLUME = 20;
    private static final int SUPPRESSED_MAX_VOLUME = 14;
    public static final String TREBLE_FORMAT_KEY = "trebleVolumeUser";

    /* JADX INFO: compiled from: OverheadLight.kt */
    @Metadata(d1 = {"\u0000\f\n\u0002\u0018\u0002\n\u0002\u0010\u0010\n\u0002\b\u0007\b\u0086\u0001\u0018\u00002\b\u0012\u0004\u0012\u00020\u00000\u0001B\u0007\b\u0002¢\u0006\u0002\u0010\u0002j\u0002\b\u0003j\u0002\b\u0004j\u0002\b\u0005j\u0002\b\u0006j\u0002\b\u0007¨\u0006\b"}, d2 = {"Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;", "", "(Ljava/lang/String;I)V", "NONE", "SLSR_AUX", "SLSR_BLUETOOTH", "SLSR_NO_VOICE", "HVLSR", "com.thermasol.touchsteam2_release"}, k = 1, mv = {1, 5, 1}, xi = 48)
    public enum LightType {
        NONE,
        SLSR_AUX,
        SLSR_BLUETOOTH,
        SLSR_NO_VOICE,
        HVLSR
    }

    /* JADX INFO: compiled from: OverheadLight.kt */
    @Metadata(k = 3, mv = {1, 5, 1}, xi = 48)
    public /* synthetic */ class WhenMappings {
        public static final /* synthetic */ int[] $EnumSwitchMapping$0;

        static {
            int[] iArr = new int[LightType.values().length];
            iArr[LightType.HVLSR.ordinal()] = 1;
            iArr[LightType.SLSR_AUX.ordinal()] = 2;
            iArr[LightType.SLSR_BLUETOOTH.ordinal()] = 3;
            iArr[LightType.SLSR_NO_VOICE.ordinal()] = 4;
            $EnumSwitchMapping$0 = iArr;
        }
    }

    @JvmStatic
    public static final int getDefaultMidVolume() {
        return 7;
    }

    @JvmStatic
    public static final int getDefaultTrebleVolume() {
        return 7;
    }

    @JvmStatic
    public static final int getMaxMidVolume() {
        return 14;
    }

    @JvmStatic
    public static final int getMaxTrebleVolume() {
        return 14;
    }

    private OverheadLight() {
    }

    /* JADX WARN: Multi-variable type inference failed */
    @JvmStatic
    public static final boolean isActive(Context context) {
        Intrinsics.checkNotNullParameter(context, "context");
        return getType(((IHardwareTouchingContext) context).getInstance()) != LightType.NONE;
    }

    @JvmStatic
    public static final LightType getType(HardwareServicePersist service) {
        Intrinsics.checkNotNullParameter(service, "service");
        LightType lightType = LightType.NONE;
        if (service.hvlsr_is_active()) {
            return LightType.HVLSR;
        }
        if (!service.slsr_is_active()) {
            return lightType;
        }
        int iSlsr_get_version = service.slsr_get_version();
        if (iSlsr_get_version < 22) {
            return LightType.SLSR_AUX;
        }
        if (iSlsr_get_version == 22) {
            return LightType.SLSR_BLUETOOTH;
        }
        return iSlsr_get_version >= 23 ? LightType.SLSR_NO_VOICE : lightType;
    }

    @JvmStatic
    public static final boolean hasBluetoothCapability(HardwareServicePersist service) {
        Intrinsics.checkNotNullParameter(service, "service");
        LightType type = getType(service);
        return type == LightType.SLSR_BLUETOOTH || type == LightType.SLSR_NO_VOICE || type == LightType.HVLSR;
    }

    @JvmStatic
    public static final boolean hasVoiceCapability(HardwareServicePersist service) {
        Intrinsics.checkNotNullParameter(service, "service");
        LightType type = getType(service);
        return type == LightType.SLSR_AUX || type == LightType.SLSR_BLUETOOTH;
    }

    @JvmStatic
    public static final int translateStateToColorHex(Context context, int state) {
        Intrinsics.checkNotNullParameter(context, "context");
        switch (state) {
            case 0:
                return SupportMenu.CATEGORY_MASK;
            case 1:
                return ContextCompat.getColor(context, R.color.thermasol_orange);
            case 2:
                return InputDeviceCompat.SOURCE_ANY;
            case 3:
                return -16711936;
            case 4:
                return -16776961;
            case 5:
                return ContextCompat.getColor(context, R.color.indigo);
            case 6:
                return ContextCompat.getColor(context, R.color.violet);
            default:
                return ViewCompat.MEASURED_STATE_MASK;
        }
    }

    /* JADX WARN: Multi-variable type inference failed */
    @JvmStatic
    public static final void setChromaState(Context context, int state) {
        Intrinsics.checkNotNullParameter(context, "context");
        HardwareServicePersist iHardwareTouchingContext = ((IHardwareTouchingContext) context).getInstance();
        int i = WhenMappings.$EnumSwitchMapping$0[getType(iHardwareTouchingContext).ordinal()];
        if (i == 1) {
            setHvlsrRgbAndIntensity(iHardwareTouchingContext, context, translateStateToColorHex(context, state));
        } else if (i == 2 || i == 3 || i == 4) {
            iHardwareTouchingContext.slsr_chroma_state(state);
        }
    }

    /* JADX WARN: Multi-variable type inference failed */
    @JvmStatic
    public static final void turnOn(Context context) {
        Intrinsics.checkNotNullParameter(context, "context");
        HardwareServicePersist iHardwareTouchingContext = ((IHardwareTouchingContext) context).getInstance();
        OverheadLight overheadLight = INSTANCE;
        int i = WhenMappings.$EnumSwitchMapping$0[getType(iHardwareTouchingContext).ordinal()];
        if (i == 1) {
            iHardwareTouchingContext.hvlsr_light_on();
        } else if (i == 2 || i == 3 || i == 4) {
            iHardwareTouchingContext.slsr_turn_on_light();
        }
        overheadLight.persistLightState(context, true);
    }

    /* JADX WARN: Multi-variable type inference failed */
    @JvmStatic
    public static final void turnOff(Context context) {
        Intrinsics.checkNotNullParameter(context, "context");
        HardwareServicePersist iHardwareTouchingContext = ((IHardwareTouchingContext) context).getInstance();
        OverheadLight overheadLight = INSTANCE;
        int i = WhenMappings.$EnumSwitchMapping$0[getType(iHardwareTouchingContext).ordinal()];
        if (i == 1) {
            iHardwareTouchingContext.hvlsr_light_off();
        } else if (i == 2 || i == 3 || i == 4) {
            iHardwareTouchingContext.slsr_turn_off_light();
        }
        overheadLight.persistLightState(context, false);
    }

    /* JADX WARN: Code duplicated, block: B:15:0x0035  */
    /* JADX WARN: Multi-variable type inference failed */
    @JvmStatic
    public static final void setMode(Context context, int mode) {
        Intrinsics.checkNotNullParameter(context, "context");
        HardwareServicePersist iHardwareTouchingContext = ((IHardwareTouchingContext) context).getInstance();
        int i = WhenMappings.$EnumSwitchMapping$0[getType(iHardwareTouchingContext).ordinal()];
        if (i != 1) {
            if (i == 2 || i == 3 || i == 4) {
                iHardwareTouchingContext.slsr_set_light_mode(mode);
            }
        } else if (mode == 1) {
            setHvlsrRgbAndIntensity(iHardwareTouchingContext, context, PreferenceManager.getDefaultSharedPreferences(context).getInt(Intrinsics.stringPlus(HardwareServicePersist.HVLSR_RGB_COLOR_KEY, Integer.valueOf(GV.ActiveUser)), SupportMenu.CATEGORY_MASK));
        } else if (mode == 2) {
            iHardwareTouchingContext.hvlsr_set_mood_light(0);
        } else if (mode == 4) {
            setHvlsrRgbAndIntensity(iHardwareTouchingContext, context, PreferenceManager.getDefaultSharedPreferences(context).getInt(Intrinsics.stringPlus(HardwareServicePersist.HVLSR_RGB_COLOR_KEY, Integer.valueOf(GV.ActiveUser)), SupportMenu.CATEGORY_MASK));
        }
        if (GV.ActiveUser != 0) {
            Utils.putSteamBasedSetting(context, LIGHT_MODE_KEY, Integer.valueOf(mode), Integer.TYPE, false);
        }
    }

    /* JADX WARN: Multi-variable type inference failed */
    @JvmStatic
    public static final void setIntensity(Context context, int value) {
        Intrinsics.checkNotNullParameter(context, "context");
        HardwareServicePersist iHardwareTouchingContext = ((IHardwareTouchingContext) context).getInstance();
        Utils.putSteamBasedSetting(context, LIGHT_INTENSITY_KEY, Integer.valueOf(value), Integer.TYPE, false);
        int i = WhenMappings.$EnumSwitchMapping$0[getType(iHardwareTouchingContext).ordinal()];
        if (i == 1) {
            setHvlsrRgbAndIntensity(iHardwareTouchingContext, context, PreferenceManager.getDefaultSharedPreferences(context).getInt(Intrinsics.stringPlus(HardwareServicePersist.HVLSR_RGB_COLOR_KEY, Integer.valueOf(GV.ActiveUser)), SupportMenu.CATEGORY_MASK));
        } else if (i == 2 || i == 3 || i == 4) {
            iHardwareTouchingContext.slsr_set_light_intensity(value);
        }
    }

    @JvmStatic
    public static final void setHvlsrRgbAndIntensity(HardwareServicePersist service, Context context, int value) throws RemoteException {
        Intrinsics.checkNotNullParameter(service, "service");
        Intrinsics.checkNotNullParameter(context, "context");
        Object steamBasedSetting = Utils.getSteamBasedSetting(context, LIGHT_INTENSITY_KEY, 80, Integer.TYPE);
        Objects.requireNonNull(steamBasedSetting, "null cannot be cast to non-null type kotlin.Int");
        int iIntValue = ((Integer) steamBasedSetting).intValue();
        SharedPreferences defaultSharedPreferences = PreferenceManager.getDefaultSharedPreferences(context);
        if (defaultSharedPreferences.getBoolean(ColorWheel.HYDROVIVE_COLOR_PALETTE_KEY, false)) {
            service.hvlsr_set_rbga((value << 8) | iIntValue);
        } else {
            service.hvlsr_set_white_rbga(((int) (iIntValue * (defaultSharedPreferences.getBoolean("max_hvlsr_brightness_enabled", true) ? 1.0f : 0.6f))) | (value << 8));
        }
    }

    /* JADX WARN: Multi-variable type inference failed */
    @JvmStatic
    public static final void setSource(Context context, int requested) {
        Intrinsics.checkNotNullParameter(context, "context");
        HardwareServicePersist iHardwareTouchingContext = ((IHardwareTouchingContext) context).getInstance();
        int i = WhenMappings.$EnumSwitchMapping$0[getType(iHardwareTouchingContext).ordinal()];
        if (i == 1) {
            iHardwareTouchingContext.hvlsr_set_source(requested);
        } else if (i == 2 || i == 3 || i == 4) {
            iHardwareTouchingContext.slsr_set_source(requested);
        }
        if (hasBluetoothCapability(iHardwareTouchingContext)) {
            if (requested == 1) {
                requested = 2;
            } else if (requested == 2) {
                requested = 1;
            }
        }
        SharedPreferences.Editor editorEdit = PreferenceManager.getDefaultSharedPreferences(context).edit();
        editorEdit.putInt(Intrinsics.stringPlus(MUSIC_SOURCE_KEY, Integer.valueOf(GV.ActiveUser)), requested);
        editorEdit.apply();
    }

    /* JADX WARN: Multi-variable type inference failed */
    @JvmStatic
    public static final void mute(Context context) {
        Intrinsics.checkNotNullParameter(context, "context");
        HardwareServicePersist iHardwareTouchingContext = ((IHardwareTouchingContext) context).getInstance();
        int i = WhenMappings.$EnumSwitchMapping$0[getType(iHardwareTouchingContext).ordinal()];
        if (i == 1) {
            iHardwareTouchingContext.hvlsr_mute();
            return;
        }
        if (i == 2 || i == 3 || i == 4) {
            try {
                iHardwareTouchingContext.getMNative().slsr_set_music_volume(0);
            } catch (Exception e) {
                Utils.handleException(e);
            }
        }
    }

    /* JADX WARN: Multi-variable type inference failed */
    @JvmStatic
    public static final void unmute(Context context) {
        Intrinsics.checkNotNullParameter(context, "context");
        if (sInShutdown) {
            return;   /* shutdown owns the mute; do not undo it */
        }
        HardwareServicePersist iHardwareTouchingContext = ((IHardwareTouchingContext) context).getInstance();
        int i = WhenMappings.$EnumSwitchMapping$0[getType(iHardwareTouchingContext).ordinal()];
        if (i == 1) {
            iHardwareTouchingContext.hvlsr_unmute();
        } else if (i == 2 || i == 3 || i == 4) {
            iHardwareTouchingContext.slsr_music_on_off(true);
        }
    }

    /* JADX WARN: Multi-variable type inference failed */
    @JvmStatic
    public static final void setMasterVolume(Context context, int volume) {
        Intrinsics.checkNotNullParameter(context, "context");
        if (sInShutdown) {
            /* The B6 volume frame force-unmutes in the ceiling unit, so sending
             * it during shutdown would restore the buzz. Skip it entirely; the
             * user's stored volume is re-applied by whichever resume path the
             * user takes next (any toggleMusicAndSource call). */
            return;
        }
        HardwareServicePersist iHardwareTouchingContext = ((IHardwareTouchingContext) context).getInstance();
        int i = WhenMappings.$EnumSwitchMapping$0[getType(iHardwareTouchingContext).ordinal()];
        if (i == 1) {
            iHardwareTouchingContext.hvlsr_master_volume(volume);
        } else if (i == 2 || i == 3 || i == 4) {
            iHardwareTouchingContext.slsr_set_music_volume(volume);
        }
        SharedPreferences.Editor editorEdit = PreferenceManager.getDefaultSharedPreferences(context).edit();
        editorEdit.putInt(Intrinsics.stringPlus(MUSIC_VOLUME_KEY, Integer.valueOf(GV.ActiveUser)), volume);
        editorEdit.apply();
    }

    /* JADX WARN: Multi-variable type inference failed */
    @JvmStatic
    public static final void setTrebleVolume(Context context, int volume) {
        Intrinsics.checkNotNullParameter(context, "context");
        HardwareServicePersist iHardwareTouchingContext = ((IHardwareTouchingContext) context).getInstance();
        int i = WhenMappings.$EnumSwitchMapping$0[getType(iHardwareTouchingContext).ordinal()];
        if (i == 1) {
            iHardwareTouchingContext.hvlsr_treble_volume(volume);
        } else if (i == 2 || i == 3 || i == 4) {
            iHardwareTouchingContext.slsr_music_treble_tone(getMaxTrebleVolume() - volume);
        }
        SharedPreferences.Editor editorEdit = PreferenceManager.getDefaultSharedPreferences(context).edit();
        editorEdit.putInt(Intrinsics.stringPlus(TREBLE_FORMAT_KEY, Integer.valueOf(GV.ActiveUser)), volume);
        editorEdit.apply();
    }

    /* JADX WARN: Multi-variable type inference failed */
    @JvmStatic
    public static final void setMidVolume(Context context, int volume) {
        Intrinsics.checkNotNullParameter(context, "context");
        HardwareServicePersist iHardwareTouchingContext = ((IHardwareTouchingContext) context).getInstance();
        int i = WhenMappings.$EnumSwitchMapping$0[getType(iHardwareTouchingContext).ordinal()];
        if (i == 1) {
            iHardwareTouchingContext.hvlsr_mid_volume(volume);
        } else if (i == 2 || i == 3 || i == 4) {
            iHardwareTouchingContext.slsr_music_mid_tone(volume);
        }
        SharedPreferences.Editor editorEdit = PreferenceManager.getDefaultSharedPreferences(context).edit();
        editorEdit.putInt(Intrinsics.stringPlus(MID_FORMAT_KEY, Integer.valueOf(GV.ActiveUser)), volume);
        editorEdit.apply();
    }

    /* JADX WARN: Multi-variable type inference failed */
    @JvmStatic
    public static final void setBassVolume(Context context, int volume) {
        Intrinsics.checkNotNullParameter(context, "context");
        HardwareServicePersist iHardwareTouchingContext = ((IHardwareTouchingContext) context).getInstance();
        int i = WhenMappings.$EnumSwitchMapping$0[getType(iHardwareTouchingContext).ordinal()];
        if (i == 1) {
            iHardwareTouchingContext.hvlsr_bass_volume(volume);
        } else if (i == 2 || i == 3 || i == 4) {
            iHardwareTouchingContext.slsr_music_bass_tone(volume);
        }
        SharedPreferences.Editor editorEdit = PreferenceManager.getDefaultSharedPreferences(context).edit();
        editorEdit.putInt(Intrinsics.stringPlus(BASS_FORMAT_KEY, Integer.valueOf(GV.ActiveUser)), volume);
        editorEdit.apply();
    }

    /* JADX WARN: Multi-variable type inference failed */
    @JvmStatic
    public static final int getMaxBassVolume(Context context) {
        Intrinsics.checkNotNullParameter(context, "context");
        int i = WhenMappings.$EnumSwitchMapping$0[getType(((IHardwareTouchingContext) context).getInstance()).ordinal()];
        if (i != 1) {
            return (i == 2 || i == 3 || i == 4) ? 20 : 10;
        }
        return 14;
    }

    @JvmStatic
    public static final int getDefaultBassVolume(Context context) {
        Intrinsics.checkNotNullParameter(context, "context");
        return getMaxBassVolume(context) / 2;
    }

    /* JADX WARN: Multi-variable type inference failed */
    @JvmStatic
    public static final String bluetoothBroadcastReminder(Context context) {
        Intrinsics.checkNotNullParameter(context, "context");
        int i = WhenMappings.$EnumSwitchMapping$0[getType(((IHardwareTouchingContext) context).getInstance()).ordinal()];
        if (i == 1) {
            String string = context.getString(R.string.hydrovive_bluetooth_message);
            Intrinsics.checkNotNullExpressionValue(string, "{\n                context.getString(R.string.hydrovive_bluetooth_message)\n            }");
            return string;
        }
        if (i != 2 && i != 3 && i != 4) {
            return "";
        }
        String string2 = context.getString(R.string.bluetooth_broadcast_message);
        Intrinsics.checkNotNullExpressionValue(string2, "{\n                context.getString(R.string.bluetooth_broadcast_message)\n            }");
        return string2;
    }

    /* JADX WARN: Multi-variable type inference failed */
    @JvmStatic
    public static final boolean bluetoothIsPresent(Context context) {
        Intrinsics.checkNotNullParameter(context, "context");
        HardwareServicePersist iHardwareTouchingContext = ((IHardwareTouchingContext) context).getInstance();
        int i = WhenMappings.$EnumSwitchMapping$0[getType(iHardwareTouchingContext).ordinal()];
        if (i == 1) {
            return true;
        }
        if (i == 2 || i == 3 || i == 4) {
            return iHardwareTouchingContext.slsr_is_slsr_bluetooth_present();
        }
        return false;
    }

    /* JADX WARN: Multi-variable type inference failed */
    @JvmStatic
    public static final int getBluetoothState(Context context) {
        Intrinsics.checkNotNullParameter(context, "context");
        HardwareServicePersist iHardwareTouchingContext = ((IHardwareTouchingContext) context).getInstance();
        int i = WhenMappings.$EnumSwitchMapping$0[getType(iHardwareTouchingContext).ordinal()];
        if (i == 1) {
            return iHardwareTouchingContext.hvlsr_get_bluetooth_state();
        }
        if (i == 2 || i == 3 || i == 4) {
            return iHardwareTouchingContext.slsr_get_bluetooth_state();
        }
        return 9;
    }

    /* JADX WARN: Multi-variable type inference failed */
    @JvmStatic
    public static final void powerOnBluetooth(Context context) {
        Intrinsics.checkNotNullParameter(context, "context");
        HardwareServicePersist iHardwareTouchingContext = ((IHardwareTouchingContext) context).getInstance();
        int i = WhenMappings.$EnumSwitchMapping$0[getType(iHardwareTouchingContext).ordinal()];
        if (i == 1) {
            iHardwareTouchingContext.hvlsr_bluetooth_power_on();
        } else if (i == 2 || i == 3 || i == 4) {
            iHardwareTouchingContext.slsr_bluetooth_power_on();
        }
    }

    /* JADX WARN: Multi-variable type inference failed */
    @JvmStatic
    public static final void powerOffBluetooth(Context context) {
        Intrinsics.checkNotNullParameter(context, "context");
        HardwareServicePersist iHardwareTouchingContext = ((IHardwareTouchingContext) context).getInstance();
        int i = WhenMappings.$EnumSwitchMapping$0[getType(iHardwareTouchingContext).ordinal()];
        if (i == 1) {
            iHardwareTouchingContext.hvlsr_bluetooth_power_off();
        } else if (i == 2 || i == 3 || i == 4) {
            iHardwareTouchingContext.slsr_bluetooth_power_off();
        }
    }

    /* JADX WARN: Multi-variable type inference failed */
    @JvmStatic
    public static final void bluetoothPlay(Context context) {
        Intrinsics.checkNotNullParameter(context, "context");
        HardwareServicePersist iHardwareTouchingContext = ((IHardwareTouchingContext) context).getInstance();
        int i = WhenMappings.$EnumSwitchMapping$0[getType(iHardwareTouchingContext).ordinal()];
        if (i == 1) {
            iHardwareTouchingContext.hvlsr_bluetooth_play();
        } else if (i == 2 || i == 3 || i == 4) {
            iHardwareTouchingContext.slsr_bluetooth_play();
        }
    }

    /* JADX WARN: Multi-variable type inference failed */
    @JvmStatic
    public static final void bluetoothPause(Context context) {
        Intrinsics.checkNotNullParameter(context, "context");
        HardwareServicePersist iHardwareTouchingContext = ((IHardwareTouchingContext) context).getInstance();
        int i = WhenMappings.$EnumSwitchMapping$0[getType(iHardwareTouchingContext).ordinal()];
        if (i == 1) {
            iHardwareTouchingContext.hvlsr_bluetooth_pause();
        } else if (i == 2 || i == 3 || i == 4) {
            iHardwareTouchingContext.slsr_bluetooth_pause();
        }
    }

    /* JADX WARN: Multi-variable type inference failed */
    @JvmStatic
    public static final void bluetoothSkipForward(Context context) {
        Intrinsics.checkNotNullParameter(context, "context");
        HardwareServicePersist iHardwareTouchingContext = ((IHardwareTouchingContext) context).getInstance();
        int i = WhenMappings.$EnumSwitchMapping$0[getType(iHardwareTouchingContext).ordinal()];
        if (i == 1) {
            iHardwareTouchingContext.hvlsr_bluetooth_skip_forward();
        } else if (i == 2 || i == 3 || i == 4) {
            iHardwareTouchingContext.slsr_bluetooth_skip_forward();
        }
    }

    /* JADX WARN: Multi-variable type inference failed */
    @JvmStatic
    public static final void bluetoothSkipBack(Context context) {
        Intrinsics.checkNotNullParameter(context, "context");
        HardwareServicePersist iHardwareTouchingContext = ((IHardwareTouchingContext) context).getInstance();
        int i = WhenMappings.$EnumSwitchMapping$0[getType(iHardwareTouchingContext).ordinal()];
        if (i == 1) {
            iHardwareTouchingContext.hvlsr_bluetooth_skip_back();
        } else if (i == 2 || i == 3 || i == 4) {
            iHardwareTouchingContext.slsr_bluetooth_skip_back();
        }
    }

    /* JADX WARN: Multi-variable type inference failed */
    @JvmStatic
    public static final String bluetoothGetDeviceName(Context context) {
        Intrinsics.checkNotNullParameter(context, "context");
        HardwareServicePersist iHardwareTouchingContext = ((IHardwareTouchingContext) context).getInstance();
        int i = WhenMappings.$EnumSwitchMapping$0[getType(iHardwareTouchingContext).ordinal()];
        if (i != 1) {
            return (i == 2 || i == 3 || i == 4) ? iHardwareTouchingContext.slsr_bluetooth_get_devicename() : "";
        }
        return iHardwareTouchingContext.hvlsr_bluetooth_get_devicename();
    }

    private final void persistLightState(Context context, boolean state) {
        if (GV.ActiveUser != 0) {
            Utils.putSteamBasedSetting(context, LIGHT_STATE_KEY, Integer.valueOf(state ? 1 : 0), Integer.TYPE, false);
        }
    }
}
