#if defined(__APPLE__)
#  define ASM_ADD_SYM _asm_add
#else
#  define ASM_ADD_SYM asm_add
#endif

.globl ASM_ADD_SYM
ASM_ADD_SYM:
#if defined(__aarch64__) || defined(__arm64__)
        add     w0, w0, w1
        ret
#elif defined(__x86_64__)
        movl    %edi, %eax
        addl    %esi, %eax
        ret
#else
#  error "examples/asm_add: unsupported host architecture"
#endif
