# CNN USB / HDMI FPGA 工程说明

本工程是一个面向 FPGA 的实时视频检测与识别系统。当前主线功能是从 HDMI 视频流中检测车牌候选框，用 overlay 在原图上画框，同时裁剪子图送入 LPRNet 做字符识别，最终把结果叠加到 HDMI 输出视频中。

工程中同时保留了两套 FPGA 目标：

- `rtl`、`prj`、`sim`：较早版本，主要面向 Xilinx K7-325T。
- `rtl_pds`、`prj_pds`、`sim_pds`：Pango/PDS 版本，主要面向 PG2L200H，开始时是因为PDS不支持许多可以在Vivado综合的SystemVerilog语法。这个版本更晚，已经包含一些功能改动，例如 DDR 同帧视频延迟、LPRNet v10 迁移、crop/overlay 相关改动等。

因此阅读或修改工程时，不要简单认为 `rtl` 和 `rtl_pds` 只是同一份代码的厂商重命名。当前开发重点通常在 `*_pds` 这一套。

## 目录结构

- `rtl_pds`：PG2L200H 目标 RTL。
  - `hdmi_loop.sv`：PDS 工程顶层，连接 HDMI、YOLO、DDR 延迟、overlay/crop 和 LPRNet。
  - `top_yolo.sv`：YOLO 检测网络顶层，串接 layer0 到 layer10。
  - `top_lprnet.sv`：LPRNet 识别网络顶层，当前串接 layer20 到 layer31，并接 CTC 后处理。
  - `data_process`：CNN 通用层、PE、输入窗口缓存、输出累加、后处理等模块。
  - `overlay`：box 画框、子图裁剪、crop buffer 管理。
  - `ddr`：PDS 版本中用于视频延迟对齐的 DDR 读写封装。
- `prj_pds`：PDS 工程文件、约束和 IP 工程引用。
- `sim_pds`：PDS 版本 ModelSim testbench。
- `sim_pds/sim_modelsim`：ModelSim `.bat` 和 `.tcl` 脚本入口。
- `python_script`：网络参数生成、仿真数据比较、辅助图片/数据脚本。
- `conv_data_yolov3_new_pds`：当前 PDS YOLO 网络的 `.mat` 数据。
- `conv_data_lprnetv10`：当前 PDS LPRNet v10 网络的 `.mat` 数据。
- `conv_data_hex_pds`：由 Python 脚本生成的仿真输入 hex。
- `rtl_pds/data_process/header`：由 Python 脚本生成的 layer 参数头文件。
- `rtl_pds/data_process/mem_data`：由 Python 脚本生成的权重、偏置、LUT、字符点阵等 mem 文件。
- `doc`：开发记录、结构理解和调试笔记。

## 视频与识别链路

PDS 版本的主链路大致如下：

```text
HDMI RX
  -> 视频/像素时钟域整理
  -> YOLO 输入适配
  -> top_yolo
  -> box packet
  -> box_overlay_sync + crop_buffer_manager
  -> top_lprnet
  -> lprnet_post_process
  -> OSD/HDMI TX
```

为了让 overlay/crop 使用的底图与 YOLO 输出的 box 来自同一帧，PDS 版本在 overlay 前加入了 DDR 视频延迟链路。视频流以 RGB888 输入，DDR 中可压缩存为 RGB565，读出后扩展回 RGB888。DDR 读取触发点与 YOLO 流水线输出标志相关，用于抵消 YOLO 固定流水延迟。

DDR 不是 CNN 推理本身的必需条件。未加入 DDR 的原始设计是一条完全流式的片上处理链路，中间特征图通过 Line Buffer、Ping-Pong RAM、FIFO 和层间 ready/valid 风格的时序直接传递，不依赖片外缓存。如果应用允许 box 与底图相差一帧，或不要求 overlay/crop 严格使用 YOLO 检测的同一帧视频，那么整个系统可以不使用任何外挂帧缓存。当前 DDR 的主要作用是缓存原始视频帧，用来补偿 YOLO 固定流水延迟，使画框和裁剪子图尽量与 box 来源保持同帧。

## CNN 生成链路

`python_script/CnnHardwareGenerator_pds.py` 是 PDS 版本 CNN 硬件参数生成的核心脚本。它不仅导出权重，还定义每一层的硬件结构参数，包括：

