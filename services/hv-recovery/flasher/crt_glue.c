/* crt_glue.c -- bionic __libc_init arguments (see crt0.S). */
extern int main(int, char **);
int slingshot(int argc, char **argv, char **envp) { (void)envp; return main(argc, argv); }
struct tt_structors {
    void *preinit_array; unsigned long preinit_array_count;
    void *init_array;    unsigned long init_array_count;
    void *fini_array;    unsigned long fini_array_count;
    void (*fini)(void);
    void (*atexit_fn)(void);
};
const struct tt_structors structors = { 0 };
