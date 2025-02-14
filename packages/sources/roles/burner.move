/// Burning process is:
///
/// 1. AUSD (or anyone, but AUSD will do that) creates a new "BurnRecipient" object for every different burn request
/// 2. User sends the Coin<AUSD> to the `BurnRecipient` object.
/// 3. AUSD burner role can use the "BurnRecipient" object to receive the Coin<AUSD> and burn it.
///
/// Recipient object is not destroyed after the burn, so it can be re-used for multiple burns.
module ausd::burner {
    use sui::{transfer::Receiving, coin::Coin, event};
    use ausd::treasury::ManagedTreasury;
    /// BurnerRole: Can burn tokens.
    public struct BurnerRole() has drop;

    public struct BurnRecipient has key {
        id: UID,
    }

    public fun new(ctx: &mut TxContext) {
        transfer::share_object(BurnRecipient { id: object::new(ctx) })
    }

    public fun burn<T>(
        treasury: &mut ManagedTreasury<T>,
        recipient: &mut BurnRecipient,
        coin: Receiving<Coin<T>>,
        ctx: &mut TxContext,
    ) {
        treasury.roles().assert_is_authorized<BurnerRole>(ctx.sender());
        treasury.roles().assert_is_not_paused<BurnerRole>();

        let coin: Coin<T> = transfer::public_receive(&mut recipient.id, coin);

        event::emit(BurnEvent<T> { amount: coin.value(), recipient: object::id(recipient).to_address() });
        treasury.treasury_cap_mut().burn(coin);
    }

    /// The burn event is emitted when the burn is successful.
    public struct BurnEvent<phantom T> has copy, drop {
        amount: u64,
        recipient: address
    }
}
