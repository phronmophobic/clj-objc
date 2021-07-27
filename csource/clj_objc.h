#include "libcljobc.h"

extern "C" {
    void call_objc(int rettype, void* ret, int nargs, int* argtypes, void** values);
    void print_objc(NSObject* obj);

    void set_graal_isolate(graal_isolate_t *isolate);
    void* make_block(void* callback_id, int rettype, int nargs, int* argtypes );
}
