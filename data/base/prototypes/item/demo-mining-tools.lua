data:extend(
{
  {
    type = "mining-tool",
    name = "iron-axe",
    localised_description = {"item-description.mining-tool"},
    icon = "__base__/graphics/icons/iron-axe.png",
    icon_size = 32,
    flags = {"goes-to-main-inventory"},
    action =
    {
      type="direct",
      action_delivery =
      {
        type = "instant",
        target_effects =
        {
            type = "damage",
            damage = { amount = 5 , type = "physical"}
        }
      }
    },
    durability = 4000,
    subgroup = "tool",
    order = "a[mining]-a[iron-axe]",
    speed = 2.5,
    stack_size = 20
  }
}
)
