# AUSD contract

The roles (and what they can do) are described in this drawing.

![roles diagram](./packages/ausd-roles.png)

The AUSD contract is a controlled treasury with custom role-based access control enforced.
All actions that use the `TreasuryCap` or the `DenyCap` (main capabilities for coin management)
are gated through specific roles with different setups / limitations.

By design, the basic check for authorization is the **sender's address**, combined with  the associated role (on each modular part of functionality).

## Roles

### Admin

The basic role of the Treasury. An admin can assign or revoke roles to addresses. The fuctionality (available calls) for an [admin lives here.](./packages/sources/admin/admin.move).

> There's an extra protection on this role, which prevents
> the last admin from ever being removed (which would result in being locked out)
> of the system.

There are two types of admins in the current setup:

1. **"Sudo" admin**: Can execute add/revoke role commands immediately.

2. **Time-locked admin**: Any addition/removal of a role has to wait a specified locking period (7 days by default here):

   The time-locked admin's proposals are saved in a special `Proposals` implementation which is a simple sequencial list of proposals,
   where each Proposal holds a `Role<R>` and a config (`V`).

   Depending on the role and if there's a custom configuration for that,
   that `V` could be a configuration, or a boolean (true). That also allows for ease of upgrades in terms of logic.

   You can find an example of a role with configuration on the `MinterRole`.

### Minter

Minter role can mint tokens to a recipient address. This role has a custom configuration to enforce minting limits, namely `MinterConfig`.

The limit enforcement works on time-windows, meaning that a single minter
can mint `N` amount of tokens every `Y` milliseconds (e.g. max 20K every 24 hours).

[You can find the implementation here.](./packages/sources/roles/minter.move)

### Burner

Burner role is responsible for burning tokens.

This utilizes TTO to create a fixed transfer address for end-users (`BurnRecipient` object). Anyone can create a BurnRecipient object,
but only an address with `Burner` role can actually receive these tokens & burn them.

[You can find the implementation here.](./packages/sources/roles/burner.move)

### Freezer

Freezer's role adding/removing addresses from the denylist.

[You can find the implementation here.](./packages/sources/roles/freezer.move)

### Pauser

Pauser can stop these operations on the contract:

1. Mint
2. Burn
3. Freeze

In an upcoming update (once it's available), the pauser will also be able to toggle the global denylist switch.

Implementation is generic on purpose, and expects a role type. For instance,
to pause (or resume) the mint operations, you'd call:

```
pauser::pause<MinterRole>();
pauser::resume<MinterRole>();
```

> While technically you could add a "pause" for any role, the enforcement
> happens on each individual role's implementation.
> For example, there are no checks for paused states on an admin's oeprations,
> and similarly, no checks for paused states on a "pauser's" operation

[You can find the implementation here.](./packages/sources/roles/pauser.move)
