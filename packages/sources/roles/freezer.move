module ausd::freezer {
    use sui::{deny_list::DenyList, coin, event};
    use ausd::treasury::ManagedTreasury;

    /// FreezerRole: Can freeze (add/remove from denylist)
    public struct FreezerRole() has drop;

    public fun freeze_address<T>(
        treasury: &mut ManagedTreasury<T>,
        denylist: &mut DenyList,
        addr: address,
        ctx: &mut TxContext,
    ) {
        treasury.roles().assert_is_authorized<FreezerRole>(ctx.sender());
        treasury.roles().assert_is_not_paused<FreezerRole>();
        coin::deny_list_add(denylist, treasury.denylist_cap_mut(), addr, ctx);

        event::emit(FreezeEvent<T> { addr, frozen: true });
    }

    public fun unfreeze_address<T>(
        treasury: &mut ManagedTreasury<T>,
        denylist: &mut DenyList,
        addr: address,
        ctx: &mut TxContext,
    ) {
        treasury.roles().assert_is_authorized<FreezerRole>(ctx.sender());
        treasury.roles().assert_is_not_paused<FreezerRole>();
        coin::deny_list_remove(denylist, treasury.denylist_cap_mut(), addr, ctx);

        event::emit(FreezeEvent<T> { addr, frozen: false });
    }

    /// Emitted when an address is frozen or unfrozen.
    public struct FreezeEvent<phantom T> has copy, drop {
        addr: address,
        frozen: bool
    }
}
