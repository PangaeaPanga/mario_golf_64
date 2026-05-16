from typing import Dict, NamedTuple, Optional
from BaseClasses import Item, ItemClassification

class MG64Item(Item):
    game = "Mario Golf 64"

class MG64ItemData(NamedTuple):
    code: Optional[int]
    classification: ItemClassification

BASE_ID = 0x4D470000

item_data_table: Dict[str, MG64ItemData] = {
    # Tournament Tickets
    "Toad Tournament Ticket":         MG64ItemData(BASE_ID + 0x00, ItemClassification.progression),
    "Koopa Cup Ticket":               MG64ItemData(BASE_ID + 0x01, ItemClassification.progression),
    "Shy Guy International Ticket":   MG64ItemData(BASE_ID + 0x02, ItemClassification.progression),
    "Yoshi Championship Ticket":      MG64ItemData(BASE_ID + 0x03, ItemClassification.progression),
    "Boo Classic Ticket":             MG64ItemData(BASE_ID + 0x04, ItemClassification.progression),
    "Mario Open Ticket":              MG64ItemData(BASE_ID + 0x05, ItemClassification.progression),

    # Ring Shot Tickets
    "Toad Highlands - Ring Shot Ticket":  MG64ItemData(BASE_ID + 0x10, ItemClassification.progression),
    "Koopa Park - Ring Shot Ticket":      MG64ItemData(BASE_ID + 0x11, ItemClassification.progression),
    "Shy Guy Desert - Ring Shot Ticket":  MG64ItemData(BASE_ID + 0x12, ItemClassification.progression),
    "Yoshi's Island - Ring Shot Ticket":  MG64ItemData(BASE_ID + 0x13, ItemClassification.progression),
    "Boo Valley - Ring Shot Ticket":      MG64ItemData(BASE_ID + 0x14, ItemClassification.progression),
    "Mario's Star - Ring Shot Ticket":    MG64ItemData(BASE_ID + 0x15, ItemClassification.progression),

    # Mini Golf Tickets
    "Luigi's Garden Ticket":  MG64ItemData(BASE_ID + 0x20, ItemClassification.progression),
    "Peach's Castle Ticket":  MG64ItemData(BASE_ID + 0x21, ItemClassification.progression),

    # Characters
    "Peach":       MG64ItemData(BASE_ID + 0x30, ItemClassification.progression),
    "Maple":       MG64ItemData(BASE_ID + 0x31, ItemClassification.progression),
    "Metal Mario": MG64ItemData(BASE_ID + 0x32, ItemClassification.progression),

    # Club Abilities
    "Power Shot":    MG64ItemData(BASE_ID + 0x40, ItemClassification.progression),
    "Approach Shot": MG64ItemData(BASE_ID + 0x41, ItemClassification.progression),
    "Woods":         MG64ItemData(BASE_ID + 0x42, ItemClassification.progression),
    "Irons":         MG64ItemData(BASE_ID + 0x43, ItemClassification.progression),
    "Wedges":        MG64ItemData(BASE_ID + 0x44, ItemClassification.progression),
    "Short Putter":  MG64ItemData(BASE_ID + 0x45, ItemClassification.progression),
    "Middle Putter": MG64ItemData(BASE_ID + 0x46, ItemClassification.useful),
    "Long Putter":   MG64ItemData(BASE_ID + 0x47, ItemClassification.useful),

    # Trophy (used as gate for Mario Open)
    "Gold Trophy": MG64ItemData(BASE_ID + 0x50, ItemClassification.progression),

    # Filler
    "Golf Ball":       MG64ItemData(BASE_ID + 0x60, ItemClassification.filler),
    "Titleist Pro V1": MG64ItemData(BASE_ID + 0x61, ItemClassification.filler),
    "TaylorMade TP5x": MG64ItemData(BASE_ID + 0x62, ItemClassification.filler),

    # Traps
    "Terrible Lie Trap":       MG64ItemData(BASE_ID + 0x70, ItemClassification.trap),
    "Rain Trap":               MG64ItemData(BASE_ID + 0x71, ItemClassification.trap),
    "Hurricane Trap":          MG64ItemData(BASE_ID + 0x72, ItemClassification.trap),
    "Fast Shot Meter Trap":    MG64ItemData(BASE_ID + 0x73, ItemClassification.trap),

    # Victory (no code — placed event)
    "Victory": MG64ItemData(None, ItemClassification.progression),
}

item_table: Dict[str, int] = {
    name: data.code
    for name, data in item_data_table.items()
    if data.code is not None
}
