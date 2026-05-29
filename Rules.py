from typing import Callable
from BaseClasses import CollectionState

# Rule primitives

def _has(item: str, player: int) -> Callable[[CollectionState], bool]:
    return lambda state: state.has(item, player)

def _has_any(*items: str, player: int) -> Callable[[CollectionState], bool]:
    return lambda state: any(state.has(i, player) for i in items)

# Character/club rule patterns
#
# A: (Peach AND Woods) OR Maple OR Metal Mario
# B: (Peach AND Irons) OR Maple OR Metal Mario
# C: (Peach AND (Power Shot OR Woods)) OR Maple OR Metal Mario
# D: (Peach AND Power Shot AND Woods) OR (Maple AND Woods) OR Metal Mario
# E: Maple OR Metal Mario
# F: (Peach AND Woods) OR (Maple AND (Power Shot OR Woods)) OR Metal Mario
# G: Peach AND Approach Shot
# H: Wedges AND ((Peach AND Woods) OR Maple OR Metal Mario)
# I: (Maple AND Power Shot AND Woods) OR (Metal Mario AND Woods)
# J: Peach OR Maple OR Metal Mario
# K: Short Putter AND ((Maple AND Power Shot AND Woods) OR (Metal Mario AND Woods))
# PAR: Irons

def rule_a(state: CollectionState, player: int) -> bool:
    return (
        (state.has("Peach", player) and state.has("Woods", player))
        or state.has("Maple", player)
        or state.has("Metal Mario", player)
    )

def rule_b(state: CollectionState, player: int) -> bool:
    return (
        (state.has("Peach", player) and state.has("Irons", player))
        or state.has("Maple", player)
        or state.has("Metal Mario", player)
    )

def rule_c(state: CollectionState, player: int) -> bool:
    return (
        (state.has("Peach", player) and (state.has("Power Shot", player) or state.has("Woods", player)))
        or state.has("Maple", player)
        or state.has("Metal Mario", player)
    )

def rule_d(state: CollectionState, player: int) -> bool:
    return (
        (state.has("Peach", player) and state.has("Power Shot", player) and state.has("Woods", player))
        or (state.has("Maple", player) and state.has("Woods", player))
        or state.has("Metal Mario", player)
    )

def rule_e(state: CollectionState, player: int) -> bool:
    return state.has("Maple", player) or state.has("Metal Mario", player)

def rule_f(state: CollectionState, player: int) -> bool:
    return (
        (state.has("Peach", player) and state.has("Woods", player))
        or (state.has("Maple", player) and (state.has("Power Shot", player) or state.has("Woods", player)))
        or state.has("Metal Mario", player)
    )

def rule_g(state: CollectionState, player: int) -> bool:
    return state.has("Peach", player) and state.has("Approach Shot", player)

def rule_h(state: CollectionState, player: int) -> bool:
    return state.has("Wedges", player) and (
        (state.has("Peach", player) and state.has("Woods", player))
        or state.has("Maple", player)
        or state.has("Metal Mario", player)
    )

def rule_i(state: CollectionState, player: int) -> bool:
    return (
        (state.has("Maple", player) and state.has("Power Shot", player) and state.has("Woods", player))
        or (state.has("Metal Mario", player) and state.has("Woods", player))
    )

def rule_j(state: CollectionState, player: int) -> bool:
    return (
        state.has("Peach", player)
        or state.has("Maple", player)
        or state.has("Metal Mario", player)
    )

def rule_k(state: CollectionState, player: int) -> bool:
    return (
        state.has("Short Putter", player) and (
        (state.has("Maple", player) and state.has("Power Shot", player) and state.has("Woods", player))
        or (state.has("Metal Mario", player) and state.has("Woods", player)))
    )

def rule_par(state: CollectionState, player: int) -> bool:
    return state.has("Irons", player)

# Per-hole birdie badge rules
# Format: {tournament_name: {hole_number: rule_fn}}

