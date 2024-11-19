#include <stdio.h>

static FILE* hdl = NULL;

static void kk_profile_init(kk_string_t kk_path, kk_context_t* ctx) {
    const char* path = kk_string_cbuf_borrow(kk_path, NULL, ctx);
    hdl = fopen( path, "w" );
    kk_string_drop(kk_path, ctx);

    const char* begin = "[\n";
    fwrite(begin, 1, strlen(begin), hdl);

    return;
}

static void kk_profile_deinit(kk_context_t* ctx) {
    fclose( hdl );
    hdl = NULL;
    return;
}

static void kk_profile_write(kk_string_t kk_evt, kk_context_t* ctx) {
    const char* msg = kk_string_cbuf_borrow(kk_evt, NULL, ctx);
    fwrite(msg, 1, strlen(msg), hdl);
    kk_string_drop(kk_evt, ctx);
    return;
}
