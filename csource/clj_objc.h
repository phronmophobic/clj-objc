#ifdef GRAAL
#include "libcljobc.h"
#endif


extern "C" {
    void call_objc(int rettype, void* ret, int nargs, int* argtypes, void** values);
    void print_objc(NSObject* obj);

#ifdef GRAAL
    void set_graal_isolate(graal_isolate_t *isolate);
#endif

    void* make_block(void* callback_id, int rettype, int nargs, int* argtypes );
    void run_on_main(void (^block)());
}
