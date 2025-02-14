module ausd::test_admin_e2e {
    use sui::{clock, test_utils};
    use ausd::{admin::{Self, AdminConfig}, test_setup::{Self, ctx}, roles::{AdminRole}, constants};

    #[test]
    fun test_admin_e2e() {
        let mut ctx = tx_context::dummy();
        let mut treasury = test_setup::create_test_treasury(&mut ctx);
        let mut clock = clock::create_for_testing(&mut ctx);

        admin::authorize_admin(&mut treasury, @0x1, false, &clock, &ctx);
        admin::authorize_minter(&mut treasury, @0x1, 10, 10, &clock, &ctx);
        admin::authorize_freezer(&mut treasury, @0x1, &clock, &ctx);
        admin::authorize_burner(&mut treasury, @0x1, &clock, &ctx);
        admin::authorize_pauser(&mut treasury, @0x1, &clock, &ctx);

        // validate that total admins are 2
        assert!(treasury.roles().admin_count() == 2, 0);

        // Add 0x2 as a time-locked admin. Do it as `0x1` which was just authorized before
        admin::authorize_admin(&mut treasury, @0x2, true, &clock, &ctx(@0x1));

        // validate that total admins are 3
        assert!(treasury.roles().admin_count() == 3, 0);

        // try to add a new admin as a "time-locked" admin.
        admin::authorize_admin(&mut treasury, @0x4, false, &clock, &ctx(@0x2));

        // try to add another new admin as a "time-locked" admin.
        admin::authorize_admin(&mut treasury, @0x5, true, &clock, &ctx(@0x2));

        // Count should remain 3, because the admin is time-locked, so there has to be an
        // explicit call to execute the transactions, after the timelock has passed.
        assert!(treasury.roles().admin_count() == 3, 0);

        // validate that there are 2 active proposals
        assert!(admin::proposals(&treasury).active_proposals() == 2, 0);

        // now let's bump the clock by `default_time_lock_period_ms` and execute the proposal
        clock.set_for_testing(constants::default_time_lock_period_ms());

        // we execute the proposal, which should add an extra admin (We get to 4)
        admin::execute_proposal<_, AdminRole, AdminConfig>(&mut treasury, 0, &clock, &ctx(@0x2));

        // validate that total admins are 4
        assert!(treasury.roles().admin_count() == 4, 0);

        // validate that there is a single active proposal
        assert!(admin::proposals(&treasury).active_proposals() == 1, 0);

        // Now let's cancel the second request as a different admin!
        admin::reject_proposal<_, AdminRole, AdminConfig>(&mut treasury, 1, &ctx(@0x1));

        // validate that there are no active proposals
        assert!(admin::proposals(&treasury).active_proposals() == 0, 0);

        // validate that total admins remain 4, since we rejected the proposal
        assert!(treasury.roles().admin_count() == 4, 0);

        // now let's remove an admin
        admin::deauthorize<_, AdminRole, AdminConfig>(&mut treasury, @0x1, &clock, &ctx(@0x1));

        // validate that total admins remain 3, since we removed an admin with a non-timelocked admin.
        assert!(treasury.roles().admin_count() == 3, 0);

        // now let's remove an admin using a timelock proposal
        admin::deauthorize<_, AdminRole, AdminConfig>(&mut treasury, @0x2, &clock, &ctx(@0x2));
        // still 3, we have an active proposal now!
        assert!(admin::proposals(&treasury).active_proposals() == 1, 0);
        assert!(treasury.roles().admin_count() == 3, 0);

        // now let's execute this proposal after we bump the clock.
        clock.set_for_testing(constants::default_time_lock_period_ms() * 2);
        admin::execute_proposal<_, AdminRole, AdminConfig>(&mut treasury, 2, &clock, &ctx(@0x2));

        // now after this, we only have 2 admins left!
        assert!(treasury.roles().admin_count() == 2, 0);

        test_utils::destroy(clock);
        test_utils::destroy(treasury);
    }

    #[test]
    fun set_version() {
        let mut ctx = tx_context::dummy();
        let mut treasury = test_setup::create_test_treasury(&mut ctx);
        admin::set_version(&mut treasury, 1, &ctx);
        test_utils::destroy(treasury);
    }

    #[test, expected_failure(abort_code= ::ausd::admin::ENotAvailableForTimeLockedAdmin)]
    fun set_version_as_time_locked_admin_failure() {
        let mut ctx = tx_context::dummy();
        let mut treasury = test_setup::create_test_treasury(&mut ctx);
        let clock = clock::create_for_testing(&mut ctx);

        admin::authorize_admin(&mut treasury, @0x1, true, &clock, &ctx);

        admin::set_version(&mut treasury, 1, &ctx(@0x1));

        abort 1337
    }

    #[test, expected_failure(abort_code= ::ausd::admin::ECannotExecuteNonOwnProposal)]
    fun execute_non_owned_proposal_failure() {
        let mut ctx = tx_context::dummy();
        let mut treasury = test_setup::create_test_treasury(&mut ctx);
        let mut clock = clock::create_for_testing(&mut ctx);

        admin::authorize_admin(&mut treasury, @0x5, true, &clock, &ctx);

        admin::authorize_admin(&mut treasury, @0x4, false, &clock, &ctx(@0x5));

        // let's bump the clock by `default_time_lock_period_ms` and execute the proposal
        clock.set_for_testing(constants::default_time_lock_period_ms());

        admin::execute_proposal<_, AdminRole, AdminConfig>(&mut treasury, 0, &clock, &ctx);

        abort 1337
    }

    #[test, expected_failure(abort_code= ::ausd::admin::ENotYetAvailableForExecution)]
    fun execute_before_time_lock_has_passed_failure() {
        let mut ctx = tx_context::dummy();
        let mut treasury = test_setup::create_test_treasury(&mut ctx);
        let mut clock = clock::create_for_testing(&mut ctx);

        admin::authorize_admin(&mut treasury, @0x5, true, &clock, &ctx);

        admin::authorize_admin(&mut treasury, @0x4, false, &clock, &ctx(@0x5));

        // let's bump the clock by `default_time_lock_period_ms` and execute the proposal
        clock.set_for_testing(constants::default_time_lock_period_ms() - 1);

        admin::execute_proposal<_, AdminRole, AdminConfig>(&mut treasury, 0, &clock, &ctx(@0x5));

        abort 1337
    }

    // some plain non-authorized calls, for extra sec
    #[test, expected_failure(abort_code = ::ausd::roles::EUnauthorizedUser)]
    fun set_version_as_unauthorized() {
        let mut ctx = tx_context::dummy();
        let mut treasury = test_setup::create_test_treasury(&mut ctx);
        admin::set_version(&mut treasury, 1, &ctx(@0x1));

        abort 1337
    }

    #[test, expected_failure(abort_code = ::ausd::roles::EUnauthorizedUser)]
    fun authorize_admin_as_unauthorized() {
        let mut ctx = tx_context::dummy();
        let mut treasury = test_setup::create_test_treasury(&mut ctx);
        let clock = clock::create_for_testing(&mut ctx);

        admin::authorize_admin(&mut treasury, @0x5, true, &clock, &ctx(@0x1));

        abort 1337
    }

    #[test, expected_failure(abort_code = ::ausd::roles::EUnauthorizedUser)]
    fun execute_proposal_as_unanuthorized() {
        let mut ctx = tx_context::dummy();
        let mut treasury = test_setup::create_test_treasury(&mut ctx);
        let clock = clock::create_for_testing(&mut ctx);
        admin::execute_proposal<_, AdminRole, AdminConfig>(&mut treasury, 0, &clock, &ctx(@0x1));

        abort 1337
    }

    #[test, expected_failure(abort_code = ::ausd::admin::ERoleNotAuthorized)]
    fun try_to_deauthorize_non_authorized() {
        let mut ctx = tx_context::dummy();
        let mut treasury = test_setup::create_test_treasury(&mut ctx);
        let clock = clock::create_for_testing(&mut ctx);

        admin::deauthorize<_, AdminRole, AdminConfig>(&mut treasury, @0x1, &clock, &ctx);

        abort 1337
    }

    #[test, expected_failure(abort_code = ::ausd::admin::EAlreadyAuthorized)]
    fun try_to_authorize_twice() {
        let mut ctx = tx_context::dummy();
        let mut treasury = test_setup::create_test_treasury(&mut ctx);
        let clock = clock::create_for_testing(&mut ctx);

        admin::authorize_admin(&mut treasury, @0x5, true, &clock, &ctx);
        admin::authorize_admin(&mut treasury, @0x5, true, &clock, &ctx);

        abort 1337
    }

    #[test, expected_failure(abort_code= ::ausd::admin::ECannotExecuteNonOwnProposal)]
    fun test_execute_non_own_proposal() {
        let mut ctx = tx_context::dummy();
        let mut treasury = test_setup::create_test_treasury(&mut ctx);
        let mut clock = clock::create_for_testing(&mut ctx);

        // create a time-locked admin
        admin::authorize_admin(&mut treasury, @0x2, true, &clock, &ctx);

        // use this time locked admin to create a proposal
        admin::authorize_admin(&mut treasury, @0x3, true, &clock, &ctx(@0x2));

        clock.set_for_testing(constants::default_time_lock_period_ms());

        // try to execute this proposal as a different admin.
        admin::execute_proposal<_, AdminRole, AdminConfig>(&mut treasury, 0, &clock, &ctx);

        abort 1337
    }

    #[test, expected_failure(abort_code= ::ausd::admin::ECannotRejectAsTimeLocked)]
    fun test_reject_non_owned_proposal() {
        let mut ctx = tx_context::dummy();
        let mut treasury = test_setup::create_test_treasury(&mut ctx);
        let mut clock = clock::create_for_testing(&mut ctx);

        // create a time-locked admin
        admin::authorize_admin(&mut treasury, @0x2, true, &clock, &ctx);
        // create another time-locked admin
        admin::authorize_admin(&mut treasury, @0x3, true, &clock, &ctx);
        // propose to add a new admin
        admin::authorize_admin(&mut treasury, @0x4, true, &clock, &ctx(@0x2));

        clock.set_for_testing(constants::default_time_lock_period_ms());

        // try to reject this proposal being a time-locked admin, and not the proposer.
        admin::reject_proposal<_, AdminRole, AdminConfig>(&mut treasury, 0, &ctx(@0x3));

        abort 1337
    }

    #[test, expected_failure(abort_code = ::ausd::roles::ECannotRemoveLastAdmin)]
    fun deauthorize_last_admin() {
        let mut ctx = tx_context::dummy();
        let mut treasury = test_setup::create_test_treasury(&mut ctx);
        let clock = clock::create_for_testing(&mut ctx);

        admin::deauthorize<_, AdminRole, AdminConfig>(&mut treasury, @0x0, &clock, &ctx);

        abort 1337
    }
}
