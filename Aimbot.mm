#import "Aimbot.h"
#import "il2cpp.h"
#import "Config.h"
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#include <unistd.h>

typedef Vector3 (*t_get_pos)(void*);
typedef void    (*t_get_mat)(Matrix4x4*, void*);
typedef void*   (*t_get_main)(void*);

static volatile bool g_run;

static void aim_loop(void) {
    il2::attach();
    void* playerKlass = il2::find_class("Player");
    void* facadeKlass = il2::find_class(g_cfg.cls_facade);
    void* camKlass    = il2::find_class("Camera");
    void* tfKlass     = il2::find_class("Transform");
    if (!playerKlass || !facadeKlass || !camKlass || !tfKlass) return;

    t_get_pos  getPos  = (t_get_pos)il2::method_ptr(tfKlass, "get_position", 0);
    t_get_main getMain = (t_get_main)il2::method_ptr(camKlass, "get_main", 0);
    t_get_mat  getW2C  = (t_get_mat)il2::method_ptr(camKlass, "get_worldToCameraMatrix", 0);
    t_get_mat  getProj = (t_get_mat)il2::method_ptr(camKlass, "get_projectionMatrix", 0);

    size_t oList = il2::field_off(facadeKlass, g_cfg.fld_player_list);
    size_t oMe   = il2::field_off(facadeKlass, g_cfg.fld_main_player);
    size_t oTf   = il2::field_off(playerKlass, g_cfg.fld_player_tf);
    size_t oDead = il2::field_off(playerKlass, g_cfg.fld_player_dead);
    size_t oTeam = il2::field_off(playerKlass, g_cfg.fld_player_team);
    size_t oAim  = il2::field_off(playerKlass, g_cfg.fld_aim_rot);
    size_t oInst = il2::field_off(facadeKlass, g_cfg.fld_facade_inst);

    CGSize screen = UIScreen.mainScreen.bounds.size;

    while (g_run) {
        @autoreleasepool {
            if (!g_cfg.aim || !getPos || !getMain || !getW2C || !getProj || !oAim) {
                usleep(15000); continue;
            }
            void* inst = il2::rd<void*>((uintptr_t)facadeKlass + oInst);
            if (!inst) { usleep(15000); continue; }
            void* me  = il2::rd<void*>((uintptr_t)inst + oMe);
            void* cam = getMain(nullptr);
            if (!me || !cam) { usleep(15000); continue; }

            Matrix4x4 w2c, proj;
            getW2C(&w2c, cam);
            getProj(&proj, cam);

            void* myTf = il2::rd<void*>((uintptr_t)me + oTf);
            if (!myTf) { usleep(15000); continue; }
            Vector3 myPos = getPos(myTf);

            void* list = il2::rd<void*>((uintptr_t)inst + oList);
            if (!list) { usleep(15000); continue; }
            void* items = il2::rd<void*>((uintptr_t)list + 0x10);
            int count   = il2::rd<int>((uintptr_t)list + 0x18);
            if (!items || count <= 0 || count > 200) { usleep(15000); continue; }

            void* best = nullptr;
            float bestPx = g_cfg.aim_fov;

            for (int i = 0; i < count; i++) {
                void* pl = il2::rd<void*>((uintptr_t)items + 0x20 + i * 8);
                if (!pl || pl == me) continue;
                if (oDead && il2::rd<bool>((uintptr_t)pl + oDead)) continue;
                if (oTeam && il2::rd<int>((uintptr_t)pl + oTeam) ==
                             il2::rd<int>((uintptr_t)me + oTeam)) continue;

                void* tf = il2::rd<void*>((uintptr_t)pl + oTf);
                if (!tf) continue;
                Vector3 p = getPos(tf);
                if (v3_dist(myPos, p) > g_cfg.aim_dist) continue;

                Vector3 aimP = v3(p.x, p.y + (g_cfg.aim_bone ? g_cfg.off_chest : g_cfg.off_head), p.z);
                float vp[4], cp[4];
                mul_mat_vec(w2c, aimP, vp);
                mul_mat_vec(proj, v3(vp[0], vp[1], vp[2]), cp);
                if (cp[3] < 0.01f) continue;

                float sx = ((cp[0] / cp[3]) * 0.5f + 0.5f) * screen.width;
                float sy = (1.0f - ((cp[1] / cp[3]) * 0.5f + 0.5f)) * screen.height;
                float dx = sx - screen.width / 2, dy = sy - screen.height / 2;
                float d = sqrtf(dx * dx + dy * dy);
                if (d < bestPx) { bestPx = d; best = pl; }
            }

            if (best) {
                void* tf = il2::rd<void*>((uintptr_t)best + oTf);
                if (tf) {
                    Vector3 p = getPos(tf);
                    Vector3 target = v3(p.x, p.y + (g_cfg.aim_bone ? g_cfg.off_chest : g_cfg.off_head), p.z);
                    Vector3 camPos = myPos;
                    void* camTf = il2::rd<void*>((uintptr_t)cam + 0x38);
                    if (camTf) {
                        Vector3 c = getPos(camTf);
                        if (c.y != 0) camPos = c;
                    }
                    Quaternion q   = look_rotation(v3_sub(target, camPos));
                    Quaternion cur = il2::rd<Quaternion>((uintptr_t)me + oAim);
                    float t = g_cfg.aim_smooth <= 1.0f ? 1.0f : (1.0f / g_cfg.aim_smooth);
                    Quaternion out = slerp(cur, q, t);
                    il2::wr((uintptr_t)me + oAim, &out, sizeof(out));
                }
            }
            usleep(16000);
        }
    }
}

void aim_start(void) {
    if (g_run) return;
    g_run = true;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{ aim_loop(); });
}

void aim_stop(void) { g_run = false; }
