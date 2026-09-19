-- TODO
-- Handle queue of multiple traps

local socket = require("socket")
-- NOTE: Load this script from C:\ProgramData\Archipelago\ where AP's
-- luasocket library is bundled. Do not load from BizHawk's own Lua folder.

console.clear()
memory.usememorydomain("SRAM")

local function json_encode(t)
  local parts = {}
  for k, v in pairs(t) do
    local key = '"' .. tostring(k) .. '"'
    local val
    if type(v) == "boolean" then
      val = tostring(v)
    elseif type(v) == "number" then
      val = tostring(v)
    elseif type(v) == "string" then
      val = '"' .. v:gsub('"', '\"') .. '"'
    elseif type(v) == "table" then
      local arr = {}
      for _, item in ipairs(v) do
        table.insert(arr, '"' .. tostring(item):gsub('"', '\"') .. '"')
      end
      val = "[" .. table.concat(arr, ",") .. "]"
    else
      val = "null"
    end
    table.insert(parts, key .. ":" .. val)
  end
  return "{" .. table.concat(parts, ",") .. "}"
end

local function json_decode_simple(s)
  local t = {}
  -- [%w_] matches word chars AND underscore (Lua %w does not include underscore)
  for key, val in s:gmatch('"([%w_]+)"%s*:%s*(-?%d+)') do
    t[key] = tonumber(val)
  end
  for key, val in s:gmatch('"([%w_]+)"%s*:%s*"([^"]*)"') do
    if t[key] == nil then t[key] = val end
  end
  local settings_str = s:match('"settings"%s*:%s*(%b{})')
  if settings_str then
    t.settings = {}
    for key, val in settings_str:gmatch('"([%w_]+)"%s*:%s*(-?%d+)') do
      t.settings[key] = tonumber(val)
    end
  end
  return t
end

-- CONSTANTS & STATE  

local SOCKET_PORT = 28922

local STATE_DISCONNECTED = 0
local STATE_CONNECTED    = 1

local cur_state     = STATE_DISCONNECTED
local ap_socket     = nil
local server        = nil
local frame         = 0
local has_connected = false

local unlocks_word = 0
local courses_word = 0
local setting_ringshotsanity          = 0
local setting_holesanity              = 0
local setting_birdiesanity            = 0
local setting_parsanity               = 1
local setting_minigolfsanity          = 0
local setting_versussanity            = 0
local setting_starting_putter         = 1  -- 0=short(30ft), 1=middle, 2=long(100ft)
local setting_trophy_count            = 2
local setting_wind_difficulty         = 10
local setting_windsanity              = 0
local setting_pinsanity               = 0
local setting_gold_trophy_difficulty  = 4
local num_gold_trophies               = 0 -- number of gold trophies collected
local required_courses                = 0

local detected_locations = {}  -- all checks ever found; always resent so Python never misses one (hopefully)
local baseline_sram      = {}  -- ring shot SRAM state at connect time




-- ADDRESSES


local RDRAM = {
  frame_counter            = 0x0C7770,
  p1_held                  = 0x0FBDC0,
  p1_held_directional      = 0x0FBDC2,
  p1_pressed               = 0x0FBDC4,
  p1_pressed_directional   = 0x0FBDC6,
  menu_id                  = 0x1EFFA3,
  game_mode                = 0x1B608F,
  menu_play_mode_id        = 0x1323AB,
  course_select            = 0x1B6097,
  course_select_animation  = 0x1323B6,
  course_mode              = 0x1B608C,
  course_points            = 0x130CEE,
  main_menu_num_players    = 0x1323A0,
  save_menu_id             = 0x2457E7,
  save_menu_phase          = 0x2457EF,
  ring_shot_course_select  = 0x1323CF,
  ring_shot_loading_phase  = 0x0C7307,
  course_overview_spinning = 0x0C59E3,
  ring_shot_1              = 0x130A40,
  ring_shot_2              = 0x130A46,
  ring_shot_3              = 0x130A4C,
  ring_shot_4              = 0x130A52,
  ring_shot_5              = 0x130A58,
  ring_shot_6              = 0x130A5E,
  current_hole             = 0x1B5603,
  course_overview_timer    = 0x0BE697,
  rain_flag                = 0x0BA9FB,
  wind_speed               = 0x0BA9F0,
  wind_direction           = 0x0BA9F4,
  pause_menu_id            = 0x0C306F,
  current_club             = 0x0FBE5B,
  ball_lie                 = 0x0FBE73,
  ball_lie_2               = 0x1B71EC,
  ball_landing             = 0x104B6B,
  shot_type                = 0x0FBE57,
  num_strokes              = 0x1B71F3,
  num_power_shots          = 0x1B71F8,
  num_power_shots_init     = 0x0FBE9C,
  action_id                = 0x1B71DF,
  is_swinging              = 0x0C3077,
  shot_meter               = 0x0FBE8B,
  shot_power               = 0x224B27,
  shot_distance            = 0x22715B,
  character_select_horz    = 0x1323A3,
  character_select_vert    = 0x1323A7,
  character_1              = 0x0C28E4,
  character_2              = 0x0C28E6,
  character_3              = 0x0C28E8,
  character_4              = 0x0C28EA,
  character_5              = 0x0C28EC,
  character_6              = 0x0C28EE,
  character_7              = 0x0C28F0,
  character_8              = 0x0C28F2,
  character_9              = 0x0C28F4,
  character_10             = 0x0C28F6,
  character_11             = 0x0C28F8,
  character_12             = 0x0C28FA,
  character_13             = 0x0C28FC,
  character_14             = 0x0C28FE,
  club_id_1w               = 0x1B7223,
  club_id_1w_2             = 0x12D11B,
  pin_x                    = 0x0BA9D8, -- 4 bytes
  pin_y                    = 0x0BA9DC, -- 4 bytes
  pin_z                    = 0x0BA9E0, -- 4 bytes

  -- Save Files
  selected_file_exists      = 0x0F7213, -- 1 byte
  confirm_selected_file     = 0x1BD5D7, -- 1 byte
  confirm_selected_file2    = 0x1D8B57, -- 1 byte
  current_character         = 0x1B71ED, -- 1 byte
  current_character_file    = 0x12D0E5, -- 1 byte
  continue_1_exists         = 0x13171B, -- 1 byte
  continue_1_wind_speed     = 0X131738, -- 4 bytes
  continue_1_wind_direction = 0x13173C, -- 2 bytes
  continue_1_rain           = 0x131743, -- 1 byte
  continue_1_pin_rng        = 0x131782, -- 2 bytes
  continue_1_pin_x          = 0x131720, -- 4 bytes
  continue_1_pin_y          = 0x131724, -- 4 bytes
  continue_1_pin_z          = 0x131728, -- 4 bytes
  continue_2_exists         = 0x1317BB, -- 1 byte
  continue_2_wind_speed     = 0X1317D8, -- 4 bytes
  continue_2_wind_direction = 0x1317DC, -- 2 bytes
  continue_2_rain           = 0x1317E3, -- 1 byte
  continue_2_pin_rng        = 0x131822, -- 2 bytes
  continue_2_pin_x          = 0x1317C0, -- 4 bytes
  continue_2_pin_y          = 0x1317C4, -- 4 bytes
  continue_2_pin_z          = 0x1317C8, -- 4 bytes
  continue_3_exists         = 0x13185B, -- 1 byte
  continue_3_wind_speed     = 0X131878, -- 4 bytes
  continue_3_wind_direction = 0x13187C, -- 2 bytes
  continue_3_rain           = 0x131883, -- 1 byte
  continue_3_pin_rng        = 0x1318C2, -- 2 bytes
  continue_3_pin_x          = 0x131860, -- 4 bytes
  continue_3_pin_y          = 0x131864, -- 4 bytes
  continue_3_pin_z          = 0x131868, -- 4 bytes
}

local RDRAM_CONTINUE = {
  0x1318F9, 0x1318FA, 0x1318FB, 0x1318FC, 0x131915,
  0x13194B, 0x13194D, 0x13194F, 0x131951, 0x131953, 0x131955, 0x131957, 0x131959, 0x13195B, 0x13195D, 0x13195F, 0x131961, 0x131963, 0x131965,
  0x131890
}

--[[
0x131960
0x131C40
0x131F20

2E0 hex, 736 decimal offset

]]--

local SRAM_MAPLE = {
  225, 240, 236, 229, 2,                                  -- ?,?,?,?, character ID
  28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, -- Club IDs
  22                                                      -- ?
}

local SRAM_METAL_MARIO = {
  229, 244, 225, 236, 13,                                               -- ?,?,?,?, character ID
  182, 183, 184, 185, 186, 187, 188, 189, 190, 191, 192, 193, 194, 195, -- Club IDs
  43                                                                    -- ?
}

local SRAM_UNLOCKS = 0x7000
local SRAM_COURSES = 0x7004

local SRAM = {
  ring_shot_1 = 0x1320,
  ring_shot_2 = 0x1326,
  ring_shot_3 = 0x132C,
  ring_shot_4 = 0x1342,
  ring_shot_5 = 0x1348,
  ring_shot_6 = 0x134E,
}

local RINGSHOT_BLANK = {
  16, 16, 16, 16, 16, 16,
  16, 16, 16, 16, 16, 16,
  16, 16, 16, 16, 16, 16,
  16, 16, 16, 16, 16, 16,
  16, 16, 16, 16, 16, 16,
  16, 16, 16, 16, 16, 16,
}

local CHARACTERS = {
  plum        = 0,
  charlie     = 1,
  peach       = 2,
  baby_mario  = 3,
  luigi       = 4,
  yoshi       = 5,
  sonny       = 6,
  wario       = 7,
  harry       = 8,
  mario       = 9,
  maple       = 10,
  donkey_kong = 11,
  bowser      = 12,
  metal_mario = 13,
  empty       = 65535,
}

local CHARACTER_IDS = {
  plum        = 0,
  charlie     = 1,
  maple       = 2,
  baby_mario  = 3,
  luigi       = 4,
  peach       = 5,
  sonny       = 6,
  wario       = 7,
  harry       = 8,
  mario       = 9,
  yoshi       = 10,
  donkey_kong = 11,
  bowser      = 12,
  metal_mario = 13,
  empty       = 65535,
}

-- UNLOCK BIT HELPERS

local function unlock_bit(word, bit_idx)
  return bit.check(word, bit_idx)
end

local function has_maple()         return unlock_bit(unlocks_word, 0) end
local function has_metal_mario()   return unlock_bit(unlocks_word, 1) end
local function has_power_shot()    return unlock_bit(unlocks_word, 2) end
local function has_woods()         return unlock_bit(unlocks_word, 3) end
local function has_wedges()        return unlock_bit(unlocks_word, 4) end
local function has_approach()      return unlock_bit(unlocks_word, 5) end
local function has_short_putter()  return unlock_bit(unlocks_word, 6) end
local function has_middle_putter() return unlock_bit(unlocks_word, 7) end
local function has_long_putter()   return unlock_bit(unlocks_word, 8) end

