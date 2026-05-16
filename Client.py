from __future__ import annotations

import asyncio
import json

from CommonClient import ClientCommandProcessor, CommonContext, get_base_parser, gui_enabled, logger, server_loop
from NetUtils import ClientStatus
from Utils import async_start, init_logging

CONNECTION_INITIAL_STATUS    = "Not connected to emulator. Please run connector_mario_golf_64.lua in BizHawk."
CONNECTION_TENTATIVE_STATUS  = "Initial connection made."
CONNECTION_CONNECTED_STATUS  = "Connected to emulator."
CONNECTION_REFUSED_STATUS    = "Connection refused. Is BizHawk open with the connector script running?"
CONNECTION_RESET_STATUS      = "Connection lost. Please restart the connector script."
CONNECTION_TIMING_OUT_STATUS = "Connection timed out. Please restart the connector script."

SOCKET_PORT = 28922

class MarioGolf64CommandProcessor(ClientCommandProcessor):
    def _cmd_n64(self) -> None:
        """Check emulator connection status."""
        if isinstance(self.ctx, MarioGolf64Context):
            logger.info(f"Emulator status: {self.ctx.emulator_status}")

class MarioGolf64Context(CommonContext):
    command_processor = MarioGolf64CommandProcessor
    game             = "Mario Golf 64"
    items_handling   = 0b111

    def __init__(self, server_address: str | None, password: str | None) -> None:
        super().__init__(server_address, password)
        self.emulator_streams: tuple[asyncio.StreamReader, asyncio.StreamWriter] | None = None
        self.emulator_sync_task   = None
        self.emulator_status      = CONNECTION_INITIAL_STATUS
        self.location_names_to_id: dict = {}
        self.pending_traps: list  = []
        self.trap_indices_sent: set = set()  # indices of trap items already queued
        self.death_link_pending   = False  # received death waiting to trigger
        self.death_link_sent_hole = -1     # last hole we sent death on (avoid spam)
        self.awaiting_slot     = False
        self.slot_data: dict   = {}
        self.local_checked_locations: set[int] = set()
        self.location_data_ready = False
        self.items_received_count = 0

        # PopTracker data
        self.current_mode = 0
        self.current_course = 0
        self.current_hole = 0

    async def server_auth(self, password_requested: bool = False) -> None:
        if password_requested and not self.password:
            await super().server_auth(password_requested)
        if not self.auth:
            await self.get_username()
            await self.send_connect()
            return

    def run_gui(self) -> None:
        from kvui import GameManager

        class MarioGolf64Manager(GameManager):
            logging_pairs = [("Client", "Archipelago")]
            base_title    = "Archipelago Mario Golf 64 Client"

        self.ui      = MarioGolf64Manager(self)
        self.ui_task = asyncio.create_task(self.ui.async_run(), name="UI")

    def on_package(self, cmd: str, args: dict) -> None:
        if cmd == "DataPackage":
            for game_data in args.get("data", {}).get("games", {}).values():
                self.location_names_to_id.update(game_data.get("location_name_to_id", {}))
            self.location_data_ready = True

        elif cmd == "Connected":
            self.slot_data = args.get("slot_data", {})
            logger.info("Connected to AP server. Please load Mario Golf 64 in BizHawk and run connector_mario_golf_64.lua.")
            if self.slot_data.get("death_link"):
                async_start(self.update_death_link(True))
                # Request data package for ALL games so we get full location name->id mapping
            async_start(self.send_msgs([{"cmd": "GetDataPackage", "games": ["Mario Golf 64"]}]))
            # Also populate from checked_locations reverse lookup using location_names
            async_start(self._populate_location_names())
            if not self.emulator_sync_task or self.emulator_sync_task.done():
                self.emulator_sync_task = asyncio.create_task(emulator_sync_task(self), name="Emulator Sync")

        elif cmd == "ReceivedItems":
            # Use enumerate position in items_received as the stable unique key.
            # network_item.index is only unique within a single packet, not globally.
            for i, network_item in enumerate(self.items_received):
                item_name = self.item_names.lookup_in_game(network_item.item)
                if isinstance(item_name, str) and "Trap" in item_name:
                    if i not in self.trap_indices_sent:
                        self.trap_indices_sent.add(i)
                        self.pending_traps.append(item_name)
            async_start(self.send_items_to_emulator())

    def on_deathlink(self, data: dict) -> None:
        super().on_deathlink(data)
        self.death_link_pending = True
        async_start(self.send_items_to_emulator())
        logger.info(f"Death Link received from {data.get('source', 'unknown')}!")

    async def _populate_location_names(self) -> None:
        """Populate location_names_to_id from the AP location names lookup."""
        await asyncio.sleep(3)  # Wait for data package to arrive
        if hasattr(self, "location_names") and self.location_names:
            # Scan our game's ID range to build the reverse lookup
            # Manual APworld uses IDs starting at LOC_BASE = 0x4D480000 = 1296564224
            for loc_id in self.missing_locations | self.checked_locations:
                name = self.location_names.lookup_in_game(loc_id)
                if isinstance(name, str) and "Unknown" not in name:
                    self.location_names_to_id[name] = loc_id
            self.location_data_ready = True

    async def send_items_to_emulator(self) -> None:
        if not self.emulator_streams:
            return
        if not self.slot:
            return

        unlocks_word = 0
        courses_word = 0

        for network_item in self.items_received:
            item_name = self.item_names.lookup_in_game(network_item.item)
            if item_name in ITEM_TO_SRAM_BIT:
                addr, bit = ITEM_TO_SRAM_BIT[item_name]
                if addr == 0:
                    unlocks_word |= (1 << bit)
                else:
                    courses_word |= (1 << bit)

        # Count Gold Trophies and unlock Mario Open if threshold met
        gold_trophies = sum(
            1 for item in self.items_received
            if self.item_names.lookup_in_game(item.item) == "Gold Trophy"
        )
        trophy_count = int(self.slot_data.get("trophy_count", 5))
        if trophy_count > 0 and gold_trophies >= trophy_count:
            courses_word |= (1 << 5)  # Mario Open bit

        starting_putter_map = {"short_putter": 0, "middle_putter": 1, "long_putter": 2}
        starting_putter_val = starting_putter_map.get(
            str(self.slot_data.get("starting_putter", "middle_putter")).lower(), 0)
        
        settings = {
            "ringshotsanity":         int(self.slot_data.get("ringshotsanity",         1)),
            "holesanity":             int(self.slot_data.get("holesanity",             0)),
            "parsanity":              int(self.slot_data.get("parsanity",              0)),
            "minigolfsanity":         int(self.slot_data.get("minigolfsanity",         0)),
            "versussanity":           int(self.slot_data.get("versussanity",           0)),
            "starting_putter":        int(self.slot_data.get("starting_putter",        1)),
            "trophy_count":           int(self.slot_data.get("trophy_count",           2)),
            "wind_difficulty":        int(self.slot_data.get("wind_difficulty",       10)),
            "windsanity":             int(self.slot_data.get("windsanity",             0)),
            "pinsanity":              int(self.slot_data.get("pinsanity",              0)),
            "gold_trophy_difficulty": int(self.slot_data.get("gold_trophy_difficulty", 0)),
            "num_gold_trophies":      gold_trophies,
            "death_link":             int(bool(self.slot_data.get("death_link", False))),
        }
        trap = self.pending_traps.pop(0) if self.pending_traps else None
        death_in = 1 if self.death_link_pending else 0
        if death_in:
            self.death_link_pending = False
        payload = json.dumps({
            "unlocks":  unlocks_word,
            "courses":  courses_word,
            "settings": settings,
            "trap":     trap or "",
            "death_in": death_in,
        }) + "\n"
        try:
            _, writer = self.emulator_streams
            writer.write(payload.encode())
            await writer.drain()
        except Exception as exc:
            logger.warning(f"Failed to send to emulator: {exc}")
            self.emulator_streams = None
            self.emulator_status  = CONNECTION_RESET_STATUS

