import scipy.io
import numpy as np
import os

"""
PDS 版本 CNN 硬件参数生成脚本。

这个脚本把量化后的 MAT 文件转换为固定权重 CNN RTL 所需的三类文件：
1. layerN.vh：每层结构参数、位宽、图像尺寸、仿真输入输出路径。
2. weight_layerN_pageP.mem / bias_layerN.mem：按脉动阵列时序预排布后的固定权重和偏置。
3. layerN_input_Xbit.hex：单层 testbench 使用的输入激励。

需要特别注意：本工程的卷积阵列是固定权重阵列，权重不会在运行时从外部动态配置。
换模型时需要重新运行本脚本生成 mem/header，并同步更新 top_yolo/top_lprnet、
testbench 和 compare 脚本中的层级连接关系。
"""

# YOLO 输入视频规格。PDS 顶层当前按 HDMI 720P@60Hz 视频链路设计。
BASE_IMG_COL = 1280
BASE_IMG_ROW = 720

# LPRNet 输入子图尺寸。crop_buffer_manager 输出的 RGB 子图会被整理成该尺寸。
BASE_IMG_ROW_LPERNET = 20
BASE_IMG_COL_LPERNET = 80

# 关键结构参数说明
# layer_num: RTL 层编号，也是 header/mem/hex 文件名中的 N。
# pe_page_num: 输入通道 page 数。每个 page 处理一组输入通道 partial sum。
# pe_col_num: 输出通道并行列数。每个 pe_col 在同一输入窗口上计算一个输出通道槽位。
# pe_row_num: 卷积核空间维展开后的 PE 数，通常为 kernel_row * kernel_col。
# img_row/img_col: 该层输入特征图尺寸，不是输出尺寸。
# max_pool: 1 表示该层走 max_pool2d 路径，不生成真实卷积权重。
# with_relu: output_layer 是否执行 ReLU/饱和处理。
# step_row/step_col: 卷积或池化步幅，同时影响 input_layer 取窗节拍和输出尺寸。

# cycle_period 是层内部通道时间复用周期。
# cycle_period_in: 每个输入 page 在时间上复用的输入通道数。
# cycle_period_out: 每个输出 PE 列在时间上复用的输出通道数。
# cycle_period = cycle_period_in * cycle_period_out，表示权重地址循环一轮的周期数。
# 通道覆盖关系：
#   实际输入通道数 <= pe_page_num * cycle_period_in
#   实际输出通道数 <= pe_col_num  * cycle_period_out
#
# 相邻层通常需要满足：
#   上一层 pe_col_num == 下一层 pe_page_num
#   上一层 cycle_period_out == 下一层 cycle_period_in
# 这样上一层输出的并行线数和时间复用节拍可以直接作为下一层输入。
#
# 一层处理一帧的理论周期数：
#   cycle_period * img_row * img_col / (step_row * step_col)
# 不同层的吞吐需要尽量匹配。若某些前级层计算量明显更小，可以在 testbench
# 或上游输入中拉大行间隔，让整网流式节拍保持稳定。