local function has_tt()  return unlock_bit(courses_word, 0)  end
local function has_kc()  return unlock_bit(courses_word, 1)  end
local function has_si()  return unlock_bit(courses_word, 2)  end
local function has_yc()  return unlock_bit(courses_word, 3)  end
local function has_bc()  return unlock_bit(courses_word, 4)  end
local function has_mo()  return unlock_bit(courses_word, 5)  end
local function has_lg()  return unlock_bit(courses_word, 6)  end
local function has_pc()  return unlock_bit(courses_word, 7)  end
local function has_th()  return unlock_bit(courses_word, 8)  end
local function has_kp()  return unlock_bit(courses_word, 9)  end
local function has_sd()  return unlock_bit(courses_word, 10) end
local function has_yi()  return unlock_bit(courses_word, 11) end
local function has_bv()  return unlock_bit(courses_word, 12) end
local function has_ms()  return unlock_bit(courses_word, 13) end

local function is_in_game()
  if mainmemory.read_u8(RDRAM.pause_menu_id) == 0
    and (mainmemory.read_u8(RDRAM.game_mode) == 5 or mainmemory.read_u8(RDRAM.game_mode) == 9)
    and mainmemory.read_u8(RDRAM.course_select) < 12
    and mainmemory.read_u8(RDRAM.action_id) ~= 0 then
    return true
  else
    return false
  end
end

local function is_playing()
  if mainmemory.read_u8(RDRAM.action_id) == 2 and is_in_game() then
    return true
  else
    return false
  end
end

-- APPLY UNLOCKS TO GAME

local function apply_unlocks_to_sram()
  memory.usememorydomain("SRAM")
  memory.write_u32_be(SRAM_UNLOCKS, unlocks_word)
  memory.write_u32_be(SRAM_COURSES, courses_word)
  memory.usememorydomain("RDRAM")
end

local function disable_input(button)
  local btn = button:gsub("^P1 ", "")
  joypad.set({[btn] = false}, 1)
end

local function set_character_select()
  gui.clearGraphics()

  mainmemory.write_u16_be(RDRAM.character_1,  CHARACTERS.peach)
  mainmemory.write_u16_be(RDRAM.character_2,  CHARACTERS.empty)
  mainmemory.write_u16_be(RDRAM.character_3,  CHARACTERS.empty)
  mainmemory.write_u16_be(RDRAM.character_4,  CHARACTERS.empty)
  mainmemory.write_u16_be(RDRAM.character_5,  CHARACTERS.empty)
  mainmemory.write_u16_be(RDRAM.character_6,  CHARACTERS.empty)
  mainmemory.write_u16_be(RDRAM.character_7,  CHARACTERS.empty)
  mainmemory.write_u16_be(RDRAM.character_8,  CHARACTERS.empty)
  mainmemory.write_u16_be(RDRAM.character_9,  CHARACTERS.empty)
  mainmemory.write_u16_be(RDRAM.character_10, CHARACTERS.empty)
  mainmemory.write_u16_be(RDRAM.character_11, CHARACTERS.empty)
  mainmemory.write_u16_be(RDRAM.character_12, CHARACTERS.empty)
  mainmemory.write_u16_be(RDRAM.character_13, CHARACTERS.empty)
  mainmemory.write_u16_be(RDRAM.character_14, CHARACTERS.empty)

  if has_maple() then
    mainmemory.write_u16_be(RDRAM.character_2, CHARACTERS.maple)
  else
    mainmemory.write_u16_be(RDRAM.character_2, CHARACTERS.empty)
    if mainmemory.read_u8(RDRAM.character_select_vert) == 0 and mainmemory.read_u8(RDRAM.character_select_horz) == 1 then
      mainmemory.write_u8(RDRAM.character_select_horz, 0)
    end
  end

  if has_metal_mario() then
    mainmemory.write_u16_be(RDRAM.character_3, CHARACTERS.metal_mario)
  else
    mainmemory.write_u16_be(RDRAM.character_3, CHARACTERS.empty)
    if mainmemory.read_u8(RDRAM.character_select_vert) == 0 and mainmemory.read_u8(RDRAM.character_select_horz) == 2 then
      mainmemory.write_u8(RDRAM.character_select_horz, 0)
    end
  end
end

local function set_play_mode_select()
  gui.clearGraphics()
  local mode = mainmemory.read_u8(RDRAM.menu_play_mode_id)
  if mode == 1 or mode == 3 or mode == 4 or mode == 5 or mode == 6 then
    gui.drawText(255, 300, "DISABLED", "Red", "Black", 25)
    disable_input("P1 A")
  end
end

local TOURNAMENT_NAMES = {
  [0] = "Toad Tournament",
  [1] = "Koopa Cup",
  [2] = "Shy Guy International",
  [3] = "Yoshi Championship",
  [4] = "Boo Classic",
  [5] = "Mario Open",
}

local function display_required_courses()
  -- Only show text if limit tournament logic is disabled
  if required_courses == 0 then return end

  required_courses_text = "REQUIRED COURSES: "
  required_courses_text_2 = ""
  local courses = required_courses
  local course_ids = {}

  -- Convert number into individual digits
  while courses > 0 do
      table.insert(course_ids, 1, courses % 10)
      courses = math.floor(courses / 10)
  end

  -- Create the string of text (breaks into two lines if more than 3 tournaments are required)
  for i = 1, #course_ids do
    if i <= 3 then
      required_courses_text = required_courses_text .. TOURNAMENT_NAMES[course_ids[i]-1]
      if i ~= #course_ids then
        required_courses_text = required_courses_text .. ", "
      end
    else
      required_courses_text_2 = required_courses_text_2 .. TOURNAMENT_NAMES[course_ids[i]-1]
      if i ~= #course_ids then
        required_courses_text_2 = required_courses_text_2 .. ", "
      end
    end
  end

  -- Draw text
  gui.drawText(20, 20, required_courses_text, "Yellow", "Black", 12)
  gui.drawText(154, 34, required_courses_text_2, "Yellow", "Black", 12)
end

local function set_tournament_course()
  mainmemory.write_u16_be(RDRAM.course_points, 65535)

  local any_unlocked = has_tt() or has_kc() or has_si() or has_yc() or has_bc() or has_mo()
  if not any_unlocked then
    gui.drawText(60, 290, "NO TOURNAMENT TICKETS RECEIVED", "Red", "Black", 22)
    gui.drawText(60, 315, "PRESS B TO GO BACK", "Yellow", "Black", 22)
    disable_input("P1 A")
    return
  end

  gui.clearGraphics()
  -- Display required courses (if applicable)
  display_required_courses()

  -- Display gold trophy score requirement
  gui.drawText(20, 410, "GOLD TROPHY SCORE REQUIREMENT: -" .. (10 + setting_gold_trophy_difficulty), "Yellow", "Black", 20)

  -- Display gold trophy requirements for Mario Open
  if not has_mo() then
    grammar = "IES"
    if setting_trophy_count - num_gold_trophies == 1 then grammar = "Y" end
    gui.drawText(20, 430, "MARIO OPEN NEEDS " .. (setting_trophy_count - num_gold_trophies) .. " MORE GOLD TROPH" .. grammar, "Yellow", "Black", 20)
  end

  local anim = mainmemory.read_u16_be(RDRAM.course_select_animation)
  local course = mainmemory.read_u8(RDRAM.course_select)

  if not has_tt() then
    if course == 0 and anim == 0     then mainmemory.write_u16_be(RDRAM.course_select_animation, 256)  end
    if anim >= 244 and anim <= 253   then mainmemory.write_u16_be(RDRAM.course_select_animation, 500)  end
    if anim >= 3   and anim <= 12    then mainmemory.write_u16_be(RDRAM.course_select_animation, 1292) end
  end
  if not has_kc() then
    if course == 1 and anim == 256   then mainmemory.write_u16_be(RDRAM.course_select_animation, 512)  end
    if anim >= 500  and anim <= 509  then mainmemory.write_u16_be(RDRAM.course_select_animation, 756)  end
    if anim >= 268  and anim <= 277  then mainmemory.write_u16_be(RDRAM.course_select_animation, 12)   end
  end
  if not has_si() then
    if course == 2 and anim == 512   then mainmemory.write_u16_be(RDRAM.course_select_animation, 768)  end
    if anim >= 756  and anim <= 765  then mainmemory.write_u16_be(RDRAM.course_select_animation, 1012) end
    if anim >= 515  and anim <= 524  then mainmemory.write_u16_be(RDRAM.course_select_animation, 268)  end
  end
  if not has_yc() then
    if course == 3 and anim == 768   then mainmemory.write_u16_be(RDRAM.course_select_animation, 1024) end
    if anim >= 1012 and anim <= 1021 then mainmemory.write_u16_be(RDRAM.course_select_animation, 1268) end
    if anim >= 771  and anim <= 780  then mainmemory.write_u16_be(RDRAM.course_select_animation, 524)  end
  end
  if not has_bc() then
    if course == 4 and anim == 1024  then mainmemory.write_u16_be(RDRAM.course_select_animation, 1280) end
    if anim >= 1268 and anim <= 1277 then mainmemory.write_u16_be(RDRAM.course_select_animation, 1524) end
    if anim >= 1027 and anim <= 1036 then mainmemory.write_u16_be(RDRAM.course_select_animation, 780)  end
  end
  if not has_mo() then
    if course == 5 and anim == 1280  then mainmemory.write_u16_be(RDRAM.course_select_animation, 12)   end
    if anim >= 1524 and anim <= 1533 then mainmemory.write_u16_be(RDRAM.course_select_animation, 244)  end
    if anim >= 1283 and anim <= 1292 then mainmemory.write_u16_be(RDRAM.course_select_animation, 1036) end
  end
end

local function set_mini_golf_course()
  gui.clearGraphics()
  local course = mainmemory.read_u8(RDRAM.course_select)
  if not has_lg() and course >= 6 and course <= 8 then
    gui.drawText(270, 300, "LOCKED", "Red", "Black", 25)
    disable_input("P1 A")
  end
  if not has_pc() and course >= 9 and course <= 11 then
    gui.drawText(270, 300, "LOCKED", "Red", "Black", 25)
    disable_input("P1 A")
  end
end

local ringshot_selection = 0

