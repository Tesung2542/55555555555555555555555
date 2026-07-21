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

  // คำสั่ง NOP สำหรับสถาปัตยกรรม ARM64 (ใช้บล็อกฟังก์ชันที่ไม่ต้องการให้ลด/ทำงาน)
  const uint32_t nopInstruction = 0xD503201F;

  // รวมรายการ Offset ทั้งหมดจากตารางที่คุณส่งมา
  // 1. scanner (0x00B1DB94)
  PatchMemory(0x00B1DB94, &nopInstruction, sizeof(nopInstruction));

  // 2. popupSwz (0x009AFAFC)
  PatchMemory(0x009AFAFC, &nopInstruction, sizeof(nopInstruction));

  // 3. svcFn1 (0x00B8E7A0) & 4. svcFn2 (0x00B8EFE0)
  PatchMemory(0x00B8E7A0, &nopInstruction, sizeof(nopInstruction));
  PatchMemory(0x00B8EFE0, &nopInstruction, sizeof(nopInstruction));

  // 5. isExempt (0x0064B4CC)
  PatchMemory(0x0064B4CC, &nopInstruction, sizeof(nopInstruction));

  // 6. dispatcher (0x00512620)
  PatchMemory(0x00512620, &nopInstruction, sizeof(nopInstruction));

  // 7. calcDelta (0x00067DC8)
  PatchMemory(0x00067DC8, &nopInstruction, sizeof(nopInstruction));

  // 8. lifeget (0x008FC8D8) - เกี่ยวกับเลือด/การรับไอเท็มชีวิต
  PatchMemory(0x008FC8D8, &nopInstruction, sizeof(nopInstruction));

  // 9. cookieUpd (0x009428E4) - อัปเดตสถานะตัวละคร
  PatchMemory(0x009428E4, &nopInstruction, sizeof(nopInstruction));

  // 10. hpModify (0x008FCCE4) - ตัวหลักในการลด/เพิ่มเลือด
  PatchMemory(0x008FCCE4, &nopInstruction, sizeof(nopInstruction));

  // 11. effectTick (0x0086BF10) - เอฟเฟกต์เวลาในเกม
  PatchMemory(0x0086BF10, &nopInstruction, sizeof(nopInstruction));

  gPatchApplied = true;
  gHookStatus = "All table functions patched successfully";
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