class CnnHardwareGenerator:
    """单个 CNN 层的硬件配置和文件生成器。

    一个实例对应 RTL 中的一个 layerN。实例化参数同时描述网络结构
    和硬件阵列规模，因此它既是模型到硬件的映射表，也是生成
    header/mem/hex 文件的唯一来源。
    """

    def __init__(self, layer_num, pe_page_num, pe_col_num,
                 cycle_period_cin, cycle_period_cout,
                 img_row=BASE_IMG_ROW, img_col=BASE_IMG_COL,
                 use_dsp = 0,
                 max_pool = 0,
                 with_relu = 1, 
                 kernel_col = 3,
                 kernel_row = 3, 
                 step_col = 1,
                 step_row = 1, 
                 bit_width_data = 8,
                 bit_width_out = 8,
                 output_mem_dir="rtl_pds/data_process/mem_data", 
                 output_vh_dir="rtl_pds/data_process/header",
                 mat_file_dir="conv_data_yolov3_new_pds"):
        """
        初始化硬件配置。

        pe_page_num/pe_col_num 决定空间并行规模，cycle_period_cin/
        cycle_period_cout 决定通道时间复用规模。use_dsp 控制 PE 乘法
        是否倾向使用 DSP，以便同一套网络根据目标 FPGA 资源做取舍。
        """
        self.layer_num = layer_num
        self.pe_page_num = pe_page_num
        self.pe_col_num = pe_col_num
        self.max_pool = max_pool
        self.kernel_col = kernel_col
        self.kernel_row = kernel_row
        self.pe_row_num = kernel_col * kernel_row
        self.cycle_period_cin = cycle_period_cin
        self.cycle_period_cout = cycle_period_cout
        self.cycle_period = cycle_period_cin * cycle_period_cout
        self.img_row = img_row
        self.img_col = img_col
        self.use_dsp = use_dsp
        self.step_row = step_row
        self.step_col = step_col
        self.bit_widths = {
                'data': bit_width_data,
                'out': bit_width_out
            }
        self.output_mem_dir = output_mem_dir
        self.output_vh_dir = output_vh_dir
        
        # 内部数据缓存
        self.weight = None
        self.bias = None
        self.shift_key = 0
        # with_relu 只影响卷积路径 output_layer；max_pool 层通常不接 ReLU。
        self.with_relu = with_relu # 1 if layer_num not in [8, 11] else 0
        # YOLO layer8 是从 layer4 分支出来的旧记录，当前主要保留作路径提示。
        self.prev_layer_num = layer_num - 1 if layer_num != 8 else 4

        # 默认按 YOLO 层名规则映射 MAT 文件。layer7/layer10 是输出分支，无 ReLU MAT。
        if(self.layer_num == 0):
            self.layer_name = "node_conv2d"
            self.relu_name = "node_relu"
        else:
            self.layer_name = f"node_conv2d_{self.layer_num}"
            if(self.layer_num == 7 or self.layer_num == 10):
                self.relu_name = None
            else:
                if(self.layer_num <= 6):
                    self.relu_name = f"node_relu_{self.layer_num}"
                else:
                    self.relu_name = f"node_relu_{self.layer_num - 1}"
        # LPRNet v10 层名与 YOLO 规则不同，使用显式映射复用 layer20 起始编号。
        # 换 LPRNet 模型时，通常首先修改这张表和后面的 layer20+ 实例参数。
        lprnetv10_layer_map = {
            20: ("node_conv2d",       "node_relu"),
            21: ("node_conv2d_1",     "node_relu_1"),
            22: ("node_max_pool2d",   None),
            23: ("node_conv2d_2",     "node_relu_2"),
            24: ("node_conv2d_3",     "node_relu_3"),
            25: ("node_max_pool2d_1", None),
            26: ("node_conv2d_4",     "node_relu_4"),
            27: ("node_conv2d_5",     "node_relu_5"),
            28: ("node_max_pool2d_2", None),
            29: ("node_conv2d_6",     "node_relu_6"),
            30: ("node_conv2d_7",     "node_relu_7"),
            31: ("node_conv2d_8",     None),
        }
        if self.layer_num in lprnetv10_layer_map:
            self.layer_name, self.relu_name = lprnetv10_layer_map[self.layer_num]
        
        self.layer_mat_file = mat_file_dir + f"/{self.layer_name}.mat"
        self.relu_mat_file = mat_file_dir + f"/{self.relu_name}.mat"
        print(f"for layer_num:{self.layer_num} reading: layer_mat_file={self.layer_mat_file}, relu_mat_file={self.relu_mat_file}")


        # 自动创建目录
        for d in [self.output_mem_dir, self.output_vh_dir]:
            if not os.path.exists(d):
                os.makedirs(d)

        # self.load_mat_data()
    def to_bin(self, val, width):
        """将整数转换为固定宽度二进制补码字符串，用于生成 .mem 文件。"""
        val = int(val)
        if val < 0:
            val = (1 << width) + val
        val = val & ((1 << width) - 1)
        return f"{val:0{width}b}"

    def load_mat_data(self):
        """从 MAT 文件加载权重、偏置、shift 和自动推导的位宽。

        卷积层读取 weight/bias；max_pool 层没有真实权重，这里只保留
        占位位宽，使后续 header 生成逻辑保持统一。
        """
        print(f"Loading {self.layer_mat_file}...")
        try:
            mat_data = scipy.io.loadmat(self.layer_mat_file)
            # print(mat_data)
            if(self.max_pool == 0):
                self.weight = mat_data['weight']
                if self.weight.ndim < 4:
                    # 在末尾添加缺失的维度（每个维度大小为1）
                    self.weight = self.weight.reshape(self.weight.shape + (1,) * (4 - self.weight.ndim))
                # print(f"** {self.weight[0:5][0:5][0][0]} **")
                print(f"weight.shape: {self.weight.shape}")
                self.bias = mat_data['bias'].flatten()
                # 权重/偏置位宽按最大绝对值自动推导；正数侧加 1 是为了覆盖补码正值上界。
                temp_max_bias = np.max(self.bias)
                temp_min_bias = np.min(self.bias)
                temp_biggest_bias = max(temp_max_bias+1, -temp_min_bias)
                self.bit_widths['bias'] = int(np.ceil(np.log2(temp_biggest_bias))) + 1
                temp_max_weight = np.max(self.weight.flat)
                temp_min_weight = np.min(self.weight.flat)
                temp_biggest_weight = max(temp_max_weight+1, -temp_min_weight)
                print(temp_max_weight, temp_min_weight)
                self.bit_widths['weight'] = int(np.ceil(np.log2(temp_biggest_weight))) + 1
                print(f"Calculated bias bit width: {self.bit_widths['bias']} bits (max bw value: {np.abs(temp_biggest_bias).max()})")
                print(f"Calculated weight bit width: {self.bit_widths['weight']} bits (max bw value: {np.abs(temp_biggest_weight).max()})")
            else:
                self.weight = []
                self.bias = []
                self.bit_widths['weight'] = 1
                self.bit_widths['bias'] = 1
            

            self.total_period = self.cycle_period * self.img_row * self.img_col / (self.step_col * self.step_row)
            print(f"Total Period per Frame: {self.total_period}")

            # # 读取 bit_widths: [DATA_WIDTH, weight_WIDTH, BIAS_WIDTH, OUT_WIDTH]
            # bw = mat_data['bit_widths'].flatten()

            
            # shift_k 使用 Power-of-Two 量化尺度，硬件中表现为右移位数。
            self.shift_key = abs(int(mat_data['shift_k'].item()))
            
            print(f"Parameters Loaded: BW={self.bit_widths}, Shift={self.shift_key}")
        except Exception as e:
            print(f"Error loading MAT file: {e}")
            raise

    def generate_mem_files(self):
        """生成按硬件时序预排布后的权重和偏置 .mem 文件。

        权重不是简单按 MAT 原始顺序写出，而是提前补偿了脉动阵列内部的数据延迟：
        d_manager 中 D[n] 相对 data[n] 延迟 n+1 个周期；pe_page 中第 c 个 pe_col
        的输入又相对第 0 列额外延迟 c 个周期。因此同一个全局时间 t 下，
        第 c 列、第 r 个卷积核位置实际看到的是更早时间步的数据。

        这里用 eff_t = (t - r - c) % cycle_period 预先选择权重对应的输入/输出
        通道时间步，使运行时 w_manager 只需顺序循环读 mem，读出的权重就已经
        与延迟后的数据对齐。偏置只需要按输出列 c 做预偏移，因为它不沿卷积核
        空间维 r 展开。
        """
        # 1. 生成每个输入 page 的权重文件。每行对应 w_manager 的一个读地址。
        for p in range(self.pe_page_num):
            filename = os.path.join(self.output_mem_dir, f"weight_layer{self.layer_num}_page{p}.mem")
            with open(filename, 'w') as f:
                # t 是未考虑阵列延迟前的层内通道时间步。
                for cin_step in range(self.cycle_period_cin):
                    for cout_step in range(self.cycle_period_cout):
                        t = cin_step * self.cycle_period_cout + cout_step
                        for c in range(self.pe_col_num):
                            line_bin = ""
                            # mem 中按 r 从高到低拼接，需与 pe_col 对 W[r] 的切片顺序保持一致。
                            for r in range(self.pe_row_num - 1, -1, -1):
                                # 权重预偏移核心：补偿卷积核 MAC 链 r 级延迟和第 c 个输出列延迟。
                                eff_t = (t - r - c) % self.cycle_period
                                eff_cin_step  = eff_t // self.cycle_period_cout
                                eff_cout_step = eff_t % self.cycle_period_cout
                                
                                current_cin_idx = p * self.cycle_period_cin + eff_cin_step
                                current_cout_idx = c * self.cycle_period_cout + eff_cout_step
                                
                                mat_col_idx, mat_row_idx = r % self.kernel_col, r // self.kernel_col
                                try:
                                    w_val = self.weight[current_cout_idx][current_cin_idx][mat_row_idx][mat_col_idx]
                                    # w_val = 255
                                except IndexError:
                                    # 硬件槽位可能多于真实通道；越界权重填为负极值，避免无效通道激活。
                                    w_val = - ( 1 << (self.bit_widths['weight']-1) )
                                line_bin += self.to_bin(w_val, self.bit_widths['weight'])
                            f.write(line_bin + "\n")
        
        # 2. 生成偏置文件。偏置按输出通道时间步读取，只需补偿 pe_col 列延迟。
        bias_filename = os.path.join(self.output_mem_dir, f"bias_layer{self.layer_num}.mem")
        with open(bias_filename, 'w') as f:
            for cout_step in range(self.cycle_period_cout):
                t = cout_step
                for c in range(self.pe_col_num):
                    # bias 与卷积核空间位置无关，因此只按输出列 c 做时间预偏移。
                    eff_t = (t - c) % self.cycle_period
                    eff_cout_step = eff_t % self.cycle_period_cout
                    current_cout_idx = c * self.cycle_period_cout + eff_cout_step
                    try:
                        b_val = self.bias[current_cout_idx]
                    except IndexError:
                        # 默认权重0，偏置为负的最小值，使得无效输出通道尽可能不激活
                        b_val = - ( 1 << (self.bit_widths['bias']-1) )
                    f.write(self.to_bin(b_val, self.bit_widths['bias']) + "\n")
        print(f"Memory files generated in {self.output_mem_dir}")

    def generate_vh_file(self):
        """生成 SystemVerilog 参数头文件 layerN.vh。

        RTL 顶层、layer.sv 和 testbench 都依赖这些参数；修改阵列规模或
        模型结构后必须重新生成。
        """
        vh_filename = os.path.join(self.output_vh_dir, f"layer{self.layer_num}.vh")
        n = self.layer_num
        
        # PE 单列输出位宽：单个乘积位宽 + 卷积核元素累加增长位宽。
        # SystemVerilog 的 $clog2 在 Python 中用 ceil(log2()) 模拟。
        pe_page_out_bw = self.bit_widths['data'] + self.bit_widths['weight'] + int(np.ceil(np.log2(self.pe_row_num)))
        # print(self.layer_num, pe_page_out_bw, int(np.ceil(np.log2(self.pe_row_num))), self.bit_widths['data'], self.bit_widths['weight'])

        # output_layer 对所有输入 page 和输入通道复用步做累加，需要额外增长位宽。
        acc_bw = self.bit_widths['data'] + self.bit_widths['weight'] + int(np.ceil(np.log2(self.pe_page_num * self.cycle_period_cin * self.pe_row_num)))

        content = f"""// =============================================================================
// File Name   : layer{n}.vh
// Description : Auto-generated configuration parameters for CNN Layer: {self.layer_name}.
// =============================================================================

`ifndef LAYER{n}_VH
`define LAYER{n}_VH
    parameter int unsigned LAYER_NUM_LAYER{n} = {n};

    // 1. 架构参数
    parameter int unsigned PE_PAGE_NUM_LAYER{n}      = {self.pe_page_num};
    parameter int unsigned PE_COL_NUM_LAYER{n}       = {self.pe_col_num};  
    parameter int unsigned PE_ROW_NUM_LAYER{n}       = {self.pe_row_num};  
    parameter int unsigned KERNEL_COL_LAYER{n}       = {self.kernel_col};
    parameter int unsigned KERNEL_ROW_LAYER{n}       = {self.kernel_row};  
    parameter int unsigned CHANNEL_OUT_NUM_LAYER{n}  = {self.cycle_period_cout*self.pe_col_num};
    parameter int unsigned CHANNEL_IN_NUM_LAYER{n}   = {self.cycle_period_cin*self.pe_page_num};  
    parameter int unsigned MAX_POOL_LAYER{n}         = {self.max_pool};
    parameter int unsigned WITH_RELU_LAYER{n}        = {self.with_relu};
    parameter int unsigned STEP_ROW_LAYER{n}         = {self.step_row};
    parameter int unsigned STEP_COL_LAYER{n}         = {self.step_col};
    parameter USE_DSP_PE_LAYER{n}                    = {'"yes"' if self.use_dsp else '"no"'};
  
    // 2. 位宽参数 (来自 MAT)  
    parameter int unsigned DATA_WIDTH_LAYER{n}       = {self.bit_widths['data']};
    parameter int unsigned WEIGHT_WIDTH_LAYER{n}     = {self.bit_widths['weight']};
    parameter int unsigned BIAS_WIDTH_LAYER{n}       = {self.bit_widths['bias']};
    parameter int unsigned OUT_WIDTH_LAYER{n}        = {self.bit_widths['out']};

    // 3. 周期与映射参数
    parameter int unsigned CYCLE_PERIOD_IN_LAYER{n}  = {self.cycle_period_cin}; 
    parameter int unsigned CYCLE_PERIOD_OUT_LAYER{n} = {self.cycle_period_cout};
    parameter int unsigned CYCLE_PERIOD_LAYER{n}     = CYCLE_PERIOD_IN_LAYER{n} * CYCLE_PERIOD_OUT_LAYER{n};
    parameter int unsigned SHIFT_KEY_LAYER{n}        = {self.shift_key};

    // 4. 图像尺寸
    parameter int unsigned IMG_COL_LAYER{n}          = {self.img_col};
    parameter int unsigned IMG_ROW_LAYER{n}          = {self.img_row};

    // 5. 自动计算的中间位宽
    parameter int unsigned PE_PAGE_OUTPUT_WIDTH_LAYER{n} = {pe_page_out_bw};
    parameter int unsigned ACC_WIDTH_LAYER{n}        = {acc_bw};

    /* Simulation Paths */
    localparam INPUT_FILE_PATH_LAYER{n}       = "{os.getcwd().replace('\\', '/')}/conv_data_hex_pds/layer{self.layer_num}_input_{self.bit_widths['data']}bit.hex";
    localparam OUTPUT_FILE_PATH_LAYER{n}      = "sim_out/layer{n}_output.hex";

`endif // LAYER{n}_VH
"""
        with open(vh_filename, 'w') as f:
            f.write(content)
        print(f"Header file generated: {vh_filename}")

    def generate_hex_files(self):
        """生成单层 testbench 使用的输入 HEX 文件。

        文件顺序为 row -> col -> channel，匹配 tb_layer/tb_lprnet 的读入方式。
        """
        input_mat = scipy.io.loadmat(self.layer_mat_file)
        input_data = input_mat["input"]
        hex_strings = []
        shape = input_data.shape
        for idr in range(shape[2]):
            for idc in range(shape[3]):
                for idx_in in range(shape[1]):
                    hex_strings.append(format(input_data[0][idx_in][idr][idc], 'x'))
                    # hex_strings.append(format((idr * 64 + idc) % 256, 'x'))
                    # hex_strings.append(format(511, 'x'))
        # 用换行符连接所有字符串，得到最终 content
        content = '\n'.join(hex_strings)
        hex_file_name = f"conv_data_hex_pds/layer{self.layer_num}_input_{self.bit_widths['data']}bit.hex"
        
        with open(hex_file_name, 'w') as f:
            f.write(content)
        print(f"HEX file generated: {hex_file_name}")

    def generate_layer(self):
        """执行单层生成全流程：读 MAT、生成输入 HEX、生成权重/偏置、生成 header。"""
        self.load_mat_data()
        self.generate_hex_files()
        self.generate_mem_files()
        self.generate_vh_file()

