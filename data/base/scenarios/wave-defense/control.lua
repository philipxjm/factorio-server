require "util"
require "mod-gui"
local increment = util.increment
local format_number = util.format_number
local format_time = util.formattime

script.on_event(defines.events.on_rocket_launched, function(event)
  local rocket = event.rocket
  if rocket.get_item_count("satellite") > 0 then
    game.set_game_state{game_finished = true, player_won = true, can_continue = true}
    global.send_satellite_round = false
    wave_end()
    update_connected_players()
  else
    game.print({"no-satellite"})
  end
end)

script.on_init(function()
  init_globals()
  setup_waypoints()
  init_forces()
  game.map_settings.pollution.enabled = false
  randomize_ore()
end)

script.on_event(defines.events.on_entity_died, function(event)
  local entity_type = event.entity.type
  if entity_type == "unit" then
    unit_died(event)
    return
  end
  if entity_type == "rocket-silo" then
    rocket_died(event)
    return
  end
end)

script.on_event(defines.events.on_player_created, function(event)
  local player = game.players[event.player_index]
  give_spawn_equipment(player)
  give_starting_equipment(player)
  if player.index == 1 then
    game.show_message_dialog({text = {"welcome-to-wave-defense"}})
  else
    player.print({"welcome-to-wave-defense"})
  end
end)

script.on_event(defines.events.on_player_joined_game, function(event)
  local player = game.players[event.player_index]
  gui_init(player)
end)

script.on_event(defines.events.on_player_respawned, function(event)
  local player = game.players[event.player_index]
  give_spawn_equipment(player)
end)

