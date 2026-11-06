#import "il2cpp.h"
#import "ESP.h"
#import "Aimbot.h"
#import "Menu.h"
#import "Config.h"
#include <unistd.h>

Config g_cfg;

#define LOG(...) do { \
    NSString* _l = [NSString stringWithFormat:__VA_ARGS__]; \
    NSLog(@"[AudioCore] %@", _l); \
    NSString* _p = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/audiocore.log"]; \
    FILE* _f = fopen(_p.UTF8String, "a"); \
    if (_f) { fprintf(_f, "%s\n", _l.UTF8String); fclose(_f); } \
} while (0)

static void boot(void) {
    LOG(@"constructor ok, pid %d", getpid());
    menu_install();
    LOG(@"menu instalado");

    int ok = 0;
    for (int i = 0; i < 900; i++) {
        if (il2::init()) { ok = 1; break; }
        usleep(100000);
    }
    LOG(@"il2cpp init = %d", ok);
    if (!ok) { LOG(@"abortando: il2cpp nao resolveu"); return; }

    il2::attach();
    LOG(@"attach ok");

    void* p = il2::find_class("Player");
    void* g = il2::find_class(g_cfg.cls_facade);
    LOG(@"classe Player = %p | %s = %p", p, g_cfg.cls_facade, g);

    usleep(3000000);
    esp_start();
    aim_start();
    LOG(@"loops iniciados");
}

__attribute__((constructor))
static void entry(void) {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{ boot(); });
}