- layer 编号和对应 `.mat` 文件名。
- `pe_page_num`：输入通道并行分组数。
- `pe_col_num`：输出通道并行分组数。
- `cycle_period_cin` / `cycle_period_cout`：输入/输出通道复用周期。
- 卷积核大小、stride、是否 maxpool、是否 ReLU。
- 输入输出位宽、特征图尺寸、权重/偏置位宽。

运行该脚本会生成：

- `rtl_pds/data_process/header/layerN.vh`
- `rtl_pds/data_process/mem_data/weight_layerN_pageP.mem`
- `rtl_pds/data_process/mem_data/bias_layerN.mem`
- `conv_data_hex_pds/layerN_input_Xbit.hex`

当前 PDS 映射约定：

- YOLO 使用 layer0 到 layer10，对应 `conv_data_yolov3_new_pds`。
- LPRNet v10 使用 layer20 到 layer31，对应 `conv_data_lprnetv10`。
- LPRNet 输入为 RGB 三通道、`20 x 80` 子图。
- LPRNet 最后一层输出 76 类，blank 类固定为 75。

## 三维脉动卷积阵列

本工程的卷积核心不是传统“指令调度 + 片外 DDR 搬运特征图”的加速器，而是面向固定网络结构的全流水线数据流架构。每层卷积由 `input_layer`、`pe_page`、`output_layer` 组成，层与层之间直接以流式特征图连接。

这里的脉动卷积阵列本质上是固定权重阵列。权重在综合/仿真前由 `CnnHardwareGenerator_pds.py` 预处理成 `.mem` 文件，运行时由 `w_manager.sv` 按固定周期循环读取，不需要 CPU 或外部总线动态下发权重。换模型时重新生成 `.mem` 和 `layerN.vh`，并同步调整层级连接即可。

卷积阵列可以从三个维度理解：

- 空间卷积维度：`PE_ROW_NUM = KERNEL_ROW * KERNEL_COL`。`pe_col.sv` 内部串接多个 `pe.sv`，每个 PE 完成一个乘加，沿卷积核窗口展开形成一列 MAC 链。
- 输出通道维度：`PE_COL_NUM`。`pe_page.sv` 中并行例化多个 `pe_col`，同一输入窗口可同时计算多个输出通道槽位。
- 输入通道分组维度：`PE_PAGE_NUM`。`layer.sv` 中并行例化多个 `pe_page`，分别处理不同输入通道 page，`output_layer.sv` 再对 page partial sum 加和、加偏置、移位量化并输出。

通道没有完全并行展开，而是通过 `CYCLE_PERIOD_IN` 和 `CYCLE_PERIOD_OUT` 做时间复用：

- `pe_page_num * cycle_period_cin` 覆盖输入通道数。
- `pe_col_num * cycle_period_cout` 覆盖输出通道数。
- `cycle_period = cycle_period_cin * cycle_period_cout` 决定权重循环周期。
- `CnnHardwareGenerator_pds.py` 会按这个时序预排布 weight mem，使 `w_manager.sv` 在每个时间步读出与数据窗口对齐的权重。

这种三维展开加时间复用的方式让数据在阵列中连续流动。`input_layer.sv` 只缓存卷积窗口所需的行数据，不把整层特征图写回片外 DDR；`d_manager.sv` 和 `pe_page.sv` 内部延迟链负责把数据与不同 PE 列的权重对齐。它的优势是片外带宽需求低、层间调度简单、延迟小，也更适合在 FPGA 上做稳定时序收敛。

数据与权重的对齐分成两部分实现：

- 数据侧：`d_manager.sv` 中 `D[n]` 相对 `data[n]` 延迟 `n+1` 个周期；`pe_page.sv` 中第 `c` 个 `pe_col` 的输入又相对前一列继续延迟。这样数据沿 PE 链和输出通道列向前脉动。
- 权重侧：`CnnHardwareGenerator_pds.py` 在生成 `weight_layerN_pageP.mem` 时做预偏移，核心公式是 `eff_t = (t - r - c) % cycle_period`。其中 `r` 补偿卷积核 MAC 链中的空间位置延迟，`c` 补偿输出列延迟。偏置没有卷积核空间维，只使用 `eff_t = (t - c) % cycle_period`。

这样设计后，运行时硬件不需要复杂的权重重排网络或多端口交叉开关，只要顺序循环读取权重 mem，就能与被延迟后的数据窗口对齐。PE 之间主要通过相邻级联和局部延迟寄存器连接，拓扑简单、结构规整，利于 FPGA 布局布线、时序收敛和规模化复制。