# SRAM bit map (addr 0 = unlocks word, addr 1 = courses word)

ITEM_TO_SRAM_BIT: dict[str, tuple[int, int]] = {
    "Maple":        (0, 0),
    "Metal Mario":  (0, 1),
    "Power Shot":   (0, 2),
    "Woods":        (0, 3),
    "Wedges":       (0, 4),
    "Approach Shot":(0, 5),
    "Short Putter": (0, 6),
    "Middle Putter":(0, 7),
    "Long Putter":  (0, 8),

    "Toad Tournament Ticket":         (1, 0),
    "Koopa Cup Ticket":               (1, 1),
    "Shy Guy International Ticket":   (1, 2),
    "Yoshi Championship Ticket":      (1, 3),
    "Boo Classic Ticket":             (1, 4),
    "Mario Open Ticket":              (1, 5),
    "Luigi's Garden Ticket":          (1, 6),
    "Peach's Castle Ticket":          (1, 7),
    "Toad Highlands - Ring Shot Ticket":  (1, 8),
    "Koopa Park - Ring Shot Ticket":      (1, 9),
    "Shy Guy Desert - Ring Shot Ticket":  (1, 10),
    "Yoshi's Island - Ring Shot Ticket":  (1, 11),
    "Boo Valley - Ring Shot Ticket":      (1, 12),
    "Mario's Star - Ring Shot Ticket":    (1, 13),
}

