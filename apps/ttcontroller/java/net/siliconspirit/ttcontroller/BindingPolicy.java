package net.siliconspirit.ttcontroller;

public final class BindingPolicy {
    public static final long RETRY_MS = 5000;
    private int bindFailures;
    private boolean bound;
    private State state = State.NEW;

    public enum Action {
        NONE,
        BIND,
        UNBIND_THEN_BIND,
        SCHEDULE_RETRY,
        UNBIND_AND_SCHEDULE_RETRY,
        CANCEL_RETRY,
        CANCEL_RETRY_AND_UNBIND
    }

    private enum State {
        NEW,
        BINDING,
        CONNECTED,
        WAITING,
        STOPPED
    }

    public boolean isBound() {
        return this.bound;
    }

    public boolean isConnected() {
        return this.state == State.CONNECTED;
    }

    public int bindFailures() {
        return this.bindFailures;
    }

    public long retryDelayMs() {
        return RETRY_MS;
    }

    public Action start() {
        if (this.state == State.STOPPED || this.state == State.BINDING || this.state == State.CONNECTED) {
            return Action.NONE;
        }
        return begin();
    }

    public Action retryElapsed() {
        return this.state != State.WAITING ? Action.CANCEL_RETRY : begin();
    }

    public Action connected() {
        if (this.state == State.STOPPED || this.state == State.CONNECTED) {
            return Action.NONE;
        }
        this.state = State.CONNECTED;
        this.bound = true;
        this.bindFailures = 0;
        return Action.CANCEL_RETRY;
    }

    public Action disconnected() {
        if (this.state == State.STOPPED || this.state == State.WAITING) {
            return Action.NONE;
        }
        this.state = State.WAITING;
        return Action.SCHEDULE_RETRY;
    }

    public Action binderDied() {
        return disconnected();
    }

    public Action nullBinding() {
        if (this.state == State.STOPPED || this.state == State.WAITING) {
            return Action.NONE;
        }
        this.state = State.WAITING;
        return Action.SCHEDULE_RETRY;
    }

    public Action bindFailed() {
        if (this.state == State.STOPPED) {
            return Action.NONE;
        }
        this.bindFailures++;
        this.bound = false;
        this.state = State.WAITING;
        return Action.SCHEDULE_RETRY;
    }

    public Action descriptorMismatch() {
        if (this.state != State.BINDING) {
            return Action.NONE;
        }
        this.bindFailures++;
        this.bound = false;
        this.state = State.WAITING;
        return Action.UNBIND_AND_SCHEDULE_RETRY;
    }

    public Action bindTimedOut() {
        if (this.state != State.BINDING) {
            return Action.NONE;
        }
        this.bindFailures++;
        this.bound = false;
        this.state = State.WAITING;
        return Action.UNBIND_AND_SCHEDULE_RETRY;
    }

    public Action destroy() {
        this.state = State.STOPPED;
        Action action = this.bound ? Action.CANCEL_RETRY_AND_UNBIND : Action.CANCEL_RETRY;
        this.bound = false;
        return action;
    }

    private Action begin() {
        boolean z = this.bound;
        this.bound = true;
        this.state = State.BINDING;
        return z ? Action.UNBIND_THEN_BIND : Action.BIND;
    }
}
