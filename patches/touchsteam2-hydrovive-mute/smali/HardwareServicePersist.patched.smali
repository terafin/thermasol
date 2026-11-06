.class public final Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;
.super Ljava/lang/Object;
.source "HardwareServicePersist.kt"

# interfaces
.implements Landroid/hardware/SensorEventListener;


# annotations
.annotation system Ldalvik/annotation/MemberClasses;
    value = {
        Lcom/thermasol/touchsteam2/comm/HardwareServicePersist$Companion;
    }
.end annotation

.annotation runtime Lkotlin/Metadata;
    d1 = {
        "\u0000Z\n\u0002\u0018\u0002\n\u0002\u0018\u0002\n\u0000\n\u0002\u0018\u0002\n\u0000\n\u0002\u0018\u0002\n\u0002\u0008\u0004\n\u0002\u0018\u0002\n\u0000\n\u0002\u0018\u0002\n\u0000\n\u0002\u0010\u000b\n\u0000\n\u0002\u0010\u0008\n\u0002\u0008\u0003\n\u0002\u0010\u0002\n\u0002\u0008\u0012\n\u0002\u0010\u000e\n\u0002\u0008\u0019\n\u0002\u0018\u0002\n\u0002\u0008\u0003\n\u0002\u0018\u0002\n\u0002\u0008\u000e\n\u0002\u0010\u0007\n\u0002\u00089\u0018\u0000 \u008c\u00012\u00020\u0001:\u0002\u008c\u0001B\u0015\u0012\u0006\u0010\u0002\u001a\u00020\u0003\u0012\u0006\u0010\u0004\u001a\u00020\u0005\u00a2\u0006\u0002\u0010\u0006J\u0010\u0010\u0011\u001a\u00020\u00102\u0006\u0010\u0012\u001a\u00020\u0010H\u0002J\u0006\u0010\u0013\u001a\u00020\u0014J\u0006\u0010\u0015\u001a\u00020\u000eJ\u0006\u0010\u0016\u001a\u00020\u0010J\u0006\u0010\u0017\u001a\u00020\u0014J\u000e\u0010\u0018\u001a\u00020\u00142\u0006\u0010\u0019\u001a\u00020\u0010J\u000e\u0010\u001a\u001a\u00020\u00142\u0006\u0010\u001b\u001a\u00020\u0010J\u000e\u0010\u001c\u001a\u00020\u00142\u0006\u0010\u001d\u001a\u00020\u0010J\u0006\u0010\u001e\u001a\u00020\u0014J\u0006\u0010\u001f\u001a\u00020\u0014J\u0006\u0010 \u001a\u00020\u0010J\u0006\u0010!\u001a\u00020\u0010J\u0006\u0010\"\u001a\u00020\u0005J\u0006\u0010#\u001a\u00020\u0010J\u000e\u0010$\u001a\u00020\u00142\u0006\u0010%\u001a\u00020\u0010J\u0008\u0010&\u001a\u0004\u0018\u00010\'J\u0006\u0010(\u001a\u00020\u0014J\u0006\u0010)\u001a\u00020\u0014J\u0006\u0010*\u001a\u00020\u0014J\u0006\u0010+\u001a\u00020\u0014J\u0006\u0010,\u001a\u00020\u0014J\u0006\u0010-\u001a\u00020\u0014J\u0006\u0010.\u001a\u00020\u0010J\u0006\u0010/\u001a\u00020\u000eJ\u0006\u00100\u001a\u00020\u0014J\u0006\u00101\u001a\u00020\u0014J\u000e\u00102\u001a\u00020\u00142\u0006\u0010%\u001a\u00020\u0010J\u000e\u00103\u001a\u00020\u00142\u0006\u0010%\u001a\u00020\u0010J\u0006\u00104\u001a\u00020\u0014J\u0006\u00105\u001a\u00020\u0014J\u000e\u00106\u001a\u00020\u00142\u0006\u00107\u001a\u00020\u0010J\u000e\u00108\u001a\u00020\u00142\u0006\u00109\u001a\u00020\u0010J\u000e\u0010:\u001a\u00020\u00142\u0006\u0010;\u001a\u00020\u0010J\u000e\u0010<\u001a\u00020\u00142\u0006\u00109\u001a\u00020\u0010J\u000e\u0010=\u001a\u00020\u00142\u0006\u0010%\u001a\u00020\u0010J\u0006\u0010>\u001a\u00020\u0014J\u001a\u0010?\u001a\u00020\u00142\u0008\u0010@\u001a\u0004\u0018\u00010A2\u0006\u0010B\u001a\u00020\u0010H\u0016J\u0012\u0010C\u001a\u00020\u00142\u0008\u0010D\u001a\u0004\u0018\u00010EH\u0016J\u0006\u0010F\u001a\u00020\u0010J\u0006\u0010G\u001a\u00020\u0010J\u0006\u0010H\u001a\u00020\u000eJ\u0006\u0010I\u001a\u00020\u0010J\u0006\u0010J\u001a\u00020\u0010J\u0006\u0010K\u001a\u00020\u0010J\u0006\u0010L\u001a\u00020\u0010J\u0006\u0010M\u001a\u00020\u0010J\u0006\u0010N\u001a\u00020\u0010J\u0006\u0010O\u001a\u00020\u0010J\u0006\u0010P\u001a\u00020\u0014J\u0006\u0010Q\u001a\u00020\u0014J\u000e\u0010R\u001a\u00020\u00142\u0006\u0010S\u001a\u00020TJ\u000e\u0010U\u001a\u00020\u00142\u0006\u0010V\u001a\u00020\u0010J\u000e\u0010W\u001a\u00020\u00142\u0006\u0010\u0012\u001a\u00020\u0010J\u000e\u0010X\u001a\u00020\u00142\u0006\u0010Y\u001a\u00020\u0010J\u000e\u0010Z\u001a\u00020\u00142\u0006\u0010[\u001a\u00020\u0010J\u000e\u0010\\\u001a\u00020\u00142\u0006\u0010]\u001a\u00020\u0010J\u0006\u0010^\u001a\u00020\u000eJ\u0006\u0010_\u001a\u00020\u0014J\u0006\u0010`\u001a\u00020\u0014J\u0006\u0010a\u001a\u00020\u0014J\u0006\u0010b\u001a\u00020\u0014J\u0006\u0010c\u001a\u00020\u0014J\u0006\u0010d\u001a\u00020\u0014J\u0008\u0010e\u001a\u0004\u0018\u00010\'J\u0006\u0010f\u001a\u00020\u0014J\u0006\u0010g\u001a\u00020\u0014J\u0006\u0010h\u001a\u00020\u0014J\u0006\u0010i\u001a\u00020\u0014J\u0006\u0010j\u001a\u00020\u0014J\u0006\u0010k\u001a\u00020\u0014J\u000e\u0010l\u001a\u00020\u00142\u0006\u0010m\u001a\u00020\u0010J\u0006\u0010n\u001a\u00020\u0010J\u0006\u0010o\u001a\u00020\u0010J\u0006\u0010p\u001a\u00020\u000eJ\u0006\u0010q\u001a\u00020\u000eJ\u000e\u0010r\u001a\u00020\u00142\u0006\u0010s\u001a\u00020\u0010J\u000e\u0010t\u001a\u00020\u00142\u0006\u0010s\u001a\u00020\u0010J\u000e\u0010u\u001a\u00020\u00142\u0006\u0010v\u001a\u00020\u000eJ\u000e\u0010w\u001a\u00020\u00142\u0006\u0010s\u001a\u00020\u0010J\u0006\u0010x\u001a\u00020\u0014J\u0006\u0010y\u001a\u00020\u0014J\u000e\u0010z\u001a\u00020\u00142\u0006\u0010{\u001a\u00020\u0010J\u000e\u0010|\u001a\u00020\u00142\u0006\u0010\u0012\u001a\u00020\u0010J\u000e\u0010}\u001a\u00020\u00142\u0006\u0010%\u001a\u00020\u0010J\u0006\u0010~\u001a\u00020\u0014J\u000f\u0010\u007f\u001a\u00020\u00142\u0007\u0010\u0080\u0001\u001a\u00020\u0010J\u000f\u0010\u0081\u0001\u001a\u00020\u00142\u0006\u00107\u001a\u00020\u0010J\u000f\u0010\u0082\u0001\u001a\u00020\u00142\u0006\u0010%\u001a\u00020\u0010J\u0007\u0010\u0083\u0001\u001a\u00020\u0014J\u0007\u0010\u0084\u0001\u001a\u00020\u0014J\u0007\u0010\u0085\u0001\u001a\u00020\u0014J\u000f\u0010\u0086\u0001\u001a\u00020\u00142\u0006\u0010v\u001a\u00020\u000eJ\u0007\u0010\u0087\u0001\u001a\u00020\u0014J\u0007\u0010\u0088\u0001\u001a\u00020\u0014J\u0007\u0010\u0089\u0001\u001a\u00020\u0014J\u0010\u0010\u008a\u0001\u001a\u00020\u00142\u0007\u0010\u008b\u0001\u001a\u00020\u0010R\u000e\u0010\u0007\u001a\u00020\u0003X\u0082\u000e\u00a2\u0006\u0002\n\u0000R\u000e\u0010\u0008\u001a\u00020\u0005X\u0082\u000e\u00a2\u0006\u0002\n\u0000R\u000e\u0010\t\u001a\u00020\nX\u0082\u000e\u00a2\u0006\u0002\n\u0000R\u000e\u0010\u000b\u001a\u00020\u000cX\u0082\u000e\u00a2\u0006\u0002\n\u0000R\u000e\u0010\r\u001a\u00020\u000eX\u0082\u000e\u00a2\u0006\u0002\n\u0000R\u000e\u0010\u000f\u001a\u00020\u0010X\u0082\u000e\u00a2\u0006\u0002\n\u0000\u00a8\u0006\u008d\u0001"
    }
    d2 = {
        "Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;",
        "Landroid/hardware/SensorEventListener;",
        "context",
        "Landroid/content/Context;",
        "service",
        "Lcom/thermasol/thermatouchservice/IHardwareService;",
        "(Landroid/content/Context;Lcom/thermasol/thermatouchservice/IHardwareService;)V",
        "mContext",
        "mNative",
        "mPreferenceEditor",
        "Landroid/content/SharedPreferences$Editor;",
        "mPreferences",
        "Landroid/content/SharedPreferences;",
        "mSimulated",
        "",
        "mTemperature",
        "",
        "bindFastStartValue",
        "mode",
        "esv_clear_flow_counter",
        "",
        "esv_get_is_dongle_present",
        "esv_get_water_temperature",
        "esv_send_heartbeat",
        "esv_set_flow",
        "flow",
        "esv_set_output",
        "output",
        "esv_set_temperature",
        "temperature",
        "esv_turn_off",
        "esv_turn_on",
        "ezs_get_user",
        "ezs_read_clear_logout",
        "getNative",
        "get_current_room_temperature",
        "hvlsr_bass_volume",
        "volume",
        "hvlsr_bluetooth_get_devicename",
        "",
        "hvlsr_bluetooth_pause",
        "hvlsr_bluetooth_play",
        "hvlsr_bluetooth_power_off",
        "hvlsr_bluetooth_power_on",
        "hvlsr_bluetooth_skip_back",
        "hvlsr_bluetooth_skip_forward",
        "hvlsr_get_bluetooth_state",
        "hvlsr_is_active",
        "hvlsr_light_off",
        "hvlsr_light_on",
        "hvlsr_master_volume",
        "hvlsr_mid_volume",
        "hvlsr_mute",
        "hvlsr_send_heartbeat",
        "hvlsr_set_mood_light",
        "value",
        "hvlsr_set_rbga",
        "color",
        "hvlsr_set_source",
        "source",
        "hvlsr_set_white_rbga",
        "hvlsr_treble_volume",
        "hvlsr_unmute",
        "onAccuracyChanged",
        "sensor",
        "Landroid/hardware/Sensor;",
        "accuracy",
        "onSensorChanged",
        "event",
        "Landroid/hardware/SensorEvent;",
        "psb_get_errors",
        "psb_get_faststart_mode",
        "psb_get_is_psb_active",
        "psb_get_power_flush_timer",
        "psb_get_psb_get_maintenance_counter",
        "psb_get_psb_run_hours",
        "psb_get_psb_steam_timer",
        "psb_get_psb_temperature_setpoint",
        "psb_get_remaining_steam_time",
        "psb_get_state",
        "psb_send_heartbeat",
        "psb_send_psbstat_request",
        "psb_set_current_room_temperature",
        "room_temperature",
        "",
        "psb_set_error",
        "error",
        "psb_set_faststart_mode",
        "psb_set_load_user",
        "user",
        "psb_set_temperature_setpoint",
        "temperature_setpoint",
        "psb_set_timer_setpoint",
        "timer_setpoint",
        "psb_steam_timer_finished",
        "psb_turn_off_power_flush",
        "psb_turn_off_steam",
        "psb_turn_on_faststart_mode",
        "psb_turn_on_power_flush",
        "psb_turn_on_steam",
        "psb_user_logout",
        "slsr_bluetooth_get_devicename",
        "slsr_bluetooth_pause",
        "slsr_bluetooth_play",
        "slsr_bluetooth_power_off",
        "slsr_bluetooth_power_on",
        "slsr_bluetooth_skip_back",
        "slsr_bluetooth_skip_forward",
        "slsr_chroma_state",
        "state",
        "slsr_get_bluetooth_state",
        "slsr_get_version",
        "slsr_is_active",
        "slsr_is_slsr_bluetooth_present",
        "slsr_music_bass_tone",
        "tone",
        "slsr_music_mid_tone",
        "slsr_music_on_off",
        "on",
        "slsr_music_treble_tone",
        "slsr_request_sls_standby",
        "slsr_request_sls_stats",
        "slsr_set_light_intensity",
        "intensity",
        "slsr_set_light_mode",
        "slsr_set_music_volume",
        "slsr_set_radio_channel",
        "slsr_set_source",
        "requested",
        "slsr_set_temperature_format",
        "slsr_set_voice_volume",
        "slsr_turn_off_light",
        "slsr_turn_on_light",
        "slsr_voice_mute",
        "slsr_voice_on_off",
        "slsr_voice_unmute",
        "thermacan_close",
        "thermacan_open",
        "thermacan_reset",
        "device",
        "Companion",
        "com.thermasol.touchsteam2_release"
    }
    k = 0x1
    mv = {
        0x1,
        0x5,
        0x1
    }
    xi = 0x30
