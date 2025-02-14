module ausd::test_setup {
    use sui::{
        coin,
    };

    use ausd::{
        setup,
        treasury::ManagedTreasury
    };

    public struct TEST_SETUP has drop {}

    #[test_only]
    public fun create_test_treasury(ctx: &mut TxContext): ManagedTreasury<TEST_SETUP> {
        let (treasury_cap, deny_cap, metadata) = coin::create_regulated_currency(
            TEST_SETUP {},
            6,
            vector[],
            vector[],
            vector[],
            option::none(),
            ctx
        );

        transfer::public_freeze_object(metadata);
        setup::setup(treasury_cap, deny_cap, ctx)
    }


    public fun ctx(addr: address): TxContext {
        tx_context::new_from_hint(addr, 0, 0, 0, 0)
    }

}
