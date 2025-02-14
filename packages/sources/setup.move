/// A basic module to setup the managed treasury.
///
/// 1. Creates a managed treasury with the given treasury cap and deny cap.
/// 2. Sets up the admin module (creating the admin proposals storage).
/// 3. Authorizes the sender as the first admin of the treasury (non time-locked).
module ausd::setup {
    use sui::coin::{TreasuryCap, DenyCap};
    use ausd::{treasury::{Self, ManagedTreasury}, admin, roles::{Self, AdminRole}};

    /// TODO: Consider making this a public function,
    /// so anyone can use this, and decouple the coin.
    public(package) fun setup<T>(
        treasury_cap: TreasuryCap<T>,
        deny_cap: DenyCap<T>,
        ctx: &mut TxContext,
    ): ManagedTreasury<T> {
        let mut managed = treasury::new(treasury_cap, deny_cap, ctx);
        // Adds the time-locked proposals storage to the treasury.
        admin::setup(&mut managed, ctx);

        // Authorize the sender as the first admin of the treasury.
        managed
            .roles_mut()
            .authorize(
                roles::new_role<AdminRole>(ctx.sender()),
                admin::new_config(false),
            );

        managed
    }
}
