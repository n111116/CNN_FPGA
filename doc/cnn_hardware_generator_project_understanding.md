# CNN 硬件生成与验证链路理解

本文记录当前工程中 `python_script/CnnHardwareGenerator_pds.py`、`python_script/compare_data_pds.py`、卷积网络数据目录、RTL 数据通路以及 `sim_pds` 下主要 testbench 的对应关系。目的是为后续将 LPRNet 从 `conv_data_lprnetv8_new_pds` 迁移到 `conv_data_lprnetv10` 时提供依据。

## 1. 数据目录与网络结构

当前工程里有三套与 CNN 相关的数据目录：

- `conv_data_yolov3_new_pds`：YOLO 检测网络数据，当前生成器映射为 `layer0` 到 `layer10`。
- `conv_data_lprnetv8_new_pds`：当前 LPRNet v8 识别网络数据，当前生成器映射为 `layer20` 到 `layer28`。
- `conv_data_lprnetv10`：待迁移的新 LPRNet 数据。目录中已经存在网络结构图 `网络结构LPRNetV10.png` 和 `.mat` 数据文件。

这些目录中的 `.mat` 文件是生成 RTL 参数和仿真参考数据的源头。卷积层文件包含 `input`、`output`、`weight`、`bias`、`shift_k` 字段；ReLU 和 MaxPool 文件包含 `input`、`output`、`shift_k` 字段。`weight` 的维度为 `(Cout, Cin, KernelRow, KernelCol)`，`input/output` 的维度为 `(1, Channel, Row, Col)`。

当前 LPRNet v8 结构为：

- 输入：`1 x 3 x 20 x 80`
- `Conv(16, 3x3)` -> `ReLU` -> `MaxPool`，输出仍为 `1 x 16 x 20 x 80`
- `Conv(32, 3x3)` -> `ReLU` -> `MaxPool`，输出为 `1 x 32 x 10 x 40`
- `Conv(64, 3x3)` -> `ReLU` -> `MaxPool`，输出为 `1 x 64 x 5 x 20`
- `Conv(128, 3x3)` -> `ReLU`
- `Conv(128, 1x3)` -> `ReLU`
- `Conv(76, 1x1)`，输出为 `1 x 76 x 5 x 20`

已观察到的 LPRNet v10 数据结构为：

- 输入：`1 x 3 x 20 x 80`
- `Conv(8, 3x3)` -> `ReLU`
- `Conv(16, 3x3)` -> `ReLU` -> `MaxPool`，输出仍为 `1 x 16 x 20 x 80`
- `Conv(16, 3x3)` -> `ReLU`
- `Conv(32, 3x3)` -> `ReLU` -> `MaxPool`，输出为 `1 x 32 x 10 x 40`
- `Conv(32, 3x3)` -> `ReLU`
- `Conv(64, 3x3)` -> `ReLU` -> `MaxPool`，输出为 `1 x 64 x 5 x 20`
- `Conv(128, 3x3)` -> `ReLU`
- `Conv(128, 1x3)` -> `ReLU`
- `Conv(76, 1x1)`，输出仍为 `1 x 76 x 5 x 20`

因此 v10 的输入尺寸、最终输出类别数和最终时空尺寸与 v8 一致，但中间卷积层数量和池化位置不同。

## 2. CnnHardwareGenerator_pds.py 的职责

`CnnHardwareGenerator_pds.py` 不是单纯导出权重，它同时定义了每层硬件的并行度、通道复用周期、步幅、卷积核尺寸、位宽和仿真路径。运行脚本后会生成：

- `rtl_pds/data_process/header/layerN.vh`
- `rtl_pds/data_process/mem_data/weight_layerN_pageP.mem`
- `rtl_pds/data_process/mem_data/bias_layerN.mem`
- `conv_data_hex_pds/layerN_input_Xbit.hex`

其中 `layerN.vh` 中的参数会被 `top_yolo.sv`、`top_lprnet.sv` 和 testbench include；`.mem` 文件会被 `w_manager.sv` 和 `output_layer.sv` 通过 `$readmemb` 读取；输入 `.hex` 文件会被 testbench 通过 `$readmemh` 读取。

