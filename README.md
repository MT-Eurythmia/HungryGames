# Hungry Games Redo

## Mods

Mods removed from the minetest_game:
* give_initial_stuff
* fireflies
* beds (replaced with hg_beds)
* bones, by default, are set to "drop" mode
* creative
* dungeon_loot
* sethome

Additional mods specific to the subgame:
* `hg_match`, manages the game itself -- player tables and so on. Registers an API.
* `hg_user`, manages the user interaction, including the HUD and the commands.
* `hg_map`, reinitializes the map and fills the chests. Can be also used to create maps.
* `hg_beds`, adds beds that players can use to respawn *once* if the bed is not
destroyed.
* `3d_armor`, unmodified.
* `throwing` and `throwing_arrows`, unmodified (some arrows are disabled).
* `hg_hunger`, hunger & thirst

By default, the chests will be randomely filled with some items (there should
be at least 50 chests on the map for maximum dispatching).
<!-- Each additional player will cause a 10% increase in the quantities. -->

Players are allowed to modify the map, it is reanitialized after each game.

Multiple maps are supported.<!-- The minimum number of players to start a new game
is the maximum between 3 and the number of players out of the number of maps
(e.g. if there are 3 maps and 30 players, a new game will start only if there
are 10 players waiting). The maximum waiting time is 5 minutes, if there are not
enough players (still more than 3) but 5 minutes were waited, a new game
will start anyway. -->

The game computes a metric named the last-20 minutes average time to get 30
players. The countdown is initially set to this value (with a maximum of 5
minutes, which will be typically used unless there are more than 6 players a
minute). Every time a new players connects, the countdown is decreased by
5% of its initial value, unless the countdown is below 20% of its initial value.
