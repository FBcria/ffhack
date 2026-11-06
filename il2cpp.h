#pragma once
#include <stdint.h>
#include <stddef.h>
#include <mach/mach.h>
#include "Types.h"

namespace il2 {
    bool  init();
    void  attach();
    void* find_class(const char* name);
    size_t field_off(void* klass, const char* name);
    void* method_ptr(void* klass, const char* name, int argc);

    template <class T> inline T rd(uintptr_t p) {
        if (p < 0x10000) return T{};
        T v{};
        vm_size_t sz = sizeof(T);
        if (vm_read_overwrite(mach_task_self(), (vm_address_t)p, (vm_size_t)sizeof(T),
                              (vm_address_t)&v, &sz) != KERN_SUCCESS) return T{};
        return v;
    }

    inline bool wr(uintptr_t p, const void* s, size_t n) {
        vm_address_t page = (vm_address_t)p & ~(vm_address_t)0xFFF;
        vm_protect(mach_task_self(), page, 0x4000, false,
                   VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
        return vm_write(mach_task_self(), (vm_address_t)p,
                        (vm_offset_t)(uintptr_t)s, (mach_msg_type_number_t)n) == KERN_SUCCESS;
    }

    void dump_classes(const char* needle);
}
