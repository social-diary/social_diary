-- The route-model handover's leg data for RagefireChasm (3 Nov 2026: ref/route-model-handover/
-- addon/Data, its `spawns` list taken out), the fixture tests/pace_model.lua holds
-- Core/Pace/Model.lua to its recorded answers with. Not loaded by the addon.
-- Ragefire Chasm route data (instance map 389). Generated, do not edit.
-- Spawns: advocaite/TrinityCore forever branch, release forever-tdb-2026-10-14 (vanilla world converted from VMaNGOS), GPL-2.0-or-later
local data = {
  name = "Ragefire Chasm",
  instanceMapId = 389,
  generated = "pipeline/tools/export_lua.py; edit config.json and rerun instead of editing this file",
  source = "Spawns: advocaite/TrinityCore forever branch, release forever-tdb-2026-10-14 (vanilla world converted from VMaNGOS), GPL-2.0-or-later",
  image = {
    file = "rfc_map.png",
    width = 1002,
    height = 668,
    credit = "community map, GPL-3.0",
  },
  transform = {
    a = 0.052297,
    b = -1.171338,
    c = 613.357081,
    d = -1.315813,
    e = -0.013621,
    f = 67.501196,
  },
  entrance = {
    x = 3.81,
    y = -14.82,
    verified = false,
  },
  bosses = {
    {
      name = "Oggleflint",
      short = "Oggleflint",
      npcId = 11517,
      x = -147.548,
      y = 38.7127,
      z = -38.8039,
      note = "the art's pink skull sits about 215 px away, in the trogg area; the spawn data puts him in the small round side room",
    },
    {
      name = "Taragaman the Hungerer",
      short = "Taragaman",
      npcId = 11520,
      x = -244.743,
      y = 150.085,
      z = -18.7494,
      note = "",
    },
    {
      name = "Jergosh the Invoker",
      short = "Jergosh",
      npcId = 11518,
      x = -376.811,
      y = 209.224,
      z = -21.801,
      note = "",
    },
    {
      name = "Bazzalan",
      short = "Bazzalan",
      npcId = 11519,
      x = -384.867,
      y = 146.045,
      z = 7.82184,
      note = "",
    },
  },
  legs = {
    {
      from = "Entrance",
      to = "Oggleflint",
      length = 265.4494,
      path = {
        { 3.81, -14.82 },
        { -36.46, -42.09 },
        { -70.09, -33.16 },
        { -106.32, -37.66 },
        { -148.18, -52.46 },
        { -162.13, -43.51 },
        { -147.68, 0.44 },
        { -147.548, 38.7127 },
      },
      pulls = {
        {
          packId = 2,
          at = 48.6,
          elites = 1,
          size = 1,
          x = -36.46,
          y = -42.09,
          names = {
            "Molten Elemental",
          },
        },
        {
          packId = 3,
          at = 60.6,
          elites = 1,
          size = 1,
          x = -45.03,
          y = -27.76,
          names = {
            "Earthborer",
          },
        },
        {
          packId = 4,
          at = 83.4,
          elites = 1,
          size = 1,
          x = -70.09,
          y = -33.16,
          names = {
            "Earthborer",
          },
        },
        {
          packId = 8,
          at = 119.9,
          elites = 1,
          size = 1,
          x = -106.32,
          y = -37.66,
          names = {
            "Earthborer",
          },
        },
        {
          packId = 13,
          at = 140.6,
          elites = 1,
          size = 1,
          x = -129.13,
          y = -35.16,
          names = {
            "Earthborer",
          },
        },
        {
          packId = 16,
          at = 164.1,
          elites = 2,
          size = 2,
          x = -146.96,
          y = -55.12,
          names = {
            "Ragefire Shaman",
            "Ragefire Trogg",
          },
        },
        {
          packId = 20,
          at = 180.9,
          elites = 1,
          size = 1,
          x = -162.13,
          y = -43.51,
          names = {
            "Ragefire Trogg",
          },
        },
        {
          packId = 18,
          at = 199.9,
          elites = 2,
          size = 2,
          x = -159.91,
          y = -24.28,
          names = {
            "Ragefire Shaman",
            "Ragefire Trogg",
          },
        },
        {
          packId = 14,
          at = 224.3,
          elites = 5,
          size = 5,
          x = -144.33,
          y = -3.71,
          names = {
            "Ragefire Shaman",
            "Ragefire Trogg",
          },
        },
        {
          packId = 17,
          at = 254.3,
          elites = 2,
          size = 2,
          x = -151.04,
          y = 27.58,
          names = {
            "Ragefire Shaman",
            "Ragefire Trogg",
          },
        },
      },
    },
    {
      from = "Oggleflint",
      to = "Taragaman the Hungerer",
      length = 179.6729,
      path = {
        { -147.55, 38.71 },
        { -176.65, 75.29 },
        { -223.45, 87.28 },
        { -257.46, 106.18 },
        { -244.743, 150.085 },
      },
      pulls = {
        {
          packId = 22,
          at = 46.7,
          elites = 1,
          size = 1,
          x = -176.65,
          y = 75.29,
          names = {
            "Molten Elemental",
          },
        },
        {
          packId = 27,
          at = 80.7,
          elites = 8,
          size = 8,
          x = -206.15,
          y = 96.95,
          names = {
            "Searing Blade Cultist",
            "Searing Blade Enforcer",
          },
        },
        {
          packId = 42,
          at = 134,
          elites = 5,
          size = 5,
          x = -264.96,
          y = 99.99,
          names = {
            "Searing Blade Cultist",
            "Searing Blade Enforcer",
            "Searing Blade Warlock",
          },
        },
      },
    },
    {
      from = "Taragaman the Hungerer",
      to = "Jergosh the Invoker",
      length = 225.4541,
      path = {
        { -244.74, 150.09 },
        { -283.76, 152.5 },
        { -294.64, 196.86 },
        { -284.91, 216.07 },
        { -321.88, 247.56 },
        { -336.36, 224.26 },
        { -376.811, 209.224 },
      },
      pulls = {
        {
          packId = 39,
          at = 18.8,
          elites = 1,
          size = 1,
          x = -263.52,
          y = 150.47,
          names = {
            "Searing Blade Enforcer",
          },
        },
        {
          packId = 47,
          at = 38.7,
          elites = 2,
          size = 2,
          x = -283.67,
          y = 148.18,
          names = {
            "Searing Blade Enforcer",
          },
        },
        {
          packId = 52,
          at = 40.3,
          elites = 2,
          size = 2,
          x = -296.99,
          y = 150.49,
          names = {
            "Searing Blade Cultist",
            "Searing Blade Warlock",
          },
        },
        {
          packId = 53,
          at = 86.3,
          elites = 3,
          size = 3,
          x = -297.98,
          y = 200.3,
          names = {
            "Searing Blade Cultist",
            "Searing Blade Warlock",
          },
        },
        {
          packId = 48,
          at = 106.3,
          elites = 3,
          size = 3,
          x = -280.1,
          y = 215.4,
          names = {
            "Searing Blade Cultist",
            "Searing Blade Warlock",
          },
        },
        {
          packId = 56,
          at = 132.3,
          elites = 2,
          size = 2,
          x = -312.85,
          y = 223.43,
          names = {
            "Searing Blade Cultist",
            "Searing Blade Warlock",
          },
        },
        {
          packId = 57,
          at = 154.9,
          elites = 2,
          size = 2,
          x = -320.41,
          y = 252.1,
          names = {
            "Searing Blade Enforcer",
          },
        },
        {
          packId = 58,
          at = 187.6,
          elites = 4,
          size = 4,
          x = -338.24,
          y = 214.09,
          names = {
            "Searing Blade Cultist",
            "Searing Blade Enforcer",
          },
        },
        {
          packId = 61,
          at = 221.7,
          elites = 2,
          size = 2,
          x = -371.74,
          y = 206.2,
          names = {
            "Searing Blade Cultist",
          },
        },
      },
    },
    {
      from = "Jergosh the Invoker",
      to = "Bazzalan",
      length = 63.6867,
      path = {
        { -376.81, 209.22 },
        { -384.867, 146.045 },
      },
      pulls = {
        {
          packId = 64,
          at = 53.3,
          elites = 1,
          size = 1,
          x = -385.16,
          y = 156.6,
          names = {
            "Searing Blade Cultist",
          },
        },
        {
          packId = 65,
          at = 60.4,
          elites = 1,
          size = 1,
          x = -396.31,
          y = 150.83,
          names = {
            "Searing Blade Cultist",
          },
        },
      },
    },
  },
}

local _, ns = ...
if type(ns) == "table" then
  ns.RouteData = ns.RouteData or {}
  ns.RouteData[data.instanceMapId] = data
end
return data