阵列规模可以按目标 FPGA 资源重新配置：

- 增大 `PE_PAGE_NUM` 或 `PE_COL_NUM` 可以提高输入/输出通道并行度，但会增加乘法器、寄存器和布线压力。
- 增大 `CYCLE_PERIOD_IN` 或 `CYCLE_PERIOD_OUT` 可以用更多时间复用换取更少并行硬件。
- `USE_DSP_PE` 可按层选择乘法使用 DSP 还是 LUT 逻辑；DSP 充足时可提高乘法性能，DSP 紧张时可把部分小层映射到 LUT 乘法。
- MaxPool 层通常改变空间尺寸，不改变通道组织，因此配置时要特别保持通道数和输出节拍与前后层一致。

这些参数共同决定吞吐、资源和时序裕量。迁移到更小或更大的 FPGA 时，通常先保持网络结构不变，再调整 `PE_PAGE_NUM/PE_COL_NUM/CYCLE_PERIOD_*` 和 `USE_DSP_PE`，重新生成 header/mem 并跑单层 compare。

## 技术指标参考

以下指标来自 `doc/技术文档-CICC1000270.docx`，对应未加入 DDR 视频延迟、且尚未迁移到当前 LPRNet v10 分支时的技术文档。当前工程已经继续迭代，最终指标应以最新 PDS 综合、布局布线和板级测试结果为准。

| 项目 | 指标 |
| --- | --- |
| 目标器件 | PG2L200H / PG200H 系列，当前 PDS 工程面向 PG2L200H-6FBB676 |
| 视频规格 | HDMI 720P@60Hz，像素时钟 74.25MHz |
| CNN 处理时钟 | 约为像素时钟 2 倍，技术文档中按约 148.5MHz 估算延迟 |
| YOLO 延迟 | 100MHz 仿真约 1.7ms；折算 148.5MHz 约 1.14ms |
| LPRNet 延迟 | 100MHz 仿真约 3.5ms；折算 148.5MHz 约 2.35ms |
| 端到端能力 | 720P@60Hz 下可在单帧内完成多个车牌定位与识别，文档测试中单帧支持 8 个车牌号 |
| 量化误差 | YOLO 累计信噪比误差小于 0.05%，LPRNet 小于 0.06% |
| 实测识别效果 | 清晰场景下车牌类型检测接近 100%，车牌号识别可达 95% 以上 |
| 适应范围 | 约 `20x80` 到 `200x800` 的车牌框，约 30 度以内俯仰、偏航、横滚角 |
| 资源利用率 | LUT 10.65%，Registers 27.26%，DRM 47.11%，APM 53.51% |
| 时序结果 | 技术文档中 pixclk Fmax 82.33MHz，clk_pe Fmax 163.23MHz，Setup/Hold Slack 为正 |
| 功耗 | 总功耗约 3.377W，其中静态功耗约 0.825W |

量化策略上，技术文档采用 PPQ 做对称量化和 Power-of-Two 量化，使硬件侧主要通过移位完成尺度调整，减少乘法和反量化资源。YOLO 文档配置中输入和中间张量主要按 9bit 量化；LPRNet 文档配置中输入按 9bit，中间张量按 10bit 量化。当前工程实际位宽以各 `layerN.vh` 和 `CnnHardwareGenerator_pds.py` 生成参数为准。

## 更换成自己的模型

如果要把 YOLO 或 LPRNet 换成自己的模型，建议按下面顺序做。

1. 准备模型导出的 `.mat` 数据。

   当前生成器期望卷积层 `.mat` 至少包含 `input`、`output`、`weight`、`bias`、`shift_k`。其中 `weight` 维度为 `(Cout, Cin, KernelRow, KernelCol)`，`input/output` 通常为 `(1, Channel, Row, Col)`。

2. 确认网络结构只使用当前 RTL 支持的算子。

   当前通用层主要支持卷积、ReLU、最大池化。若模型包含 BatchNorm、LeakyReLU、上采样、concat、reshape 等算子，需要先在训练/导出侧融合，或扩展 RTL。

3. 修改 `CnnHardwareGenerator_pds.py` 的层名映射。

   例如 LPRNet v10 使用 `lprnetv10_layer_map` 把 layer20 到 layer31 映射到 `node_conv2d_*` 和 `node_max_pool2d_*`。换模型时需要让 layer 编号、`.mat` 文件名和实际网络结构一一对应。

