#ifndef RWA_VAULT_WASM_ASSERT_H
#define RWA_VAULT_WASM_ASSERT_H

#define assert(expression) ((expression) ? (void)0 : __builtin_trap())

#endif