layer0 = CnnHardwareGenerator(
    layer_num=0,
    pe_page_num=3,
    pe_col_num=1,
    cycle_period_cin=1,
    cycle_period_cout=8,
    use_dsp=1,
    step_row=2,
    step_col=2,
    img_row=int(BASE_IMG_ROW),
    img_col=int(BASE_IMG_COL)
)

layer1 = CnnHardwareGenerator(
    layer_num=1,
    pe_page_num=layer0.pe_col_num,
    pe_col_num=4,
    cycle_period_cin=layer0.cycle_period_cout,
    cycle_period_cout=4,
    use_dsp=1,
    step_row=2,
    step_col=2,
    img_row=int(BASE_IMG_ROW/2),
    img_col=int(BASE_IMG_COL/2)
)

layer2 = CnnHardwareGenerator(
    layer_num=2,
    pe_page_num=layer1.pe_col_num,
    pe_col_num=1,
    cycle_period_cin=layer1.cycle_period_cout,
    cycle_period_cout=32,
    use_dsp=1,
    step_row=2,
    step_col=2,
    img_row=int(BASE_IMG_ROW/4),
    img_col=int(BASE_IMG_COL/4)
)

layer3 = CnnHardwareGenerator(
    layer_num=3,
    pe_page_num=layer2.pe_col_num,
    pe_col_num=4,
    cycle_period_cin=layer2.cycle_period_cout,
    cycle_period_cout=16,
    use_dsp=1,
    step_row=2,
    step_col=2,
    img_row=int(BASE_IMG_ROW/8),
    img_col=int(BASE_IMG_COL/8)
)

