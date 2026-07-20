#pragma once

#define IMGUI_VERSION "1.89.9"

struct ImVec2 {
    float x, y;
    ImVec2(float _x = 0.0f, float _y = 0.0f) : x(_x), y(_y) {}
};

typedef int ImGuiTreeNodeFlags;
enum ImGuiTreeNodeFlags_ {
    ImGuiTreeNodeFlags_None = 0,
    ImGuiTreeNodeFlags_Selected = 1 << 0,
    ImGuiTreeNodeFlags_Framed = 1 << 1,
    ImGuiTreeNodeFlags_AllowItemOverlap = 1 << 2,
    ImGuiTreeNodeFlags_NoTreePushOnOpen = 1 << 3,
    ImGuiTreeNodeFlags_NoAutoOpenOnLog = 1 << 4,
    ImGuiTreeNodeFlags_DefaultOpen = 1 << 5,
    ImGuiTreeNodeFlags_OpenOnDoubleClick = 1 << 6,
    ImGuiTreeNodeFlags_OpenOnArrow = 1 << 7,
    ImGuiTreeNodeFlags_Leaf = 1 << 8,
    ImGuiTreeNodeFlags_Bullet = 1 << 9,
    ImGuiTreeNodeFlags_ToggleMask = 1 << 10
};

namespace ImGui {
    bool Begin(const char* name, bool* p_open = nullptr, int flags = 0);
    void End();
    bool CollapsingHeader(const char* label, ImGuiTreeNodeFlags flags = 0);
    bool Checkbox(const char* label, bool* v);
    bool SliderFloat(const char* label, float* v, float v_min, float v_max, const char* format = "%.3f", int flags = 0);
    void Text(const char* fmt, ...);
    void TextWrapped(const char* fmt, ...);
    void TextUnformatted(const char* text, const char* text_end = nullptr);
    bool Button(const char* label, const ImVec2& size = ImVec2(0, 0));
    void Separator();
    void SameLine(float offset_from_start_x = 0.0f, float spacing = -1.0f);
    void SetNextItemWidth(float item_width);
}