.end annotation


# static fields
.field public static final Companion:Lcom/thermasol/touchsteam2/comm/HardwareServicePersist$Companion;

.field public static final HVLSR_RGB_COLOR_KEY:Ljava/lang/String; = "rgbColorUser"

.field public static final SHOWER_FLOW_KEY:Ljava/lang/String; = "showerFlow"

.field public static final SHOWER_STATE_KEY:Ljava/lang/String; = "showerState"

.field public static final SHOWER_TEMP_KEY:Ljava/lang/String; = "showerTemp"

.field public static final SHOWER_VALVE_KEY:Ljava/lang/String; = "showerValve"

.field public static final STEAM_KEY_PREFIX:Ljava/lang/String; = "steam"

.field public static final STEAM_TEMP_KEY:Ljava/lang/String; = "steamTempUser"

.field public static final TEMP_FORMAT_KEY:Ljava/lang/String; = "tempFormatUser"

.field public static final TT_APP_STORE_KEY:Ljava/lang/String; = "thermatouchAllowAppStore"

.field public static final TT_SHOW_APP_KEY:Ljava/lang/String; = "thermatouchShowAppPage"

.field public static final VOICE_STATE_KEY:Ljava/lang/String; = "voiceStateUser"

.field public static final VOICE_VOLUME_KEY:Ljava/lang/String; = "voiceVolumeUser"