layer4 = CnnHardwareGenerator(
    layer_num=4,
    pe_page_num=layer3.pe_col_num,
    pe_col_num=2,
    cycle_period_cin=layer3.cycle_period_cout,
    cycle_period_cout=32,
    use_dsp=1,
    img_row=int(BASE_IMG_ROW/16),
    img_col=int(BASE_IMG_COL/16)
)

layer5 = CnnHardwareGenerator(
    layer_num=5,
    pe_page_num=layer4.pe_col_num,
    pe_col_num=2,
    cycle_period_cin=layer4.cycle_period_cout,
    cycle_period_cout=16,
    use_dsp=0,
    img_row=int(BASE_IMG_ROW/16),
    img_col=int(BASE_IMG_COL/16)
)

layer6 = CnnHardwareGenerator(
    layer_num=6,
    pe_page_num=layer5.pe_col_num,
    pe_col_num=1,
    cycle_period_cin=layer5.cycle_period_cout,
    cycle_period_cout=32,
    use_dsp=0,
    img_row=int(BASE_IMG_ROW/16),
    img_col=int(BASE_IMG_COL/16)
)

layer7 = CnnHardwareGenerator(
    layer_num=7,
    pe_page_num=layer6.pe_col_num,
    pe_col_num=1,
    cycle_period_cin=layer6.cycle_period_cout,
    cycle_period_cout=16,
    kernel_row=1,  # 1*1卷积
    kernel_col=1,  # 1*1卷积
    use_dsp=0,
    bit_width_out=9,
    with_relu=0, 
    img_row=int(BASE_IMG_ROW/16),
    img_col=int(BASE_IMG_COL/16)
)