_BIRDIE_RULES = {
    "Toad Tournament": {
        1:  rule_a, 2:  rule_b, 3:  rule_c, 4:  rule_c,
        5:  rule_a, 6:  rule_b, 7:  rule_d, 8:  rule_c,
        9:  rule_d, 10: rule_b, 11: rule_a, 12: rule_b,
        13: rule_c, 14: rule_a, 15: rule_a, 16: rule_b,
        17: rule_b, 18: rule_d,
    },
    "Koopa Cup": {
        1:  rule_a, 2:  rule_a, 3:  rule_c, 4:  rule_a,
        5:  rule_a, 6:  rule_c, 7:  rule_a, 8:  rule_b,
        9:  rule_a, 10: rule_a, 11: rule_a, 12: rule_b,
        13: rule_c, 14: rule_d, 15: rule_d, 16: rule_b,
        17: rule_c, 18: rule_c,
    },
    "Shy Guy International": {
        1:  rule_a, 2:  rule_b, 3:  rule_c, 4:  rule_a,
        5:  rule_d, 6:  rule_d, 7:  rule_c, 8:  rule_d,
        9:  rule_c, 10: rule_d, 11: rule_d, 12: rule_c,
        13: rule_a, 14: rule_a, 15: rule_b, 16: rule_c,
        17: rule_a, 18: rule_d,
    },
    "Yoshi Championship": {
        1:  rule_a, 2:  rule_d, 3:  rule_c, 4:  rule_b,
        5:  rule_d, 6:  rule_c, 7:  rule_a, 8:  rule_d,
        9:  rule_a, 10: rule_a, 11: rule_a, 12: rule_b,
        13: rule_a, 14: rule_d, 15: rule_a, 16: rule_a,
        17: rule_d, 18: rule_c,
    },
    "Boo Classic": {
        1:  rule_a, 2:  rule_d, 3:  rule_a, 4:  rule_a,
        5:  rule_a, 6:  rule_d, 7:  rule_a, 8:  rule_b,
        9:  rule_d, 10: rule_a, 11: rule_a, 12: rule_a,
        13: rule_d, 14: rule_a, 15: rule_a, 16: rule_d,
        17: rule_a, 18: rule_a,
    },
    "Mario Open": {
        1:  rule_b, 2:  rule_d, 3:  rule_a, 4:  rule_a,
        5:  rule_f, 6:  rule_b, 7:  rule_b, 8:  rule_a,
        9:  rule_d, 10: rule_a, 11: rule_a, 12: rule_c,
        13: rule_a, 14: rule_a, 15: rule_d, 16: rule_a,
        17: rule_c, 18: rule_d,
    },
}

# Gold/Silver/Bronze trophy rules per tournament (Gold is victory for Mario Open)
_TROPHY_RULES = {
    "Toad Tournament":       {"Gold": rule_d, "Silver": rule_a, "Bronze": rule_b},
    "Koopa Cup":             {"Gold": rule_d, "Silver": rule_a, "Bronze": rule_b},
    "Shy Guy International": {"Gold": rule_d, "Silver": rule_a, "Bronze": rule_b},
    "Yoshi Championship":    {"Gold": rule_d, "Silver": rule_a, "Bronze": rule_b},
    "Boo Classic":           {"Gold": rule_d, "Silver": rule_a, "Bronze": rule_b},
    "Mario Open":            {"Silver": rule_a, "Bronze": rule_b},
}

