package net.siliconspirit.ttidle;

public final class IdlePeripheralPolicy {
    private boolean ownsMute;

    public enum Action {
        NONE,
        OFF,
        UNMUTE
    }

    public IdlePeripheralPolicy() {
        this(false);
    }

    public IdlePeripheralPolicy(boolean z) {
        this.ownsMute = z;
    }

    public Action next(boolean z, boolean z2, boolean z3) {
        if (!z) {
            return Action.NONE;
        }
        if (z3) {
            return this.ownsMute ? Action.UNMUTE : Action.NONE;
        }
        return (!z2 || this.ownsMute) ? Action.NONE : Action.OFF;
    }

    public void completed(Action action, boolean z) {
        if (z) {
            if (action == Action.OFF) {
                this.ownsMute = true;
            }
            if (action == Action.UNMUTE) {
                this.ownsMute = false;
            }
        }
    }

    public static int[] offSequence() {
        return new int[]{98, 97, 38};
    }

    public static boolean fresh(long j, long j2, long j3) {
        return j2 > 0 && j2 <= j && j - j2 <= j3;
    }
}