local function set_ring_shot_menu()
  if mainmemory.read_u8(RDRAM.course_overview_spinning) == 1 then
    mainmemory.write_bytes_as_array(RDRAM.ring_shot_1, RINGSHOT_BLANK)

    for i = 0, 5 do
      if mainmemory.read_u8(RDRAM.ring_shot_course_select) == i then
        memory.usememorydomain("SRAM")
        for j = 0, 5 do
          local val = memory.read_u8(SRAM.ring_shot_1 + (i * 6) + j)
          memory.usememorydomain("RDRAM")
          mainmemory.write_u8(RDRAM.ring_shot_1 + (i * 6) + j, val)
          memory.usememorydomain("SRAM")
        end
        memory.usememorydomain("RDRAM")
      end
    end

    local ringshot_menu = {
      [0] = has_th(), [1] = has_kp(), [2] = has_sd(),
      [3] = has_yi(), [4] = has_bv(), [5] = has_ms(),
    }

    local any_rs = has_th() or has_kp() or has_sd() or has_yi() or has_bv() or has_ms()
    if not any_rs then
      gui.drawText(60, 290, "NO RING SHOT TICKETS RECEIVED", "Red", "Black", 22)
      gui.drawText(60, 315, "PRESS B TO GO BACK", "Yellow", "Black", 22)
      disable_input("P1 A")
    else
      gui.clearGraphics()
    end

    if mainmemory.read_u8(RDRAM.ring_shot_loading_phase) == 1 then
      ringshot_selection = mainmemory.read_u8(RDRAM.ring_shot_course_select)

      if not ringshot_menu[ringshot_selection] then
        if bit.check(mainmemory.read_u8(RDRAM.p1_pressed_directional), 2) then
          for i = 0, 5 do
            ringshot_selection = (ringshot_selection + 1) % 6
            if ringshot_menu[ringshot_selection] then break end
          end
          mainmemory.write_u8(RDRAM.ring_shot_course_select, ringshot_selection)
        elseif bit.check(mainmemory.read_u8(RDRAM.p1_pressed_directional), 3) then
          for i = 0, 5 do
            ringshot_selection = (ringshot_selection - 1 + 6) % 6
            if ringshot_menu[ringshot_selection] then break end
          end
          mainmemory.write_u8(RDRAM.ring_shot_course_select, ringshot_selection)
        end
      end
    end

  elseif mainmemory.read_u8(RDRAM.action_id) == 17 then
    memory.usememorydomain("SRAM")
    for i = 0, 5 do
      for j = 0, 5 do
        local val = memory.read_u8(SRAM.ring_shot_1 + (i * 6) + j)
        memory.usememorydomain("RDRAM")
        mainmemory.write_u8(RDRAM.ring_shot_1 + (i * 6) + j, val)
        memory.usememorydomain("SRAM")
      end
    end
    memory.usememorydomain("RDRAM")
  end
end


-- DEATH LINK

local death_link_enabled  = false
local death_link_can_send = false
local death_out_pending   = false
local death_in_pending    = false
local last_death_hole     = -1
local last_hole_strokes   = -1
local last_hole_num       = -1
local strokes_prev_frame  = 0

local function trigger_death_in()
  death_in_pending = true
  print("[MG64] Death Link queued - will trigger on next swing")
end

local function process_death_in()
  if not death_in_pending then return end
  if mainmemory.read_u8(RDRAM.action_id) == 2 and mainmemory.read_u8(RDRAM.pause_menu_id) == 0 then
    mainmemory.write_u8(RDRAM.action_id,    5)
    local dist = math.random(1, 256)
    mainmemory.write_u8(RDRAM.shot_distance, dist)
    mainmemory.write_u8(RDRAM.shot_power,    math.floor((dist * 30) / 256))
    mainmemory.write_u8(RDRAM.shot_meter,    69)
    mainmemory.write_u8(RDRAM.num_strokes,   mainmemory.read_u8(RDRAM.num_strokes) + 1)
    death_in_pending = false
    print("[MG64] Death Link triggered - forced whiff!")
  end
end

-- TOURNAMENT PAR DATA

local TOURNAMENT_PAR = {
  [0] = {4,3,4,5,4,3,4,5,4, 4,4,5,3,4,4,5,3,4}, -- Toad Tournament
  [1] = {4,5,4,3,4,5,4,3,4, 4,4,5,3,4,4,3,4,5}, -- Koopa Cup
  [2] = {4,3,5,4,4,4,3,4,5, 4,4,3,4,5,3,4,5,4}, -- Shy Guy International
  [3] = {4,4,3,5,4,3,5,4,4, 4,5,3,4,4,3,4,4,5}, -- Yoshi Championship
  [4] = {4,4,5,3,4,4,5,3,4, 5,4,3,4,4,3,4,5,4}, -- Boo Classic
  [5] = {4,4,5,3,4,3,5,4,4, 4,5,3,4,4,4,3,5,4}, -- Mario Open
}

local function check_death_out()
  if not death_link_enabled then return end
  if not death_link_can_send then return end

  local strokes = mainmemory.read_u8(RDRAM.num_strokes)
  local action  = mainmemory.read_u8(RDRAM.action_id)
  local ball_landing = mainmemory.read_u8(RDRAM.ball_landing)

  -- Death on water hazard or out-of-bounds
  if action == 10 then
    if ball_landing == 0 or ball_landing == 5 or ball_landing == 22 then
      death_out_pending = true
      death_link_can_send = false
      print("[MG64] Death Link sent - water hazard or out-of-bounds")
    end
  end

  --[[
  if action == 16 then
    if strokes == (strokes_prev_frame + 1) then
      death_out_pending = true
      strokes_prev_frame = strokes
      print("[MG64] Death Link sent - water hazard or out-of-bounds")
    end
  end
  strokes_prev_frame = strokes
  ]]--

  --[[

  -- Death on bogey or worse
  local game_mode = mainmemory.read_u8(RDRAM.game_mode)
  if game_mode ~= 5 then return end

  --local action  = mainmemory.read_u8(RDRAM.action_id)
  if action ~= 20 then return end

  local hole    = mainmemory.read_u8(RDRAM.current_hole) + 1
  --local strokes = mainmemory.read_u8(RDRAM.num_strokes)
  local course  = mainmemory.read_u8(RDRAM.course_select)

  if hole == last_death_hole then return end

  if course <= 5 then
    local par = TOURNAMENT_PAR[course][hole]
    if strokes > par then
      death_out_pending = true
      last_death_hole   = hole
      print("[MG64] Death Link sent - bogey or worse on hole " .. hole)
    end
  end
  ]]--
end

-- CLUB RESTRICTION

-- Club IDs: 0=1W, 1=3W, 2=4W, 3=2I..10=9I, 11=PW, 12=SW, 13=Putter
local function get_allowed_clubs()
  local allowed = {}
  allowed[13] = true           -- Putter always available
  for id = 3, 10 do allowed[id] = true end  -- Irons always available
  if has_woods()  then allowed[0] = true; allowed[1] = true; allowed[2] = true end
  if has_wedges() then allowed[11] = true; allowed[12] = true end
  return allowed
end

-- TRAPS

local _rain_active = false
local _hurricane_active = false
local _terrible_lie_active = false
local _fast_meter_active = false

local function apply_trap(trap)
  if trap == nil or trap == "" then return end
  print("[MG64] Trap triggered: " .. trap)
  if trap == "Rain Trap" then
    _rain_active = true
  elseif trap == "Hurricane Trap" then
    _hurricane_active = true
  elseif trap == "Terrible Lie Trap" then
    _terrible_lie_active = true
  elseif trap == "Fast Shot Meter Trap" then
    _fast_meter_active = true
  end
end

local function process_rain_trap()
  if not _rain_active then return end
  if is_in_game() then
    mainmemory.write_u8(RDRAM.rain_flag, 1)
    _rain_active = false
  end
end

local function process_hurricane_trap()
  if not _hurricane_active then return end
  if is_in_game() then
    mainmemory.write_u16_be(RDRAM.wind_direction, math.random(0, 65535))
    mainmemory.write_u32_be(RDRAM.wind_speed, 1048575)
    _hurricane_active = false
  end
end

local function process_terrible_lie_trap()
  if not _terrible_lie_active then return end
  if is_playing() then
    mainmemory.write_u8(RDRAM.ball_lie,   12)
    mainmemory.write_u8(RDRAM.ball_lie_2, 12)
    _terrible_lie_active = false
  end
end

local function process_fast_meter()
  if not _fast_meter_active then return end
  local action = mainmemory.read_u8(RDRAM.action_id)
  if (action == 4 or action == 5) and bit.check(mainmemory.read_u32_be(RDRAM.frame_counter), 0) then
    mainmemory.write_u8(RDRAM.shot_meter, bit.set(mainmemory.read_u8(RDRAM.shot_meter), 0) + 1)
  elseif action == 6 then
    _fast_meter_active = false
  end
end

local function enforce_shot_type()
  local menu = mainmemory.read_u8(RDRAM.menu_id)
  if menu ~= 12 and menu ~= 18 then return end

  local club      = mainmemory.read_u8(RDRAM.current_club)
  local shot_type = mainmemory.read_u8(RDRAM.shot_type)

  if club == 13 then
    --[[
    local starting_shot = 2 - setting_starting_putter
    local allowed = {}
    allowed[starting_shot] = true
    if has_short_putter()  then allowed[2] = true end
    if has_middle_putter() then allowed[1] = true end
    if has_long_putter()   then allowed[0] = true end
    if not allowed[shot_type] then
      mainmemory.write_u8(RDRAM.shot_type, starting_shot)
    end
    ]]--

    -- Set the putter to the correct distance based on what has been checked. This needs to be cleaned up
    if not has_short_putter() and mainmemory.read_u8(RDRAM.shot_type) == 2 then
      if has_middle_putter() then
        mainmemory.write_u8(RDRAM.shot_type, 1)
      elseif has_long_putter() then
        mainmemory.write_u8(RDRAM.shot_type, 0)
      end
    elseif not has_middle_putter() and mainmemory.read_u8(RDRAM.shot_type) == 1 then
      if has_long_putter() then
        mainmemory.write_u8(RDRAM.shot_type, 0)
      elseif has_short_putter() then
        mainmemory.write_u8(RDRAM.shot_type, 2)
      end
    elseif not has_long_putter() and mainmemory.read_u8(RDRAM.shot_type) == 0 then
      if has_short_putter() then
        mainmemory.write_u8(RDRAM.shot_type, 2)
      elseif has_middle_putter() then
        mainmemory.write_u8(RDRAM.shot_type, 1)
      end
    end

  else
    if shot_type == 0 and not has_power_shot() then
      mainmemory.write_u8(RDRAM.shot_type, 1)
    elseif shot_type == 2 and not has_approach() then
      mainmemory.write_u8(RDRAM.shot_type, 1)
    end

    -- Check power shot
    if has_power_shot() then
      mainmemory.write_u8(RDRAM.num_power_shots, 255)
      mainmemory.write_u8(RDRAM.num_power_shots_init, 255)
    else
      mainmemory.write_u8(RDRAM.num_power_shots, 0)
      mainmemory.write_u8(RDRAM.num_power_shots_init, 0)

      -- Prevents the player from switching to a power shot
      -- Checks to see if the putter is selected
      if mainmemory.read_u8(RDRAM.shot_type) == 0 and mainmemory.read_u8(RDRAM.current_club) ~= 13 then
        mainmemory.write_u8(RDRAM.shot_type, 1)
      end
    end
  end
