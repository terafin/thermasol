.class public Lcom/thermasol/touchsteam2/util/Utils;
.super Ljava/lang/Object;
.source "Utils.java"


# annotations
.annotation system Ldalvik/annotation/MemberClasses;
    value = {
        Lcom/thermasol/touchsteam2/util/Utils$ExecutionResult;
    }
.end annotation


# static fields
.field private static final REQUEST_TRUST_EXTERNAL_SOURCE:I = 0x1

.field private static mDetails:Ljava/util/List;
    .annotation system Ldalvik/annotation/Signature;
        value = {
            "Ljava/util/List<",
            "Lcom/thermasol/utils/AppDetail;",
            ">;"
        }
    .end annotation
.end field


# direct methods
.method static constructor <clinit>()V
    .registers 1

    .line 1023
    new-instance v0, Ljava/util/ArrayList;

    invoke-direct {v0}, Ljava/util/ArrayList;-><init>()V

    sput-object v0, Lcom/thermasol/touchsteam2/util/Utils;->mDetails:Ljava/util/List;

    return-void
.end method

.method public constructor <init>()V
    .registers 1

    .line 52
    invoke-direct {p0}, Ljava/lang/Object;-><init>()V

    return-void
.end method

.method public static AndroidBluetoothSupported()Z
    .registers 1

    const/4 v0, 0x0

    return v0
.end method

.method public static BoundsCheck(III)I
    .registers 3
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0,
            0x0,
            0x0
        }
        names = {
            "ivalue",
            "minvalue",
            "maxvalue"
        }
    .end annotation

    if-le p0, p2, :cond_3

    return p2

    .line 112
    :cond_3
    invoke-static {p0, p1}, Ljava/lang/Math;->max(II)I

    move-result p0

    return p0
.end method

