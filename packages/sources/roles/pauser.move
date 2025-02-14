module ausd::pauser {
    use std::type_name::{Self, TypeName};
    use sui::event;
    use ausd::treasury::ManagedTreasury;

    /// PauserRole: Can pause various functionality of the contract.
    public struct PauserRole() has drop;

    // Functionality available to pauser role users.
    public fun pause<T, R: drop>(treasury: &mut ManagedTreasury<T>, ctx: &TxContext) {
        treasury.roles().assert_is_authorized<PauserRole>(ctx.sender());
        treasury.roles_mut().pause<R>();

        event::emit(PauseEvent<T> { role: type_name::get<R>(), paused: true });
    }

    public fun resume<T, R: drop>(treasury: &mut ManagedTreasury<T>, ctx: &TxContext) {
        treasury.roles().assert_is_authorized<PauserRole>(ctx.sender());
        treasury.roles_mut().unpause<R>();

        event::emit(PauseEvent<T> { role: type_name::get<R>(), paused: false });
    }

    /// Emitted when a role is paused or resumed.
    public struct PauseEvent<phantom T> has copy, drop {
        role: TypeName,
        paused: bool
    }
}
