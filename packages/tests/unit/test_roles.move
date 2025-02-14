module ausd::test_roles {
    use ausd::{roles::{Self, AdminRole}};

    #[test, expected_failure(abort_code= ::ausd::roles::ERoleAlreadyExists)]
    fun authorize_twice() {
        let mut ctx = tx_context::dummy();
        let mut roles = roles::new(&mut ctx);

        roles.authorize(
            roles::new_role<AdminRole>(@0x2),
            true,
        );

        roles.authorize(
            roles::new_role<AdminRole>(@0x2),
            true,
        );

        abort 1337
    }

    #[test, expected_failure(abort_code= ::ausd::roles::ERoleNotExists)]
    fun deauthorize_non_existing() {
        let mut ctx = tx_context::dummy();
        let mut roles = roles::new(&mut ctx);

        roles.deauthorize<_, bool>(roles::new_role<AdminRole>(@0x2));

        abort 1337
    }

    #[test, expected_failure(abort_code= ::ausd::roles::EAlreadyPaused)]
    fun pause_twice() {
        let mut ctx = tx_context::dummy();
        let mut roles = roles::new(&mut ctx);

        roles.pause<AdminRole>();
        roles.pause<AdminRole>();

        abort 1337
    }

    #[test, expected_failure(abort_code= ::ausd::roles::EAlreadyUnpaused)]
    fun unpause_non_paused() {
        let mut ctx = tx_context::dummy();
        let mut roles = roles::new(&mut ctx);

        roles.unpause<AdminRole>();

        abort 1337
    }
}