几个关键映射关系：

- `pe_page_num * cycle_period_cin = 输入通道数`
- `pe_col_num * cycle_period_cout = 硬件可表达的输出通道数`
- 如果实际输出通道数少于硬件表达通道数，生成器会为越界通道填入负极小值权重/偏置，比较脚本也会跳过这些无效通道。例如当前 `layer28` 硬件为 `4 * 32 = 128` 个输出通道槽位，但实际类别数是 76。
- `cycle_period = cycle_period_cin * cycle_period_cout`，决定权重地址循环和一层处理一帧所需周期。
- 相邻层需要满足上一层 `pe_col_num` 与下一层 `pe_page_num` 的数据线数量匹配，同时上一层 `cycle_period_cout` 往往成为下一层 `cycle_period_cin`，这样层间流可以直接连接。
- `step_row/step_col` 同时影响 `input_layer` 的窗口输出节拍和 testbench 的喂数间隔，也决定输出特征图尺寸。

生成器对层名有硬编码映射：

- YOLO：`layer0` 对应 `node_conv2d`，`layer1` 到 `layer10` 对应 `node_conv2d_1` 到 `node_conv2d_10`，其中 `layer7` 和 `layer10` 无 ReLU。
- LPRNet v8：`layer20` 到 `layer28` 分别硬编码映射到 `node_conv2d`、`node_max_pool2d`、`node_conv2d_1`、`node_max_pool2d_1`、`node_conv2d_2`、`node_max_pool2d_2`、`node_conv2d_3`、`node_conv2d_4`、`node_conv2d_5`。

迁移 v10 时，这个硬编码映射必须修改，因为 v10 的层序变为 9 个卷积加 3 个池化，不能直接复用 v8 的 `layer20` 到 `layer28` 映射。

## 3. RTL 通用层结构

`rtl_pds/data_process/layer.sv` 是卷积层和池化层的统一封装：

- `MAX_POOL == 0` 时走卷积路径：`input_layer` -> 多个 `pe_page` -> `output_layer`
- `MAX_POOL == 1` 时走池化路径：`input_layer` -> `max_pool2d`

`input_layer.sv` 将串行输入流整理成卷积/池化窗口。它根据 `KERNEL_ROW/COL`、`STEP_ROW/COL`、`IMG_ROW/COL` 和 `CYCLE_PERIOD_IN/OUT` 控制行缓存、列缓存、padding 和 `new_line_out_1/data_out_valid`。后续网络结构变更只要仍是卷积和池化，原则上仍可复用该模块，但必须保证参数组合合法，例如 `CYCLE_PERIOD_OUT / STEP_COL / STEP_ROW` 在 testbench 和当前节拍设计中应是整数。

`pe_page.sv` 内部包含：

- `d_manager.sv`：把窗口数据按 PE 列做延迟对齐。
- `w_manager.sv`：按 `CYCLE_PERIOD * PE_COL_NUM` 深度循环读取 weight mem。
- `pe_col.sv/pe.sv`：实现一列卷积核的乘加链，`USE_DSP_PE` 控制乘法使用 DSP 或 LUT 逻辑。

`output_layer.sv` 完成：

- 多个 page 的部分和累加。
- 读取 `bias_layerN.mem` 并加偏置。
- 根据 `SHIFT_KEY` 右移四舍五入。
- 根据 `WITH_RELU` 做 ReLU/无 ReLU 饱和输出。
- 输出 `final_out`、`output_valid` 和相对每行首个输出提前一拍的 `new_line_out_1`。

需要特别注意：`layer.sv` 为了避开 PDS 对字符串参数推断的问题，用宏硬编码了 `weight_layerN_pageP.mem` 和 `bias_layerN.mem` 的路径。新增 v10 层编号或增加 page 数时，必须同步扩展这些 `INST_PE` 和 `INST_OUT` 覆盖范围，否则 RTL 即使参数存在，也可能读不到对应权重或偏置。

## 4. YOLO 数据通路

`rtl_pds/top_yolo.sv` 手写串接 `layer0` 到 `layer10`。其中：

