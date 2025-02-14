module ausd::minter {
    use sui::{coin, deny_list::DenyList, clock::Clock, event};

    use ausd::treasury::ManagedTreasury;

    /// MinterRole: Can mint tokens.
    public struct MinterRole() has drop;

    /// Tries to mint more than the limit allows
    const ELimitExceeded: u64 = 1;
    /// Tries to mint to a frozen recipient
    const ERecipientFrozen: u64 = 2;
    /// Tries to mint more transactions than allowed in the window.
    const ETransactionsLimitExceeded: u64 = 3;

    /// The maximum amount of transactions per window we allow.
    const MAX_TRANSACTIONS_PER_WINDOW: u64 = 7_500;

    /// A transaction is a minting transaction that happened in the past.
    public struct Transaction has copy, store, drop {
        amount: u64,
        timestamp_ms: u64,
    }

    /// Our configuration for the minting limits works as "N" amount in X time.
    /// This means that the minting limit is reset every X time, and cannot
    /// be exceeded in that time frame.
    public struct MintConfig has store, drop {
        duration_ms: u64,
        // the amount of minting that has happened in the current window.
        mint_limit: u64,
        // we save the `active window` history, so we can check if we've exceeded the usage limit, or the
        // total transactions limit. Hardcoded to prevent object size limits. Transactions are always kept in order (newest first),
        // so we can break our iteration early and discard the old ones.
        history: vector<Transaction>,
    }

    public fun mint<T>(
        treasury: &mut ManagedTreasury<T>,
        deny_list: &DenyList,
        amount: u64,
        recipient: address,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        treasury.roles().assert_is_authorized<MinterRole>(ctx.sender());
        treasury.roles().assert_is_not_paused<MinterRole>();

        assert!(!coin::deny_list_contains<T>(deny_list, recipient), ERecipientFrozen);
        let config: &mut MintConfig = treasury.roles_mut().config_mut<MinterRole, _>(ctx.sender());

        // adjusts minting. Checks if we've exceeded limits for our time window.
        config.add_mint_transaction(amount, clock.timestamp_ms());

        // mint & transfer the amount to the recipient.
        transfer::public_transfer(treasury.treasury_cap_mut().mint(amount, ctx), recipient);

        event::emit(MintEvent<T> { amount, recipient });
    }

    public(package) fun new_config(mint_limit: u64, duration_ms: u64): MintConfig {
        MintConfig { duration_ms, mint_limit, history: vector[] }
    }

    /// Adds a transaction to the history, and checks if we've exceeded the minting limits for the time window.
    /// This utilizes a sliding window approach for enforcing limits.
    /// This function is limited to ~100 mints per transaction before hitting transaction limits, which shouldn't
    /// be a problem as operations are usually singular.
    public(package) fun add_mint_transaction(
        config: &mut MintConfig,
        amount: u64,
        current_timestamp_ms: u64,
    ) {
        config.adjust_history(
            vector[
                Transaction { amount, timestamp_ms: current_timestamp_ms },
            ],
            current_timestamp_ms,
        );
    }

    /// Takes in the new history (new transactions that are being added)
    /// and adjusts the history to only include the transactions that happened in the last `duration_ms`.
    ///
    /// Aborts:
    /// 1. If the total minting usage surpasses the minting limit for the window.
    /// 2. If the count of transactions surpass the limit for the window.
    fun adjust_history(
        config: &mut MintConfig,
        mut new_history: vector<Transaction>,
        current_timestamp_ms: u64,
    ) {
        // The transactions we accept are only the ones that happened in the last `duration_ms`.
        let oldest_transaction_timestamp_ms = config.floor_timestamp(current_timestamp_ms);

        // Our initial usage is the amount passed as the "new_history".
        // Allows us to also create bulk APIs if we ever need to (to avoid multiple calls to `add_mint_transaction`,
        //  which re-creates the vector and can hit system limits).
        let mut total_usage = new_history.fold!(0, |acc, transaction| acc + transaction.amount);

        // Reverse the history to pop elements from the end, but maintain the order
        // as we add them to the new history (newest -> oldest)
        config.history.reverse();

        // Iterate over the history and sum the total minting usage.
        // Also move the transactions that happened within the range we care about in a single pass.
        // We reserve 2*n space, which is cleaned up at the end of the function.
        while (config.history.length() > 0) {
            let transaction = config.history.pop_back();

            // if the transaction is older than the accepted timestamp, we can break the loop.
            // By that point, we've moved the transactions that happened within the range we care about.
            if (oldest_transaction_timestamp_ms > transaction.timestamp_ms) break;

            total_usage = total_usage + transaction.amount;
            new_history.push_back(transaction);
        };

        // cannot surpass the total minting limit for the window.
        assert!(total_usage <= config.mint_limit, ELimitExceeded);
        // cannot surpass the total transactions limit for the window.
        assert!(new_history.length() <= MAX_TRANSACTIONS_PER_WINDOW, ETransactionsLimitExceeded);

        config.history = new_history
    }

    // prevent from underflowing the lower bound of the timestamp.
    fun floor_timestamp(config: &MintConfig, current_timestamp_ms: u64): u64 {
        if (config.duration_ms > current_timestamp_ms) 0
        else current_timestamp_ms - config.duration_ms
    }

    public struct MintEvent<phantom T> has copy, drop {
        amount: u64,
        recipient: address,
    }

    #[test_only]
    /// Returns the minting history vector. Useful for testing
    public(package) fun history(config: &MintConfig): &vector<Transaction> {
        &config.history
    }

    #[test_only]
    public(package) fun test_bulk_add_mint_transactions(
        config: &mut MintConfig,
        amount: u64,
        current_timestamp_ms: u64,
        total_transactions: u64,
    ) {
        let mut new_history: vector<Transaction> = vector[];
        total_transactions.do!(
            |_| new_history.push_back(Transaction { amount, timestamp_ms: current_timestamp_ms }),
        );

        config.adjust_history(new_history, current_timestamp_ms);
    }

    #[test_only]
    public(package) fun max_transactions_per_window(): u64 {
        MAX_TRANSACTIONS_PER_WINDOW
    }

    #[test_only]
    public(package) fun usage(config: &MintConfig, timestamp_ms: u64): u64 {
        config
            .history
            .fold!(
                0,
                |acc, transaction| {
                    if (transaction.timestamp_ms >= config.floor_timestamp(timestamp_ms)) {
                        acc + transaction.amount
                    } else {
                        acc
                    }
                },
            )
    }
}
