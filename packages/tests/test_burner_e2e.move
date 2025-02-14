module ausd::test_burner_e2e {
    use sui::{test_scenario::{Self, Scenario}, clock::{Self, Clock}};

    use ausd::{
        treasury::{Self, ManagedTreasury},
        test_setup::{Self, TEST_SETUP},
        burner::{Self, BurnRecipient, BurnerRole},
        admin,
        pauser
    };


    #[test]
    fun test_e2e() {
        let (mut scenario_val, coin_id) = test_init();
        let scenario = &mut scenario_val;

        scenario.next_tx(@0x5);

        let mut treasury = scenario.take_shared<ManagedTreasury<TEST_SETUP>>();
        let mut recipient = scenario.take_shared<BurnRecipient>();

        // burn the coin as a burner.
        burner::burn(&mut treasury, &mut recipient, test_scenario::receiving_ticket_by_id(coin_id), scenario.ctx());

        assert!(treasury.treasury_cap_mut().total_supply() == 0, 0);

        test_scenario::return_shared(treasury);
        test_scenario::return_shared(recipient);

        scenario_val.end();
    }

    #[test, expected_failure(abort_code= ::ausd::roles::EUnauthorizedUser)]
    fun burn_as_unauthorized() {
        let (mut scenario_val, coin_id) = test_init();
        let scenario = &mut scenario_val;

        scenario.next_tx(@0x0);
        let mut treasury = scenario.take_shared<ManagedTreasury<TEST_SETUP>>();

        scenario.next_tx(@0x4);
        let mut recipient = scenario.take_shared<BurnRecipient>();
        // burn the coin as a burner.
        burner::burn(&mut treasury, &mut recipient, test_scenario::receiving_ticket_by_id(coin_id), scenario.ctx());

        abort 1337
    }


    #[test, expected_failure(abort_code= ::ausd::roles::ERolePaused)]
    fun burn_while_burnings_are_paused() {
        let (mut scenario_val, coin_id) = test_init();
        let scenario = &mut scenario_val;

        scenario.next_tx(@0x0);
        let mut treasury = scenario.take_shared<ManagedTreasury<TEST_SETUP>>();
        let clock = scenario.take_shared<Clock>();
        // authorize pauser & pause minter role
        admin::authorize_pauser(&mut treasury, @0x1, &clock, scenario.ctx());
        admin::authorize_burner(&mut treasury, @0x4, &clock, scenario.ctx());

        scenario.next_tx(@0x1);
        pauser::pause<_, BurnerRole>(&mut treasury, scenario.ctx());

        scenario.next_tx(@0x4);
        let mut recipient = scenario.take_shared<BurnRecipient>();
        // burn the coin as a burner.
        burner::burn(&mut treasury, &mut recipient, test_scenario::receiving_ticket_by_id(coin_id), scenario.ctx());

        abort 1337
    }

    /// Initializes the test scenario, returns two IDs of coins transferred to a recipient object.
    fun test_init(): (Scenario, ID) {
        let mut scenario_val = test_scenario::begin(@0x0);
        let scenario = &mut scenario_val;
        clock::create_for_testing(scenario.ctx()).share_for_testing();

        treasury::share(test_setup::create_test_treasury(scenario.ctx()));

        scenario.next_tx(@0x0);

        let mut treasury = scenario.take_shared<ManagedTreasury<TEST_SETUP>>();
        let clock = scenario.take_shared<Clock>();

        // creating a burn recipient object.
        burner::new(scenario.ctx());

        // authjorize `0x5` to be a burner
        admin::authorize_burner(&mut treasury, @0x5, &clock, scenario.ctx());

        // new transaction!
        scenario.next_tx(@0x0);

        let recipient = scenario.take_shared<BurnRecipient>();
        // find the ID of the recipient object, so we can do TTO.
        let id = object::id(&recipient);
        // mint a coin (only available in tests)
        let coin = treasury.treasury_cap_mut().mint(1000, scenario.ctx());

        // save the ID to receive the coin later.
        let coin_id = object::id(&coin);

        // transfer the coin to the recipient object!
        transfer::public_transfer(coin, id.to_address());

        test_scenario::return_shared(treasury);
        test_scenario::return_shared(clock);
        test_scenario::return_shared(recipient);

        (scenario_val, coin_id)
    }
}
