# Mario Golf 64

## What does randomization do to this game?
Items which the player would normally acquire throughout the game have been moved around. Logic remains, so the game is always able to be completed, but because of the item shuffle, the player may need to access certain areas before they would in the vanilla game. Wind speed/direction and pin locations can also be randomized per shot.

Some Quality-of-Life features included are:
- either save or randomize the current pin position and wind when creating a save file
- select any unlocked character using certain button combination when resuming a save file
- set the maximum wind speed per hole defined in player options

## What is the goal of Mario Golf 64 when randomized?
There are currently two possible victory conditions to goal Mario Golf 64:
- Win Mario Open by reaching a certain score
- Collect a certain amount of gold trophies

## What game modes are available?
Currently, only tournament and ring shot modes are enabled. 2-4 players are not supported.

## What items and locations can get shuffled?
Locations in which items can be found:
- All Birdie Badges
- Pars on each tournament hole (Parsanity)
- Ring Shot hole clears
- Bronze/Silver/Gold trophies

Items that can be shuffled:
- Certain characters (Maple, Metal Mario). Peach is the starting characters
- Certain clubs (wedges, woods). All irons (2i-9i) are the starting clubs
- Putter lengths (short, middle, long). Starting putter is defined in player options
- All club abilities (approach shot, power shot)
- All tournament tickets
- All ring shot tickets

## What traps are added?
- Bad Lie Trap (simulates the next shot being hit from deep rough)
- Rain Trap (makes the current hole rainy)
- Hurricane Trap (sets the wind to 35mph for the next shot)
- Fast Meter Trap (makes the shot meter move twice as fast for the next shot)

## When the player receives an item, what happens?
Currently, there is no in-game notification system that tells the player that they have received an item. You can refer to the client by using the `/unlocked` command which tells you what do you have.

Here you can tell the player what it will look like when you receive an item in game. This is really nice cause it helps people figure out if
they actually are receiving items the first time they set up the game. Also nice for explaining that really funny/cool/quirky system you
put into your game that only a few people will see but youre really proud of.

## Future Roadmap
Not guaranteed to be added, but just ideas for the future:
- Switching setup from running a dedicated lua script to opening a patched ROM
- Having the user-defined score to win a gold trophy reflect accurately in-game (the score to win each tournament is different in the vanilla game)
- Implementing "fast travel" (allow players to select a specific hole to play which doesn't count towards the gross tournament score, similar to training mode)
- Adding every character to the item pool (Charactersanity). Currently, only Maple and Metal Mario are the only unlockable characters, with Peach being the starting character
- Adding individual clubs to the item pool (Clubsanity). Currently, only wedges and woods are the only unlockable clubs, with players starting with all irons
- Implementing logic for all individual character/club combinations
- Implementing logic for gold trophy difficulties
- Implementing logic for course difficulties
- Adding Checks for character match victories (Versussanity)
- Adding Checks for mini golf hole clears (Minigolfsanity)
- Adding Checks for landing in every bunker (Bunkersanity)
- Adding Checks for getting a green-in-regulation per hole (GIRsanity)
- Implementing hole shuffle (each individual hole of a tournament can be a completely random hole from any tournament)
- Implementing full Universal Tracker support
- Implementing death link send on double-bogey or worse and making it independently toggleable on/off from the normal death link
- Handling a queue multiple traps