---
name: godot-paint-ground
description: >-
  Paints Godot 4.7 TileMapLayer ground into .tscn by encoding tile_map_data
  (2-byte header + 12-byte cells). Use when the user asks to 铺地面, 铺Tile, 铺砖,
  paint tiles, match a screenshot or grid layout to the tilemap, or edit
  TileMapLayer data in scene/game.tscn.
---

# 铺地面（Godot 4.7 TileMapLayer）

把格子写进 `.tscn` 的 `tile_map_data`，让编辑器立刻看见。不要用手改 base64，不要用 `_Ready` + `SetCell` 当关卡源（Play 才看得到，编辑器仍是旧图）。

## 本项目约定

- 场景：`scene/game.tscn`
- 地面层：`GoundTileMapLayer`（拼写保持现状，不要改名）
- 上层：`OverlayTileMapLayer`（16×32 立牌）
- 网格：16×16，格子 16px；相机 `offset=(128,128)` `zoom=2`
- 只使用 TileSet 里**已经定义**的 atlas 坐标

图块表见 [atlas.md](atlas.md)。编解码用 [scripts/tile_map_data.py](scripts/tile_map_data.py)。

## 流程

1. 读 `scene/game.tscn` 里两个 `TileSetAtlasSource`，确认可用 `(source_id, atlas_x, atlas_y)`。
2. 需要看现状时解码：

```bash
python3 .cursor/skills/godot-paint-ground/scripts/tile_map_data.py decode scene/game.tscn
```

3. 用 16 行、每行 16 个字符画图（字符含义见 atlas.md），再写入：

```bash
python3 .cursor/skills/godot-paint-ground/scripts/tile_map_data.py paint scene/game.tscn --ground-file map.txt --overlay 0,8 15,8
```

也可在对话里直接组 `rows = ['....', ...]`，用同一脚本的 `encode` 逻辑，只替换对应 `PackedByteArray("...")`。
4. 告诉用户：Godot 若已打开该场景，执行 **Scene → Reload Saved Scene**。

## 对照截图时

1. 截图应是 16×16 场地（约正方形）。按格子采样中心色，对齐 `atlas.md` 的参考色。
2. 黄虚线（`Y`）看**格子边框**的黄色像素，不要只看中心（中心仍是地板色）。
3. 终端砖（`K`）四角也有黄点。颜色接近 `(62,64,68)` 时标 `K`，不要标 `Y`。
4. 红叹号是上层 16×32，只占 **一个 cell**，视觉上盖住两格高。左右墙典型位置：`(0,8)`、`(15,8)`。
5. 分类会有噪声。先用像素归类，再按截图意图修：围墙、出入口、2×2 障碍、虚线组。

## 禁止

- 手改 `PackedByteArray` 字符串
- 使用未在 atlas source 里声明的坐标（例如动态图集的 `0:0` 16×16——那是 overlay 的 16×32）
- 为铺地改 `.godot/` 或大段重写无关 `.import`
- 把角色、子弹做成 Tile

## 格式要点

`tile_map_data` = `uint16 version`（恒为 0）+ 每格 12 字节 little-endian：

`int16 x, int16 y, uint16 source_id, uint16 atlas_x, uint16 atlas_y, uint16 alternative`

总长必须满足 `(len - 2) % 12 == 0`。`.tscn` 里是标准 base64。细节见 [format.md](format.md)。
