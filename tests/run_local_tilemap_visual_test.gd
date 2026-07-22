# Copyright (C) 2026 sword-godot contributors
# SPDX-License-Identifier: GPL-3.0-or-later
## 使用本机合法导入资源比较 TileMapLayer 与 CPU SDLPal 基准的 320×200 像素输出。
## 差异截图只写入被 Git 忽略的 `generated/pal/visual_tests/`。
extends SceneTree

const TEST_CASES: Array[Dictionary] = [
	{"name": "inn_room", "scene": 0, "position": Vector2i(1248, 1040), "night": false},
	{"name": "kitchen_entry", "scene": 0, "position": Vector2i(1248, 1104), "night": false},
	{"name": "stairs", "scene": 0, "position": Vector2i(96, 48), "night": false},
	{"name": "wine_outdoor", "scene": 2, "position": Vector2i(1088, 1648), "night": false},
	{"name": "roof_night", "scene": 3, "position": Vector2i(1440, 1536), "night": true},
	{"name": "hidden_dragon_nearby", "scene": 41, "position": Vector2i(1760, 1792), "night": false, "party": [2, 0]},
	{"name": "hidden_dragon_snake", "scene": 40, "position": Vector2i(816, 776), "night": false, "party": [0, 2]},
	{"name": "hidden_dragon_inner", "scene": 46, "position": Vector2i(1280, 1328), "night": false, "party": [0, 2]},
	{"name": "baihe_road", "scene": 47, "position": Vector2i(464, 1672), "night": false, "party": [0, 2]},
	{"name": "baihe_village", "scene": 48, "position": Vector2i(576, 1632), "night": false, "party": [0, 2]},
	{"name": "baihe_deer_hunt", "scene": 47, "position": Vector2i(704, 1040), "night": false, "party": [0], "event_states": {791: 0, 792: 0, 793: 0, 794: 0, 795: 0, 798: 2, 799: 2}},
	{"name": "baihe_han_outside", "scene": 51, "position": Vector2i(896, 832), "night": false, "party": [0]},
	{"name": "baihe_han_clinic_recovered", "scene": 52, "position": Vector2i(1472, 600), "night": false, "party": [0, 1, 2], "event_states": {905: 0, 907: 0, 908: 0, 910: 0}},
	{"name": "baihe_rear_road", "scene": 53, "position": Vector2i(352, 640), "night": false, "party": [0, 1, 2]},
	{"name": "jade_buddha_courtyard", "scene": 55, "position": Vector2i(1376, 1000), "night": false, "party": [0, 1, 2]},
	{"name": "jade_buddha_hall", "scene": 57, "position": Vector2i(800, 1088), "night": false, "party": [0, 1, 2]},
	{"name": "jade_buddha_cleared", "scene": 56, "position": Vector2i(1184, 560), "night": false, "party": [0, 1, 2]},
	{"name": "blackwater_village", "scene": 60, "position": Vector2i(1280, 1120), "night": false, "party": [0, 1, 2]},
	{"name": "burial_wilderness", "scene": 62, "position": Vector2i(1536, 1456), "night": false, "party": [0, 1, 2]},
	{"name": "burial_grave_gate", "scene": 63, "position": Vector2i(560, 384), "night": false, "party": [0, 1, 2]},
	{"name": "general_tomb_upper", "scene": 59, "position": Vector2i(1392, 1600), "night": false, "party": [0, 1, 2]},
	{"name": "general_tomb_lower_boss", "scene": 64, "position": Vector2i(640, 304), "night": false, "party": [0, 1, 2]},
	{"name": "blood_pool_red_ghost", "scene": 58, "position": Vector2i(832, 112), "night": false, "party": [0, 1, 2]},
	{"name": "ghost_mountain_guards", "scene": 54, "position": Vector2i(320, 1464), "night": false, "party": [0, 1, 2]},
	{"name": "ghost_mountain_maze", "scene": 69, "position": Vector2i(1504, 880), "night": false, "party": [0, 1, 2]},
	{"name": "ghost_mountain_summit", "scene": 68, "position": Vector2i(1232, 1040), "night": false, "party": [0, 1, 2]},
	{"name": "ghost_altar_plot", "scene": 66, "position": Vector2i(1344, 1120), "night": false, "party": [0, 1, 2]},
	{"name": "ghost_altar_rescued", "scene": 76, "position": Vector2i(1216, 976), "night": false, "party": [0, 2]},
	{"name": "yangzhou_approach", "scene": 82, "position": Vector2i(224, 848), "night": false, "party": [0, 2]},
	{"name": "yangzhou_gate", "scene": 78, "position": Vector2i(432, 1192), "night": false, "party": [0, 2]},
	{"name": "yangzhou_inn_night", "scene": 92, "position": Vector2i(768, 528), "night": true, "party": [0], "event_states": {1814: 0, 1815: 2, 1835: 1}},
	{"name": "yangzhou_rooftop_night", "scene": 84, "position": Vector2i(752, 248), "night": true, "party": [2, 0]},
	{"name": "yangzhou_widow_house", "scene": 88, "position": Vector2i(1056, 1104), "night": false, "party": [0, 2], "event_states": {1725: 0, 1726: 2}},
	{"name": "yangzhou_well_tunnel", "scene": 91, "position": Vector2i(848, 1528), "night": false, "party": [2, 0]},
	{"name": "yangzhou_court", "scene": 80, "position": Vector2i(1504, 1056), "night": false, "party": [0, 2]},
	{"name": "toad_valley_approach", "scene": 104, "position": Vector2i(224, 1072), "night": false, "party": [0, 2]},
	{"name": "toad_valley_wounded_woman", "scene": 100, "position": Vector2i(736, 968), "night": false, "party": [0, 2]},
	{"name": "toad_cave_boss", "scene": 102, "position": Vector2i(768, 856), "night": false, "party": [0, 2]},
	{"name": "toad_cave_defeated", "scene": 102, "position": Vector2i(768, 856), "night": false, "party": [0, 2], "event_states": {1984: 0, 1986: 2, 1987: 2, 1988: 2, 1989: 2, 1990: 2, 1991: 2, 1992: 2, 1993: 2}},
	{"name": "toad_cave_rear", "scene": 103, "position": Vector2i(896, 960), "night": false, "party": [0, 2]},
	{"name": "white_miao_hotel", "scene": 109, "position": Vector2i(864, 672), "night": false, "party": [0, 2]},
	{"name": "white_miao_hotel_aftermath", "scene": 108, "position": Vector2i(880, 1080), "night": false, "party": [0, 2]},
	{"name": "changan_outskirts", "scene": 106, "position": Vector2i(1232, 1416), "night": false, "party": [2, 0]},
	{"name": "water_temple_fair", "scene": 111, "position": Vector2i(896, 1488), "night": false, "party": [2, 0]},
	{"name": "water_temple_dock", "scene": 110, "position": Vector2i(1248, 936), "night": false, "party": [2, 0]},
	{"name": "changan_arrival", "scene": 99, "position": Vector2i(432, 328), "night": false, "party": [2, 0]},
	{"name": "changan_mansion_hall", "scene": 117, "position": Vector2i(1104, 648), "night": false, "party": [2, 0]},
	{"name": "changan_liu_sickroom", "scene": 123, "position": Vector2i(800, 704), "night": false, "party": [2, 0]},
	{"name": "changan_wine_immortal_altar", "scene": 114, "position": Vector2i(1104, 520), "night": false, "party": [0], "event_states": {2212: 2, 2213: 2, 2214: 2, 2215: 2, 2216: 2, 2217: 2, 2218: 2, 2219: 2, 2220: 2, 2221: 2, 2222: 2}},
	{"name": "changan_butterfly_reveal", "scene": 107, "position": Vector2i(656, 1456), "night": false, "party": [0], "event_states": {2085: 1, 2086: 1, 2087: 1}},
	{"name": "poison_forest_maze", "scene": 138, "position": Vector2i(944, 1112), "night": false, "party": [2, 0]},
	{"name": "poison_lady_lair", "scene": 137, "position": Vector2i(1344, 1248), "night": false, "party": [2, 0]},
	{"name": "butterfly_aftermath", "scene": 139, "position": Vector2i(1344, 1328), "night": false, "party": [0]},
	{"name": "butterfly_memory_rescue", "scene": 140, "position": Vector2i(1408, 384), "night": false, "party": [0]},
	{"name": "butterfly_memory_mansion", "scene": 141, "position": Vector2i(496, 832), "night": false, "party": [0]},
	{"name": "butterfly_memory_betrothal", "scene": 142, "position": Vector2i(864, 576), "night": false, "party": [0]},
	{"name": "shushan_arrival", "scene": 154, "position": Vector2i(1024, 1600), "night": false, "party": [0, 2]},
	{"name": "shushan_hall_exterior", "scene": 156, "position": Vector2i(576, 1664), "night": false, "party": [0, 2]},
	{"name": "shushan_hall_interior", "scene": 158, "position": Vector2i(608, 1488), "night": false, "party": [0, 2]},
	{"name": "shushan_back_mountain", "scene": 157, "position": Vector2i(832, 1440), "night": false, "party": [0, 2], "event_states": {2754: 2, 2755: 2}},
	{"name": "shushan_cloud_front", "scene": 160, "position": Vector2i(464, 1736), "night": false, "party": [0, 2]},
	{"name": "shushan_cloud_rear", "scene": 161, "position": Vector2i(432, 168), "night": false, "party": [0, 2]},
	{"name": "tower_exterior", "scene": 162, "position": Vector2i(672, 704), "night": false, "party": [0, 2]},
	{"name": "tower_eighth_floor", "scene": 145, "position": Vector2i(1184, 560), "night": false, "party": [0, 2]},
	{"name": "tower_seventh_floor", "scene": 164, "position": Vector2i(1440, 288), "night": false, "party": [0, 2]},
	{"name": "tower_sixth_floor", "scene": 165, "position": Vector2i(1024, 720), "night": false, "party": [0, 2]},
	{"name": "tower_jiang_qing", "scene": 146, "position": Vector2i(1472, 1136), "night": false, "party": [0, 2]},
	{"name": "tower_fourth_floor", "scene": 166, "position": Vector2i(848, 712), "night": false, "party": [0, 2]},
	{"name": "tower_ghost_emperor", "scene": 147, "position": Vector2i(864, 1440), "night": false, "party": [0, 2]},
	{"name": "tower_book_immortal", "scene": 153, "position": Vector2i(1392, 776), "night": false, "party": [0, 2]},
	{"name": "tower_demon_pool", "scene": 155, "position": Vector2i(320, 1712), "night": false, "party": [0, 2]},
	{"name": "tower_bottom_outer", "scene": 167, "position": Vector2i(464, 856), "night": false, "party": [0, 2]},
	{"name": "tower_linger_bound", "scene": 144, "position": Vector2i(1536, 432), "night": false, "party": [0, 2]},
	{"name": "tower_demon_council", "scene": 152, "position": Vector2i(1680, 408), "night": false, "party": [0, 1, 2]},
	{"name": "tower_seven_pillars", "scene": 143, "position": Vector2i(1184, 272), "night": false, "party": [1, 0, 2], "role_sprites": {0: 532, 1: 534, 2: 533}},
	{"name": "tower_collapse", "scene": 148, "position": Vector2i(832, 1040), "night": false, "party": [1, 0, 2], "role_sprites": {0: 232, 1: 534, 2: 533}},
	{"name": "tower_wine_immortal_rescue", "scene": 149, "position": Vector2i(1120, 528), "night": false, "party": [1, 0, 2]},
	{"name": "tower_changan_vision", "scene": 150, "position": Vector2i(1632, 1664), "night": false, "party": [1, 0, 2]},
	{"name": "tower_yueru_haze", "scene": 171, "position": Vector2i(480, 368), "night": false, "party": [1, 0, 2]},
	{"name": "tower_yueru_last_memory", "scene": 198, "position": Vector2i(1680, 424), "night": false, "party": [0]},
	{"name": "tower_li_wakes", "scene": 173, "position": Vector2i(528, 488), "night": false, "party": [0]},
	{"name": "tower_sword_saint_leaves", "scene": 176, "position": Vector2i(1408, 704), "night": false, "party": [0]},
	{"name": "shenggu_exterior", "scene": 175, "position": Vector2i(1424, 712), "night": false, "party": [0]},
	{"name": "sacred_tree_bottom", "scene": 185, "position": Vector2i(1808, 1160), "night": false, "party": [0]},
	{"name": "sacred_tree_maze", "scene": 191, "position": Vector2i(1488, 1512), "night": false, "party": [0]},
	{"name": "sacred_tree_phoenix_nest", "scene": 184, "position": Vector2i(912, 1352), "night": false, "party": [0]},
	{"name": "sacred_tree_anu_join", "scene": 187, "position": Vector2i(544, 1440), "night": false, "party": [4, 0]},
	{"name": "sacred_tree_cave_entry", "scene": 183, "position": Vector2i(336, 616), "night": false, "party": [4, 0]},
	{"name": "sacred_tree_cave_deep", "scene": 183, "position": Vector2i(752, 1032), "night": false, "party": [0, 4]},
	{"name": "sacred_tree_cave_exit", "scene": 186, "position": Vector2i(384, 1248), "night": false, "party": [0, 4]},
	{"name": "lingshan_to_dali", "scene": 178, "position": Vector2i(1664, 1440), "night": false, "party": [0, 4]},
	{"name": "dali_outskirts_arrival", "scene": 201, "position": Vector2i(208, 504), "night": false, "party": [0, 4]},
	{"name": "dali_han_settlement", "scene": 205, "position": Vector2i(352, 1744), "night": false, "party": [0, 4]},
	{"name": "dali_council", "scene": 204, "position": Vector2i(928, 1200), "night": false, "party": [4, 0]},
	{"name": "fire_kirin_cave", "scene": 211, "position": Vector2i(272, 1608), "night": false, "party": [4, 0]},
	{"name": "fire_kirin_lair", "scene": 199, "position": Vector2i(1584, 1384), "night": false, "party": [4, 0]},
	{"name": "dali_nuwa_temple_exterior", "scene": 210, "position": Vector2i(560, 1272), "night": false, "party": [4, 0]},
	{"name": "dali_nuwa_temple", "scene": 202, "position": Vector2i(288, 1392), "night": false, "party": [4, 0]},
	{"name": "dali_nuwa_temple_plot", "scene": 202, "position": Vector2i(1184, 752), "night": false, "party": [0], "role_sprites": {0: 232}, "event_states": {3635: 1, 3637: 1}},
	{"name": "dali_dream_bed", "scene": 200, "position": Vector2i(896, 832), "night": false, "party": [0], "event_states": {3593: 1}},
	{"name": "flashback_road_entry", "scene": 226, "position": Vector2i(896, 832), "night": false, "party": [0]},
	{"name": "flashback_nanzhao_city", "scene": 234, "position": Vector2i(1680, 1720), "night": false, "party": [0], "role_sprites": {0: 563}},
	{"name": "flashback_nanzhao_palace_exterior", "scene": 228, "position": Vector2i(1216, 1504), "night": false, "party": [0], "role_sprites": {0: 563}},
	{"name": "flashback_nanzhao_dungeon", "scene": 227, "position": Vector2i(560, 824), "night": false, "party": [0], "role_sprites": {0: 563}},
	{"name": "flashback_nanzhao_secret_passage", "scene": 229, "position": Vector2i(336, 696), "night": false, "party": [0], "role_sprites": {0: 563}},
	{"name": "flashback_nanzhao_staff_chamber", "scene": 245, "position": Vector2i(624, 856), "night": false, "party": [0], "role_sprites": {0: 563}},
	{"name": "flashback_nanzhao_underwater", "scene": 232, "position": Vector2i(336, 376), "night": false, "party": [3, 0], "role_sprites": {0: 563}},
	{"name": "flashback_yuhang_shrine", "scene": 248, "position": Vector2i(464, 504), "night": false, "party": [0], "role_sprites": {0: 541}},
	{"name": "flashback_yuhang_market", "scene": 253, "position": Vector2i(240, 1640), "night": false, "party": [0], "role_sprites": {0: 541}},
	{"name": "flashback_yuhang_carpenter", "scene": 256, "position": Vector2i(672, 880), "night": false, "party": [0], "role_sprites": {0: 541}},
	{"name": "shenggu_linger_delivery", "scene": 172, "position": Vector2i(560, 472), "night": false, "party": [0], "event_states": {3012: 0, 3013: 0, 3016: 0, 3017: 0, 3018: 2, 3019: 2, 3020: 0}},
	{"name": "trial_cave_road_entry", "scene": 213, "position": Vector2i(752, 184), "night": false, "party": [0], "event_states": {3877: 0, 3878: 0, 3879: 0, 3880: 0, 3881: 0, 3882: 0}},
	{"name": "trial_cave_gai_luojiao", "scene": 214, "position": Vector2i(1152, 320), "night": false, "party": [0]},
	{"name": "trial_cave_first_215", "scene": 215, "position": Vector2i(448, 1152), "night": false, "party": [0, 4]},
	{"name": "trial_cave_first_216", "scene": 216, "position": Vector2i(1232, 1144), "night": false, "party": [0, 4]},
	{"name": "trial_cave_first_217", "scene": 217, "position": Vector2i(928, 272), "night": false, "party": [0, 4]},
	{"name": "trial_cave_first_218", "scene": 218, "position": Vector2i(768, 320), "night": false, "party": [0, 4]},
	{"name": "trial_cave_second_gate", "scene": 219, "position": Vector2i(736, 480), "night": false, "party": [0, 4]},
	{"name": "trial_cave_second_220", "scene": 220, "position": Vector2i(1024, 528), "night": false, "party": [0, 4]},
	{"name": "trial_cave_second_221", "scene": 221, "position": Vector2i(1248, 464), "night": false, "party": [0, 4]},
	{"name": "trial_cave_second_222", "scene": 222, "position": Vector2i(720, 1544), "night": false, "party": [0, 4]},
	{"name": "trial_cave_second_223", "scene": 223, "position": Vector2i(1184, 1504), "night": false, "party": [0, 4]},
	{"name": "trial_cave_third_224", "scene": 224, "position": Vector2i(928, 896), "night": false, "party": [0, 4]},
	{"name": "trial_cave_third_225", "scene": 225, "position": Vector2i(384, 1152), "night": false, "party": [0, 4]},
	{"name": "trial_cave_nuwa_ruins", "scene": 212, "position": Vector2i(1552, 600), "night": false, "party": [0, 4]},
	{"name": "dali_war_outskirts_front", "scene": 258, "position": Vector2i(1104, 648), "night": false, "party": [1, 0, 4]},
	{"name": "dali_war_trial_road", "scene": 259, "position": Vector2i(800, 1296), "night": false, "party": [1, 0, 4]},
	{"name": "dali_nuwa_defense_exterior", "scene": 262, "position": Vector2i(1104, 936), "night": false, "party": [1, 0, 4]},
	{"name": "dali_nuwa_defense_temple", "scene": 264, "position": Vector2i(928, 960), "night": false, "party": [1, 0, 4]},
	{"name": "dali_linger_worship", "scene": 263, "position": Vector2i(1200, 744), "night": false, "party": [0], "role_sprites": {0: 232}},
	{"name": "dali_altar_open", "scene": 271, "position": Vector2i(1136, 1048), "night": false, "party": [1, 0, 4], "event_states": {4923: 0, 4924: 1, 4925: 2, 4926: 2, 4927: 2, 4928: 2, 4929: 2}},
	{"name": "dali_altar_filled", "scene": 257, "position": Vector2i(1152, 1040), "night": false, "party": [0], "role_sprites": {0: 232}},
	{"name": "dali_altar_celebration", "scene": 261, "position": Vector2i(800, 1344), "night": false, "party": [1, 0, 4]},
	{"name": "dali_earth_demon", "scene": 261, "position": Vector2i(880, 1256), "night": false, "party": [1, 0, 4], "event_states": {4788: 0, 4789: 0, 4790: 0, 4791: 0, 4792: 0, 4793: 0, 4794: 0, 4795: 0, 4796: 0, 4797: 0, 4798: 0, 4799: 1, 4800: 1, 4801: 1, 4802: 1, 4803: 1, 4804: 1, 4805: 1, 4806: 1, 4807: 1, 4808: 1, 4809: 1, 4810: 1}},
	{"name": "dali_rain_aftermath", "scene": 274, "position": Vector2i(672, 1296), "night": false, "party": [0], "role_sprites": {0: 232}},
	{"name": "dali_rain_temple_exterior", "scene": 275, "position": Vector2i(832, 976), "night": false, "party": [0], "role_sprites": {0: 232}},
	{"name": "bottomless_abyss_entry", "scene": 290, "position": Vector2i(240, 1672), "night": false, "party": [1, 0, 4]},
	{"name": "bottomless_abyss_second", "scene": 291, "position": Vector2i(208, 1800), "night": false, "party": [1, 0, 4]},
	{"name": "bottomless_abyss_depth", "scene": 292, "position": Vector2i(240, 1736), "night": false, "party": [1, 0, 4]},
	{"name": "nanzhao_palace_secret_passage", "scene": 278, "position": Vector2i(1408, 704), "night": false, "party": [1, 0, 4]},
	{"name": "nanzhao_palace_dungeon_deep", "scene": 287, "position": Vector2i(336, 392), "night": false, "party": [1, 0, 4]},
	{"name": "nanzhao_palace_dungeon_mid", "scene": 286, "position": Vector2i(912, 952), "night": false, "party": [1, 0, 4]},
	{"name": "nanzhao_palace_dungeon_gate", "scene": 284, "position": Vector2i(1008, 712), "night": false, "party": [1, 0, 4]},
	{"name": "nanzhao_palace_exterior", "scene": 276, "position": Vector2i(848, 1528), "night": false, "party": [1, 0, 4]},
	{"name": "nanzhao_palace_hall", "scene": 280, "position": Vector2i(1296, 1272), "night": false, "party": [1, 0, 4]},
	{"name": "nanzhao_fake_shaman_confrontation", "scene": 277, "position": Vector2i(1408, 1136), "night": false, "party": [0, 1, 4], "role_sprites": {0: 232}, "event_states": {4997: 1, 4999: 1, 5000: 1, 5001: 1, 5002: 1, 5003: 1, 5004: 1}},
	{"name": "nanzhao_fake_shaman_aftermath", "scene": 277, "position": Vector2i(1424, 1144), "night": false, "party": [0], "role_sprites": {0: 2}, "event_states": {4997: 0, 4999: 0, 5000: 0, 5001: 0, 5002: 0, 5003: 0, 5004: 0, 5005: 2}},
	{"name": "nanzhao_final_confrontation", "scene": 280, "position": Vector2i(1104, 1368), "night": false, "party": [0, 1, 4], "role_sprites": {0: 2}, "event_states": {5054: 1, 5056: 0, 5057: 1, 5058: 1}},
	{"name": "compact_two_person_formation", "scene": 41, "position": Vector2i(1808, 1768), "night": false, "party": [0, 1], "direction": GameSession.DIR_SOUTH, "steps": 3, "expected_follower_delta": Vector2i(32, -16)},
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var database := PalContentDatabase.new()
	if not database.load_generated():
		_fail("本地生成内容不可用：%s" % database.error_message)
		return
	var requested_case := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--pal-visual-case="):
			requested_case = argument.trim_prefix("--pal-visual-case=")
	var tested_count := 0
	for test_case in TEST_CASES:
		if not requested_case.is_empty() and test_case["name"] != requested_case:
			continue
		# Metal 后端在同一 SubViewport 连续换图时偶尔会读回上一地图的完整旧帧；每个用例
		# 使用独立视口和正式 PalTileMapWorld，避免用延长固定等待掩盖 GPU 换图时序。
		var viewport := SubViewport.new()
		viewport.size = Vector2i(320, 200)
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		viewport.transparent_bg = false
		root.add_child(viewport)
		var world := PalTileMapWorld.new()
		# 新增星芒是正式 TileMap 辅助层，不属于 SDLPal CPU 像素基准。
		world.set_collectible_markers_enabled(false)
		viewport.add_child(world)
		var failure := await _compare_case(database, viewport, world, test_case)
		viewport.free()
		if not failure.is_empty():
			_fail(failure)
			return
		tested_count += 1
	if tested_count == 0:
		_fail("没有名为 %s 的 TileMap 视觉用例" % requested_case)
		return
	print("PASS: %d 个 TileMapLayer 固定视口与 CPU 基准均为 320×200 零像素差异" % tested_count)
	quit(0)


func _compare_case(database: PalContentDatabase, viewport: SubViewport, world: PalTileMapWorld, test_case: Dictionary) -> String:
	var original_role_sprites := database.player_roles.scene_sprite_numbers.duplicate()
	for raw_role_index in test_case.get("role_sprites", {}):
		var role_index := int(raw_role_index)
		if role_index >= 0 and role_index < database.player_roles.scene_sprite_numbers.size():
			database.player_roles.scene_sprite_numbers[role_index] = int(test_case["role_sprites"][raw_role_index])
	var session := GameSession.new()
	session.reset_new_game()
	if test_case.has("party"):
		session.party_roles = PackedInt32Array(test_case["party"])
	session.scene_index = int(test_case["scene"])
	session.night_palette = bool(test_case["night"])
	session.set_party_world_position(test_case["position"])
	if test_case.has("steps"):
		var direction: int = test_case["direction"]
		var movement := GameSession.movement_for_direction(direction)
		for _step in range(int(test_case["steps"])):
			session.record_party_step(direction, movement)
	if test_case.has("expected_follower_delta"):
		var follower_delta := session.party_member_world_position(1) - session.party_world_position()
		if follower_delta != test_case["expected_follower_delta"]:
			_restore_role_sprites(database, original_role_sprites)
			return "%s：紧凑队伍间距错误，实际 %s" % [test_case["name"], follower_delta]
	var scene := database.scenes[session.scene_index]
	var events := database.events_for_scene(session.scene_index)
	if not world.load_map(database, scene.map_number):
		_restore_role_sprites(database, original_role_sprites)
		return "%s：%s" % [test_case["name"], world.error_message]
	var original_event_states: Dictionary = {}
	for raw_event_id in test_case.get("event_states", {}):
		var event_id := int(raw_event_id)
		if event_id <= 0 or event_id > database.event_objects.size():
			continue
		var event := database.event_objects[event_id - 1]
		original_event_states[event_id] = event.state
		event.state = int(test_case["event_states"][raw_event_id])
	world.set_walk_animation(0, false)
	if not world.sync_world(session, events):
		_restore_event_states(database, original_event_states)
		_restore_role_sprites(database, original_role_sprites)
		return "%s：%s" % [test_case["name"], world.error_message]

	# 新建 SubViewport 后等待 TileMapLayer、人物和事件节点完成第一次稳定提交。
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	# Metal 可能在 process_frame 已推进后仍未完成离屏视口提交；等待正式渲染帧结束，
	# 避免 get_image() 偶发读到一张全透明的未提交纹理。
	await RenderingServer.frame_post_draw
	var native_image := viewport.get_texture().get_image()
	if native_image == null:
		_restore_event_states(database, original_event_states)
		_restore_role_sprites(database, original_role_sprites)
		return "当前为 dummy renderer；请去掉 --headless，使用真实 GL Compatibility 渲染器运行"
	var scene_items: Array = world._build_scene_items(session, events, session.viewport_position)
	var map_data := database.load_map(scene.map_number)
	var tile_sprite := database.load_map_tiles(scene.map_number)
	var cpu_indexed := PalSceneRenderer.render(map_data, tile_sprite, Rect2i(session.viewport_position, Vector2i(320, 200)), scene_items)
	var palette := database.load_palette(session.palette_index, session.night_palette)
	var cpu_image := cpu_indexed.to_rgba_image(palette)
	if native_image.get_size() != cpu_image.get_size():
		_restore_event_states(database, original_event_states)
		_restore_role_sprites(database, original_role_sprites)
		return "%s 截图尺寸不一致：TileMap %s / CPU %s" % [test_case["name"], native_image.get_size(), cpu_image.get_size()]

	var different := 0
	var maximum_channel_difference := 0
	var difference_examples := PackedStringArray()
	for y in range(cpu_image.get_height()):
		for x in range(cpu_image.get_width()):
			var cpu := cpu_image.get_pixel(x, y)
			var native := native_image.get_pixel(x, y)
			var channel_difference := maxi(
				absi(roundi(cpu.r * 255.0) - roundi(native.r * 255.0)),
				maxi(
					absi(roundi(cpu.g * 255.0) - roundi(native.g * 255.0)),
					absi(roundi(cpu.b * 255.0) - roundi(native.b * 255.0))
				)
			)
			if channel_difference > 0:
				different += 1
				maximum_channel_difference = maxi(maximum_channel_difference, channel_difference)
				if difference_examples.size() < 8:
					difference_examples.append("(%d,%d) CPU=%s TileMap=%s" % [x, y, cpu.to_html(), native.to_html()])

	var output_directory := ProjectSettings.globalize_path("res://generated/pal/visual_tests")
	DirAccess.make_dir_recursive_absolute(output_directory)
	var output_name := str(test_case["name"])
	native_image.save_png(output_directory.path_join("tilemap_%s_native.png" % output_name))
	cpu_image.save_png(output_directory.path_join("tilemap_%s_cpu.png" % output_name))
	_restore_event_states(database, original_event_states)
	_restore_role_sprites(database, original_role_sprites)
	if different > 0:
		return "%s（map %d）有 %d 个差异像素，最大通道差 %d：%s；截图已写入 visual_tests" % [output_name, scene.map_number, different, maximum_channel_difference, "、".join(difference_examples)]
	return ""


func _restore_event_states(database: PalContentDatabase, original_states: Dictionary) -> void:
	for raw_event_id in original_states:
		var event_id := int(raw_event_id)
		database.event_objects[event_id - 1].state = int(original_states[raw_event_id])


func _restore_role_sprites(database: PalContentDatabase, original_sprites: PackedInt32Array) -> void:
	database.player_roles.scene_sprite_numbers = original_sprites.duplicate()


func _fail(message: String) -> void:
	printerr("FAIL: %s" % message)
	quit(1)
