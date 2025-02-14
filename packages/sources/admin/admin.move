/// In the AUSD contract, there are two types of admins:
///
/// 1. "Privileged" admin: This admin can execute proposals immediately.
/// 2. "Time-locked" admin: This admin can only execute proposals after a time-lock period has passed.
///
/// The `admin` module provides the functionality to manage these admins, as well as the proposals.
/// When a new admin is added, the caller can specify whether the admin is time-locked or not.
/// A "privileged" admin can reject any time-locked proposals, while a "time-locked" admin can only reject their own proposals.
///
///
/// We have a different API for each role instead of a generic, because some of the roles
/// require special configuration (e.g. minter, admin), and future roles might too.
/// That way we're always certain that a Role<R> exists in the bag only with an expected Value.
module ausd::admin {
    use std::type_name::{Self, TypeName};
    use sui::{dynamic_field as df, clock::Clock, event};
    use ausd::{
        roles::{Self, AdminRole, Role},
        treasury::{ManagedTreasury},
        proposals::{Self, Proposals},
        minter::{Self, MinterRole},
        pauser::PauserRole,
        constants,
        burner::BurnerRole,
        freezer::FreezerRole,
    };

    /// This is only available for time-locked admins.
    const ENotAvailableForTimeLockedAdmin: u64 = 1;
    /// This is only available for the proposer of a proposal.
    const ECannotExecuteNonOwnProposal: u64 = 2;
    /// The proposal is not yet available for execution.
    const ENotYetAvailableForExecution: u64 = 3;
    /// Tries to deauthorize (or propose) a role that is not authorized.
    const ERoleNotAuthorized: u64 = 4;
    /// Tries to authorize (or propose) a role that is already authorized.
    const EAlreadyAuthorized: u64 = 5;
    /// Tries to reject a non-owned proposal as a time-locked admin.
    const ECannotRejectAsTimeLocked: u64 = 6;

    public struct AdminConfig has store, drop {
        time_locked: bool,
    }

    /// Executes a proposal. Can only be called by the time-locked admin that proposed it
    /// and only after the time-lock period has passed.
    public fun execute_proposal<T, R: drop, V: store + drop>(
        treasury: &mut ManagedTreasury<T>,
        proposal_id: u64,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        treasury.roles().assert_is_authorized<AdminRole>(ctx.sender());

        let proposal = proposals_mut(treasury).remove<R, V>(proposal_id);

        // Only the address that proposed a transaction can execute it.
        assert!(proposal.proposer() == ctx.sender(), ECannotExecuteNonOwnProposal);
        // The time-lock period must have passed.
        assert!(
            clock.timestamp_ms() >=
            proposal.timestamp_ms() + constants::default_time_lock_period_ms(),
            ENotYetAvailableForExecution,
        );

        let (key, value) = proposal.destroy();

        if (value.is_none()) {
            treasury.roles_mut().deauthorize<_, V>(key);
            emit_role_change_event<T, R>(false, key.addr());
        } else {
            treasury.roles_mut().authorize(key, value.destroy_some());
            emit_role_change_event<T, R>(true, key.addr());
        }
    }

    /// Rejects a proposal. Can be called by either a non time-locked admin,
    /// or the proposer of a proposal.
    public fun reject_proposal<T, R: drop, V: store + drop>(
        treasury: &mut ManagedTreasury<T>,
        proposal_id: u64,
        ctx: &TxContext,
    ) {
        treasury.roles().assert_is_authorized<AdminRole>(ctx.sender());

        let proposal = proposals_mut(treasury).remove<R, V>(proposal_id);
        let config: &AdminConfig = treasury.roles().config<AdminRole, _>(ctx.sender());

        // for time locked admins, only the proposer can reject the proposal.
        if (config.time_locked) {
            assert!(proposal.proposer() == ctx.sender(), ECannotRejectAsTimeLocked);
        };

        proposal.destroy();
    }

    public fun set_version<T>(treasury: &mut ManagedTreasury<T>, version: u16, ctx: &TxContext) {
        treasury.roles().assert_is_authorized<AdminRole>(ctx.sender());
        let config = treasury.roles().config<AdminRole, AdminConfig>(ctx.sender());

        assert!(!config.time_locked, ENotAvailableForTimeLockedAdmin);
        treasury.set_version(version);
    }

    public fun authorize_admin<T>(
        treasury: &mut ManagedTreasury<T>,
        admin: address,
        time_locked: bool,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        let role = roles::new_role<AdminRole>(admin);
        let role_config = new_config(time_locked);

        internal_authorize_or_propose(treasury, role, role_config, clock, ctx);
    }