end

local last_valid_club = 3

local function enforce_club_restriction()
  local menu = mainmemory.read_u8(RDRAM.menu_id)
  if menu ~= 12 and menu ~= 18 then return end

  local allowed = get_allowed_clubs()
  local current = mainmemory.read_u8(RDRAM.current_club)

  if allowed[current] then
    last_valid_club = current
    return
  end

  --[[
  local target = nil
  if last_valid_club < current then
    for i = 1, 13 do
      local id = (current + i) % 14
      if allowed[id] then target = id; break end
    end
  else
    for i = 1, 13 do
      local id = (current - i + 14) % 14
      if allowed[id] then target = id; break end
    end
  end

  mainmemory.write_u8(RDRAM.current_club, target)
  last_valid_club = target
  ]]--

  -- Woods
  if not allowed[0] then
    if mainmemory.read_u8(RDRAM.current_club) <= 2 then
      mainmemory.write_u8(RDRAM.current_club, 3)
    end
  end

  -- Wedges
  if not allowed[11] then
    -- Check if PW or SW is selected and auto-select the appropriate club
    if mainmemory.read_u8(RDRAM.current_club) == 11 then
      mainmemory.write_u8(RDRAM.current_club, 13)
    elseif mainmemory.read_u8(RDRAM.current_club) == 12 then
      mainmemory.write_u8(RDRAM.current_club, 10)
    end
  end

end

-- LOCATION DETECTION

local RING_SHOT_NAMES = {
  [0] = {
    "Toad Highlands Ring Shot 1 - Give It a Shot!",
    "Toad Highlands Ring Shot 2 - Climb That Hill!",
    "Toad Highlands Ring Shot 3 - Ring in the Valley",
    "Toad Highlands Ring Shot 4 - 3 Rings Above the Pond",
    "Toad Highlands Ring Shot 5 - Creek Crossing",
    "Toad Highlands Ring Shot 6 - Every Which Way!",
  },
  [1] = {
    "Koopa Park Ring Shot 1 - R-RR-Ring!",
    "Koopa Park Ring Shot 2 - Arch at Forked Creek",
    "Koopa Park Ring Shot 3 - Switchback Swinging!",
    "Koopa Park Ring Shot 4 - Hide-and-Go-Ring!",
    "Koopa Park Ring Shot 5 - Power Past the Pond!",
    "Koopa Park Ring Shot 6 - Arches Here & There",
  },
  [2] = {
    "Shy Guy Desert Ring Shot 1 - The Anthill Bunker",
    "Shy Guy Desert Ring Shot 2 - Cactus Arms",
    "Shy Guy Desert Ring Shot 3 - Pyramid Ring",
    "Shy Guy Desert Ring Shot 4 - Center of the Bull's-Eye",
    "Shy Guy Desert Ring Shot 5 - Shoot for the Stones!",
    "Shy Guy Desert Ring Shot 6 - Sand Dune Summit",
  },
  [3] = {
    "Yoshi's Island Ring Shot 1 - Doughnut Hole",
    "Yoshi's Island Ring Shot 2 - Scraping the Cliff",
    "Yoshi's Island Ring Shot 3 - Dunk the Bunker!",
    "Yoshi's Island Ring Shot 4 - Drop into the Valley!",
    "Yoshi's Island Ring Shot 5 - Arches in the Hills",
    "Yoshi's Island Ring Shot 6 - Zig and Zag",
  },
  [4] = {
    "Boo Valley Ring Shot 1 - The Bottleneck",
    "Boo Valley Ring Shot 2 - Past the Peak",
    "Boo Valley Ring Shot 3 - The Egg Hill",
    "Boo Valley Ring Shot 4 - Emerging from the Mist",
    "Boo Valley Ring Shot 5 - Valley in the Valley",
    "Boo Valley Ring Shot 6 - Duck and Dodge!",
  },
  [5] = {
    "Mario's Star Ring Shot 1 - Bloober Calamari Rings",
    "Mario's Star Ring Shot 2 - Skull & Bones",
    "Mario's Star Ring Shot 3 - Bowser's Big Mouth",
    "Mario's Star Ring Shot 4 - Lakitu's Glasses",
    "Mario's Star Ring Shot 5 - Sorry, Bob-omb!",
    "Mario's Star Ring Shot 6 - Princess Peach's Ring",
  },
}

local RING_SHOT_SRAM_BASE = SRAM.ring_shot_1

local function get_completed_locations()
  -- Scan SRAM for ring shot completions (only if ringshotsanity enabled)
  if setting_ringshotsanity == 1 then
    memory.usememorydomain("SRAM")
    -- FIX: read the whole ring shot SRAM block in one call instead of 36 individual reads
    local sram_block = memory.read_bytes_as_array(RING_SHOT_SRAM_BASE, 36)
    memory.usememorydomain("RDRAM")
    for course_idx = 0, 5 do
      for hole_idx = 0, 5 do
        local offset = course_idx * 6 + hole_idx
        local val    = sram_block[offset + 1]  -- Lua arrays are 1-based
        if val == 1 and baseline_sram[offset] ~= 1 then
          local name = RING_SHOT_NAMES[course_idx][hole_idx + 1]
          if not detected_locations[name] then
            detected_locations[name] = true
            print("[MG64] Check complete: " .. name)
          end
        end
      end
    end
  end

  local result = {}
  for name in pairs(detected_locations) do
    table.insert(result, name)
  end
  return result
end

-- LOAD SAVE FILE
--[[
local function set_character_save_file()
  offset = mainmemory.read_u8(RDRAM.save_menu_id) * 736
  mainmemory.write_u8(RDRAM_CONTINUE[5] + offset, SRAM_METAL_MARIO[5])
end
]]--

local CHARACTER_CLUBS = {
  70, 28, 182 -- Peach, Maple, Metal Mario
}

function load_save_file()

  -- Draw directions for swapping characters
  if has_maple() or has_metal_mario() then
    gui.drawText(210, 95, "HOLD BUTTON AFTER SELECTING SAVE FILE TO SWAP", "YELLOW", "Black", 14)
    gui.drawText(420, 120, "START FOR PEACH", "YELLOW", "Black", 18)
    if has_maple() then gui.drawText(420, 140, "L FOR MAPLE", "YELLOW", "Black", 18) end
    if has_metal_mario() then gui.drawText(420, 160, "R FOR METAL MARIO", "YELLOW", "Black", 18) end
  end

  -- Check that you're actually loading a save file
  if mainmemory.read_u8(RDRAM.selected_file_exists) == 0 and mainmemory.read_u8(RDRAM.confirm_selected_file) == 0 and mainmemory.read_u8(RDRAM.confirm_selected_file2) == 0 then
    
    -- Change character based on what button is pressed (start = Peach, L = Maple, R = Metal Mario)
    if bit.check(mainmemory.read_u16_be(RDRAM.p1_held), 12) then
      character = 1
      mainmemory.write_u8(RDRAM.current_character, CHARACTER_IDS.peach)
    elseif bit.check(mainmemory.read_u16_be(RDRAM.p1_held), 5) and has_maple() then
      character = 2
      mainmemory.write_u8(RDRAM.current_character, CHARACTER_IDS.maple)
    elseif bit.check(mainmemory.read_u16_be(RDRAM.p1_held), 4) and has_metal_mario() then
      character = 3
      mainmemory.write_u8(RDRAM.current_character, CHARACTER_IDS.metal_mario)
    else
      return
    end

    -- Set the club IDs based on the character selected
    for i=0, 13, 1 do
      mainmemory.write_u8(RDRAM.club_id_1w + (i * 2), CHARACTER_CLUBS[character] + i)
    end
  end
end

-- RANDOMIZE SAVE FILE

local TOAD_TOURNAMENT_PINS = {
  2122604, 4294714616, 1849829, -- hole 1
  2110979, 4294705152, 2128662,
  2050930, 4294705152, 2181606,
  2042670, 4294713344, 1953359,
  1908375, 4294912245, 3091684, -- hole 2
  1679440, 4294905856, 3197884,
  1515323, 4294904529, 3160817,
  1783015, 4294905856, 3000131,
  2437305, 4294812163, 1559489, -- hole 3
  2470848, 4294811648, 1681761,
  2608279, 4294811648, 1625598,
  2329177, 4294812806, 1642563,
  2675720, 4294766155, 800443, -- hole 4
  2596870, 4294764469, 854369,
  2839133, 4294766180, 799640,
  2559012, 4294768474, 726227,
  1629497, 4294727029, 1982066, -- hole 5
  1710144, 4294737920, 2173952,
  1710407, 4294739001, 2256360,
  1622827, 4294734034, 2135035,
  1976202, 4294942720, 4047675, -- hole 6
  2073534, 4294942720, 4040774,
  1836620, 4294958903, 4085719,
  1792321, 4294960437, 4127508,
  1759533, 4294869614, 1374644, -- hole 7
  1847909, 4294864090, 1462344,
  2007921, 4294856704, 1421423,
  1885188, 4294861760, 1384454,
  1205338, 4294512640, 924855, -- hole 8
  1107724, 4294512640, 929929,
  1123668, 4294512640, 787915,
  1145856, 4294512640, 893831,
  1863275, 4294927623, 1351913, -- hole 9
  1967805, 4294923691, 1226080,
  1943717, 4294931183, 1465838,
  2026613, 4294927698, 1354304,
  2107392, 4294702048, 1463296, -- hole 10
  2049770, 4294695609, 1314894,
  2011581, 4294701115, 1529272,
  2362551, 4294717440, 1610953,
  2861977, 4294898373, 2020275, -- hole 11
  2982710, 4294894922, 2064679,
  2715648, 4294897408, 2035712,
  2777999, 4294894889, 2076021,
  831521, 4294865837, 967995, -- hole 12
  612558, 4294868730, 856164,
  771164, 4294884408, 663207,
  738304, 4294875168, 794624,
  2417947, 4294557803, 3270714, -- hole 13
  2465258, 4294571338, 3478968,
  2525965, 4294568153, 3420423,
  2432696, 4294567902, 3393302,
  2202546, 4294852474, 1434835, -- hole 14
  2080561, 4294848988, 1336521,
  2096334, 4294855159, 1523450,
  2125895, 4294852560, 1439317,
  2466320, 4294757799, 1684534, -- hole 15
  2456144, 4294757331, 1476529,
  2322966, 4294753169, 1531609,
  2408417, 4294756115, 1621602,
  1729029, 4294340849, 918648, -- hole 16
  1504101, 4294335438, 779159,
  1634693, 4294338444, 675510,
  1640448, 4294338614, 852992,
  2374814, 4294790570, 3339125, -- hole 17
  2138672, 4294783767, 3321528,
  2278400, 4294792891, 3288064,
  2526322, 4294794226, 3274078,
  2595024, 4294763650, 1670077, -- hole 18
  2686951, 4294772954, 1735410,
  2598951, 4294758400, 1531986,
  2452068, 4294760069, 1664603,
}

