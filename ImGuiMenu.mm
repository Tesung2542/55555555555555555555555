#include "ImGuiMenu.hpp"

#include <algorithm>

#include "GameHooks.hpp"
#include "MenuState.hpp"
#include "imgui.h"

void DrawBNControls() {
  bool speed = BNMenu::speedEnabled.load();
  float multiplier = BNMenu::speedMultiplier.load();
  bool invincible = BNMenu::invincible.load();
  bool boost = BNMenu::invincibleBoost.load();
  bool gigantic = BNMenu::gigantic.load();

  if (!ImGui::Begin("bn_controls")) {
    ImGui::End();
    return;
  }

  if (!BNHooksInstalled()) {
    ImGui::TextWrapped("%s", BNHookStatus());
    if (ImGui::Button("Activate recovered hooks")) InstallBNHooks();
    ImGui::Separator();
  }

  if (ImGui::CollapsingHeader("Movement", ImGuiTreeNodeFlags_DefaultOpen)) {
    if (ImGui::Checkbox("Speed Hack##speed", &speed)) {
      BNMenu::speedEnabled.store(speed);
    }
    ImGui::SameLine();
    ImGui::TextUnformatted("ความเร็ว");
    ImGui::SetNextItemWidth(220.0f);
    if (ImGui::SliderFloat("##speed_multiplier", &multiplier, 1.0f, 10.0f,
                           "x%.1f")) {
      BNMenu::speedMultiplier.store(std::clamp(multiplier, 1.0f, 10.0f));
    }
  }

  if (ImGui::CollapsingHeader("Survival", ImGuiTreeNodeFlags_DefaultOpen)) {
    if (ImGui::Checkbox("อมตะ (Invincible)##invincible", &invincible)) {
      BNMenu::invincible.store(invincible);
    }
  }

  if (ImGui::CollapsingHeader("Buffs", ImGuiTreeNodeFlags_DefaultOpen)) {
    if (ImGui::Checkbox("วิ่งทะลุ (InvincibleBoost)##boost", &boost)) {
      BNMenu::invincibleBoost.store(boost);
    }
    if (ImGui::Checkbox("ตัวยักษ์ (Gigantic)##gigantic", &gigantic)) {
      BNMenu::gigantic.store(gigantic);
    }
  }

  ImGui::End();
}
