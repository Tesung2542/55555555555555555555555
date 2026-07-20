#pragma once
#include <atomic>

namespace BNMenu {
    inline std::atomic<bool> speedEnabled(false);
    inline std::atomic<float> speedMultiplier(1.0f);
    inline std::atomic<bool> invincible(false);
    inline std::atomic<bool> invincibleBoost(false);
    inline std::atomic<bool> gigantic(false);
}
