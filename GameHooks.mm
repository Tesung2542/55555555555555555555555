#include "GameHooks.hpp"
#include <algorithm>
#include <cstdint>
#include <cstring>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include "dobby.h"
#include "MenuState.hpp"
#include "Offsets.hpp"

namespace {
uintptr_t gImageBase = 0;
uintptr_t gExecutableStart = 0;
uintptr_t gExecutableEnd = 0;
bool gInstallAttempted = false;
bool gHooksInstalled = false;
const char *gHookStatus = "Hooks are not activated";

using DispatcherFn = void (*)(void *object);
using LifeGetFn = int64_t (*)(void *object);
using CookieUpdateFn = void (*)(void *object);
using HpModifyFn = void (*)(float amount);
using EffectTickFn = void *(*)(void *object, void *effect);
using ApplyEffectFn = void (*)(void *object, void *effect);

DispatcherFn originalDispatcher = nullptr;
LifeGetFn originalLifeGet = nullptr;
CookieUpdateFn originalCookieUpdate = nullptr;
HpModifyFn originalHpModify = nullptr;
EffectTickFn originalEffectTick = nullptr;
ApplyEffectFn applyInvincibleBoost = nullptr;
ApplyEffectFn applyGigantic = nullptr;

uintptr_t FindExecutableBase() {
  for (uint32_t i = 0; i < _dyld_image_count(); ++i) {
    const mach_header *header = _dyld_get_image_header(i);
    if (header != nullptr && header->filetype == MH_EXECUTE) {
      uintptr_t base = reinterpret_cast<uintptr_t>(header);
      const auto *header64 = reinterpret_cast<const mach_header_64 *>(header);
      const uint8_t *cursor = reinterpret_cast<const uint8_t *>(header64 + 1);
      for (uint32_t commandIndex = 0; commandIndex < header64->ncmds; ++commandIndex) {
        const auto *command = reinterpret_cast<const load_command *>(cursor);
        if (command->cmd == LC_SEGMENT_64) {
          const auto *segment = reinterpret_cast<const segment_command_64 *>(cursor);
          if (std::strncmp(segment->segname, "__TEXT", sizeof(segment->segname)) == 0) {
            gExecutableStart = base;
            gExecutableEnd = gExecutableStart + segment$vmsize; // หรือ vmsize ตามต้นฉบับ
            break;
          }
        }
        cursor += command->cmdsize;
      }
      return base;
    }
  }
  return 0;
}

template <typename T>
T Resolve(uintptr_t rva) {
  return reinterpret_cast<T>(gImageBase + rva);
}

bool Hook(uintptr_t rva, void *replacement, void **original) {
  uintptr_t address = gImageBase + rva;
  if ((rva & 3U) != 0 || address < gExecutableStart || address + sizeof(uint32_t) > gExecutableEnd) {
    return false;
  }
  return DobbyHook(Resolve<void *>(rva), replacement, original) == 0 && *original != nullptr;
}
}
