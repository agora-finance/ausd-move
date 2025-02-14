module ausd::treasury {
    use sui::{coin::{TreasuryCap, DenyCap}, dynamic_object_field as dof};

    use ausd::roles::{Self, Roles};

    /// Current version of the treasury.
    const VERSION: u16 = 1;

    // ** ERRORS **
    /// The version of the treasury is no longer supported.
    const EVersionNoLongerSupported: u64 = 1;

    /// We save the treasuryCap as a DOF, to maintain discoverability
    public struct TreasuryCapKey() has copy, store, drop;
    /// Save the DenyCap as a DOF to maintain upgradability (we'll migrate to V2)
    public struct DenyCapKey() has copy, store, drop;

    public struct ManagedTreasury<phantom T> has key {
        id: UID,
        /// The roles / auth system of the treasury.
        roles: Roles,
        /// The treasury version. This is used to make sure that only a single version of the package
        /// is usable at a time.
        version: u16,
    }

    public(package) fun new<T>(
        treasury_cap: TreasuryCap<T>,
        deny_cap: DenyCap<T>,
        ctx: &mut TxContext,
    ): ManagedTreasury<T> {
        let mut id = object::new(ctx);
        dof::add(&mut id, TreasuryCapKey(), treasury_cap);
        dof::add(&mut id, DenyCapKey(), deny_cap);

        ManagedTreasury { id, roles: roles::new(ctx), version: VERSION }
    }

    public(package) fun roles<T>(treasury: &ManagedTreasury<T>): &Roles {
        &treasury.roles
    }
    public(package) fun roles_mut<T>(treasury: &mut ManagedTreasury<T>): &mut Roles {
        treasury.assert_is_valid_version();
        &mut treasury.roles
    }

    // ** Pause functionality. Only callable from "pauser" role. **
    // Access control checks are handled by the role and allow flexibility
    // on the implementation logic.

    // ** Accessors to unblock different role's functionality **
    public(package) fun treasury_cap_mut<T>(
        treasury: &mut ManagedTreasury<T>,
    ): &mut TreasuryCap<T> {
        treasury.assert_is_valid_version();
        dof::borrow_mut(&mut treasury.id, TreasuryCapKey())
    }

    public(package) fun denylist_cap_mut<T>(treasury: &mut ManagedTreasury<T>): &mut DenyCap<T> {
        treasury.assert_is_valid_version();
        dof::borrow_mut(&mut treasury.id, DenyCapKey())
    }

    public(package) fun uid<T>(treasury: &ManagedTreasury<T>): &UID {
        treasury.assert_is_valid_version();
        &treasury.id
    }

    /// Useful to attach plugins / other custom functionality to the core object.
    public(package) fun uid_mut<T>(treasury: &mut ManagedTreasury<T>): &mut UID {
        treasury.assert_is_valid_version();
        &mut treasury.id
    }

    /// Our versioning system. Allows to bump (or downgrade) the version of
    /// the accepted treasury package. What is accepted is controlled by the `VERSION` constant.
    public(package) fun set_version<T>(treasury: &mut ManagedTreasury<T>, version: u16) {
        treasury.version = version;
    }
    #[allow(lint(share_owned))]
    public fun share<T>(treasury: ManagedTreasury<T>) {
        transfer::share_object(treasury)
    }

    fun assert_is_valid_version<T>(treasury: &ManagedTreasury<T>) {
        assert!(treasury.version == VERSION, EVersionNoLongerSupported);
    }
}