layer8 = CnnHardwareGenerator(
    layer_num=8,
    pe_page_num=layer4.pe_col_num,
    pe_col_num=2,
    cycle_period_cin=layer4.cycle_period_cout,
    cycle_period_cout=16,
    use_dsp=0,
    img_row=int(BASE_IMG_ROW/16),
    img_col=int(BASE_IMG_COL/16)
)

layer9 = CnnHardwareGenerator(
    layer_num=9,
    pe_page_num=layer8.pe_col_num,
    pe_col_num=1,
    cycle_period_cin=layer8.cycle_period_cout,
    cycle_period_cout=32,
    use_dsp=0,
    img_row=int(BASE_IMG_ROW/16),
    img_col=int(BASE_IMG_COL/16)
)

layer10 = CnnHardwareGenerator(
    layer_num=10,
    pe_page_num=layer9.pe_col_num,
    pe_col_num=1,
    cycle_period_cin=layer9.cycle_period_cout,
    cycle_period_cout=16,
    kernel_row=1,  # 1*1卷积
    kernel_col=1,  # 1*1卷积
    use_dsp=0,
    with_relu=0, 
    bit_width_out=9,
    img_row=int(BASE_IMG_ROW/16),
    img_col=int(BASE_IMG_COL/16)
)

# 从 layer20 开始是 lprnetv10 的层结构，复用原 LPRNet 编号段
layer20 = CnnHardwareGenerator(
    mat_file_dir="conv_data_lprnetv10",
    layer_num=20,
    pe_page_num=3,
    pe_col_num=1,
    cycle_period_cin=1,
    cycle_period_cout=8,
    bit_width_out=9,
    step_row=1,
    step_col=1,
    img_row=int(BASE_IMG_ROW_LPERNET),
    img_col=int(BASE_IMG_COL_LPERNET)
)

