#pragma once

#ifdef __cplusplus
extern "C" {
#endif

int DobbyHook(void *function_address, void *replace_call, void **origin_call);

#ifdef __cplusplus
}
#endif