- `layer0` 到 `layer7` 是一路分支，`layer7` 的原始特征图通过顶层端口输出。
- `layer4` 同时分支给 `layer8`，然后接 `layer9`、`layer10`。
- `layer10` 接 `post_cv3_conv2d.sv` 后处理，输出 `post_packet_data/post_packet_valid/post_frame_done`。

`post_cv3_conv2d.sv` 使用 `extrema_finder.sv` 对每个特征图位置的通道做极值选择，然后用 `activation_lut.sv` 转置信度并按阈值输出 box packet。输出打包格式在代码中为：

- `[31:24]`：通道号
- `[23:16]`：特征图 X
- `[15:8]`：特征图 Y
- `[7:0]`：confidence

在 `hdmi_loop.sv` 中，YOLO 的输入来自视频/适配后的 RGB 数据流；YOLO 输出 packet 再进入后续 box/overlay/crop 链路。

## 5. LPRNet 数据通路

`rtl_pds/top_lprnet.sv` 当前手写串接 `layer20` 到 `layer28`，之后接 `lprnet_post_process.sv`。当前顶层假设最后一层是 `layer28`，后处理参数也来自 `layer28.vh`：

- `POST_CH_OUT_NUM = CYCLE_PERIOD_OUT_LAYER28 * PE_COL_NUM_LAYER28`
- `BLANK_CHAR = 75`
- 最后一层输出转 signed 后送入后处理。

`lprnet_post_process.sv` 的处理链为：

- `lprnet_spatial_sum.sv`：对最后一层输出在 `IMG_ROW` 方向做累加，等价于把 `5 x 20` 的高度维压缩到每列一个通道向量。
- `extrema_finder.sv`：对每个时间步的 76 类通道找最大值。
- CTC greedy decoder：过滤 blank 和连续重复字符，输出 `out_char/out_valid/frame_start_out`。

在 `hdmi_loop.sv` 中，`box_overlay_sync` 产生裁剪写入信号，`crop_buffer_manager` 将子图整理为 LPRNet 输入流：

- `lprnet_rgb_data[23:16]` -> `lprnet_data_in[0]`
- `lprnet_rgb_data[15:8]` -> `lprnet_data_in[1]`
- `lprnet_rgb_data[7:0]` -> `lprnet_data_in[2]`

因此只要 v10 仍以 RGB 三通道、20x80 子图作为输入，并仍输出 76 类、5x20 时空图，overlay/crop 与 LPRNet 后处理接口可以保持大体不变；需要变化的是 LPRNet 内部层序和最后层编号。

## 6. 仿真与 compare 脚本

`sim_pds/tb_layer.sv` 用于单层验证。当前文件通过 include 所有 layer header，但实例化和信号命名是固定在某一层上的，文件开头注释建议用查找替换把 `_LAYER21` 换成目标层。它读取 `INPUT_FILE_PATH_LAYERN`，输出到 `OUTPUT_FILE_PATH_LAYERN`。

`sim_pds/tb_lprnet.sv` 用于当前 v8 的整网验证。它手写串接 `layer20` 到 `layer28`，读取 `layer20` 的输入 hex，同时把每层输出和 CTC 输出写入 `sim_out`。其中输入行尾间隙专门拉长，用于让前几层较快的输出速度匹配后续层，代码注释明确提到这是为了匹配 `layer22` 处理速度。v10 迁移时这里的层间吞吐和行间隙需要重新核算。

`sim_pds/tb_yolo.sv` 用于 YOLO 顶层验证。它驱动一帧 Layer0 输入流，并监控 `post_packet_valid` 和 `post_frame_done`，输出检测结果文本。

`python_script/compare_data_pds.py` 当前以源码内 `from CnnHardwareGenerator_pds import layer28 as layer_to_test` 的方式选择待比对层。它根据对应层的 MAT 参考输出和 `sim_pds/sim_modelsim/sim_out/layerN_output.hex` 做逐点比较。它已经对 `layer7`、`layer10`、`layer28` 的实际通道少于硬件槽位做了特殊跳过处理。后续 v10 若最后层仍是 76 类但硬件槽位大于 76，也需要保留或泛化这个跳过逻辑。

