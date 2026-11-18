# Examples Of Various Settings

Due to the complexity of how the options in the YAML work, I've put together an in-depth explanation for some of the settings in the YAML. Understanding how the different options affect one another is important when creating your settings. As a result, it allows for more control on how you want your multiworld to function. Not all options will be displayed here. Only ones that are important or affect another option will be used in these examples. I've also put together a list of different examples at the very end of this document to show how you might want to setup your Mario Golf 64 settings.

## Default Template Settings

These are the default settings when you generate template options.

- goal: `win_mario_open`
- gold_trophy_shuffle: `disabled`
- trophy_amount: `5`
- trophy_count: `2`
- gold_trophy_difficulty: `-4`
- limit_tournament_logic: `disabled`
- number_of_tournaments: `-1`
- tournament_likeliness:
  - Toad Tournament: `1`
  - Koopa Cup: `1`
  - Shy Guy International: `1`
  - Yoshi Championship: `1`
  - Boo Classic: `1`
  - Mario Open: `0`

To finish this seed, you must beat Mario Open with a score of `-4` or better. In order to gain access to Mario Open at all, you must first collect `2` Gold Trophies first. Since Gold Trophies are not shuffled, they will be in their normal vanilla locations. This means that you must win any 2 of the 5 tournaments with a score of -4 or better.

## Number of Tournaments Required

In the above example, `trophy_count` is equal to the number of tournaments you are required to win before gaining access to Mario Open. So if you want to win only 1 tournament, `trophy_count` would be `1`. If you want to win all tournaments before accessing Mario Open, `trophy_count` would be `5` (equal to `trophy_amount`).

## Shuffling Gold Trophy Locations

Let's say that you don't necessarily want to win 2 tournaments but still want to require 2 Gold Trophy items to gain access to Mario Open.

- goal: `win_mario_open`
- **gold_trophy_shuffle: `enabled`**
- trophy_amount: `5`
- trophy_count: `2`

By setting `gold_trophy_shuffle` to `enabled` and having `trophy_amount` unchanged at `5`, this means that Gold Trophies you normally would have received from first place of each tournament are now placed anywhere within the MultiWorld. That means it could be behind the `Koopa Cup - Hole 4 Par` location, or even the `Boo Classic - Bronze Trophy` location. Of course it also means that there is a chance that the seed shuffles a Gold Trophy in its original location, but now this means that you do not necessarily need to win 2 tournaments to gain access to Mario Open; you simply need to find 2 locations that hold a Gold Trophy item.

Having `gold_trophy_shuffle` set to `enabled` allows one additional feature:

- goal: `win_mario_open`
- gold_trophy_shuffle: `enabled`
- **trophy_amount: `69`**
- trophy_count: `2`

Because `gold_trophy_shuffle` is now `enabled`, it allows `trophy_amount` to be any number between 1 and 200 instead of being permanently set to 5. This setting puts `69` Gold Trophies in the item pool which can be placed in any location. That means there will be a higher chance of finding 2 Gold Trophy items, thus unlocking Mario Open much faster.

## Number of Gold Trophies Required

If you want to change the amount of trophies to make it so you'd have to find nearly all the Gold Trophies in the item pool, you would set `trophy_count` to a number closer to `trophy_amount`.

- goal: `win_mario_open`
- gold_trophy_shuffle: `enabled`
- **trophy_amount: `69`**
- trophy_count: `55`

Here, you would need to find `55` out of `69` Gold Trophies before gaining access to Mario Open.

## Removing Specific Tournaments From The MultiWorld

Going back to the original default template settings, let's say that you really hate Boo Classic and do not want to include it in the seed whatsoever. Your settings will now look like this:

- goal: `win_mario_open`
- gold_trophy_shuffle: `disabled`
- trophy_amount: `5`
- trophy_count: `2`
- gold_trophy_difficulty: `-4`
- limit_tournament_logic: `disabled`
- number_of_tournaments: `-1`
- tournament_likeliness:
  - Toad Tournament: `1`
  - Koopa Cup: `1`
  - Shy Guy International: `1`
  - Yoshi Championship: `1`
  - **Boo Classic: `0`**
  - Mario Open: `0`

