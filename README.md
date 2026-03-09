# Snaptic's Cursor
A fan-made garry's mod addon designed for maximum tomfoolery.\
Based on the ever so funny `@snaptic.3d` and `@alanbecker`, classical X + Δ + R2\
*Explodes into Boxes*

## Bug/Issue Submissions
All bugs or issues should be directed to the git repository.\
Please make sure you are able to show steps for reproducing a problem, if not it may take longer for myself to investigate what is wrong with it.

## Abilities
As a wielder of ungodly amounts of alan becker style power, you can do the following:
- Grab people, and force them to ragdoll by slaming them into the ground.
- Boxify people, to their utter despair.
- Use the cursors like a physgun, almost replicates it.
- Freeze people in-place to talk about that time you did `X + Δ + R2`
- Automatically send anything that touches you into the shadow realms upon being provoked.

Do note: cursors do take damage, once you run out of cursors completely, you are no longer able to create more, yes this is an intended behavior.

## Spawn Permissions
Snaptic's spawnability is based on your administration level, to access the cursor you should be at the `:IsSuperAdmin()` level, however you can change this if the admin-mod being used supports `CAMI` or via the developer guide.

## Console Variables
List of console variables that can be changed on the server.
- `snaptic_cursor_superadmin` (default: 1) - Allows superadmins to use the cursors.
- `snaptic_cursor_superadmin_players` (default: 1) - Allows superadmins to target all players regardless.
- `snaptic_cursor_admin` (default: 0) - Allows admins to use the cursors.
- `snaptic_cursor_admin_players` (default: 0) - Allows admins to target all players regardless.
- `snaptic_cursor_ragdoll_self` (default: 1) - If ragdoll slamming can also inflict the user themselves.
- `snaptic_cursor_ragdoll_duration` (default: 5) - How long (in seconds) a player can be stuck in ragdoll after being dunked on.
- `snaptic_cursor_ragdoll_struggle` (default: 1) - How long (in seconds, tick-based) a player can keyboard mash before breaking free from ragdoll.
- `snaptic_cursor_lives` (default: 4) - Maximum number of i-frame lives for the cursors.
- `snaptic_cursor_durability` (default: 2000) - Maximum durability of the cursors.
- `snaptic_cursor_durabilityregen` (default: 250) - How much durability is restored each regeneration tick.
- `snaptic_cursor_regencooldown` (default: 10) - Delay (in seconds) before durability regeneration can begin.
- `snaptic_cursor_regendelay` (default: 5) - How often (in seconds) a regeneration tick occurs.

## Upcoming (at my discretion)
- Sub-menu contexts - allows for infinitely expanding context menu.
- Cursor physics - cursors inflict damage and force upon just moving it over something.

## Special Thanks
- BuildStruct - literally a dev-land, and for me to... boxify people against their will.
- BuildStruct Developers - screaming at me about errors from this thing.
- Bonyoze - Some physgun code replication based on newtonian physgun.

# Developer Guide

## Access Levels
By default Snaptic's Cursor will check for `:IsSuperAdmin()` as a last resort.\
The chain of precedence goes as follows:
```
1. CVAR - snaptic_cursor_admin and snaptic_cursor_superadmin check.
2. CAMI - Administration standard and access control.
3. Snaptic.Access - Hook access convention. (if this is `nil` the next stage is checked, if any)
```
Additional support for addons are welcome, simply request by making a tracker issue.

### Why not just SWEP.AdminSpawnable?
Reason is because some addons or behaviors of gamemodes that do this can easily fail this check, and for something as powerful as the cursor itself, its better to have more procedures to check if the player is absolutely accepted to have access.\
(Also because funny boxify, its the best feature thus far.)

## Prediction

Snaptic's Cursor expects that interactions are shared.\
This means that permissions for `PhysgunPickup` should be synced or else there maybe some deviations.

## Hooks
These are created for server's and other addon's to attach to.\
While there is CPPI this is more of adaptibility between addons.

### Snaptic.Access(invoker: Player, weapon: Weapon): boolean?
- Realm: SERVER
- Checks if the player who spawned in Snaptic's Cursor can use it.
- By default it will check using :IsSuperAdmin() if no returns are present.
- Reason is to allow for the funny "boxify" effect to take place.

### Snaptic.Interact(invoker: Player, weapon: Weapon, entity: Entity): true?
- Realm: SHARED
- Determines if the player using Snaptic's Cursor can interact with an entity.
- This will allow them to use certain features on the entity and telekinesis.
- By default this checks CPPI or GetOwner if CPPI isn't available.
- This also affects the context menu interaction.

### Snaptic.Context(invoker: Player, weapon: Weapon, entity: Entity): false?
- Realm: SERVER
- Determines if the player is able to open the context menu on an entity.
- This is ran just after `Snaptic.Interact`, by default this will have it open.

### Snaptic.Context.Populate(invoker: Player, weapon: Weapon, context: Entity, entity: Entity): boolean
- Realm: SHARED
- Both sides, client and server must share the same creation of options being added.
- Allows for custom allocation of context menu options, using `context:AddSpacer()` and `context:AddOption(name, callback?)`
- Returning `false` will prevent the context menu from generating, while `true` will allow it to generate.
- By not returning anything will allow the default options to appear.

#### context:AddSpacer()
- This simply adds a spacer between options
  
#### context:AddOption(name: string, callback?: function)
- callback: (context: Entity, invoker: Player, weapon: Weapon, cursor: Entity, entity: Entity)
- Adds an option to be used by the player, not providing callback will simply make it do nothing.

#### context:Close()
- Simply closes the context menu.

```lua
hook.Add("Snaptic.Context.Populate", "example", function(invoker, weapon, context, entity)
    context:AddOption("test", function(invoker, weapon, context, cursor, entity)
        print("bye bye entity!")
        entity:Remove() -- deletes the entity you right-click on.
        context:Close() -- don't want the context menu to linger afterwards.
    end)
    return true -- override
end)
```
