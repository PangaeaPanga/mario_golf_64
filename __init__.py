from typing import Dict, List, TextIO

from BaseClasses import Region, Tutorial, ItemClassification, LocationProgressType
from worlds.AutoWorld import WebWorld, World
from worlds.LauncherComponents import Component, components, Type, launch_subprocess

from .Items import MG64Item, MG64ItemData, item_data_table, item_table
from .Locations import MG64Location, MG64LocationData, location_data_table, location_table
from .Regions import region_data_table
from .Options import MG64Options
from .Rules import set_rules

def run_client() -> None:
    from .Client import main
    launch_subprocess(main, name="Mario Golf 64 Client")

components.append(Component("Mario Golf 64 Client", func=run_client, component_type=Type.CLIENT))

class MG64WebWorld(WebWorld):
    theme = "grass"
    tutorials = [
        Tutorial(
            "Multiworld Setup Guide",
            "A guide to setting up the Mario Golf 64 Archipelago client",
            "English",
            "setup_en.md",
            "setup/en",
            ["PangaeaPanga"],
        )
    ]

class MG64World(World):
    """
    Mario Golf 64 is a golf simulation game for the Nintendo 64. Play as one of
    fourteen characters across six tournaments, ring shot challenges, and mini
    golf courses. Unlock characters, clubs, and courses to conquer the Mario Open.
    """

    game                 = "Mario Golf 64"
    web                  = MG64WebWorld()
    options_dataclass    = MG64Options
    options: MG64Options
    data_version         = 1
    location_name_to_id  = location_table
    item_name_to_id      = item_table

    # Item creation

    def create_item(self, name: str) -> MG64Item:
        data = item_data_table[name]
        return MG64Item(name, data.classification, data.code, self.player)

    def create_filler(self) -> MG64Item:
        return self.create_item(self.get_filler_item_name())

    def get_filler_item_name(self) -> str:
        filler = ["Golf Ball", "Titleist Pro V1", "TaylorMade TP5x"]
        return self.random.choice(filler)
    
        #traps  = ["Terrible Lie Trap", "Rain Trap", "Hurricane Trap", "Fast Shot Meter Trap"]
        #pool   = filler + traps
        #return self.random.choice(pool)
    
        # Percentage of traps are filler. 20% for now
        #filler_type = self.random.randint(1, 100)
        #if filler_type > 20:
            #return self.random.choice(filler)
        #else:
            #return self.random.choice(traps)
    
    def create_trap(self) -> MG64Item:
        return self.create_item(self.get_trap_item_name())
    
    def get_trap_item_name(self) -> str:
        traps  = ["Terrible Lie Trap", "Rain Trap", "Hurricane Trap", "Fast Shot Meter Trap"]

        # Randomly select a trap based on the weighted options
        # If all traps are set to 0, set them to have equal weight
        if self.options.terrible_lie_trap_percentage == 0 and self.options.rain_trap_percentage == 0 and self.options.hurricane_trap_percentage == 0 and self.options.fast_meter_trap_percentage == 0:
            return self.random.choice(traps)
        else:
            selected_trap = self.random.choices(traps, weights=[self.options.terrible_lie_trap_percentage, self.options.rain_trap_percentage, self.options.hurricane_trap_percentage, self.options.fast_meter_trap_percentage], k=1)

            # Since this returns a list with only 1 item, we need to get the trap name this way (I think)
            return selected_trap[0]
    
    # TODO limited logic still sometimes makes you do tickets that aren't required
    def set_tournament_logic(self, logic_option) -> None:
        tournament_locations = [
            "Toad Tournament",
            "Koopa Cup",
            "Shy Guy International",
            "Yoshi Championship",
            "Boo Classic"
        ]
        
        # Calculate which courses are in the pool
        global tournament_tickets
        global tournament_tickets_in_logic
        global trophy_locations
        global tournaments_not_in_logic
        global trophies_in_pool

        indexes_to_remove = []
        tournament_tickets = []

        # Determine how what courses are in logic
        if logic_option == 0:
            pool = tournament_locations
        else:
            pool = self.random.sample(tournament_locations, self.options.trophy_count)

            # Get the list of courses to remove from the pool
            for i, location in enumerate(tournament_locations):
                for j, course in enumerate(pool):
                    if pool[j] in tournament_locations[i]:
                        indexes_to_remove.append(i)
        
        # Tickets and trophies are removed only if limit_tournament_logic is required_courses_only
        if logic_option != 2:
            trophies_in_pool = [val + " - Gold Trophy" for i, val in enumerate(tournament_locations)]
            tournament_tickets = [val + " Ticket" for i, val in enumerate(tournament_locations)]
        else:
            trophies_in_pool = [val + " - Gold Trophy" for i, val in enumerate(tournament_locations) if i in indexes_to_remove]
            tournament_tickets = [val + " Ticket" for i, val in enumerate(tournament_locations) if i in indexes_to_remove]

        tournament_tickets_in_logic = [val + " Ticket" for i, val in enumerate(tournament_locations) if i in indexes_to_remove]
        tournaments_not_in_logic = [val for i, val in enumerate(tournament_locations) if i not in indexes_to_remove]

        # Remove locations for tournaments not in pool
        if logic_option == 2:

            # Remove locations from the pool
            for loc_name, loc_data in list(location_data_table.items()):
                for i, val in enumerate(tournaments_not_in_logic):
                    if tournaments_not_in_logic[i] in loc_name:
                        location_data_table.pop(loc_name)
    
    def write_spoiler_header(self, spoiler_handle: TextIO) -> None:
        if tournament_tickets_in_logic:
            spoiler_handle.write("Tournaments in logic:            " + ', '.join(tournament_tickets_in_logic))

    # Early generation

    def generate_early(self) -> None:
        self.multiworld.push_precollected(self.create_item("Peach"))
        self.multiworld.push_precollected(self.create_item("Irons"))

        # Starting ringshot ticket
        # TODO either change logic so any ringshot ticket can be used, or not start with a ringshot ticket
        if self.options.ringshotsanity:
            self.multiworld.push_precollected(self.create_item("Toad Highlands - Ring Shot Ticket"))

        self.set_tournament_logic(self.options.limit_tournament_logic.value)

        # Starting tournament ticket
        global starting_ticket

        # Determine logic for trophy count
        if self.options.trophy_count != 0:
            if self.options.limit_tournament_logic.value == 0:
                starting_ticket = self.random.choice(tournament_tickets)
            else:
                starting_ticket = self.random.choice(tournament_tickets_in_logic)
            self.multiworld.push_precollected(self.create_item(starting_ticket))

            # Remove the starting ticket from the item pool
            tournament_tickets.remove(starting_ticket)

        elif not self.options.ringshotsanity:
            self.multiworld.push_precollected(self.create_item("Mario Open Ticket"))

        # Starting putter based on YAML option
        starting_putter = getattr(self.options, "starting_putter", None)
        if starting_putter is not None:
            val = starting_putter.value if hasattr(starting_putter, "value") else int(starting_putter)
            putter_map = {0: "Short Putter", 1: "Middle Putter", 2: "Long Putter"}
            putter_item = putter_map.get(val, "Middle Putter")
            
            self.multiworld.push_precollected(self.create_item(putter_item))

    # Region and location creation

    def create_regions(self) -> None:
        player = self.player
        mw     = self.multiworld

        # Regions are named areas of the game. Locations sit inside regions.
        # Entrances are the connections between regions — Rules.py adds
        # access_rule functions to entrances to gate them behind items.
        #
        # Step 1: Create a Region object for every region defined in Regions.py
        #         and add it to self.multiworld.regions so Archipelago can find it.
        regions: Dict[str, Region] = {}
        for name in region_data_table:
            region = Region(name, player, mw)
            regions[name] = region
            mw.regions.append(region)

        # Step 2: Connect regions to each other.
        # region.connect(dest) creates a one-way entrance from region -> dest.
        # The entrance is named "RegionName -> DestName" automatically.
        # Rules.py later calls mw.get_entrance("Menu -> Toad Tournament", player)
        # to attach an access rule to that entrance.
        for name, data in region_data_table.items():
            source = regions[name]
            for dest_name in data.connecting_regions:
                dest = regions[dest_name]
                source.connect(dest)

        # Step 3: Create Location objects and add them to their regions.
        # Each location needs: player, name, address (numeric ID), parent region.
        # Victory locations have address=None and get a locked Victory item placed on them.
        # The Victory item is what triggers goal completion when collected.
        for loc_name, loc_data in location_data_table.items():
            if not self._location_active(loc_data):
                continue

            region = regions[loc_data.region]
            address = None if loc_data.victory else loc_data.address
            location = MG64Location(player, loc_name, address, region)

            # Exclude all locations for not required tournaments if limited_tournament_logic
            if self.options.limit_tournament_logic.value == 1:
                for i, val in enumerate(tournaments_not_in_logic):
                    if tournaments_not_in_logic[i] in loc_name:
                        location.progress_type = LocationProgressType.EXCLUDED

            region.locations.append(location)

            if loc_data.victory:
                location.place_locked_item(self.create_item("Victory"))

        # If gold trophy shuffle is off, Gold Trophies are fixed rewards —
        # place them directly on their locations so they can't be randomised away.
        if not self.options.gold_trophy_shuffle:
            self._lock_gold_trophies(regions)

    # Checks whether a location should exist in this seed.
    # Victory locations always exist.
    # Locations with option=None are always on (e.g. birdie badges, trophies).
    # Locations with an option name (e.g. "ringshotsanity") only exist when
    # that option is enabled in the player's YAML.
    #
    # getattr(self.options, loc_data.option) fetches the option object by name,
    # then .value gives the current setting (0 or 1 for Toggles).
    def _location_active(self, loc_data: MG64LocationData) -> bool:
        if loc_data.victory:
            return True
        if loc_data.option is None:
            return True
        return bool(getattr(self.options, loc_data.option).value)

    # When gold_trophy_shuffle is disabled, Gold Trophies are not randomised.
    # place_locked_item() puts an item directly on a location, preventing
    # Archipelago from placing anything else there.
    def _lock_gold_trophies(self, regions: Dict[str, Region]) -> None:
        for loc_name in trophies_in_pool:
            loc = self.multiworld.get_location(loc_name, self.player)
            if loc is not None:
                loc.place_locked_item(self.create_item("Gold Trophy"))

    # Item pool

    def create_items(self) -> None:
        pool: List[MG64Item] = []

        pool += [self.create_item(name) for name in tournament_tickets]

        #pool += [self.create_item(name) for name in [
            #"Toad Tournament Ticket",
            #"Koopa Cup Ticket",
            #"Shy Guy International Ticket",
            #"Yoshi Championship Ticket",
            #"Boo Classic Ticket",
        #]]

        # Set the number of tournament tickets in the pool based on YAML setting
        #if self.options.limit_tournament_logic.value == 2:
            #pool = self.random.sample(pool, self.options.trophy_count)

        if self.options.trophy_count == 0:
            pool.append(self.create_item("Mario Open Ticket"))

        if self.options.ringshotsanity:
            pool += [self.create_item(name) for name in [
                #"Toad Highlands - Ring Shot Ticket",
                "Koopa Park - Ring Shot Ticket",
                "Shy Guy Desert - Ring Shot Ticket",
                "Yoshi's Island - Ring Shot Ticket",
                "Boo Valley - Ring Shot Ticket",
                "Mario's Star - Ring Shot Ticket",
            ]]

        if self.options.minigolfsanity:
            pool += [self.create_item(name) for name in [
                "Luigi's Garden Ticket",
                "Peach's Castle Ticket",
            ]]

        # Characters and club abilities are always shuffled.
        pool += [self.create_item(name) for name in [
            "Maple",
            "Metal Mario",
            "Power Shot",
            "Approach Shot",
            "Woods",
            "Wedges",
            "Short Putter",
            "Middle Putter",
            "Long Putter",
        ]]

        # Gold Trophies only enter the pool when trophy shuffle is on.
        # There are 5 main tournaments, each awarding one Gold Trophy.
        if self.options.gold_trophy_shuffle:
            pool += [self.create_item("Gold Trophy") for _ in range(5)]

        # Add the pool to the multiworld item list.
        self.multiworld.itempool += pool

        # Count how many locations still have no item placed on them.
        # Subtract the pool size to find how many filler items we need.
        # max(0, ...) prevents negative filler counts if something was over-placed.
        unfilled = sum(
            1 for loc in self.multiworld.get_locations(self.player)
            if not loc.item
        )

        # Set the number of traps to include in the pool
        trap_count = max(0, int((self.options.trap_fill_percentage * 0.01) * unfilled))

        for _ in range(trap_count):
            self.multiworld.itempool.append(self.create_trap())

        # Set the new unfilled amount after traps have been added
        unfilled -= trap_count
        filler_count = max(0, unfilled - len(pool))

        for _ in range(filler_count):
            self.multiworld.itempool.append(self.create_filler())

    # Rules

    def set_rules(self) -> None:
        set_rules(self)

    # Slot data

    def fill_slot_data(self) -> Dict:
        return {
            "starting_putter":        self.options.starting_putter.value,
            "trophy_count":           self.options.trophy_count.value,
            "gold_trophy_shuffle":    self.options.gold_trophy_shuffle.value,
            "ringshotsanity":         self.options.ringshotsanity.value,
            "holesanity":             self.options.holesanity.value,
            "parsanity":              self.options.parsanity.value,
            "minigolfsanity":         self.options.minigolfsanity.value,
            "versussanity":           self.options.versussanity.value,
            "wind_difficulty":        self.options.wind_difficulty.value,
            "windsanity":             self.options.windsanity.value,
            "pinsanity":              self.options.pinsanity.value,
            "gold_trophy_difficulty": self.options.gold_trophy_difficulty.value,
            "death_link":             self.options.death_link.value,
        }