主要 ModelSim 脚本位于 `sim_pds/sim_modelsim`：

- `test_layer.tcl` / `1_Run_test_layer.bat`：单层仿真。
- `test_layer_all.tcl` / `2_Run_test_layer_run-all.bat`：单层 run-all 版本。
- `test_yolo.tcl` / `9a_Run_test_yolo.bat`：YOLO 顶层仿真。
- `test_lprnet.tcl` / `9b_Run_test_lprnet.bat`：LPRNet 顶层仿真。
- `test_lprnet_post_process.tcl` / `8_Run_test_lprnet_post_process.bat`：最后一层加 LPRNet 后处理仿真。

这些脚本通常会把 `rtl_pds/data_process/mem_data/*.mem` 拷贝到仿真工作目录，因为 RTL 内部 `$readmemb` 使用的是 `mem_data/...` 或当前工作目录下的 mem 文件路径。

## 7. 迁移 LPRNet v10 时需要同步改的点

1. 修改 `CnnHardwareGenerator_pds.py` 的 LPRNet 层定义和层名映射。建议给 v10 使用连续的新层号，或复用 `layer20` 起始但扩展到更多层；无论哪种方式，都要保证顶层、testbench、compare 脚本和 `layer.sv` 的硬编码路径一致。

2. 根据 v10 的每层实际 `Cin/Cout/Kernel/Stride/Pool` 重新选择 `pe_page_num`、`pe_col_num`、`cycle_period_cin`、`cycle_period_cout`、`step_row`、`step_col`。选择时要同时满足通道覆盖、层间线数匹配和总吞吐匹配，不只是让参数等于通道数。

3. 重新生成 `layerN.vh`、weight mem、bias mem 和输入 hex。确认 `CHANNEL_OUT_NUM_LAYERN` 如果大于真实输出通道数，后处理和 compare 脚本能正确忽略无效槽位。

4. 扩展 `rtl_pds/data_process/layer.sv` 中的 `INST_PE`/`INST_OUT` 硬编码路径，覆盖 v10 所有新增层号和 page 编号。

5. 重写或扩展 `rtl_pds/top_lprnet.sv`，按 v10 层序手写串接所有卷积/池化层，并把 `lprnet_post_process` 的输入改为 v10 最后一层。

6. 同步更新 `sim_pds/tb_lprnet.sv`，包括 include、信号定义、层实例、输出文件句柄、写文件逻辑和输入行间隙。v10 的前几层吞吐不同，不能直接沿用 v8 里针对 `layer22` 的行尾间隙公式。

7. 更新 `sim_pds/tb_lprnet_post_process.sv`，使其测试 v10 最后一层和后处理。

8. 更新 `python_script/compare_data_pds.py`，至少支持选择 v10 层；更稳妥的做法是改成命令行参数选择层，并根据 MAT 的真实输出通道数自动跳过硬件填充通道。

9. 跑验证顺序建议为：生成器只读检查 MAT 字段和 shape -> 单层仿真与 compare -> LPRNet 整网仿真 -> 后处理字符输出检查 -> 接入 `hdmi_loop` 后板级或链路仿真。

## 8. 目前需要确认的问题

以下问题会影响后续 v10 迁移的具体实现，不能靠猜：

1. v10 是否仍希望使用 `layer20` 起始编号并覆盖现有 v8 的 layer20 到 layer28，还是保留 v8，给 v10 使用新的编号段？

2. v10 的硬件吞吐目标是否要保持与当前 v8 LPRNet 接口完全一致，即 `crop_buffer_manager` 仍按当前节拍给 `lprnet_top` 喂 20x80 RGB 子图？

3. v10 中 MaxPool 的具体 kernel/stride 是否完全由 MAT 的输入输出尺寸推断即可，还是有显式结构文件需要作为准绳？当前生成器只通过手写 `step_row/step_col` 表达池化后的尺寸变化。

4. 是否要求 v10 与 v8 一样最终输出 76 类，且 blank 类仍固定为 75？

5. 迁移后是否需要保留 YOLO 的生成配置不变，只替换 LPRNet 相关层？