4. 重新选择每层硬件并行度和节拍。

   关键约束是：

   - `pe_page_num * cycle_period_cin` 要覆盖输入通道数。
   - `pe_col_num * cycle_period_cout` 要覆盖输出通道数。
   - 相邻层通常需要让上一层 `PE_COL_NUM` 等于下一层 `PE_PAGE_NUM`。
   - 相邻层通常需要让上一层 `CYCLE_PERIOD_OUT` 等于下一层 `CYCLE_PERIOD_IN`。
   - MaxPool 不改变通道数时，输出通道数和输出节拍应保持与输入侧通道组织一致。
   - `step_row` / `step_col` 必须与特征图尺寸变化一致。

5. 运行生成器。

   ```powershell
   python python_script/CnnHardwareGenerator_pds.py
   ```

6. 更新 RTL 顶层串接。

   - YOLO：修改 `rtl_pds/top_yolo.sv`。
   - LPRNet：修改 `rtl_pds/top_lprnet.sv`。
   - 如果新增 layer 编号或 page 数，检查 `rtl_pds/data_process/layer.sv` 中权重/偏置 mem 文件路径覆盖是否完整。
   - 如果最终层编号或输出通道变化，检查 `hdmi_loop.sv`、`lprnet_post_process.sv`、字符解码和 OSD 相关宽度。

7. 更新 testbench 和比较脚本。

   - 单层验证：`sim_pds/tb_layer.sv`
   - LPRNet 整网：`sim_pds/tb_lprnet.sv`
   - 后处理：`sim_pds/tb_lprnet_post_process.sv`
   - 数据比较：`python_script/compare_data_pds.py`

8. 按从小到大的范围验证。

   ```powershell
   cd sim_pds\sim_modelsim
   .\2_Run_test_layer_run-all.bat 25
   cd ..\..
   python python_script\compare_data_pds.py --layer 25
   ```

   然后再跑整网和顶层语法：

   ```powershell
   cd sim_pds\sim_modelsim
   .\9b_Run_test_lprnet.bat
   .\9c_Run_test_top_lprnet_syntax.bat
   ```

## 常用仿真入口

PDS 版本的常用脚本位于 `sim_pds/sim_modelsim`：

- `2_Run_test_layer_run-all.bat <layer>`：单层仿真。
- `8_Run_test_lprnet_post_process.bat`：LPRNet 最后一层加 CTC 后处理仿真。
- `9a_Run_test_yolo.bat`：YOLO 顶层仿真。
- `9b_Run_test_lprnet.bat`：完整 LPRNet 链路仿真。
- `9c_Run_test_top_lprnet_syntax.bat`：`top_lprnet` 编译/例化检查。
- `10_Run_test_ddr_video_delay_sync.bat`：DDR 视频延迟链路快速行为仿真。
- `10a_Run_test_ddr_video_delay_sync_pds_ip.bat`：PDS DDR IP smoke 联合仿真。

ModelSim 脚本不要并行运行同一个 `rtl_work` 工作库。并行跑多个 `.bat` 容易遇到 `_opt` 优化库锁，导致看起来像编译失败的假错误。

## 仿真 X/Z 约定

`rtl_pds/data_process/sdp_ram.sv` 中的 BRAM 仿真模型故意不做初始化。这样如果代码读到了尚未写入的 RAM 地址，ModelSim 输出中会出现 `x/z`，可以及时暴露 valid、new_line 或读写地址时序问题。

因此不要为了让比较脚本通过而给 BRAM 加零初始化。正确处理方式是修复数据有效控制和缓存预热逻辑。`python_script/compare_data_pds.py` 也会把任何 `x/z` 当成错误处理。

## PDS 与 Xilinx 版本的关系

早期工程在 `rtl`、`prj`、`sim` 中，主要服务 Xilinx K7-325T。PDS 版本在 `rtl_pds`、`prj_pds`、`sim_pds` 中，目标器件为 PG2L200H-6FBB676。

由于两套代码形成时间不同，PDS 版本不只是厂商 IP 替换，还包含功能演进。把一个版本的改动移植到另一个版本时，需要同时检查：