# Ring Shot rules per course: {location_name_suffix: rule_fn}
_RING_SHOT_RULES = {
    "Toad Highlands Ring Shot 1 - Give It a Shot!":        rule_b,
    "Toad Highlands Ring Shot 2 - Climb That Hill!":       rule_b,
    "Toad Highlands Ring Shot 3 - Ring in the Valley":     rule_b,
    "Toad Highlands Ring Shot 4 - 3 Rings Above the Pond": rule_b,
    "Toad Highlands Ring Shot 5 - Creek Crossing":         rule_e,
    "Toad Highlands Ring Shot 6 - Every Which Way!":       rule_b,

    "Koopa Park Ring Shot 1 - R-RR-Ring!":              rule_b,
    "Koopa Park Ring Shot 2 - Arch at Forked Creek":    rule_b,
    "Koopa Park Ring Shot 3 - Switchback Swinging!":    rule_b,
    "Koopa Park Ring Shot 4 - Hide-and-Go-Ring!":       rule_f,
    "Koopa Park Ring Shot 5 - Power Past the Pond!":    rule_a,
    "Koopa Park Ring Shot 6 - Arches Here & There":     rule_a,

    "Shy Guy Desert Ring Shot 1 - The Anthill Bunker":          rule_b,
    "Shy Guy Desert Ring Shot 2 - Cactus Arms":                 rule_b,
    "Shy Guy Desert Ring Shot 3 - Pyramid Ring":                rule_a,
    "Shy Guy Desert Ring Shot 4 - Center of the Bull's-Eye":    rule_b,
    "Shy Guy Desert Ring Shot 5 - Shoot for the Stones!":       rule_f,
    "Shy Guy Desert Ring Shot 6 - Sand Dune Summit":            rule_f,

    "Yoshi's Island Ring Shot 1 - Doughnut Hole":        rule_g,
    "Yoshi's Island Ring Shot 2 - Scraping the Cliff":   rule_a,
    "Yoshi's Island Ring Shot 3 - Dunk the Bunker!":     rule_b,
    "Yoshi's Island Ring Shot 4 - Drop into the Valley!": rule_b,
    "Yoshi's Island Ring Shot 5 - Arches in the Hills":  rule_b,
    "Yoshi's Island Ring Shot 6 - Zig and Zag":          rule_a,

    "Boo Valley Ring Shot 1 - The Bottleneck":          rule_b,
    "Boo Valley Ring Shot 2 - Past the Peak":           rule_c,
    "Boo Valley Ring Shot 3 - The Egg Hill":            rule_a,
    "Boo Valley Ring Shot 4 - Emerging from the Mist":  rule_b,
    "Boo Valley Ring Shot 5 - Valley in the Valley":    rule_b,
    "Boo Valley Ring Shot 6 - Duck and Dodge!":         rule_c,

    "Mario's Star Ring Shot 1 - Bloober Calamari Rings": rule_h,
    "Mario's Star Ring Shot 2 - Skull & Bones":          rule_b,
    "Mario's Star Ring Shot 3 - Bowser's Big Mouth":     rule_a,
    "Mario's Star Ring Shot 4 - Lakitu's Glasses":       rule_b,
    "Mario's Star Ring Shot 5 - Sorry, Bob-omb!":        rule_e,
    "Mario's Star Ring Shot 6 - Princess Peach's Ring":  rule_c,
}

_CHARACTER_MATCH_RULES = {
    "Character Match - Plum":        rule_j,
    "Character Match - Charlie":     rule_j,
    "Character Match - Peach":       rule_j,
    "Character Match - Baby Mario":  rule_j,
    "Character Match - Luigi":       rule_a,
    "Character Match - Yoshi":       rule_a,
    "Character Match - Sonny":       rule_a,
    "Character Match - Maple":       rule_a,
    "Character Match - Wario":       rule_d,
    "Character Match - Harry":       rule_d,
    "Character Match - Mario":       rule_d,
    "Character Match - Donkey Kong": rule_i,
    "Character Match - Bowser":      rule_i,
    "Character Match - Metal Mario": rule_i,
}

# Rule application

def set_rules(world) -> None:
    player  = world.player
    mw      = world.multiworld
    options = world.options

    mw.completion_condition[player] = lambda state: state.has("Victory", player)

    _set_region_rules(world)
    _set_location_rules(world)

