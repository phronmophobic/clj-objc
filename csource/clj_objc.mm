#include <ffi.h>
#import <objc/message.h>
#import <Foundation/Foundation.h>
#import "clj_objc.h"



ffi_type* argtype_to_ffi_type(int argtype){
    ffi_type* ret;

    switch (argtype){
    case 0: ret = &ffi_type_void; break;
    case 1: ret = &ffi_type_pointer; break;
    case 2: ret = &ffi_type_sint8; break;
    case 3: ret = &ffi_type_sint16; break;
    case 4: ret = &ffi_type_sint32; break;
    case 5: ret = &ffi_type_sint64; break;
    case 6: ret = &ffi_type_float; break;
    case 7: ret = &ffi_type_double; break;
    default: ret = &ffi_type_void;
    }

    return ret;
}


enum {
    BLOCK_HAS_COPY_DISPOSE = (1 << 25),
    BLOCK_IS_GLOBAL        = (1 << 28),
    BLOCK_HAS_STRET        = (1 << 29),
    BLOCK_HAS_SIGNATURE    = (1 << 30)
};

/*
 * End of definitions.
 */

static Class gGlobalBlockClass = nil;

struct block_descriptor {
    unsigned long int reserved;
    unsigned long int size;
    void (*copy_helper)(void* dst, void* src);
    void (*dispose_helper)(void* src);
    const char* signature;
};

// struct block_descriptor_basic {
//     unsigned long int reserved;
//     unsigned long int size;
//     void*             rest[1];
// };

struct block_literal {
    void* isa;
    int   flags;
    int   reserved;
    void (*invoke)(void*, ...);
    struct block_descriptor* descriptor;
};

// static void
// oc_copy_helper(void* _dst, void* _src)
// {
//     struct block_literal* dst = (struct block_literal*)_dst;
//     struct block_literal* src = (struct block_literal*)_src;

//     PyObjC_BEGIN_WITH_GIL
//         dst->invoke_cleanup = src->invoke_cleanup;
//         Py_XINCREF(dst->invoke_cleanup);

//     PyObjC_END_WITH_GIL
// }

// static void
// oc_dispose_helper(void* _src)
// {
//     struct block_literal* src = (struct block_literal*)_src;

//     PyObjC_BEGIN_WITH_GIL
//         Py_CLEAR(src->invoke_cleanup);

//     PyObjC_END_WITH_GIL
// }


static struct block_descriptor gDescriptorTemplate = {
    0, sizeof(struct block_literal), 
    NULL, // oc_copy_helper, 
    NULL, // oc_dispose_helper, 
    };

static struct block_literal gLiteralTemplate = {0, /* ISA */
                                                0, // BLOCK_HAS_COPY_DISPOSE,
                                                0,
                                                0,
                                                &gDescriptorTemplate,
                                                };

int multiplyByFour(void* block, int num){
    return num*4;
}


static graal_isolate_t *_isolate = NULL;
void set_graal_isolate(graal_isolate_t *isolate){
    _isolate = isolate;
}

void callback_wrapper(ffi_cif *cif, void *ret, void* args[], void *callback_id) {
	// *(ffi_arg *) ret = fputs(*(char **) args[0], (FILE *) stream);
    
    graal_isolatethread_t *thread = NULL;

    if ( !_isolate ){
        fprintf(stderr, "no graal isolate for callback!\n");
        exit(1);
        return;
    }
    if ( graal_attach_thread(_isolate, &thread) != 0) {
        fprintf(stderr, "could not attach thread to graal isolate!\n");
    }



    void * args_without_block_ptr = args[1];

    clj_callback(thread, callback_id, ret, args_without_block_ptr);
}


typedef struct {
	ffi_closure* closure;
	ffi_type **argtypes;
	ffi_cif cif;
	void* fn;
} ffi_putter_t;

ffi_putter_t* make_clojure_closure(void* callback_id, int rettype, int nargs, int* argtypes ) {
	ffi_status status;
	void *code_ptr;
	ffi_putter_t *ffi_putter;

    // blocks take self as first argument
    int total_args = nargs+1;

	ffi_putter = new ffi_putter_t(); //malloc(sizeof(*ffi_putter));
	ffi_putter->closure = (ffi_closure*)ffi_closure_alloc(sizeof(ffi_closure), &code_ptr);
	if (ffi_putter == NULL) {
		printf("Failed to allocated memory for closure!\n");
		goto err;
	}



    ffi_putter->argtypes =new ffi_type*[total_args];
    ffi_putter->argtypes[0] = &ffi_type_pointer;
    for ( int i = 0; i < nargs; i ++){
        ffi_putter->argtypes[i+1] = argtype_to_ffi_type(argtypes[i]);
    }

	status = ffi_prep_cif(&(ffi_putter->cif), FFI_DEFAULT_ABI, total_args, argtype_to_ffi_type(rettype), ffi_putter->argtypes);
	if (status != FFI_OK) {
		printf("ffi_prep_cif failed: %d\n", status);
		goto err;
	}

	status = ffi_prep_closure_loc(ffi_putter->closure, &(ffi_putter->cif), &callback_wrapper, callback_id, code_ptr);
	if (status != FFI_OK) {
		printf("ffi_prep_closure_loc failed: %d\n", status);
		goto err;
	}

	ffi_putter->fn = code_ptr;
	return ffi_putter;
err:
	ffi_closure_free(ffi_putter->closure);
	free(ffi_putter);
	return NULL;
}

void* make_block(void* callback_id, int rettype, int nargs, int* argtypes ){
    if ( gGlobalBlockClass == NULL){
        gGlobalBlockClass = objc_lookUpClass("__NSGlobalBlock__");
    }

    
    struct block_literal* block;

    block = (block_literal*)malloc(sizeof(struct block_literal)+ sizeof(struct block_descriptor));
    if (block == NULL) {
        return NULL;
    }

    *block = gLiteralTemplate;
    block->descriptor =
        (struct block_descriptor*)(((char*)block) + sizeof(struct block_literal));
    *(block->descriptor) = *(gLiteralTemplate.descriptor);

    // block->invoke = (void (*)(void *, ...))&multiplyByFour;

    ffi_putter_t* closure = make_clojure_closure(callback_id, rettype, nargs, argtypes );

    /* block->descriptor->signature = "v??"; */
    /* block->flags |= BLOCK_HAS_SIGNATURE; */
    /* block->descsignature = "v??"; */


    /* block->flags = 0; */
    block->invoke = (void (*)(void *, ...))closure->fn;
    block->isa    = gGlobalBlockClass;

    /* printf("block address: %p\n", block); */
    /* printf("fn address: %p\n", block->invoke); */

    return block;
}



void print_objc(NSObject* obj){
    NSLog(@"%p", obj);
    NSLog(@"%@", obj);
}

void* ffi_target(void* c, void* sel, float none);

void call_objc(int rettype, void* ret, int nargs, int* argtypes, void** values){

    ffi_type* ffi_argtypes[nargs];
    for ( int i = 0; i < nargs; i ++){
        ffi_argtypes[i] = argtype_to_ffi_type(argtypes[i]);
    }

    
    ffi_cif cif;
    ffi_status status = ffi_prep_cif(&cif, FFI_DEFAULT_ABI, nargs, argtype_to_ffi_type(rettype),
                                     ffi_argtypes);

    
    

    ffi_call(&cif, FFI_FN(objc_msgSend), ret, values);


}