layer21 = CnnHardwareGenerator(
    mat_file_dir="conv_data_lprnetv10",
    layer_num=21,
    pe_page_num=layer20.pe_col_num,
    pe_col_num=2,
    cycle_period_cin=layer20.cycle_period_cout,
    cycle_period_cout=8,
    bit_width_data=9,
    bit_width_out=9,
    step_row=1,
    step_col=1,
    img_row=int(BASE_IMG_ROW_LPERNET),
    img_col=int(BASE_IMG_COL_LPERNET)
)

layer22 = CnnHardwareGenerator(
    mat_file_dir="conv_data_lprnetv10",
    layer_num=22,
    pe_page_num=layer21.pe_col_num,
    pe_col_num=layer21.pe_col_num,
    cycle_period_cin=layer21.cycle_period_cout,
    cycle_period_cout=layer21.cycle_period_cout,
    bit_width_data=9,
    bit_width_out=9,
    max_pool=1,
    with_relu=0,
    step_row=1,
    step_col=1,
    img_row=int(BASE_IMG_ROW_LPERNET),
    img_col=int(BASE_IMG_COL_LPERNET)
)

layer23 = CnnHardwareGenerator(
    mat_file_dir="conv_data_lprnetv10",
    layer_num=23,
    pe_page_num=layer22.pe_col_num,
    pe_col_num=2,
    cycle_period_cin=layer22.cycle_period_cin,
    cycle_period_cout=8,
    bit_width_data=9,
    bit_width_out=9,
    step_row=1,
    step_col=1,
    img_row=int(BASE_IMG_ROW_LPERNET),
    img_col=int(BASE_IMG_COL_LPERNET)
)

