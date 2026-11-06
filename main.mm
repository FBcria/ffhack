#import "il2cpp.h"
#import "ESP.h"
#import "Aimbot.h"
#import "Menu.h"
#import "Config.h"

Config g_cfg;

static void boot() {
    for (int i = 0; i < 900; i++) {           // espera até 90s o Unity subir
        if (il2::init()) break;
        usleep(100000);
    }
    if (!il2::init()) return;
    il2::attach();
    usleep(3000000);                          // deixa a cena carregar
    esp_start();
    aim_start();
    menu_install();
}

__attribute__((constructor))
static void entry() {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{ boot(); });
}