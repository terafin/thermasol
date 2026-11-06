.class public final Lcom/thermasol/touchsteam2/util/OverheadLight;
.super Ljava/lang/Object;
.source "OverheadLight.kt"


# annotations
.annotation system Ldalvik/annotation/MemberClasses;
    value = {
        Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;,
        Lcom/thermasol/touchsteam2/util/OverheadLight$WhenMappings;
    }
.end annotation

.annotation runtime Lkotlin/Metadata;
    d1 = {
        "\u0000>\n\u0002\u0018\u0002\n\u0002\u0010\u0000\n\u0002\u0008\u0002\n\u0002\u0010\u000e\n\u0000\n\u0002\u0010\u0008\n\u0002\u0008\r\n\u0002\u0018\u0002\n\u0002\u0008\u0002\n\u0002\u0010\u000b\n\u0000\n\u0002\u0010\u0002\n\u0002\u0008\u000b\n\u0002\u0018\u0002\n\u0000\n\u0002\u0018\u0002\n\u0002\u0008\u001b\u0008\u00c6\u0002\u0018\u00002\u00020\u0001:\u0001AB\u0007\u0008\u0002\u00a2\u0006\u0002\u0010\u0002J\u0010\u0010\u0012\u001a\u00020\u00042\u0006\u0010\u0013\u001a\u00020\u0014H\u0007J\u0012\u0010\u0015\u001a\u0004\u0018\u00010\u00042\u0006\u0010\u0013\u001a\u00020\u0014H\u0007J\u0010\u0010\u0016\u001a\u00020\u00172\u0006\u0010\u0013\u001a\u00020\u0014H\u0007J\u0010\u0010\u0018\u001a\u00020\u00192\u0006\u0010\u0013\u001a\u00020\u0014H\u0007J\u0010\u0010\u001a\u001a\u00020\u00192\u0006\u0010\u0013\u001a\u00020\u0014H\u0007J\u0010\u0010\u001b\u001a\u00020\u00192\u0006\u0010\u0013\u001a\u00020\u0014H\u0007J\u0010\u0010\u001c\u001a\u00020\u00192\u0006\u0010\u0013\u001a\u00020\u0014H\u0007J\u0010\u0010\u001d\u001a\u00020\u00062\u0006\u0010\u0013\u001a\u00020\u0014H\u0007J\u0010\u0010\u001e\u001a\u00020\u00062\u0006\u0010\u0013\u001a\u00020\u0014H\u0007J\u0008\u0010\u001f\u001a\u00020\u0006H\u0007J\u0008\u0010 \u001a\u00020\u0006H\u0007J\u0010\u0010!\u001a\u00020\u00062\u0006\u0010\u0013\u001a\u00020\u0014H\u0007J\u0008\u0010\"\u001a\u00020\u0006H\u0007J\u0008\u0010#\u001a\u00020\u0006H\u0007J\u0010\u0010$\u001a\u00020%2\u0006\u0010&\u001a\u00020\'H\u0007J\u0010\u0010(\u001a\u00020\u00172\u0006\u0010&\u001a\u00020\'H\u0007J\u0010\u0010)\u001a\u00020\u00172\u0006\u0010&\u001a\u00020\'H\u0007J\u0010\u0010*\u001a\u00020\u00172\u0006\u0010\u0013\u001a\u00020\u0014H\u0007J\u0010\u0010+\u001a\u00020\u00192\u0006\u0010\u0013\u001a\u00020\u0014H\u0007J\u0018\u0010,\u001a\u00020\u00192\u0006\u0010\u0013\u001a\u00020\u00142\u0006\u0010-\u001a\u00020\u0017H\u0002J\u0010\u0010.\u001a\u00020\u00192\u0006\u0010\u0013\u001a\u00020\u0014H\u0007J\u0010\u0010/\u001a\u00020\u00192\u0006\u0010\u0013\u001a\u00020\u0014H\u0007J\u0018\u00100\u001a\u00020\u00192\u0006\u0010\u0013\u001a\u00020\u00142\u0006\u00101\u001a\u00020\u0006H\u0007J\u0018\u00102\u001a\u00020\u00192\u0006\u0010\u0013\u001a\u00020\u00142\u0006\u0010-\u001a\u00020\u0006H\u0007J \u00103\u001a\u00020\u00192\u0006\u0010&\u001a\u00020\'2\u0006\u0010\u0013\u001a\u00020\u00142\u0006\u00104\u001a\u00020\u0006H\u0007J\u0018\u00105\u001a\u00020\u00192\u0006\u0010\u0013\u001a\u00020\u00142\u0006\u00104\u001a\u00020\u0006H\u0007J\u0018\u00106\u001a\u00020\u00192\u0006\u0010\u0013\u001a\u00020\u00142\u0006\u00101\u001a\u00020\u0006H\u0007J\u0018\u00107\u001a\u00020\u00192\u0006\u0010\u0013\u001a\u00020\u00142\u0006\u00101\u001a\u00020\u0006H\u0007J\u0018\u00108\u001a\u00020\u00192\u0006\u0010\u0013\u001a\u00020\u00142\u0006\u00109\u001a\u00020\u0006H\u0007J\u0018\u0010:\u001a\u00020\u00192\u0006\u0010\u0013\u001a\u00020\u00142\u0006\u0010;\u001a\u00020\u0006H\u0007J\u0018\u0010<\u001a\u00020\u00192\u0006\u0010\u0013\u001a\u00020\u00142\u0006\u00101\u001a\u00020\u0006H\u0007J\u0018\u0010=\u001a\u00020\u00062\u0006\u0010\u0013\u001a\u00020\u00142\u0006\u0010-\u001a\u00020\u0006H\u0007J\u0010\u0010>\u001a\u00020\u00192\u0006\u0010\u0013\u001a\u00020\u0014H\u0007J\u0010\u0010?\u001a\u00020\u00192\u0006\u0010\u0013\u001a\u00020\u0014H\u0007J\u0010\u0010@\u001a\u00020\u00192\u0006\u0010\u0013\u001a\u00020\u0014H\u0007R\u000e\u0010\u0003\u001a\u00020\u0004X\u0086T\u00a2\u0006\u0002\n\u0000R\u000e\u0010\u0005\u001a\u00020\u0006X\u0086T\u00a2\u0006\u0002\n\u0000R\u000e\u0010\u0007\u001a\u00020\u0004X\u0086T\u00a2\u0006\u0002\n\u0000R\u000e\u0010\u0008\u001a\u00020\u0004X\u0086T\u00a2\u0006\u0002\n\u0000R\u000e\u0010\t\u001a\u00020\u0004X\u0086T\u00a2\u0006\u0002\n\u0000R\u000e\u0010\n\u001a\u00020\u0004X\u0086T\u00a2\u0006\u0002\n\u0000R\u000e\u0010\u000b\u001a\u00020\u0006X\u0086T\u00a2\u0006\u0002\n\u0000R\u000e\u0010\u000c\u001a\u00020\u0004X\u0086T\u00a2\u0006\u0002\n\u0000R\u000e\u0010\r\u001a\u00020\u0004X\u0086T\u00a2\u0006\u0002\n\u0000R\u000e\u0010\u000e\u001a\u00020\u0006X\u0086T\u00a2\u0006\u0002\n\u0000R\u000e\u0010\u000f\u001a\u00020\u0006X\u0082T\u00a2\u0006\u0002\n\u0000R\u000e\u0010\u0010\u001a\u00020\u0006X\u0082T\u00a2\u0006\u0002\n\u0000R\u000e\u0010\u0011\u001a\u00020\u0004X\u0086T\u00a2\u0006\u0002\n\u0000\u00a8\u0006B"
    }
    d2 = {
        "Lcom/thermasol/touchsteam2/util/OverheadLight;",
        "",
        "()V",
        "BASS_FORMAT_KEY",
        "",
        "DEFAULT_VOLUME",
        "",
        "LIGHT_INTENSITY_KEY",
        "LIGHT_MODE_KEY",
        "LIGHT_STATE_KEY",
        "MID_FORMAT_KEY",
        "MIN_VOLUME",
        "MUSIC_SOURCE_KEY",
        "MUSIC_VOLUME_KEY",
        "NORMAL_MAX_VOLUME",
        "SLSR_BASS_MAX_VOLUME",
        "SUPPRESSED_MAX_VOLUME",
        "TREBLE_FORMAT_KEY",
        "bluetoothBroadcastReminder",
        "context",
        "Landroid/content/Context;",
        "bluetoothGetDeviceName",
        "bluetoothIsPresent",
        "",
        "bluetoothPause",
        "",
        "bluetoothPlay",
        "bluetoothSkipBack",
        "bluetoothSkipForward",
        "getBluetoothState",
        "getDefaultBassVolume",
        "getDefaultMidVolume",
        "getDefaultTrebleVolume",
        "getMaxBassVolume",
        "getMaxMidVolume",
        "getMaxTrebleVolume",
        "getType",
        "Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;",
        "service",
        "Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;",
        "hasBluetoothCapability",
        "hasVoiceCapability",
        "isActive",
        "mute",
        "persistLightState",
        "state",
        "powerOffBluetooth",
        "powerOnBluetooth",
        "setBassVolume",
        "volume",
        "setChromaState",
        "setHvlsrRgbAndIntensity",
        "value",
        "setIntensity",
        "setMasterVolume",
        "setMidVolume",
        "setMode",
        "mode",
        "setSource",
        "requested",
        "setTrebleVolume",
        "translateStateToColorHex",
        "turnOff",
        "turnOn",
        "unmute",
        "LightType",
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
.field public static volatile sShutdownMuted:Z

.field public static final BASS_FORMAT_KEY:Ljava/lang/String; = "bassVolumeUser"

.field public static final DEFAULT_VOLUME:I = 0xa

.field public static final INSTANCE:Lcom/thermasol/touchsteam2/util/OverheadLight;

.field public static final LIGHT_INTENSITY_KEY:Ljava/lang/String; = "lightIntensityUser"

.field public static final LIGHT_MODE_KEY:Ljava/lang/String; = "lightModeUser"

.field public static final LIGHT_STATE_KEY:Ljava/lang/String; = "lightStateUser"

.field public static final MID_FORMAT_KEY:Ljava/lang/String; = "midVolumeUser"

.field public static final MIN_VOLUME:I = 0x0

.field public static final MUSIC_SOURCE_KEY:Ljava/lang/String; = "musicSourceUser"

.field public static final MUSIC_VOLUME_KEY:Ljava/lang/String; = "musicVolumeUser"

.field public static final NORMAL_MAX_VOLUME:I = 0xf

.field private static final SLSR_BASS_MAX_VOLUME:I = 0x14

.field private static final SUPPRESSED_MAX_VOLUME:I = 0xe

.field public static final TREBLE_FORMAT_KEY:Ljava/lang/String; = "trebleVolumeUser"


# direct methods
.method static constructor <clinit>()V
    .registers 1

    new-instance v0, Lcom/thermasol/touchsteam2/util/OverheadLight;

    invoke-direct {v0}, Lcom/thermasol/touchsteam2/util/OverheadLight;-><init>()V

    sput-object v0, Lcom/thermasol/touchsteam2/util/OverheadLight;->INSTANCE:Lcom/thermasol/touchsteam2/util/OverheadLight;

    return-void
.end method

.method private constructor <init>()V
    .registers 1

    .line 16
    invoke-direct {p0}, Ljava/lang/Object;-><init>()V

    return-void
.end method

.method public static final bluetoothBroadcastReminder(Landroid/content/Context;)Ljava/lang/String;
    .registers 3
    .annotation runtime Lkotlin/jvm/JvmStatic;
    .end annotation

    const-string v0, "context"

    invoke-static {p0, v0}, Lkotlin/jvm/internal/Intrinsics;->checkNotNullParameter(Ljava/lang/Object;Ljava/lang/String;)V

    .line 451
    move-object v0, p0

    check-cast v0, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;

    invoke-interface {v0}, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;->getInstance()Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;

    move-result-object v0

    .line 452
    invoke-static {v0}, Lcom/thermasol/touchsteam2/util/OverheadLight;->getType(Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;)Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;

    move-result-object v0

    sget-object v1, Lcom/thermasol/touchsteam2/util/OverheadLight$WhenMappings;->$EnumSwitchMapping$0:[I

    invoke-virtual {v0}, Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;->ordinal()I

    move-result v0

    aget v0, v1, v0

    const/4 v1, 0x1

    if-eq v0, v1, :cond_34

    const/4 v1, 0x2

    if-eq v0, v1, :cond_27

    const/4 v1, 0x3

    if-eq v0, v1, :cond_27

    const/4 v1, 0x4

    if-eq v0, v1, :cond_27

    const-string p0, ""

    goto :goto_40

    :cond_27
    const v0, 0x7f110044

    .line 459
    invoke-virtual {p0, v0}, Landroid/content/Context;->getString(I)Ljava/lang/String;

    move-result-object p0

    const-string v0, "{\n                context.getString(R.string.bluetooth_broadcast_message)\n            }"

    .line 458
    invoke-static {p0, v0}, Lkotlin/jvm/internal/Intrinsics;->checkNotNullExpressionValue(Ljava/lang/Object;Ljava/lang/String;)V

    goto :goto_40

    :cond_34
    const v0, 0x7f110078

    .line 454
    invoke-virtual {p0, v0}, Landroid/content/Context;->getString(I)Ljava/lang/String;

    move-result-object p0

    const-string v0, "{\n                context.getString(R.string.hydrovive_bluetooth_message)\n            }"

    .line 453
    invoke-static {p0, v0}, Lkotlin/jvm/internal/Intrinsics;->checkNotNullExpressionValue(Ljava/lang/Object;Ljava/lang/String;)V

    :goto_40
    return-object p0
.end method

.method public static final bluetoothGetDeviceName(Landroid/content/Context;)Ljava/lang/String;
    .registers 3
    .annotation runtime Lkotlin/jvm/JvmStatic;
    .end annotation

    const-string v0, "context"

    invoke-static {p0, v0}, Lkotlin/jvm/internal/Intrinsics;->checkNotNullParameter(Ljava/lang/Object;Ljava/lang/String;)V

    .line 610
    check-cast p0, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;

    invoke-interface {p0}, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;->getInstance()Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;

    move-result-object p0

    .line 611
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/OverheadLight;->getType(Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;)Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;

    move-result-object v0

    sget-object v1, Lcom/thermasol/touchsteam2/util/OverheadLight$WhenMappings;->$EnumSwitchMapping$0:[I

    invoke-virtual {v0}, Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;->ordinal()I

    move-result v0

    aget v0, v1, v0

    const/4 v1, 0x1

    if-eq v0, v1, :cond_2b

    const/4 v1, 0x2

    if-eq v0, v1, :cond_26

    const/4 v1, 0x3

    if-eq v0, v1, :cond_26

    const/4 v1, 0x4

    if-eq v0, v1, :cond_26

    const-string p0, ""

    goto :goto_2f

    .line 618
    :cond_26
    invoke-virtual {p0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->slsr_bluetooth_get_devicename()Ljava/lang/String;

    move-result-object p0

    goto :goto_2f

    .line 613
    :cond_2b
    invoke-virtual {p0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->hvlsr_bluetooth_get_devicename()Ljava/lang/String;

    move-result-object p0

    :goto_2f
    return-object p0
.end method

.method public static final bluetoothIsPresent(Landroid/content/Context;)Z
    .registers 3
    .annotation runtime Lkotlin/jvm/JvmStatic;
    .end annotation

    const-string v0, "context"

    invoke-static {p0, v0}, Lkotlin/jvm/internal/Intrinsics;->checkNotNullParameter(Ljava/lang/Object;Ljava/lang/String;)V

    .line 470
    check-cast p0, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;

    invoke-interface {p0}, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;->getInstance()Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;

    move-result-object p0

    .line 471
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/OverheadLight;->getType(Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;)Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;

    move-result-object v0

    sget-object v1, Lcom/thermasol/touchsteam2/util/OverheadLight$WhenMappings;->$EnumSwitchMapping$0:[I

    invoke-virtual {v0}, Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;->ordinal()I

    move-result v0

    aget v0, v1, v0

    const/4 v1, 0x1

    if-eq v0, v1, :cond_29

    const/4 v1, 0x2

    if-eq v0, v1, :cond_25

    const/4 v1, 0x3

    if-eq v0, v1, :cond_25

    const/4 v1, 0x4

    if-eq v0, v1, :cond_25

    const/4 v1, 0x0

    goto :goto_29

    .line 478
    :cond_25
    invoke-virtual {p0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->slsr_is_slsr_bluetooth_present()Z

    move-result v1

    :cond_29
    :goto_29
    return v1
.end method

.method public static final bluetoothPause(Landroid/content/Context;)V
    .registers 3
    .annotation runtime Lkotlin/jvm/JvmStatic;
    .end annotation

    const-string v0, "context"

    invoke-static {p0, v0}, Lkotlin/jvm/internal/Intrinsics;->checkNotNullParameter(Ljava/lang/Object;Ljava/lang/String;)V

    .line 559
    check-cast p0, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;

    invoke-interface {p0}, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;->getInstance()Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;

    move-result-object p0

    .line 560
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/OverheadLight;->getType(Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;)Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;

    move-result-object v0

    sget-object v1, Lcom/thermasol/touchsteam2/util/OverheadLight$WhenMappings;->$EnumSwitchMapping$0:[I

    invoke-virtual {v0}, Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;->ordinal()I

    move-result v0

    aget v0, v1, v0

    const/4 v1, 0x1

    if-eq v0, v1, :cond_28

    const/4 v1, 0x2

    if-eq v0, v1, :cond_24

    const/4 v1, 0x3

    if-eq v0, v1, :cond_24

    const/4 v1, 0x4

    if-eq v0, v1, :cond_24

    goto :goto_2b

    .line 567
    :cond_24
    invoke-virtual {p0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->slsr_bluetooth_pause()V

    goto :goto_2b

    .line 562
    :cond_28
    invoke-virtual {p0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->hvlsr_bluetooth_pause()V

    :goto_2b
    return-void
.end method

.method public static final bluetoothPlay(Landroid/content/Context;)V
    .registers 3
    .annotation runtime Lkotlin/jvm/JvmStatic;
    .end annotation

    const-string v0, "context"

    invoke-static {p0, v0}, Lkotlin/jvm/internal/Intrinsics;->checkNotNullParameter(Ljava/lang/Object;Ljava/lang/String;)V

    .line 542
    check-cast p0, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;

    invoke-interface {p0}, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;->getInstance()Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;

    move-result-object p0

    .line 543
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/OverheadLight;->getType(Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;)Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;

    move-result-object v0

    sget-object v1, Lcom/thermasol/touchsteam2/util/OverheadLight$WhenMappings;->$EnumSwitchMapping$0:[I

    invoke-virtual {v0}, Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;->ordinal()I

    move-result v0

    aget v0, v1, v0

    const/4 v1, 0x1

    if-eq v0, v1, :cond_28

    const/4 v1, 0x2

    if-eq v0, v1, :cond_24

    const/4 v1, 0x3

    if-eq v0, v1, :cond_24

    const/4 v1, 0x4

    if-eq v0, v1, :cond_24

    goto :goto_2b

    .line 550
    :cond_24
    invoke-virtual {p0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->slsr_bluetooth_play()V

    goto :goto_2b

    .line 545
    :cond_28
    invoke-virtual {p0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->hvlsr_bluetooth_play()V

    :goto_2b
    return-void
.end method

.method public static final bluetoothSkipBack(Landroid/content/Context;)V
    .registers 3
    .annotation runtime Lkotlin/jvm/JvmStatic;
    .end annotation

    const-string v0, "context"

    invoke-static {p0, v0}, Lkotlin/jvm/internal/Intrinsics;->checkNotNullParameter(Ljava/lang/Object;Ljava/lang/String;)V

    .line 593
    check-cast p0, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;

    invoke-interface {p0}, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;->getInstance()Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;

    move-result-object p0

    .line 594
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/OverheadLight;->getType(Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;)Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;

    move-result-object v0

    sget-object v1, Lcom/thermasol/touchsteam2/util/OverheadLight$WhenMappings;->$EnumSwitchMapping$0:[I

    invoke-virtual {v0}, Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;->ordinal()I

    move-result v0

    aget v0, v1, v0

    const/4 v1, 0x1

    if-eq v0, v1, :cond_28

    const/4 v1, 0x2

    if-eq v0, v1, :cond_24

    const/4 v1, 0x3

    if-eq v0, v1, :cond_24

    const/4 v1, 0x4

    if-eq v0, v1, :cond_24

    goto :goto_2b

    .line 601
    :cond_24
    invoke-virtual {p0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->slsr_bluetooth_skip_back()V

    goto :goto_2b

    .line 596
    :cond_28
    invoke-virtual {p0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->hvlsr_bluetooth_skip_back()V

    :goto_2b
    return-void
.end method

.method public static final bluetoothSkipForward(Landroid/content/Context;)V
    .registers 3
    .annotation runtime Lkotlin/jvm/JvmStatic;
    .end annotation

    const-string v0, "context"

    invoke-static {p0, v0}, Lkotlin/jvm/internal/Intrinsics;->checkNotNullParameter(Ljava/lang/Object;Ljava/lang/String;)V

    .line 576
    check-cast p0, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;

    invoke-interface {p0}, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;->getInstance()Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;

    move-result-object p0

    .line 577
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/OverheadLight;->getType(Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;)Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;

    move-result-object v0

    sget-object v1, Lcom/thermasol/touchsteam2/util/OverheadLight$WhenMappings;->$EnumSwitchMapping$0:[I

    invoke-virtual {v0}, Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;->ordinal()I

    move-result v0

    aget v0, v1, v0

    const/4 v1, 0x1

    if-eq v0, v1, :cond_28

    const/4 v1, 0x2

    if-eq v0, v1, :cond_24

    const/4 v1, 0x3

    if-eq v0, v1, :cond_24

    const/4 v1, 0x4

    if-eq v0, v1, :cond_24

    goto :goto_2b

    .line 584
    :cond_24
    invoke-virtual {p0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->slsr_bluetooth_skip_forward()V

    goto :goto_2b

    .line 579
    :cond_28
    invoke-virtual {p0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->hvlsr_bluetooth_skip_forward()V

    :goto_2b
    return-void
.end method

.method public static final getBluetoothState(Landroid/content/Context;)I
    .registers 3
    .annotation runtime Lkotlin/jvm/JvmStatic;
    .end annotation

    const-string v0, "context"

    invoke-static {p0, v0}, Lkotlin/jvm/internal/Intrinsics;->checkNotNullParameter(Ljava/lang/Object;Ljava/lang/String;)V

    .line 489
    check-cast p0, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;

    invoke-interface {p0}, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;->getInstance()Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;

    move-result-object p0

    .line 490
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/OverheadLight;->getType(Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;)Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;

    move-result-object v0

    sget-object v1, Lcom/thermasol/touchsteam2/util/OverheadLight$WhenMappings;->$EnumSwitchMapping$0:[I

    invoke-virtual {v0}, Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;->ordinal()I

    move-result v0

    aget v0, v1, v0

    const/4 v1, 0x1

    if-eq v0, v1, :cond_2b

    const/4 v1, 0x2

    if-eq v0, v1, :cond_26

    const/4 v1, 0x3

    if-eq v0, v1, :cond_26

    const/4 v1, 0x4

    if-eq v0, v1, :cond_26

    const/16 p0, 0x9

    goto :goto_2f

    .line 497
    :cond_26
    invoke-virtual {p0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->slsr_get_bluetooth_state()I

    move-result p0

    goto :goto_2f

    .line 492
    :cond_2b
    invoke-virtual {p0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->hvlsr_get_bluetooth_state()I

    move-result p0

    :goto_2f
    return p0
.end method

.method public static final getDefaultBassVolume(Landroid/content/Context;)I
    .registers 2
    .annotation runtime Lkotlin/jvm/JvmStatic;
    .end annotation

    const-string v0, "context"

    invoke-static {p0, v0}, Lkotlin/jvm/internal/Intrinsics;->checkNotNullParameter(Ljava/lang/Object;Ljava/lang/String;)V

    .line 445
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/OverheadLight;->getMaxBassVolume(Landroid/content/Context;)I

    move-result p0

    div-int/lit8 p0, p0, 0x2

    return p0
.end method

.method public static final getDefaultMidVolume()I
    .registers 1
    .annotation runtime Lkotlin/jvm/JvmStatic;
    .end annotation

    const/4 v0, 0x7

    return v0
.end method

.method public static final getDefaultTrebleVolume()I
    .registers 1
    .annotation runtime Lkotlin/jvm/JvmStatic;
    .end annotation

    const/4 v0, 0x7

    return v0
.end method

.method public static final getMaxBassVolume(Landroid/content/Context;)I
    .registers 2
    .annotation runtime Lkotlin/jvm/JvmStatic;
    .end annotation

    const-string v0, "context"

    invoke-static {p0, v0}, Lkotlin/jvm/internal/Intrinsics;->checkNotNullParameter(Ljava/lang/Object;Ljava/lang/String;)V

    .line 426
    check-cast p0, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;

    invoke-interface {p0}, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;->getInstance()Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;

    move-result-object p0

    .line 428
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/OverheadLight;->getType(Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;)Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;

    move-result-object p0

    sget-object v0, Lcom/thermasol/touchsteam2/util/OverheadLight$WhenMappings;->$EnumSwitchMapping$0:[I

    invoke-virtual {p0}, Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;->ordinal()I

    move-result p0

    aget p0, v0, p0

    const/4 v0, 0x1

    if-eq p0, v0, :cond_29

    const/4 v0, 0x2

    if-eq p0, v0, :cond_26

    const/4 v0, 0x3

    if-eq p0, v0, :cond_26

    const/4 v0, 0x4

    if-eq p0, v0, :cond_26

    const/16 p0, 0xa

    goto :goto_2b

    :cond_26
    const/16 p0, 0x14

    goto :goto_2b

    :cond_29
    const/16 p0, 0xe

    :goto_2b
    return p0
.end method

.method public static final getMaxMidVolume()I
    .registers 1
    .annotation runtime Lkotlin/jvm/JvmStatic;
    .end annotation

    const/16 v0, 0xe

    return v0
.end method

.method public static final getMaxTrebleVolume()I
    .registers 1
    .annotation runtime Lkotlin/jvm/JvmStatic;
    .end annotation

    const/16 v0, 0xe

    return v0
.end method

.method public static final getType(Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;)Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;
    .registers 3
    .annotation runtime Lkotlin/jvm/JvmStatic;
    .end annotation

    const-string v0, "service"

    invoke-static {p0, v0}, Lkotlin/jvm/internal/Intrinsics;->checkNotNullParameter(Ljava/lang/Object;Ljava/lang/String;)V

    .line 42
    sget-object v0, Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;->NONE:Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;

    .line 43
    invoke-virtual {p0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->hvlsr_is_active()Z

    move-result v1

    if-eqz v1, :cond_10

    .line 44
    sget-object v0, Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;->HVLSR:Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;

    goto :goto_2c

    .line 45
    :cond_10
    invoke-virtual {p0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->slsr_is_active()Z

    move-result v1

    if-eqz v1, :cond_2c

    .line 46
    invoke-virtual {p0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->slsr_get_version()I

    move-result p0

    const/16 v1, 0x16

    if-ge p0, v1, :cond_21

    .line 49
    sget-object v0, Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;->SLSR_AUX:Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;

    goto :goto_2c

    :cond_21
    if-ne p0, v1, :cond_26

    .line 52
    sget-object v0, Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;->SLSR_BLUETOOTH:Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;

    goto :goto_2c

    :cond_26
    const/16 v1, 0x17

    if-lt p0, v1, :cond_2c

    .line 55
    sget-object v0, Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;->SLSR_NO_VOICE:Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;

    :cond_2c
    :goto_2c
    return-object v0
.end method

.method public static final hasBluetoothCapability(Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;)Z
    .registers 2
    .annotation runtime Lkotlin/jvm/JvmStatic;
    .end annotation

    const-string v0, "service"

    invoke-static {p0, v0}, Lkotlin/jvm/internal/Intrinsics;->checkNotNullParameter(Ljava/lang/Object;Ljava/lang/String;)V

    .line 66
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/OverheadLight;->getType(Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;)Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;

    move-result-object p0

    .line 67
    sget-object v0, Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;->SLSR_BLUETOOTH:Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;

    if-eq p0, v0, :cond_18

    sget-object v0, Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;->SLSR_NO_VOICE:Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;

    if-eq p0, v0, :cond_18

    sget-object v0, Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;->HVLSR:Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;

    if-ne p0, v0, :cond_16

    goto :goto_18

    :cond_16
    const/4 p0, 0x0

    goto :goto_19

    :cond_18
    :goto_18
    const/4 p0, 0x1

    :goto_19
    return p0
.end method

.method public static final hasVoiceCapability(Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;)Z
    .registers 2
    .annotation runtime Lkotlin/jvm/JvmStatic;
    .end annotation

    const-string v0, "service"

    invoke-static {p0, v0}, Lkotlin/jvm/internal/Intrinsics;->checkNotNullParameter(Ljava/lang/Object;Ljava/lang/String;)V

    .line 73
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/OverheadLight;->getType(Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;)Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;

    move-result-object p0

    .line 74
    sget-object v0, Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;->SLSR_AUX:Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;

    if-eq p0, v0, :cond_14

    sget-object v0, Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;->SLSR_BLUETOOTH:Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;

    if-ne p0, v0, :cond_12

    goto :goto_14

    :cond_12
    const/4 p0, 0x0

    goto :goto_15

    :cond_14
    :goto_14
    const/4 p0, 0x1

    :goto_15
    return p0
.end method

.method public static final isActive(Landroid/content/Context;)Z
    .registers 2
    .annotation runtime Lkotlin/jvm/JvmStatic;
    .end annotation

    const-string v0, "context"

    invoke-static {p0, v0}, Lkotlin/jvm/internal/Intrinsics;->checkNotNullParameter(Ljava/lang/Object;Ljava/lang/String;)V

    .line 30
    check-cast p0, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;

    invoke-interface {p0}, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;->getInstance()Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;

    move-result-object p0

    .line 31
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/OverheadLight;->getType(Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;)Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;

    move-result-object p0

    sget-object v0, Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;->NONE:Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;

    if-eq p0, v0, :cond_15

    const/4 p0, 0x1

    goto :goto_16

    :cond_15
    const/4 p0, 0x0

    :goto_16
    return p0
.end method

.method public static final mute(Landroid/content/Context;)V
    .registers 3
    .annotation runtime Lkotlin/jvm/JvmStatic;
    .end annotation

    const-string v0, "context"

    invoke-static {p0, v0}, Lkotlin/jvm/internal/Intrinsics;->checkNotNullParameter(Ljava/lang/Object;Ljava/lang/String;)V

    .line 268
    check-cast p0, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;

    invoke-interface {p0}, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;->getInstance()Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;

    move-result-object p0

    .line 269
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/OverheadLight;->getType(Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;)Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;

    move-result-object v0

    sget-object v1, Lcom/thermasol/touchsteam2/util/OverheadLight$WhenMappings;->$EnumSwitchMapping$0:[I

    invoke-virtual {v0}, Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;->ordinal()I

    move-result v0

    aget v0, v1, v0

    const/4 v1, 0x1

    if-eq v0, v1, :cond_32

    const/4 v1, 0x2

    if-eq v0, v1, :cond_24

    const/4 v1, 0x3

    if-eq v0, v1, :cond_24

    const/4 v1, 0x4

    if-eq v0, v1, :cond_24

    goto :goto_35

    .line 277
    :cond_24
    :try_start_24
    invoke-virtual {p0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->getNative()Lcom/thermasol/thermatouchservice/IHardwareService;

    move-result-object p0

    const/4 v0, 0x0

    invoke-interface {p0, v0}, Lcom/thermasol/thermatouchservice/IHardwareService;->slsr_set_music_volume(I)V
    :try_end_2c
    .catch Ljava/lang/Exception; {:try_start_24 .. :try_end_2c} :catch_2d

    goto :goto_35

    :catch_2d
    move-exception p0

    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/Utils;->handleException(Ljava/lang/Exception;)V

    goto :goto_35

    .line 271
    :cond_32
    invoke-virtual {p0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->hvlsr_mute()V

    :goto_35
    return-void
.end method

.method private final persistLightState(Landroid/content/Context;Z)V
    .registers 5

    .line 628
    sget p0, Lcom/thermasol/touchsteam2/GV;->ActiveUser:I

    if-eqz p0, :cond_10

    .line 630
    invoke-static {p2}, Ljava/lang/Integer;->valueOf(I)Ljava/lang/Integer;

    move-result-object p0

    sget-object p2, Ljava/lang/Integer;->TYPE:Ljava/lang/Class;

    const/4 v0, 0x0

    const-string v1, "lightStateUser"

    invoke-static {p1, v1, p0, p2, v0}, Lcom/thermasol/touchsteam2/util/Utils;->putSteamBasedSetting(Landroid/content/Context;Ljava/lang/String;Ljava/lang/Object;Ljava/lang/Class;Z)V

    :cond_10
    return-void
.end method

.method public static final powerOffBluetooth(Landroid/content/Context;)V
    .registers 3
    .annotation runtime Lkotlin/jvm/JvmStatic;
    .end annotation

    const-string v0, "context"

    invoke-static {p0, v0}, Lkotlin/jvm/internal/Intrinsics;->checkNotNullParameter(Ljava/lang/Object;Ljava/lang/String;)V

    .line 525
    check-cast p0, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;

    invoke-interface {p0}, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;->getInstance()Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;

    move-result-object p0

    .line 526
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/OverheadLight;->getType(Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;)Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;

    move-result-object v0

    sget-object v1, Lcom/thermasol/touchsteam2/util/OverheadLight$WhenMappings;->$EnumSwitchMapping$0:[I

    invoke-virtual {v0}, Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;->ordinal()I

    move-result v0

    aget v0, v1, v0

    const/4 v1, 0x1

    if-eq v0, v1, :cond_28

    const/4 v1, 0x2

    if-eq v0, v1, :cond_24

    const/4 v1, 0x3

    if-eq v0, v1, :cond_24

    const/4 v1, 0x4

    if-eq v0, v1, :cond_24

    goto :goto_2b

    .line 533
    :cond_24
    invoke-virtual {p0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->slsr_bluetooth_power_off()V

    goto :goto_2b

    .line 528
    :cond_28
    invoke-virtual {p0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->hvlsr_bluetooth_power_off()V

    :goto_2b
    return-void
.end method

.method public static final powerOnBluetooth(Landroid/content/Context;)V
    .registers 3
    .annotation runtime Lkotlin/jvm/JvmStatic;
    .end annotation

    const-string v0, "context"

    invoke-static {p0, v0}, Lkotlin/jvm/internal/Intrinsics;->checkNotNullParameter(Ljava/lang/Object;Ljava/lang/String;)V

    .line 508
    check-cast p0, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;

    invoke-interface {p0}, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;->getInstance()Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;

    move-result-object p0

    .line 509
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/OverheadLight;->getType(Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;)Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;

    move-result-object v0

    sget-object v1, Lcom/thermasol/touchsteam2/util/OverheadLight$WhenMappings;->$EnumSwitchMapping$0:[I

    invoke-virtual {v0}, Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;->ordinal()I

    move-result v0

    aget v0, v1, v0

    const/4 v1, 0x1

    if-eq v0, v1, :cond_28

    const/4 v1, 0x2

    if-eq v0, v1, :cond_24

    const/4 v1, 0x3

    if-eq v0, v1, :cond_24

    const/4 v1, 0x4

    if-eq v0, v1, :cond_24

    goto :goto_2b

    .line 516
    :cond_24
    invoke-virtual {p0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->slsr_bluetooth_power_on()V

    goto :goto_2b

    .line 511
    :cond_28
    invoke-virtual {p0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->hvlsr_bluetooth_power_on()V

    :goto_2b
    return-void
.end method

.method public static final setBassVolume(Landroid/content/Context;I)V
    .registers 5
    .annotation runtime Lkotlin/jvm/JvmStatic;
    .end annotation

    const-string v0, "context"

    invoke-static {p0, v0}, Lkotlin/jvm/internal/Intrinsics;->checkNotNullParameter(Ljava/lang/Object;Ljava/lang/String;)V

    .line 371
    move-object v0, p0

    check-cast v0, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;

    invoke-interface {v0}, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;->getInstance()Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;

    move-result-object v0

    .line 372
    invoke-static {v0}, Lcom/thermasol/touchsteam2/util/OverheadLight;->getType(Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;)Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;

    move-result-object v1

    sget-object v2, Lcom/thermasol/touchsteam2/util/OverheadLight$WhenMappings;->$EnumSwitchMapping$0:[I

    invoke-virtual {v1}, Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;->ordinal()I

    move-result v1

    aget v1, v2, v1

    const/4 v2, 0x1

    if-eq v1, v2, :cond_29

    const/4 v2, 0x2

    if-eq v1, v2, :cond_25

    const/4 v2, 0x3

    if-eq v1, v2, :cond_25

    const/4 v2, 0x4

    if-eq v1, v2, :cond_25

    goto :goto_2c

    .line 379
    :cond_25
    invoke-virtual {v0, p1}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->slsr_music_bass_tone(I)V

    goto :goto_2c

    .line 374
    :cond_29
    invoke-virtual {v0, p1}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->hvlsr_bass_volume(I)V

    .line 385
    :goto_2c
    invoke-static {p0}, Landroidx/preference/PreferenceManager;->getDefaultSharedPreferences(Landroid/content/Context;)Landroid/content/SharedPreferences;

    move-result-object p0

    invoke-interface {p0}, Landroid/content/SharedPreferences;->edit()Landroid/content/SharedPreferences$Editor;

    move-result-object p0

    .line 386
    sget v0, Lcom/thermasol/touchsteam2/GV;->ActiveUser:I

    invoke-static {v0}, Ljava/lang/Integer;->valueOf(I)Ljava/lang/Integer;

    move-result-object v0

    const-string v1, "bassVolumeUser"

    invoke-static {v1, v0}, Lkotlin/jvm/internal/Intrinsics;->stringPlus(Ljava/lang/String;Ljava/lang/Object;)Ljava/lang/String;

    move-result-object v0

    invoke-interface {p0, v0, p1}, Landroid/content/SharedPreferences$Editor;->putInt(Ljava/lang/String;I)Landroid/content/SharedPreferences$Editor;

    .line 387
    invoke-interface {p0}, Landroid/content/SharedPreferences$Editor;->apply()V

    return-void
.end method

.method public static final setChromaState(Landroid/content/Context;I)V
    .registers 5
    .annotation runtime Lkotlin/jvm/JvmStatic;
    .end annotation

    const-string v0, "context"

    invoke-static {p0, v0}, Lkotlin/jvm/internal/Intrinsics;->checkNotNullParameter(Ljava/lang/Object;Ljava/lang/String;)V

    .line 110
    move-object v0, p0

    check-cast v0, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;

    invoke-interface {v0}, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;->getInstance()Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;

    move-result-object v0

    .line 111
    invoke-static {v0}, Lcom/thermasol/touchsteam2/util/OverheadLight;->getType(Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;)Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;

    move-result-object v1

    sget-object v2, Lcom/thermasol/touchsteam2/util/OverheadLight$WhenMappings;->$EnumSwitchMapping$0:[I

    invoke-virtual {v1}, Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;->ordinal()I

    move-result v1

    aget v1, v2, v1

    const/4 v2, 0x1

    if-eq v1, v2, :cond_29

    const/4 p0, 0x2

    if-eq v1, p0, :cond_25

    const/4 p0, 0x3

    if-eq v1, p0, :cond_25

    const/4 p0, 0x4

    if-eq v1, p0, :cond_25

    goto :goto_30

    .line 118
    :cond_25
    invoke-virtual {v0, p1}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->slsr_chroma_state(I)V

    goto :goto_30

    .line 113
    :cond_29
    invoke-static {p0, p1}, Lcom/thermasol/touchsteam2/util/OverheadLight;->translateStateToColorHex(Landroid/content/Context;I)I

    move-result p1

    invoke-static {v0, p0, p1}, Lcom/thermasol/touchsteam2/util/OverheadLight;->setHvlsrRgbAndIntensity(Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;Landroid/content/Context;I)V

    :goto_30
    return-void
.end method

.method public static final setHvlsrRgbAndIntensity(Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;Landroid/content/Context;I)V
    .registers 6
    .annotation runtime Lkotlin/jvm/JvmStatic;
    .end annotation

    const-string v0, "service"

    invoke-static {p0, v0}, Lkotlin/jvm/internal/Intrinsics;->checkNotNullParameter(Ljava/lang/Object;Ljava/lang/String;)V

    const-string v0, "context"

    invoke-static {p1, v0}, Lkotlin/jvm/internal/Intrinsics;->checkNotNullParameter(Ljava/lang/Object;Ljava/lang/String;)V

    const/16 v0, 0x50

    .line 220
    invoke-static {v0}, Ljava/lang/Integer;->valueOf(I)Ljava/lang/Integer;

    move-result-object v0

    sget-object v1, Ljava/lang/Integer;->TYPE:Ljava/lang/Class;

    const-string v2, "lightIntensityUser"

    invoke-static {p1, v2, v0, v1}, Lcom/thermasol/touchsteam2/util/Utils;->getSteamBasedSetting(Landroid/content/Context;Ljava/lang/String;Ljava/lang/Object;Ljava/lang/Class;)Ljava/lang/Object;

    move-result-object v0

    const-string v1, "null cannot be cast to non-null type kotlin.Int"

    invoke-static {v0, v1}, Ljava/util/Objects;->requireNonNull(Ljava/lang/Object;Ljava/lang/String;)Ljava/lang/Object;

    check-cast v0, Ljava/lang/Integer;

    invoke-virtual {v0}, Ljava/lang/Integer;->intValue()I

    move-result v0

    .line 222
    invoke-static {p1}, Landroidx/preference/PreferenceManager;->getDefaultSharedPreferences(Landroid/content/Context;)Landroid/content/SharedPreferences;

    move-result-object p1

    const/4 v1, 0x0

    const-string v2, "hydrovivePalette"

    .line 223
    invoke-interface {p1, v2, v1}, Landroid/content/SharedPreferences;->getBoolean(Ljava/lang/String;Z)Z

    move-result v1

    if-eqz v1, :cond_37

    shl-int/lit8 p1, p2, 0x8

    or-int/2addr p1, v0

    .line 225
    invoke-virtual {p0, p1}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->hvlsr_set_rbga(I)V

    goto :goto_4f

    :cond_37
    const/4 v1, 0x1

    const-string v2, "max_hvlsr_brightness_enabled"

    .line 227
    invoke-interface {p1, v2, v1}, Landroid/content/SharedPreferences;->getBoolean(Ljava/lang/String;Z)Z

    move-result p1

    if-eqz p1, :cond_43

    const/high16 p1, 0x3f800000    # 1.0f

    goto :goto_46

    :cond_43
    const p1, 0x3f19999a    # 0.6f

    :goto_46
    int-to-float v0, v0

    mul-float/2addr v0, p1

    float-to-int p1, v0

    shl-int/lit8 p2, p2, 0x8

    or-int/2addr p1, p2

    .line 230
    invoke-virtual {p0, p1}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->hvlsr_set_white_rbga(I)V

    :goto_4f
    return-void
.end method

.method public static final setIntensity(Landroid/content/Context;I)V
    .registers 7
    .annotation runtime Lkotlin/jvm/JvmStatic;
    .end annotation

    const-string v0, "context"

    invoke-static {p0, v0}, Lkotlin/jvm/internal/Intrinsics;->checkNotNullParameter(Ljava/lang/Object;Ljava/lang/String;)V

    .line 198
    move-object v0, p0

    check-cast v0, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;

    invoke-interface {v0}, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;->getInstance()Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;

    move-result-object v0

    .line 199
    invoke-static {p1}, Ljava/lang/Integer;->valueOf(I)Ljava/lang/Integer;

    move-result-object v1

    sget-object v2, Ljava/lang/Integer;->TYPE:Ljava/lang/Class;

    const-string v3, "lightIntensityUser"

    const/4 v4, 0x0

    invoke-static {p0, v3, v1, v2, v4}, Lcom/thermasol/touchsteam2/util/Utils;->putSteamBasedSetting(Landroid/content/Context;Ljava/lang/String;Ljava/lang/Object;Ljava/lang/Class;Z)V

    .line 200
    invoke-static {v0}, Lcom/thermasol/touchsteam2/util/OverheadLight;->getType(Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;)Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;

    move-result-object v1

    sget-object v2, Lcom/thermasol/touchsteam2/util/OverheadLight$WhenMappings;->$EnumSwitchMapping$0:[I

    invoke-virtual {v1}, Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;->ordinal()I

    move-result v1

    aget v1, v2, v1

    const/4 v2, 0x1

    if-eq v1, v2, :cond_35

    const/4 p0, 0x2

    if-eq v1, p0, :cond_31

    const/4 p0, 0x3

    if-eq v1, p0, :cond_31

    const/4 p0, 0x4

    if-eq v1, p0, :cond_31

    goto :goto_4e

    .line 210
    :cond_31
    invoke-virtual {v0, p1}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->slsr_set_light_intensity(I)V

    goto :goto_4e

    .line 203
    :cond_35
    invoke-static {p0}, Landroidx/preference/PreferenceManager;->getDefaultSharedPreferences(Landroid/content/Context;)Landroid/content/SharedPreferences;

    move-result-object p1

    .line 204
    sget v1, Lcom/thermasol/touchsteam2/GV;->ActiveUser:I

    invoke-static {v1}, Ljava/lang/Integer;->valueOf(I)Ljava/lang/Integer;

    move-result-object v1

    const-string v2, "rgbColorUser"

    invoke-static {v2, v1}, Lkotlin/jvm/internal/Intrinsics;->stringPlus(Ljava/lang/String;Ljava/lang/Object;)Ljava/lang/String;

    move-result-object v1

    const/high16 v2, -0x10000

    invoke-interface {p1, v1, v2}, Landroid/content/SharedPreferences;->getInt(Ljava/lang/String;I)I

    move-result p1

    .line 205
    invoke-static {v0, p0, p1}, Lcom/thermasol/touchsteam2/util/OverheadLight;->setHvlsrRgbAndIntensity(Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;Landroid/content/Context;I)V

    :goto_4e
    return-void
.end method

.method public static final setMasterVolume(Landroid/content/Context;I)V
    .registers 5

    sget-boolean v0, Lcom/thermasol/touchsteam2/util/OverheadLight;->sShutdownMuted:Z

    if-nez v0, :tt_hv_ok

    return-void

    :tt_hv_ok
    .annotation runtime Lkotlin/jvm/JvmStatic;
    .end annotation

    const-string v0, "context"

    invoke-static {p0, v0}, Lkotlin/jvm/internal/Intrinsics;->checkNotNullParameter(Ljava/lang/Object;Ljava/lang/String;)V

    .line 305
    move-object v0, p0

    check-cast v0, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;

    invoke-interface {v0}, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;->getInstance()Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;

    move-result-object v0

    .line 306
    invoke-static {v0}, Lcom/thermasol/touchsteam2/util/OverheadLight;->getType(Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;)Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;

    move-result-object v1

    sget-object v2, Lcom/thermasol/touchsteam2/util/OverheadLight$WhenMappings;->$EnumSwitchMapping$0:[I

    invoke-virtual {v1}, Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;->ordinal()I

    move-result v1

    aget v1, v2, v1

    const/4 v2, 0x1

    if-eq v1, v2, :cond_29

    const/4 v2, 0x2

    if-eq v1, v2, :cond_25

    const/4 v2, 0x3

    if-eq v1, v2, :cond_25

    const/4 v2, 0x4

    if-eq v1, v2, :cond_25

    goto :goto_2c

    .line 313
    :cond_25
    invoke-virtual {v0, p1}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->slsr_set_music_volume(I)V

    goto :goto_2c

    .line 308
    :cond_29
    invoke-virtual {v0, p1}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->hvlsr_master_volume(I)V

    .line 319
    :goto_2c
    invoke-static {p0}, Landroidx/preference/PreferenceManager;->getDefaultSharedPreferences(Landroid/content/Context;)Landroid/content/SharedPreferences;

    move-result-object p0

    invoke-interface {p0}, Landroid/content/SharedPreferences;->edit()Landroid/content/SharedPreferences$Editor;

    move-result-object p0

    .line 320
    sget v0, Lcom/thermasol/touchsteam2/GV;->ActiveUser:I

    invoke-static {v0}, Ljava/lang/Integer;->valueOf(I)Ljava/lang/Integer;

    move-result-object v0

    const-string v1, "musicVolumeUser"

    invoke-static {v1, v0}, Lkotlin/jvm/internal/Intrinsics;->stringPlus(Ljava/lang/String;Ljava/lang/Object;)Ljava/lang/String;

    move-result-object v0

    invoke-interface {p0, v0, p1}, Landroid/content/SharedPreferences$Editor;->putInt(Ljava/lang/String;I)Landroid/content/SharedPreferences$Editor;

    .line 321
    invoke-interface {p0}, Landroid/content/SharedPreferences$Editor;->apply()V

    return-void
.end method

.method public static final setMidVolume(Landroid/content/Context;I)V
    .registers 5
    .annotation runtime Lkotlin/jvm/JvmStatic;
    .end annotation

    const-string v0, "context"

    invoke-static {p0, v0}, Lkotlin/jvm/internal/Intrinsics;->checkNotNullParameter(Ljava/lang/Object;Ljava/lang/String;)V

    .line 349
    move-object v0, p0

    check-cast v0, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;

    invoke-interface {v0}, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;->getInstance()Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;

    move-result-object v0

    .line 350
    invoke-static {v0}, Lcom/thermasol/touchsteam2/util/OverheadLight;->getType(Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;)Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;

    move-result-object v1

    sget-object v2, Lcom/thermasol/touchsteam2/util/OverheadLight$WhenMappings;->$EnumSwitchMapping$0:[I

    invoke-virtual {v1}, Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;->ordinal()I

    move-result v1

    aget v1, v2, v1

    const/4 v2, 0x1

    if-eq v1, v2, :cond_29

    const/4 v2, 0x2

    if-eq v1, v2, :cond_25

    const/4 v2, 0x3

    if-eq v1, v2, :cond_25

    const/4 v2, 0x4

    if-eq v1, v2, :cond_25

    goto :goto_2c

    .line 357
    :cond_25
    invoke-virtual {v0, p1}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->slsr_music_mid_tone(I)V

    goto :goto_2c

    .line 352
    :cond_29
    invoke-virtual {v0, p1}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->hvlsr_mid_volume(I)V

    .line 363
    :goto_2c
    invoke-static {p0}, Landroidx/preference/PreferenceManager;->getDefaultSharedPreferences(Landroid/content/Context;)Landroid/content/SharedPreferences;

    move-result-object p0

    invoke-interface {p0}, Landroid/content/SharedPreferences;->edit()Landroid/content/SharedPreferences$Editor;

    move-result-object p0

    .line 364
    sget v0, Lcom/thermasol/touchsteam2/GV;->ActiveUser:I

    invoke-static {v0}, Ljava/lang/Integer;->valueOf(I)Ljava/lang/Integer;

    move-result-object v0

    const-string v1, "midVolumeUser"

    invoke-static {v1, v0}, Lkotlin/jvm/internal/Intrinsics;->stringPlus(Ljava/lang/String;Ljava/lang/Object;)Ljava/lang/String;

    move-result-object v0

    invoke-interface {p0, v0, p1}, Landroid/content/SharedPreferences$Editor;->putInt(Ljava/lang/String;I)Landroid/content/SharedPreferences$Editor;

    .line 365
    invoke-interface {p0}, Landroid/content/SharedPreferences$Editor;->apply()V

    return-void
.end method

.method public static final setMode(Landroid/content/Context;I)V
    .registers 8
    .annotation runtime Lkotlin/jvm/JvmStatic;
    .end annotation

    const-string v0, "context"

    invoke-static {p0, v0}, Lkotlin/jvm/internal/Intrinsics;->checkNotNullParameter(Ljava/lang/Object;Ljava/lang/String;)V

    .line 168
    move-object v0, p0

    check-cast v0, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;

    invoke-interface {v0}, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;->getInstance()Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;

    move-result-object v0

    .line 169
    invoke-static {v0}, Lcom/thermasol/touchsteam2/util/OverheadLight;->getType(Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;)Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;

    move-result-object v1

    sget-object v2, Lcom/thermasol/touchsteam2/util/OverheadLight$WhenMappings;->$EnumSwitchMapping$0:[I

    invoke-virtual {v1}, Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;->ordinal()I

    move-result v1

    aget v1, v2, v1

    const/4 v2, 0x0

    const/4 v3, 0x4

    const/4 v4, 0x2

    const/4 v5, 0x1

    if-eq v1, v5, :cond_2a

    if-eq v1, v4, :cond_26

    const/4 v4, 0x3

    if-eq v1, v4, :cond_26

    if-eq v1, v3, :cond_26

    goto :goto_4e

    .line 184
    :cond_26
    invoke-virtual {v0, p1}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->slsr_set_light_mode(I)V

    goto :goto_4e

    :cond_2a
    if-eq p1, v5, :cond_35

    if-eq p1, v4, :cond_31

    if-eq p1, v3, :cond_35

    goto :goto_4e

    .line 172
    :cond_31
    invoke-virtual {v0, v2}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->hvlsr_set_mood_light(I)V

    goto :goto_4e

    .line 175
    :cond_35
    invoke-static {p0}, Landroidx/preference/PreferenceManager;->getDefaultSharedPreferences(Landroid/content/Context;)Landroid/content/SharedPreferences;

    move-result-object v1

    .line 176
    sget v3, Lcom/thermasol/touchsteam2/GV;->ActiveUser:I

    invoke-static {v3}, Ljava/lang/Integer;->valueOf(I)Ljava/lang/Integer;

    move-result-object v3

    const-string v4, "rgbColorUser"

    invoke-static {v4, v3}, Lkotlin/jvm/internal/Intrinsics;->stringPlus(Ljava/lang/String;Ljava/lang/Object;)Ljava/lang/String;

    move-result-object v3

    const/high16 v4, -0x10000

    invoke-interface {v1, v3, v4}, Landroid/content/SharedPreferences;->getInt(Ljava/lang/String;I)I

    move-result v1

    .line 177
    invoke-static {v0, p0, v1}, Lcom/thermasol/touchsteam2/util/OverheadLight;->setHvlsrRgbAndIntensity(Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;Landroid/content/Context;I)V

    .line 190
    :goto_4e
    sget v0, Lcom/thermasol/touchsteam2/GV;->ActiveUser:I

    if-eqz v0, :cond_5d

    .line 191
    invoke-static {p1}, Ljava/lang/Integer;->valueOf(I)Ljava/lang/Integer;

    move-result-object p1

    sget-object v0, Ljava/lang/Integer;->TYPE:Ljava/lang/Class;

    const-string v1, "lightModeUser"

    invoke-static {p0, v1, p1, v0, v2}, Lcom/thermasol/touchsteam2/util/Utils;->putSteamBasedSetting(Landroid/content/Context;Ljava/lang/String;Ljava/lang/Object;Ljava/lang/Class;Z)V

    :cond_5d
    return-void
.end method

.method public static final setSource(Landroid/content/Context;I)V
    .registers 7
    .annotation runtime Lkotlin/jvm/JvmStatic;
    .end annotation

    const-string v0, "context"

    invoke-static {p0, v0}, Lkotlin/jvm/internal/Intrinsics;->checkNotNullParameter(Ljava/lang/Object;Ljava/lang/String;)V

    .line 237
    move-object v0, p0

    check-cast v0, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;

    invoke-interface {v0}, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;->getInstance()Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;

    move-result-object v0

    .line 238
    invoke-static {v0}, Lcom/thermasol/touchsteam2/util/OverheadLight;->getType(Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;)Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;

    move-result-object v1

    sget-object v2, Lcom/thermasol/touchsteam2/util/OverheadLight$WhenMappings;->$EnumSwitchMapping$0:[I

    invoke-virtual {v1}, Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;->ordinal()I

    move-result v1

    aget v1, v2, v1

    const/4 v2, 0x2

    const/4 v3, 0x1

    if-eq v1, v3, :cond_29

    if-eq v1, v2, :cond_25

    const/4 v4, 0x3

    if-eq v1, v4, :cond_25

    const/4 v4, 0x4

    if-eq v1, v4, :cond_25

    goto :goto_2c

    .line 245
    :cond_25
    invoke-virtual {v0, p1}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->slsr_set_source(I)V

    goto :goto_2c

    .line 240
    :cond_29
    invoke-virtual {v0, p1}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->hvlsr_set_source(I)V

    .line 253
    :goto_2c
    invoke-static {v0}, Lcom/thermasol/touchsteam2/util/OverheadLight;->hasBluetoothCapability(Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;)Z

    move-result v0

    if-eqz v0, :cond_3a

    if-eq p1, v3, :cond_39

    if-eq p1, v2, :cond_37

    goto :goto_3a

    :cond_37
    move p1, v3

    goto :goto_3a

    :cond_39
    move p1, v2

    .line 260
    :cond_3a
    :goto_3a
    invoke-static {p0}, Landroidx/preference/PreferenceManager;->getDefaultSharedPreferences(Landroid/content/Context;)Landroid/content/SharedPreferences;

    move-result-object p0

    invoke-interface {p0}, Landroid/content/SharedPreferences;->edit()Landroid/content/SharedPreferences$Editor;

    move-result-object p0

    .line 261
    sget v0, Lcom/thermasol/touchsteam2/GV;->ActiveUser:I

    invoke-static {v0}, Ljava/lang/Integer;->valueOf(I)Ljava/lang/Integer;

    move-result-object v0

    const-string v1, "musicSourceUser"

    invoke-static {v1, v0}, Lkotlin/jvm/internal/Intrinsics;->stringPlus(Ljava/lang/String;Ljava/lang/Object;)Ljava/lang/String;

    move-result-object v0

    invoke-interface {p0, v0, p1}, Landroid/content/SharedPreferences$Editor;->putInt(Ljava/lang/String;I)Landroid/content/SharedPreferences$Editor;

    .line 262
    invoke-interface {p0}, Landroid/content/SharedPreferences$Editor;->apply()V

    return-void
.end method

.method public static final setTrebleVolume(Landroid/content/Context;I)V
    .registers 5
    .annotation runtime Lkotlin/jvm/JvmStatic;
    .end annotation

    const-string v0, "context"

    invoke-static {p0, v0}, Lkotlin/jvm/internal/Intrinsics;->checkNotNullParameter(Ljava/lang/Object;Ljava/lang/String;)V

    .line 327
    move-object v0, p0

    check-cast v0, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;

    invoke-interface {v0}, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;->getInstance()Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;

    move-result-object v0

    .line 328
    invoke-static {v0}, Lcom/thermasol/touchsteam2/util/OverheadLight;->getType(Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;)Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;

    move-result-object v1

    sget-object v2, Lcom/thermasol/touchsteam2/util/OverheadLight$WhenMappings;->$EnumSwitchMapping$0:[I

    invoke-virtual {v1}, Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;->ordinal()I

    move-result v1

    aget v1, v2, v1

    const/4 v2, 0x1

    if-eq v1, v2, :cond_2e

    const/4 v2, 0x2

    if-eq v1, v2, :cond_25

    const/4 v2, 0x3

    if-eq v1, v2, :cond_25

    const/4 v2, 0x4

    if-eq v1, v2, :cond_25

    goto :goto_31

    .line 335
    :cond_25
    invoke-static {}, Lcom/thermasol/touchsteam2/util/OverheadLight;->getMaxTrebleVolume()I

    move-result v1

    sub-int/2addr v1, p1

    invoke-virtual {v0, v1}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->slsr_music_treble_tone(I)V

    goto :goto_31

    .line 330
    :cond_2e
    invoke-virtual {v0, p1}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->hvlsr_treble_volume(I)V

    .line 341
    :goto_31
    invoke-static {p0}, Landroidx/preference/PreferenceManager;->getDefaultSharedPreferences(Landroid/content/Context;)Landroid/content/SharedPreferences;

    move-result-object p0

    invoke-interface {p0}, Landroid/content/SharedPreferences;->edit()Landroid/content/SharedPreferences$Editor;

    move-result-object p0

    .line 342
    sget v0, Lcom/thermasol/touchsteam2/GV;->ActiveUser:I

    invoke-static {v0}, Ljava/lang/Integer;->valueOf(I)Ljava/lang/Integer;

    move-result-object v0

    const-string v1, "trebleVolumeUser"

    invoke-static {v1, v0}, Lkotlin/jvm/internal/Intrinsics;->stringPlus(Ljava/lang/String;Ljava/lang/Object;)Ljava/lang/String;

    move-result-object v0

    invoke-interface {p0, v0, p1}, Landroid/content/SharedPreferences$Editor;->putInt(Ljava/lang/String;I)Landroid/content/SharedPreferences$Editor;

    .line 343
    invoke-interface {p0}, Landroid/content/SharedPreferences$Editor;->apply()V

    return-void
.end method

.method public static final translateStateToColorHex(Landroid/content/Context;I)I
    .registers 3
    .annotation runtime Lkotlin/jvm/JvmStatic;
    .end annotation

    const-string v0, "context"

    invoke-static {p0, v0}, Lkotlin/jvm/internal/Intrinsics;->checkNotNullParameter(Ljava/lang/Object;Ljava/lang/String;)V

    packed-switch p1, :pswitch_data_32

    const/high16 p0, -0x1000000

    goto :goto_30

    :pswitch_b
    const p1, 0x7f0600e0

    .line 100
    invoke-static {p0, p1}, Landroidx/core/content/ContextCompat;->getColor(Landroid/content/Context;I)I

    move-result p0

    goto :goto_30

    :pswitch_13
    const p1, 0x7f06006c

    .line 97
    invoke-static {p0, p1}, Landroidx/core/content/ContextCompat;->getColor(Landroid/content/Context;I)I

    move-result p0

    goto :goto_30

    :pswitch_1b
    const p0, -0xffff01

    goto :goto_30

    :pswitch_1f
    const p0, -0xff0100

    goto :goto_30

    :pswitch_23
    const/16 p0, -0x100

    goto :goto_30

    :pswitch_26
    const p1, 0x7f0600dd

    .line 85
    invoke-static {p0, p1}, Landroidx/core/content/ContextCompat;->getColor(Landroid/content/Context;I)I

    move-result p0

    goto :goto_30

    :pswitch_2e
    const/high16 p0, -0x10000

    :goto_30
    return p0

    nop

    :pswitch_data_32
    .packed-switch 0x0
        :pswitch_2e
        :pswitch_26
        :pswitch_23
        :pswitch_1f
        :pswitch_1b
        :pswitch_13
        :pswitch_b
    .end packed-switch
.end method

.method public static final turnOff(Landroid/content/Context;)V
    .registers 5
    .annotation runtime Lkotlin/jvm/JvmStatic;
    .end annotation

    const-string v0, "context"

    invoke-static {p0, v0}, Lkotlin/jvm/internal/Intrinsics;->checkNotNullParameter(Ljava/lang/Object;Ljava/lang/String;)V

    .line 148
    move-object v0, p0

    check-cast v0, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;

    invoke-interface {v0}, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;->getInstance()Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;

    move-result-object v0

    .line 149
    sget-object v1, Lcom/thermasol/touchsteam2/util/OverheadLight;->INSTANCE:Lcom/thermasol/touchsteam2/util/OverheadLight;

    invoke-static {v0}, Lcom/thermasol/touchsteam2/util/OverheadLight;->getType(Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;)Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;

    move-result-object v2

    sget-object v3, Lcom/thermasol/touchsteam2/util/OverheadLight$WhenMappings;->$EnumSwitchMapping$0:[I

    invoke-virtual {v2}, Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;->ordinal()I

    move-result v2

    aget v2, v3, v2

    const/4 v3, 0x1

    if-eq v2, v3, :cond_2b

    const/4 v3, 0x2

    if-eq v2, v3, :cond_27

    const/4 v3, 0x3

    if-eq v2, v3, :cond_27

    const/4 v3, 0x4

    if-eq v2, v3, :cond_27

    goto :goto_2e

    .line 156
    :cond_27
    invoke-virtual {v0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->slsr_turn_off_light()V

    goto :goto_2e

    .line 151
    :cond_2b
    invoke-virtual {v0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->hvlsr_light_off()V

    :goto_2e
    const/4 v0, 0x0

    .line 162
    invoke-direct {v1, p0, v0}, Lcom/thermasol/touchsteam2/util/OverheadLight;->persistLightState(Landroid/content/Context;Z)V

    return-void
.end method

.method public static final turnOn(Landroid/content/Context;)V
    .registers 6
    .annotation runtime Lkotlin/jvm/JvmStatic;
    .end annotation

    const-string v0, "context"

    invoke-static {p0, v0}, Lkotlin/jvm/internal/Intrinsics;->checkNotNullParameter(Ljava/lang/Object;Ljava/lang/String;)V

    .line 128
    move-object v0, p0

    check-cast v0, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;

    invoke-interface {v0}, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;->getInstance()Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;

    move-result-object v0

    .line 129
    sget-object v1, Lcom/thermasol/touchsteam2/util/OverheadLight;->INSTANCE:Lcom/thermasol/touchsteam2/util/OverheadLight;

    invoke-static {v0}, Lcom/thermasol/touchsteam2/util/OverheadLight;->getType(Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;)Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;

    move-result-object v2

    sget-object v3, Lcom/thermasol/touchsteam2/util/OverheadLight$WhenMappings;->$EnumSwitchMapping$0:[I

    invoke-virtual {v2}, Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;->ordinal()I

    move-result v2

    aget v2, v3, v2

    const/4 v3, 0x1

    if-eq v2, v3, :cond_2b

    const/4 v4, 0x2

    if-eq v2, v4, :cond_27

    const/4 v4, 0x3

    if-eq v2, v4, :cond_27

    const/4 v4, 0x4

    if-eq v2, v4, :cond_27

    goto :goto_2e

    .line 136
    :cond_27
    invoke-virtual {v0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->slsr_turn_on_light()V

    goto :goto_2e

    .line 131
    :cond_2b
    invoke-virtual {v0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->hvlsr_light_on()V

    .line 142
    :goto_2e
    invoke-direct {v1, p0, v3}, Lcom/thermasol/touchsteam2/util/OverheadLight;->persistLightState(Landroid/content/Context;Z)V

    return-void
.end method

.method public static final unmute(Landroid/content/Context;)V
    .registers 4

    sget-boolean v0, Lcom/thermasol/touchsteam2/util/OverheadLight;->sShutdownMuted:Z

    if-nez v0, :tt_hv_ok

    return-void

    :tt_hv_ok
    .annotation runtime Lkotlin/jvm/JvmStatic;
    .end annotation

    const-string v0, "context"

    invoke-static {p0, v0}, Lkotlin/jvm/internal/Intrinsics;->checkNotNullParameter(Ljava/lang/Object;Ljava/lang/String;)V

    .line 287
    check-cast p0, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;

    invoke-interface {p0}, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;->getInstance()Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;

    move-result-object p0

    .line 288
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/OverheadLight;->getType(Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;)Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;

    move-result-object v0

    sget-object v1, Lcom/thermasol/touchsteam2/util/OverheadLight$WhenMappings;->$EnumSwitchMapping$0:[I

    invoke-virtual {v0}, Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;->ordinal()I

    move-result v0

    aget v0, v1, v0

    const/4 v1, 0x1

    if-eq v0, v1, :cond_28

    const/4 v2, 0x2

    if-eq v0, v2, :cond_24

    const/4 v2, 0x3

    if-eq v0, v2, :cond_24

    const/4 v2, 0x4

    if-eq v0, v2, :cond_24

    goto :goto_2b

    .line 295
    :cond_24
    invoke-virtual {p0, v1}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->slsr_music_on_off(Z)V

    goto :goto_2b

    .line 290
    :cond_28
    invoke-virtual {p0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->hvlsr_unmute()V

    :goto_2b
    return-void
.end method
