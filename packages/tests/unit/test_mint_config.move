module ausd::test_mint_config {
    use ausd::minter;

    #[test]
    fun test_mint_windows_success() {
        let mut config = minter::new_config(10, 10);

        config.add_mint_transaction(2, 1);
        config.add_mint_transaction(3, 2);

        assert!(config.history().length() == 2);
        assert!(config.usage(2) == 5);

        config.add_mint_transaction(5, 3);

        // same moment, usage must be 3
        assert!(config.usage(3) == 10);

        // on 11th second, usage should still be 10 (since the first transaction is still inside the window)
        // std::debug::print(&config.usage(11));
        assert!(config.usage(11) == 10);

        // on 12th second, usage should be 8 (since the first transaction is outside the window)
        assert!(config.usage(12) == 8);
        
        // adding another 5 after the first two transactions would go away.
        config.add_mint_transaction(5, 13);

        // validate our history was shortened
        assert!(config.history().length() == 2);

        // and now we add 10 after this last window has passed (24-10=14)
        config.add_mint_transaction(10, 24);

        // validate our history was shortened appropriately
        assert!(config.history().length() == 1);
    }

    #[test]
    fun test_to_the_window_size_limit() {
        let mut config = minter::new_config(minter::max_transactions_per_window(), 10);
        config.test_bulk_add_mint_transactions(1, 1, minter::max_transactions_per_window());
        assert!(config.usage(1) == minter::max_transactions_per_window());
    }

    #[test]
    fun test_to_the_window_size_limit_with_full_history_removal() {
        let mut config = minter::new_config(minter::max_transactions_per_window(), 10);
        // fill in the maximum amount of transactions in a single window.
        config.test_bulk_add_mint_transactions(1, 0, minter::max_transactions_per_window());

        // refill that maximum amount of transactions after all the previous ones have expired.
        config.test_bulk_add_mint_transactions(1, 11, minter::max_transactions_per_window());
    }

    #[test, expected_failure(abort_code = ::ausd::minter::ETransactionsLimitExceeded)]
    fun surpass_window_total_transactions_limit() {
        let mut config = minter::new_config(minter::max_transactions_per_window() + 1 , 10);
        // fill in the maximum amount of transactions in a single window.
        config.test_bulk_add_mint_transactions(1, 0, minter::max_transactions_per_window() + 1);
    }

    #[test, expected_failure(abort_code = ::ausd::minter::ELimitExceeded)]
    fun surpass_total_amount_for_window() {
        let mut config = minter::new_config(100 , 10);
        config.add_mint_transaction(101, 5);
    }

    #[test, expected_failure(abort_code = ::ausd::minter::ELimitExceeded)]
    fun surpass_total_amount_for_rolling_window() {
        let mut config = minter::new_config(100 , 10);
        config.add_mint_transaction(90, 5);
        config.add_mint_transaction(11, 15);
    }
}
