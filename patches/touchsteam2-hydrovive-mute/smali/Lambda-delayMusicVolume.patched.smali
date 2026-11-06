.class public final synthetic Lcom/thermasol/touchsteam2/util/-$$Lambda$Utils$q_hQ287_rT8SvwrN8-OgSwqt7yA;
.super Ljava/lang/Object;
.source "lambda"

# interfaces
.implements Ljava/lang/Runnable;


# instance fields
.field public final synthetic f$0:I

.field public final synthetic f$1:Landroid/content/Context;

.field public final synthetic f$2:I

.field public final synthetic f$3:I


# direct methods
.method public synthetic constructor <init>(ILandroid/content/Context;II)V
    .registers 5

    invoke-direct {p0}, Ljava/lang/Object;-><init>()V

    iput p1, p0, Lcom/thermasol/touchsteam2/util/-$$Lambda$Utils$q_hQ287_rT8SvwrN8-OgSwqt7yA;->f$0:I

    iput-object p2, p0, Lcom/thermasol/touchsteam2/util/-$$Lambda$Utils$q_hQ287_rT8SvwrN8-OgSwqt7yA;->f$1:Landroid/content/Context;

    iput p3, p0, Lcom/thermasol/touchsteam2/util/-$$Lambda$Utils$q_hQ287_rT8SvwrN8-OgSwqt7yA;->f$2:I

    iput p4, p0, Lcom/thermasol/touchsteam2/util/-$$Lambda$Utils$q_hQ287_rT8SvwrN8-OgSwqt7yA;->f$3:I

    return-void
.end method


# virtual methods
.method public final run()V
    .registers 5

    iget v0, p0, Lcom/thermasol/touchsteam2/util/-$$Lambda$Utils$q_hQ287_rT8SvwrN8-OgSwqt7yA;->f$0:I

    iget-object v1, p0, Lcom/thermasol/touchsteam2/util/-$$Lambda$Utils$q_hQ287_rT8SvwrN8-OgSwqt7yA;->f$1:Landroid/content/Context;

    iget v2, p0, Lcom/thermasol/touchsteam2/util/-$$Lambda$Utils$q_hQ287_rT8SvwrN8-OgSwqt7yA;->f$2:I

    iget v3, p0, Lcom/thermasol/touchsteam2/util/-$$Lambda$Utils$q_hQ287_rT8SvwrN8-OgSwqt7yA;->f$3:I

    invoke-static {v0, v1, v2, v3}, Lcom/thermasol/touchsteam2/util/Utils;->lambda$delayMusicVolume$1(ILandroid/content/Context;II)V

    return-void
.end method
