require "util"
require "story"


local supplies =
{
  ["piercing-rounds-magazine"] =  800,
  ["steel-plate"] = 1500,
  ["iron-plate"] = 3000,
  ["copper-plate"] = 3000,
  ["solar-panel"] = 50
}

function check_supplies(force)
  if not force and game.tick % 60 ~= 0 then return end
  local counts = {}
  local finished = true
  local items = game.item_prototypes
  for name, require in pairs (supplies) do
    if not items[name] then error(name.." is not a valid item") end
    counts[name] = {required = require, count = 0}
  end
  for k, player in pairs (game.players) do
    for name, supply in pairs (counts) do
      supply.count = supply.count + player.get_item_count(name)
    end
    local car = player.vehicle
    if car then
      local driver = car.get_driver()
      if driver and driver.player and driver.player.index == player.index then
        for name, supply in pairs (counts) do
          supply.count = supply.count + car.get_item_count(name)
        end
      end
    end
  end
  global.counts = counts
  set_info({custom_function = build_gui})
  return global.finished
end

function build_gui(gui)
  local counts = global.counts
  if not counts then return end
  local items = game.item_prototypes
  local table = gui.add{type = "table", column_count = 3}
  table.style.top_padding = 12
  table.style.column_alignments[3] = "right"
  global.finished = true
  for name, supply in pairs (counts) do
    local sprite = table.add{type = "sprite", sprite = "item/"..name}
    local label = table.add{type = "label", caption = items[name].localised_name}
    label.style.font = "default-large"
    local count = table.add{type = "label"}
    if supply.count < supply.required then
      count.caption = supply.count.."/"..supply.required
      count.style.font_color = {r = 1, g = 0.2, b = 0.2}
      global.finished = false
    else
      count.caption = supply.required.."/"..supply.required
      count.style.font_color = {r = 0.3, g = 0.9, b = 0.3}
    end
  end
end

