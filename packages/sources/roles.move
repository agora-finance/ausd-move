module ausd::roles {
    use std::{type_name};
    use sui::{bag::{Self, Bag}};

    /// Tries to remove the last admin.
    const ECannotRemoveLastAdmin: u64 = 1;
    /// Tries to authorize a role that already exists.
    const ERoleAlreadyExists: u64 = 2;
    /// Tries to authenticate to a role that is not authorized.
    const EUnauthorizedUser: u64 = 3;
    /// Tries to authenticate a role which is paused.
    const ERolePaused: u64 = 4;
    /// Tries to pause a role that is already paused.
    const EAlreadyPaused: u64 = 5;
    /// Tries to unpause a role that is already unpaused.
    const EAlreadyUnpaused: u64 = 6;
    /// Tries to deauthorize a role that does not exist.
    const ERoleNotExists: u64 = 7;

    /// We keep the roles struct generic, using a Bag to store the different roles / configs.
    /// This allows us to add more roles in the future without changing the Roles struct.
    ///
    /// The only core role is the `admin`, for which we also keep a count.
    /// This is to add an extra security later preventing the last admin from ever being removed.
    public struct Roles has store {
        data: Bag,
        admin_count: u8,
    }

    /// A role is a struct that contains the address that is authorized
    /// to perform certain actions.
    public struct Role<phantom T> has copy, store, drop {
        addr: address,
    }

    /// This can be used to pause the functionality of individual roles.
    /// E.g. if there's a `Pause<MinterRole>` in the bag, no actions can be executed by this role.
    public struct Pause<phantom T>() has copy, store, drop;

    /// The following roles are defined in the system. Each of these roles are managed on their own module for
    /// additional checks / functionality / configurations.
    ///
    /// AdminRole: Can authorize or deauthorize roles.
    public struct AdminRole() has drop;

    public(package) fun new(ctx: &mut TxContext): Roles {
        Roles { data: bag::new(ctx), admin_count: 0 }
    }

    public(package) fun new_role<T: drop>(addr: address): Role<T> {
        Role { addr }
    }

    /// Authorize a role. If the role is Admin, we also increment the admin count.
    public(package) fun authorize<T: drop, V: store + drop>(
        roles: &mut Roles,
        role: Role<T>,
        value: V,
    ) {
        // we ignore type, as we don't wanna allow the same "role" (role <> address)
        // to be authorized twice with different setups.
        assert!(!roles.data.contains(role), ERoleAlreadyExists);

        if (type_name::get<T>() == type_name::get<AdminRole>()) {
            roles.admin_count = roles.admin_count + 1;
        };

        roles.data.add(role, value)
    }

    /// Deauthorize a role. If the role is Admin, we also decrement the admin count,
    /// and prevent the last admin from being removed.
    public(package) fun deauthorize<T: drop, V: store + drop>(roles: &mut Roles, role: Role<T>): V {
        assert!(roles.data.contains_with_type<_, V>(role), ERoleNotExists);
        if (type_name::get<T>() == type_name::get<AdminRole>()) {
            roles.admin_count = roles.admin_count - 1;
            assert!(roles.admin_count > 0, ECannotRemoveLastAdmin)
        };

        roles.data.remove(role)
    }

    public(package) fun pause<R: drop>(roles: &mut Roles) {
        assert!(!roles.is_paused<R>(), EAlreadyPaused);
        roles.data.add(Pause<R>(), true)
    }

    public(package) fun unpause<R: drop>(roles: &mut Roles) {
        assert!(roles.is_paused<R>(), EAlreadyUnpaused);
        roles.data.remove<_, bool>(Pause<R>());
    }

    public(package) fun is_authorized<R: drop>(roles: &Roles, addr: address): bool {
        let role = Role<R> { addr };
        roles.data.contains(role)
    }

    public(package) fun is_paused<R: drop>(roles: &Roles): bool {
        // TODO: Should we allow pausing admin roles? My guess is no!
        roles.data.contains(Pause<R>())
    }

    public(package) fun config<R: drop, V: store + drop>(roles: &Roles, addr: address): &V {
        roles.data.borrow(Role<R> { addr })
    }

    public(package) fun config_mut<R: drop, V: store + drop>(
        roles: &mut Roles,
        addr: address,
    ): &mut V {
        roles.data.borrow_mut(Role<R> { addr })
    }

    public(package) fun assert_is_authorized<R: drop>(roles: &Roles, addr: address) {
        assert!(is_authorized<R>(roles, addr), EUnauthorizedUser);
    }

    public(package) fun assert_is_not_paused<T: drop>(roles: &Roles) {
        assert!(!is_paused<T>(roles), ERolePaused);
    }

    public(package) fun admin_count(roles: &Roles): u8 {
        roles.admin_count
    }

    public(package) fun data(roles: &Roles): &Bag {
        &roles.data
    }

    public(package) fun addr<R: drop>(role: &Role<R>): address {
        role.addr
    }
}
