module ausd::test_proposals {
    use sui::test_utils;
    use ausd::{proposals, roles};

    public struct TestRole has drop {}

    #[test]
    fun test_proposals() {
        let mut ctx = tx_context::dummy();
        let mut proposals = proposals::new_registry(&mut ctx);

        proposals.add(proposals::new(
            roles::new_role<TestRole>(@0x1),
            option::some(true),
            @0x1,
            0,
        ));
        assert!(proposals.active_proposals() == 1, 0);
        let proposal = proposals.remove<TestRole, bool>(0);
        let (key, mut value) = proposal.destroy();

        assert!(key == roles::new_role<TestRole>(@0x1), 0);
        assert!(value.extract() == true, 0);

        test_utils::destroy(proposals);
    }

    #[test, expected_failure(abort_code = ausd::proposals::EProposalNotFound)]
    fun remove_non_existing_proposal() {
        let mut ctx = tx_context::dummy();
        let mut proposals = proposals::new_registry(&mut ctx);

        let _proposal = proposals.remove<TestRole, bool>(0);
        abort 1337
    }
}