script.on_event(defines.events.on_gui_click, function(event)
  local gui = event.element
  local player = game.players[event.player_index]
  if gui.name == "send_next_wave" then
    local skipped = math.floor(global.skipped_multiplier*(global.wave_tick - game.tick)*(1.15^global.wave_number))
    increment(global, "money", skipped)
    next_wave()
    if #game.players > 1 then
      game.print({"sent-next-wave", player.name})
    else
      game.print({"next-wave"})
    end
    update_connected_players()
    return
  end
  if gui.name == "upgrade_button" then
    create_upgrade_gui(player.gui.center)
    return
  end
  if gui.name == "wave_defense_visibility_button" then
    local gui =  mod_gui.get_frame_flow(player)
    gui.wave_frame.style.visible = not gui.wave_frame.style.visible
    return
  end
  if global.team_upgrades[gui.name] then
    local list = get_upgrades()
    local upgrades = global.team_upgrades
    local price = list[gui.name].price(upgrades[gui.name])
    if global.money >= price then
      increment(global, "money", -price)
      local sucess = false
      for k, effect in pairs (list[gui.name].effect) do
        sucess = effect(event)
      end
      if sucess and (#game.players > 1) then
        game.print({"purchased-team-upgrade", player.name, list[gui.name].caption,upgrades[gui.name]})
      end
      update_connected_players()
      for k, player in pairs (game.connected_players) do
        local gui = player.gui.center
        if gui.team_upgrade_frame then
          update_upgrade_listing(gui.team_upgrade_frame.team_upgrade_scroll.upgrade_table, list, upgrades)
        end
      end
    else
      player.print({"not-enough-money"})
    end
    return
  end
end)

script.on_event(defines.events.on_tick, function (event)
  local tick = event.tick
  check_next_wave(tick)
  check_spawn_units(tick)
  if tick % 60 == 0 then
    update_connected_players()
  end
end)

function init_forces()
  for k, force in pairs (game.forces) do
    set_research(force)
    set_recipes(force)
    force.set_spawn_position(global.silo.position, game.surfaces[1])
    force.friendly_fire = false
  end
end

function init_globals()
  global.wave_number = 0
  global.wave_tick = 21250
  global.force_bounty_modifier = 0.5
  global.bounty_bonus = 1
  global.skipped_multiplier = 0.1
  global.round_button_visible = true
  global.silo = game.surfaces[1].find_entities_filtered{name = "rocket-silo"}[1]
  global.silo.minable = false
  global.money = 0
  global.send_satellite_round = false
  global.spawn_time = 2500
  global.wave_time = 10000
  global.team_upgrades = {}
  init_unit_settings()
  for name, upgrade in pairs (get_upgrades()) do
    global.team_upgrades[name] = 0
  end
end

function init_unit_settings()
  game.map_settings.unit_group.max_group_slowdown_factor = 1
  game.map_settings.unit_group.max_member_speedup_when_behind = 2
  game.map_settings.unit_group.max_member_slowdown_when_ahead = 0.8
  game.map_settings.unit_group.member_disown_distance = 25
  game.map_settings.unit_group.min_group_radius = 8.0
  game.map_settings.path_finder.use_path_cache = true
  game.map_settings.path_finder.max_steps_worked_per_tick = 300
  game.map_settings.path_finder.short_cache_size = 50
  game.map_settings.path_finder.long_cache_size = 50
end

function check_next_wave(tick)
  if not global.wave_tick then return end
  if global.wave_tick ~= tick then return end
  game.print({"next-wave"})
  next_wave()
end

function next_wave()
  increment(global, "wave_number")
  make_next_wave_tick()
  make_next_spawn_tick()
  local exponent = math.min(#game.connected_players, 8)
  global.force_bounty_modifier = (0.5 * (1.15/(1.15^exponent)))
  update_round_number()
  global.wave_power = calculate_wave_power(global.wave_number)
  next_round_button_visible(false)
  local value = math.floor(100*((global.wave_number-1)%20+1)/20)
  if global.silo.valid then
    global.silo.rocket_parts = value
  end
  global.send_satellite_round = (value == 100)
  command_straglers()
  spawn_units()
end

function calculate_wave_power(x)
  local c = 1.65
  local p = math.min(#game.connected_players, 8)
  if x % 4 == 0 then
    return math.floor((1.15^p)*(x^c)*60)
  elseif x % 2 == 0 then
    return math.floor((1.15^p)*(x^c)*50)
  else
    return math.floor((1.15^p)*(x^c)*40)
  end
end

function wave_end()
  next_round_button_visible(true)
  game.print({"wave-over"})
  spawn_units()
  global.spawn_tick = nil
end

function make_next_spawn_tick()
  global.spawn_tick = game.tick + math.random(200, 300)
end

function check_spawn_units(tick)
  if not global.spawn_tick then return end

  if global.send_satellite_round then
    global.end_spawn_tick = tick+1
    global.wave_tick = tick+global.wave_time
    if (tick) % 250 == 0 then
      if not global.silo.get_inventory(defines.inventory.rocket_silo_rocket) then
        global.silo.rocket_parts = 100
      end
    end
  end

  if global.end_spawn_tick <= tick then
    wave_end()
    return
  end

  if global.spawn_tick == tick then
    spawn_units()
    make_next_spawn_tick()
  end
end

function get_wave_units(x)
  local units = {}
  local k = 1
  for unit_name, unit in pairs (unit_config) do
    if unit.in_wave(x) then
      units[k] = {name = unit_name, cost = unit.cost}
      k = k + 1
    end
  end
  return units
end

function spawn_units()

  local rand = math.random
  local surface = game.surfaces[1]
  if surface.count_entities_filtered{type = "unit"} > 500 then return end
  local power = 0+global.wave_power
  local spawns = global.spawns
  local spawns_count = #spawns
  local units = get_wave_units(global.wave_number)
  local units_length = #units
  local groups = {}
  local group_count = 1
  local new_group = true
  local spawn
  local unit_count
  local group

  while units_length > 0 do
    if new_group == true then
      spawn = spawns[rand(spawns_count)]
      group = surface.create_unit_group{position = spawn}
      groups[group_count] = group; group_count = group_count + 1
      new_group = false
      unit_count = 0
    end
    local k = rand(units_length)
    local biter = units[k]
    local cost = biter.cost
    if cost > power then
      table.remove(units, k)
      units_length = units_length - 1
    else
      local position = surface.find_non_colliding_position(biter.name, spawn, 32, 2)
      if position then
        if unit_count <= 500 then
          group.add_member(surface.create_entity{name = biter.name, position = position})
          power = power-cost
          unit_count = unit_count + 1
        else
          new_group = true
        end
      else
        break
      end
    end
  end
  set_command(groups)
end

function randomize_ore()
  local surface = game.surfaces[1]
  local rand = math.random
  for k, ore in pairs (surface.find_entities_filtered{type = "resource"}) do
    ore.amount = ore.amount + rand(-5,5)
  end
end

function set_command(groups)
  if not global.silo then return end
  if not global.silo.valid then return end
  local waypoints = global.waypoints
  local num_waypoints = #waypoints
  local rand = math.random
  local def = defines
  local compound = def.command.compound
  local structure = def.compound_command.return_last
  local go_to = def.command.go_to_location
  local attack = def.command.attack
  local target = global.silo
  for k, group in pairs (groups) do
    group.set_command
    {
      type = compound,
      structure_type = structure,
      commands =
      {
        {type = go_to, destination = waypoints[rand(num_waypoints)]},
        {type = attack, target = target}
      }
    }
  end
end

function command_straglers()
  local command = {type = defines.command.attack, target = global.silo}
  for k, unit in pairs (game.surfaces[1].find_entities_filtered({type = "unit"})) do
    if not unit.unit_group then
      unit.set_command(command)
    end
  end
end

unit_config =
  {
    ["small-biter"] =      {bounty = 20, cost = 10, in_wave = function(x) return (x<=5) end},
    ["small-spitter"] =    {bounty = 30, cost = 20, in_wave = function(x) return ((x>=3) and (x<=8)) end},
    ["medium-biter"] =     {bounty = 120, cost = 80 , in_wave = function(x) return ((x>=5) and (x<=10)) end},
    ["medium-spitter"] =   {bounty = 50, cost = 120, in_wave = function(x) return ((x>=7) and (x<=12)) end},
    ["big-biter"] =        {bounty = 400, cost = 300, in_wave = function(x) return (x>=11) and (x<=19) end},
    ["big-spitter"] =      {bounty = 200, cost = 400, in_wave = function(x) return (x>=13) and (x<=21) end},
    ["behemoth-biter"] =   {bounty = 1200, cost = 800, in_wave = function(x) return (x>=15) end},
    ["behemoth-spitter"] = {bounty = 500, cost = 650, in_wave = function(x) return (x>=17) end}
  }

function make_next_wave_tick()
  global.end_spawn_tick = game.tick + global.spawn_time
  global.wave_tick  = global.end_spawn_tick + global.wave_time
end

function time_to_next_wave()
  if not global.wave_tick then return end
  return format_time(global.wave_tick - game.tick)
end

function time_to_wave_end()
  if not global.end_spawn_tick then return end
  return format_time(global.end_spawn_tick - game.tick)
end

function rocket_died(event)
  local silo = event.entity
  if silo == global.silo then
    game.set_game_state{game_finished = true, player_won = false, can_continue = false}
  end
end

function unit_died(event)
  local force = event.force
  if not force then return end
  if not force.valid then return end
  local died = event.entity
  local surface = died.surface
  local cash = math.floor(get_bounty_price(died.name)*global.force_bounty_modifier*global.bounty_bonus)
  increment(global, "money", cash)
  surface.create_entity{name = "flying-text", position = died.position, text = "+"..cash, color = {r = 0.2, g = 0.8, b = 0.2, a = 0.2}}
  if global.wave_number < 20 then return end
  for k, belt in pairs (surface.find_entities_filtered{area = died.bounding_box, type = "transport-belt", limit = 1}) do
    belt.damage(50, "enemy")
  end
end

function get_bounty_price(name)
  if not unit_config[name] then game.print(name.." not in config") return 0 end
  if not unit_config[name].bounty then game.print(name.." not in bounty list") return 0 end
  return unit_config[name].bounty
end

function setup_waypoints()
  local surface = game.surfaces[1]
  local w = surface.map_gen_settings.width
  local threshold = -((5*w)/8)
  local spawns = {}
  local waypoints = {}
  for k, entity in pairs (surface.find_entities_filtered{name = "big-worm-turret"}) do
    local position = entity.position
    local X = position.x
    local Y = position.y
    local I = Y-X
    if I > threshold then
      table.insert(waypoints, position)
    else
      table.insert(spawns, position)
    end
    entity.destroy()
  end
  global.waypoints = waypoints
  global.spawns = spawns
end

function insert_items(entity, array)
  for name, count in pairs (array) do
    entity.insert({name = name, count = count})
  end
end

function give_starting_equipment(player)
  local items =
  {
    ["iron-plate"] = 200,
    ["pipe"] = 200,
    ["pipe-to-ground"] = 50,
    ["copper-plate"] = 200,
    ["steel-plate"] = 200,
    ["iron-gear-wheel"] = 250,
    ["transport-belt"] = 600,
    ["underground-belt"] = 40,
    ["splitter"] = 40,
    ["gun-turret"] = 8,
    ["stone-wall"] = 50,
    ["repair-pack"] = 20,
    ["inserter"] = 100,
    ["burner-inserter"] = 50,
    ["small-electric-pole"] = 50,
    ["medium-electric-pole"] = 50,
    ["big-electric-pole"] = 15,
    ["burner-mining-drill"] = 50,
    ["electric-mining-drill"] = 50,
    ["stone-furnace"] = 35,
    ["steel-furnace"] = 20,
    ["electric-furnace"] = 8,
    ["assembling-machine-1"] = 50,
    ["assembling-machine-2"] = 20,
    ["assembling-machine-3"] = 8,
    ["electronic-circuit"] = 200,
    ["fast-inserter"] = 100,
    ["long-handed-inserter"] = 100,
    ["substation"] = 10,
    ["boiler"] = 10,
    ["offshore-pump"] = 1,
    ["steam-engine"] = 20,
    ["chemical-plant"] = 20,
    ["oil-refinery"] = 5,
    ["pumpjack"] = 10,
    ["small-lamp"] = 20
  }
  insert_items(player, items)
end

function give_spawn_equipment(player)
  local items =
    {
      ["steel-axe"] = 3,
      ["submachine-gun"] = 1,
      ["firearm-magazine"] = 40,
      ["shotgun"] = 1,
      ["shotgun-shell"] = 20,
      ["power-armor"] = 1,
      ["construction-robot"] = 20,
      ["blueprint"] = 3,
      ["deconstruction-planner"] = 1
    }
  insert_items(player, items)
  local equipment =
    {
      "fusion-reactor-equipment",
      "exoskeleton-equipment",
      "personal-roboport-equipment",
      "personal-roboport-equipment"
    }
  local armor = player.get_inventory(5)[1].grid
  for k, name in pairs (equipment) do
    armor.put({name = name})
  end
  for k, equipment in pairs (armor.equipment) do
    equipment.energy = equipment.max_energy
  end
end

function next_round_button_visible(bool)
  for k, player in pairs (game.connected_players) do
    mod_gui.get_frame_flow(player).wave_frame.send_next_wave.style.visible = bool
  end
  global.round_button_visible = bool
end

function gui_init(player)
  local gui = mod_gui.get_frame_flow(player)
  if gui.wave_frame then
    gui.wave_frame.destroy()
  end
  create_wave_frame(gui)
  local button_flow = mod_gui.get_button_flow(player)
  local button = button_flow.wave_defense_visibility_button
  if not button then
    button_flow.add
    {
      type = "sprite-button",
      name = "wave_defense_visibility_button",
      style = mod_gui.button_style,
      sprite = "entity/behemoth-spitter",
      tooltip = {"visibility-button-tooltip"}
    }
  end
  local upgrade_button = button_flow.upgrade_button
  if upgrade_button then upgrade_button.destroy() end
  upgrade_button = button_flow.add{
    type = "sprite-button",
    name = "upgrade_button",
    caption = {"upgrade-button"},
    tooltip = {"upgrade-button-tooltip"},
    style = mod_gui.button_style
  }
  if gui.team_upgrade_frame then
    gui.team_upgrade_frame.destroy()
  end
end

function create_wave_frame(gui)
  if not gui.valid then return end
  local frame = gui.add{type = "frame", name = "wave_frame", caption = {"wave-frame"}, direction = "vertical"}
  frame.style.visible = true
  frame.add{type = "label", name = "current_wave", caption = {"current-wave", global.wave_number}}
  frame.add{type = "label", name = "time_to_next_wave", caption = {"time-to-next-wave", time_to_next_wave()}}
  local money_table = frame.add{type = "table", name = "money_table", column_count = 2}
  money_table.add{type = "label", name = "force_money_label", caption = {"force-money"}}
  local cash = money_table.add{type = "label", name = "force_money_count", caption = get_money()}.style
  cash.font_color = {r = 0.8, b = 0.5, g = 0.8}
  local button = frame.add
  {
    type = "button",
    name = "send_next_wave",
    caption = {"send-next-wave"},
    tooltip = {"send-next-wave-tooltip"},
    style = "play_tutorial_button"
  }
  button.style.font = "default"
  button.style.visible = global.round_button_visible
end

function create_upgrade_gui(gui)
  local player = game.players[gui.player_index]
  if gui.team_upgrade_frame then
    gui.team_upgrade_frame.destroy()
    return
  end
  local team_upgrades = gui.add{type = "frame", name = "team_upgrade_frame", caption = {"buy-upgrades"}, direction = "vertical"}
  team_upgrades.style.visible = true
  team_upgrades.style.title_bottom_padding = 2
  local money_table = team_upgrades.add{type = "table", name = "money_table", column_count = 2}
  money_table.style.column_alignments[2] = "right"
  local label = money_table.add{type = "label", name = "force_money_label", caption = {"force-money"}}
  label.style.font = "default-semibold"
  local cash = money_table.add{type = "label", name = "force_money_count", caption = get_money()}.style
  cash.font_color = {r = 0.8, b = 0.5, g = 0.8}
  local scroll = team_upgrades.add{type = "scroll-pane", name = "team_upgrade_scroll"}
  scroll.style.maximal_height = 450
  local upgrade_table = scroll.add{type = "table", name = "upgrade_table", column_count = 2}
  upgrade_table.style.horizontal_spacing = 0
  upgrade_table.style.vertical_spacing = 0
  update_upgrade_listing(upgrade_table, get_upgrades(), global.team_upgrades)
  player.opened = team_upgrades
end

script.on_event(defines.events.on_gui_closed, function(event)
  local gui = event.element
  if not gui then return end
  local name = gui.name
  if not name then return end
  if name == "team_upgrade_frame" then
    gui.destroy()
  end
end)

function update_upgrade_listing(gui, array, upgrades)
  for name, upgrade in pairs (array) do
    local level = upgrades[name]
    if not gui[name] then
      local sprite = gui.add{type = "sprite-button", name = name, sprite = upgrade.sprite, tooltip = {"purchase"}, style = "play_tutorial_button"}
      sprite.style.minimal_height = 75
      sprite.style.minimal_width = 75
      local flow = gui.add{type = "frame", name = name.."_flow", direction = "vertical"}
      flow.style.maximal_height = 75
      local another_table = flow.add{type = "table", name = name.."_label_table", column_count = 1}
      another_table.style.vertical_spacing = 2
      local label = another_table.add{type = "label", name = name.."_name", caption = {"", upgrade.caption, " "..upgrade.modifier}}
      label.style.font = "default-bold"
      another_table.add{type = "label", name = name.."_price", caption = {"upgrade-price", format_number(upgrade.price(level))}}
      if not upgrade.hide_level then
        local level = another_table.add{type = "label", name = name.."_level", caption = {"upgrade-level", level}}
      end
    else
      gui[name.."_flow"][name.."_label_table"][name.."_price"].caption = {"upgrade-price", format_number(upgrade.price(level))}
      if not upgrade.hide_level then
        gui[name.."_flow"][name.."_label_table"][name.."_level"].caption = {"upgrade-level", level}
      end
    end
  end
end

upgrade_research =
{
  ["bullet-damage"] = 2500,
  ["bullet-speed"] = 1500,
  ["shotgun-shell-damage"] = 1250,
  ["shotgun-shell-speed"] = 2500,
  ["flamethrower-damage"] = 7500,
  ["gun-turret-damage"] = 2000,
  ["laser-turret-damage"] = 2500,
  ["laser-turret-speed"] = 2250,
  ["rocket-damage"] = 1000,
  ["rocket-speed"] = 750,
  ["grenade-damage"] = 1500,
  ["follower-robot-count"] = 500,
  ["combat-robot-damage"] = 1000,
  ["mining-productivity"] = 750,
  ["cannon-shell-damage"] = 500,
  ["cannon-shell-speed"] = 250,
}

function get_upgrades()
  local list = {}
  local tech = game.forces["player"].technologies
  for name, price in pairs (upgrade_research) do
    local append = name.."-1"
    if tech[append] then
      local base = tech[append]
      local upgrade = {}
      local mod = base.effects[1].modifier
      upgrade.modifier = "+"..tostring(mod*100).."%"
      upgrade.price = function(x) return math.floor((1+x))*price end
      upgrade.sprite = "technology/"..append
      upgrade.caption = {"technology-name."..name}
      upgrade.effect = {}
      for k, effect in pairs (base.effects) do
        local type = effect.type
        if type == "ammo-damage" then
          local cat = effect.ammo_category
          upgrade.effect[k] = function(event)
            local force = game.players[event.player_index].force
            force.set_ammo_damage_modifier(cat, force.get_ammo_damage_modifier(cat)+mod)
            increment(global.team_upgrades, name)
            return true
          end
        elseif type == "turret-attack" then
          local id = effect.turret_id
          upgrade.effect[k] = function(event)
            local force = game.players[event.player_index].force
            force.set_turret_attack_modifier(id, force.get_turret_attack_modifier(id)+mod)
            increment(global.team_upgrades, name)
            return true
          end
        elseif type == "gun-speed" then
          local cat = effect.ammo_category
          upgrade.effect[k] = function(event)
            local force = game.players[event.player_index].force
            force.set_gun_speed_modifier(cat, force.get_gun_speed_modifier(cat)+mod)
            increment(global.team_upgrades, name)
            return true
          end
        elseif type == "maximum-following-robots-count" then
          upgrade.modifier = "+"..tostring(mod)
          upgrade.effect[k] = function(event)
            local force = game.players[event.player_index].force
            increment(force, "maximum_following_robot_count", mod)
            increment(global.team_upgrades, name)
            return true
          end
        elseif type == "mining-drill-productivity-bonus" then
          upgrade.effect[k] = function(event)
            local force = game.players[event.player_index].force
            increment(force, "mining_drill_productivity_bonus", mod)
            increment(global.team_upgrades, name)
            return true
          end
        else error(name.." - This tech has no relevant upgrade effect") end
      end
      list[name] = upgrade
    end
  end
  local bonus = {}
  bonus.modifier = "+10%"
  bonus.sprite = "technology/energy-shield-equipment"
  bonus.price = function(x) return math.floor((1+x))*2500 end
  bonus.effect = {}
  bonus.effect[1] =  function (event)
    increment(global, "bounty_bonus", 0.1)
    increment(global.team_upgrades, "bounty_bonus")
    return true
  end
  bonus.caption = {"bounty-bonus"}
  list["bounty_bonus"] = bonus
  local sat = {}
  sat.modifier = ""
  sat.sprite = "technology/rocket-silo"
  sat.price = function(x) return 500000 end
  sat.hide_level = true
  sat.effect = {}
  sat.effect[1] = function(event)
    if not global.silo then error("No global silo") return end
    local inventory = global.silo.get_inventory(defines.inventory.rocket_silo_rocket)
    if inventory then
      local contents = global.silo.get_inventory(defines.inventory.rocket_silo_rocket).get_contents()
      if #contents == 0 then
        inventory.insert"satellite"
        game.print({"satellite-purchase", game.players[event.player_index].name})
        return false
      end
    end
    increment(global, "money", 500000)
    game.players[event.player_index].print({"satellite-refund"})
    return false
  end
  sat.caption = {"buy-satellite"}
  list["buy-satellite"] = sat
  return list
end

function get_money()
  return format_number(global.money)
end

function update_connected_players()
  local update_timer = function (gui, time_left, label)
    if not gui.wave_frame then return end
    if not gui.wave_frame.time_to_next_wave then return end
    local label = gui.wave_frame.time_to_next_wave
    if global.spawn_tick then
      label.caption = {"time-to-wave-end", time_left}
    elseif global.wave_tick then
      label.caption = {"time-to-next-wave", time_left}
    end
    if global.send_satellite_round then
      label.caption = {"send-satellite"}
    end
  end
  local update_money_amounts = function(player)
    local wave_frame = mod_gui.get_frame_flow(player).wave_frame
    local money_table = wave_frame.money_table
    money_table.force_money_count.caption = get_money()
    local frame = player.gui.center.team_upgrade_frame
    if not frame then return end
    local money_table = frame.money_table
    money_table.force_money_count.caption = get_money()
  end
  local time_left
  if global.spawn_tick then
    time_left = time_to_wave_end()
  elseif global.wave_tick then
    time_left = time_to_next_wave()
  else
    time_left = "Somethings gone wrong here... ?"
  end
  for k, player in pairs (game.connected_players) do
    update_timer(mod_gui.get_frame_flow(player), time_left, label)
    update_money_amounts(player.gui.center)
  end
end

function update_round_number()
  local update = function (gui, caption)
    if not gui.wave_frame then return end
    if not gui.wave_frame.current_wave then return end
    local label = gui.wave_frame.current_wave
    label.caption = caption
  end
  local caption = {"current-wave", global.wave_number}
  for k, player in pairs (game.connected_players) do
    update(mod_gui.get_frame_flow(player), caption)
  end
end

function set_research(force)
  force.research_all_technologies()
  local tech = force.technologies
  for name in pairs (upgrade_research) do
    for i = 1, 20 do
      local full_name = name.."-"..i
      if tech[full_name] then
        tech[full_name].researched = false
      end
    end
  end
  force.reset_technology_effects()
  force.disable_research()
end

function set_recipes(force)
  local recipes = force.recipes
  local disable =
  {
    "science-pack-1",
    "science-pack-2",
    "science-pack-3",
    "military-science-pack",
    "production-science-pack",
    "high-tech-science-pack",
    "lab"
  }

  for k, name in pairs (disable) do
    if recipes[name] then
      recipes[name].enabled = false
    else
      error(name.." is not a valid recipe")
    end
  end
end