def _set_region_rules(world) -> None:
    player  = world.player
    mw      = world.multiworld
    options = world.options

    def entrance(source: str, dest: str):
        return mw.get_entrance(f"{source} -> {dest}", player)

    entrance("Menu", "Toad Tournament").access_rule = \
        lambda state: state.has("Toad Tournament Ticket", player)

    entrance("Menu", "Koopa Cup").access_rule = \
        lambda state: state.has("Koopa Cup Ticket", player)

    entrance("Menu", "Shy Guy International").access_rule = \
        lambda state: state.has("Shy Guy International Ticket", player)

    entrance("Menu", "Yoshi Championship").access_rule = \
        lambda state: state.has("Yoshi Championship Ticket", player)

    entrance("Menu", "Boo Classic").access_rule = \
        lambda state: state.has("Boo Classic Ticket", player)

    _set_mario_open_rule(world)

    entrance("Menu", "Toad Highlands - Ring Shot").access_rule = \
        lambda state: state.has("Toad Highlands - Ring Shot Ticket", player)

    entrance("Menu", "Koopa Park - Ring Shot").access_rule = \
        lambda state: state.has("Koopa Park - Ring Shot Ticket", player)

    entrance("Menu", "Shy Guy Desert - Ring Shot").access_rule = \
        lambda state: state.has("Shy Guy Desert - Ring Shot Ticket", player)

    entrance("Menu", "Yoshi's Island - Ring Shot").access_rule = \
        lambda state: state.has("Yoshi's Island - Ring Shot Ticket", player)

    entrance("Menu", "Boo Valley - Ring Shot").access_rule = \
        lambda state: state.has("Boo Valley - Ring Shot Ticket", player)

    entrance("Menu", "Mario's Star - Ring Shot").access_rule = \
        lambda state: state.has("Mario's Star - Ring Shot Ticket", player)

    entrance("Menu", "Luigi's Garden").access_rule = \
        lambda state: state.has("Luigi's Garden Ticket", player)

    entrance("Menu", "Peach's Castle").access_rule = \
        lambda state: state.has("Peach's Castle Ticket", player)

def _set_mario_open_rule(world) -> None:
    player  = world.player
    mw      = world.multiworld
    options = world.options

    tournament_weights = options.tournament_likeliness.value
    entrance = mw.get_entrance("Menu -> Mario Open", player)
    count    = options.trophy_count.value

    if count == 0 or (options.goal.value != 0 and tournament_weights.get("6. Mario Open") != 0):
        entrance.access_rule = lambda state: state.has("Mario Open Ticket", player)
    else:
        entrance.access_rule = lambda state: state.has("Gold Trophy", player, count)

def _set_location_rules(world) -> None:
    player = world.player
    mw     = world.multiworld

    def set_rule(name: str, rule_fn) -> None:
        try:
            loc = mw.get_location(name, player)
            loc.access_rule = lambda state, fn=rule_fn: fn(state, player)
        except KeyError:
            pass

    for tournament, hole_rules in _BIRDIE_RULES.items():
        for hole, rule_fn in hole_rules.items():
            set_rule(f"{tournament} - Birdie Badge {hole}", rule_fn)

    for tournament, trophy_rules in _TROPHY_RULES.items():
        for medal, rule_fn in trophy_rules.items():
            set_rule(f"{tournament} - {medal} Trophy", rule_fn)

    for loc_name, rule_fn in _RING_SHOT_RULES.items():
        set_rule(loc_name, rule_fn)

    for loc_name, rule_fn in _CHARACTER_MATCH_RULES.items():
        set_rule(loc_name, rule_fn)

    for tournament in _BIRDIE_RULES:
        for hole in range(1, 19):
            set_rule(f"{tournament} - Hole {hole} Par", rule_par)

    _set_victory_rule(world)

def _set_victory_rule(world) -> None:
    player  = world.player
    mw      = world.multiworld
    options = world.options

    # basic (-16) and advanced (-18) are achievable with any strong combo.
    # difficult (-20) and extreme (-22) require eagles, which Peach cannot
    # reliably achieve even fully equipped, so only Maple or Metal Mario qualify.
    # TODO
    difficulty = options.gold_trophy_difficulty.value

    if difficulty <= 1:
        victory_rule = rule_k
    else:
        victory_rule = rule_k

    try:
        loc = mw.get_location("Mario Open - Gold Trophy", player)
        loc.access_rule = lambda state: victory_rule(state, player)
    except KeyError:
        pass

    def rule_gold_trophies(state: CollectionState, player: int) -> bool:
        return state.has("Gold Trophy", player, world.options.trophy_count.value)

    try:
        loc = mw.get_location("Trophy Victory - Goal", player)
        loc.access_rule = lambda state: rule_gold_trophies(state, player)
    except KeyError:
        pass
