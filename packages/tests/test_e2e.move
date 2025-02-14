module ausd::test_e2e {
    use sui::{test_utils};
    use ausd::test_setup;

    #[test]
    fun test_e2e() {
        let mut ctx = tx_context::dummy();
        let treasury = test_setup::create_test_treasury(&mut ctx);

        test_utils::destroy(treasury);
    }
}
