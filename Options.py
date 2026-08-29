from dataclasses import dataclass
from Options import Choice, Toggle, Range, DeathLink, PerGameCommonOptions, StartInventoryPool, OptionCounter
from schema import Schema

class LimitTournamentLogic(Choice):
    """Sets how the item pool is distributed within tournament courses.

    disabled: Progression items may appear in any course.
    limited: Progression items will only appear in required courses (except Gold Trophies if gold_trophy_shuffle is disabled).
    required_courses_only: Courses that are not required will be completely removed from the item pool.
    
    limited is currently incompatible with Universal Tracker."""
    display_name = "Limit Tournament Logic"
    option_disabled = 0
    option_limited = 1
    option_required_courses_only = 2
    default = 0

class StartingPutter(Choice):
    """Which putter distance you start with.

    short_putter:  30ft (requires accurate shots to green)
    middle_putter: 100ft (best middle-ground starter)
    long_putter:   200ft (requires accurate power)"""
    display_name = "Starting Putter"
    option_short_putter  = 0
    option_middle_putter = 1
    option_long_putter   = 2
    default = 1

class Goal(Choice):
    """This determines the victory condition/goal of the game.

    win_mario_open: Reach the winning score set in gold_trophy_difficulty for Mario Open.
    gold_trophies: Collect the number of trophies set in trophy_count."""
    display_name = "Goal"
    option_win_mario_open = 0
    option_gold_trophies = 1
    default = 0

class GoldTrophyShuffle(Toggle):
    """Add Gold Trophies as shuffled items in the multiworld item pool.

    When disabled, Gold Trophies are collected by reaching the winning score set in gold_trophy_difficulty for each tournament.
    When enabled, Gold Trophies from the five main tournaments are items rather than fixed rewards."""
    display_name = "Gold Trophy Shuffle"
    default = 0

class TrophyAmount(Range):
    """Total number of Gold Trophies in the pool.

    This option only works if gold_trophy_shuffle is enabled. Otherwise, the total number of gold trophies in the pool is automatically set to 5 (6 if Mario Open likeness is greater than 0)."""
    display_name = "Trophy Amount"
    range_start = 0
    range_end = 200
    default = 5

class TrophyCount(Range):
    """This setting does one of two things depending on which goal is selected.

    win_mario_open: Number of Gold Trophies required to access Mario Open. If trophy_count is set to 0, a Mario Open Ticket is added to the item pool instead.
    gold_trophies: Sets the amount of gold trophies required to goal. trophy_count must be greater than 0 and also less than or equal to trophy_amount for this option.
    
    If gold_trophy_shuffle is disabled, the maximum value is 5 (6 if Mario Open likeness is greater than 0 and goal is set to gold_trophies).
    If gold_trophy_shuffle is enabled, the maximum value is 200."""
    display_name = "Trophy Count"
    range_start = 0
    range_end = 200
    default = 2

class GoldTrophyDifficulty(Range):
    """Score required to earn a Gold Trophy in each tournament.

    Each number subtracts one stroke, starting at -10.
    0:  -10 (8 pars + 10 birdies)
    8:  -18 (0 pars + 18 birdies)
    20: -30 (12 eagles + 6 birdies)"""
    display_name = "Gold Trophy Difficulty"
    range_start = 0
    range_end = 20
    default = 4

class NumberOfTournaments(Range):
    """Number of required tournaments to include in the pool when gold_trophy_shuffle is enabled. If win_mario_open is selected, the maximum value is 5.
    
    This option only works for limited and required_courses_only tournament logic.
    If gold_trophy_shuffle is disabled, this value is automatically set equal to trophy_count.

    Which tournaments that get included is determined by the option below (likeliness). Make sure that this value does not exceed the number of tournaments with a likeliness greater than 0.
    Set this to -1 if you want all tournaments (it will auto-calculate the maximum amount of tournaments based on the likeliness values set)."""
    display_name = "Number of Tournaments"
    range_start = -1
    range_end = 6
    default = -1

class TournamentLikeliness(OptionCounter):
    """Likeliness of each tournament to be included in the pool. Each number can go as high as you want (kind of). The greater the number, the more likely that tournament will be selected.

    If goal is set to win_mario_open, then Mario Open likeliness will be ignored.
    If goal is set to gold_trophies, you can add Mario Open to the pool by setting the likeliness to be greater than 0 here. Note that this also adds an additional Gold Trophy to the pool if gold_trophy_shuffle is disabled.

    If gold_trophy_shuffle is disabled, make sure that the number of tournaments in the pool is greater than or equal to trophy_count.
    
    For disabled tournament logic, any tournament set to 0 will be removed from the pool completely.
    For both limited and required_courses_only, this determines which tournaments will likely be selected as required to win."""
   
    display_name = "Likeliness of Tournaments"
    # all keys must be present and values must be integers >= 0
    schema = Schema({
        "1. Toad Tournament": int,
        "2. Koopa Cup": int,
        "3. Shy Guy International": int,
        "4. Yoshi Championship": int,
        "5. Boo Classic": int,
        "6. Mario Open": int,
    })
    min = 0
    default = {
        "1. Toad Tournament": 1,
        "2. Koopa Cup": 1,
        "3. Shy Guy International": 1,
        "4. Yoshi Championship": 1,
        "5. Boo Classic": 1,
        "6. Mario Open": 0,
    }

