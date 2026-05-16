from dataclasses import dataclass
from Options import Choice, Toggle, Range, DeathLink, PerGameCommonOptions, StartInventoryPool

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

class TrophyCount(Range):
    """Number of Gold Trophies required to access Mario Open.

    When set to 0, a Mario Open Ticket is added to the item pool instead.
    When set to 1-5, the ticket is never in the pool and Gold Trophies are
    collected from the five main tournaments gate entry."""
    display_name = "Trophy Count"
    range_start = 0
    range_end = 5
    default = 2

class LimitTournamentLogic(Choice):
    """Sets how the item pool is distributed within tournament courses.

    disabled: Progression items may appear in any course.
    limited: Progression items will only appear in required courses and ringshot/mini golf (if enabled).
    required_courses_only: Courses that are not required will be completely removed from the item pool.
    
    limited is NOT YET IMPLEMENTED. disabled and required_courses_only work."""
    display_name = "Limit Tournament Logic"
    option_disabled = 0
    option_limited = 1
    option_required_courses_only = 2
    default = 0

class GoldTrophyShuffle(Toggle):
    """Add Gold Trophies as shuffled items in the multiworld item pool.

    When enabled, Gold Trophies from the five main tournaments are items
    rather than fixed rewards."""
    display_name = "Gold Trophy Shuffle"
    default = 0

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

class CourseDifficulty(Choice):
    """Determines the club threshold for getting certain scores on each hole.
    Difficult may require you to re-roll wind RNG multiple times.

    NOT YET IMPLEMENTED — enabling this option has no effect."""
    display_name = "Course Difficulty (Coming Soon)"
    option_basic = 0
    option_advanced = 1
    option_difficult = 2
    default = 0

class WindDifficulty(Range):
    """Maximum wind speed per hole selected when loading a save file."""
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
    starting_putter: StartingPutter
    trophy_count: TrophyCount
    limit_tournament_logic: LimitTournamentLogic
    gold_trophy_shuffle: GoldTrophyShuffle
    gold_trophy_difficulty: GoldTrophyDifficulty
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