#import "il2cpp.h"
#import <mach-o/dyld.h>
#import <dlfcn.h>
#import <string.h>
#import <Foundation/Foundation.h>

namespace il2 {

typedef void*   (*t_domain_get)();
typedef void**  (*t_domain_get_assemblies)(void*, size_t*);
typedef void*   (*t_assembly_get_image)(void*);
typedef void*   (*t_class_from_name)(void*, const char*, const char*);
typedef void*   (*t_class_get_field)(void*, const char*);
typedef size_t  (*t_field_get_offset)(void*);
typedef void*   (*t_class_get_method)(void*, const char*, int);
typedef void*   (*t_method_get_pointer)(void*);
typedef void*   (*t_thread_attach)(void*);
typedef void*   (*t_class_get_parent)(void*);
typedef const char* (*t_class_get_name)(void*);

static void* g_img = nullptr;
static t_domain_get            p_domain_get;
static t_domain_get_assemblies p_get_asms;
static t_assembly_get_image    p_get_image;
static t_class_from_name       p_class_from_name;
static t_class_get_field       p_class_get_field;
static t_field_get_offset      p_field_get_offset;
static t_class_get_method      p_class_get_method;
static t_method_get_pointer    p_method_get_pointer;
static t_thread_attach         p_thread_attach;
static t_class_get_parent      p_class_get_parent;
static t_class_get_name        p_class_get_name;

static void* S(const char* n) { return g_img ? dlsym(g_img, n) : nullptr; }

bool init() {
    if (p_class_from_name) return true;

    NSLog(@"[AudioCore] init: procurando UnityFramework");

    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char* n = _dyld_get_image_name(i);
        if (n && strstr(n, "UnityFramework")) {
            g_img = dlopen(n, RTLD_NOLOAD | RTLD_NOW);
            NSLog(@"[AudioCore] imagem achada: %s", n);
            break;
        }
    }
    if (!g_img)
        g_img = dlopen("@executable_path/Frameworks/UnityFramework.framework/UnityFramework", RTLD_NOW);
    if (!g_img) g_img = dlopen("UnityFramework", RTLD_NOW);
    if (!g_img) { NSLog(@"[AudioCore] UnityFramework nao abriu"); return false; }

    p_domain_get        = (t_domain_get)S("il2cpp_domain_get");
    p_get_asms          = (t_domain_get_assemblies)S("il2cpp_domain_get_assemblies");
    p_get_image         = (t_assembly_get_image)S("il2cpp_assembly_get_image");
    p_class_from_name   = (t_class_from_name)S("il2cpp_class_from_name");
    p_class_get_field   = (t_class_get_field)S("il2cpp_class_get_field_from_name");
    p_field_get_offset  = (t_field_get_offset)S("il2cpp_field_get_offset");
    p_class_get_method  = (t_class_get_method)S("il2cpp_class_get_method_from_name");
    p_method_get_pointer= (t_method_get_pointer)S("il2cpp_method_get_pointer");
    p_thread_attach     = (t_thread_attach)S("il2cpp_thread_attach");
    p_class_get_parent  = (t_class_get_parent)S("il2cpp_class_get_parent");
    p_class_get_name    = (t_class_get_name)S("il2cpp_class_get_name");

    if (!p_domain_get || !p_class_from_name || !p_class_get_field) {
        NSLog(@"[AudioCore] API il2cpp incompleta: domain=%p class=%p field=%p",
              p_domain_get, p_class_from_name, p_class_get_field);
        g_img = nullptr;
        return false;
    }
    NSLog(@"[AudioCore] il2cpp resolvido");
    return true;
}

void attach() {
    static thread_local bool done = false;
    if (done || !p_thread_attach || !p_domain_get) return;
    p_thread_attach(p_domain_get());
    done = true;
}

void* find_class(const char* name) {
    attach();
    if (!name || !p_get_asms) return nullptr;
    size_t n = 0;
    void** asms = p_get_asms(p_domain_get(), &n);
    if (!asms) return nullptr;
    for (size_t i = 0; i < n; i++) {
        void* img = p_get_image(asms[i]);
        if (!img) continue;
        if (void* k = p_class_from_name(img, "", name))      return k;
        if (void* k = p_class_from_name(img, nullptr, name)) return k;
    }
    return nullptr;
}

size_t field_off(void* klass, const char* name) {
    if (!klass || !name || !p_class_get_field) return 0;
    void* f = p_class_get_field(klass, name);
    return f ? p_field_get_offset(f) : 0;
}

void* method_ptr(void* klass, const char* name, int argc) {
    if (!klass || !name || !p_class_get_method) return nullptr;
    void* m = p_class_get_method(klass, name, argc);
    if (!m) return nullptr;
    if (p_method_get_pointer) {
        if (void* p = p_method_get_pointer(m)) return p;
    }
    return *(void**)m;
}

void dump_classes(const char* needle) {
    attach();
    if (!p_get_asms || !p_class_get_name) return;
    NSMutableString* out = [NSMutableString stringWithFormat:@"=== dump '%s' ===\n", needle];
    size_t n = 0;
    void** asms = p_get_asms(p_domain_get(), &n);
    for (size_t i = 0; i < n; i++) {
        void* img = p_get_image(asms[i]);
        if (!img) continue;
        void* k = p_class_from_name(img, "", needle);
        if (k) [out appendFormat:@"%s -> %p\n", needle, k];
    }
    NSString* path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"ffhack_dump.txt"];
    [out writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    NSLog(@"%@", out);
}
}
