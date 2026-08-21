#ifndef RWA_VAULT_WASM_STDLIB_H
#define RWA_VAULT_WASM_STDLIB_H

#include <stddef.h>

void *malloc(size_t size);
void free(void *pointer);
_Noreturn void exit(int status);

#endif
