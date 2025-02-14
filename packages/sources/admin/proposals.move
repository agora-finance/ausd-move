/// This module is responsible for keeping a list of proposals
/// that are created by time-locked admins. These proposals are used to
/// add or remove roles from the registry. The proposals are
/// timelocked, meaning that they are not active immediately
///
/// The proposals are stored in a bag, where the key is a sequence
/// number. The sequence number is monotonically increasing and is used
/// to identify the proposals.
module ausd::proposals {
    use sui::bag::{Self, Bag};
    use ausd::roles::Role;

    /// Tries to remove a proposal that does not exist in the bag.
    const EProposalNotFound: u64 = 1;

    public struct Proposal<phantom R: drop, V: store + drop> has store {
        /// The role that's being proposed to be added or removed.
        key: Role<R>,
        /// The config for the role (any custom config or bool for non-custom configs).
        /// If this is a "none", that means we are initiating a "deauthorize" proposal,
        /// otherwise it will contain a value (even if it's bool for non-config roles).
        value: Option<V>,
        /// The address of the proposer.
        proposer: address,
        /// The timestamp of the proposal (time of proposing, not time it becomes active).
        /// the activation logic is deferred to the admin module.
        proposal_timestamp_ms: u64,
    }

    /// A key for the admin proposals. It's added on the roles bag.
    public struct ProposalsKey() has copy, store, drop;

    /// The bag of different proposals coming from a timelocked admin.
    public struct Proposals has store {
        /// A bag of proposals, where the key is the sequence number (u64).
        proposals: Bag,
        /// A monotonically increasing sequence number for proposals.
        seq_num: u64,
    }

    public(package) fun new<R: drop, V: store + drop>(
        key: Role<R>,
        value: Option<V>,
        proposer: address,
        proposal_timestamp_ms: u64,
    ): Proposal<R, V> {
        Proposal { key, value, proposer, proposal_timestamp_ms }
    }

    public(package) fun new_registry(ctx: &mut TxContext): Proposals {
        Proposals { proposals: bag::new(ctx), seq_num: 0 }
    }

    public(package) fun add<R: drop, V: store + drop>(
        proposals: &mut Proposals,
        proposal: Proposal<R, V>,
    ) {
        proposals.proposals.add(proposals.seq_num, proposal);
        proposals.seq_num = proposals.seq_num + 1;
    }

    public(package) fun remove<R: drop, V: store + drop>(
        proposals: &mut Proposals,
        seq_num: u64,
    ): Proposal<R, V> {
        assert!(proposals.proposals.contains(seq_num), EProposalNotFound);
        proposals.proposals.remove(seq_num)
    }

    public(package) fun destroy<R: drop, V: store + drop>(
        proposal: Proposal<R, V>,
    ): (Role<R>, Option<V>) {
        let Proposal { key, value, proposer: _, proposal_timestamp_ms: _ } = proposal;
        (key, value)
    }

    public(package) fun key(): ProposalsKey {
        ProposalsKey()
    }

    public(package) fun proposer<R: drop, V: store + drop>(proposal: &Proposal<R, V>): address {
        proposal.proposer
    }

    public(package) fun timestamp_ms<R: drop, V: store + drop>(proposal: &Proposal<R, V>): u64 {
        proposal.proposal_timestamp_ms
    }

    public(package) fun active_proposals(proposals: &Proposals): u64 {
        proposals.proposals.length()
    }
}
