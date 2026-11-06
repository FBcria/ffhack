#import "Menu.h"
#import "Config.h"
#import "ESP.h"
#import "Aimbot.h"
#import "il2cpp.h"
#import <UIKit/UIKit.h>

static UIWindow* mWin;
static UIView*   mPanel;

@interface FFMenuVC : UIViewController @end

@implementation FFMenuVC

- (void)togglePanel { mPanel.hidden = !mPanel.hidden; }

- (void)flip:(UISwitch*)s {
    switch (s.tag) {
        case 0: g_cfg.esp = s.on; break;
        case 1: g_cfg.esp_box = s.on; break;
        case 2: g_cfg.esp_snapline = s.on; break;
        case 3: g_cfg.esp_dist = s.on; break;
        case 4: g_cfg.aim = s.on; if (s.on) aim_start(); else aim_stop(); break;
        case 5: g_cfg.only_enemies = s.on; break;
    }
}

- (void)doDump   { il2::dump_classes("Player"); }
- (void)doReload { esp_stop(); esp_start(); }

@end

void menu_install(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        FFMenuVC* vc = [FFMenuVC new];

        mWin = [[UIWindow alloc] initWithFrame:CGRectMake(10, 120, 240, 430)];
        mWin.windowLevel = UIWindowLevelAlert + 2;
        mWin.backgroundColor = UIColor.clearColor;
        mWin.rootViewController = vc;

        UIButton* dot = [UIButton buttonWithType:UIButtonTypeCustom];
        dot.frame = CGRectMake(0, 0, 46, 46);
        dot.backgroundColor = [UIColor colorWithRed:0 green:0.6 blue:1 alpha:0.75];
        dot.layer.cornerRadius = 23;
        [dot setTitle:@"V" forState:UIControlStateNormal];
        [dot addTarget:vc action:@selector(togglePanel) forControlEvents:UIControlEventTouchUpInside];
        [vc.view addSubview:dot];

        mPanel = [[UIView alloc] initWithFrame:CGRectMake(0, 52, 240, 370)];
        mPanel.backgroundColor = [UIColor colorWithWhite:0.06 alpha:0.92];
        mPanel.layer.cornerRadius = 12;
        mPanel.hidden = YES;
        [vc.view addSubview:mPanel];

        NSArray* labels = @[@"ESP", @"Caixa", @"Linha", @"Distancia", @"Aimbot", @"So inimigos"];
        BOOL states[6] = { g_cfg.esp, g_cfg.esp_box, g_cfg.esp_snapline,
                           g_cfg.esp_dist, g_cfg.aim, g_cfg.only_enemies };

        for (int i = 0; i < 6; i++) {
            UILabel* l = [[UILabel alloc] initWithFrame:CGRectMake(12, 12 + i * 40, 160, 30)];
            l.text = labels[i];
            l.textColor = UIColor.whiteColor;
            l.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
            [mPanel addSubview:l];

            UISwitch* s = [UISwitch new];
            s.tag = i;
            s.on = states[i];
            s.center = CGPointMake(200, 27 + i * 40);
            s.transform = CGAffineTransformMakeScale(0.8, 0.8);
            [s addTarget:vc action:@selector(flip:) forControlEvents:UIControlEventValueChanged];
            [mPanel addSubview:s];
        }

        UIButton* dump = [UIButton buttonWithType:UIButtonTypeSystem];
        dump.frame = CGRectMake(12, 268, 105, 34);
        [dump setTitle:@"Dump Player" forState:UIControlStateNormal];
        [dump addTarget:vc action:@selector(doDump) forControlEvents:UIControlEventTouchUpInside];
        [mPanel addSubview:dump];

        UIButton* reload = [UIButton buttonWithType:UIButtonTypeSystem];
        reload.frame = CGRectMake(122, 268, 105, 34);
        [reload setTitle:@"Recarregar" forState:UIControlStateNormal];
        [reload addTarget:vc action:@selector(doReload) forControlEvents:UIControlEventTouchUpInside];
        [mPanel addSubview:reload];

        mWin.hidden = NO;
    });
}