script.on_init(function()
  global.story = story_init()
  game.players[1].force.reset_recipes() --Fix some 0.12->0.13 migration issue
  game.players[1].force.disable_all_prototypes()
  game.map_settings.enemy_expansion.enabled = false
  game.forces.enemy.evolution_factor = 0
  game.map_settings.enemy_evolution.enabled = false
  local recipe_list = game.players[1].force.recipes
  recipe_list["iron-plate"].enabled = true
  recipe_list["copper-plate"].enabled = true
  recipe_list["stone-brick"].enabled = true
  recipe_list["wood"].enabled = true
  recipe_list["stone-furnace"].enabled = true
  recipe_list["iron-stick"].enabled = true
  recipe_list["iron-axe"].enabled = true
  recipe_list["wooden-chest"].enabled = true
  recipe_list["iron-gear-wheel"].enabled = true
  recipe_list["burner-mining-drill"].enabled = true
  recipe_list["transport-belt"].enabled = true
  recipe_list["burner-inserter"].enabled = true
  recipe_list["pipe"].enabled = true
  recipe_list["pipe-to-ground"].enabled = true
  recipe_list["boiler"].enabled = true
  recipe_list["steam-engine"].enabled = true
  recipe_list["electronic-circuit"].enabled = true
  recipe_list["copper-cable"].enabled = true
  recipe_list["pistol"].enabled = true
  recipe_list["firearm-magazine"].enabled = true
  recipe_list["offshore-pump"].enabled = true
  recipe_list["small-electric-pole"].enabled = true
  recipe_list["electric-mining-drill"].enabled = true
  recipe_list["inserter"].enabled = true
  recipe_list["radar"].enabled = true
  recipe_list["lab"].enabled = true
  recipe_list["science-pack-1"].enabled = true
  recipe_list["science-pack-2"].enabled = true
  recipe_list["stone-wall"].enabled = true
  recipe_list["repair-pack"].enabled = true

  local technologies = game.players[1].force.technologies
  technologies["automation"].researched = true
  technologies["logistics"].researched = true
  technologies["logistics-2"].enabled = true
  technologies["automobilism"].researched = true
  technologies["military"].researched = true
  technologies["military-2"].enabled = true
  technologies["optics"].researched = true
  technologies["steel-processing"].researched = true
  technologies["automation-2"].enabled = true
  technologies["turrets"].researched = true
  technologies["heavy-armor"].enabled = true
  technologies["railway"].enabled = true
  technologies["automated-rail-transportation"].enabled = true
  technologies["electric-energy-distribution-1"].enabled = true
  technologies["electric-energy-distribution-1"].researched = true
  technologies["bullet-damage-1"].researched = true
  technologies["bullet-damage-2"].enabled = true
  technologies["bullet-damage-3"].enabled = true
  technologies["bullet-speed-1"].researched = true
  technologies["bullet-speed-2"].enabled = true
  technologies["bullet-speed-3"].enabled = true
  technologies["advanced-material-processing"].enabled = true
  technologies["electronics"].enabled = true
  technologies["solar-energy"].enabled = true
  technologies["engine"].enabled = true
  technologies["rail-signals"].enabled = true
  technologies["stone-walls"].researched = true
  technologies["gates"].enabled = true

  local character = game.players[1].character
  character.insert{name = "iron-plate", count = 200}
  character.insert{name = "copper-plate", count = 100}
  character.insert{name = "coal", count = 40}
  character.insert{name = "small-lamp", count = 20}
  character.insert{name = "transport-belt", count = 50}
  character.insert{name = "inserter", count = 20}
  character.insert{name = "small-electric-pole", count = 20}
  character.insert{name = "long-handed-inserter", count = 10}
  character.insert{name = "electric-mining-drill", count = 5}
  character.insert{name = "submachine-gun", count = 1}
  character.insert{name = "firearm-magazine", count = 20}
  character.insert{name = "iron-axe", count = 1}
  character.insert{name = "electronic-circuit", count = 100}
  character.insert{name = "assembling-machine-1", count = 10}
  character.insert{name = "lab", count = 5}
  character.insert{name = "stone", count = 200}
  character.insert{name = "raw-wood", count = 50}
  character.insert{name = "iron-gear-wheel", count = 50}
  character.insert{name = "pipe", count = 40}

  --This map has an old version of steam engine and boilers, where the outputs are incorrect
  --This fixes them. It won't be needed with new maps
  local boilers = export_entities({entities = game.surfaces[1].find_entities_filtered{name = "boiler"}})
  recreate_entities(boilers)
  local engines = export_entities({entities = game.surfaces[1].find_entities_filtered{name = "steam-engine"}})
  recreate_entities(engines)

end)

story_table =
{
  {
    {
      action =
      function()
        set_goal("")
        game.forces.player.set_spawn_position(game.players[1].position, game.players[1].surface)
        story_show_message_dialog{text = {"msg-came-too-late"}}
        story_show_message_dialog{text = {"msg-everyone-dead"}}
        story_show_message_dialog{text = {"msg-biters-are-dangerous"}}
        story_show_message_dialog{text = {"msg-recover-base"}}
        story_show_message_dialog{text = {"msg-rails"}}
      end
    },
    {
      condition = story_elapsed_check(2),
      action =
      function()
        set_goal({"goal-recover-base-and-research-railway"})
      end
    },
    {
      condition =
      function(event)
        return event.name == defines.events.on_research_finished and
               event.research.name == "automated-rail-transportation"
      end,
      action =
      function()
        set_goal("")
        game.players[1].print({"think-recover-railway"})
      end
    },
    {
      condition = story_elapsed_check(6)
    },
    {
      init = function(event)
        set_goal({"goal-get-supplies"})
        check_supplies(true)
      end,
      condition = function() return check_supplies() end,
      action = function()
        set_goal("")
        set_info()
        story_show_message_dialog{text = {"msg-ready-to-go"}}
      end
    },
    {}
  }
}

story_init_helpers(story_table)

script.on_event(defines.events, function(event)
  story_update(global.story, event, "level-03")
end)