# instance fields
.field private mContext:Landroid/content/Context;

.field private mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

.field private mPreferenceEditor:Landroid/content/SharedPreferences$Editor;

.field private mPreferences:Landroid/content/SharedPreferences;

.field private mSimulated:Z

.field private mTemperature:I


# direct methods
.method static constructor <clinit>()V
    .registers 2

    new-instance v0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist$Companion;

    const/4 v1, 0x0

    invoke-direct {v0, v1}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist$Companion;-><init>(Lkotlin/jvm/internal/DefaultConstructorMarker;)V

    sput-object v0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->Companion:Lcom/thermasol/touchsteam2/comm/HardwareServicePersist$Companion;

    return-void
.end method

.method public constructor <init>(Landroid/content/Context;Lcom/thermasol/thermatouchservice/IHardwareService;)V
    .registers 4

    const-string v0, "context"

    invoke-static {p1, v0}, Lkotlin/jvm/internal/Intrinsics;->checkNotNullParameter(Ljava/lang/Object;Ljava/lang/String;)V

    const-string v0, "service"

    invoke-static {p2, v0}, Lkotlin/jvm/internal/Intrinsics;->checkNotNullParameter(Ljava/lang/Object;Ljava/lang/String;)V

    .line 20
    invoke-direct {p0}, Ljava/lang/Object;-><init>()V

    .line 38
    iput-object p2, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    .line 39
    iput-object p1, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mContext:Landroid/content/Context;

    .line 41
    invoke-static {p1}, Landroidx/preference/PreferenceManager;->getDefaultSharedPreferences(Landroid/content/Context;)Landroid/content/SharedPreferences;

    move-result-object p2

    const-string v0, "getDefaultSharedPreferences(context)"

    invoke-static {p2, v0}, Lkotlin/jvm/internal/Intrinsics;->checkNotNullExpressionValue(Ljava/lang/Object;Ljava/lang/String;)V

    iput-object p2, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mPreferences:Landroid/content/SharedPreferences;

    .line 42
    invoke-interface {p2}, Landroid/content/SharedPreferences;->edit()Landroid/content/SharedPreferences$Editor;

    move-result-object p2

    const-string v0, "mPreferences.edit()"

    invoke-static {p2, v0}, Lkotlin/jvm/internal/Intrinsics;->checkNotNullExpressionValue(Ljava/lang/Object;Ljava/lang/String;)V

    iput-object p2, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mPreferenceEditor:Landroid/content/SharedPreferences$Editor;

    const/16 p2, 0x50

    .line 43
    iput p2, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mTemperature:I

    const-string p2, "sensor"

    .line 47
    invoke-virtual {p1, p2}, Landroid/content/Context;->getSystemService(Ljava/lang/String;)Ljava/lang/Object;

    move-result-object p1

    const-string p2, "null cannot be cast to non-null type android.hardware.SensorManager"

    invoke-static {p1, p2}, Ljava/util/Objects;->requireNonNull(Ljava/lang/Object;Ljava/lang/String;)Ljava/lang/Object;

    check-cast p1, Landroid/hardware/SensorManager;

    const/16 p2, 0xd

    .line 48
    invoke-virtual {p1, p2}, Landroid/hardware/SensorManager;->getDefaultSensor(I)Landroid/hardware/Sensor;

    move-result-object p2

    .line 49
    check-cast p0, Landroid/hardware/SensorEventListener;

    const/4 v0, 0x3

    invoke-virtual {p1, p0, p2, v0}, Landroid/hardware/SensorManager;->registerListener(Landroid/hardware/SensorEventListener;Landroid/hardware/Sensor;I)Z

    return-void
.end method

.method private final bindFastStartValue(I)I
    .registers 6

    const/4 v0, 0x2

    const/4 v1, 0x0

    const/4 v2, 0x1

    if-eq p1, v2, :cond_10

    const/16 v3, 0x9

    if-eq p1, v3, :cond_e

    const/16 v3, 0x90

    if-eq p1, v3, :cond_e

    goto :goto_12

    :cond_e
    move p1, v1

    goto :goto_11

    :cond_10
    move p1, v0

    :goto_11
    move v1, v2

    :goto_12
    const/4 v3, 0x3

    if-eqz p1, :cond_1b

    if-eq p1, v0, :cond_1b

    if-eq p1, v3, :cond_1b

    move p1, v3

    goto :goto_1c

    :cond_1b
    move v2, v1

    :goto_1c
    if-eqz v2, :cond_23

    .line 197
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0, p1}, Lcom/thermasol/thermatouchservice/IHardwareService;->psb_set_faststart_mode(I)V

    :cond_23
    return p1
