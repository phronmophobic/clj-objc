#import <Foundation/Foundation.h>
#include <objc/message.h>
#include "clj_objc.h"

#include "libcljobc.h"

void direct_test(){
    // SEL sel = NSSelectorFromString([NSString stringWithUTF8String:s]);
    SEL sel = NSSelectorFromString(@"stringWithUTF8String:");

    id instance = objc_getClass("NSString");
    int rettype = 01;
    NSString* ret;
    int nargs = 3;
    
    const char* s = "asdadf";

    int argtypes[] = {1,1,1};
    void* values[]  = {
        &instance,&sel,&s
    };
    call_objc(rettype, &ret, nargs, argtypes, values);

    print_objc(ret);

}

graal_isolate_t *isolate = NULL;
graal_isolatethread_t *thread = NULL;

void indirect_test(){
    if ( !isolate ){
      if (graal_create_isolate(NULL, &isolate, &thread) != 0) {
        fprintf(stderr, "initialization error\n");
        return;
      }
    }
    set_graal_isolate(isolate);

    ffi_test(thread);

    NSComparator mycomp = (NSComparator)make_test_block(thread);
    printf("mycomp: %p\n", mycomp);

    NSArray* arr = [NSArray arrayWithObjects:@"asdf", @"asdfasdf", nil];
    arr = [arr sortedArrayUsingComparator:mycomp];

    NSLog(@"sorted!: %@\n", arr);


}

void direct_block_test(){

    // int (^myBlock)(int) = (int (^)(int))make_block(NULL);

    // printf("%d", myBlock(3));

}

int main(){


    direct_test();

    indirect_test();

    // direct_block_test();

    return 0;
}