local KOOPA_CUP_PINS = {
  2027667, 4294881094, 1181641, -- hole 1
  2036193, 4294865698, 1345860,
  2114759, 4294871981, 1278846,
  2059874, 4294874176, 1255424,
  2541382, 4294858621, 978870, -- hole 2
  2357404, 4294859774, 1017648,
  2256205, 4294856704, 988963,
  2447360, 4294858240, 966656,
  1145705, 4294448563, 1792828, -- hole 3
  1176153, 4294450983, 1676382,
  1116160, 4294453152, 1897472,
  1046061, 4294448336, 1739289,
  2214238, 4294510273, 2406654, -- hole 4
  2329923, 4294507094, 2348770,
  2165051, 4294503837, 2243056,
  2300306, 4294511026, 2446998,
  2025603, 4294935767, 1393427, -- hole 5
  2093271, 4294932837, 1514891,
  2228500, 4294932109, 1495348,
  2121728, 4294930859, 1421312,
  2854771, 4294596741, 1028150, -- hole 6
  2679873, 4294606112, 1167887,
  2715648, 4294608160, 1221632,
  2704173, 4294611366, 1324247,
  2163030, 4294934550, 1555817, -- hole 7
  2206224, 4294936621, 1614692,
  2092137, 4294930119, 1551906,
  2087363, 4294929821, 1411759,
  1653052, 4294858406, 2726980, -- hole 8
  1757941, 4294861640, 2774356,
  1597400, 4294846068, 2595372,
  1541457, 4294861311, 2761723,
  2195800, 4294934528, 2038793, -- hole 9
  2184814, 4294934528, 1876215,
  2190967, 4294934528, 2176991,
  2358969, 4294945699, 2062419,
  3041067, 4294680576, 2003399, -- hole 10
  3121132, 4294685460, 2135779,
  2929169, 4294681911, 2068457,
  2815953, 4294674412, 1871236,
  2222800, 4294964660, 1952915, -- hole 11
  2157568, 4294967176, 1910784,
  2173300, 4294941756, 2138296,
  2214968, 4294966829, 1791866,
  1688905, 4294958052, 1124947, -- hole 12
  1606702, 4294960612, 1109080,
  1726482, 4294950292, 1244110,
  1624080, 4294950144, 1227780,
  2570475, 4294965948, 2899264, -- hole 13
  2743248, 0, 2978740,
  2628608, 0, 2950144,
  2580441, 4294965792, 3020920,
  2089624, 4294965968, 1487818, -- hole 14
  2008321, 4294956225, 1323416,
  2078720, 4294962436, 1412096,
  2017538, 4294966301, 1512949,
  2096128, 4294922744, 1106944, -- hole 15
  2165537, 4294923230, 1106944,
  1947811, 4294929978, 1125512,
  2030142, 4294926130, 1136638,
  1943490, 4294951226, 2872512, -- hole 16
  1875564, 4294948265, 2700396,
  1979673, 4294949382, 2841850,
  2046976, 4294951939, 2772992,
  1418101, 4294858815, 2153823, -- hole 17
  1558753, 4294849393, 2005409,
  1449984, 4294856192, 2056192,
  1300457, 4294865129, 2055592,
  1355434, 4294426215, 975180, -- hole 18
  1497823, 4294423645, 1109358,
  1633417, 4294422897, 1094986,
  1487251, 4294422175, 1026888,
}

local SHY_GUY_INTERNATIONAL_PINS = {
  2378612, 4294743592, 1881013, -- hole 1
  2456732, 4294745260, 1716229,
  2383884, 4294743703, 1777252,
  2330807, 4294746754, 1683417,
  2181493, 4294657533, 3620983, -- hole 2
  2199475, 4294638629, 3992493,
  2136658, 4294657234, 3621807,
  2295374, 4294638161, 3935565,
  3194252, 4294775212, 894875, -- hole 3
  3315712, 4294774784, 832512,
  3316830, 4294775449, 898758,
  3276560, 4294776171, 742382,
  1985052, 4294785409, 1519661, -- hole 4
  2235392, 4294790720, 1492992,
  2137226, 4294791859, 1563889,
  2363816, 4294796499, 1476802,
  719340, 4294780185, 1662203, -- hole 5
  828416, 4294771303, 1822720,
  943419, 4294769275, 1880245,
  828836, 4294768151, 1916196,
  1126849, 4294768432, 1435721, -- hole 6
  1302465, 4294758835, 1578506,
  1193266, 4294765765, 1691114,
  1402443, 4294755026, 1556632,
  2133227, 4294776843, 3604159, -- hole 7
  2006910, 4294768567, 3724367,
  1944100, 4294760959, 3793721,
  2083761, 4294771149, 3759566,
  2657172, 4294960062, 1424305, -- hole 8
  2651136, 4294965935, 1299456,
  2510870, 4294964170, 1497846,
  2644225, 4294964859, 1330188,
  1350432, 4294963200, 888092, -- hole 9
  1143808, 4294938624, 739328,
  1268770, 4294941345, 713279,
  913143, 4294963200, 714141,
  2129680, 4294778601, 1335306, -- hole 10
  2025472, 4294770071, 1341440,
  1970252, 4294766396, 1357272,
  2063963, 4294773422, 1260315,
  1417749, 4294840252, 1419942, -- hole 11
  1338739, 4294837100, 1699816,
  1333266, 4294836928, 1587799,
  1332224, 4294836896, 1509376,
  2155078, 4294730517, 2692857, -- hole 12
  2090396, 4294768111, 3072303,
  2180444, 4294756632, 3004124,
  2188535, 4294763069, 3075617,
  2741480, 4294585347, 1867692, -- hole 13
  2557036, 4294585432, 1864989,
  2646656, 4294584164, 1905566,
  2458763, 4294585945, 1848546,
  2151843, 4294856020, 821116, -- hole 14
  2275951, 4294856622, 927922,
  2209792, 4294850432, 699392,
  2279899, 4294852294, 820799,
  2272495, 4294949862, 3004885, -- hole 15
  2043904, 4294959693, 2912256,
  2112004, 4294952865, 3068403,
  2314140, 4294941126, 3241915,
  1872214, 4294815559, 2319706, -- hole 16
  1964618, 4294813893, 2158043,
  1998585, 4294813679, 2240916,
  1928192, 4294812838, 2233344,
  3255526, 4294856733, 1180597, -- hole 17
  3334479, 4294857025, 964902,
  3185962, 4294855500, 956059,
  3304448, 4294855008, 1097728,
  2283133, 4294730152, 1677237, -- hole 18
  2294122, 4294727246, 1547834,
  2178943, 4294733455, 1660696,
  2245576, 4294729651, 1597556,
}

local YOSHI_CHAMPIONSHIP_PINS = {
  2064398, 4294805275, 1926658, -- hole 1
  2131446, 4294801313, 1840671,
  2257236, 4294792981, 1922210,
  2143232, 4294800576, 1899520,
  2143031, 4294351463, 1586148, -- hole 2
  2086193, 4294352896, 1638675,
  2306723, 4294343387, 1478117,
  2235392, 4294347424, 1536000,
  1972241, 4294934010, 3421216, -- hole 3
  1881731, 4294929685, 3391901,
  1953833, 4294930120, 3460290,
  1933358, 4294932098, 3410782,
  2273280, 4294235552, 1573888, -- hole 4
  2380878, 4294238208, 1701917,
  2170015, 4294234734, 1480111,
  2325245, 4294238208, 1660110,
  1660550, 4294427534, 1623843, -- hole 5
  1724323, 4294426707, 1576895,
  1552356, 4294428205, 1661435,
  1449154, 4294428634, 1685470,
  2011678, 4294676481, 3600405, -- hole 6
  2042719, 4294676760, 3605150,
  1963852, 4294674041, 3558930,
  1975725, 4294678185, 3629375,
  1569672, 4294776095, 808634, -- hole 7
  1434052, 4294773477, 721410,
  1486015, 4294775824, 803084,
  1650331, 4294782019, 869884,
  2113536, 4294877696, 1465344, -- hole 8
  1937220, 4294882182, 1454658,
  2359560, 4294885380, 1447137,
  1834813, 4294885667, 1582206,
  3023702, 4294705152, 1830502, -- hole 9
  2657879, 4294719258, 1794562,
  2819072, 4294709184, 1822720,
  2929350, 4294705152, 1775225,
  2153622, 4294841336, 1873007, -- hole 10
  2321967, 4294836702, 1602550,
  2091040, 4294836874, 1830735,
  2192757, 4294838061, 1710021,
  2370382, 4294837332, 859115, -- hole 11
  2148335, 4294841217, 1030782,
  2246171, 4294836224, 886348,
  2322272, 4294836224, 724017,
  1795937, 4294916143, 3157197, -- hole 12
  2070971, 4294912332, 3384451,
  1974272, 4294916778, 3268608,
  1887688, 4294916499, 3211834,
  2900320, 4294657161, 1450387, -- hole 13
  2831780, 4294655081, 1387246,
  2868558, 4294652811, 1281697,
  2814595, 4294655920, 1182238,
  2467618, 4294437833, 1777761, -- hole 14
  2698345, 4294437220, 1635447,
  2504704, 4294435360, 1686528,
  2467618, 4294437833, 1777761,
  2101248, 4294801764, 2740878, -- hole 15
  2101248, 4294799334, 2708480,
  2101248, 4294797455, 2683422,
  2101006, 4294795666, 2659571,
  2228229, 4294824785, 1520916, -- hole 16
  2172300, 4294822728, 1543924,
  2099639, 4294819286, 1561516,
  2156948, 4294818649, 1494014,
  1523468, 4294781845, 1906598, -- hole 17
  1436048, 4294773819, 1879295,
  1514496, 4294775040, 2118656,
  1306575, 4294766345, 1862735,
  1919208, 4294612028, 1158115, -- hole 18
  2022594, 4294613511, 1261819,
  1775457, 4294611207, 990467,
  1845248, 4294608035, 1032192,
}

