# SpriteFrames 在 .tscn 里的写法

每个切片：

```
[sub_resource type="AtlasTexture" id="AtlasTexture_唯一id"]
atlas = ExtResource("已有纹理id")
region = Rect2(x, y, 宽, 高)
```

`SpriteFrames.animations` 里一项：

```
{
"frames": [{
"duration": 1.0,
"texture": SubResource("AtlasTexture_唯一id")
}, {
...
}],
"loop": 1,
"name": &"armed_right",
"speed": 8.0
}
```

- `name` 用 `&"动画名"`（StringName）
- 追加时用 `}, {` 接在上一项后面，最后一项以 `}]` 结束整个数组
- 不要改 `SpriteFrames` 的 sub_resource id，节点上的 `sprite_frames = SubResource(...)` 必须仍指向它
