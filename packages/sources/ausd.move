/// The coin module is responsible for creating and managing the AUSD currency.
/// It is a regulated currency, and it gets immediately wrapped into the managed_treasury.
module ausd::ausd {
    use sui::{coin, url};

    use ausd::{treasury, setup};

    const DECIMALS: u8 = 6;
    const SYMBOL: vector<u8> = b"AUSD";
    const NAME: vector<u8> = b"AUSD";
    const DESCRIPTION: vector<u8> = b"AUSD is a digital dollar issued by Agora";
    const ICON_URL: vector<u8> = b"https://static.agora.finance/ausd-token-icon.svg";

    public struct AUSD has drop {}

    #[allow(lint(share_owned))]
    fun init(otw: AUSD, ctx: &mut TxContext) {
        let (treasury_cap, deny_cap, metadata) = coin::create_regulated_currency(
            otw,
            DECIMALS,
            SYMBOL,
            NAME,
            DESCRIPTION,
            option::some(url::new_unsafe(ICON_URL.to_ascii_string())),
            ctx,
        );

        transfer::public_share_object(metadata);
        let managed = setup::setup(treasury_cap, deny_cap, ctx);
        treasury::share(managed);
    }
}