By setting Boo Classic's likeliness to `0`, that means that tournament is completely removed from the seed. So now, you must win 2 out of **4** tournaments (no longer 5) to gain access to Mario Open.

**Note:** `trophy_amount` and `number_of_tournaments` are unaffected due to how `gold_trophy_shuffle` works. They are automatically calculated, so there is no need to change their values.

## Tournament Logic (Disabled)

By default, the setting `limit_tournament_logic` is set to `disabled`. What this means is that all tournaments in the MultiWorld with a non-zero `tournament_likeliness` (excluding Mario Open) has a chance of containing progression items required to beat the seed. This means that you could find yourself entering all 5 tournaments and might even get really deep into some of them (having to go all the way to hole 17 just to find your Woods, for example) without ever winning that tournament. As a result, you might end up playing a majority of the game and extending the playthrough longer than expected since at the end of the day, the seed only cares that you collect `2` Gold Trophies to gain access Mario Open and does not care not how far into each tournament you are. This is where the `limited` and `required_courses_only` options come into play.

## Tournament Logic (Required Courses Only)

Let's say that you do not want to deal with the possibility of getting really deep into a tournament to find a possible progression item and only want to play the tournaments that the seed expects you to win. You would then set `limit_tournament_logic` to either `limited` or `required_courses_only`. There is a small difference between these two options, which will be explained below. Going back to the original default template settings, this is what is affected:

- goal: `win_mario_open`
- gold_trophy_shuffle: `enabled`
- trophy_amount: `5`
- trophy_count: `2`
- gold_trophy_difficulty: `-4`
- **limit_tournament_logic: `required_courses_only`**
- number_of_tournaments: `-1`
- tournament_likeliness:
  - Toad Tournament: `1`
  - Koopa Cup: `1`
  - Shy Guy International: `1`
  - Yoshi Championship: `1`
  - Boo Classic: `1`
  - Mario Open: `0`

By setting `limit_tournament_logic` to `required_courses_only`, the seed will now randomly choose 2 tournaments and only put those in the MultiWorld. The other 3 will not exist at all. For example, the seed might make you win Koopa Cup and Shy Guy International to get your 2 Gold Trophies required to gain access to Mario Open. Thus all Toad Tournament, Yoshi Championship, and Boo Classic locations are completely removed from the MultiWorld.

## Tournament Logic (Limited)

By setting `limit_tournament_logic` to `limited` instead, the seed still randomly chooses 2 tournaments, but the difference is that the other tournaments *will* exist in the MultiWorld. However, all items located in these tournaments are forced to be fillers and *not* useful towards progression. This is only useful if you think that you might want to collect filler items that might be somewhat helpful in other games (for example, getting extra badges in Paper Mario: The Thousand-Year Door, more lives in Super Mario Sunshine, etc.). So although you still need a Tournament Ticket to gain access to one of these "unused" tournaments, you are *not* required to check any locations there, ever. So if the seed is expecting you to win Koopa Cup and Shy Guy International, sending checks from Toad Tournament is not required to beat the MultiWorld.

However, there is a special case where having `limited_tournament_logic` to limited could be helpful.

- goal: `win_mario_open`
- gold_trophy_shuffle: `disabled`
- limit_tournament_logic: `limited`

If `gold_trophy_shuffle` is `disabled`, the Gold Trophies will be the only non-filler item in these "unused" tournaments. That means that winning Toad Tournament will in fact grant you a Gold Trophy item. So in the event that you are unable to find a Koopa Cup Ticket or Shy Guy Internaional Ticket and somehow found a Tournament Ticket early on to one of the other "unused" tournaments and are able to reach the winning score threshold, you can 100% do that and actually benefit from it instead of getting a filler item for that location, which is what having `gold_trophy_shuffle` to `enabled` would originally do. It gives you more options to beat the MultiWorld since again, the seed only logically expects you to win the tournaments in logic (in this example, Koopa Cup and Shy Guy International), so any other tournament win is a bonus.

**Note:** the LUA script will tell you exactly which tournaments the seed logically expects you to win. This is only true for `limited` and `required_courses_only`, since `disabled` expects you to potentially enter every tournament in the MultiWorld, depending on the seed.