local BOO_CLASSIC_PINS = {
  2221056, 4294781896, 1820672, -- hole 1
  2156894, 4294781395, 1830751,
  2301696, 4294782142, 1776935,
  2080664, 4294783350, 1657017,
  1187840, 4294890095, 1378304, -- hole 2
  1256448, 4294891281, 1362944,
  1106944, 4294889472, 1422336,
  1009664, 4294889472, 1448960,
  952288, 4294803860, 1055040, -- hole 3
  965077, 4294809802, 1150117,
  1094676, 4294805555, 1082163,
  867630, 4294803863, 1056732,
  2259576, 4294772842, 3390325, -- hole 4
  2384356, 4294764011, 3439862,
  2370507, 4294773804, 3564546,
  2326051, 4294782125, 3660230,
  2349673, 4294942456, 1836257, -- hole 5
  2334983, 4294945103, 1896357,
  2242844, 4294941351, 1859240,
  2177529, 4294940017, 1898545,
  1702880, 4294798714, 1682220, -- hole 6
  1553260, 4294801973, 1656508,
  1636352, 4294801440, 1702912,
  1663718, 4294802878, 1776323,
  3426340, 4294844087, 794356, -- hole 7
  3511819, 4294840678, 761001,
  3449798, 4294841713, 714531,
  3576160, 4294840175, 819001,
  2025736, 4294778880, 4049442, -- hole 8
  2080825, 4294778880, 4049348,
  2150198, 4294778880, 4060588,
  1957343, 4294779972, 4043655,
  2159062, 4294502041, 1468822, -- hole 9
  2270208, 4294503535, 1409024,
  2043345, 4294500352, 1477287,
  2102287, 4294505770, 1528480,
  2915650, 4294715436, 919685, -- hole 10
  2993152, 4294710592, 952320,
  2835609, 4294721937, 875229,
  3087855, 4294704674, 958337,
  1380541, 4294721803, 1849099, -- hole 11
  1316864, 4294717820, 1833984,
  1298876, 4294718180, 1909272,
  1468624, 4294725632, 1837904,
  2104320, 4294582496, 3559614, -- hole 12
  2104320, 4294582272, 3670016,
  2104320, 4294587778, 3758119,
  2055594, 4294590077, 3794903,
  1373814, 4294896723, 1411391, -- hole 13
  1452032, 4294898411, 1431552,
  1520207, 4294898596, 1466076,
  1341291, 4294896408, 1340210,
  2884477, 4294777243, 2230658, -- hole 14
  2717553, 4294770688, 2229071,
  2898846, 4294776055, 2120891,
  2793219, 4294772388, 2211156,
  2504823, 4294795396, 2684440, -- hole 15
  2424427, 4294801483, 2758930,
  2736548, 4294771417, 2508617,
  2577408, 4294787616, 2597888,
  1768448, 4294869248, 1511424, -- hole 16
  1617753, 4294874638, 1622469,
  1898269, 4294859845, 1387924,
  1683079, 4294872066, 1556521,
  2338707, 4294452918, 1493247, -- hole 17
  2385733, 4294456517, 1618850,
  2138301, 4294465670, 1539180,
  2234623, 4294459038, 1565312,
  1667892, 4294772930, 2173413, -- hole 18
  1625714, 4294774259, 2144613,
  1385129, 4294776210, 2016790,
  1522829, 4294781511, 2160314,
}

local MARIO_OPEN_PINS = {
  2876628, 4294871476, 1991887, -- hole 1
  2608174, 4294873509, 1959358,
  2702100, 4294871948, 1984322,
  2793472, 4294876224, 1915904,
  1470934, 4294926522, 1032049, -- hole 2
  1592320, 4294942752, 973824,
  1558835, 4294930681, 1070909,
  1630386, 4294934850, 1083485,
  848525, 4294946893, 1113143, -- hole 3
  843763, 4294946816, 1007778,
  898048, 4294943648, 1042432,
  933103, 4294943883, 1070210,
  2783073, 4294925285, 3440786, -- hole 4
  2739718, 4294923439, 3345855,
  2754560, 4294924045, 3379200,
  2720390, 4294924979, 3403969,
  2093645, 4294944977, 465450, -- hole 5
  2052219, 4294944840, 370317,
  2112512, 4294943904, 415744,
  2174393, 4294946816, 453475,
  1207021, 4294920751, 2224675, -- hole 6
  1235889, 4294919937, 2208834,
  1176576, 4294921440, 2256896,
  1155667, 4294921522, 2275189,
  3080753, 4294921474, 1127491, -- hole 7
  3003741, 4294941383, 856989,
  3059118, 4294929487, 1015737,
  3023379, 4294935959, 943189,
  1518592, 4294793760, 1544192, -- hole 8
  1714155, 4294801449, 1971341,
  1688026, 4294791168, 1685656,
  1853059, 4294821207, 1931198,
  1954647, 4294829508, 1453982, -- hole 9
  1965056, 4294828609, 1306853,
  1965056, 4294828125, 1353524,
  1965056, 4294828125, 1405152,
  2943269, 4294946451, 1161951, -- hole 10
  2920800, 4294945046, 1214398,
  2951168, 4294946944, 1199104,
  2951893, 4294946989, 1235723,
  3697664, 4294823200, 997376, -- hole 11
  3607552, 4294822976, 833536,
  3663872, 4294820704, 896000,
  3703808, 4294821056, 922624,
  2096128, 4294880096, 2939904, -- hole 12
  1996800, 4294881472, 2895872,
  1997824, 4294879264, 2931712,
  1922048, 4294877760, 2939904,
  3112400, 4294948773, 1715555, -- hole 13
  2929251, 4294944951, 1715964,
  3049472, 4294944763, 1731584,
  2998145, 4294942456, 1725338,
  2349070, 4294902423, 1875464, -- hole 14
  2257031, 4294897917, 1835231,
  2310144, 4294904051, 1878016,
  2261769, 4294902227, 1906685,
  2960605, 4294919690, 2194879, -- hole 15
  2953157, 4294916987, 2114325,
  2967565, 4294917642, 2160650,
  2937596, 4294919685, 2160640,
  2173215, 4294961550, 3583827, -- hole 16
  2222963, 4294961167, 3564174,
  2187264, 4294959650, 3555328,
  2146766, 4294957080, 3532038,
  1762834, 4294934943, 681257, -- hole 17
  1857973, 4294934886, 584103,
  1991680, 4294936512, 667648,
  1948159, 4294937747, 776290,
  3281064, 4294911862, 1903440, -- hole 18
  3054456, 4294904612, 2005904,
  3209103, 4294908715, 1935586,
  3162008, 4294904523, 2008752,
}

local WIND_SPEEDS = {
  43690,  72817,  101944, 131071, 160198, -- 1-5mph
  189325, 218452, 247579, 276706, 305833, -- 6-10mph
  334960, 364087, 393214, 422341, 451468, -- 11-15mph
  480595, 509722, 538849, 567976, 597103, -- 16-20mph
  630000                                  -- 21mph
}

WIND_SPEEDS[0] = 0                        -- 0mph

-- Function that randomizes wind speed and direction
function randomize_wind(max_mph)
  new_wind_direction = math.random(0, 65535)
  new_wind_speed = math.random(0, WIND_SPEEDS[max_mph])

  if new_wind_speed < 29184 then new_wind_speed = 0 end
  if max_mph == 0 then new_wind_speed = 0 end

  mainmemory.write_u16_be(RDRAM.wind_direction, new_wind_direction)
  mainmemory.write_u32_be(RDRAM.wind_speed, new_wind_speed)
end

-- Function that sets the max wind speed when loading a hole for the very first time
function set_initial_wind()
  if mainmemory.read_u8(RDRAM.course_overview_spinning) == 1 then
    if mainmemory.read_u32_be(RDRAM.wind_speed) > WIND_SPEEDS[setting_wind_difficulty] then
      randomize_wind(setting_wind_difficulty)
    end
  end
end

-- Function that randomizes rain
function randomize_rain()

  -- Shy Guy International has a 1/16 chance of rain
  if mainmemory.read_u8(RDRAM.course_select) == 2 then
    if math.random(0, 15) > 0 then
      mainmemory.write_u8(RDRAM.rain_flag, 0)
    else
      mainmemory.write_u8(RDRAM.rain_flag, 1)
    end

  -- Yoshi Championship has a 1/3 chance of rain
  elseif mainmemory.read_u8(RDRAM.course_select) == 3 then
    if math.random(0, 2) > 0 then
      mainmemory.write_u8(RDRAM.rain_flag, 0)
    else
      mainmemory.write_u8(RDRAM.rain_flag, 1)
    end

  -- Every other course has a 1/4 chance of rain
  else
    if math.random(0, 3) > 0 then
      mainmemory.write_u8(RDRAM.rain_flag, 0)
    else
      mainmemory.write_u8(RDRAM.rain_flag, 1)
    end
  end
end

-- Function that gets a new random pin location
function get_new_pin_location(course_num, hole_num)

  -- Determine which course we're in
  if course_num == 0 then
    PINS = TOAD_TOURNAMENT_PINS
  elseif course_num == 1 then
    PINS = KOOPA_CUP_PINS
  elseif course_num == 2 then
    PINS = SHY_GUY_INTERNATIONAL_PINS
  elseif course_num == 3 then
    PINS = YOSHI_CHAMPIONSHIP_PINS
  elseif course_num == 4 then
    PINS = BOO_CLASSIC_PINS
  elseif course_num == 5 then
    PINS = MARIO_OPEN_PINS
  end

  -- Pick the random pin location
  i = math.random(0, 3)
  pin_x = PINS[(hole_num * 12) + (3 * i) + 1]
  pin_y = PINS[(hole_num * 12) + (3 * i) + 2]
  pin_z = PINS[(hole_num * 12) + (3 * i) + 3]

  return pin_x, pin_y, pin_z
end