.end method


# virtual methods
.method public final esv_clear_flow_counter()V
    .registers 1

    .line 277
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0}, Lcom/thermasol/thermatouchservice/IHardwareService;->esv_clear_flow_counter()V

    return-void
.end method

.method public final esv_get_is_dongle_present()Z
    .registers 1

    .line 282
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0}, Lcom/thermasol/thermatouchservice/IHardwareService;->esv_get_is_dongle_present()Z

    move-result p0

    return p0
.end method

.method public final esv_get_water_temperature()I
    .registers 1

    .line 288
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0}, Lcom/thermasol/thermatouchservice/IHardwareService;->esv_get_water_temperature()I

    move-result p0

    return p0
.end method

.method public final esv_send_heartbeat()V
    .registers 1

    .line 237
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0}, Lcom/thermasol/thermatouchservice/IHardwareService;->esv_send_heartbeat()V

    return-void
.end method

.method public final esv_set_flow(I)V
    .registers 5

    .line 263
    iget-object v0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {v0, p1}, Lcom/thermasol/thermatouchservice/IHardwareService;->esv_set_flow(I)V

    .line 264
    iget-object v0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mPreferenceEditor:Landroid/content/SharedPreferences$Editor;

    sget v1, Lcom/thermasol/touchsteam2/GV;->ActiveUser:I

    invoke-static {v1}, Ljava/lang/Integer;->valueOf(I)Ljava/lang/Integer;

    move-result-object v1

    const-string v2, "showerFlow"

    invoke-static {v2, v1}, Lkotlin/jvm/internal/Intrinsics;->stringPlus(Ljava/lang/String;Ljava/lang/Object;)Ljava/lang/String;

    move-result-object v1

    invoke-interface {v0, v1, p1}, Landroid/content/SharedPreferences$Editor;->putInt(Ljava/lang/String;I)Landroid/content/SharedPreferences$Editor;

    .line 265
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mPreferenceEditor:Landroid/content/SharedPreferences$Editor;

    invoke-interface {p0}, Landroid/content/SharedPreferences$Editor;->apply()V

    return-void
.end method

.method public final esv_set_output(I)V
    .registers 5

    .line 256
    iget-object v0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {v0, p1}, Lcom/thermasol/thermatouchservice/IHardwareService;->esv_set_output(I)V

    .line 257
    iget-object v0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mPreferenceEditor:Landroid/content/SharedPreferences$Editor;

    sget v1, Lcom/thermasol/touchsteam2/GV;->ActiveUser:I

    invoke-static {v1}, Ljava/lang/Integer;->valueOf(I)Ljava/lang/Integer;

    move-result-object v1

    const-string v2, "showerValve"

    invoke-static {v2, v1}, Lkotlin/jvm/internal/Intrinsics;->stringPlus(Ljava/lang/String;Ljava/lang/Object;)Ljava/lang/String;

    move-result-object v1

    invoke-interface {v0, v1, p1}, Landroid/content/SharedPreferences$Editor;->putInt(Ljava/lang/String;I)Landroid/content/SharedPreferences$Editor;

    .line 258
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mPreferenceEditor:Landroid/content/SharedPreferences$Editor;

    invoke-interface {p0}, Landroid/content/SharedPreferences$Editor;->apply()V

    return-void
.end method

.method public final esv_set_temperature(I)V
    .registers 5

    .line 270
    iget-object v0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {v0, p1}, Lcom/thermasol/thermatouchservice/IHardwareService;->esv_set_temperature(I)V

    .line 271
    iget-object v0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mPreferenceEditor:Landroid/content/SharedPreferences$Editor;

    sget v1, Lcom/thermasol/touchsteam2/GV;->ActiveUser:I

    invoke-static {v1}, Ljava/lang/Integer;->valueOf(I)Ljava/lang/Integer;

    move-result-object v1

    const-string v2, "showerTemp"

    invoke-static {v2, v1}, Lkotlin/jvm/internal/Intrinsics;->stringPlus(Ljava/lang/String;Ljava/lang/Object;)Ljava/lang/String;

    move-result-object v1

    invoke-interface {v0, v1, p1}, Landroid/content/SharedPreferences$Editor;->putInt(Ljava/lang/String;I)Landroid/content/SharedPreferences$Editor;

    .line 272
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mPreferenceEditor:Landroid/content/SharedPreferences$Editor;

    invoke-interface {p0}, Landroid/content/SharedPreferences$Editor;->apply()V

    return-void
.end method

.method public final esv_turn_off()V
    .registers 4

    .line 249
    iget-object v0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {v0}, Lcom/thermasol/thermatouchservice/IHardwareService;->esv_turn_off()V

    .line 250
    iget-object v0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mPreferenceEditor:Landroid/content/SharedPreferences$Editor;

    const-string v1, "showerState"

    const/4 v2, 0x0

    invoke-interface {v0, v1, v2}, Landroid/content/SharedPreferences$Editor;->putBoolean(Ljava/lang/String;Z)Landroid/content/SharedPreferences$Editor;

    .line 251
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mPreferenceEditor:Landroid/content/SharedPreferences$Editor;

    invoke-interface {p0}, Landroid/content/SharedPreferences$Editor;->apply()V

    return-void
.end method

.method public final esv_turn_on()V
    .registers 4

    iget-object v0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mContext:Landroid/content/Context;

    invoke-static {v0}, Lcom/thermasol/touchsteam2/util/OverheadLight;->unmute(Landroid/content/Context;)V

    .line 242
    iget-object v0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {v0}, Lcom/thermasol/thermatouchservice/IHardwareService;->esv_turn_on()V

    .line 243
    iget-object v0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mPreferenceEditor:Landroid/content/SharedPreferences$Editor;

    const-string v1, "showerState"

    const/4 v2, 0x1

    invoke-interface {v0, v1, v2}, Landroid/content/SharedPreferences$Editor;->putBoolean(Ljava/lang/String;Z)Landroid/content/SharedPreferences$Editor;

    .line 244
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mPreferenceEditor:Landroid/content/SharedPreferences$Editor;

    invoke-interface {p0}, Landroid/content/SharedPreferences$Editor;->apply()V

    return-void
.end method

.method public final ezs_get_user()I
    .registers 1

    .line 409
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0}, Lcom/thermasol/thermatouchservice/IHardwareService;->ezs_get_user()I

    move-result p0

    return p0
.end method