.method public static GetBluetoothDeviceName(Landroid/content/Context;)Ljava/lang/String;
    .registers 3
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0
        }
        names = {
            "context"
        }
    .end annotation

    .line 205
    move-object v0, p0

    check-cast v0, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;

    invoke-interface {v0}, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;->getInstance()Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;

    move-result-object v0

    .line 206
    invoke-static {}, Lcom/thermasol/touchsteam2/util/Utils;->AndroidBluetoothSupported()Z

    move-result v1

    if-eqz v1, :cond_1b

    .line 208
    :try_start_d
    invoke-virtual {v0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->getNative()Lcom/thermasol/thermatouchservice/IHardwareService;

    move-result-object p0

    invoke-interface {p0}, Lcom/thermasol/thermatouchservice/IHardwareService;->getConnectedDeviceInfo()Ljava/lang/String;

    move-result-object p0
    :try_end_15
    .catch Ljava/lang/Exception; {:try_start_d .. :try_end_15} :catch_16

    goto :goto_42

    :catch_16
    move-exception p0

    .line 209
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/Utils;->handleException(Ljava/lang/Exception;)V

    goto :goto_40

    .line 211
    :cond_1b
    invoke-virtual {v0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->slsr_request_sls_stats()V

    .line 212
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/OverheadLight;->bluetoothIsPresent(Landroid/content/Context;)Z

    move-result v0

    if-eqz v0, :cond_40

    .line 213
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/OverheadLight;->getBluetoothState(Landroid/content/Context;)I

    move-result v0

    const/4 v1, 0x1

    if-eq v0, v1, :cond_34

    const/4 v1, 0x2

    if-eq v0, v1, :cond_2f

    goto :goto_40

    .line 216
    :cond_2f
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/OverheadLight;->bluetoothGetDeviceName(Landroid/content/Context;)Ljava/lang/String;

    move-result-object p0

    goto :goto_42

    .line 219
    :cond_34
    invoke-virtual {p0}, Landroid/content/Context;->getResources()Landroid/content/res/Resources;

    move-result-object p0

    const v0, 0x7f1100d9

    invoke-virtual {p0, v0}, Landroid/content/res/Resources;->getString(I)Ljava/lang/String;

    move-result-object p0

    goto :goto_42

    :cond_40
    :goto_40
    const-string p0, ""

    :goto_42
    return-object p0
.end method

.method public static GetBluetoothTimestamp(Landroid/content/Context;)J
    .registers 3
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0
        }
        names = {
            "context"
        }
    .end annotation

    .line 233
    move-object v0, p0

    check-cast v0, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;

    invoke-interface {v0}, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;->getInstance()Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;

    move-result-object v0

    .line 234
    invoke-static {}, Lcom/thermasol/touchsteam2/util/Utils;->AndroidBluetoothSupported()Z

    move-result v1

    if-eqz v1, :cond_1b

    .line 236
    :try_start_d
    invoke-virtual {v0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->getNative()Lcom/thermasol/thermatouchservice/IHardwareService;

    move-result-object p0

    invoke-interface {p0}, Lcom/thermasol/thermatouchservice/IHardwareService;->getPacketTimestamp()J

    move-result-wide v0
    :try_end_15
    .catch Ljava/lang/Exception; {:try_start_d .. :try_end_15} :catch_16

    goto :goto_29

    :catch_16
    move-exception p0

    .line 237
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/Utils;->handleException(Ljava/lang/Exception;)V

    goto :goto_27

    .line 239
    :cond_1b
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/OverheadLight;->getBluetoothState(Landroid/content/Context;)I

    move-result p0

    const/4 v0, 0x2

    if-ne p0, v0, :cond_27

    .line 240
    invoke-static {}, Ljava/lang/System;->currentTimeMillis()J

    move-result-wide v0

    goto :goto_29

    :cond_27
    :goto_27
    const-wide/16 v0, 0x0

    :goto_29
    return-wide v0
.end method

.method public static InitializeThermaCan(Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;)V
    .registers 2
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0
        }
        names = {
            "service"
        }
    .end annotation

    .line 466
    invoke-virtual {p0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->thermacan_close()V

    const/4 v0, 0x0

    .line 468
    invoke-virtual {p0, v0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->psb_set_error(I)V

    const/16 v0, 0x5a

    .line 469
    invoke-virtual {p0, v0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->psb_set_temperature_setpoint(I)V

    const/16 v0, 0x4b0

    .line 470
    invoke-virtual {p0, v0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->psb_set_timer_setpoint(I)V

    .line 472
    invoke-virtual {p0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->thermacan_open()V

    .line 473
    invoke-virtual {p0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->psb_get_faststart_mode()I

    return-void
.end method

.method public static IsLightTypeHv(Landroid/content/Context;)Z
    .registers 2
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0
        }
        names = {
            "context"
        }
    .end annotation

    .line 198
    check-cast p0, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;

    invoke-interface {p0}, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;->getInstance()Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;

    move-result-object p0

    .line 199
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/OverheadLight;->getType(Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;)Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;

    move-result-object p0

    sget-object v0, Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;->HVLSR:Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;

    if-ne p0, v0, :cond_10

    const/4 p0, 0x1

    goto :goto_11

    :cond_10
    const/4 p0, 0x0

    :goto_11
    return p0
.end method

.method public static IsSevenInch(Landroid/content/Context;)Z
    .registers 2
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0
        }
        names = {
            "context"
        }
    .end annotation

    .line 189
    invoke-virtual {p0}, Landroid/content/Context;->getResources()Landroid/content/res/Resources;

    move-result-object p0

    invoke-virtual {p0}, Landroid/content/res/Resources;->getDisplayMetrics()Landroid/util/DisplayMetrics;

    move-result-object p0

    iget p0, p0, Landroid/util/DisplayMetrics;->widthPixels:I

    const/16 v0, 0x3e8

    if-gt p0, v0, :cond_10

    const/4 p0, 0x1

    goto :goto_11

    :cond_10
    const/4 p0, 0x0

    :goto_11
    return p0
.end method

.method public static KillBluetooth(Landroid/content/Context;)V
    .registers 3
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0
        }
        names = {
            "context"
        }
    .end annotation

    .line 357
    move-object v0, p0

    check-cast v0, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;

    invoke-interface {v0}, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;->getInstance()Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;

    move-result-object v0

    .line 359
    :try_start_7
    invoke-static {}, Lcom/thermasol/touchsteam2/util/Utils;->AndroidBluetoothSupported()Z

    move-result v1

    if-eqz v1, :cond_15

    .line 360
    invoke-virtual {v0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->getNative()Lcom/thermasol/thermatouchservice/IHardwareService;

    move-result-object p0

    invoke-interface {p0}, Lcom/thermasol/thermatouchservice/IHardwareService;->killBluetooth()V

    goto :goto_27

    .line 362
    :cond_15
    invoke-static {v0}, Lcom/thermasol/touchsteam2/util/OverheadLight;->hasBluetoothCapability(Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;)Z

    move-result v0

    if-eqz v0, :cond_27

    .line 365
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/OverheadLight;->powerOffBluetooth(Landroid/content/Context;)V

    const/4 v0, 0x1

    .line 366
    invoke-static {p0, v0}, Lcom/thermasol/touchsteam2/util/Utils;->toggleMusicAndSource(Landroid/content/Context;I)V
    :try_end_22
    .catch Ljava/lang/Exception; {:try_start_7 .. :try_end_22} :catch_23

    goto :goto_27

    :catch_23
    move-exception p0

    .line 369
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/Utils;->handleException(Ljava/lang/Exception;)V

    :cond_27
    :goto_27
    return-void
.end method

.method public static PauseBluetooth(Landroid/content/Context;)V
    .registers 3
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0
        }
        names = {
            "context"
        }
    .end annotation

    const/16 v0, 0x46

    const/4 v1, 0x0

    .line 334
    invoke-static {p0, v0, v1}, Lcom/thermasol/touchsteam2/util/Utils;->SendBluetoothAvrcpCommand(Landroid/content/Context;II)Z

    .line 335
    invoke-static {}, Lcom/thermasol/utils/Utility;->waitForHardwareReaction()V

    const/4 v1, 0x1

    .line 336
    invoke-static {p0, v0, v1}, Lcom/thermasol/touchsteam2/util/Utils;->SendBluetoothAvrcpCommand(Landroid/content/Context;II)Z

    return-void
.end method

.method public static PersistBluetooth(Landroid/content/Context;Z)V
    .registers 3
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0,
            0x0
        }
        names = {
            "context",
            "state"
        }
    .end annotation

    .line 351
    invoke-static {p0}, Landroidx/preference/PreferenceManager;->getDefaultSharedPreferences(Landroid/content/Context;)Landroid/content/SharedPreferences;

    move-result-object p0

    .line 352
    invoke-interface {p0}, Landroid/content/SharedPreferences;->edit()Landroid/content/SharedPreferences$Editor;

    move-result-object p0

    const-string v0, "bluetooth_state"

    invoke-interface {p0, v0, p1}, Landroid/content/SharedPreferences$Editor;->putBoolean(Ljava/lang/String;Z)Landroid/content/SharedPreferences$Editor;

    move-result-object p0

    invoke-interface {p0}, Landroid/content/SharedPreferences$Editor;->apply()V

    return-void
.end method

.method public static PersistPauseAndKillBluetooth(Landroid/content/Context;)V
    .registers 2
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0
        }
        names = {
            "context"
        }
    .end annotation

    const/4 v0, 0x0

    .line 341
    invoke-static {p0, v0}, Lcom/thermasol/touchsteam2/util/Utils;->PersistBluetooth(Landroid/content/Context;Z)V

    .line 345
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/Utils;->PauseBluetooth(Landroid/content/Context;)V

    .line 346
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/Utils;->KillBluetooth(Landroid/content/Context;)V

    return-void
.end method

.method public static RemoveBluetoothDeviceBonds(Landroid/content/Context;)V
    .registers 2
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0
        }
        names = {
            "context"
        }
    .end annotation

    .line 291
    check-cast p0, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;

    invoke-interface {p0}, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;->getInstance()Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;

    move-result-object p0

    .line 292
    invoke-static {}, Lcom/thermasol/touchsteam2/util/Utils;->AndroidBluetoothSupported()Z

    move-result v0

    if-eqz v0, :cond_18

    .line 294
    :try_start_c
    invoke-virtual {p0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->getNative()Lcom/thermasol/thermatouchservice/IHardwareService;

    move-result-object p0

    invoke-interface {p0}, Lcom/thermasol/thermatouchservice/IHardwareService;->removeBluetoothDeviceBonds()V
    :try_end_13
    .catch Ljava/lang/Exception; {:try_start_c .. :try_end_13} :catch_14

    goto :goto_18

    :catch_14
    move-exception p0

    .line 295
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/Utils;->handleException(Ljava/lang/Exception;)V

    :cond_18
    :goto_18
    return-void
.end method

.method public static SendBluetoothAvrcpCommand(Landroid/content/Context;II)Z
    .registers 5
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0,
            0x0,
            0x0
        }
        names = {
            "context",
            "command",
            "action"
        }
    .end annotation

    .line 305
    :try_start_0
    invoke-static {}, Lcom/thermasol/touchsteam2/util/Utils;->AndroidBluetoothSupported()Z

    move-result v0

    const/4 v1, 0x1

    if-eqz v0, :cond_16

    .line 306
    check-cast p0, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;

    invoke-interface {p0}, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;->getInstance()Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;

    move-result-object p0

    .line 307
    invoke-virtual {p0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->getNative()Lcom/thermasol/thermatouchservice/IHardwareService;

    move-result-object p0

    invoke-interface {p0, p1, p2}, Lcom/thermasol/thermatouchservice/IHardwareService;->sendAvrcpCommand(II)Z

    move-result v1

    goto :goto_3e

    :cond_16
    if-ne p2, v1, :cond_3e

    const/16 p2, 0x44

    if-eq p1, p2, :cond_35

    const/16 p2, 0x46

    if-eq p1, p2, :cond_31

    const/16 p2, 0x4b

    if-eq p1, p2, :cond_2d

    const/16 p2, 0x4c

    if-eq p1, p2, :cond_29

    goto :goto_3e

    .line 321
    :cond_29
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/OverheadLight;->bluetoothSkipBack(Landroid/content/Context;)V

    goto :goto_3e

    .line 312
    :cond_2d
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/OverheadLight;->bluetoothSkipForward(Landroid/content/Context;)V

    goto :goto_3e

    .line 315
    :cond_31
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/OverheadLight;->bluetoothPause(Landroid/content/Context;)V

    goto :goto_3e

    .line 318
    :cond_35
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/OverheadLight;->bluetoothPlay(Landroid/content/Context;)V
    :try_end_38
    .catch Ljava/lang/Exception; {:try_start_0 .. :try_end_38} :catch_39

    goto :goto_3e

    :catch_39
    move-exception p0

    .line 327
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/Utils;->handleException(Ljava/lang/Exception;)V

    const/4 v1, 0x0

    :cond_3e
    :goto_3e
    return v1
.end method

.method public static ShutdownAll(Landroid/content/Context;)V
    .registers 3

    # HydroVive: from here until loadUserSettings() runs again, no unmute and
    # no B6 volume frame may leave the panel -- the ceiling unit unmutes on
    # both, and shutdown is supposed to end with the speaker quiet.
    const/4 v0, 0x1

    sput-boolean v0, Lcom/thermasol/touchsteam2/util/OverheadLight;->sShutdownMuted:Z

    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0
        }
        names = {
            "context"
        }
    .end annotation

    .line 478
    move-object v0, p0

    check-cast v0, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;

    invoke-interface {v0}, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;->getInstance()Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;

    move-result-object v0

    .line 479
    invoke-virtual {v0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->slsr_voice_mute()V

    .line 480
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/OverheadLight;->mute(Landroid/content/Context;)V

    .line 481
    invoke-virtual {v0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->esv_turn_off()V

    .line 482
    invoke-virtual {v0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->esv_clear_flow_counter()V

    .line 483
    invoke-virtual {v0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->psb_turn_off_power_flush()V

    .line 487
    :try_start_16
    invoke-virtual {v0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->getNative()Lcom/thermasol/thermatouchservice/IHardwareService;

    move-result-object v1

    invoke-interface {v1}, Lcom/thermasol/thermatouchservice/IHardwareService;->slsr_turn_off_light()V

    .line 488
    invoke-virtual {v0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->getNative()Lcom/thermasol/thermatouchservice/IHardwareService;

    move-result-object v1

    invoke-interface {v1}, Lcom/thermasol/thermatouchservice/IHardwareService;->hvlsr_light_off()V

    .line 491
    invoke-virtual {v0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->getNative()Lcom/thermasol/thermatouchservice/IHardwareService;

    move-result-object v1

    invoke-interface {v1}, Lcom/thermasol/thermatouchservice/IHardwareService;->hvlsr_bluetooth_disconnect()V
    :try_end_2b
    .catch Ljava/lang/Exception; {:try_start_16 .. :try_end_2b} :catch_2c

    goto :goto_30

    :catch_2c
    move-exception v1

    .line 492
    invoke-static {v1}, Lcom/thermasol/touchsteam2/util/Utils;->handleException(Ljava/lang/Exception;)V

    .line 494
    :goto_30
    invoke-static {}, Lcom/thermasol/utils/Utility;->waitForHardwareReaction()V

    .line 496
    invoke-virtual {v0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->psb_user_logout()V

    .line 497
    invoke-virtual {v0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->slsr_voice_mute()V

    .line 498
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/OverheadLight;->mute(Landroid/content/Context;)V

    .line 499
    invoke-virtual {v0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->slsr_request_sls_standby()V

    .line 500
    invoke-virtual {v0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->psb_turn_off_steam()V

    .line 501
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/Utils;->PersistPauseAndKillBluetooth(Landroid/content/Context;)V

    const/4 v0, 0x0

    .line 503
    invoke-static {p0, v0}, Lcom/thermasol/touchsteam2/util/Utils;->ToggleBluetooth(Landroid/content/Context;Z)V

    return-void
    # Last word: everything above may have re-selected source or volume,
    # and any of those would have unmuted.
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/OverheadLight;->mute(Landroid/content/Context;)V

.end method

.method public static StartBluetooth(Landroid/content/Context;)V
    .registers 5
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0
        }
        names = {
            "context"
        }
    .end annotation

    const/4 v0, 0x1

    .line 252
    invoke-static {v0}, Ljava/lang/Integer;->valueOf(I)Ljava/lang/Integer;

    move-result-object v1

    const-string v2, "bluetooth_session"

    const-string v3, "start_bluetooth"

    invoke-static {p0, v2, v3, v1}, Lcom/thermasol/touchsteam2/util/FirebaseAnalyticEvents;->logEvent(Landroid/content/Context;Ljava/lang/String;Ljava/lang/String;Ljava/lang/Number;)V

    .line 254
    invoke-static {p0}, Landroidx/preference/PreferenceManager;->getDefaultSharedPreferences(Landroid/content/Context;)Landroid/content/SharedPreferences;

    move-result-object v1

    .line 255
    invoke-interface {v1}, Landroid/content/SharedPreferences;->edit()Landroid/content/SharedPreferences$Editor;

    move-result-object v1

    const-string v2, "bluetooth_state"

    invoke-interface {v1, v2, v0}, Landroid/content/SharedPreferences$Editor;->putBoolean(Ljava/lang/String;Z)Landroid/content/SharedPreferences$Editor;

    move-result-object v1

    invoke-interface {v1}, Landroid/content/SharedPreferences$Editor;->apply()V

    .line 258
    move-object v1, p0

    check-cast v1, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;

    invoke-interface {v1}, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;->getInstance()Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;

    move-result-object v1

    .line 259
    invoke-static {}, Lcom/thermasol/touchsteam2/util/Utils;->AndroidBluetoothSupported()Z

    move-result v2

    if-eqz v2, :cond_37

    .line 261
    :try_start_2a
    invoke-virtual {v1}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->getNative()Lcom/thermasol/thermatouchservice/IHardwareService;

    move-result-object v1

    invoke-interface {v1}, Lcom/thermasol/thermatouchservice/IHardwareService;->startBluetooth()V
    :try_end_31
    .catch Ljava/lang/Exception; {:try_start_2a .. :try_end_31} :catch_32

    goto :goto_38

    :catch_32
    move-exception v1

    .line 262
    invoke-static {v1}, Lcom/thermasol/touchsteam2/util/Utils;->handleException(Ljava/lang/Exception;)V

    goto :goto_38

    :cond_37
    const/4 v0, 0x2

    .line 267
    :goto_38
    invoke-static {p0, v0}, Lcom/thermasol/touchsteam2/util/Utils;->toggleMusicAndSource(Landroid/content/Context;I)V

    return-void
.end method

.method public static ToggleBluetooth(Landroid/content/Context;Z)V
    .registers 4
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0,
            0x0
        }
        names = {
            "context",
            "enable"
        }
    .end annotation

    .line 272
    move-object v0, p0

    check-cast v0, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;

    invoke-interface {v0}, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;->getInstance()Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;

    move-result-object v0

    .line 273
    invoke-static {}, Lcom/thermasol/touchsteam2/util/Utils;->AndroidBluetoothSupported()Z

    move-result v1

    if-eqz v1, :cond_1a

    .line 278
    :try_start_d
    invoke-virtual {v0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->getNative()Lcom/thermasol/thermatouchservice/IHardwareService;

    move-result-object p0

    invoke-interface {p0, p1}, Lcom/thermasol/thermatouchservice/IHardwareService;->toggleBluetooth(Z)V
    :try_end_14
    .catch Ljava/lang/Exception; {:try_start_d .. :try_end_14} :catch_15

    goto :goto_23

    :catch_15
    move-exception p0

    .line 279
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/Utils;->handleException(Ljava/lang/Exception;)V

    goto :goto_23

    :cond_1a
    if-eqz p1, :cond_20

    .line 282
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/OverheadLight;->powerOnBluetooth(Landroid/content/Context;)V

    goto :goto_23

    .line 284
    :cond_20
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/OverheadLight;->powerOffBluetooth(Landroid/content/Context;)V

    :goto_23
    return-void
.end method

.method public static TurnOffSteam(Landroid/content/Context;)V
    .registers 4
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0
        }
        names = {
            "context"
        }
    .end annotation

    .line 386
    move-object v0, p0

    check-cast v0, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;

    invoke-interface {v0}, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;->getInstance()Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;

    move-result-object v0

    .line 388
    invoke-virtual {v0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->psb_get_remaining_steam_time()I

    move-result v1

    const/4 v2, 0x0

    .line 389
    invoke-static {v0, v2}, Lcom/thermasol/touchsteam2/util/Utils;->toggleSteam(Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;Z)V

    .line 391
    invoke-virtual {v0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->psb_turn_off_steam()V

    .line 393
    sget v2, Lcom/thermasol/touchsteam2/GV;->ActiveUser:I

    invoke-virtual {v0, v2}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->psb_set_load_user(I)V

    if-lez v1, :cond_1d

    .line 395
    invoke-virtual {v0, v1}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->psb_set_timer_setpoint(I)V

    goto :goto_24

    .line 397
    :cond_1d
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/Utils;->getRecoveryTimerSetpointForActiveUser(Landroid/content/Context;)I

    move-result v1

    .line 398
    invoke-virtual {v0, v1}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->psb_set_timer_setpoint(I)V

    .line 401
    :goto_24
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/Utils;->resetLightSettings(Landroid/content/Context;)V

    return-void
.end method

.method public static TurnOnSteam(Landroid/content/Context;)V
    .registers 5
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0
        }
        names = {
            "context"
        }
    .end annotation

    .line 377
    move-object v0, p0

    check-cast v0, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;

    invoke-interface {v0}, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;->getInstance()Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;

    move-result-object v0

    const/4 v1, 0x1

    .line 378
    invoke-static {v0, v1}, Lcom/thermasol/touchsteam2/util/Utils;->toggleSteam(Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;Z)V

    .line 379
    invoke-virtual {v0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->psb_get_psb_temperature_setpoint()I

    move-result v1

    invoke-static {v1}, Ljava/lang/Integer;->valueOf(I)Ljava/lang/Integer;

    move-result-object v1

    const-string v2, "steam_session"

    const-string v3, "initial_temperature_set_point"

    invoke-static {p0, v2, v3, v1}, Lcom/thermasol/touchsteam2/util/FirebaseAnalyticEvents;->logEvent(Landroid/content/Context;Ljava/lang/String;Ljava/lang/String;Ljava/lang/Number;)V

    .line 380
    invoke-virtual {v0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->psb_get_remaining_steam_time()I

    move-result v0

    invoke-static {v0}, Ljava/lang/Integer;->valueOf(I)Ljava/lang/Integer;

    move-result-object v0

    const-string v1, "initial_timer_set_point"

    invoke-static {p0, v2, v1, v0}, Lcom/thermasol/touchsteam2/util/FirebaseAnalyticEvents;->logEvent(Landroid/content/Context;Ljava/lang/String;Ljava/lang/String;Ljava/lang/Number;)V

    .line 381
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/Utils;->resetLightSettings(Landroid/content/Context;)V

    return-void
.end method

.method public static adjustFlow(Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;Landroid/content/Context;Z)V
    .registers 5
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0,
            0x0,
            0x0
        }
        names = {
            "service",
            "context",
            "increase"
        }
    .end annotation

    .line 782
    invoke-static {p1}, Landroidx/preference/PreferenceManager;->getDefaultSharedPreferences(Landroid/content/Context;)Landroid/content/SharedPreferences;

    move-result-object p1

    .line 783
    new-instance v0, Ljava/lang/StringBuilder;

    invoke-direct {v0}, Ljava/lang/StringBuilder;-><init>()V

    const-string v1, "showerFlow"

    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object v0

    sget v1, Lcom/thermasol/touchsteam2/GV;->ActiveUser:I

    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;

    move-result-object v0

    invoke-virtual {v0}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v0

    const/4 v1, 0x1

    invoke-interface {p1, v0, v1}, Landroid/content/SharedPreferences;->getInt(Ljava/lang/String;I)I

    move-result p1

    if-eqz p2, :cond_22

    add-int/2addr p1, v1

    goto :goto_24

    :cond_22
    add-int/lit8 p1, p1, -0x1

    :goto_24
    const/4 p2, 0x0

    const/4 v0, 0x2

    .line 790
    invoke-static {p1, p2, v0}, Lcom/thermasol/touchsteam2/util/Utils;->BoundsCheck(III)I

    move-result p1

    .line 791
    invoke-virtual {p0, p1}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->esv_set_flow(I)V

    return-void
.end method

.method private static applyColorFilter(Landroid/graphics/Bitmap;)Landroid/graphics/Bitmap;
    .registers 6
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0
        }
        names = {
            "original"
        }
    .end annotation

    .line 433
    invoke-virtual {p0}, Landroid/graphics/Bitmap;->getWidth()I

    move-result v0

    .line 434
    invoke-virtual {p0}, Landroid/graphics/Bitmap;->getHeight()I

    move-result v1

    .line 436
    sget-object v2, Landroid/graphics/Bitmap$Config;->ARGB_8888:Landroid/graphics/Bitmap$Config;

    invoke-static {v0, v1, v2}, Landroid/graphics/Bitmap;->createBitmap(IILandroid/graphics/Bitmap$Config;)Landroid/graphics/Bitmap;

    move-result-object v0

    .line 437
    new-instance v1, Landroid/graphics/Canvas;

    invoke-direct {v1, v0}, Landroid/graphics/Canvas;-><init>(Landroid/graphics/Bitmap;)V

    .line 439
    new-instance v2, Landroid/graphics/Paint;

    invoke-direct {v2}, Landroid/graphics/Paint;-><init>()V

    .line 440
    new-instance v3, Landroid/graphics/ColorMatrix;

    invoke-direct {v3}, Landroid/graphics/ColorMatrix;-><init>()V

    const/high16 v4, 0x3f000000    # 0.5f

    .line 441
    invoke-virtual {v3, v4}, Landroid/graphics/ColorMatrix;->setSaturation(F)V

    .line 443
    new-instance v4, Landroid/graphics/ColorMatrixColorFilter;

    invoke-direct {v4, v3}, Landroid/graphics/ColorMatrixColorFilter;-><init>(Landroid/graphics/ColorMatrix;)V

    invoke-virtual {v2, v4}, Landroid/graphics/Paint;->setColorFilter(Landroid/graphics/ColorFilter;)Landroid/graphics/ColorFilter;

    const/4 v3, 0x0

    .line 444
    invoke-virtual {v1, p0, v3, v3, v2}, Landroid/graphics/Canvas;->drawBitmap(Landroid/graphics/Bitmap;FFLandroid/graphics/Paint;)V

    return-object v0
.end method

.method public static applyFullscreenOptions(Landroid/view/Window;)V
    .registers 2
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0
        }
        names = {
            "window"
        }
    .end annotation

    if-nez p0, :cond_3

    return-void

    :cond_3
    const/4 v0, 0x2

    .line 797
    invoke-static {v0}, Landroidx/appcompat/app/AppCompatDelegate;->setDefaultNightMode(I)V

    .line 807
    invoke-virtual {p0}, Landroid/view/Window;->getDecorView()Landroid/view/View;

    move-result-object p0

    const/16 v0, 0x1006

    invoke-virtual {p0, v0}, Landroid/view/View;->setSystemUiVisibility(I)V

    return-void
.end method

.method public static attachSecondaryService(Landroid/content/Context;Landroid/os/IBinder;Landroid/content/ServiceConnection;)V
    .registers 3
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0,
            0x0,
            0x0
        }
        names = {
            "context",
            "service",
            "connection"
        }
    .end annotation

    .line 926
    check-cast p0, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;

    invoke-interface {p0}, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;->getInstance()Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;

    move-result-object p0

    invoke-virtual {p0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->getNative()Lcom/thermasol/thermatouchservice/IHardwareService;

    move-result-object p0

    .line 927
    check-cast p0, Lcom/thermasol/touchsteam2/services/SimulatedHardwareService;

    .line 928
    invoke-static {p1}, Lcom/thermasol/thermatouchservice/IHardwareService$Stub;->asInterface(Landroid/os/IBinder;)Lcom/thermasol/thermatouchservice/IHardwareService;

    move-result-object p1

    invoke-virtual {p0, p1, p2}, Lcom/thermasol/touchsteam2/services/SimulatedHardwareService;->setSecondaryService(Lcom/thermasol/thermatouchservice/IHardwareService;Landroid/content/ServiceConnection;)V

    return-void
.end method

.method public static buildServiceIntent()Landroid/content/Intent;
    .registers 4

    .line 933
    new-instance v0, Landroid/content/Intent;

    invoke-direct {v0}, Landroid/content/Intent;-><init>()V

    .line 934
    new-instance v1, Landroid/content/ComponentName;

    const-string v2, "com.thermasol.thermatouchservice"

    const-string v3, "com.thermasol.thermatouchservice.HardwareService"

    invoke-direct {v1, v2, v3}, Landroid/content/ComponentName;-><init>(Ljava/lang/String;Ljava/lang/String;)V

    invoke-virtual {v0, v1}, Landroid/content/Intent;->setComponent(Landroid/content/ComponentName;)Landroid/content/Intent;

    return-object v0
.end method

.method private static buildSteamPreferenceKey(Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;Ljava/lang/String;)Ljava/lang/String;
    .registers 3
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0,
            0x0
        }
        names = {
            "ThermaCan",
            "key"
        }
    .end annotation

    .line 509
    invoke-virtual {p0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->psb_get_state()I

    move-result p0

    const/4 v0, 0x2

    if-ne p0, v0, :cond_1a

    .line 510
    new-instance p0, Ljava/lang/StringBuilder;

    invoke-direct {p0}, Ljava/lang/StringBuilder;-><init>()V

    const-string v0, "steam"

    invoke-virtual {p0, v0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object p0

    invoke-virtual {p0, p1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object p0

    invoke-virtual {p0}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object p1

    :cond_1a
    return-object p1
.end method

.method public static calculateFrameHeight(Landroid/content/res/Resources;I)I
    .registers 5
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0,
            0x0
        }
        names = {
            "resources",
            "menus"
        }
    .end annotation

    .line 1090
    invoke-virtual {p0}, Landroid/content/res/Resources;->getDisplayMetrics()Landroid/util/DisplayMetrics;

    move-result-object v0

    iget v0, v0, Landroid/util/DisplayMetrics;->heightPixels:I

    const v1, 0x7f07019c

    .line 1091
    invoke-virtual {p0, v1}, Landroid/content/res/Resources;->getDimensionPixelSize(I)I

    move-result v1

    const v2, 0x7f0700d7

    .line 1092
    invoke-virtual {p0, v2}, Landroid/content/res/Resources;->getDimensionPixelSize(I)I

    move-result p0

    mul-int/2addr v1, p1

    sub-int/2addr v0, v1

    add-int/2addr v0, p0

    return v0
.end method

.method public static captureViewImageData(Landroid/app/Activity;)[B
    .registers 4
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0
        }
        names = {
            "activity"
        }
    .end annotation

    .line 451
    invoke-virtual {p0}, Landroid/app/Activity;->getWindow()Landroid/view/Window;

    move-result-object p0

    invoke-virtual {p0}, Landroid/view/Window;->getDecorView()Landroid/view/View;

    move-result-object p0

    const/4 v0, 0x1

    .line 452
    invoke-virtual {p0, v0}, Landroid/view/View;->setDrawingCacheEnabled(Z)V

    .line 453
    invoke-virtual {p0}, Landroid/view/View;->buildDrawingCache()V

    .line 454
    invoke-virtual {p0}, Landroid/view/View;->getDrawingCache()Landroid/graphics/Bitmap;

    move-result-object v0

    invoke-static {v0}, Lcom/thermasol/touchsteam2/util/Utils;->applyColorFilter(Landroid/graphics/Bitmap;)Landroid/graphics/Bitmap;

    move-result-object v0

    const/4 v1, 0x0

    .line 455
    invoke-virtual {p0, v1}, Landroid/view/View;->setDrawingCacheEnabled(Z)V

    .line 457
    new-instance p0, Ljava/io/ByteArrayOutputStream;

    invoke-direct {p0}, Ljava/io/ByteArrayOutputStream;-><init>()V

    .line 458
    sget-object v1, Landroid/graphics/Bitmap$CompressFormat;->PNG:Landroid/graphics/Bitmap$CompressFormat;

    const/16 v2, 0x64

    invoke-virtual {v0, v1, v2, p0}, Landroid/graphics/Bitmap;->compress(Landroid/graphics/Bitmap$CompressFormat;ILjava/io/OutputStream;)Z

    .line 459
    invoke-virtual {v0}, Landroid/graphics/Bitmap;->recycle()V

    .line 461
    invoke-virtual {p0}, Ljava/io/ByteArrayOutputStream;->toByteArray()[B

    move-result-object p0

    return-object p0
.end method

.method public static changeOutputValveFromResource(Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;Landroid/content/Context;I)V
    .registers 8
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0,
            0x0,
            0x0
        }
        names = {
            "service",
            "context",
            "resource"
        }
    .end annotation

    const v0, 0x7f0800e6

    if-ne p2, v0, :cond_8

    .line 756
    sget-object p2, Lcom/thermasol/touchsteam2/fragments/DigitalShowerScreenFragment$PersistentStorageFixture;->RAINHEAD:Lcom/thermasol/touchsteam2/fragments/DigitalShowerScreenFragment$PersistentStorageFixture;

    goto :goto_2a

    :cond_8
    const v0, 0x7f0800e7

    if-ne p2, v0, :cond_10

    .line 758
    sget-object p2, Lcom/thermasol/touchsteam2/fragments/DigitalShowerScreenFragment$PersistentStorageFixture;->SHOWERHEAD:Lcom/thermasol/touchsteam2/fragments/DigitalShowerScreenFragment$PersistentStorageFixture;

    goto :goto_2a

    :cond_10
    const v0, 0x7f080100

    if-ne p2, v0, :cond_18

    .line 760
    sget-object p2, Lcom/thermasol/touchsteam2/fragments/DigitalShowerScreenFragment$PersistentStorageFixture;->HANDHELD:Lcom/thermasol/touchsteam2/fragments/DigitalShowerScreenFragment$PersistentStorageFixture;

    goto :goto_2a

    :cond_18
    const v0, 0x7f0800c9

    if-ne p2, v0, :cond_20

    .line 762
    sget-object p2, Lcom/thermasol/touchsteam2/fragments/DigitalShowerScreenFragment$PersistentStorageFixture;->BATH:Lcom/thermasol/touchsteam2/fragments/DigitalShowerScreenFragment$PersistentStorageFixture;

    goto :goto_2a

    :cond_20
    const v0, 0x7f0800ca

    if-ne p2, v0, :cond_28

    .line 764
    sget-object p2, Lcom/thermasol/touchsteam2/fragments/DigitalShowerScreenFragment$PersistentStorageFixture;->BODYSPRAY:Lcom/thermasol/touchsteam2/fragments/DigitalShowerScreenFragment$PersistentStorageFixture;

    goto :goto_2a

    .line 766
    :cond_28
    sget-object p2, Lcom/thermasol/touchsteam2/fragments/DigitalShowerScreenFragment$PersistentStorageFixture;->NOFIXTURE:Lcom/thermasol/touchsteam2/fragments/DigitalShowerScreenFragment$PersistentStorageFixture;

    .line 769
    :goto_2a
    invoke-static {p1}, Landroidx/preference/PreferenceManager;->getDefaultSharedPreferences(Landroid/content/Context;)Landroid/content/SharedPreferences;

    move-result-object p1

    const/4 v0, 0x3

    const-string v1, "valve_0_drawable"

    const-string v2, "valve_1_drawable"

    const-string v3, "valve_2_drawable"

    .line 770
    filled-new-array {v1, v2, v3}, [Ljava/lang/String;

    move-result-object v1

    const/4 v2, 0x0

    :goto_3a
    if-ge v2, v0, :cond_50

    .line 772
    aget-object v3, v1, v2

    const/4 v4, -0x1

    invoke-interface {p1, v3, v4}, Landroid/content/SharedPreferences;->getInt(Ljava/lang/String;I)I

    move-result v3

    .line 773
    invoke-virtual {p2}, Lcom/thermasol/touchsteam2/fragments/DigitalShowerScreenFragment$PersistentStorageFixture;->ordinal()I

    move-result v4

    if-ne v3, v4, :cond_4d

    .line 774
    invoke-virtual {p0, v2}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->esv_set_output(I)V

    goto :goto_50

    :cond_4d
    add-int/lit8 v2, v2, 0x1

    goto :goto_3a

    :cond_50
    :goto_50
    return-void
.end method

.method public static computeAndReturnDeviceId(Landroid/content/Context;)Ljava/lang/String;
    .registers 3
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0
        }
        names = {
            "context"
        }
    .end annotation

    .line 166
    invoke-virtual {p0}, Landroid/content/Context;->getContentResolver()Landroid/content/ContentResolver;

    move-result-object p0

    const-string v0, "android_id"

    invoke-static {p0, v0}, Landroid/provider/Settings$Secure;->getString(Landroid/content/ContentResolver;Ljava/lang/String;)Ljava/lang/String;

    move-result-object p0

    .line 167
    new-instance v0, Ljava/math/BigInteger;

    const/16 v1, 0x10

    invoke-direct {v0, p0, v1}, Ljava/math/BigInteger;-><init>(Ljava/lang/String;I)V

    const/16 p0, 0x15

    .line 168
    invoke-virtual {v0, p0}, Ljava/math/BigInteger;->toString(I)Ljava/lang/String;

    move-result-object p0

    const/4 v0, 0x0

    const/4 v1, 0x6

    .line 169
    invoke-virtual {p0, v0, v1}, Ljava/lang/String;->substring(II)Ljava/lang/String;

    move-result-object p0

    .line 171
    invoke-static {}, Lcom/thermasol/touchsteam2/util/CoreCountProvider;->getInstance()Lcom/thermasol/touchsteam2/util/CoreCountProvider;

    move-result-object v0

    invoke-virtual {v0}, Lcom/thermasol/touchsteam2/util/CoreCountProvider;->getCoreCount()I

    move-result v0

    const/4 v1, 0x1

    if-eq v0, v1, :cond_57

    const/4 v1, 0x2

    if-eq v0, v1, :cond_43

    const/4 v1, 0x4

    if-eq v0, v1, :cond_2f

    goto :goto_6a

    .line 180
    :cond_2f
    new-instance v0, Ljava/lang/StringBuilder;

    invoke-direct {v0}, Ljava/lang/StringBuilder;-><init>()V

    invoke-virtual {v0, p0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object p0

    const-string v0, "q"

    invoke-virtual {p0, v0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object p0

    invoke-virtual {p0}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object p0

    goto :goto_6a

    .line 177
    :cond_43
    new-instance v0, Ljava/lang/StringBuilder;

    invoke-direct {v0}, Ljava/lang/StringBuilder;-><init>()V

    invoke-virtual {v0, p0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object p0

    const-string v0, "d"

    invoke-virtual {p0, v0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object p0

    invoke-virtual {p0}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object p0

    goto :goto_6a

    .line 174
    :cond_57
    new-instance v0, Ljava/lang/StringBuilder;

    invoke-direct {v0}, Ljava/lang/StringBuilder;-><init>()V

    invoke-virtual {v0, p0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object p0

    const-string v0, "s"

    invoke-virtual {p0, v0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object p0

    invoke-virtual {p0}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object p0

    :goto_6a
    return-object p0
.end method

.method private static delayMusicVolume(Landroid/content/Context;II)V
    .registers 5

    sget-boolean v0, Lcom/thermasol/touchsteam2/util/OverheadLight;->sShutdownMuted:Z

    if-nez v0, :tt_hv_spawn

    return-void

    :tt_hv_spawn

    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x10,
            0x10,
            0x10
        }
        names = {
            "context",
            "volume",
            "delay"
        }
    .end annotation

    .line 566
    new-instance v0, Ljava/lang/Thread;

    new-instance v1, Lcom/thermasol/touchsteam2/util/-$$Lambda$Utils$q_hQ287_rT8SvwrN8-OgSwqt7yA;

    invoke-direct {v1, p2, p0, p1}, Lcom/thermasol/touchsteam2/util/-$$Lambda$Utils$q_hQ287_rT8SvwrN8-OgSwqt7yA;-><init>(ILandroid/content/Context;I)V

    invoke-direct {v0, v1}, Ljava/lang/Thread;-><init>(Ljava/lang/Runnable;)V

    .line 569
    invoke-virtual {v0}, Ljava/lang/Thread;->start()V

    return-void
.end method

.method public static enableExternalApp(Landroid/content/Context;Ljava/lang/String;)V
    .registers 3
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0,
            0x0
        }
        names = {
            "context",
            "packageName"
        }
    .end annotation

    .line 837
    check-cast p0, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;

    invoke-interface {p0}, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;->getInstance()Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;

    move-result-object p0

    .line 839
    :try_start_6
    invoke-virtual {p0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->getNative()Lcom/thermasol/thermatouchservice/IHardwareService;

    move-result-object p0

    const/4 v0, 0x1

    invoke-interface {p0, p1, v0}, Lcom/thermasol/thermatouchservice/IHardwareService;->setApplicationEnabled(Ljava/lang/String;I)V
    :try_end_e
    .catch Ljava/lang/Exception; {:try_start_6 .. :try_end_e} :catch_f

    goto :goto_13

    :catch_f
    move-exception p0

    .line 840
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/Utils;->handleException(Ljava/lang/Exception;)V

    :goto_13
    return-void
.end method

.method public static generateSecondaryUserThemeColor(Landroid/content/Context;)I
    .registers 4
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0
        }
        names = {
            "context"
        }
    .end annotation

    .line 1070
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/Utils;->getUserThemeColor(Landroid/content/Context;)I

    move-result p0

    const/4 v0, 0x3

    new-array v0, v0, [F

    .line 1072
    invoke-static {p0, v0}, Landroid/graphics/Color;->colorToHSV(I[F)V

    const/4 p0, 0x1

    .line 1073
    aget v1, v0, p0

    const v2, 0x3f333333    # 0.7f

    mul-float/2addr v1, v2

    aput v1, v0, p0

    .line 1075
    invoke-static {v0}, Landroid/graphics/Color;->HSVToColor([F)I

    move-result p0

    return p0
.end method

.method private static getAndroidVolumeInterval(Landroid/content/Context;)I
    .registers 2
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0
        }
        names = {
            "context"
        }
    .end annotation

    const-string v0, "audio"

    .line 1100
    invoke-virtual {p0, v0}, Landroid/content/Context;->getSystemService(Ljava/lang/String;)Ljava/lang/Object;

    move-result-object p0

    check-cast p0, Landroid/media/AudioManager;

    const/4 v0, 0x3

    .line 1101
    invoke-virtual {p0, v0}, Landroid/media/AudioManager;->getStreamMaxVolume(I)I

    move-result p0

    .line 1103
    div-int/lit8 p0, p0, 0xf

    return p0
.end method

.method private static getAppDetails(Ljava/lang/String;)Ljava/util/List;
    .registers 4
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0
        }
        names = {
            "listing"
        }
    .end annotation

    .annotation system Ldalvik/annotation/Signature;
        value = {
            "(",
            "Ljava/lang/String;",
            ")",
            "Ljava/util/List<",
            "Lcom/thermasol/utils/AppDetail;",
            ">;"
        }
    .end annotation

    .line 1026
    sget-object v0, Lcom/thermasol/touchsteam2/util/Utils;->mDetails:Ljava/util/List;

    invoke-interface {v0}, Ljava/util/List;->clear()V

    .line 1027
    new-instance v0, Ljava/lang/StringBuilder;

    invoke-direct {v0}, Ljava/lang/StringBuilder;-><init>()V

    const-string v1, "http://thermatouch.tsolup.com/"

    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object v0

    invoke-virtual {v0, p0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object p0

    invoke-virtual {p0}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object p0

    invoke-static {p0}, Lcom/thermasol/utils/Utility;->getVerifiableFromServer(Ljava/lang/String;)Lcom/thermasol/utils/Verifiable;

    move-result-object p0

    .line 1028
    new-instance v0, Ljava/io/BufferedReader;

    new-instance v1, Ljava/io/CharArrayReader;

    new-instance v2, Ljava/lang/String;

    invoke-virtual {p0}, Lcom/thermasol/utils/Verifiable;->getBinary()[B

    move-result-object p0

    invoke-direct {v2, p0}, Ljava/lang/String;-><init>([B)V

    invoke-virtual {v2}, Ljava/lang/String;->toCharArray()[C

    move-result-object p0

    invoke-direct {v1, p0}, Ljava/io/CharArrayReader;-><init>([C)V

    invoke-direct {v0, v1}, Ljava/io/BufferedReader;-><init>(Ljava/io/Reader;)V

    .line 1029
    invoke-static {v0}, Lcom/thermasol/utils/Utility;->buildAppsServerResponse(Ljava/io/BufferedReader;)Lcom/thermasol/utils/ServerResponse;

    move-result-object p0

    invoke-virtual {p0}, Lcom/thermasol/utils/ServerResponse;->getAppDetails()Ljava/util/List;

    move-result-object p0

    sput-object p0, Lcom/thermasol/touchsteam2/util/Utils;->mDetails:Ljava/util/List;

    .line 1031
    new-instance p0, Ljava/util/ArrayList;

    sget-object v0, Lcom/thermasol/touchsteam2/util/Utils;->mDetails:Ljava/util/List;

    invoke-direct {p0, v0}, Ljava/util/ArrayList;-><init>(Ljava/util/Collection;)V

    return-object p0
.end method

.method public static getAppListCacheFile(Landroid/content/Context;)Ljava/io/File;
    .registers 3
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0
        }
        names = {
            "context"
        }
    .end annotation

    .line 1014
    new-instance v0, Ljava/io/File;

    sget-object v1, Landroid/os/Environment;->DIRECTORY_DOCUMENTS:Ljava/lang/String;

    invoke-virtual {p0, v1}, Landroid/content/Context;->getExternalFilesDir(Ljava/lang/String;)Ljava/io/File;

    move-result-object p0

    const-string v1, "cached"

    invoke-direct {v0, p0, v1}, Ljava/io/File;-><init>(Ljava/io/File;Ljava/lang/String;)V

    return-object v0
.end method

.method public static getBoundedVolume(I)I
    .registers 3
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0
        }
        names = {
            "volume"
        }
    .end annotation

    const/4 v0, 0x0

    const/16 v1, 0xf

    .line 945
    invoke-static {p0, v0, v1}, Lcom/thermasol/touchsteam2/util/Utils;->BoundsCheck(III)I

    move-result p0

    return p0
.end method

.method public static getHardwareRevision(Landroid/content/Context;)I
    .registers 1
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0
        }
        names = {
            "context"
        }
    .end annotation

    .line 97
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/Utils;->IsSevenInch(Landroid/content/Context;)Z

    move-result p0

    if-eqz p0, :cond_8

    const/4 p0, 0x2

    goto :goto_9

    :cond_8
    const/4 p0, 0x1

    :goto_9
    return p0
.end method

.method public static getRecoveryTimerSetpointForActiveUser(Landroid/content/Context;)I
    .registers 3
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0
        }
        names = {
            "context"
        }
    .end annotation

    .line 748
    invoke-static {p0}, Landroidx/preference/PreferenceManager;->getDefaultSharedPreferences(Landroid/content/Context;)Landroid/content/SharedPreferences;

    move-result-object p0

    .line 749
    new-instance v0, Ljava/lang/StringBuilder;

    invoke-direct {v0}, Ljava/lang/StringBuilder;-><init>()V

    const-string v1, "userTimerSetpoint"

    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object v0

    sget v1, Lcom/thermasol/touchsteam2/GV;->ActiveUser:I

    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;

    move-result-object v0

    invoke-virtual {v0}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v0

    const/16 v1, 0x4b0

    invoke-interface {p0, v0, v1}, Landroid/content/SharedPreferences;->getInt(Ljava/lang/String;I)I

    move-result p0

    return p0
.end method

.method public static getScaledSize(Landroid/content/res/Resources;I)I
    .registers 4
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0,
            0x0
        }
        names = {
            "resources",
            "baseSize"
        }
    .end annotation

    const v0, 0x7f0700d7

    .line 1082
    invoke-virtual {p0, v0}, Landroid/content/res/Resources;->getDimensionPixelSize(I)I

    move-result v0

    int-to-float v0, v0

    const/high16 v1, 0x44480000    # 800.0f

    sub-float/2addr v1, v0

    .line 1083
    invoke-virtual {p0}, Landroid/content/res/Resources;->getDisplayMetrics()Landroid/util/DisplayMetrics;

    move-result-object v0

    iget v0, v0, Landroid/util/DisplayMetrics;->heightPixels:I

    int-to-float v0, v0

    invoke-virtual {p0}, Landroid/content/res/Resources;->getDisplayMetrics()Landroid/util/DisplayMetrics;

    move-result-object p0

    iget p0, p0, Landroid/util/DisplayMetrics;->density:F

    div-float/2addr v0, p0

    div-float/2addr v1, v0

    int-to-float p0, p1

    div-float/2addr p0, v1

    float-to-int p0, p0

    return p0
.end method

.method public static getSteamBasedSetting(Landroid/content/Context;Ljava/lang/String;Ljava/lang/Object;Ljava/lang/Class;)Ljava/lang/Object;
    .registers 6
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0,
            0x0,
            0x0,
            0x0
        }
        names = {
            "context",
            "key",
            "defValue",
            "type"
        }
    .end annotation

    .annotation system Ldalvik/annotation/Signature;
        value = {
            "(",
            "Landroid/content/Context;",
            "Ljava/lang/String;",
            "Ljava/lang/Object;",
            "Ljava/lang/Class<",
            "*>;)",
            "Ljava/lang/Object;"
        }
    .end annotation

    .line 519
    invoke-static {p0}, Landroidx/preference/PreferenceManager;->getDefaultSharedPreferences(Landroid/content/Context;)Landroid/content/SharedPreferences;

    move-result-object v0

    .line 521
    check-cast p0, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;

    invoke-interface {p0}, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;->getInstance()Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;

    move-result-object p0

    invoke-static {p0, p1}, Lcom/thermasol/touchsteam2/util/Utils;->buildSteamPreferenceKey(Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;Ljava/lang/String;)Ljava/lang/String;

    move-result-object p0

    .line 522
    invoke-virtual {p3}, Ljava/lang/Class;->toString()Ljava/lang/String;

    move-result-object p1

    invoke-virtual {p1}, Ljava/lang/String;->hashCode()I

    const-string v1, "int"

    invoke-virtual {p1, v1}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z

    move-result v1

    if-nez v1, :cond_4a

    const-string v1, "class java.lang.String"

    invoke-virtual {p1, v1}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z

    move-result p1

    if-nez p1, :cond_30

    .line 530
    invoke-virtual {p3}, Ljava/lang/Class;->toString()Ljava/lang/String;

    move-result-object p0

    const-string p1, "DEBUG_TYPE_DEF"

    invoke-static {p1, p0}, Landroid/util/Log;->v(Ljava/lang/String;Ljava/lang/String;)I

    const/4 p0, 0x0

    goto :goto_6b

    .line 527
    :cond_30
    new-instance p1, Ljava/lang/StringBuilder;

    invoke-direct {p1}, Ljava/lang/StringBuilder;-><init>()V

    invoke-virtual {p1, p0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object p0

    sget p1, Lcom/thermasol/touchsteam2/GV;->ActiveUser:I

    invoke-virtual {p0, p1}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;

    move-result-object p0

    invoke-virtual {p0}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object p0

    check-cast p2, Ljava/lang/String;

    invoke-interface {v0, p0, p2}, Landroid/content/SharedPreferences;->getString(Ljava/lang/String;Ljava/lang/String;)Ljava/lang/String;

    move-result-object p0

    goto :goto_6b

    .line 524
    :cond_4a
    new-instance p1, Ljava/lang/StringBuilder;

    invoke-direct {p1}, Ljava/lang/StringBuilder;-><init>()V

    invoke-virtual {p1, p0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object p0

    sget p1, Lcom/thermasol/touchsteam2/GV;->ActiveUser:I

    invoke-virtual {p0, p1}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;

    move-result-object p0

    invoke-virtual {p0}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object p0

    check-cast p2, Ljava/lang/Integer;

    invoke-virtual {p2}, Ljava/lang/Integer;->intValue()I

    move-result p1

    invoke-interface {v0, p0, p1}, Landroid/content/SharedPreferences;->getInt(Ljava/lang/String;I)I

    move-result p0

    invoke-static {p0}, Ljava/lang/Integer;->valueOf(I)Ljava/lang/Integer;

    move-result-object p0

    :goto_6b
    return-object p0
.end method

.method private static getUserTheme(Landroid/content/Context;)I
    .registers 3
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0
        }
        names = {
            "context"
        }
    .end annotation

    .line 1108
    invoke-static {p0}, Landroidx/preference/PreferenceManager;->getDefaultSharedPreferences(Landroid/content/Context;)Landroid/content/SharedPreferences;

    move-result-object p0

    const-string v0, "userAppTheme"

    const-string v1, "-1"

    .line 1111
    invoke-interface {p0, v0, v1}, Landroid/content/SharedPreferences;->getString(Ljava/lang/String;Ljava/lang/String;)Ljava/lang/String;

    move-result-object p0

    invoke-static {p0}, Ljava/lang/Integer;->parseInt(Ljava/lang/String;)I

    move-result p0

    if-eqz p0, :cond_24

    const/4 v0, 0x1

    if-eq p0, v0, :cond_20

    const/4 v0, 0x2

    if-eq p0, v0, :cond_1c

    const p0, 0x7f1200f0

    goto :goto_27

    :cond_1c
    const p0, 0x7f1200eb

    goto :goto_27

    :cond_20
    const p0, 0x7f1200f2

    goto :goto_27

    :cond_24
    const p0, 0x7f1202ff

    :goto_27
    return p0
.end method

.method public static getUserThemeColor(Landroid/content/Context;)I
    .registers 4
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0
        }
        names = {
            "context"
        }
    .end annotation

    .line 1060
    invoke-virtual {p0}, Landroid/content/Context;->getResources()Landroid/content/res/Resources;

    move-result-object v0

    invoke-virtual {v0}, Landroid/content/res/Resources;->newTheme()Landroid/content/res/Resources$Theme;

    move-result-object v0

    .line 1061
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/Utils;->getUserTheme(Landroid/content/Context;)I

    move-result p0

    const/4 v1, 0x1

    invoke-virtual {v0, p0, v1}, Landroid/content/res/Resources$Theme;->applyStyle(IZ)V

    .line 1062
    new-instance p0, Landroid/util/TypedValue;

    invoke-direct {p0}, Landroid/util/TypedValue;-><init>()V

    const v2, 0x7f040383

    .line 1063
    invoke-virtual {v0, v2, p0, v1}, Landroid/content/res/Resources$Theme;->resolveAttribute(ILandroid/util/TypedValue;Z)Z

    .line 1065
    iget p0, p0, Landroid/util/TypedValue;->data:I

    return p0
.end method

.method public static getUserThemedDrawable(Landroid/content/Context;Landroid/graphics/drawable/Drawable;)Landroid/graphics/drawable/Drawable;
    .registers 4
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0,
            0x0
        }
        names = {
            "context",
            "drawable"
        }
    .end annotation

    .line 1051
    invoke-virtual {p0}, Landroid/content/Context;->getResources()Landroid/content/res/Resources;

    move-result-object v0

    invoke-virtual {v0}, Landroid/content/res/Resources;->newTheme()Landroid/content/res/Resources$Theme;

    move-result-object v0

    .line 1052
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/Utils;->getUserTheme(Landroid/content/Context;)I

    move-result p0

    const/4 v1, 0x1

    invoke-virtual {v0, p0, v1}, Landroid/content/res/Resources$Theme;->applyStyle(IZ)V

    .line 1053
    invoke-virtual {p1, v0}, Landroid/graphics/drawable/Drawable;->applyTheme(Landroid/content/res/Resources$Theme;)V

    return-object p1
.end method

.method public static handleException(Ljava/lang/Exception;)V
    .registers 1
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0
        }
        names = {
            "e"
        }
    .end annotation

    return-void
.end method

.method public static handleHardwareError(Landroid/content/Context;I)V
    .registers 5
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0,
            0x0
        }
        names = {
            "context",
            "errors"
        }
    .end annotation

    .line 409
    invoke-static {p1}, Ljava/lang/Integer;->valueOf(I)Ljava/lang/Integer;

    move-result-object v0

    const-string v1, "hardware_error"

    const-string v2, "errors"

    invoke-static {p0, v1, v2, v0}, Lcom/thermasol/touchsteam2/util/FirebaseAnalyticEvents;->logEvent(Landroid/content/Context;Ljava/lang/String;Ljava/lang/String;Ljava/lang/Number;)V

    .line 411
    invoke-static {p0}, Landroidx/preference/PreferenceManager;->getDefaultSharedPreferences(Landroid/content/Context;)Landroid/content/SharedPreferences;

    move-result-object p0

    .line 412
    invoke-interface {p0}, Landroid/content/SharedPreferences;->edit()Landroid/content/SharedPreferences$Editor;

    move-result-object p0

    const-string v0, "systemErrors"

    .line 413
    invoke-interface {p0, v0, p1}, Landroid/content/SharedPreferences$Editor;->putInt(Ljava/lang/String;I)Landroid/content/SharedPreferences$Editor;

    const-string p1, "requestLayout"

    const/4 v0, 0x6

    .line 414
    invoke-interface {p0, p1, v0}, Landroid/content/SharedPreferences$Editor;->putInt(Ljava/lang/String;I)Landroid/content/SharedPreferences$Editor;

    move-result-object p0

    invoke-interface {p0}, Landroid/content/SharedPreferences$Editor;->commit()Z

    return-void
.end method

.method public static handleInstall(Landroid/content/Context;Ljava/io/File;)V
    .registers 4
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0,
            0x0
        }
        names = {
            "context",
            "file"
        }
    .end annotation

    .line 860
    invoke-static {}, Lcom/thermasol/touchsteam2/util/Utils;->isVantron()Z

    move-result v0

    if-eqz v0, :cond_31

    .line 861
    new-instance p0, Ljava/lang/StringBuilder;

    invoke-direct {p0}, Ljava/lang/StringBuilder;-><init>()V

    const-string v0, "pm install "

    invoke-virtual {p0, v0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object p0

    sget-object v0, Landroid/os/Environment;->DIRECTORY_DOWNLOADS:Ljava/lang/String;

    invoke-static {v0}, Landroid/os/Environment;->getExternalStoragePublicDirectory(Ljava/lang/String;)Ljava/io/File;

    move-result-object v0

    invoke-virtual {p0, v0}, Ljava/lang/StringBuilder;->append(Ljava/lang/Object;)Ljava/lang/StringBuilder;

    move-result-object p0

    const-string v0, "/"

    invoke-virtual {p0, v0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object p0

    invoke-virtual {p1}, Ljava/io/File;->getName()Ljava/lang/String;

    move-result-object p1

    invoke-virtual {p0, p1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object p0

    invoke-virtual {p0}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object p0

    .line 862
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/Utils;->sendLinuxCommand(Ljava/lang/String;)Lcom/thermasol/touchsteam2/util/Utils$ExecutionResult;

    goto :goto_45

    :cond_31
    const-string v0, "com.thermasol.touchsteam2.fileprovider"

    .line 864
    invoke-static {p0, v0, p1}, Landroidx/core/content/FileProvider;->getUriForFile(Landroid/content/Context;Ljava/lang/String;Ljava/io/File;)Landroid/net/Uri;

    move-result-object p1

    .line 866
    new-instance v0, Landroid/content/Intent;

    const-string v1, "android.intent.action.INSTALL_PACKAGE"

    invoke-direct {v0, v1, p1}, Landroid/content/Intent;-><init>(Ljava/lang/String;Landroid/net/Uri;)V

    const/4 p1, 0x1

    .line 867
    invoke-virtual {v0, p1}, Landroid/content/Intent;->setFlags(I)Landroid/content/Intent;

    .line 868
    invoke-virtual {p0, v0}, Landroid/content/Context;->startActivity(Landroid/content/Intent;)V

    :goto_45
    return-void
.end method

.method public static isOnline()Z
    .registers 1

    const-string v0, "/system/bin/ping -c 1 -W 1 8.8.8.8"

    .line 155
    invoke-static {v0}, Lcom/thermasol/touchsteam2/util/Utils;->sendLinuxCommand(Ljava/lang/String;)Lcom/thermasol/touchsteam2/util/Utils$ExecutionResult;

    move-result-object v0

    invoke-virtual {v0}, Lcom/thermasol/touchsteam2/util/Utils$ExecutionResult;->getResult()I

    move-result v0

    if-nez v0, :cond_e

    const/4 v0, 0x1

    goto :goto_f

    :cond_e
    const/4 v0, 0x0

    :goto_f
    return v0
.end method

.method public static isVantron()Z
    .registers 2

    .line 160
    sget-object v0, Landroid/os/Build;->DEVICE:Ljava/lang/String;

    const-string v1, "ipc_rk66_tms"

    invoke-virtual {v0, v1}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z

    move-result v0

    return v0
.end method

.method public static killExternalApps(Landroid/content/Context;Ljava/lang/String;)V
    .registers 7
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0,
            0x0
        }
        names = {
            "context",
            "ignore"
        }
    .end annotation

    .line 845
    move-object v0, p0

    check-cast v0, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;

    invoke-interface {v0}, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;->getInstance()Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;

    move-result-object v0

    .line 847
    :try_start_7
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/Utils;->getAppListCacheFile(Landroid/content/Context;)Ljava/io/File;

    move-result-object v1

    const/4 v2, 0x1

    invoke-static {p0, v1, v2}, Lcom/thermasol/touchsteam2/util/Utils;->parseServerResponse(Landroid/content/Context;Ljava/io/File;Z)Ljava/util/List;

    move-result-object p0

    invoke-interface {p0}, Ljava/util/List;->iterator()Ljava/util/Iterator;

    move-result-object p0

    :goto_14
    invoke-interface {p0}, Ljava/util/Iterator;->hasNext()Z

    move-result v1

    if-eqz v1, :cond_49

    invoke-interface {p0}, Ljava/util/Iterator;->next()Ljava/lang/Object;

    move-result-object v1

    check-cast v1, Lcom/thermasol/utils/AppDetail;

    if-eqz p1, :cond_38

    .line 848
    invoke-virtual {v1}, Lcom/thermasol/utils/AppDetail;->getPackageName()Ljava/lang/String;

    move-result-object v3

    invoke-virtual {v3, p1}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z

    move-result v3

    if-eqz v3, :cond_38

    .line 849
    invoke-virtual {v0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->getNative()Lcom/thermasol/thermatouchservice/IHardwareService;

    move-result-object v3

    invoke-virtual {v1}, Lcom/thermasol/utils/AppDetail;->getPackageName()Ljava/lang/String;

    move-result-object v1

    invoke-interface {v3, v1, v2}, Lcom/thermasol/thermatouchservice/IHardwareService;->setApplicationEnabled(Ljava/lang/String;I)V

    goto :goto_14

    .line 852
    :cond_38
    invoke-virtual {v0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->getNative()Lcom/thermasol/thermatouchservice/IHardwareService;

    move-result-object v3

    invoke-virtual {v1}, Lcom/thermasol/utils/AppDetail;->getPackageName()Ljava/lang/String;

    move-result-object v1

    const/4 v4, 0x2

    invoke-interface {v3, v1, v4}, Lcom/thermasol/thermatouchservice/IHardwareService;->setApplicationEnabled(Ljava/lang/String;I)V
    :try_end_44
    .catch Ljava/lang/Exception; {:try_start_7 .. :try_end_44} :catch_45

    goto :goto_14

    :catch_45
    move-exception p0

    .line 854
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/Utils;->handleException(Ljava/lang/Exception;)V

    :cond_49
    return-void
.end method

.method static synthetic lambda$delayMusicVolume$1(ILandroid/content/Context;I)V
    .registers 5

    sget-boolean v0, Lcom/thermasol/touchsteam2/util/OverheadLight;->sShutdownMuted:Z

    if-nez v0, :tt_hv_wake

    return-void

    :tt_hv_wake


    int-to-long v0, p0

    .line 567
    :try_start_1
    invoke-static {v0, v1}, Ljava/lang/Thread;->sleep(J)V
    :try_end_4
    .catch Ljava/lang/Exception; {:try_start_1 .. :try_end_4} :catch_5

    goto :goto_9

    :catch_5
    move-exception p0

    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/Utils;->handleException(Ljava/lang/Exception;)V

    .line 568
    :goto_9
    invoke-static {p1, p2}, Lcom/thermasol/touchsteam2/util/OverheadLight;->setMasterVolume(Landroid/content/Context;I)V

    return-void
.end method

.method static synthetic lambda$resetLightSettings$0(Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;Landroid/content/Context;)V
    .registers 4

    .line 422
    invoke-virtual {p0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->slsr_voice_mute()V

    .line 423
    sget p0, Lcom/thermasol/touchsteam2/GV;->ActiveUser:I

    invoke-static {p1, p0}, Lcom/thermasol/touchsteam2/util/Utils;->loadLightSettings(Landroid/content/Context;I)V

    const-wide/16 v0, 0x1388

    .line 425
    :try_start_a
    invoke-static {v0, v1}, Ljava/lang/Thread;->sleep(J)V
    :try_end_d
    .catch Ljava/lang/Exception; {:try_start_a .. :try_end_d} :catch_e

    goto :goto_12

    :catch_e
    move-exception p0

    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/Utils;->handleException(Ljava/lang/Exception;)V

    .line 426
    :goto_12
    sget p0, Lcom/thermasol/touchsteam2/GV;->ActiveUser:I

    invoke-static {p1, p0}, Lcom/thermasol/touchsteam2/util/Utils;->loadVoiceVolumeSettings(Landroid/content/Context;I)V

    return-void
.end method

.method public static loadLightSettings(Landroid/content/Context;I)V
    .registers 11
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0,
            0x0
        }
        names = {
            "context",
            "user"
        }
    .end annotation

    const/4 v0, 0x0

    .line 663
    invoke-static {v0}, Ljava/lang/Integer;->valueOf(I)Ljava/lang/Integer;

    move-result-object v1

    sget-object v2, Ljava/lang/Integer;->TYPE:Ljava/lang/Class;

    const-string v3, "lightStateUser"

    invoke-static {p0, v3, v1, v2}, Lcom/thermasol/touchsteam2/util/Utils;->getSteamBasedSetting(Landroid/content/Context;Ljava/lang/String;Ljava/lang/Object;Ljava/lang/Class;)Ljava/lang/Object;

    move-result-object v2

    check-cast v2, Ljava/lang/Integer;

    invoke-virtual {v2}, Ljava/lang/Integer;->intValue()I

    move-result v2

    const/4 v3, 0x1

    if-ne v2, v3, :cond_18

    move v2, v3

    goto :goto_19

    :cond_18
    move v2, v0

    :goto_19
    const/16 v4, 0x50

    .line 664
    invoke-static {v4}, Ljava/lang/Integer;->valueOf(I)Ljava/lang/Integer;

    move-result-object v4

    sget-object v5, Ljava/lang/Integer;->TYPE:Ljava/lang/Class;

    const-string v6, "lightIntensityUser"

    invoke-static {p0, v6, v4, v5}, Lcom/thermasol/touchsteam2/util/Utils;->getSteamBasedSetting(Landroid/content/Context;Ljava/lang/String;Ljava/lang/Object;Ljava/lang/Class;)Ljava/lang/Object;

    move-result-object v4

    check-cast v4, Ljava/lang/Integer;

    invoke-virtual {v4}, Ljava/lang/Integer;->intValue()I

    move-result v4

    .line 666
    move-object v5, p0

    check-cast v5, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;

    invoke-interface {v5}, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;->getInstance()Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;

    move-result-object v5

    .line 667
    invoke-virtual {v5}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->psb_get_is_psb_active()Z

    move-result v6

    if-eqz v6, :cond_58

    .line 668
    invoke-static {p0}, Landroidx/preference/PreferenceManager;->getDefaultSharedPreferences(Landroid/content/Context;)Landroid/content/SharedPreferences;

    move-result-object v6

    .line 669
    new-instance v7, Ljava/lang/StringBuilder;

    invoke-direct {v7}, Ljava/lang/StringBuilder;-><init>()V

    const-string v8, "tempFormatUser"

    invoke-virtual {v7, v8}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object v7

    invoke-virtual {v7, p1}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;

    move-result-object p1

    invoke-virtual {p1}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object p1

    invoke-interface {v6, p1, v0}, Landroid/content/SharedPreferences;->getInt(Ljava/lang/String;I)I

    move-result p1

    .line 670
    invoke-virtual {v5, p1}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->slsr_set_temperature_format(I)V

    .line 672
    :cond_58
    invoke-static {p0, v4}, Lcom/thermasol/touchsteam2/util/OverheadLight;->setIntensity(Landroid/content/Context;I)V

    if-eqz v2, :cond_61

    .line 674
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/OverheadLight;->turnOn(Landroid/content/Context;)V

    goto :goto_64

    .line 676
    :cond_61
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/OverheadLight;->turnOff(Landroid/content/Context;)V

    :goto_64
    if-eqz v2, :cond_8f

    .line 679
    invoke-static {v3}, Ljava/lang/Integer;->valueOf(I)Ljava/lang/Integer;

    move-result-object p1

    sget-object v0, Ljava/lang/Integer;->TYPE:Ljava/lang/Class;

    const-string v2, "lightModeUser"

    invoke-static {p0, v2, p1, v0}, Lcom/thermasol/touchsteam2/util/Utils;->getSteamBasedSetting(Landroid/content/Context;Ljava/lang/String;Ljava/lang/Object;Ljava/lang/Class;)Ljava/lang/Object;

    move-result-object p1

    check-cast p1, Ljava/lang/Integer;

    invoke-virtual {p1}, Ljava/lang/Integer;->intValue()I

    move-result p1

    .line 680
    invoke-static {p0, p1}, Lcom/thermasol/touchsteam2/util/OverheadLight;->setMode(Landroid/content/Context;I)V

    const/4 v0, 0x4

    if-ne p1, v0, :cond_8f

    .line 682
    sget-object p1, Ljava/lang/Integer;->TYPE:Ljava/lang/Class;

    const-string v0, "lightChromColorUser"

    invoke-static {p0, v0, v1, p1}, Lcom/thermasol/touchsteam2/util/Utils;->getSteamBasedSetting(Landroid/content/Context;Ljava/lang/String;Ljava/lang/Object;Ljava/lang/Class;)Ljava/lang/Object;

    move-result-object p1

    check-cast p1, Ljava/lang/Integer;

    invoke-virtual {p1}, Ljava/lang/Integer;->intValue()I

    move-result p1

    .line 683
    invoke-static {p0, p1}, Lcom/thermasol/touchsteam2/util/OverheadLight;->setChromaState(Landroid/content/Context;I)V

    :cond_8f
    return-void
.end method

.method private static loadOverheadLightSettings(Landroid/content/Context;I)V
    .registers 3
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0,
            0x0
        }
        names = {
            "context",
            "user"
        }
    .end annotation

    .line 717
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/OverheadLight;->isActive(Landroid/content/Context;)Z

    move-result v0

    if-nez v0, :cond_7

    return-void

    .line 719
    :cond_7
    invoke-static {p0, p1}, Lcom/thermasol/touchsteam2/util/Utils;->loadLightSettings(Landroid/content/Context;I)V

    .line 720
    invoke-static {p0, p1}, Lcom/thermasol/touchsteam2/util/Utils;->loadVoiceVolumeSettings(Landroid/content/Context;I)V

    return-void
.end method

.method private static loadSteamSettings(Landroid/content/Context;I)V
    .registers 6
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0,
            0x0
        }
        names = {
            "context",
            "user"
        }
    .end annotation

    .line 705
    move-object v0, p0

    check-cast v0, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;

    invoke-interface {v0}, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;->getInstance()Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;

    move-result-object v0

    .line 706
    invoke-virtual {v0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->psb_get_is_psb_active()Z

    move-result v1

    if-nez v1, :cond_e

    return-void

    .line 708
    :cond_e
    invoke-static {p0}, Landroidx/preference/PreferenceManager;->getDefaultSharedPreferences(Landroid/content/Context;)Landroid/content/SharedPreferences;

    move-result-object v1

    .line 709
    new-instance v2, Ljava/lang/StringBuilder;

    invoke-direct {v2}, Ljava/lang/StringBuilder;-><init>()V

    const-string v3, "steamTempUser"

    invoke-virtual {v2, v3}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object v2

    invoke-virtual {v2, p1}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;

    move-result-object p1

    invoke-virtual {p1}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object p1

    const/16 v2, 0x5a

    invoke-interface {v1, p1, v2}, Landroid/content/SharedPreferences;->getInt(Ljava/lang/String;I)I

    move-result p1

    .line 710
    invoke-virtual {v0, p1}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->psb_set_temperature_setpoint(I)V

    .line 711
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/Utils;->getRecoveryTimerSetpointForActiveUser(Landroid/content/Context;)I

    move-result p0

    .line 712
    invoke-virtual {v0, p0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->psb_set_timer_setpoint(I)V

    return-void
.end method

.method public static loadUserSettings(Landroid/content/Context;I)V
    .registers 9

    # A user session is starting: release the shutdown mute so the volume and
    # source calls below can restore normal audio.
    const/4 v0, 0x0

    sput-boolean v0, Lcom/thermasol/touchsteam2/util/OverheadLight;->sShutdownMuted:Z

    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0,
            0x0
        }
        names = {
            "context",
            "user"
        }
    .end annotation

    const-string v0, "wifi"

    .line 620
    move-object v1, p0

    check-cast v1, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;

    invoke-interface {v1}, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;->getInstance()Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;

    move-result-object v1

    .line 621
    invoke-static {p0}, Landroidx/preference/PreferenceManager;->getDefaultSharedPreferences(Landroid/content/Context;)Landroid/content/SharedPreferences;

    move-result-object v2

    const/4 v3, 0x0

    const/4 v4, 0x2

    .line 623
    invoke-static {p1, v3, v4}, Lcom/thermasol/touchsteam2/util/Utils;->BoundsCheck(III)I

    move-result v4

    sput v4, Lcom/thermasol/touchsteam2/GV;->ActiveUser:I

    .line 625
    new-instance v4, Ljava/lang/StringBuilder;

    invoke-direct {v4}, Ljava/lang/StringBuilder;-><init>()V

    const-string v5, "musicVolumeUser"

    invoke-virtual {v4, v5}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object v4

    sget v5, Lcom/thermasol/touchsteam2/GV;->ActiveUser:I

    invoke-virtual {v4, v5}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;

    move-result-object v4

    invoke-virtual {v4}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v4

    const/16 v5, 0xa

    .line 626
    invoke-interface {v2, v4, v5}, Landroid/content/SharedPreferences;->getInt(Ljava/lang/String;I)I

    move-result v4

    .line 625
    invoke-static {p0, v4}, Lcom/thermasol/touchsteam2/util/Utils;->setRoutedVolume(Landroid/content/Context;I)I

    .line 627
    new-instance v4, Ljava/lang/StringBuilder;

    invoke-direct {v4}, Ljava/lang/StringBuilder;-><init>()V

    const-string v5, "trebleVolumeUser"

    invoke-virtual {v4, v5}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object v4

    sget v5, Lcom/thermasol/touchsteam2/GV;->ActiveUser:I

    invoke-virtual {v4, v5}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;

    move-result-object v4

    invoke-virtual {v4}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v4

    .line 628
    invoke-static {}, Lcom/thermasol/touchsteam2/util/OverheadLight;->getDefaultTrebleVolume()I

    move-result v5

    invoke-interface {v2, v4, v5}, Landroid/content/SharedPreferences;->getInt(Ljava/lang/String;I)I

    move-result v4

    .line 627
    invoke-static {p0, v4}, Lcom/thermasol/touchsteam2/util/OverheadLight;->setTrebleVolume(Landroid/content/Context;I)V

    .line 629
    new-instance v4, Ljava/lang/StringBuilder;

    invoke-direct {v4}, Ljava/lang/StringBuilder;-><init>()V

    const-string v5, "midVolumeUser"

    invoke-virtual {v4, v5}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object v4

    sget v5, Lcom/thermasol/touchsteam2/GV;->ActiveUser:I

    invoke-virtual {v4, v5}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;

    move-result-object v4

    invoke-virtual {v4}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v4

    .line 630
    invoke-static {}, Lcom/thermasol/touchsteam2/util/OverheadLight;->getDefaultMidVolume()I

    move-result v5

    invoke-interface {v2, v4, v5}, Landroid/content/SharedPreferences;->getInt(Ljava/lang/String;I)I

    move-result v4

    .line 629
    invoke-static {p0, v4}, Lcom/thermasol/touchsteam2/util/OverheadLight;->setMidVolume(Landroid/content/Context;I)V

    .line 631
    new-instance v4, Ljava/lang/StringBuilder;

    invoke-direct {v4}, Ljava/lang/StringBuilder;-><init>()V

    const-string v5, "bassVolumeUser"

    invoke-virtual {v4, v5}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object v4

    sget v5, Lcom/thermasol/touchsteam2/GV;->ActiveUser:I

    invoke-virtual {v4, v5}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;

    move-result-object v4

    invoke-virtual {v4}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v4

    .line 632
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/OverheadLight;->getDefaultBassVolume(Landroid/content/Context;)I

    move-result v5

    invoke-interface {v2, v4, v5}, Landroid/content/SharedPreferences;->getInt(Ljava/lang/String;I)I

    move-result v4

    .line 631
    invoke-static {p0, v4}, Lcom/thermasol/touchsteam2/util/OverheadLight;->setBassVolume(Landroid/content/Context;I)V

    .line 634
    invoke-virtual {v1, p1}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->psb_set_load_user(I)V

    .line 635
    invoke-static {p0, p1}, Lcom/thermasol/touchsteam2/util/Utils;->loadSteamSettings(Landroid/content/Context;I)V

    .line 636
    invoke-static {p0, p1}, Lcom/thermasol/touchsteam2/util/Utils;->loadOverheadLightSettings(Landroid/content/Context;I)V

    const/4 p1, 0x1

    .line 638
    invoke-static {p0, p1}, Lcom/thermasol/touchsteam2/util/Utils;->toggleMusicAndSource(Landroid/content/Context;I)V

    .line 640
    invoke-virtual {v1}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->esv_get_is_dongle_present()Z

    move-result v4

    if-eqz v4, :cond_a9

    invoke-virtual {v1}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->esv_turn_off()V

    .line 641
    :cond_a9
    invoke-interface {v2}, Landroid/content/SharedPreferences;->edit()Landroid/content/SharedPreferences$Editor;

    move-result-object v2

    const/16 v4, 0x9

    const-string v5, "requestLayout"

    invoke-interface {v2, v5, v4}, Landroid/content/SharedPreferences$Editor;->putInt(Ljava/lang/String;I)Landroid/content/SharedPreferences$Editor;

    move-result-object v2

    invoke-interface {v2}, Landroid/content/SharedPreferences$Editor;->apply()V

    .line 645
    invoke-virtual {v1}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->get_current_room_temperature()I

    .line 646
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/Utils;->getHardwareRevision(Landroid/content/Context;)I

    move-result v2

    invoke-static {v2}, Ljava/lang/Integer;->valueOf(I)Ljava/lang/Integer;

    move-result-object v2

    const-string v4, "hardware"

    const-string v5, "hardware_revision"

    invoke-static {p0, v4, v5, v2}, Lcom/thermasol/touchsteam2/util/FirebaseAnalyticEvents;->logEvent(Landroid/content/Context;Ljava/lang/String;Ljava/lang/String;Ljava/lang/Number;)V

    .line 651
    :try_start_ca
    invoke-virtual {v1}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->getNative()Lcom/thermasol/thermatouchservice/IHardwareService;

    move-result-object v2

    invoke-interface {v2}, Lcom/thermasol/thermatouchservice/IHardwareService;->getEthernetIpValue()I

    move-result v2

    .line 652
    invoke-virtual {v1}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->getNative()Lcom/thermasol/thermatouchservice/IHardwareService;

    move-result-object v5

    const-string v6, "eth0"

    invoke-interface {v5, v6}, Lcom/thermasol/thermatouchservice/IHardwareService;->networkInterfaceIsUp(Ljava/lang/String;)Z

    move-result v5

    if-eqz v5, :cond_e2

    if-eqz v2, :cond_e2

    move v2, p1

    goto :goto_e3

    :cond_e2
    move v2, v3

    :goto_e3
    const-string v5, "ethernet"

    if-eqz v2, :cond_e9

    move v2, p1

    goto :goto_ea

    :cond_e9
    move v2, v3

    .line 653
    :goto_ea
    invoke-static {v2}, Ljava/lang/Integer;->valueOf(I)Ljava/lang/Integer;

    move-result-object v2

    invoke-static {p0, v4, v5, v2}, Lcom/thermasol/touchsteam2/util/FirebaseAnalyticEvents;->logEvent(Landroid/content/Context;Ljava/lang/String;Ljava/lang/String;Ljava/lang/Number;)V

    .line 654
    invoke-virtual {p0, v0}, Landroid/content/Context;->getSystemService(Ljava/lang/String;)Ljava/lang/Object;

    move-result-object v2

    check-cast v2, Landroid/net/wifi/WifiManager;

    .line 655
    invoke-virtual {v2}, Landroid/net/wifi/WifiManager;->getConnectionInfo()Landroid/net/wifi/WifiInfo;

    move-result-object v2

    invoke-virtual {v2}, Landroid/net/wifi/WifiInfo;->getIpAddress()I

    move-result v2

    .line 656
    invoke-virtual {v1}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->getNative()Lcom/thermasol/thermatouchservice/IHardwareService;

    move-result-object v1

    const-string v5, "wlan0"

    invoke-interface {v1, v5}, Lcom/thermasol/thermatouchservice/IHardwareService;->networkInterfaceIsUp(Ljava/lang/String;)Z

    move-result v1

    if-eqz v1, :cond_10f

    if-eqz v2, :cond_10f

    move v1, p1

    goto :goto_110

    :cond_10f
    move v1, v3

    :goto_110
    if-eqz v1, :cond_113

    move v3, p1

    .line 657
    :cond_113
    invoke-static {v3}, Ljava/lang/Integer;->valueOf(I)Ljava/lang/Integer;

    move-result-object p1

    invoke-static {p0, v4, v0, p1}, Lcom/thermasol/touchsteam2/util/FirebaseAnalyticEvents;->logEvent(Landroid/content/Context;Ljava/lang/String;Ljava/lang/String;Ljava/lang/Number;)V
    :try_end_11a
    .catch Ljava/lang/Exception; {:try_start_ca .. :try_end_11a} :catch_11b

    goto :goto_11f

    :catch_11b
    move-exception p0

    .line 658
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/Utils;->handleException(Ljava/lang/Exception;)V

    :goto_11f
    return-void
.end method

.method public static loadVoiceVolumeSettings(Landroid/content/Context;I)V
    .registers 5
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0,
            0x0
        }
        names = {
            "context",
            "user"
        }
    .end annotation

    .line 690
    move-object v0, p0

    check-cast v0, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;

    invoke-interface {v0}, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;->getInstance()Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;

    move-result-object v0

    .line 691
    invoke-static {p0}, Landroidx/preference/PreferenceManager;->getDefaultSharedPreferences(Landroid/content/Context;)Landroid/content/SharedPreferences;

    move-result-object p0

    .line 693
    invoke-static {v0}, Lcom/thermasol/touchsteam2/util/OverheadLight;->getType(Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;)Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;

    move-result-object v1

    .line 694
    sget-object v2, Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;->SLSR_AUX:Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;

    if-eq v1, v2, :cond_17

    sget-object v2, Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;->SLSR_BLUETOOTH:Lcom/thermasol/touchsteam2/util/OverheadLight$LightType;

    if-ne v1, v2, :cond_58

    .line 696
    :cond_17
    invoke-virtual {v0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->slsr_voice_mute()V

    .line 697
    new-instance v1, Ljava/lang/StringBuilder;

    invoke-direct {v1}, Ljava/lang/StringBuilder;-><init>()V

    const-string v2, "voiceVolumeUser"

    invoke-virtual {v1, v2}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object v1

    invoke-virtual {v1, p1}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;

    move-result-object v1

    invoke-virtual {v1}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v1

    const/16 v2, 0xa

    invoke-interface {p0, v1, v2}, Landroid/content/SharedPreferences;->getInt(Ljava/lang/String;I)I

    move-result v1

    invoke-virtual {v0, v1}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->slsr_set_voice_volume(I)V

    .line 698
    new-instance v1, Ljava/lang/StringBuilder;

    invoke-direct {v1}, Ljava/lang/StringBuilder;-><init>()V

    const-string v2, "voiceStateUser"

    invoke-virtual {v1, v2}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object v1

    invoke-virtual {v1, p1}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;

    move-result-object p1

    invoke-virtual {p1}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object p1

    const/4 v1, 0x0

    invoke-interface {p0, p1, v1}, Landroid/content/SharedPreferences;->getInt(Ljava/lang/String;I)I

    move-result p0

    const/4 p1, 0x1

    if-ne p0, p1, :cond_52

    move v1, p1

    :cond_52
    invoke-virtual {v0, v1}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->slsr_voice_on_off(Z)V

    .line 699
    invoke-virtual {v0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->slsr_voice_unmute()V

    :cond_58
    return-void
.end method

.method public static parseServerResponse(Landroid/content/Context;Ljava/io/File;Z)Ljava/util/List;
    .registers 9
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0,
            0x0,
            0x0
        }
        names = {
            "context",
            "index",
            "filter"
        }
    .end annotation

    .annotation system Ldalvik/annotation/Signature;
        value = {
            "(",
            "Landroid/content/Context;",
            "Ljava/io/File;",
            "Z)",
            "Ljava/util/List<",
            "Lcom/thermasol/utils/AppDetail;",
            ">;"
        }
    .end annotation

    .annotation system Ldalvik/annotation/Throws;
        value = {
            Ljava/io/IOException;
        }
    .end annotation

    .line 812
    new-instance v0, Ljava/io/FileInputStream;

    invoke-direct {v0, p1}, Ljava/io/FileInputStream;-><init>(Ljava/io/File;)V

    .line 813
    new-instance p1, Ljava/io/BufferedReader;

    new-instance v1, Ljava/io/InputStreamReader;

    invoke-direct {v1, v0}, Ljava/io/InputStreamReader;-><init>(Ljava/io/InputStream;)V

    invoke-direct {p1, v1}, Ljava/io/BufferedReader;-><init>(Ljava/io/Reader;)V

    .line 814
    invoke-static {p1}, Lcom/thermasol/utils/Utility;->buildAppsServerResponse(Ljava/io/BufferedReader;)Lcom/thermasol/utils/ServerResponse;

    move-result-object p1

    invoke-virtual {p1}, Lcom/thermasol/utils/ServerResponse;->getAppDetails()Ljava/util/List;

    move-result-object p1

    .line 815
    new-instance v0, Ljava/util/ArrayList;

    invoke-direct {v0}, Ljava/util/ArrayList;-><init>()V

    const/4 v1, 0x0

    move v2, v1

    .line 817
    :goto_1e
    invoke-interface {p1}, Ljava/util/List;->size()I

    move-result v3

    if-ge v2, v3, :cond_47

    .line 818
    invoke-interface {p1, v2}, Ljava/util/List;->get(I)Ljava/lang/Object;

    move-result-object v3

    check-cast v3, Lcom/thermasol/utils/AppDetail;

    .line 819
    invoke-static {v3}, Lcom/thermasol/utils/Utility;->internalApp(Lcom/thermasol/utils/AppDetail;)Z

    move-result v4

    if-eqz v4, :cond_33

    .line 820
    invoke-virtual {v0, v3}, Ljava/util/ArrayList;->add(Ljava/lang/Object;)Z

    .line 823
    :cond_33
    :try_start_33
    invoke-virtual {p0}, Landroid/content/Context;->getPackageManager()Landroid/content/pm/PackageManager;

    move-result-object v4

    invoke-virtual {v3}, Lcom/thermasol/utils/AppDetail;->getPackageName()Ljava/lang/String;

    move-result-object v5

    invoke-virtual {v4, v5, v1}, Landroid/content/pm/PackageManager;->getApplicationInfo(Ljava/lang/String;I)Landroid/content/pm/ApplicationInfo;
    :try_end_3e
    .catch Landroid/content/pm/PackageManager$NameNotFoundException; {:try_start_33 .. :try_end_3e} :catch_3f

    goto :goto_44

    :catch_3f
    if-eqz p2, :cond_44

    .line 826
    invoke-virtual {v0, v3}, Ljava/util/ArrayList;->add(Ljava/lang/Object;)Z

    :cond_44
    :goto_44
    add-int/lit8 v2, v2, 0x1

    goto :goto_1e

    .line 830
    :cond_47
    invoke-interface {p1, v0}, Ljava/util/List;->removeAll(Ljava/util/Collection;)Z

    return-object p1
.end method

.method public static playVideo(Lcom/thermasol/touchsteam2/activities/MainControl;Ljava/lang/String;Ljava/lang/String;Z)V
    .registers 10
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0,
            0x0,
            0x0,
            0x0
        }
        names = {
            "activity",
            "videoPath",
            "videoName",
            "demo"
        }
    .end annotation

    .line 117
    new-instance v0, Ljava/lang/StringBuilder;

    invoke-direct {v0}, Ljava/lang/StringBuilder;-><init>()V

    invoke-virtual {v0, p1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object p1

    const-string v0, "/"

    invoke-virtual {p1, v0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object p1

    invoke-virtual {p1, p2}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object p1

    invoke-virtual {p1}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object p1

    .line 118
    new-instance v1, Ljava/io/File;

    invoke-direct {v1, p1}, Ljava/io/File;-><init>(Ljava/lang/String;)V

    .line 122
    invoke-virtual {p2}, Ljava/lang/String;->hashCode()I

    invoke-virtual {p2}, Ljava/lang/String;->hashCode()I

    move-result v2

    const/4 v3, 0x1

    const/4 v4, 0x0

    const/4 v5, -0x1

    sparse-switch v2, :sswitch_data_f0

    goto/16 :goto_90

    :sswitch_2b
    const-string v2, "smoke_indigo.mp4"

    invoke-virtual {p2, v2}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z

    move-result p2

    if-nez p2, :cond_35

    goto/16 :goto_90

    :cond_35
    const/16 v5, 0x8

    goto/16 :goto_90

    :sswitch_39
    const-string v2, "smoke_red.mp4"

    invoke-virtual {p2, v2}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z

    move-result p2

    if-nez p2, :cond_42

    goto :goto_90

    :cond_42
    const/4 v5, 0x7

    goto :goto_90

    :sswitch_44
    const-string v2, "smoke_yellow.mp4"

    invoke-virtual {p2, v2}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z

    move-result p2

    if-nez p2, :cond_4d

    goto :goto_90

    :cond_4d
    const/4 v5, 0x6

    goto :goto_90

    :sswitch_4f
    const-string v2, "smoke_orange.mp4"

    invoke-virtual {p2, v2}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z

    move-result p2

    if-nez p2, :cond_58

    goto :goto_90

    :cond_58
    const/4 v5, 0x5

    goto :goto_90

    :sswitch_5a
    const-string v2, "mood_video.mp4"

    invoke-virtual {p2, v2}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z

    move-result p2

    if-nez p2, :cond_63

    goto :goto_90

    :cond_63
    const/4 v5, 0x4

    goto :goto_90

    :sswitch_65
    const-string v2, "smoke_green.mp4"

    invoke-virtual {p2, v2}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z

    move-result p2

    if-nez p2, :cond_6e

    goto :goto_90

    :cond_6e
    const/4 v5, 0x3

    goto :goto_90

    :sswitch_70
    const-string v2, ""

    invoke-virtual {p2, v2}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z

    move-result p2

    if-nez p2, :cond_79

    goto :goto_90

    :cond_79
    const/4 v5, 0x2

    goto :goto_90

    :sswitch_7b
    const-string v2, "smoke_violet.mp4"

    invoke-virtual {p2, v2}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z

    move-result p2

    if-nez p2, :cond_84

    goto :goto_90

    :cond_84
    move v5, v3

    goto :goto_90

    :sswitch_86
    const-string v2, "smoke_blue.mp4"

    invoke-virtual {p2, v2}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z

    move-result p2

    if-nez p2, :cond_8f

    goto :goto_90

    :cond_8f
    move v5, v4

    :goto_90
    const/high16 p2, 0x3f800000    # 1.0f

    packed-switch v5, :pswitch_data_116

    goto :goto_9a

    :pswitch_96
    const p2, 0x3eaaa64c    # 0.3333f

    :pswitch_99
    move v3, v4

    :goto_9a
    if-eqz v3, :cond_9f

    .line 139
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/Utils;->PersistPauseAndKillBluetooth(Landroid/content/Context;)V

    .line 142
    :cond_9f
    new-instance v2, Landroid/content/Intent;

    const-class v3, Lcom/thermasol/touchsteam2/activities/VideoPlayerActivity;

    invoke-direct {v2, p0, v3}, Landroid/content/Intent;-><init>(Landroid/content/Context;Ljava/lang/Class;)V

    .line 143
    invoke-virtual {v1}, Ljava/io/File;->exists()Z

    move-result v1

    if-eqz v1, :cond_b4

    .line 144
    invoke-static {p1}, Landroid/net/Uri;->parse(Ljava/lang/String;)Landroid/net/Uri;

    move-result-object p1

    invoke-virtual {v2, p1}, Landroid/content/Intent;->setData(Landroid/net/Uri;)Landroid/content/Intent;

    goto :goto_dd

    .line 146
    :cond_b4
    new-instance p1, Ljava/lang/StringBuilder;

    invoke-direct {p1}, Ljava/lang/StringBuilder;-><init>()V

    const-string v1, "android.resource://"

    invoke-virtual {p1, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object p1

    invoke-virtual {p0}, Lcom/thermasol/touchsteam2/activities/MainControl;->getPackageName()Ljava/lang/String;

    move-result-object v1

    invoke-virtual {p1, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object p1

    invoke-virtual {p1, v0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object p1

    const v0, 0x7f100002

    invoke-virtual {p1, v0}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;

    move-result-object p1

    invoke-virtual {p1}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object p1

    invoke-static {p1}, Landroid/net/Uri;->parse(Ljava/lang/String;)Landroid/net/Uri;

    move-result-object p1

    invoke-virtual {v2, p1}, Landroid/content/Intent;->setData(Landroid/net/Uri;)Landroid/content/Intent;

    :goto_dd
    const-string p1, "demo"

    .line 148
    invoke-virtual {v2, p1, p3}, Landroid/content/Intent;->putExtra(Ljava/lang/String;Z)Landroid/content/Intent;

    const-string p1, "speed"

    .line 149
    invoke-virtual {v2, p1, p2}, Landroid/content/Intent;->putExtra(Ljava/lang/String;F)Landroid/content/Intent;

    .line 150
    invoke-virtual {p0}, Lcom/thermasol/touchsteam2/activities/MainControl;->getLauncher()Landroidx/activity/result/ActivityResultLauncher;

    move-result-object p0

    invoke-virtual {p0, v2}, Landroidx/activity/result/ActivityResultLauncher;->launch(Ljava/lang/Object;)V

    return-void

    nop

    :sswitch_data_f0
    .sparse-switch
        -0x20f767d3 -> :sswitch_86
        -0x6a8922e -> :sswitch_7b
        0x0 -> :sswitch_70
        0xbad2ab6 -> :sswitch_65
        0xc3e1bb6 -> :sswitch_5a
        0x3fcf9001 -> :sswitch_4f
        0x5eb93b47 -> :sswitch_44
        0x61622944 -> :sswitch_39
        0x64b676a5 -> :sswitch_2b
    .end sparse-switch

    :pswitch_data_116
    .packed-switch 0x0
        :pswitch_99
        :pswitch_99
        :pswitch_99
        :pswitch_99
        :pswitch_96
        :pswitch_99
        :pswitch_99
        :pswitch_99
        :pswitch_99
    .end packed-switch
.end method

.method public static promptUninstall(Landroid/content/Context;Ljava/lang/String;)V
    .registers 4
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0,
            0x0
        }
        names = {
            "context",
            "packageName"
        }
    .end annotation

    .line 874
    new-instance v0, Ljava/lang/StringBuilder;

    invoke-direct {v0}, Ljava/lang/StringBuilder;-><init>()V

    const-string v1, "package:"

    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object v0

    invoke-virtual {v0, p1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object p1

    invoke-virtual {p1}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object p1

    .line 875
    new-instance v0, Landroid/content/Intent;

    invoke-static {p1}, Landroid/net/Uri;->parse(Ljava/lang/String;)Landroid/net/Uri;

    move-result-object p1

    const-string v1, "android.intent.action.DELETE"

    invoke-direct {v0, v1, p1}, Landroid/content/Intent;-><init>(Ljava/lang/String;Landroid/net/Uri;)V

    .line 876
    invoke-virtual {p0, v0}, Landroid/content/Context;->startActivity(Landroid/content/Intent;)V

    return-void
.end method

.method public static putSteamBasedSetting(Landroid/content/Context;Ljava/lang/String;Ljava/lang/Object;Ljava/lang/Class;Z)V
    .registers 7
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0,
            0x0,
            0x0,
            0x0,
            0x0
        }
        names = {
            "context",
            "key",
            "value",
            "type",
            "commit"
        }
    .end annotation

    .annotation system Ldalvik/annotation/Signature;
        value = {
            "(",
            "Landroid/content/Context;",
            "Ljava/lang/String;",
            "Ljava/lang/Object;",
            "Ljava/lang/Class<",
            "*>;Z)V"
        }
    .end annotation

    .line 540
    invoke-static {p0}, Landroidx/preference/PreferenceManager;->getDefaultSharedPreferences(Landroid/content/Context;)Landroid/content/SharedPreferences;

    move-result-object v0

    .line 541
    invoke-interface {v0}, Landroid/content/SharedPreferences;->edit()Landroid/content/SharedPreferences$Editor;

    move-result-object v0

    .line 543
    check-cast p0, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;

    invoke-interface {p0}, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;->getInstance()Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;

    move-result-object p0

    .line 544
    invoke-static {p0, p1}, Lcom/thermasol/touchsteam2/util/Utils;->buildSteamPreferenceKey(Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;Ljava/lang/String;)Ljava/lang/String;

    move-result-object p0

    .line 545
    invoke-virtual {p3}, Ljava/lang/Class;->toString()Ljava/lang/String;

    move-result-object p1

    invoke-virtual {p1}, Ljava/lang/String;->hashCode()I

    const-string v1, "int"

    invoke-virtual {p1, v1}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z

    move-result v1

    if-nez v1, :cond_4c

    const-string v1, "class java.lang.String"

    invoke-virtual {p1, v1}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z

    move-result p1

    if-nez p1, :cond_33

    .line 553
    invoke-virtual {p3}, Ljava/lang/Class;->toString()Ljava/lang/String;

    move-result-object p0

    const-string p1, "DEBUG_TYPE_DEF"

    invoke-static {p1, p0}, Landroid/util/Log;->v(Ljava/lang/String;Ljava/lang/String;)I

    goto :goto_68

    .line 550
    :cond_33
    new-instance p1, Ljava/lang/StringBuilder;

    invoke-direct {p1}, Ljava/lang/StringBuilder;-><init>()V

    invoke-virtual {p1, p0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object p0

    sget p1, Lcom/thermasol/touchsteam2/GV;->ActiveUser:I

    invoke-virtual {p0, p1}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;

    move-result-object p0

    invoke-virtual {p0}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object p0

    check-cast p2, Ljava/lang/String;

    invoke-interface {v0, p0, p2}, Landroid/content/SharedPreferences$Editor;->putString(Ljava/lang/String;Ljava/lang/String;)Landroid/content/SharedPreferences$Editor;

    goto :goto_68

    .line 547
    :cond_4c
    new-instance p1, Ljava/lang/StringBuilder;

    invoke-direct {p1}, Ljava/lang/StringBuilder;-><init>()V

    invoke-virtual {p1, p0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object p0

    sget p1, Lcom/thermasol/touchsteam2/GV;->ActiveUser:I

    invoke-virtual {p0, p1}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;

    move-result-object p0

    invoke-virtual {p0}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object p0

    check-cast p2, Ljava/lang/Integer;

    invoke-virtual {p2}, Ljava/lang/Integer;->intValue()I

    move-result p1

    invoke-interface {v0, p0, p1}, Landroid/content/SharedPreferences$Editor;->putInt(Ljava/lang/String;I)Landroid/content/SharedPreferences$Editor;

    :goto_68
    if-eqz p4, :cond_6e

    .line 558
    invoke-interface {v0}, Landroid/content/SharedPreferences$Editor;->commit()Z

    goto :goto_71

    .line 560
    :cond_6e
    invoke-interface {v0}, Landroid/content/SharedPreferences$Editor;->apply()V

    :goto_71
    return-void
.end method

.method public static resetLightSettings(Landroid/content/Context;)V
    .registers 4
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0
        }
        names = {
            "context"
        }
    .end annotation

    .line 419
    move-object v0, p0

    check-cast v0, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;

    invoke-interface {v0}, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;->getInstance()Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;

    move-result-object v0

    .line 420
    invoke-static {}, Lcom/thermasol/touchsteam2/activities/MainControl;->getCurrentLayout()I

    move-result v1

    const/16 v2, 0x8

    if-eq v1, v2, :cond_1c

    .line 421
    new-instance v1, Ljava/lang/Thread;

    new-instance v2, Lcom/thermasol/touchsteam2/util/-$$Lambda$Utils$svB1OsIIsCG0YV8NsWcI7JhBei4;

    invoke-direct {v2, v0, p0}, Lcom/thermasol/touchsteam2/util/-$$Lambda$Utils$svB1OsIIsCG0YV8NsWcI7JhBei4;-><init>(Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;Landroid/content/Context;)V

    invoke-direct {v1, v2}, Ljava/lang/Thread;-><init>(Ljava/lang/Runnable;)V

    .line 427
    invoke-virtual {v1}, Ljava/lang/Thread;->start()V

    :cond_1c
    return-void
.end method

.method public static secondsToCountdown(I)Ljava/lang/String;
    .registers 5
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0
        }
        names = {
            "value"
        }
    .end annotation

    .line 1036
    sget-object v0, Ljava/util/concurrent/TimeUnit;->SECONDS:Ljava/util/concurrent/TimeUnit;

    int-to-long v1, p0

    invoke-virtual {v0, v1, v2}, Ljava/util/concurrent/TimeUnit;->toMinutes(J)J

    move-result-wide v0

    invoke-static {v0, v1}, Ljava/lang/Long;->valueOf(J)Ljava/lang/Long;

    move-result-object v0

    invoke-virtual {v0}, Ljava/lang/Long;->toString()Ljava/lang/String;

    move-result-object v0

    .line 1037
    invoke-virtual {v0}, Ljava/lang/String;->length()I

    move-result v1

    const-string v2, "0"

    const/4 v3, 0x1

    if-ne v1, v3, :cond_29

    .line 1038
    new-instance v1, Ljava/lang/StringBuilder;

    invoke-direct {v1}, Ljava/lang/StringBuilder;-><init>()V

    invoke-virtual {v1, v2}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object v1

    invoke-virtual {v1, v0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object v0

    invoke-virtual {v0}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v0

    .line 1041
    :cond_29
    rem-int/lit8 p0, p0, 0x3c

    invoke-static {p0}, Ljava/lang/Integer;->valueOf(I)Ljava/lang/Integer;

    move-result-object p0

    invoke-virtual {p0}, Ljava/lang/Integer;->toString()Ljava/lang/String;

    move-result-object p0

    .line 1042
    invoke-virtual {p0}, Ljava/lang/String;->length()I

    move-result v1

    if-ne v1, v3, :cond_4a

    .line 1043
    new-instance v1, Ljava/lang/StringBuilder;

    invoke-direct {v1}, Ljava/lang/StringBuilder;-><init>()V

    invoke-virtual {v1, v2}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object v1

    invoke-virtual {v1, p0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object p0

    invoke-virtual {p0}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object p0

    .line 1046
    :cond_4a
    new-instance v1, Ljava/lang/StringBuilder;

    invoke-direct {v1}, Ljava/lang/StringBuilder;-><init>()V

    invoke-virtual {v1, v0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object v0

    const-string v1, ":"

    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object v0

    invoke-virtual {v0, p0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object p0

    invoke-virtual {p0}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object p0

    return-object p0
.end method

.method public static sendLinuxCommand(Ljava/lang/String;)Lcom/thermasol/touchsteam2/util/Utils$ExecutionResult;
    .registers 6
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0
        }
        names = {
            "command"
        }
    .end annotation

    .line 71
    new-instance v0, Lcom/thermasol/touchsteam2/util/Utils$ExecutionResult;

    invoke-direct {v0}, Lcom/thermasol/touchsteam2/util/Utils$ExecutionResult;-><init>()V

    .line 73
    :try_start_5
    invoke-static {}, Ljava/lang/Runtime;->getRuntime()Ljava/lang/Runtime;

    move-result-object v1

    invoke-virtual {v1, p0}, Ljava/lang/Runtime;->exec(Ljava/lang/String;)Ljava/lang/Process;

    move-result-object v1

    if-eqz v1, :cond_47

    .line 75
    invoke-virtual {v1}, Ljava/lang/Process;->waitFor()I

    move-result v2

    # setter for: Lcom/thermasol/touchsteam2/util/Utils$ExecutionResult;->mResult:I
    invoke-static {v0, v2}, Lcom/thermasol/touchsteam2/util/Utils$ExecutionResult;->access$002(Lcom/thermasol/touchsteam2/util/Utils$ExecutionResult;I)I

    .line 76
    new-instance v2, Ljava/io/BufferedReader;

    new-instance v3, Ljava/io/InputStreamReader;

    invoke-virtual {v1}, Ljava/lang/Process;->getInputStream()Ljava/io/InputStream;

    move-result-object v4

    invoke-direct {v3, v4}, Ljava/io/InputStreamReader;-><init>(Ljava/io/InputStream;)V

    invoke-direct {v2, v3}, Ljava/io/BufferedReader;-><init>(Ljava/io/Reader;)V

    .line 77
    invoke-virtual {v2}, Ljava/io/BufferedReader;->readLine()Ljava/lang/String;

    move-result-object v3

    .line 78
    invoke-static {v0, v3}, Lcom/thermasol/touchsteam2/util/Utils$ExecutionResult;->access$184(Lcom/thermasol/touchsteam2/util/Utils$ExecutionResult;Ljava/lang/Object;)Ljava/lang/String;

    .line 79
    invoke-virtual {v2}, Ljava/io/BufferedReader;->close()V

    .line 80
    invoke-virtual {v1}, Ljava/lang/Process;->destroy()V
    :try_end_31
    .catch Ljava/io/IOException; {:try_start_5 .. :try_end_31} :catch_37
    .catch Ljava/lang/Exception; {:try_start_5 .. :try_end_31} :catch_32

    goto :goto_47

    :catch_32
    move-exception p0

    .line 88
    invoke-virtual {p0}, Ljava/lang/Exception;->printStackTrace()V

    goto :goto_47

    :catch_37
    move-exception v1

    .line 83
    invoke-virtual {v1}, Ljava/io/IOException;->toString()Ljava/lang/String;

    move-result-object v1

    const-string v2, "Try again"

    invoke-virtual {v1, v2}, Ljava/lang/String;->contains(Ljava/lang/CharSequence;)Z

    move-result v1

    if-eqz v1, :cond_47

    .line 85
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/Utils;->sendLinuxCommand(Ljava/lang/String;)Lcom/thermasol/touchsteam2/util/Utils$ExecutionResult;

    :cond_47
    :goto_47
    return-object v0
.end method

.method public static setA2dpDirection(Landroid/content/Context;Z)V
    .registers 6
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0,
            0x0
        }
        names = {
            "context",
            "shouldSink"
        }
    .end annotation

    .line 883
    sget-object v0, Landroid/os/Build;->DEVICE:Ljava/lang/String;

    invoke-static {v0}, Lcom/thermasol/utils/Utility;->knownDevice(Ljava/lang/String;)Z

    move-result v0

    if-nez v0, :cond_9

    return-void

    .line 885
    :cond_9
    new-instance v0, Landroid/content/Intent;

    invoke-direct {v0}, Landroid/content/Intent;-><init>()V

    .line 886
    new-instance v1, Landroid/content/ComponentName;

    const-string v2, "com.android.bluetooth"

    const-string v3, "com.android.bluetooth.a2dp.A2dpEnablingActivity"

    invoke-direct {v1, v2, v3}, Landroid/content/ComponentName;-><init>(Ljava/lang/String;Ljava/lang/String;)V

    invoke-virtual {v0, v1}, Landroid/content/Intent;->setComponent(Landroid/content/ComponentName;)Landroid/content/Intent;

    const-string v1, "sink_bt_audio"

    .line 890
    invoke-virtual {v0, v1, p1}, Landroid/content/Intent;->putExtra(Ljava/lang/String;Z)Landroid/content/Intent;

    .line 891
    invoke-virtual {p0, v0}, Landroid/content/Context;->startActivity(Landroid/content/Intent;)V

    return-void
.end method

.method public static setAndroidVolume(Landroid/content/Context;I)V
    .registers 6
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0,
            0x0
        }
        names = {
            "context",
            "volume"
        }
    .end annotation

    const-string v0, "audio"

    .line 973
    invoke-virtual {p0, v0}, Landroid/content/Context;->getSystemService(Ljava/lang/String;)Ljava/lang/Object;

    move-result-object v0

    check-cast v0, Landroid/media/AudioManager;

    .line 974
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/Utils;->getAndroidVolumeInterval(Landroid/content/Context;)I

    move-result v1

    mul-int/2addr v1, p1

    const/4 v2, 0x3

    const/4 v3, 0x0

    .line 975
    invoke-virtual {v0, v2, v1, v3}, Landroid/media/AudioManager;->setStreamVolume(III)V

    .line 977
    invoke-static {p0}, Landroidx/preference/PreferenceManager;->getDefaultSharedPreferences(Landroid/content/Context;)Landroid/content/SharedPreferences;

    move-result-object p0

    .line 978
    invoke-interface {p0}, Landroid/content/SharedPreferences;->edit()Landroid/content/SharedPreferences$Editor;

    move-result-object p0

    new-instance v0, Ljava/lang/StringBuilder;

    invoke-direct {v0}, Ljava/lang/StringBuilder;-><init>()V

    const-string v1, "musicVolumeUser"

    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object v0

    sget v1, Lcom/thermasol/touchsteam2/GV;->ActiveUser:I

    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;

    move-result-object v0

    invoke-virtual {v0}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v0

    invoke-interface {p0, v0, p1}, Landroid/content/SharedPreferences$Editor;->putInt(Ljava/lang/String;I)Landroid/content/SharedPreferences$Editor;

    move-result-object p0

    invoke-interface {p0}, Landroid/content/SharedPreferences$Editor;->apply()V

    return-void
.end method

.method private static setMusicSource(Landroid/content/Context;I)V
    .registers 5
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0,
            0x0
        }
        names = {
            "context",
            "requested"
        }
    .end annotation

    .line 579
    move-object v0, p0

    check-cast v0, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;

    invoke-interface {v0}, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;->getInstance()Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;

    move-result-object v0

    .line 580
    invoke-static {v0}, Lcom/thermasol/touchsteam2/util/OverheadLight;->hasBluetoothCapability(Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;)Z

    move-result v0

    const/4 v1, 0x2

    const/4 v2, 0x1

    if-eqz v0, :cond_17

    if-eq p1, v2, :cond_16

    if-eq p1, v1, :cond_14

    goto :goto_17

    :cond_14
    move p1, v2

    goto :goto_17

    :cond_16
    move p1, v1

    .line 591
    :cond_17
    :goto_17
    invoke-static {p0, p1}, Lcom/thermasol/touchsteam2/util/OverheadLight;->setSource(Landroid/content/Context;I)V

    return-void
.end method

.method public static setRecoveryTimerSetpointForActiveUser(Landroid/content/Context;I)V
    .registers 4
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0,
            0x0
        }
        names = {
            "context",
            "setpoint"
        }
    .end annotation

    .line 741
    invoke-static {p0}, Landroidx/preference/PreferenceManager;->getDefaultSharedPreferences(Landroid/content/Context;)Landroid/content/SharedPreferences;

    move-result-object p0

    invoke-interface {p0}, Landroid/content/SharedPreferences;->edit()Landroid/content/SharedPreferences$Editor;

    move-result-object p0

    .line 742
    new-instance v0, Ljava/lang/StringBuilder;

    invoke-direct {v0}, Ljava/lang/StringBuilder;-><init>()V

    const-string v1, "userTimerSetpoint"

    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object v0

    sget v1, Lcom/thermasol/touchsteam2/GV;->ActiveUser:I

    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;

    move-result-object v0

    invoke-virtual {v0}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v0

    invoke-interface {p0, v0, p1}, Landroid/content/SharedPreferences$Editor;->putInt(Ljava/lang/String;I)Landroid/content/SharedPreferences$Editor;

    .line 743
    invoke-interface {p0}, Landroid/content/SharedPreferences$Editor;->apply()V

    return-void
.end method

.method public static setRoutedVolume(Landroid/content/Context;I)I
    .registers 5
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0,
            0x0
        }
        names = {
            "context",
            "volume"
        }
    .end annotation

    const/4 v0, 0x0

    const/16 v1, 0xf

    .line 950
    invoke-static {p1, v0, v1}, Lcom/thermasol/touchsteam2/util/Utils;->BoundsCheck(III)I

    move-result p1

    .line 951
    invoke-static {p0}, Landroidx/preference/PreferenceManager;->getDefaultSharedPreferences(Landroid/content/Context;)Landroid/content/SharedPreferences;

    move-result-object v1

    const-string v2, "simulated"

    .line 952
    invoke-interface {v1, v2, v0}, Landroid/content/SharedPreferences;->getBoolean(Ljava/lang/String;Z)Z

    move-result v1

    .line 956
    :try_start_11
    move-object v2, p0

    check-cast v2, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;

    invoke-interface {v2}, Lcom/thermasol/touchsteam2/shared/IHardwareTouchingContext;->getInstance()Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;

    move-result-object v2

    invoke-virtual {v2}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->getNative()Lcom/thermasol/thermatouchservice/IHardwareService;

    move-result-object v2

    .line 957
    check-cast v2, Lcom/thermasol/touchsteam2/services/SimulatedHardwareService;

    .line 958
    invoke-virtual {v2}, Lcom/thermasol/touchsteam2/services/SimulatedHardwareService;->lightConnected()Z

    move-result v0
    :try_end_22
    .catch Ljava/lang/Exception; {:try_start_11 .. :try_end_22} :catch_23

    goto :goto_27

    :catch_23
    move-exception v2

    .line 959
    invoke-static {v2}, Lcom/thermasol/touchsteam2/util/Utils;->handleException(Ljava/lang/Exception;)V

    :goto_27
    if-nez v0, :cond_36

    if-nez v1, :cond_32

    .line 961
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/OverheadLight;->isActive(Landroid/content/Context;)Z

    move-result v0

    if-eqz v0, :cond_32

    goto :goto_36

    .line 964
    :cond_32
    invoke-static {p0, p1}, Lcom/thermasol/touchsteam2/util/Utils;->setAndroidVolume(Landroid/content/Context;I)V

    goto :goto_39

    .line 962
    :cond_36
    :goto_36
    invoke-static {p0, p1}, Lcom/thermasol/touchsteam2/util/OverheadLight;->setMasterVolume(Landroid/content/Context;I)V

    :goto_39
    return p1
.end method

.method public static setupAppInstallPermissions(Landroid/app/Activity;)V
    .registers 4
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0
        }
        names = {
            "activity"
        }
    .end annotation

    .line 899
    new-instance v0, Landroid/content/Intent;

    invoke-direct {v0}, Landroid/content/Intent;-><init>()V

    const-string v1, "android.settings.MANAGE_UNKNOWN_APP_SOURCES"

    .line 900
    invoke-virtual {v0, v1}, Landroid/content/Intent;->setAction(Ljava/lang/String;)Landroid/content/Intent;

    .line 901
    new-instance v1, Ljava/lang/StringBuilder;

    invoke-direct {v1}, Ljava/lang/StringBuilder;-><init>()V

    const-string v2, "package:"

    invoke-virtual {v1, v2}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object v1

    invoke-virtual {p0}, Landroid/app/Activity;->getPackageName()Ljava/lang/String;

    move-result-object v2

    invoke-virtual {v1, v2}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object v1

    invoke-virtual {v1}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v1

    invoke-static {v1}, Landroid/net/Uri;->parse(Ljava/lang/String;)Landroid/net/Uri;

    move-result-object v1

    .line 902
    invoke-virtual {v0, v1}, Landroid/content/Intent;->setData(Landroid/net/Uri;)Landroid/content/Intent;

    const/4 v1, 0x1

    .line 904
    :try_start_29
    invoke-virtual {p0, v0, v1}, Landroid/app/Activity;->startActivityForResult(Landroid/content/Intent;I)V
    :try_end_2c
    .catch Ljava/lang/Exception; {:try_start_29 .. :try_end_2c} :catch_2d

    goto :goto_31

    :catch_2d
    move-exception p0

    .line 905
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/Utils;->handleException(Ljava/lang/Exception;)V

    :goto_31
    return-void
.end method

.method public static shouldAttachSecondaryService(Landroid/content/Context;)Z
    .registers 3
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0
        }
        names = {
            "context"
        }
    .end annotation

    .line 919
    invoke-static {p0}, Landroidx/preference/PreferenceManager;->getDefaultSharedPreferences(Landroid/content/Context;)Landroid/content/SharedPreferences;

    move-result-object p0

    .line 920
    sget-object v0, Landroid/os/Build;->DEVICE:Ljava/lang/String;

    invoke-static {v0}, Lcom/thermasol/utils/Utility;->knownDevice(Ljava/lang/String;)Z

    move-result v0

    const/4 v1, 0x0

    if-eqz v0, :cond_16

    const-string v0, "simulated"

    .line 921
    invoke-interface {p0, v0, v1}, Landroid/content/SharedPreferences;->getBoolean(Ljava/lang/String;Z)Z

    move-result p0

    if-eqz p0, :cond_16

    const/4 v1, 0x1

    :cond_16
    return v1
.end method

.method public static toggleMusicAndSource(Landroid/content/Context;I)V
    .registers 6
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0,
            0x0
        }
        names = {
            "context",
            "source"
        }
    .end annotation

    .line 596
    invoke-static {p0}, Landroidx/preference/PreferenceManager;->getDefaultSharedPreferences(Landroid/content/Context;)Landroid/content/SharedPreferences;

    move-result-object v0

    .line 597
    new-instance v1, Ljava/lang/StringBuilder;

    invoke-direct {v1}, Ljava/lang/StringBuilder;-><init>()V

    const-string v2, "musicVolumeUser"

    invoke-virtual {v1, v2}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object v1

    sget v2, Lcom/thermasol/touchsteam2/GV;->ActiveUser:I

    invoke-virtual {v1, v2}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;

    move-result-object v1

    invoke-virtual {v1}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v1

    const/16 v2, 0xa

    invoke-interface {v0, v1, v2}, Landroid/content/SharedPreferences;->getInt(Ljava/lang/String;I)I

    move-result v1

    .line 598
    new-instance v2, Ljava/lang/StringBuilder;

    invoke-direct {v2}, Ljava/lang/StringBuilder;-><init>()V

    const-string v3, "musicSourceUser"

    invoke-virtual {v2, v3}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object v2

    sget v3, Lcom/thermasol/touchsteam2/GV;->ActiveUser:I

    invoke-virtual {v2, v3}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;

    move-result-object v2

    invoke-virtual {v2}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v2

    const/4 v3, 0x1

    invoke-interface {v0, v2, v3}, Landroid/content/SharedPreferences;->getInt(Ljava/lang/String;I)I

    move-result v0

    .line 599
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/OverheadLight;->mute(Landroid/content/Context;)V

    .line 600
    invoke-static {}, Lcom/thermasol/utils/Utility;->waitForHardwareReaction()V

    .line 601
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/OverheadLight;->unmute(Landroid/content/Context;)V

    if-eq v0, p1, :cond_4c

    if-ne p1, v3, :cond_4c

    .line 606
    invoke-static {p0, p1}, Lcom/thermasol/touchsteam2/util/Utils;->setMusicSource(Landroid/content/Context;I)V

    const/16 p1, 0x7d0

    goto :goto_50

    .line 611
    :cond_4c
    invoke-static {p0, p1}, Lcom/thermasol/touchsteam2/util/Utils;->setMusicSource(Landroid/content/Context;I)V

    const/4 p1, 0x0

    .line 614
    :goto_50
    invoke-static {p0, v1, p1}, Lcom/thermasol/touchsteam2/util/Utils;->delayMusicVolume(Landroid/content/Context;II)V

    return-void
.end method

.method public static toggleSteam(Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;Z)V
    .registers 4
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0,
            0x0
        }
        names = {
            "ThermaCan",
            "on"
        }
    .end annotation

    .line 725
    invoke-virtual {p0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->psb_get_state()I

    move-result v0

    const/4 v1, 0x2

    if-eqz p1, :cond_e

    if-ne v0, v1, :cond_a

    return-void

    .line 728
    :cond_a
    invoke-virtual {p0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->psb_turn_on_steam()V

    goto :goto_14

    :cond_e
    if-eq v0, v1, :cond_11

    return-void

    .line 731
    :cond_11
    invoke-virtual {p0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->psb_turn_off_steam()V

    .line 734
    :goto_14
    invoke-virtual {p0}, Lcom/thermasol/touchsteam2/comm/HardwareServicePersist;->psb_get_state()I

    move-result p1

    if-ne p1, v0, :cond_1e

    .line 735
    invoke-static {}, Lcom/thermasol/utils/Utility;->waitForHardwareReaction()V

    goto :goto_14

    :cond_1e
    return-void
.end method

.method public static trimUserName(Ljava/lang/String;)Ljava/lang/String;
    .registers 3
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0
        }
        names = {
            "name"
        }
    .end annotation

    .line 1020
    invoke-virtual {p0}, Ljava/lang/String;->length()I

    move-result v0

    const/16 v1, 0x9

    invoke-static {v0, v1}, Ljava/lang/Math;->min(II)I

    move-result v0

    const/4 v1, 0x0

    invoke-virtual {p0, v1, v0}, Ljava/lang/String;->substring(II)Ljava/lang/String;

    move-result-object p0

    return-object p0
.end method

.method public static updateAvailableAppData(Landroid/content/Context;)V
    .registers 10
    .annotation system Ldalvik/annotation/MethodParameters;
        accessFlags = {
            0x0
        }
        names = {
            "context"
        }
    .end annotation

    const-string v0, "index.json"

    .line 983
    invoke-static {v0}, Lcom/thermasol/touchsteam2/util/Utils;->getAppDetails(Ljava/lang/String;)Ljava/util/List;

    move-result-object v0

    .line 985
    new-instance v1, Ljava/util/ArrayList;

    invoke-direct {v1}, Ljava/util/ArrayList;-><init>()V

    const-string v2, "index-10.json"

    .line 986
    invoke-static {v2}, Lcom/thermasol/touchsteam2/util/Utils;->getAppDetails(Ljava/lang/String;)Ljava/util/List;

    move-result-object v2

    const/4 v3, 0x0

    move v4, v3

    .line 987
    :goto_13
    invoke-interface {v2}, Ljava/util/List;->size()I

    move-result v5

    if-ge v4, v5, :cond_43

    move v5, v3

    .line 988
    :goto_1a
    invoke-interface {v0}, Ljava/util/List;->size()I

    move-result v6

    if-ge v5, v6, :cond_40

    .line 989
    invoke-interface {v0, v5}, Ljava/util/List;->get(I)Ljava/lang/Object;

    move-result-object v6

    check-cast v6, Lcom/thermasol/utils/AppDetail;

    .line 990
    invoke-virtual {v6}, Lcom/thermasol/utils/AppDetail;->getPackageName()Ljava/lang/String;

    move-result-object v7

    invoke-interface {v2, v4}, Ljava/util/List;->get(I)Ljava/lang/Object;

    move-result-object v8

    check-cast v8, Lcom/thermasol/utils/AppDetail;

    invoke-virtual {v8}, Lcom/thermasol/utils/AppDetail;->getPackageName()Ljava/lang/String;

    move-result-object v8

    invoke-virtual {v7, v8}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z

    move-result v7

    if-eqz v7, :cond_3d

    .line 991
    invoke-interface {v1, v6}, Ljava/util/List;->add(Ljava/lang/Object;)Z

    :cond_3d
    add-int/lit8 v5, v5, 0x1

    goto :goto_1a

    :cond_40
    add-int/lit8 v4, v4, 0x1

    goto :goto_13

    .line 995
    :cond_43
    invoke-interface {v0, v1}, Ljava/util/List;->removeAll(Ljava/util/Collection;)Z

    .line 996
    invoke-interface {v0, v2}, Ljava/util/List;->addAll(Ljava/util/Collection;)Z

    .line 998
    new-instance v1, Lcom/google/gson/Gson;

    invoke-direct {v1}, Lcom/google/gson/Gson;-><init>()V

    .line 999
    new-instance v2, Lcom/thermasol/utils/ServerResponse;

    invoke-direct {v2}, Lcom/thermasol/utils/ServerResponse;-><init>()V

    .line 1000
    invoke-virtual {v2, v0}, Lcom/thermasol/utils/ServerResponse;->setAppDetails(Ljava/util/List;)V

    .line 1003
    :try_start_56
    new-instance v0, Ljava/io/File;

    sget-object v3, Landroid/os/Environment;->DIRECTORY_DOCUMENTS:Ljava/lang/String;

    invoke-virtual {p0, v3}, Landroid/content/Context;->getExternalFilesDir(Ljava/lang/String;)Ljava/io/File;

    move-result-object v3

    const-string v4, "combined.json"

    invoke-direct {v0, v3, v4}, Ljava/io/File;-><init>(Ljava/io/File;Ljava/lang/String;)V

    .line 1004
    new-instance v3, Ljava/io/BufferedWriter;

    new-instance v4, Ljava/io/FileWriter;

    invoke-virtual {v0}, Ljava/io/File;->toString()Ljava/lang/String;

    move-result-object v5

    invoke-direct {v4, v5}, Ljava/io/FileWriter;-><init>(Ljava/lang/String;)V

    invoke-direct {v3, v4}, Ljava/io/BufferedWriter;-><init>(Ljava/io/Writer;)V

    .line 1005
    invoke-virtual {v1, v2}, Lcom/google/gson/Gson;->toJson(Ljava/lang/Object;)Ljava/lang/String;

    move-result-object v1

    invoke-virtual {v3, v1}, Ljava/io/BufferedWriter;->write(Ljava/lang/String;)V

    .line 1006
    invoke-virtual {v3}, Ljava/io/BufferedWriter;->close()V

    .line 1008
    new-instance v1, Ljava/lang/StringBuilder;

    invoke-direct {v1}, Ljava/lang/StringBuilder;-><init>()V

    const-string v2, "mv "

    invoke-virtual {v1, v2}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object v1

    invoke-virtual {v0}, Ljava/io/File;->toString()Ljava/lang/String;

    move-result-object v0

    invoke-virtual {v1, v0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object v0

    const-string v1, " "

    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object v0

    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/Utils;->getAppListCacheFile(Landroid/content/Context;)Ljava/io/File;

    move-result-object p0

    invoke-virtual {p0}, Ljava/io/File;->toString()Ljava/lang/String;

    move-result-object p0

    invoke-virtual {v0, p0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object p0

    invoke-virtual {p0}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object p0

    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/Utils;->sendLinuxCommand(Ljava/lang/String;)Lcom/thermasol/touchsteam2/util/Utils$ExecutionResult;
    :try_end_a7
    .catch Ljava/lang/Exception; {:try_start_56 .. :try_end_a7} :catch_a8

    goto :goto_ac

    :catch_a8
    move-exception p0

    .line 1009
    invoke-static {p0}, Lcom/thermasol/touchsteam2/util/Utils;->handleException(Ljava/lang/Exception;)V

    :goto_ac
    return-void
.end method
