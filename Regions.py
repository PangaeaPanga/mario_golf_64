from typing import Dict, NamedTuple, List


class MG64RegionData(NamedTuple):
    connecting_regions: List[str] = []


region_data_table: Dict[str, MG64RegionData] = {
    "Menu": MG64RegionData([
        "Toad Tournament",
        "Koopa Cup",
        "Shy Guy International",
        "Yoshi Championship",
        "Boo Classic",
        "Mario Open",
        "Toad Highlands - Ring Shot",
        "Koopa Park - Ring Shot",
        "Shy Guy Desert - Ring Shot",
        "Yoshi's Island - Ring Shot",
        "Boo Valley - Ring Shot",
        "Mario's Star - Ring Shot",
        "Luigi's Garden",
        "Peach's Castle",
        "Character Match",
        "Trophy Victory",
    ]),

    "Toad Tournament":       MG64RegionData(),
    "Koopa Cup":             MG64RegionData(),
    "Shy Guy International": MG64RegionData(),
    "Yoshi Championship":    MG64RegionData(),
    "Boo Classic":           MG64RegionData(),
    "Mario Open":            MG64RegionData(),

    "Toad Highlands - Ring Shot": MG64RegionData(),
    "Koopa Park - Ring Shot":     MG64RegionData(),
    "Shy Guy Desert - Ring Shot": MG64RegionData(),
    "Yoshi's Island - Ring Shot": MG64RegionData(),
    "Boo Valley - Ring Shot":     MG64RegionData(),
    "Mario's Star - Ring Shot":   MG64RegionData(),

    "Luigi's Garden": MG64RegionData(),
    "Peach's Castle": MG64RegionData(),

    "Character Match": MG64RegionData(),
    "Trophy Victory": MG64RegionData(),
}