.method public final ezs_read_clear_logout()I
    .registers 1

    .line 414
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0}, Lcom/thermasol/thermatouchservice/IHardwareService;->ezs_read_clear_logout()I

    move-result p0

    return p0
.end method

.method public final getNative()Lcom/thermasol/thermatouchservice/IHardwareService;
    .registers 1

    .line 586
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    return-object p0
.end method

.method public final get_current_room_temperature()I
    .registers 1

    .line 581
    iget p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mTemperature:I

    return p0
.end method

.method public final hvlsr_bass_volume(I)V
    .registers 2

    .line 521
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0, p1}, Lcom/thermasol/thermatouchservice/IHardwareService;->hvlsr_bass_volume(I)V

    return-void
.end method

.method public final hvlsr_bluetooth_get_devicename()Ljava/lang/String;
    .registers 1

    .line 576
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0}, Lcom/thermasol/thermatouchservice/IHardwareService;->hvlsr_bluetooth_get_devicename()Ljava/lang/String;

    move-result-object p0

    return-object p0
.end method

.method public final hvlsr_bluetooth_pause()V
    .registers 1

    .line 561
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0}, Lcom/thermasol/thermatouchservice/IHardwareService;->hvlsr_bluetooth_pause()V

    return-void
.end method

.method public final hvlsr_bluetooth_play()V
    .registers 1

    .line 556
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0}, Lcom/thermasol/thermatouchservice/IHardwareService;->hvlsr_bluetooth_play()V

    return-void
.end method

.method public final hvlsr_bluetooth_power_off()V
    .registers 1

    .line 551
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0}, Lcom/thermasol/thermatouchservice/IHardwareService;->hvlsr_bluetooth_power_off()V

    return-void
.end method

.method public final hvlsr_bluetooth_power_on()V
    .registers 1

    .line 546
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0}, Lcom/thermasol/thermatouchservice/IHardwareService;->hvlsr_bluetooth_power_on()V

    return-void
.end method

.method public final hvlsr_bluetooth_skip_back()V
    .registers 1

    .line 571
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0}, Lcom/thermasol/thermatouchservice/IHardwareService;->hvlsr_bluetooth_skip_back()V

    return-void
.end method

.method public final hvlsr_bluetooth_skip_forward()V
    .registers 1

    .line 566
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0}, Lcom/thermasol/thermatouchservice/IHardwareService;->hvlsr_bluetooth_skip_forward()V

    return-void
.end method

.method public final hvlsr_get_bluetooth_state()I
    .registers 1

    .line 541
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0}, Lcom/thermasol/thermatouchservice/IHardwareService;->hvlsr_get_bluetooth_state()I

    move-result p0

    return p0
.end method

.method public final hvlsr_is_active()Z
    .registers 1

    .line 464
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0}, Lcom/thermasol/thermatouchservice/IHardwareService;->hvlsr_is_active()Z

    move-result p0

    return p0
.end method

.method public final hvlsr_light_off()V
    .registers 1

    .line 501
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0}, Lcom/thermasol/thermatouchservice/IHardwareService;->hvlsr_light_off()V

    return-void
.end method

.method public final hvlsr_light_on()V
    .registers 1

    .line 496
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0}, Lcom/thermasol/thermatouchservice/IHardwareService;->hvlsr_light_on()V

    return-void
.end method

.method public final hvlsr_master_volume(I)V
    .registers 2

    .line 516
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0, p1}, Lcom/thermasol/thermatouchservice/IHardwareService;->hvlsr_master_volume(I)V

    return-void
.end method

.method public final hvlsr_mid_volume(I)V
    .registers 2

    .line 526
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0, p1}, Lcom/thermasol/thermatouchservice/IHardwareService;->hvlsr_mid_volume(I)V

    return-void
.end method

.method public final hvlsr_mute()V
    .registers 1

    .line 506
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0}, Lcom/thermasol/thermatouchservice/IHardwareService;->hvlsr_mute()V

    return-void
.end method

.method public final hvlsr_send_heartbeat()V
    .registers 1

    .line 470
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0}, Lcom/thermasol/thermatouchservice/IHardwareService;->hvlsr_send_heartbeat()V

    return-void
.end method

.method public final hvlsr_set_mood_light(I)V
    .registers 2

    .line 491
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0, p1}, Lcom/thermasol/thermatouchservice/IHardwareService;->hvlsr_set_mood_light(I)V

    return-void
.end method

.method public final hvlsr_set_rbga(I)V
    .registers 5

    .line 475
    iget-object v0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {v0, p1}, Lcom/thermasol/thermatouchservice/IHardwareService;->hvlsr_set_rbga(I)V

    .line 477
    iget-object v0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mPreferenceEditor:Landroid/content/SharedPreferences$Editor;

    sget v1, Lcom/thermasol/touchsteam2/GV;->ActiveUser:I

    invoke-static {v1}, Ljava/lang/Integer;->valueOf(I)Ljava/lang/Integer;

    move-result-object v1

    const-string v2, "rgbColorUser"

    invoke-static {v2, v1}, Lkotlin/jvm/internal/Intrinsics;->stringPlus(Ljava/lang/String;Ljava/lang/Object;)Ljava/lang/String;

    move-result-object v1

    shr-int/lit8 p1, p1, 0x8

    invoke-interface {v0, v1, p1}, Landroid/content/SharedPreferences$Editor;->putInt(Ljava/lang/String;I)Landroid/content/SharedPreferences$Editor;

    .line 478
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mPreferenceEditor:Landroid/content/SharedPreferences$Editor;

    invoke-interface {p0}, Landroid/content/SharedPreferences$Editor;->apply()V

    return-void
.end method

.method public final hvlsr_set_source(I)V
    .registers 2

    .line 536
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0, p1}, Lcom/thermasol/thermatouchservice/IHardwareService;->hvlsr_set_source(I)V

    return-void
.end method

.method public final hvlsr_set_white_rbga(I)V
    .registers 5

    .line 483
    iget-object v0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {v0, p1}, Lcom/thermasol/thermatouchservice/IHardwareService;->hvlsr_set_white_rbga(I)V

    .line 485
    iget-object v0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mPreferenceEditor:Landroid/content/SharedPreferences$Editor;

    sget v1, Lcom/thermasol/touchsteam2/GV;->ActiveUser:I

    invoke-static {v1}, Ljava/lang/Integer;->valueOf(I)Ljava/lang/Integer;

    move-result-object v1

    const-string v2, "rgbColorUser"

    invoke-static {v2, v1}, Lkotlin/jvm/internal/Intrinsics;->stringPlus(Ljava/lang/String;Ljava/lang/Object;)Ljava/lang/String;

    move-result-object v1

    shr-int/lit8 p1, p1, 0x8

    invoke-interface {v0, v1, p1}, Landroid/content/SharedPreferences$Editor;->putInt(Ljava/lang/String;I)Landroid/content/SharedPreferences$Editor;

    .line 486
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mPreferenceEditor:Landroid/content/SharedPreferences$Editor;

    invoke-interface {p0}, Landroid/content/SharedPreferences$Editor;->apply()V

    return-void