layer24 = CnnHardwareGenerator(
    mat_file_dir="conv_data_lprnetv10",
    layer_num=24,
    pe_page_num=layer23.pe_col_num,
    pe_col_num=2,
    cycle_period_cin=layer23.cycle_period_cout,
    cycle_period_cout=16,
    bit_width_data=9,
    bit_width_out=9,
    step_row=1,
    step_col=1,
    img_row=int(BASE_IMG_ROW_LPERNET),
    img_col=int(BASE_IMG_COL_LPERNET)
)

layer25 = CnnHardwareGenerator(
    mat_file_dir="conv_data_lprnetv10",
    layer_num=25,
    pe_page_num=layer24.pe_col_num,
    pe_col_num=layer24.pe_col_num,
    cycle_period_cin=layer24.cycle_period_cout,
    cycle_period_cout=layer24.cycle_period_cout,
    bit_width_data=9,
    bit_width_out=9,
    max_pool=1,
    with_relu=0,
    step_row=2,
    step_col=2,
    img_row=int(BASE_IMG_ROW_LPERNET),
    img_col=int(BASE_IMG_COL_LPERNET)
)

layer26 = CnnHardwareGenerator(
    mat_file_dir="conv_data_lprnetv10",
    layer_num=26,
    pe_page_num=layer25.pe_col_num,
    pe_col_num=2,
    cycle_period_cin=layer25.cycle_period_cin,
    cycle_period_cout=16,
    bit_width_data=9,
    bit_width_out=9,
    step_row=1,
    step_col=1,
    img_row=int(BASE_IMG_ROW_LPERNET/2),
    img_col=int(BASE_IMG_COL_LPERNET/2)
)