-- Function that randomizes rain, pin location, wind direction and speed when saving to a file
-- Ignores mini-golf mode
function randomize_save_file()
  if mainmemory.read_u8(RDRAM.pause_menu_id) == 5 and mainmemory.read_u8(RDRAM.course_select) <= 5 then

    if setting_windsanity == 0 then
      gui.drawText(50, 80, "HOLD L OR R TO REROLL WIND/PIN LOCATION", "YELLOW", "Black", 22)
    end

    -- Check if A is pressed (not held) and the save menu allows user input
    if bit.check(mainmemory.read_u16_be(RDRAM.p1_pressed), 15) and mainmemory.read_u8(RDRAM.save_menu_phase) == 1 then

      -- Check if L or R is held (if windsanity is not enabled)
      if (bit.check(mainmemory.read_u16_be(RDRAM.p1_held), 4) or bit.check(mainmemory.read_u16_be(RDRAM.p1_held), 5)) or setting_windsanity == 1 then
        --set_character_save_file()

        randomize_wind(setting_wind_difficulty)
        randomize_rain()
        pin_x, pin_y, pin_z = get_new_pin_location(mainmemory.read_u8(RDRAM.course_select), mainmemory.read_u8(RDRAM.current_hole))
        
        -- Check which save file we are writing to
        if mainmemory.read_u8(RDRAM.save_menu_id) == 0 then
          mainmemory.write_u16_be(RDRAM.continue_1_wind_direction, mainmemory.read_u16_be(RDRAM.wind_direction))
          mainmemory.write_u32_be(RDRAM.continue_1_wind_speed, mainmemory.read_u32_be(RDRAM.wind_speed))
          mainmemory.write_u8(RDRAM.continue_1_rain, mainmemory.read_u8(RDRAM.rain_flag))
          mainmemory.write_u16_be(RDRAM.continue_1_pin_rng, math.random(0, 65535))
          mainmemory.write_u32_be(RDRAM.continue_1_pin_x, pin_x)
          mainmemory.write_u32_be(RDRAM.continue_1_pin_y, pin_y)
          mainmemory.write_u32_be(RDRAM.continue_1_pin_z, pin_z)
        elseif mainmemory.read_u8(RDRAM.save_menu_id) == 1 then
          mainmemory.write_u16_be(RDRAM.continue_2_wind_direction, mainmemory.read_u16_be(RDRAM.wind_direction))
          mainmemory.write_u32_be(RDRAM.continue_2_wind_speed, mainmemory.read_u32_be(RDRAM.wind_speed))
          mainmemory.write_u8(RDRAM.continue_2_rain, mainmemory.read_u8(RDRAM.rain_flag))
          mainmemory.write_u16_be(RDRAM.continue_2_pin_rng, math.random(0, 65535))
          mainmemory.write_u32_be(RDRAM.continue_2_pin_x, pin_x)
          mainmemory.write_u32_be(RDRAM.continue_2_pin_y, pin_y)
          mainmemory.write_u32_be(RDRAM.continue_2_pin_z, pin_z)
        elseif mainmemory.read_u8(RDRAM.save_menu_id) == 2 then
          mainmemory.write_u16_be(RDRAM.continue_3_wind_direction, mainmemory.read_u16_be(RDRAM.wind_direction))
          mainmemory.write_u32_be(RDRAM.continue_3_wind_speed, mainmemory.read_u32_be(RDRAM.wind_speed))
          mainmemory.write_u8(RDRAM.continue_3_rain, mainmemory.read_u8(RDRAM.rain_flag))
          mainmemory.write_u16_be(RDRAM.continue_3_pin_rng, math.random(0, 65535))
          mainmemory.write_u32_be(RDRAM.continue_3_pin_x, pin_x)
          mainmemory.write_u32_be(RDRAM.continue_3_pin_y, pin_y)
          mainmemory.write_u32_be(RDRAM.continue_3_pin_z, pin_z)
        end
      end
    end
  end
end

-- WINDSANITY
function windsanity()
  if setting_windsanity == 1 and mainmemory.read_u8(RDRAM.action_id) == 16 then
    randomize_wind(setting_wind_difficulty)
  end
end

local RINGSHOT_HOLES = {
  [0] = {1, 17, 16, 14, 18, 7},
  [1] = {2, 14, 12, 5, 3, 18},
  [2] = {14, 3, 13, 7, 5, 17},
  [3] = {15, 5, 8, 12, 17, 7},
  [4] = {1, 11, 16, 15, 18, 2},
  [5] = {15, 11, 9, 6, 17, 16},
}

-- PINSANITY
function pinsanity()
  if setting_pinsanity == 1 and mainmemory.read_u8(RDRAM.action_id) == 16 then

    -- Get pin locations
    if mainmemory.read_u8(RDRAM.game_mode) == 5 then
      pin_x, pin_y, pin_z = get_new_pin_location(mainmemory.read_u8(RDRAM.course_select), mainmemory.read_u8(RDRAM.current_hole))

    -- Get actual hole number from ringshot number
    elseif mainmemory.read_u8(RDRAM.game_mode) == 9 then
      ringshot_hole = RINGSHOT_HOLES[mainmemory.read_u8(RDRAM.course_select)][mainmemory.read_u8(RDRAM.current_hole) + 1]
      pin_x, pin_y, pin_z = get_new_pin_location(mainmemory.read_u8(RDRAM.course_select), ringshot_hole - 1)
    end

    mainmemory.write_u32_be(RDRAM.pin_x, pin_x)
    mainmemory.write_u32_be(RDRAM.pin_y, pin_y)
    mainmemory.write_u32_be(RDRAM.pin_z, pin_z)
  end
end

-- TOURNAMENT HOLE / BIRDIE / TROPHY DETECTION

local BIRDIE_BADGE_BASE = 0x1301a4

local last_action_id    = 0
local last_hole_checked = -1

local TROPHY_LOCATIONS = {
  { addr=0x1305f0, name="Toad Tournament - Gold Trophy"        },
  { addr=0x1305ef, name="Toad Tournament - Silver Trophy"      },
  { addr=0x1305eb, name="Toad Tournament - Bronze Trophy"      },
  { addr=0x130664, name="Koopa Cup - Gold Trophy"              },
  { addr=0x130663, name="Koopa Cup - Silver Trophy"            },
  { addr=0x13065f, name="Koopa Cup - Bronze Trophy"            },
  { addr=0x1306d8, name="Shy Guy International - Gold Trophy"  },
  { addr=0x1306d7, name="Shy Guy International - Silver Trophy"},
  { addr=0x1306d3, name="Shy Guy International - Bronze Trophy"},
  { addr=0x13074c, name="Yoshi Championship - Gold Trophy"     },
  { addr=0x13074b, name="Yoshi Championship - Silver Trophy"   },
  { addr=0x130747, name="Yoshi Championship - Bronze Trophy"   },
  { addr=0x1307c0, name="Boo Classic - Gold Trophy"            },
  { addr=0x1307bf, name="Boo Classic - Silver Trophy"          },
  { addr=0x1307bb, name="Boo Classic - Bronze Trophy"          },
  { addr=0x130834, name="Mario Open - Gold Trophy"             },
  { addr=0x130833, name="Mario Open - Silver Trophy"           },
  { addr=0x13082f, name="Mario Open - Bronze Trophy"           },
}
-- Gold   → { Silver, Bronze }   -- top implies both below
-- Silver → { Bronze }           -- middle implies only bottom
local TROPHY_IMPLIES = {
  ["Toad Tournament - Gold Trophy"]         = {"Toad Tournament - Silver Trophy",         "Toad Tournament - Bronze Trophy"},
  ["Koopa Cup - Gold Trophy"]               = {"Koopa Cup - Silver Trophy",               "Koopa Cup - Bronze Trophy"},
  ["Shy Guy International - Gold Trophy"]   = {"Shy Guy International - Silver Trophy",   "Shy Guy International - Bronze Trophy"},
  ["Yoshi Championship - Gold Trophy"]      = {"Yoshi Championship - Silver Trophy",      "Yoshi Championship - Bronze Trophy"},
  ["Boo Classic - Gold Trophy"]             = {"Boo Classic - Silver Trophy",             "Boo Classic - Bronze Trophy"},
  ["Mario Open - Gold Trophy"]              = {"Mario Open - Silver Trophy",              "Mario Open - Bronze Trophy"},
  ["Toad Tournament - Silver Trophy"]       = {"Toad Tournament - Bronze Trophy"},
  ["Koopa Cup - Silver Trophy"]             = {"Koopa Cup - Bronze Trophy"},
  ["Shy Guy International - Silver Trophy"] = {"Shy Guy International - Bronze Trophy"},
  ["Yoshi Championship - Silver Trophy"]    = {"Yoshi Championship - Bronze Trophy"},
  ["Boo Classic - Silver Trophy"]           = {"Boo Classic - Bronze Trophy"},
  ["Mario Open - Silver Trophy"]            = {"Mario Open - Bronze Trophy"},
}

local function mark_detected(name)
  if not detected_locations[name] then
    detected_locations[name] = true
    print("[MG64] Check complete: " .. name)
  end
  local implied = TROPHY_IMPLIES[name]
  if implied then
    for _, implied_name in ipairs(implied) do
      if not detected_locations[implied_name] then
        detected_locations[implied_name] = true
        print("[MG64] Check complete: " .. implied_name)
      end
    end
  end
end

--[[
local function check_trophies()
  get_total_strokes()
  memory.usememorydomain("RDRAM")
  for _, t in ipairs(TROPHY_LOCATIONS) do
    if memory.read_u32_be(t.addr) > 0 then
      mark_detected(t.name)
    end
  end
end
]]--

--[[
local HOLE_LOCATIONS = {
  { addr=0x1b71fb, name="Hole 1" },
  { addr=0x1b71fd, name="Hole 2" },
  { addr=0x1b71ff, name="Hole 3" },
  { addr=0x1b7201, name="Hole 4" },
  { addr=0x1b7203, name="Hole 5" },
  { addr=0x1b7205, name="Hole 6" },
  { addr=0x1b7207, name="Hole 7" },
  { addr=0x1b7209, name="Hole 8" },
  { addr=0x1b720b, name="Hole 9" },
  { addr=0x1b720d, name="Hole 10"},
  { addr=0x1b720f, name="Hole 11"},
  { addr=0x1b7211, name="Hole 12"},
  { addr=0x1b7213, name="Hole 13"},
  { addr=0x1b7215, name="Hole 14"},
  { addr=0x1b7217, name="Hole 15"},
  { addr=0x1b7219, name="Hole 16"},
  { addr=0x1b721b, name="Hole 17"},
  { addr=0x1b721d, name="Hole 18"},
}
]]--

local bronze_score = 72
local silver_score = 63
local gold_score = 62

--[[
local BEST_SCORES = {
  100, 100, 100, 100, 100, 100,
}
]]--

local BEST_SCORES = {}
  BEST_SCORES[0] = 100
  BEST_SCORES[1] = 100
  BEST_SCORES[2] = 100
  BEST_SCORES[3] = 100
  BEST_SCORES[4] = 100
  BEST_SCORES[5] = 100

local function get_best_score(course)
  if mainmemory.read_u8(RDRAM.game_mode) == 5 and mainmemory.read_u8(RDRAM.current_hole) == 17 and mainmemory.read_u8(RDRAM.action_id) == 20 then
    local score = 0

    for i = 0, 36, 2 do
      score = score + mainmemory.read_u8(0x1b71fb + i)
    end

    if score < BEST_SCORES[course] then
      BEST_SCORES[course] = score
    end

    --gui.drawText(60, 290, BEST_SCORES[course], "Red", "Black", 22)
  end
end

local function check_trophies()
  local i = -1
  local course = mainmemory.read_u8(RDRAM.course_select)
  get_best_score(course)
  
  memory.usememorydomain("RDRAM")
  for _, t in ipairs(TROPHY_LOCATIONS) do
    i = i + 1

    -- Check score. If not under threshold then skip
    if string.find(t.name, "Bronze") then
      if BEST_SCORES[math.floor(i/3)] <= bronze_score then mark_detected(t.name) end
    elseif string.find(t.name, "Silver") then
      if BEST_SCORES[math.floor(i/3)] <= silver_score then mark_detected(t.name) end
    elseif string.find(t.name, "Gold") then
      if BEST_SCORES[math.floor(i/3)] <= (gold_score - setting_gold_trophy_difficulty) then mark_detected(t.name) end
    end

    --if memory.read_u32_be(t.addr) > 0 then
      --mark_detected(t.name)
    --end
  end