# Emulator sync loop

async def emulator_sync_task(ctx: MarioGolf64Context) -> None:

    while not ctx.exit_event.is_set():
        if not ctx.emulator_streams:
            await connect_to_emulator(ctx)
            if not ctx.emulator_streams:
                await asyncio.sleep(5)
                continue

        try:
            # Send our state first, Lua always responds
            await ctx.send_items_to_emulator()
            if not ctx.emulator_streams:
                continue

            reader, _ = ctx.emulator_streams
            data = await asyncio.wait_for(reader.readline(), timeout=10)
            if not data:
                raise ConnectionResetError

            payload = json.loads(data.decode())
            await process_emulator_payload(ctx, payload)
            # Handle death sent from Lua
            if payload.get("death_out") and ctx.slot_data.get("death_link"):
                await ctx.send_death("Mario Golf 64")
            
            await handle_tracker_info(ctx, payload)

        except asyncio.TimeoutError:
            ctx.emulator_status = CONNECTION_TIMING_OUT_STATUS
            ctx.emulator_streams = None
        except (ConnectionResetError, ConnectionAbortedError, BrokenPipeError):
            ctx.emulator_status = CONNECTION_RESET_STATUS
            ctx.emulator_streams = None
        except Exception as exc:
            logger.error(f"Emulator sync error: {exc}")
            ctx.emulator_streams = None

        await asyncio.sleep(0.1)

async def handle_tracker_info(ctx: "MarioGolf64Context", payload: dict) -> None:
    new_mode = payload.get("current_mode")
    new_course = payload.get("current_course")
    new_hole = payload.get("current_hole")

    current_mode = ctx.current_mode
    current_course = ctx.current_course
    current_hole = ctx.current_hole

    # Send a bounce message when game mode, course, or hole is changed
    if new_mode != current_mode or new_course != current_course or new_hole != current_hole:
        ctx.current_mode = new_mode
        ctx.current_course = new_course
        ctx.current_hole = new_hole

        await ctx.send_msgs([{
            "cmd": "Bounce",
            "slots": [ctx.slot],
            "data": {
                "modeId": new_mode,
                "courseId": new_course,
                "holeId": new_hole,
            },
        }])

async def connect_to_emulator(ctx: MarioGolf64Context) -> None:
    logger.info(f"Attempting to connect to BizHawk on 127.0.0.1:{SOCKET_PORT}...")
    try:
        reader, writer = await asyncio.open_connection("127.0.0.1", SOCKET_PORT)
        ctx.emulator_streams = (reader, writer)
        ctx.emulator_status  = CONNECTION_CONNECTED_STATUS
        logger.info("Connected to BizHawk emulator.")
    except ConnectionRefusedError:
        ctx.emulator_status = CONNECTION_REFUSED_STATUS
    except Exception as exc:
        ctx.emulator_status = f"Connection error: {exc}"

async def process_emulator_payload(ctx: MarioGolf64Context, payload: dict) -> None:
    if not ctx.server or not ctx.slot:
        return

    new_checks: list[int] = []
    for loc_name in payload.get("locations", []):
        # lookup_in_game returns int if found, or a "Unknown location..." string if not
        loc_id = ctx.location_names.lookup_in_game(loc_name)
        if not isinstance(loc_id, int):
            # Try our own dict as fallback (populated from DataPackage)
            loc_id = ctx.location_names_to_id.get(loc_name)
        if not isinstance(loc_id, int):
            continue  # not in this seed's options
        if loc_id in ctx.checked_locations or loc_id in ctx.local_checked_locations:
            continue
        ctx.local_checked_locations.add(loc_id)
        new_checks.append(loc_id)

    if new_checks:
        async_start(ctx.send_msgs([{"cmd": "LocationChecks", "locations": new_checks}]))

    if not ctx.finished_game and payload.get("gameComplete"):
        await ctx.send_msgs([{"cmd": "StatusUpdate", "status": ClientStatus.CLIENT_GOAL}])
        ctx.finished_game = True

# Entry point

def main() -> None:
    init_logging("MarioGolf64Client")

    async def _main() -> None:
        parser = get_base_parser()
        args   = parser.parse_args()
        ctx    = MarioGolf64Context(args.connect, args.password)
        ctx.server_task = asyncio.create_task(server_loop(ctx), name="Server Loop")

        if gui_enabled:
            ctx.run_gui()
        ctx.run_cli()

        await ctx.exit_event.wait()
        ctx.server_address = None
        await ctx.shutdown()

    asyncio.run(_main())

if __name__ == "__main__":
    main()
