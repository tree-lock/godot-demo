---
name: godot-world-bounds
description: >-
  Adds Godot 4.7 invisible world-edge air walls into a .tscn as WorldBounds
  (four StaticBody2D + SegmentShape2D). Use when the user asks to 加空气墙,
  世界边界, 封边, WorldBounds, Top/Bottom/Left/RightBoundary, or keep the
  player from walking off the tilemap.
---

# 空气墙（WorldBounds）

把四边不可见碰撞写进 `.tscn`，编辑器 Reload 后立刻能看见。不要在 C# `_Ready` 里 `new StaticBody2D()`（Play 才有，编辑器空）。

## 本项目约定

- 场景：`scene/game.tscn`
- 父节点：`WorldBounds`（`Node2D`）
- 四边：`TopBoundary` / `BottomBoundary` / `LeftBoundary` / `RightBoundary`（各一个 `StaticBody2D` + `CollisionShape2D`）
- 形状：`SegmentShape2D`，节点停在原点，用 `a`/`b` 写世界像素
- 网格：16×16，格子 16px → 场地 `0..256`
- 碰撞层不另设（默认 layer/mask 1，与地面 `physics_layer_0`、玩家一致）

## 四边坐标

`SegmentShape2D` 未写出的 `a` 默认为 `(0, 0)`。

| 节点 | a | b |
|------|---|---|
| TopBoundary | `(0, 0)`（可省略） | `(256, 0)` |
| BottomBoundary | `(0, 256)` | `(256, 256)` |
| LeftBoundary | `(0, 0)`（可省略） | `(0, 256)` |
| RightBoundary | `(256, 0)` | `(256, 256)` |

## 流程

1. 读 `scene/game.tscn`：已有 `WorldBounds` 子节点、`SegmentShape2D` id、是否已挂 `shape`。
2. 节点已在但名叫 `StaticBody2D` / `StaticBody2D2` / `StaticBody2D3`：只改名 + 补 shape，保留 `unique_id`。
3. 每个方向单独一个 `sub_resource`，id 不要和现有冲突。`.tscn` 写法：

```
[sub_resource type="SegmentShape2D" id="SegmentShape2D_bottom"]
a = Vector2(0, 256)
b = Vector2(256, 256)

[node name="BottomBoundary" type="StaticBody2D" parent="WorldBounds"]

[node name="CollisionShape2D" type="CollisionShape2D" parent="WorldBounds/BottomBoundary"]
shape = SubResource("SegmentShape2D_bottom")
```

4. 告诉用户：Godot 若已打开该场景，执行 **Scene → Reload Saved Scene**。Debug → Visible Collision Shapes 可核对四条边。

## 禁止

- 用 `WorldBoundaryShape2D`（无限半平面，容易和原点/朝向搞错）
- 用 `Area2D` 当空气墙（只检测，不挡住）
- 在 `_Ready` 里动态生成边界，或用脚本 `Clamp` 代替碰撞
- 为加空气墙去改 `.godot/`、Tile 碰撞多边形、或无关 `.import`
- 改已有边的 `a`/`b`，除非用户明确要求改场地尺寸