## Choosing Specific Tournaments From The MultiWorld

Let's say that you are fine with the seed choosing random tournaments to win, but you *really* want Yoshi Championship to be one of the tournaments it possibly selects and do not really care which tournament gets selected after that.

- goal: `win_mario_open`
- gold_trophy_shuffle: `disabled`
- trophy_amount: `5`
- trophy_count: `2`
- limit_tournament_logic: `limited`
- number_of_tournaments: `-1`
- tournament_likeliness:
  - Toad Tournament: `1`
  - Koopa Cup: `1`
  - Shy Guy International: `1`
  - **Yoshi Championship: `99`**
  - Boo Classic: `1`
  - Mario Open: `0`

By changing the likeliness of Yoshi Championship to `99` (or any large number, really), the chances of selecting Yoshi Championship is extremely high (to be exact, it's 99/103 since 103 is the total between all tournaments' likeliness combined), but *not* guaranteed. So there is still a chance the seed makes you win Koopa Cup and Shy Guy International, albeit extremely unlikely.

**Note:** the values of `tournament_likeliness` represent a weighted average, so there is not really a maximum value you can use. Anything over `1000` is probably overkill.

Another option this allows is that you can also choose exactly which two tournaments you want to win in your seed by setting all the other tournaments you don't want to 0.

- tournament_likeliness:
  - **Toad Tournament: `0`**
  - Koopa Cup: `1`
  - Shy Guy International: `1`
  - **Yoshi Championship: `0`**
  - **Boo Classic: `0`**
  - Mario Open: `0`

In this example, Koopa Cup and Shy Guy International are the 2 tournaments required to win in order to gain access to Mario Open.

## Choosing A Specific Number Of Tournaments

By having `gold_trophy_shuffle` set to `enabled`, it also allows you to set a value for `number_of_tournaments` and not have it be defaulted to `-1`. When Gold Trophies are not shuffled and are placed in their vanilla locations, the number of tournaments in logic is equal to `trophy_count`. But now that Gold Trophies are shuffled and can be placed anywhere, you need to manually decide how many tournaments to include in the MultiWorld. This is done with the `number_of_tournaments` setting.

- goal: `win_mario_open`
- **gold_trophy_shuffle: `enabled`**
- trophy_amount: `5`
- trophy_count: `2`
- **limit_tournament_logic: `limited` or `required_courses_only`**
- number_of_tournaments: `-1`
- tournament_likeliness:
  - Toad Tournament: `1`
  - Koopa Cup: `1`
  - Shy Guy International: `1`
  - Yoshi Championship: `1`
  - Boo Classic: `1`
  - Mario Open: `0`

By only changing `gold_trophy_shuffle` and `limit_tournament_logic` in the original default template settings and nothing else, it acts exactly how `disabled` tournament logic works where you might find yourself deep in all 5 tournaments without actually beating any of them. The main difference is now `5` Gold Trophies are randomly placed within the MultiWorld and not necessarily at the tournament's respective gold trophy location. Since `number_of_tournaments` is set to `-1`, it means all tournaments are in logic, which negates how `limited` and `required_courses_only` tournament logic work in this example. By setting `number_of_tournaments` to a specific number, only that number of tournaments will be considered in logic by the seed, with the "unused" tournaments either being completely removed (`required_courses_only`), or only contain filler items (`limited`).

- gold_trophy_shuffle: `enabled`
- trophy_amount: `5`
- trophy_count: `2`
- **limit_tournament_logic: `required_courses_only`**
- **number_of_tournaments: `3`**
- tournament_likeliness:
  - Toad Tournament: `1`
  - Koopa Cup: `0`
  - Shy Guy International: `1`
  - Yoshi Championship: `1`
  - Boo Classic: `1`
  - Mario Open: `0`

In this example, the seed will randomly select 3 out of 4 courses to put into logic, removing the "unused" tournament completely from the MultiWorld. Since Koopa Cup's `tournament_likeliness` is already `0`, it is removed completely from the MultiWorld, regardless of what tournament logic is set. One example outcome could be having Toad Tournament, Shy Guy International, and Boo Classic as the tournaments in logic, while Yoshi Championship is completely removed from the MultiWorld.