end

local function check_birdie_badges()
  if setting_birdiesanity == 1 then
    memory.usememorydomain("RDRAM")
    -- FIX: read entire birdie badge block in one call (6 courses * 18 holes = 108 bytes)
    local badge_block = memory.read_bytes_as_array(BIRDIE_BADGE_BASE, 108)
    for ci = 0, 5 do
      local tourney = TOURNAMENT_NAMES[ci]
      for hi = 1, 18 do
        local idx = ci * 18 + (hi - 1) + 1  -- +1 for Lua 1-based array
        if badge_block[idx] == 1 then
          local birdie_name = tourney .. " - Birdie Badge " .. hi
          if not detected_locations[birdie_name] then
            detected_locations[birdie_name] = true
            print("[MG64] Check complete: " .. birdie_name)
          end
        end
      end
    end
  end
end

local function check_tournament_hole()
  local action    = mainmemory.read_u8(RDRAM.action_id)
  local game_mode = mainmemory.read_u8(RDRAM.game_mode)

  if game_mode ~= 5 then
    last_action_id = action
    return
  end

  if action == 20 and last_action_id ~= 20 then
    local course   = mainmemory.read_u8(RDRAM.course_select)
    local hole     = mainmemory.read_u8(RDRAM.current_hole)
    local hole_num = hole + 1
    local strokes  = mainmemory.read_u8(RDRAM.num_strokes)
    local hole_key = course * 100 + hole_num

    if course <= 5 and hole_key ~= last_hole_checked and hole_num >= 1 and hole_num <= 18 then
      last_hole_checked = hole_key
      local tourney = TOURNAMENT_NAMES[course]
      local par     = TOURNAMENT_PAR[course][hole_num]

      if setting_holesanity == 1 then
        local clear_name = tourney .. " - Hole " .. hole_num .. " Clear"
        if not detected_locations[clear_name] then
          detected_locations[clear_name] = true
          print("[MG64] Check complete: " .. clear_name)
        end
      end

      if setting_parsanity == 1 and strokes <= par then
        local par_name = tourney .. " - Hole " .. hole_num .. " Par"
        if not detected_locations[par_name] then
          detected_locations[par_name] = true
          print("[MG64] Check complete: " .. par_name)
        end
      end
    end
  end

  last_action_id = action
end

-- SOCKET COMMUNICATION

local function init_server()
  local err, res
  server, err = socket.socket.tcp4()
  if not server then print("Socket error: " .. (err or "")) return end
  server:setoption("reuseaddr", true)
  res, err = server:bind("127.0.0.1", SOCKET_PORT)
  if res == nil then print("Bind error: " .. (err or "")) server:close() server = nil return end
  res, err = server:listen(0)
  if err ~= nil then print("Listen error: " .. (err or "")) server:close() server = nil return end
  server:settimeout(0)
  print("Mario Golf 64 AP connector listening on port " .. SOCKET_PORT)
end

local function send_to_client(data)
  if not ap_socket then return end
  local ok, err = ap_socket:send(json_encode(data) .. "\n")
  if not ok and err ~= "timeout" then
    print("Send error: " .. (err or ""))
    ap_socket = nil
  end
end

-- FIX: drain ALL pending messages per frame, not just one
local function receive_from_client()
  if not ap_socket then return end
  ap_socket:settimeout(0)
  while true do
    local data, err = ap_socket:receive("*l")
    if err == "closed" or err == "reset" then
      print("Client disconnected.")
      ap_socket = nil
      return
    end
    if not data or data == "" then break end  -- no more data waiting
    local ok, p = pcall(json_decode_simple, data)
    if ok and p then
      if p.unlocks ~= nil then unlocks_word = p.unlocks end
      if p.courses ~= nil then courses_word = p.courses end
      if p.trap ~= nil and p.trap ~= "" then apply_trap(p.trap) end
      if p.death_in ~= nil and p.death_in == 1 then trigger_death_in() end
      if p.settings ~= nil then
        if p.settings.ringshotsanity         ~= nil then setting_ringshotsanity         = p.settings.ringshotsanity         end
        if p.settings.holesanity             ~= nil then setting_holesanity             = p.settings.holesanity             end
        if p.settings.birdiesanity           ~= nil then setting_birdiesanity           = p.settings.birdiesanity           end
        if p.settings.parsanity              ~= nil then setting_parsanity              = p.settings.parsanity              end
        if p.settings.minigolfsanity         ~= nil then setting_minigolfsanity         = p.settings.minigolfsanity         end
        if p.settings.versussanity           ~= nil then setting_versussanity           = p.settings.versussanity           end
        if p.settings.starting_putter        ~= nil then setting_starting_putter        = p.settings.starting_putter        end
        if p.settings.trophy_count           ~= nil then setting_trophy_count           = p.settings.trophy_count           end
        if p.settings.wind_difficulty        ~= nil then setting_wind_difficulty        = p.settings.wind_difficulty        end
        if p.settings.windsanity             ~= nil then setting_windsanity             = p.settings.windsanity             end
        if p.settings.pinsanity              ~= nil then setting_pinsanity              = p.settings.pinsanity              end
        if p.settings.gold_trophy_difficulty ~= nil then setting_gold_trophy_difficulty = p.settings.gold_trophy_difficulty end
        if p.settings.num_gold_trophies      ~= nil then num_gold_trophies              = p.settings.num_gold_trophies      end
        if p.settings.required_courses       ~= nil then required_courses               = p.settings.required_courses       end
        if p.settings.death_link             ~= nil then death_link_enabled = (p.settings.death_link == 1) end
      end
      apply_unlocks_to_sram()
    end
  end
end

-- MAIN LOOP

event.onexit(function()
  if ap_socket then ap_socket:close() end
  if server then server:close() end
  forms.destroyall()
  gui.clearImageCache()
  gui.clearGraphics()
  print("Mario Golf 64 AP connector stopped.")
end)

init_server()

while true do
  frame = frame + 1

  -- Accept new connections (check every 60 frames / ~1 second)
  if server ~= nil and ap_socket == nil and frame % 60 == 0 then
    has_connected = true
    local client = server:accept()
    if client then
      ap_socket = client
      print("AP client connected on port " .. SOCKET_PORT .. ".")
      memory.usememorydomain("SRAM")
      unlocks_word = memory.read_u32_be(SRAM_UNLOCKS)
      courses_word = memory.read_u32_be(SRAM_COURSES)
      -- Snapshot ring shot SRAM so pre-existing completions aren't sent as new checks
      baseline_sram = {}
      for ci = 0, 5 do
        for hi = 0, 5 do
          local offset = ci * 6 + hi
          baseline_sram[offset] = memory.read_u8(RING_SHOT_SRAM_BASE + offset)
        end
      end
      memory.usememorydomain("RDRAM")
      print("[MG64] Baseline ring shot SRAM snapshotted.")
    end
  end

  -- Receive every frame (drains full queue hopefully)
  if ap_socket ~= nil then
    receive_from_client()
  end

  -- expects a regular heartbeat. Skipping sends causes a timeout → disconnect.
  -- Python deduplicates via local_checked_locations so resending is safe.
  if ap_socket ~= nil and frame % 30 == 0 then
    local locs = get_completed_locations()
    local d_out = death_out_pending and 1 or 0
    death_out_pending = false
    local game_complete = detected_locations["Mario Open - Gold Trophy"] == true

    -- PopTracker data
    local c_mode = mainmemory.read_u8(RDRAM.game_mode)
    local c_course = mainmemory.read_u8(RDRAM.course_select)
    local c_hole = mainmemory.read_u8(RDRAM.current_hole)
    
    send_to_client({ locations = locs, gameComplete = game_complete, death_out = d_out, current_mode = c_mode, current_course = c_course, current_hole = c_hole })
  end

  -- Game logic runs every frame
  gui.clearGraphics()
  enforce_shot_type()
  process_rain_trap()
  process_hurricane_trap()
  process_terrible_lie_trap()
  process_fast_meter()
  process_death_in()
  check_tournament_hole()
  check_death_out()
  check_birdie_badges()
  check_trophies()
  --gui.drawText(255, 320, num_gold_trophies, "Red", "Black", 25)
  --gui.drawText(255, 340, ringshot_hole, "Red", "Black", 25)

  local _action = mainmemory.read_u8(RDRAM.action_id)
  local _menu   = mainmemory.read_u8(RDRAM.menu_id)

  -- Check to see if in stroke/mini golf or tournament or ring shot game mode
  if mainmemory.read_u8(RDRAM.game_mode) == 5 or mainmemory.read_u8(RDRAM.game_mode) == 9 then
    set_initial_wind()
    windsanity()
    pinsanity()
    randomize_save_file()

    -- Allow death links to be sent after each shot attempt
    if _action == 2 then
      death_link_can_send = true
    end
  end

  -- Reset club to 1W only when ball enters hole AND putter is equipped
  if _action == 20 and _menu == 12 and mainmemory.read_u8(RDRAM.current_club) == 13 then
    mainmemory.write_u8(RDRAM.current_club, 0)
  end

  -- Reset certain addresses when on main menu
  if _menu == 0 then
    mainmemory.write_u8(RDRAM.current_hole, 255)
    mainmemory.write_u8(RDRAM.action_id, 0)
  end

  -- Club restriction runs LAST so nothing overrides it
  enforce_club_restriction()

  if mainmemory.read_u8(RDRAM.course_overview_spinning) == 1 then
    mainmemory.write_u8(RDRAM.save_menu_phase, 0)
  end

  local menu = mainmemory.read_u8(RDRAM.menu_id)

  if menu == 0 then
    mainmemory.write_u8(RDRAM.main_menu_num_players, 0)

  elseif menu == 1 then
    set_character_select()

  elseif menu == 3 then
    load_save_file()

  elseif menu == 5 then
    set_play_mode_select()

  elseif menu == 6 then
    local play_mode = mainmemory.read_u8(RDRAM.menu_play_mode_id)
    local game_mode = mainmemory.read_u8(RDRAM.game_mode)

    if play_mode == 0 and game_mode == 5 then
      set_tournament_course()
    elseif play_mode == 5 and game_mode == 0 then
      set_mini_golf_course()
    end

  elseif menu == 18 then
    local game_mode = mainmemory.read_u8(RDRAM.game_mode)
    if game_mode == 9 then
      set_ring_shot_menu()
    end
  end

  -- Show a warning if not connected to the server
  if server ~= nil and ap_socket == nil and has_connected == true then
    gui.drawText(70, 180, "Lost connection. Please close/reopen the", "Red", "Black", 20)
    gui.drawText(75, 200, " Lua Console and rerun the lua script.", "Red", "Black", 20)
  end

  emu.frameadvance()
end
