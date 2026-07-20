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
      for (uint32_t commandIndex = 0; commandIndex < header64->ncmds;
            ++commandIndex) {
        const auto *command = reinterpret_cast<const load_command *>(cursor);
        if (command->cmd == LC_SEGMENT_64) {
          const auto *segment = reinterpret_cast<const segment_command_64 *>(cursor);
          if (std::strncmp(segment->segname, "__TEXT", sizeof(segment->segname)) == 0) {
            gExecutableStart = base;
            gExecutableEnd = gExecutableStart + segment->vmsize;
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
  if ((rva & 3U) != 0 || address < gExecutableStart ||
      address + sizeof(uint32_t) > gExecutableEnd) {
    return false;
  }
  return DobbyHook(Resolve<void *>(rva), replacement, original) == 0 &&
         *original != nullptr;
}

void HookDispatcher(void *object) {
  if (originalDispatcher != nullptr) originalDispatcher(object);
  if (object == nullptr || !BNMenu::speedEnabled.load()) return;

  float multiplier = std::clamp(BNMenu::speedMultiplier.load(), 1.0f, 100.0f);
  auto *speed = reinterpret_cast<float *>(
      reinterpret_cast<uintptr_t>(object) + 0x50);
  *speed *= multiplier;
}

int64_t HookLifeGet(void *object) {
  if (BNMenu::invincible.load()) return 999;
  return originalLifeGet != nullptr ? originalLifeGet(object) : 0;
}

void HookCookieUpdate(void *object) {
  if (originalCookieUpdate != nullptr) originalCookieUpdate(object);
  if (object == nullptr || !BNMenu::invincible.load()) return;

  auto *state = reinterpret_cast<uintptr_t *>(
      reinterpret_cast<uintptr_t>(object) + 0x3A0);
  if (*state != 0) *state = 0;
}

void HookHpModify(float amount) {
  if (BNMenu::speedEnabled.load() && amount < 0.0f) {
    float multiplier = std::clamp(BNMenu::speedMultiplier.load(), 1.0f, 100.0f);
    amount /= multiplier;
  }
  if (originalHpModify != nullptr) originalHpModify(amount);
}

void *HookEffectTick(void *object, void *effect) {
  void *result = originalEffectTick != nullptr
                     ? originalEffectTick(object, effect)
                     : nullptr;
  if (object == nullptr) return result;
  if (BNMenu::invincibleBoost.load() && applyInvincibleBoost != nullptr) {
    applyInvincibleBoost(object, effect);
  }
  if (BNMenu::gigantic.load() && applyGigantic != nullptr) {
    applyGigantic(object, effect);
  }
  return result;
}

}  // namespace

bool InstallBNHooks() {
  if (gInstallAttempted) return gHooksInstalled;
  gInstallAttempted = true;
  gImageBase = FindExecutableBase();
  if (gImageBase == 0 || gExecutableStart == 0 || gExecutableEnd == 0) {
    gHookStatus = "Main executable __TEXT was not found";
    return false;
  }

  const uintptr_t required[] = {
      BNOffsets::kCalcDelta, BNOffsets::kLifeGet, BNOffsets::kCookieUpdate,
      BNOffsets::kHpModify, BNOffsets::kEffectTick, BNOffsets::kInvincibleBoost,
      BNOffsets::kGigantic,
  };
  for (uintptr_t rva : required) {
    uintptr_t address = gImageBase + rva;
    if ((rva & 3U) != 0 || address < gExecutableStart ||
        address + sizeof(uint32_t) > gExecutableEnd) {
      gHookStatus = "Recovered RVA is outside this build's __TEXT";
      return false;
    }
  }

  applyInvincibleBoost = Resolve<ApplyEffectFn>(BNOffsets::kInvincibleBoost);
  applyGigantic = Resolve<ApplyEffectFn>(BNOffsets::kGigantic);

  bool ok = true;
  ok &= Hook(BNOffsets::kCalcDelta, reinterpret_cast<void *>(&HookDispatcher),
             reinterpret_cast<void **>(&originalDispatcher));
  ok &= Hook(BNOffsets::kLifeGet, reinterpret_cast<void *>(&HookLifeGet),
             reinterpret_cast<void **>(&originalLifeGet));
  ok &= Hook(BNOffsets::kCookieUpdate,
             reinterpret_cast<void *>(&HookCookieUpdate),
             reinterpret_cast<void **>(&originalCookieUpdate));
  ok &= Hook(BNOffsets::kHpModify, reinterpret_cast<void *>(&HookHpModify),
             reinterpret_cast<void **>(&originalHpModify));
  ok &= Hook(BNOffsets::kEffectTick, reinterpret_cast<void *>(&HookEffectTick),
             reinterpret_cast<void **>(&originalEffectTick));
  gHooksInstalled = ok;
  gHookStatus = ok ? "Recovered hooks active"
                   : "MobileSubstrate rejected one or more hooks";
  return gHooksInstalled;
}

bool BNHooksInstalled() {
  return gHooksInstalled;
}

const char *BNHookStatus() {
  return gHookStatus;
}

__attribute__((constructor)) void autoInitHooks() {
  InstallBNHooks();
}