.end method

.method public final hvlsr_treble_volume(I)V
    .registers 2

    .line 531
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0, p1}, Lcom/thermasol/thermatouchservice/IHardwareService;->hvlsr_treble_volume(I)V

    return-void
.end method

.method public final hvlsr_unmute()V
    .registers 1

    .line 511
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0}, Lcom/thermasol/thermatouchservice/IHardwareService;->hvlsr_unmute()V

    return-void
.end method

.method public onAccuracyChanged(Landroid/hardware/Sensor;I)V
    .registers 3

    return-void
.end method

.method public onSensorChanged(Landroid/hardware/SensorEvent;)V
    .registers 4

    if-eqz p1, :cond_21

    .line 592
    invoke-static {}, Lcom/thermasol/touchsteam2/util/Utils;->isVantron()Z

    move-result v0

    const/4 v1, 0x0

    if-eqz v0, :cond_16

    .line 593
    iget-object p1, p1, Landroid/hardware/SensorEvent;->values:[F

    aget p1, p1, v1

    invoke-static {p1}, Lcom/thermasol/utils/Utility;->vantronSensorToKelvin(F)F

    move-result p1

    .line 594
    invoke-static {p1}, Lcom/thermasol/utils/Utility;->kelvinToFahrenheit(F)F

    move-result p1

    goto :goto_1e

    .line 596
    :cond_16
    iget-object p1, p1, Landroid/hardware/SensorEvent;->values:[F

    aget p1, p1, v1

    invoke-static {p1}, Lcom/thermasol/utils/Utility;->celsiusToFahrenheit(F)F

    move-result p1

    :goto_1e
    float-to-int p1, p1

    .line 592
    iput p1, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mTemperature:I

    :cond_21
    return-void
.end method

.method public final psb_get_errors()I
    .registers 1

    .line 164
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0}, Lcom/thermasol/thermatouchservice/IHardwareService;->psb_get_errors()I

    move-result p0

    return p0
.end method

.method public final psb_get_faststart_mode()I
    .registers 2

    .line 205
    iget-object v0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {v0}, Lcom/thermasol/thermatouchservice/IHardwareService;->psb_get_faststart_mode()I

    move-result v0

    invoke-direct {p0, v0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->bindFastStartValue(I)I

    move-result p0

    return p0
.end method

.method public final psb_get_is_psb_active()Z
    .registers 1

    .line 159
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0}, Lcom/thermasol/thermatouchservice/IHardwareService;->psb_get_is_psb_active()Z

    move-result p0

    return p0
.end method

.method public final psb_get_power_flush_timer()I
    .registers 1

    .line 230
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0}, Lcom/thermasol/thermatouchservice/IHardwareService;->psb_get_power_flush_timer()I

    move-result p0

    return p0
.end method

.method public final psb_get_psb_get_maintenance_counter()I
    .registers 1

    .line 225
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0}, Lcom/thermasol/thermatouchservice/IHardwareService;->psb_get_psb_get_maintenance_counter()I

    move-result p0

    return p0
.end method

.method public final psb_get_psb_run_hours()I
    .registers 1

    .line 220
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0}, Lcom/thermasol/thermatouchservice/IHardwareService;->psb_get_psb_run_hours()I

    move-result p0

    return p0
.end method

.method public final psb_get_psb_steam_timer()I
    .registers 1

    .line 137
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0}, Lcom/thermasol/thermatouchservice/IHardwareService;->psb_get_psb_steam_timer()I

    move-result p0

    return p0
.end method

.method public final psb_get_psb_temperature_setpoint()I
    .registers 1

    .line 174
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0}, Lcom/thermasol/thermatouchservice/IHardwareService;->psb_get_psb_temperature_setpoint()I

    move-result p0

    return p0
.end method

.method public final psb_get_remaining_steam_time()I
    .registers 1

    .line 210
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0}, Lcom/thermasol/thermatouchservice/IHardwareService;->psb_get_remaining_steam_time()I

    move-result p0

    return p0
.end method

.method public final psb_get_state()I
    .registers 1

    .line 169
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0}, Lcom/thermasol/thermatouchservice/IHardwareService;->psb_get_state()I

    move-result p0

    return p0
.end method

.method public final psb_send_heartbeat()V
    .registers 1

    .line 79
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0}, Lcom/thermasol/thermatouchservice/IHardwareService;->psb_send_heartbeat()V

    return-void
.end method

.method public final psb_send_psbstat_request()V
    .registers 1

    .line 114
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0}, Lcom/thermasol/thermatouchservice/IHardwareService;->psb_send_psbstat_request()V

    return-void
.end method

.method public final psb_set_current_room_temperature(F)V
    .registers 2

    .line 143
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0, p1}, Lcom/thermasol/thermatouchservice/IHardwareService;->psb_set_current_room_temperature(F)V

    return-void
.end method

.method public final psb_set_error(I)V
    .registers 2

    .line 119
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0, p1}, Lcom/thermasol/thermatouchservice/IHardwareService;->psb_set_error(I)V

    return-void
.end method

.method public final psb_set_faststart_mode(I)V
    .registers 2

    .line 154
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0, p1}, Lcom/thermasol/thermatouchservice/IHardwareService;->psb_set_faststart_mode(I)V

    return-void
.end method

.method public final psb_set_load_user(I)V
    .registers 2

    .line 84
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0, p1}, Lcom/thermasol/thermatouchservice/IHardwareService;->psb_set_load_user(I)V

    return-void
.end method

.method public final psb_set_temperature_setpoint(I)V
    .registers 5

    .line 124
    iget-object v0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {v0, p1}, Lcom/thermasol/thermatouchservice/IHardwareService;->psb_set_temperature_setpoint(I)V

    .line 125
    iget-object v0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mPreferenceEditor:Landroid/content/SharedPreferences$Editor;

    sget v1, Lcom/thermasol/touchsteam2/GV;->ActiveUser:I

    invoke-static {v1}, Ljava/lang/Integer;->valueOf(I)Ljava/lang/Integer;

    move-result-object v1

    const-string v2, "steamTempUser"

    invoke-static {v2, v1}, Lkotlin/jvm/internal/Intrinsics;->stringPlus(Ljava/lang/String;Ljava/lang/Object;)Ljava/lang/String;

    move-result-object v1

    invoke-interface {v0, v1, p1}, Landroid/content/SharedPreferences$Editor;->putInt(Ljava/lang/String;I)Landroid/content/SharedPreferences$Editor;

    .line 126
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mPreferenceEditor:Landroid/content/SharedPreferences$Editor;

    invoke-interface {p0}, Landroid/content/SharedPreferences$Editor;->apply()V

    return-void
