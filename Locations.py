from typing import Dict, NamedTuple, Optional
from BaseClasses import Location

class MG64Location(Location):
    game = "Mario Golf 64"

class MG64LocationData(NamedTuple):
    region: str
    address: int
    option: Optional[str] = None  # None = always on; otherwise the option name that enables it
    victory: bool = False

LOC_BASE = 0x4D480000

# Helpers

def _tournament_locs(name: str, base: int) -> Dict[str, MG64LocationData]:
    locs: Dict[str, MG64LocationData] = {}
    for i in range(1, 19):
        locs[f"{name} - Birdie Badge {i}"] = MG64LocationData(name, base + (i - 1))
    locs[f"{name} - Silver Trophy"] = MG64LocationData(name, base + 0x12)
    locs[f"{name} - Bronze Trophy"] = MG64LocationData(name, base + 0x13)
    locs[f"{name} - Gold Trophy"]   = MG64LocationData(name, base + 0x14)
    return locs

def _hole_clear_locs(name: str, base: int) -> Dict[str, MG64LocationData]:
    locs: Dict[str, MG64LocationData] = {}
    for i in range(1, 19):
        locs[f"{name} - Hole {i} Clear"] = MG64LocationData(name, base + (i - 1), "holesanity")
    locs[f"{name} - Clear"] = MG64LocationData(name, base + 0x12, "holesanity")
    return locs

def _par_locs(name: str, base: int) -> Dict[str, MG64LocationData]:
    locs: Dict[str, MG64LocationData] = {}
    for i in range(1, 19):
        locs[f"{name} - Hole {i} Par"] = MG64LocationData(name, base + (i - 1), "parsanity")
    return locs

def _mini_golf_locs(name: str, base: int) -> Dict[str, MG64LocationData]:
    locs: Dict[str, MG64LocationData] = {}
    for i in range(1, 19):
        locs[f"{name} - Hole {i} Clear"] = MG64LocationData(name, base + (i - 1), "minigolfsanity")
    locs[f"{name} - Clear"] = MG64LocationData(name, base + 0x12, "minigolfsanity")
    return locs

# Location data table

location_data_table: Dict[str, MG64LocationData] = {}

location_data_table.update(_tournament_locs("Toad Tournament",       LOC_BASE + 0x0000))
location_data_table.update(_tournament_locs("Koopa Cup",             LOC_BASE + 0x0020))
location_data_table.update(_tournament_locs("Shy Guy International", LOC_BASE + 0x0040))
location_data_table.update(_tournament_locs("Yoshi Championship",    LOC_BASE + 0x0060))
location_data_table.update(_tournament_locs("Boo Classic",           LOC_BASE + 0x0080))
location_data_table.update(_tournament_locs("Mario Open",            LOC_BASE + 0x00A0))

# Mario Open Gold Trophy is the victory location.
location_data_table["Mario Open - Gold Trophy"] = MG64LocationData(
    "Mario Open", LOC_BASE + 0x00B4, victory=True
)

_ring_shot_names = {
    "Toad Highlands - Ring Shot": [
        "Give It a Shot!",
        "Climb That Hill!",
        "Ring in the Valley",
        "3 Rings Above the Pond",
        "Creek Crossing",
        "Every Which Way!",
    ],
    "Koopa Park - Ring Shot": [
        "R-RR-Ring!",
        "Arch at Forked Creek",
        "Switchback Swinging!",
        "Hide-and-Go-Ring!",
        "Power Past the Pond!",
        "Arches Here & There",
    ],
    "Shy Guy Desert - Ring Shot": [
        "The Anthill Bunker",
        "Cactus Arms",
        "Pyramid Ring",
        "Center of the Bull's-Eye",
        "Shoot for the Stones!",
        "Sand Dune Summit",
    ],
    "Yoshi's Island - Ring Shot": [
        "Doughnut Hole",
        "Scraping the Cliff",
        "Dunk the Bunker!",
        "Drop into the Valley!",
        "Arches in the Hills",
        "Zig and Zag",
    ],
    "Boo Valley - Ring Shot": [
        "The Bottleneck",
        "Past the Peak",
        "The Egg Hill",
        "Emerging from the Mist",
        "Valley in the Valley",
        "Duck and Dodge!",
    ],
    "Mario's Star - Ring Shot": [
        "Bloober Calamari Rings",
        "Skull & Bones",
        "Bowser's Big Mouth",
        "Lakitu's Glasses",
        "Sorry, Bob-omb!",
        "Princess Peach's Ring",
    ],
}

_ring_shot_bases = {
    "Toad Highlands - Ring Shot": LOC_BASE + 0x0100,
    "Koopa Park - Ring Shot":     LOC_BASE + 0x0110,
    "Shy Guy Desert - Ring Shot": LOC_BASE + 0x0120,
    "Yoshi's Island - Ring Shot": LOC_BASE + 0x0130,
    "Boo Valley - Ring Shot":     LOC_BASE + 0x0140,
    "Mario's Star - Ring Shot":   LOC_BASE + 0x0150,
}

for region, names in _ring_shot_names.items():
    base = _ring_shot_bases[region]
    course_prefix = region.replace(" - Ring Shot", "")
    for i, subtitle in enumerate(names):
        loc_name = f"{course_prefix} Ring Shot {i + 1} - {subtitle}"
        location_data_table[loc_name] = MG64LocationData(region, base + i, "ringshotsanity")

location_data_table.update(_hole_clear_locs("Toad Tournament",       LOC_BASE + 0x0200))
location_data_table.update(_hole_clear_locs("Koopa Cup",             LOC_BASE + 0x0220))
location_data_table.update(_hole_clear_locs("Shy Guy International", LOC_BASE + 0x0240))
location_data_table.update(_hole_clear_locs("Yoshi Championship",    LOC_BASE + 0x0260))
location_data_table.update(_hole_clear_locs("Boo Classic",           LOC_BASE + 0x0280))
location_data_table.update(_hole_clear_locs("Mario Open",            LOC_BASE + 0x02A0))

location_data_table.update(_par_locs("Toad Tournament",       LOC_BASE + 0x0300))
location_data_table.update(_par_locs("Koopa Cup",             LOC_BASE + 0x0320))
location_data_table.update(_par_locs("Shy Guy International", LOC_BASE + 0x0340))
location_data_table.update(_par_locs("Yoshi Championship",    LOC_BASE + 0x0360))
location_data_table.update(_par_locs("Boo Classic",           LOC_BASE + 0x0380))
location_data_table.update(_par_locs("Mario Open",            LOC_BASE + 0x03A0))

location_data_table.update(_mini_golf_locs("Luigi's Garden", LOC_BASE + 0x0400))
location_data_table.update(_mini_golf_locs("Peach's Castle", LOC_BASE + 0x0420))

_character_match_names = [
    "Plum", "Charlie", "Peach", "Baby Mario",
    "Luigi", "Yoshi", "Sonny", "Maple",
    "Wario", "Harry", "Mario", "Donkey Kong",
    "Bowser", "Metal Mario",
]

for i, character in enumerate(_character_match_names):
    location_data_table[f"Character Match - {character}"] = MG64LocationData(
        "Character Match", LOC_BASE + 0x0500 + i, "versussanity"
    )

# Lookup table for the world class

location_table: Dict[str, int] = {
    name: data.address
    for name, data in location_data_table.items()
}
