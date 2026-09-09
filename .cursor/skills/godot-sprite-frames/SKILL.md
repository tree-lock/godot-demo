---
name: godot-sprite-frames
description: >-
  Adds Godot 4 AnimatedSprite2D animations by slicing a spritesheet into
  AtlasTexture regions and appending SpriteFrames entries in a .tscn. Use when
  the user asks to 生成动画, 加动画, create armed/normal/walk/idle animations,
  slice W.png or another spritesheet, or edit SpriteFrames on Player /
  AnimatedSprite2D.
---

# 从图集生成 SpriteFrames 动画

把图集切成 `AtlasTexture`，写进场景里已有的 `SpriteFrames`，让编辑器立刻能切动画。不要在 C# `_Ready` 里动态 `new SpriteFrames()`（Play 才有，编辑器里空）。

## 本项目约定

- 玩家场景：`scene/player.tscn`
- 身体：`BodySprite`（`AnimatedSprite2D`），动画在它的 `SpriteFrames` 上
- 图集：`res://resources/texture/W.png`（160×288，32×32 格，5 列 × 9 行）
- 命名：`{state}_{dir}`，dir 为 `up` / `down` / `left` / `right`
- `ArmedEffectSprite` 留给枪口/特效，**不要**把整身持枪帧铺上去（会叠两个角色）

图集行表见 [sheet.md](sheet.md)。`.tscn` 写法见 [tscn-format.md](tscn-format.md)。

## 流程

1. 读目标 `.tscn`：已有 `ext_resource`、`AtlasTexture` 的 `region`、`SpriteFrames` 动画名与速度。
2. 量图集：

```bash
python3 .cursor/skills/godot-sprite-frames/scripts/inspect_sheet.py resources/texture/W.png --cell 32
```

只使用**有像素**的格子；`W.png` 第 5 列（x=128）除特效行外是空的。
3. 若用户说「参照 `normal_*`」：同一方向、同样帧数/速度/loop，只改图集行（通常 +4 行 = +128px）。
4. 为每帧新增 `sub_resource AtlasTexture`，`atlas` 指向已有 `ExtResource`，`region = Rect2(x, y, w, h)`。id 不要和现有冲突。
5. 在 `SpriteFrames.animations` 数组**末尾**追加动画对象（结构与现有条目一致：`frames` / `loop` / `name` / `speed`）。`loop` 在 Godot 4 文本里常写成 `1`。
6. 告诉用户：Godot 若已打开该场景，执行 **Scene → Reload Saved Scene**，在 `BodySprite` 的动画下拉里检查新名字。

## 禁止

- 改已有 `normal_*` 的 region，除非用户明确要求重切
- 把特效行（`W.png` y=256）塞进行走动画
- 复制整份 `SpriteFrames` 另起一个节点来播同一套身体动画
- 为加动画去改 `.godot/` 或无关 `.import`

## 切图原则

- 先用文件像素尺寸 ÷ 现有动画的 `region` 宽高，不要猜 16/32/64
- 现有 `normal_right` 在 y=0、`left` y=32、`down` y=64、`up` y=96 时，对应 `armed_*` 在 y=128/160/192/224
- 每向默认 4 帧、x = 0,32,64,96，与现有一致
