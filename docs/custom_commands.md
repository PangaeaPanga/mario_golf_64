# Custom Commands

The Mario Golf 64 Client supports custom commands that perform a various amount of functions. Commands that include `<value>` need an additional parameter passed in order to function. The valid values for each command are listed below their respective command.

- `/n64` checks the emulator connection status
- `/tracker` toggles the built-in Universal Tracker on or off. Client restart is required (this value can also be manually edited in host.yaml under `enable_tracker`)
- `/slot_data` lists the slot data. Note that this gets reset to its original values when the client is reopened
- `/wind_difficulty` `<value>` sets maximum possible wind. This takes effect on next hole reload (or next shot if windsanity is enabled)
  - `<value>` must be a number between `0` and `21`
- `/windsanity` `<value>` toggles windsanity on or off
  - `0` disables this setting
  - `1` enables this setting
- `/pinsanity` `<value>` toggles pinsanity on or off
  - `0` disables this setting
  - `1` enables this setting
- `/death_link` `<value>` toggles death link on or off (both receiving and sending)
  - `0` disables this setting
  - `1` enables this setting
- `/receive_death_link` `<value>` toggles receiving death link on or off
  - `0` disables this setting
  - `1` enables this setting
- `/death_link_on_bad_shot` `<value>` toggles death link on water hazard or out-of-bounds on or off
  - `0` disables this setting
  - `1` enables this setting
- `/death_link_on_bogey` `<value>` toggles death link on bogey or worse on or off
  - `0` disables this setting
  - `1` enables this setting