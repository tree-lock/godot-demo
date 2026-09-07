# W.png 格子（32×32）

尺寸 160×288 → 5 列 × 9 行。行走动画只用前 4 列。

| 行 | y | 动画 |
|----|---|------|
| 0 | 0 | `normal_right` |
| 1 | 32 | `normal_left` |
| 2 | 64 | `normal_down` |
| 3 | 96 | `normal_up` |
| 4 | 128 | `armed_right` |
| 5 | 160 | `armed_left` |
| 6 | 192 | `armed_down` |
| 7 | 224 | `armed_up` |
| 8 | 256 | 特效（最多 5 帧，给 `armed-effect-sprite`，不是身体行走） |

持枪行比空手行像素更多（枪），可用来确认没有切错行。