- 时钟、PLL、复位和 IO 原语。
- RAM/FIFO/DDR IP。
- 工程约束和顶层端口。
- CNN layer 参数头文件和 mem 路径。
- testbench 使用的 include、工作目录和文件 IO 路径。

## PDS 综合与 Debug 经验

PDS 版本中遇到过“ModelSim 仿真正常，但综合、DeviceMap 或上板行为异常”的情况。曾出现过 `LPRNet` 在综合结果中消失，或者`u_char_overlay` 在综合/映射后资源异常偏小，看起来只剩少量寄存器、没有有效 LUT 的现象。这类问题不一定是算法错误，也不一定能从普通时序报告中直接看出来。

如果 LPRNet 或字符叠加逻辑在综合结果中不可见，或者资源明显不符合预期，可以先尝试清除 PDS 缓存后重新跑流程：删除工程生成的 `compile`、`synthesize`、`device_map` 等缓存/中间结果文件夹，再重新 compile、synthesize 和 DeviceMap。有时 PDS 的增量缓存会保留错误的层级解析或优化结果，清缓存后可以恢复正常。

还遇到过与 `prj_pds/synthesize/hdmi_loop_syn.fic` 相关的缓存现象：LPRNet 输出一开始上板异常，插入 PDS Fabric Debugger 后正常；随后复制整个工程，在复制后的工程中删除 `synthesize/hdmi_loop_syn.fic`，并从已有综合结果继续往后跑，生成的 bit 流也能正常识别字符。这个现象说明 `.fic` 或 PDS 工程内部状态可能会影响后续流程复用的网表/优化信息。需要注意，这不是一个稳定的“修复公式”：同一个复制工程删除 `.fic` 后如果直接从头重新跑完整流程，曾出现上板后连 YOLO 都不工作的情况。因此遇到仿真正常、资源和时序看起来也正常但上板行为异常时，应记录当次 PDS 工程状态、是否插入过 Fabric Debugger、是否删除过 `.fic`、以及从哪个流程阶段继续运行；不要只用“清缓存后从头跑”作为唯一判断依据。

但如果问题反复出现，通常要进一步检查 RTL 写法和综合优化边界。`syn_preserve` 不是“保住整个功能模块”的保险丝，它主要保寄存器，不一定保组合逻辑、ROM、FIFO、mux 路径，也不一定能阻止 DeviceMap 做跨层常量传播和死逻辑删除。例如只给 `char_overlay` 内部寄存器加 `syn_preserve`，如果上游 `lprnet_out_valid`、`lprnet_frame_start` 或 `lprnet_out_char` 被工具误判为恒定/不可达，那么字符写入路径仍会被认为是死逻辑，最终画字 mux 和字体 ROM 仍可能被优化掉。

实测中，把关键 debug 信号接到顶层引脚或加 `PAP_MARK_DEBUG` 后，电路可能突然正常。这通常说明 debug 改变了综合/映射可观察性或布局布线结果：

- 如果加 debug 后资源恢复正常，优先怀疑 PDS 优化或 DeviceMap 对相关 RTL 的处理存在问题。
- 如果只有真正接到顶层引脚才正常，而仅保留 `syn_preserve` 不正常，要继续检查跨时钟域、复位释放、时序约束和布局相关问题。
- debug 引脚是顶层可观察输出，约束强度通常高于普通 preserve 属性，工具不能随意删除会影响外部引脚的逻辑。

调试 LPRNet 字符链路时，不要只保留 `char_overlay`。建议保住从 LPRNet 最后一层到字符叠加的完整链路：

- `top_lprnet.sv`：最后几层的 `new_line_out_1`、`output_valid`、`layer_y_out`，尤其是最终层输出。
- `lprnet_post_process.sv`：`ef_val_valid`、`ef_val_out_channel`、`ctc_match`、`out_valid`、`frame_start_out`、`out_char`。
- `hdmi_loop.sv`：`lprnet_out_valid`、`lprnet_frame_start`、`lprnet_out_char`，以及 crop 到 LPRNet 的 `lprnet_new_line`、`lprnet_data_valid`。
- `char_overlay.sv`：坐标 FIFO、字符 FIFO、`c_valid` 字符缓存、字体 ROM 地址流水线、`char_pixel` 和最终视频 mux。

实际调试中，曾在 PDS Fabric Debugger 中插入一个 FLA debug core。这里说的是综合工具中实际插入的 debug 采样信号，不是 RTL 代码里的 `PAP_MARK_DEBUG` 或 `syn_preserve` 注解。`prj_pds/log/debugger.log` 中该 core 的采样宽度为 `0x3b`，即 59 bit，主要包含以下信号：