.end method

.method public final psb_set_timer_setpoint(I)V
    .registers 2

    .line 131
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0, p1}, Lcom/thermasol/thermatouchservice/IHardwareService;->psb_set_timer_setpoint(I)V

    return-void
.end method

.method public final psb_steam_timer_finished()Z
    .registers 1

    .line 215
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0}, Lcom/thermasol/thermatouchservice/IHardwareService;->psb_steam_timer_finished()Z

    move-result p0

    return p0
.end method

.method public final psb_turn_off_power_flush()V
    .registers 1

    .line 109
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0}, Lcom/thermasol/thermatouchservice/IHardwareService;->psb_turn_off_power_flush()V

    return-void
.end method

.method public final psb_turn_off_steam()V
    .registers 1

    .line 99
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0}, Lcom/thermasol/thermatouchservice/IHardwareService;->psb_turn_off_steam()V

    return-void
.end method

.method public final psb_turn_on_faststart_mode()V
    .registers 1

    .line 149
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0}, Lcom/thermasol/thermatouchservice/IHardwareService;->psb_turn_on_faststart_mode()V

    return-void
.end method

.method public final psb_turn_on_power_flush()V
    .registers 1

    .line 104
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0}, Lcom/thermasol/thermatouchservice/IHardwareService;->psb_turn_on_power_flush()V

    return-void
.end method

.method public final psb_turn_on_steam()V
    .registers 2

    .line 94
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    sget v0, Lcom/thermasol/touchsteam2/GV;->ActiveUser:I

    invoke-interface {p0, v0}, Lcom/thermasol/thermatouchservice/IHardwareService;->psb_turn_on_steam(I)V

    return-void
.end method

.method public final psb_user_logout()V
    .registers 1

    .line 89
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0}, Lcom/thermasol/thermatouchservice/IHardwareService;->psb_user_logout()V

    return-void
.end method

.method public final slsr_bluetooth_get_devicename()Ljava/lang/String;
    .registers 1

    .line 454
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0}, Lcom/thermasol/thermatouchservice/IHardwareService;->slsr_bluetooth_get_devicename()Ljava/lang/String;

    move-result-object p0

    return-object p0
.end method

.method public final slsr_bluetooth_pause()V
    .registers 1

    .line 424
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0}, Lcom/thermasol/thermatouchservice/IHardwareService;->slsr_bluetooth_pause()V

    return-void
.end method

.method public final slsr_bluetooth_play()V
    .registers 1

    .line 419
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0}, Lcom/thermasol/thermatouchservice/IHardwareService;->slsr_bluetooth_play()V

    return-void
.end method

.method public final slsr_bluetooth_power_off()V
    .registers 1

    .line 449
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0}, Lcom/thermasol/thermatouchservice/IHardwareService;->slsr_bluetooth_power_off()V

    return-void
.end method

.method public final slsr_bluetooth_power_on()V
    .registers 1

    .line 444
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0}, Lcom/thermasol/thermatouchservice/IHardwareService;->slsr_bluetooth_power_on()V

    return-void
.end method

.method public final slsr_bluetooth_skip_back()V
    .registers 1

    .line 434
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0}, Lcom/thermasol/thermatouchservice/IHardwareService;->slsr_bluetooth_skip_back()V

    return-void
.end method

.method public final slsr_bluetooth_skip_forward()V
    .registers 1

    .line 429
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0}, Lcom/thermasol/thermatouchservice/IHardwareService;->slsr_bluetooth_skip_forward()V

    return-void
.end method

.method public final slsr_chroma_state(I)V
    .registers 2

    .line 349
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0, p1}, Lcom/thermasol/thermatouchservice/IHardwareService;->slsr_chroma_state(I)V

    return-void
.end method

.method public final slsr_get_bluetooth_state()I
    .registers 1

    .line 439
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0}, Lcom/thermasol/thermatouchservice/IHardwareService;->slsr_get_bluetooth_state()I

    move-result p0

    return p0
.end method

.method public final slsr_get_version()I
    .registers 1

    .line 404
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0}, Lcom/thermasol/thermatouchservice/IHardwareService;->slsr_get_version()I

    move-result p0

    return p0
.end method

.method public final slsr_is_active()Z
    .registers 1

    .line 384
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0}, Lcom/thermasol/thermatouchservice/IHardwareService;->slsr_is_active()Z

    move-result p0

    return p0
.end method

.method public final slsr_is_slsr_bluetooth_present()Z
    .registers 1

    .line 459
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0}, Lcom/thermasol/thermatouchservice/IHardwareService;->slsr_is_slsr_bluetooth_present()Z

    move-result p0

    return p0
.end method

.method public final slsr_music_bass_tone(I)V
    .registers 2

    .line 364
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0, p1}, Lcom/thermasol/thermatouchservice/IHardwareService;->slsr_music_bass_tone(I)V

    return-void
.end method

.method public final slsr_music_mid_tone(I)V
    .registers 2

    .line 369
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0, p1}, Lcom/thermasol/thermatouchservice/IHardwareService;->slsr_music_mid_tone(I)V

    return-void
.end method

.method public final slsr_music_on_off(Z)V
    .registers 2

    .line 317
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0, p1}, Lcom/thermasol/thermatouchservice/IHardwareService;->slsr_music_on_off(Z)V

    return-void
.end method

.method public final slsr_music_treble_tone(I)V
    .registers 2

    .line 374
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0, p1}, Lcom/thermasol/thermatouchservice/IHardwareService;->slsr_music_treble_tone(I)V

    return-void
.end method

.method public final slsr_request_sls_standby()V
    .registers 1

    .line 294
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0}, Lcom/thermasol/thermatouchservice/IHardwareService;->slsr_request_sls_standby()V

    return-void
.end method

.method public final slsr_request_sls_stats()V
    .registers 1

    .line 399
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0}, Lcom/thermasol/thermatouchservice/IHardwareService;->slsr_request_sls_stats()V

    return-void
.end method

.method public final slsr_set_light_intensity(I)V
    .registers 2

    .line 344
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0, p1}, Lcom/thermasol/thermatouchservice/IHardwareService;->slsr_set_light_intensity(I)V

    return-void
.end method

.method public final slsr_set_light_mode(I)V
    .registers 2

    .line 354
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0, p1}, Lcom/thermasol/thermatouchservice/IHardwareService;->slsr_set_light_mode(I)V

    return-void
.end method

.method public final slsr_set_music_volume(I)V
    .registers 2

    .line 359
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0, p1}, Lcom/thermasol/thermatouchservice/IHardwareService;->slsr_set_music_volume(I)V

    return-void
.end method