class CourseDifficulty(Choice):
    """Determines the club threshold for getting certain scores on each hole.
    difficult may require you to re-roll wind RNG multiple times.

    NOT YET IMPLEMENTED — enabling this option has no effect."""
    display_name = "Course Difficulty (Coming Soon)"
    option_basic = 0
    option_advanced = 1
    option_difficult = 2
    default = 0

class WindDifficulty(Range):
    """Maximum wind speed per hole."""
    display_name = "Wind Difficulty"
    range_start = 0
    range_end = 21
    default = 10

class Windsanity(Toggle):
    """Wind speed and direction changes after every shot."""
    display_name = "Wind Sanity"
    default = 0

class Pinsanity(Toggle):
    """Pin location changes after every shot. This includes putting."""
    display_name = "Pin Sanity"
    default = 0

class Ringshotsanity(Toggle):
    """Add a location for every Ring Shot challenge.

    Toad Highlands - Ring Shot Ticket is added as a starting item by default when enabled."""
    display_name = "Ring Shot Sanity"
    default = 1

class Parsanity(Toggle):
    """Add a location for achieving par on every tournament hole."""
    display_name = "Par Sanity"
    default = 0

class Holesanity(Toggle):
    """Add a location for every individual tournament hole completion."""
    display_name = "Hole Sanity"
    default = 0

class Minigolfsanity(Toggle):
    """Add a location for every Mini Golf hole completion.

    NOT YET IMPLEMENTED — enabling this option has no effect."""
    display_name = "Mini Golf Sanity (Coming Soon)"
    default = 0

class Versussanity(Toggle):
    """Add a location for every Character Match victory.

    NOT YET IMPLEMENTED — enabling this option has no effect."""
    display_name = "Versus Sanity (Coming Soon)"
    default = 0

class Clubsanity(Toggle):
    """Individual clubs will be added to the item pool.

    NOT YET IMPLEMENTED — enabling this option has no effect."""
    display_name = "Club Sanity (Coming Soon)"
    default = 0

class Charactersanity(Toggle):
    """Characters will be added to the item pool.
    Maple and Metal Mario are already added by default.

    NOT YET IMPLEMENTED — enabling this option has no effect."""
    display_name = "Club Sanity (Coming Soon)"
    default = 0

class TrapFillPercentage(Range):
    """Replace a percentage of junk items in the item pool with random traps."""
    display_name = "Trap Fill Percentage"
    range_start = 0
    range_end = 100
    default = 5

class TerribleLieTrapPercentage(Range):
    """Likelihood of receiving a terrible lie trap."""
    display_name = "Terrible Lie Trap Weight"
    range_start = 0
    range_end = 100
    default = 0

class RainTrapPercentage(Range):
    """Likelihood of receiving a rain trap."""
    display_name = "Rain Trap Weight"
    range_start = 0
    range_end = 100
    default = 0

class HurricaneTrapPercentage(Range):
    """Likelihood of receiving a hurricane trap."""
    display_name = "Hurricane Trap Weight"
    range_start = 0
    range_end = 100
    default = 0

class FastMeterTrapPercentage(Range):
    """Likelihood of receiving a Fast Shot Meter Trap."""
    display_name = "Fast Meter Trap Weight"
    range_start = 0
    range_end = 100
    default = 0

@dataclass
class MG64Options(PerGameCommonOptions):
    start_inventory_from_pool: StartInventoryPool
    limit_tournament_logic: LimitTournamentLogic
    starting_putter: StartingPutter
    goal: Goal
    gold_trophy_shuffle: GoldTrophyShuffle
    trophy_amount: TrophyAmount
    trophy_count: TrophyCount
    gold_trophy_difficulty: GoldTrophyDifficulty
    number_of_tournaments: NumberOfTournaments
    tournament_likeliness: TournamentLikeliness
    course_difficulty: CourseDifficulty
    wind_difficulty: WindDifficulty
    windsanity: Windsanity
    pinsanity: Pinsanity
    ringshotsanity: Ringshotsanity
    parsanity: Parsanity
    holesanity: Holesanity
    minigolfsanity: Minigolfsanity
    clubsanity: Clubsanity
    charactersanity: Charactersanity
    versussanity: Versussanity
    death_link: DeathLink
    trap_fill_percentage: TrapFillPercentage
    terrible_lie_trap_percentage: TerribleLieTrapPercentage
    rain_trap_percentage: RainTrapPercentage
    hurricane_trap_percentage: HurricaneTrapPercentage
    fast_meter_trap_percentage: FastMeterTrapPercentage