| Debug 信号 | 位宽 | 含义 |
| --- | --- | --- |
| `crop_wr_en[7:0]` | 8 | `box_overlay_sync` 对 8 个候选框的裁剪像素写使能。某一 bit 拉高表示对应 box 当前正在向 crop buffer 写入一个裁剪像素。 |
| `end_crop_wr[7:0]` | 8 | 对应 box 的一次裁剪结束脉冲。用于确认一个完整 `CROP_WIDTH x CROP_HEIGHT` 子图已经写完。 |
| `start_crop_wr[7:0]` | 8 | 对应 box 的一次裁剪开始脉冲。用于确认检测框被接收并开始产生子图。 |
| `lprnet_new_line` | 1 | crop buffer 输出到 LPRNet 的新行标志。用于检查 `20 x 80` 子图行边界是否正确送入 LPRNet。 |
| `lprnet_data_valid` | 1 | LPRNet 输入数据有效信号。和 `lprnet_rgb_data` 配合，表示当前 PE 时钟周期有一个 RGB 像素样本送入 LPRNet。 |
| `lprnet_out_char[6:0]` | 7 | LPRNet CTC 后处理输出的字符编号。只有在 `lprnet_out_valid` 有效时才应作为字符结果解释。 |
| `lprnet_out_valid` | 1 | LPRNet 后处理字符输出有效脉冲。如果输入 crop 正常但该信号没有脉冲，问题通常在 LPRNet 计算链路或后处理。 |
| `lprnet_frame_start` | 1 | 一组识别字符的起始脉冲，`char_overlay` 用它对齐字符坐标。若 `out_valid` 有而该信号异常，字符可能无法正确挂到对应 box 坐标上。 |
| `lprnet_rgb_data[23:0]` | 24 | 实际送入 LPRNet 的 RGB888 子图像素，约定为 `R[23:16]`、`G[15:8]`、`B[7:0]`。用于检查裁剪图像内容、颜色顺序和数据是否为全黑/异常常量。 |

这些信号覆盖了从 box 裁剪开始、crop buffer 完成、LPRNet 输入、LPRNet 输出到字符坐标对齐的主路径。若加上这组实际 debug core 后上板行为恢复正常，而移除后又异常，说明问题更可能与 PDS 综合/映射的可观察性、优化边界或布局布线变化有关。注意这些信号不一定都在同一个时钟域；如果在同一个 FLA core 中跨时钟采样，波形更适合判断“有没有脉冲/数据是否活动”，不适合作为严格周期级时序关系的唯一依据。

PDS 对部分 SystemVerilog 写法支持不如 Vivado 完整，`rtl` 和 `rtl_pds` 下的 `layer` 相关文件存在写法差异，主要就是为了绕开这些限制：

- 不要在可综合 RTL 中依赖 `$sformatf("bias_layer%0d.mem", LAYER_NUM)` 这类动态字符串来选择 mem 文件。PDS 可能把它判定为不可综合，或无法正确解析初始化文件。PDS 版本应使用工具能静态解析的路径、显式 `if/generate/case` 分支，或由 Python 生成固定文件名引用。
- 模块端口上的多维数组尽量写成 packed 形式，例如 `logic [B:0][A:0] xx`。避免写成 unpacked 端口形式 `logic [A:0] xx [B:0]`，PDS 在层级解析、端口连接和综合时更容易出问题。转换为 packed 后，代码内部按下标引用的逻辑含义通常可以保持一致。
- 对跨模块的大数组、memory、FIFO 状态和 generate 结构，尽量使用 PDS 已验证过的写法；如果 Design hierarchy 解析失败或资源突然异常，优先怀疑语法支持和优化推断，而不是先假定算法错了。

## 开发建议

- 修改模型后先跑单层，再跑整网，最后接 `hdmi_loop`。
- 生成器、RTL 顶层、testbench、compare 脚本要同步修改，不要只改其中一处。
- 对 MaxPool 层特别注意通道数和 `cycle_period_cout`，池化通常改变空间尺寸，不改变通道组织。
- 保留 `doc` 下的调试记录。这个工程涉及视频时序、CNN 流水、DDR 和 overlay，多写一条记录往往能省很多回头路。
