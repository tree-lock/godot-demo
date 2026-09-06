# tile_map_data 二进制

Godot 4.3+ `TileMapLayer.tile_map_data`：

```
offset 0: uint16 format_version = 0
then repeat:
  +0  int16  coords.x
  +2  int16  coords.y
  +4  uint16 source_id   (0xFFFF = 已擦除，跳过)
  +6  uint16 atlas.x
  +8  uint16 atlas.y
  +10 uint16 alternative | flip flags
```

`alternative` 高位：`0x1000` 水平翻转，`0x2000` 垂直翻转，`0x4000` 转置。

校验：`(len(bytes) - 2) % 12 == 0`。base64 解码后可能多 0–2 字节 padding，写入时不要带多余字节。

`.tscn` 超过约 64 字节的数组会写成 `PackedByteArray("base64...")`（`format=4`）。替换时只换引号内的 base64，保持两个数组的顺序：先地面、后 overlay。
