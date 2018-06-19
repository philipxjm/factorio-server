require "util"
require "story"

script.on_init(function()
  global.story = story_init()
  game.forces.player.clear_chart()
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
  recipe_list["stone-wall"].enabled = true
  recipe_list["iron-chest"].enabled = true
  recipe_list["repair-pack"].enabled = true

  local technologies = game.players[1].force.technologies

  technologies["steel-processing"].enabled = true
  technologies["optics"].enabled = true
  technologies["logistics"].enabled = true
  technologies["logistics-2"].enabled = true
  technologies["automation"].enabled = true
  technologies["automation-2"].enabled = true
  technologies["electronics"].enabled = true
  technologies["military"].enabled = true
  technologies["military-2"].enabled = true
  technologies["turrets"].enabled = true
  technologies["bullet-damage-1"].enabled = true
  technologies["bullet-damage-2"].enabled = true
  technologies["bullet-damage-3"].enabled = true
  technologies["bullet-speed-1"].enabled = true
  technologies["bullet-speed-2"].enabled = true
  technologies["bullet-speed-3"].enabled = true
  technologies["engine"].enabled = true
  technologies["automobilism"].enabled = true

  local character = game.players[1].character
  character.insert{name = "iron-plate", count = 40}
  character.insert{name = "copper-plate", count = 10}
  character.insert{name = "coal", count = 40}
  character.insert{name = "transport-belt", count = 100}
  character.insert{name = "inserter", count = 20}
  character.insert{name = "small-electric-pole", count = 20}
  character.insert{name = "electric-mining-drill", count = 5}
  character.insert{name = "pistol", count = 1}
  character.insert{name = "firearm-magazine", count = 20}
  character.insert{name = "iron-axe", count = 1}
  character.insert{name = "electronic-circuit", count = 40}

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
        story_show_message_dialog{text = {"msg-sector-scan-completed"}}
        story_show_message_dialog{text = {"msg-ship-wreck-located"}}
        game.forces.player.set_spawn_position(game.players[1].position, game.players[1].surface)
      end
    },
    {
      condition = story_elapsed_check(2),
      action =
      function()
        game.players[1].print({"think-explore-ship-wreck"})
      end
    },
    {
      condition = story_elapsed_check(5),
      action =
      function()
        story_show_message_dialog{text = {"msg-distress-signal-1"}}
        story_show_message_dialog{text = {"msg-distress-signal-2"}}
        story_show_message_dialog{text = {"msg-distress-signal-3"}}
      end
    },
    {
      condition = story_elapsed_check(2),
      action =
      function()
        game.players[1].print({"think-find-survivors"})
      end
    },
    {
      condition = story_elapsed_check(5),
      action =
      function()
        story_show_message_dialog{text = {"msg-distress-signal-4"}}
        story_show_message_dialog{text = {"msg-distress-signal-5"}}
        story_show_message_dialog{text = {"msg-distress-signal-6"}}
        story_show_message_dialog{text = {"msg-distress-signal-7"}}
        story_show_message_dialog{text = {"msg-distress-signal-8"}}
      end
    },
    {
      condition = story_elapsed_check(3),
      action =
      function()
        set_goal({"goal-build-lab"})
      end
    },
    {
      condition =
      function(event)
        return (event.name == defines.events.on_built_entity and event.created_entity.name == "lab")
          or game.players[1].force.get_entity_count("lab") > 0
      end,
      action =
      function(event)
        set_goal({"goal-research-automation"})
        story_show_message_dialog{text = {"msg-lab-ready"}}
        if event.name == defines.events.on_built_entity and event.created_entity.name == "lab" then
          event.created_entity.energy = 1 -- avoid the not enough energy icon in this frame
        end
      end
    },
    {
      condition = function() return game.players[1].force.technologies["automation"].researched end,
      action =
      function()
        game.players[1].force.recipes["science-pack-2"].enabled = true
        set_goal({"goal-research-automobilism"})
      end
    },
    {
      condition = function() return game.players[1].force.technologies["automobilism"].researched end,
      action =
      function()
        set_goal({"goal-build-car"})
      end
    },
    {
      condition = function() return game.players[1].get_item_count("car") > 0 end,
      action =
      function()
        set_goal({"goal-enter-car-insert-fuel"})
      end
    },
    {
      condition = function() return game.players[1].vehicle ~= nil and game.players[1].vehicle.energy > 0 end,
      action =
      function()
        set_goal("")
      end
    }
  }
}

function check_automate_science_packs_advice(event)
  if global.science_packs_crafted == nil then
    global.science_packs_crafted = 0
  end
  if event.item_stack.name == "science-pack-1" then
    global.science_packs_crafted = global.science_packs_crafted + event.item_stack.count
  end
  if global.science_packs_crafted > 15 and global.automate_science_packs_advice == nil then
    story_show_message_dialog{text = {"hint-to-automate-science-pack-crafting"}}
    global.automate_science_packs_advice = true
  end
end

function check_research_hints()
  if global.research_hint == nil and game.players[1].force.current_research ~= nil then
    global.research_hint = true
    story_show_message_dialog{text = {"hint-research-1"}}
    story_show_message_dialog{text = {"hint-research-2"}}
  end
end

story_init_helpers(story_table)

script.on_event(defines.events, function(event)
  story_update(global.story, event, "level-02")
  check_research_hints()
end)

script.on_event(defines.events.on_player_crafted_item, check_automate_science_packs_advice)