**Note:** `number_of_tournaments` only works if `limit_tournament_logic` is set to `limited` or `required_courses_only`. This is because when `limit_tournament_logic` set to `disabled`, all tournaments (with a non-zero `tournament_likeliness`) are automatically included in the MultiWorld, rather than a specific subset.

## Alternate Goal (Collecting A Specific Number Of Trophies)

In all of the above examples, `goal` has been set to `win_mario_open`. This means that in order to gain access to Mario Open, you must find a certain amount of Gold Trophies first. The way `gold_trophies` works is that Mario Golf will goal the moment you collect a certain amount of Gold Trophies (no matter where you are in the game), rather than rewarding access to Mario Open.

- **goal: `gold_trophies`**
- gold_trophy_shuffle: `disabled`
- trophy_amount: `5`
- trophy_count: `2`
- limit_tournament_logic: `disabled`
- number_of_tournaments: `-1`
- tournament_likeliness:
  - Toad Tournament: `1`
  - Koopa Cup: `1`
  - Shy Guy International: `1`
  - Yoshi Championship: `1`
  - Boo Classic: `1`
  - Mario Open: `0`

 By only changing `goal` to `gold_trophies` in the original default template settings and nothing else, it acts almost exactly the same. The only difference is that rather than accessing Mario Open upon collecing the 2nd Gold Trophy, you will instead goal and finish the game.

 ## Changing Access To Mario Open

To change how you access Mario Open (or even remove it completely from the MultiWorld), `goal` must be set to `gold_trophies`. So Mario Open's access changes to needing a Mario Open Ticket item, which is the same way you gain access to any other tournament. This now allows you to set Mario Open's likeliness above 0 if you want to include it in the pool of tournaments.

- goal: `gold_trophies`
- gold_trophy_shuffle: `disabled`
- trophy_amount: `5`
- trophy_count: `2`
- **limit_tournament_logic: `disabled`
- number_of_tournaments: `-1`
- tournament_likeliness:
  - Toad Tournament: `1`
  - Koopa Cup: `1`
  - Shy Guy International: `1`
  - Yoshi Championship: `1`
  - Boo Classic: `1`
  - **Mario Open: `1`**

With this change, Mario Open is now able to be a possible selection in the pool of tournaments in logic. Thus this seed will randomly choose 2 tournaments from the list of all 6. Now a Mario Open Ticket item is added to the pool, which is how you access that tournament. This also means that it is possible to have Mario Open as your starting tournament as well. And because `gold_trophy_shuffle` is set to `disabled`, you do not have to touch `trophy_amount` since it is auto-calculated. Because Mario Open's likeliness is above `0`, it adds 1 additional Gold Trophy to the pool, meaning `trophy_amount` auto-calculates to `6`.

- goal: `gold_trophies`
- gold_trophy_shuffle: `enabled`**
- trophy_amount: `5`
- **trophy_count: `4`**
- limit_tournament_logic: `disabled`
- number_of_tournaments: `-1`
- tournament_likeliness:
  - Toad Tournament: `1`
  - Koopa Cup: `1`
  - Shy Guy International: `1`
  - Yoshi Championship: `1`
  - Boo Classic: `1`
  - Mario Open: `1`

By changing `trophy_count` to `4`, the seed now only selects 4 tournaments out of the possible 6 to be in logic. Because of `disabled` tournament logic, the other 2 "unused" tournaments are still accessible, but not required to be won. At this point, Mario Open is treated exactly like any other tournament, so you can use the different combinations from previous examples to produce the same customization, just with a different victory condition.

## Examples Of Different Types Of Settings

Below are a list of various types of scenarios, which will help show which settings to modify and what values to set them to.

---

(Default Template Example) Win by beating Mario Open with a score of -4 or better. Win 2 tournaments to gain access to Mario Open. All tournaments are accessible.

- goal: `win_mario_open`
- gold_trophy_shuffle: `disabled`
- trophy_amount: `5`
- trophy_count: `2`
- gold_trophy_difficulty: `-4`
- limit_tournament_logic: `disabled`
- number_of_tournaments: `-1`
- tournament_likeliness:
  - Toad Tournament: `1`
  - Koopa Cup: `1`
  - Shy Guy International: `1`
  - Yoshi Championship: `1`
  - Boo Classic: `1`
  - Mario Open: `0`