.method public final slsr_set_radio_channel()V
    .registers 1

    .line 379
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0}, Lcom/thermasol/thermatouchservice/IHardwareService;->slsr_set_radio_channel()V

    return-void
.end method

.method public final slsr_set_source(I)V
    .registers 2

    .line 322
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0, p1}, Lcom/thermasol/thermatouchservice/IHardwareService;->slsr_set_source(I)V

    return-void
.end method

.method public final slsr_set_temperature_format(I)V
    .registers 5

    .line 337
    iget-object v0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {v0, p1}, Lcom/thermasol/thermatouchservice/IHardwareService;->slsr_set_temperature_format(I)V

    .line 338
    iget-object v0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mPreferenceEditor:Landroid/content/SharedPreferences$Editor;

    sget v1, Lcom/thermasol/touchsteam2/GV;->ActiveUser:I

    invoke-static {v1}, Ljava/lang/Integer;->valueOf(I)Ljava/lang/Integer;

    move-result-object v1

    const-string v2, "tempFormatUser"

    invoke-static {v2, v1}, Lkotlin/jvm/internal/Intrinsics;->stringPlus(Ljava/lang/String;Ljava/lang/Object;)Ljava/lang/String;

    move-result-object v1

    invoke-interface {v0, v1, p1}, Landroid/content/SharedPreferences$Editor;->putInt(Ljava/lang/String;I)Landroid/content/SharedPreferences$Editor;

    .line 339
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mPreferenceEditor:Landroid/content/SharedPreferences$Editor;

    invoke-interface {p0}, Landroid/content/SharedPreferences$Editor;->apply()V

    return-void
.end method

.method public final slsr_set_voice_volume(I)V
    .registers 5

    .line 299
    iget-object v0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {v0, p1}, Lcom/thermasol/thermatouchservice/IHardwareService;->slsr_set_voice_volume(I)V

    .line 300
    iget-object v0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mPreferenceEditor:Landroid/content/SharedPreferences$Editor;

    sget v1, Lcom/thermasol/touchsteam2/GV;->ActiveUser:I

    invoke-static {v1}, Ljava/lang/Integer;->valueOf(I)Ljava/lang/Integer;

    move-result-object v1

    const-string v2, "voiceVolumeUser"

    invoke-static {v2, v1}, Lkotlin/jvm/internal/Intrinsics;->stringPlus(Ljava/lang/String;Ljava/lang/Object;)Ljava/lang/String;

    move-result-object v1

    invoke-interface {v0, v1, p1}, Landroid/content/SharedPreferences$Editor;->putInt(Ljava/lang/String;I)Landroid/content/SharedPreferences$Editor;

    .line 301
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mPreferenceEditor:Landroid/content/SharedPreferences$Editor;

    invoke-interface {p0}, Landroid/content/SharedPreferences$Editor;->apply()V

    return-void
.end method

.method public final slsr_turn_off_light()V
    .registers 1

    .line 332
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0}, Lcom/thermasol/thermatouchservice/IHardwareService;->slsr_turn_off_light()V

    return-void
.end method

.method public final slsr_turn_on_light()V
    .registers 1

    .line 327
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0}, Lcom/thermasol/thermatouchservice/IHardwareService;->slsr_turn_on_light()V

    return-void
.end method

.method public final slsr_voice_mute()V
    .registers 1

    .line 389
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0}, Lcom/thermasol/thermatouchservice/IHardwareService;->slsr_voice_mute()V

    return-void
.end method

.method public final slsr_voice_on_off(Z)V
    .registers 5

    .line 309
    iget-object v0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {v0, p1}, Lcom/thermasol/thermatouchservice/IHardwareService;->slsr_voice_on_off(Z)V

    .line 310
    iget-object v0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mPreferenceEditor:Landroid/content/SharedPreferences$Editor;

    sget v1, Lcom/thermasol/touchsteam2/GV;->ActiveUser:I

    invoke-static {v1}, Ljava/lang/Integer;->valueOf(I)Ljava/lang/Integer;

    move-result-object v1

    const-string v2, "voiceStateUser"

    invoke-static {v2, v1}, Lkotlin/jvm/internal/Intrinsics;->stringPlus(Ljava/lang/String;Ljava/lang/Object;)Ljava/lang/String;

    move-result-object v1

    invoke-interface {v0, v1, p1}, Landroid/content/SharedPreferences$Editor;->putInt(Ljava/lang/String;I)Landroid/content/SharedPreferences$Editor;

    .line 311
    iget-object v0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mPreferenceEditor:Landroid/content/SharedPreferences$Editor;

    invoke-interface {v0}, Landroid/content/SharedPreferences$Editor;->apply()V

    .line 312
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mContext:Landroid/content/Context;

    invoke-static {p1}, Ljava/lang/Integer;->valueOf(I)Ljava/lang/Integer;

    move-result-object p1

    check-cast p1, Ljava/lang/Number;

    const-string v0, "slsr_info"

    const-string v1, "voice_state"

    invoke-static {p0, v0, v1, p1}, Lcom/thermasol/touchsteam2/util/FirebaseAnalyticEvents;->logEvent(Landroid/content/Context;Ljava/lang/String;Ljava/lang/String;Ljava/lang/Number;)V

    return-void
.end method

.method public final slsr_voice_unmute()V
    .registers 1

    .line 394
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0}, Lcom/thermasol/thermatouchservice/IHardwareService;->slsr_voice_unmute()V

    return-void
.end method

.method public final thermacan_close()V
    .registers 1

    .line 65
    invoke-static {}, Lcom/thermasol/utils/Utility;->waitForHardwareReaction()V

    .line 66
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0}, Lcom/thermasol/thermatouchservice/IHardwareService;->thermacan_close()V

    return-void
.end method

.method public final thermacan_open()V
    .registers 4

    const/4 v0, 0x0

    .line 54
    iput-boolean v0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mSimulated:Z

    .line 55
    iget-object v1, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mPreferences:Landroid/content/SharedPreferences;

    const-string v2, "simulated"

    invoke-interface {v1, v2, v0}, Landroid/content/SharedPreferences;->getBoolean(Ljava/lang/String;Z)Z

    move-result v0

    if-eqz v0, :cond_10

    const/4 v0, 0x1

    .line 57
    iput-boolean v0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mSimulated:Z

    .line 59
    :cond_10
    iget-object v0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    iget-boolean p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mSimulated:Z

    invoke-interface {v0, p0}, Lcom/thermasol/thermatouchservice/IHardwareService;->thermacan_open(Z)V

    return-void
.end method

.method public final thermacan_reset(I)V
    .registers 2

    .line 72
    iget-object p0, p0, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->mNative:Lcom/thermasol/thermatouchservice/IHardwareService;

    invoke-interface {p0, p1}, Lcom/thermasol/thermatouchservice/IHardwareService;->thermacan_reset(I)V

    return-void
.end method