    /// Authorizing a new minter.
    ///
    /// Expects an address, the "limit" of total minted AUSD every "duration_ms" time windows.
    /// E.g 10_000 AUSD every 1 day (86400000 ms).
    public fun authorize_minter<T>(
        treasury: &mut ManagedTreasury<T>,
        addr: address,
        limit: u64,
        duration_ms: u64,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        let role_config = minter::new_config(limit, duration_ms);
        internal_authorize_or_propose(
            treasury,
            roles::new_role<MinterRole>(addr),
            role_config,
            clock,
            ctx,
        );
    }

    public fun authorize_freezer<T>(
        treasury: &mut ManagedTreasury<T>,
        addr: address,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        internal_authorize_or_propose(
            treasury,
            roles::new_role<FreezerRole>(addr),
            true,
            clock,
            ctx,
        );
    }

    public fun authorize_burner<T>(
        treasury: &mut ManagedTreasury<T>,
        addr: address,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        internal_authorize_or_propose(
            treasury,
            roles::new_role<BurnerRole>(addr),
            true,
            clock,
            ctx,
        );
    }

    public fun authorize_pauser<T>(
        treasury: &mut ManagedTreasury<T>,
        addr: address,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        internal_authorize_or_propose(
            treasury,
            roles::new_role<PauserRole>(addr),
            true,
            clock,
            ctx,
        );
    }

    /// For roles deauthorization, we also supply the types of the role to be deauthorized.
    public fun deauthorize<T, R: drop, V: store + drop>(
        treasury: &mut ManagedTreasury<T>,
        addr: address,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        treasury.roles().assert_is_authorized<AdminRole>(ctx.sender());
        let role = roles::new_role<R>(addr);

        assert!(treasury.roles().data().contains_with_type<_, V>(role), ERoleNotAuthorized);
        let config: &AdminConfig = treasury.roles().config<AdminRole, _>(ctx.sender());

        // If we have a time-locked admin, we create a proposal instead of authorizing the role.
        if (config.time_locked) {
            let proposal = proposals::new<R, V>(
                role,
                option::none(),
                ctx.sender(),
                clock.timestamp_ms(),
            );
            proposals_mut(treasury).add(proposal);
            return
        };

        treasury.roles_mut().deauthorize<_, V>(role);
        emit_role_change_event<T, R>(false, role.addr());
    }

    /// Create a new admin config.
    public(package) fun new_config(time_locked: bool): AdminConfig {
        AdminConfig { time_locked }
    }

    /// Setup the admin proposals storage, by adding it as a DF to the treasury object.
    public(package) fun setup<T>(treasury: &mut ManagedTreasury<T>, ctx: &mut TxContext) {
        df::add(treasury.uid_mut(), proposals::key(), proposals::new_registry(ctx));
    }

    public(package) fun proposals<T>(treasury: &ManagedTreasury<T>): &Proposals {
        df::borrow(treasury.uid(), proposals::key())
    }

    /// Internal function that:
    ///
    /// 1. If the admin is time-locked, creates a proposal.
    /// 2. If not, authorizes the role immediately.
    fun internal_authorize_or_propose<T, R: drop, V: store + drop>(
        treasury: &mut ManagedTreasury<T>,
        role: Role<R>,
        role_config: V,
        clock: &Clock,
        ctx: &TxContext,
    ) {
        treasury.roles().assert_is_authorized<AdminRole>(ctx.sender());
        let config: &AdminConfig = treasury.roles().config<AdminRole, _>(ctx.sender());

        assert!(!treasury.roles().is_authorized<R>(role.addr()), EAlreadyAuthorized);

        // If we have a time-locked admin, we create a proposal instead of authorizing the role.
        if (config.time_locked) {
            let proposal = proposals::new(
                role,
                option::some(role_config),
                ctx.sender(),
                clock.timestamp_ms(),
            );
            proposals_mut(treasury).add(proposal);
            return
        };

        treasury.roles_mut().authorize(role, role_config);
        emit_role_change_event<T, R>(true, role.addr());
    }

    fun proposals_mut<T>(treasury: &mut ManagedTreasury<T>): &mut Proposals {
        df::borrow_mut(treasury.uid_mut(), proposals::key())
    }

    fun emit_role_change_event<T, R: drop>(is_authorized: bool, authorized_address: address) {
        event::emit(RoleChangedEvent<T> { role: type_name::get<R>(), is_authorized, authorized_address });
    }

    public struct RoleChangedEvent<phantom T> has copy, drop {
        role: TypeName,
        is_authorized: bool,
        authorized_address: address
    }
}
