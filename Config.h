#pragma once

struct Config {
    // ---- ESP
    bool esp          = true;
    bool esp_box      = true;
    bool esp_snapline = true;
    bool esp_name     = false;
    bool esp_dist     = true;
    bool esp_hp       = false;
    bool only_enemies = true;
    float esp_max_dist = 200.0f;

    // ---- Aimbot
    bool  aim          = false;
    float aim_fov      = 140.0f;   // px
    float aim_dist     = 120.0f;   // m
    float aim_smooth   = 5.0f;     // 1 = snap, 10 = suave
    bool  aim_visible_only = true;
    int   aim_bone     = 0;        // 0 = cabeça, 1 = peito

    // ---- Nomes (AJUSTE POR VERSÃO — use o Dump)
    const char* cls_facade        = "GameFacade";
    const char* fld_facade_inst   = "instance";
    const char* fld_player_list   = "playerList";
    const char* fld_main_player   = "mainPlayer";
    const char* fld_player_tf     = "transform";
    const char* fld_player_dead   = "isDead";
    const char* fld_player_team   = "team";
    const char* fld_aim_rot       = "aimRotation";

    // ---- Geometria
    float off_head = 1.58f;
    float off_chest = 1.15f;
};

extern Config g_cfg;