---

Win by collecting 70% of Gold Trophies, which are shuffled throughout the MultiWorld. Only include 3 tournaments in the MultiWorld and remove the rest completely. This includes Mario Open. Each tournament's gold trophy location requires a score of -8 or better to send.

- goal: `gold_trophies`
- gold_trophy_shuffle: `enabled`
- trophy_amount: `100`
- trophy_count: `70`
- gold_trophy_difficulty: `-8`
- limit_tournament_logic: `enabled`
- number_of_tournaments: `3`
- tournament_likeliness:
  - Toad Tournament: `1`
  - Koopa Cup: `1`
  - Shy Guy International: `1`
  - Yoshi Championship: `1`
  - Boo Classic: `1`
  - Mario Open: `0`

---

Win by getting 1st place in 2 tournaments. Make Mario Open have a high chance of being one of them, while the other can be either Toad Tournament or Yoshi Championship. Each tournament requires a score of -1 or better to win. Remove all the other tournaments from the MultiWorld.

- goal: `gold_trophies`
- gold_trophy_shuffle: `disabled`
- trophy_amount: `5` (unchanged but you can set this to `2` if you really wanted to)
- trophy_count: `2`
- gold_trophy_difficulty: `-1`
- limit_tournament_logic: `enabled`
- number_of_tournaments: `-1` (unchanged but you can set this to `2` if you really wanted to)
- tournament_likeliness:
  - Toad Tournament: `1`
  - Koopa Cup: `0`
  - Shy Guy International: `0`
  - Yoshi Championship: `1`
  - Boo Classic: `0`
  - Mario Open: `100`

---

Win by beating Mario Open with a score of -7 or better. Win 1 tournament to gain access to Mario Open. Make Koopa Cup have high odds of being selected. Shy Guy International has okay odds, Yoshi Championship has low odds, and Toad Tournament has extremely low odds. All tournaments are accessible, but only one will be required to beat by the seed. Winning an "unused" tournament will also grant access to Mario Open.

- goal: `win_mario_open`
- gold_trophy_shuffle: `disabled`
- trophy_amount: `5`
- trophy_count: `1`
- gold_trophy_difficulty: `-7`
- limit_tournament_logic: `limited_courses_only`
- number_of_tournaments: `-1`
- tournament_likeliness:
  - Toad Tournament: `1`
  - Koopa Cup: `100`
  - Shy Guy International: `40`
  - Yoshi Championship: `10`
  - Boo Classic: `10`
  - Mario Open: `0`

---

Win by collecting all Gold Trophies in the pool, which are shuffled throughout the MultiWorld. Only make Koopa Cup and Boo Classic as the tournaments in logic. Mario Open is removed completely from the MultiWorld. The other 3 "unused" tournaments are accessible (after receiving their respective Tournament Ticket items), and winning them will only reward a filler item. Each tournament's gold trophy location requires a score of -2 or better to send.

- goal: `gold_trophies`
- gold_trophy_shuffle: `enabled`
- trophy_amount: `45`
- trophy_count: `45`
- gold_trophy_difficulty: `-2`
- limit_tournament_logic: `limited_courses_only`
- number_of_tournaments: `2` (unchanged but you can set this to `2` if you really wanted to)
- tournament_likeliness:
  - Toad Tournament: `0`
  - Koopa Cup: `1`
  - Shy Guy International: `0`
  - Yoshi Championship: `0`
  - Boo Classic: `1`
  - Mario Open: `0`

---

Win by beating Mario Open with a score of -13 or better. Mario Open is unlocked at the very beginning. No other tournaments are in the MultiWorld.

- goal: `gold_trophies`
- gold_trophy_shuffle: `disabled`
- trophy_amount: `1`
- trophy_count: `1`
- gold_trophy_difficulty: `-13`
- limit_tournament_logic: `disabled`
- number_of_tournaments: `-1`
- tournament_likeliness:
  - Toad Tournament: `0`
  - Koopa Cup: `0`
  - Shy Guy International: `0`
  - Yoshi Championship: `0`
  - Boo Classic: `0`
  - Mario Open: `1`