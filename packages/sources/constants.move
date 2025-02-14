module ausd::constants {
    /// Time-lock period in milliseconds.
    /// Current time-lock is 7 days, meaning that a proposal
    /// will be available for execution after 7 days.
    const DEFAULT_TIME_LOCK_PERIOD_MS: u64 = 7 * 24 * 60 * 60 * 1000;

    public fun default_time_lock_period_ms(): u64 {
        DEFAULT_TIME_LOCK_PERIOD_MS
    }
}
