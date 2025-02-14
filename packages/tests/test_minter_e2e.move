module ausd::test_minter_e2e {
    use sui::{clock, test_utils, deny_list};
    use ausd::{
        admin,
        minter::{Self, MintConfig, MinterRole},
        test_setup::{Self, ctx},
        freezer,
        pauser,
    };

    #[test]
    fun test_minter_e2e() {
        let mut ctx = tx_context::dummy();
        let mut treasury = test_setup::create_test_treasury(&mut ctx);
        let mut clock = clock::create_for_testing(&mut ctx);
        let denylist = deny_list::new_for_testing(&mut ctx);

        admin::authorize_minter(&mut treasury, @0x1, 10, 10, &clock, &ctx);
        // another minter, different limit!
        admin::authorize_minter(&mut treasury, @0x5, 120, 10, &clock, &ctx);

        minter::mint(&mut treasury, &denylist, 10, @0x3, &clock, &mut ctx(@0x1));
        minter::mint(&mut treasury, &denylist, 120, @0x3, &clock, &mut ctx(@0x5));
        // let's also spend some time, then mint in a next time-window again.
        clock.set_for_testing(15);
        minter::mint(&mut treasury, &denylist, 10, @0x3, &clock, &mut ctx(@0x1));

        test_utils::destroy(clock);
        test_utils::destroy(treasury);
        test_utils::destroy(denylist);
    }

    #[test]
    fun mint_after_pause_and_unpause() {
        let mut ctx = tx_context::dummy();
        let mut treasury = test_setup::create_test_treasury(&mut ctx);
        let clock = clock::create_for_testing(&mut ctx);
        let denylist = deny_list::new_for_testing(&mut ctx);

        admin::authorize_minter(&mut treasury, @0x1, 10, 10, &clock, &ctx);
        admin::authorize_pauser(&mut treasury, @0x1, &clock, &ctx);

        pauser::pause<_, MinterRole>(&mut treasury, &ctx(@0x1));
        pauser::resume<_, MinterRole>(&mut treasury, &ctx(@0x1));

        minter::mint(&mut treasury, &denylist, 10, @0x012, &clock, &mut ctx(@0x1));

        test_utils::destroy(clock);
        test_utils::destroy(treasury);
        test_utils::destroy(denylist);
    }

    #[test]
    fun freeze_unfreeze_and_mint() {
        let mut ctx = tx_context::dummy();
        let mut treasury = test_setup::create_test_treasury(&mut ctx);
        let clock = clock::create_for_testing(&mut ctx);
        let mut denylist = deny_list::new_for_testing(&mut ctx);

        // authorize freezer
        admin::authorize_freezer(&mut treasury, @0x1, &clock, &ctx);

        // cannot mint to this address now!
        freezer::freeze_address(&mut treasury, &mut denylist, @0x012, &mut ctx(@0x1));
        // mint is enabled again!
        freezer::unfreeze_address(&mut treasury, &mut denylist, @0x012, &mut ctx(@0x1));

        admin::authorize_minter(&mut treasury, @0x1, 10, 10, &clock, &ctx);
        minter::mint(&mut treasury, &denylist, 10, @0x012, &clock, &mut ctx(@0x1));

        test_utils::destroy(clock);
        test_utils::destroy(treasury);
        test_utils::destroy(denylist);
    }

    #[test, expected_failure(abort_code= ::ausd::roles::EUnauthorizedUser)]
    fun test_as_unauthorized() {
        let mut ctx = tx_context::dummy();
        let mut treasury = test_setup::create_test_treasury(&mut ctx);
        let clock = clock::create_for_testing(&mut ctx);
        let denylist = deny_list::new_for_testing(&mut ctx);

        minter::mint(&mut treasury, &denylist, 10, @0x3, &clock, &mut ctx(@0x1));

        abort 1337
    }

    #[test, expected_failure(abort_code= ::ausd::roles::EUnauthorizedUser)]
    fun authorize_mint_deauthorize_fail() {
        let mut ctx = tx_context::dummy();
        let mut treasury = test_setup::create_test_treasury(&mut ctx);
        let clock = clock::create_for_testing(&mut ctx);
        let denylist = deny_list::new_for_testing(&mut ctx);

        admin::authorize_minter(&mut treasury, @0x1, 10, 10, &clock, &ctx);
        minter::mint(&mut treasury, &denylist, 10, @0x3, &clock, &mut ctx(@0x1));

        admin::deauthorize<_, MinterRole, MintConfig>(&mut treasury, @0x1, &clock, &ctx);

        minter::mint(&mut treasury, &denylist, 10, @0x3, &clock, &mut ctx(@0x1));

        abort 1337
    }

    #[test, expected_failure(abort_code= ::ausd::minter::ERecipientFrozen)]
    fun mint_to_frozen_recipient() {
        let mut ctx = tx_context::dummy();
        let mut treasury = test_setup::create_test_treasury(&mut ctx);
        let clock = clock::create_for_testing(&mut ctx);
        let mut denylist = deny_list::new_for_testing(&mut ctx);

        // authorize freezer
        admin::authorize_freezer(&mut treasury, @0x1, &clock, &ctx);

        // cannot mint to this address now!
        freezer::freeze_address(&mut treasury, &mut denylist, @0x012, &mut ctx(@0x1));

        admin::authorize_minter(&mut treasury, @0x1, 10, 10, &clock, &ctx);
        minter::mint(&mut treasury, &denylist, 10, @0x012, &clock, &mut ctx(@0x1));

        abort 1337
    }

    #[test, expected_failure(abort_code= ::ausd::roles::ERolePaused)]
    fun mint_while_mints_are_paused() {
        let mut ctx = tx_context::dummy();
        let mut treasury = test_setup::create_test_treasury(&mut ctx);
        let clock = clock::create_for_testing(&mut ctx);
        let denylist = deny_list::new_for_testing(&mut ctx);

        admin::authorize_minter(&mut treasury, @0x1, 10, 10, &clock, &ctx);

        // authorize pauser & pause minter role
        admin::authorize_pauser(&mut treasury, @0x1, &clock, &ctx);
        pauser::pause<_, MinterRole>(&mut treasury, &ctx(@0x1));

        minter::mint(&mut treasury, &denylist, 10, @0x012, &clock, &mut ctx(@0x1));

        abort 1337
    }
}