layer27 = CnnHardwareGenerator(
    mat_file_dir="conv_data_lprnetv10",
    layer_num=27,
    pe_page_num=layer26.pe_col_num,
    pe_col_num=2,
    cycle_period_cin=layer26.cycle_period_cout,
    cycle_period_cout=32,
    bit_width_data=9,
    bit_width_out=9,
    kernel_col=3,
    kernel_row=3,
    step_row=1,
    step_col=1,
    img_row=int(BASE_IMG_ROW_LPERNET/2),
    img_col=int(BASE_IMG_COL_LPERNET/2)
)

layer28 = CnnHardwareGenerator(
    mat_file_dir="conv_data_lprnetv10",
    layer_num=28,
    pe_page_num=layer27.pe_col_num,
    pe_col_num=layer27.pe_col_num,
    cycle_period_cin=layer27.cycle_period_cout,
    cycle_period_cout=layer27.cycle_period_cout,
    bit_width_data=9,
    bit_width_out=9,
    max_pool=1,
    with_relu=0,
    step_row=2,
    step_col=2,
    img_row=int(BASE_IMG_ROW_LPERNET/2),
    img_col=int(BASE_IMG_COL_LPERNET/2)
)

layer29 = CnnHardwareGenerator(
    mat_file_dir="conv_data_lprnetv10",
    layer_num=29,
    pe_page_num=layer28.pe_col_num,
    pe_col_num=4,
    cycle_period_cin=layer28.cycle_period_cin,
    cycle_period_cout=32,
    bit_width_data=9,
    bit_width_out=9,
    step_row=1,
    step_col=1,
    img_row=int(BASE_IMG_ROW_LPERNET/4),
    img_col=int(BASE_IMG_COL_LPERNET/4)
)

layer30 = CnnHardwareGenerator(
    mat_file_dir="conv_data_lprnetv10",
    layer_num=30,
    pe_page_num=layer29.pe_col_num,
    pe_col_num=2,
    cycle_period_cin=layer29.cycle_period_cout,
    cycle_period_cout=64,
    bit_width_data=9,
    bit_width_out=9,
    kernel_col=3,
    kernel_row=1,
    step_row=1,
    step_col=1,
    img_row=int(BASE_IMG_ROW_LPERNET/4),
    img_col=int(BASE_IMG_COL_LPERNET/4)
)

layer31 = CnnHardwareGenerator(
    mat_file_dir="conv_data_lprnetv10",
    layer_num=31,
    pe_page_num=layer30.pe_col_num,
    pe_col_num=4,
    cycle_period_cin=layer30.cycle_period_cout,
    cycle_period_cout=32,
    bit_width_data=9,
    bit_width_out=10,
    with_relu=0,
    kernel_col=1,
    kernel_row=1,
    step_row=1,
    step_col=1,
    img_row=int(BASE_IMG_ROW_LPERNET/4),
    img_col=int(BASE_IMG_COL_LPERNET/4)
)

all_layers = [layer0, layer1, layer2, layer3, layer4, layer5, layer6, layer7, layer8, layer9, layer10, \
    layer20, layer21, layer22, layer23, layer24, layer25, layer26, layer27, layer28, layer29, layer30, layer31]

# ================= 使用示例 =================
if __name__ == "__main__":
    # 实例化 Layer n 的生成器
    for layer in all_layers:
        layer.generate_layer()
