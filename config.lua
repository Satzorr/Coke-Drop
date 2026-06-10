Config = {}

Config.NPCRespawnDelay = 14400 -- 4 hours in seconds
Config.InteractionDistance = 2.0
Config.SimcardItem = 'black_chip'

Config.Drop = {
    DropHeight   = 150.0,
    SpawnHeight  = 120.0,
    PoliceChance = 33,
    CallerRadius = 220.0,
    ChipRadius   = 540.0,
    BlipDuration = 900,
    Models = {
        plane  = 'cuban800',
        pilot  = 's_m_m_pilot_02',
        chute  = 'gr_prop_gr_para_s_01', 
        crate  = 'prop_box_wood05a',
    }
}

Config.Packages = {
    blueprint = { label = 'Warehouse Blueprints', item = 'blueprint_coke_1', amount = 1,  price = 14000  },
    small     = { label = '6 Cocaine Bricks',     item = 'cocaine_brick',    amount = 6,  price = 126000 },
    medium    = { label = '12 Cocaine Bricks',    item = 'cocaine_brick',    amount = 12, price = 230000 },
    large     = { label = '18 Cocaine Bricks',    item = 'cocaine_brick',    amount = 18, price = 310000 },
}

-- Cartel NPC models
Config.CartelModels = {
    'g_m_m_mexboss_01',
    'g_m_m_mexboss_02',
    'a_m_m_mexcntry_01',
    'g_m_y_mexgang_01',
    'g_m_y_mexgoon_01',
    'g_m_y_mexgoon_02',
    'g_m_y_mexgoon_03',
    'a_m_m_mexlabor_01',
    'a_m_y_mexthug_01',
}

Config.PhoneNumbers = {
    '52-550-220-7111',
    '52-550-331-8222',
    '52-550-442-9333',
    '52-550-553-0444',
    '52-550-664-1555',
    '52-550-775-2666',
    '52-550-886-3777',
    '52-550-997-4888',
}

Config.CartelScenarios = {
    'WORLD_HUMAN_SMOKING',
    'WORLD_HUMAN_SMOKING_POT',
    'WORLD_HUMAN_DRUG_DEALER',
    'WORLD_HUMAN_STAND_IMPATIENT',
    'WORLD_HUMAN_DRUG_DEALER_HARD',
}


-- Server picks one randomly every 4h
-- Each group = 3 NPCs spawned side by side at that position
Config.GroupPositions = {
    vector4(-46.313,   -1757.504, 29.421,  46.395),
    vector4(24.376,    -1345.558, 29.421,  267.940),
    vector4(1134.182,  -982.477,  46.416,  275.432),
    vector4(373.015,   328.332,   103.566, 257.309),
    vector4(2676.389,  3280.362,  55.241,  332.305),
    vector4(1715.89,   3254.55,   41.12,   309.2),
    vector4(652.65,    -1026.54,  22.32,   89.09),
    vector4(487.50,    -798.12,   42.52,   83.99),
    vector4(-119.47,   -984.57,   39.26,   156.63),
    vector4(883.29,    2870.61,   56.50,   91.06),
    vector4(-1255.28,  -820.75,   17.10,   128.35),
    vector4(1135.91,   -999.72,   45.20,   9.06),
}
