/* crt0.S -- minimal aarch64 bionic entry (no crt1/crtbegin in this checkout). */
    .text
    .global _start
    .type _start, %function
_start:
    mov     x0, sp
    mov     x1, #0
    adrp    x2, slingshot
    add     x2, x2, :lo12:slingshot
    adrp    x3, structors
    add     x3, x3, :lo12:structors
    b       __libc_init
    .size _start, .-_start
