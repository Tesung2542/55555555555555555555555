#include "GameHooks.hpp"

#import <UIKit/UIKit.h>
#include <algorithm>
#include <cstdint>
#include <cstring>
#include <sys/mman.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <unistd.h>

#include "MenuState.hpp"
#include "Offsets.hpp"

namespace {

uintptr_t gImageBase = 0;
bool gPatchApplied = false;
const char *gHookStatus = "Patches are not activated";

uintptr_t FindExecutableBase() {
  for (uint32_t i = 0; i < _dyld_image_count(); ++i) {
    const mach_header *header = _dyld_get_image_header(i);
    if (header != nullptr && header->filetype == MH_EXECUTE) {
      return reinterpret_cast<uintptr_t>(header);
    }
  }
  return 0;
}

// ฟังก์ชันเขียนทับค่าหน่วยความจำ (Memory Patching)
bool PatchMemory(uintptr_t rva, const void *bytes, size_t size) {
  if (gImageBase == 0) return false;
  uintptr_t targetAddress = gImageBase + rva;
  
  size_t pageSize = sysconf(_SC_PAGESIZE);
  uintptr_t pageStart = targetAddress & ~(pageSize - 1);
  
  if (mprotect(reinterpret_cast<void *>(pageStart), pageSize, PROT_READ | PROT_WRITE | PROT_EXEC) != 0) {
    return false;
  }
  
  std::memcpy(reinterpret_cast<void *>(targetAddress), bytes, size);
  
  mprotect(reinterpret_cast<void *>(pageStart), pageSize, PROT_READ | PROT_EXEC);
  return true;
}

void ApplyPatches() {
  if (gPatchApplied) return;
  gImageBase = FindExecutableBase();
  if (gImageBase == 0) {
    gHookStatus = "Main executable base was not found";
    return;
  }

  // 1. ฟังก์ชันตัวใหญ่: ลองใช้ Offset จาก cookieUpd (0x009428E4) หรือปรับเปลี่ยนตามต้องการ
  float bigScaleValue = 2.0f; 
  bool patchBig = PatchMemory(0x009428E4, &bigScaleValue, sizeof(bigScaleValue));

  // 2. ฟังก์ชันฟรีสค่าไอเท็ม: ลองใช้ Offset จาก effectTick (0x0086BF10) หรือตัวอื่นในตาราง
  int itemValue = 99;
  bool patchItem = PatchMemory(0x0086BF10, &itemValue, sizeof(itemValue));

  gPatchApplied = (patchBig || patchItem);
  gHookStatus = gPatchApplied ? "Big & Item patches applied successfully" : "Failed to apply patches";
}

}  // namespace

bool InstallBNHooks() {
  ApplyPatches();
  return gPatchApplied;
}

bool BNHooksInstalled() {
  return gPatchApplied;
}

const char *BNHookStatus() {
  return gHookStatus;
}

static void RunHooksWhenReady(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    ApplyPatches();
  });
  CFNotificationCenterRemoveEveryObserver(CFNotificationCenterGetLocalCenter(), observer);
}

__attribute__((constructor)) void safeInitMod() {
  CFNotificationCenterAddObserver(
      CFNotificationCenterGetLocalCenter(),
      NULL,
      RunHooksWhenReady,
      (__bridge CFStringRef)NSNotificationName(@"UIApplicationDidFinishLaunchingNotification"),
      NULL,
      CFNotificationSuspensionBehaviorDrop
  );
}
