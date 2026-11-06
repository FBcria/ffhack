#import "ESP.h"
#import "il2cpp.h"
#import "Config.h"
#import <QuartzCore/QuartzCore.h>

typedef Vector3 (*t_get_pos)(void*);
typedef void    (*t_get_mat)(Matrix4x4*, void*);
typedef void*   (*t_get_main)(void*);

static void*  g_cam_class, *g_player_class, *g_facade_class;
static size_t g_off_list, g_off_tf, g_off_dead, g_off_team, g_off_main, g_off_inst;
static t_get_pos  g_get_pos;
static t_get_mat  g_get_w2c, g_get_proj;
static t_get_main g_get_main;
static CADisplayLink* g_link;
static UIWindow*      g_win;

@class FFCanvas;
static FFCanvas* g_canvas;
static void render(CGContextRef ctx, CGSize size);

@interface FFCanvas : UIView @end
@implementation FFCanvas
- (void)drawRect:(CGRect)r {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (ctx && g_cfg.esp) render(ctx, self.bounds.size);
}
@end

@interface FFTicker : NSObject @end
@implementation FFTicker
- (void)tick:(CADisplayLink*)l { if (g_canvas) [g_canvas setNeedsDisplay]; }
@end
static FFTicker* g_ticker;

static void resolve(void) {
    if (g_player_class) return;
    g_facade_class = il2::find_class(g_cfg.cls_facade);
    g_player_class = il2::find_class("Player");
    g_cam_class    = il2::find_class("Camera");
    if (!g_player_class) return;

    g_off_tf   = il2::field_off(g_player_class, g_cfg.fld_player_tf);
    g_off_dead = il2::field_off(g_player_class, g_cfg.fld_player_dead);
    g_off_team = il2::field_off(g_player_class, g_cfg.fld_player_team);

    if (g_facade_class) {
        g_off_list = il2::field_off(g_facade_class, g_cfg.fld_player_list);
        g_off_main = il2::field_off(g_facade_class, g_cfg.fld_main_player);
        g_off_inst = il2::field_off(g_facade_class, g_cfg.fld_facade_inst);
    }
    if (g_cam_class) {
        g_get_w2c  = (t_get_mat)il2::method_ptr(g_cam_class, "get_worldToCameraMatrix", 0);
        g_get_proj = (t_get_mat)il2::method_ptr(g_cam_class, "get_projectionMatrix", 0);
        g_get_main = (t_get_main)il2::method_ptr(g_cam_class, "get_main", 0);
    }
    void* tf = il2::find_class("Transform");
    if (tf) g_get_pos = (t_get_pos)il2::method_ptr(tf, "get_position", 0);
}

static bool w2s(Vector3 world, CGSize size, const Matrix4x4& v, const Matrix4x4& p, CGPoint* out) {
    float vp[4], cp[4];
    mul_mat_vec(v, world, vp);
    mul_mat_vec(p, v3(vp[0], vp[1], vp[2]), cp);
    if (cp[3] < 0.01f) return false;
    float x = cp[0] / cp[3], y = cp[1] / cp[3];
    if (x < -1.4f || x > 1.4f || y < -1.4f || y > 1.4f) return false;
    out->x = (x * 0.5f + 0.5f) * size.width;
    out->y = (1.0f - (y * 0.5f + 0.5f)) * size.height;
    return true;
}

static void render(CGContextRef ctx, CGSize size) {
    resolve();
    if (!g_player_class || !g_cam_class || !g_facade_class || !g_off_inst) return;

    void* cam = g_get_main ? g_get_main(nullptr) : nullptr;
    if (!cam || !g_get_w2c || !g_get_proj) return;

    Matrix4x4 w2c, proj;
    g_get_w2c(&w2c, cam);
    g_get_proj(&proj, cam);

    void* inst = il2::rd<void*>((uintptr_t)g_facade_class + g_off_inst);
    if (!inst) return;
    void* list = il2::rd<void*>((uintptr_t)inst + g_off_list);
    if (!list) return;
    void* items = il2::rd<void*>((uintptr_t)list + 0x10);
    int count   = il2::rd<int>((uintptr_t)list + 0x18);
    if (!items || count <= 0 || count > 200) return;

    void* me = il2::rd<void*>((uintptr_t)inst + g_off_main);
    Vector3 myPos = {0, 0, 0};
    if (me && g_off_tf && g_get_pos) {
        void* myTf = il2::rd<void*>((uintptr_t)me + g_off_tf);
        if (myTf) myPos = g_get_pos(myTf);
    }

    for (int i = 0; i < count; i++) {
        void* pl = il2::rd<void*>((uintptr_t)items + 0x20 + i * 8);
        if (!pl || pl == me) continue;
        if (g_off_dead && il2::rd<bool>((uintptr_t)pl + g_off_dead)) continue;
        if (g_cfg.only_enemies && g_off_team && me) {
            if (il2::rd<int>((uintptr_t)pl + g_off_team) == il2::rd<int>((uintptr_t)me + g_off_team)) continue;
        }
        if (!g_off_tf || !g_get_pos) continue;
        void* tf = il2::rd<void*>((uintptr_t)pl + g_off_tf);
        if (!tf) continue;

        Vector3 feet = g_get_pos(tf);
        Vector3 head = v3(feet.x, feet.y + g_cfg.off_head, feet.z);
        float dist = v3_dist(myPos, feet);
        if (dist > g_cfg.esp_max_dist) continue;

        CGPoint h, f;
        if (!w2s(head, size, w2c, proj, &h)) continue;
        if (!w2s(feet, size, w2c, proj, &f)) continue;

        float hgt = f.y - h.y;
        if (hgt < 6 || hgt > size.height) continue;
        float wid = hgt * 0.45f;

        CGContextSetRGBStrokeColor(ctx, 1, 1, 1, 0.95);
        CGContextSetLineWidth(ctx, 1.2f);
        if (g_cfg.esp_box)
            CGContextStrokeRect(ctx, CGRectMake(h.x - wid / 2, h.y, wid, hgt));
        if (g_cfg.esp_snapline) {
            CGContextMoveToPoint(ctx, size.width / 2, size.height);
            CGContextAddLineToPoint(ctx, h.x, f.y);
            CGContextStrokePath(ctx);
        }
        if (g_cfg.esp_dist) {
            NSString* s = [NSString stringWithFormat:@"%.0fm", dist];
            [s drawAtPoint:CGPointMake(h.x - wid / 2, h.y - 14)
                withAttributes:@{ NSFontAttributeName: [UIFont boldSystemFontOfSize:10],
                                  NSForegroundColorAttributeName: UIColor.whiteColor }];
        }
    }
}

void esp_start(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (g_win) return;
        g_win = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
        g_win.windowLevel = UIWindowLevelStatusBar + 1;
        g_win.backgroundColor = UIColor.clearColor;
        g_win.userInteractionEnabled = NO;
        g_win.rootViewController = [UIViewController new];
        g_canvas = [[FFCanvas alloc] initWithFrame:g_win.bounds];
        g_canvas.backgroundColor = UIColor.clearColor;
        g_canvas.userInteractionEnabled = NO;
        [g_win.rootViewController.view addSubview:g_canvas];
        g_win.hidden = NO;

        g_ticker = [FFTicker new];
        g_link = [CADisplayLink displayLinkWithTarget:g_ticker selector:@selector(tick:)];
        g_link.preferredFramesPerSecond = 30;
        [g_link addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    });
}

void esp_stop(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [g_link invalidate]; g_link = nil;
        g_ticker = nil;
        g_win.hidden = YES; g_win = nil; g_canvas = nil;
    });
}