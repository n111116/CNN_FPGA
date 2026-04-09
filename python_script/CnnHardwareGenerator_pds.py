import scipy.io
import numpy as np
import os
# 1080P
# BASE_IMG_COL = 1920
# BASE_IMG_ROW = 1080
# 720P
BASE_IMG_COL = 1280
BASE_IMG_ROW = 720
# 800P
# BASE_IMG_COL = 1600
# BASE_IMG_ROW = 800
# BASE_IMG_COL = 640
# BASE_IMG_ROW = 640

BASE_IMG_COL_LPERNET = 80
BASE_IMG_ROW_LPERNET = 20

# 变量的定义
# layer_num: 当前层编号
# pe_page_num: PE 页数 (输入通道分组数)（与上一层的 pe_col_num 相同以匹配线数）
# pe_col_num: PE 列数 (输出通道分组数)
# pe_row_num: PE 行数 (卷积核元素数，通常为 3x3=9)
# img_row, img_col: 输入图像的行数和列数 (根据层级逐渐减小)
# max_pool: 是否是max_pool层
# with_relu_shift: 是否包含 ReLU 和 shift 操作，影响输出位宽和数据处理
# STEP_ROW, STEP_COL: 输入数据的步长 (卷积步长)，决定了输入数据的访问模式，也影响输出特征图的尺寸

# ** cycle_period 是针对层内部的 ** 
# ** 对输入数据，每 cycle_period_out / STEP_COL / STEP / ROW 个周期应输入一个数据
# 每 cycle_period / STEP_COL / STEP / ROW 个周期应输入一个像素
# cycle_period_out: 输出通道的周期 (每个PE列的输出通道数 = cycle_period_out)(内部单个 data 的保持时长)
# cycle_period_in: 输入通道的周期 (每个PE列的输入通道数 = cycle_period_in)
# cycle_period = cycle_period_in * cycle_period_out (每多少个时钟周期权重的访问模式重复一次，一个像素需要处理的周期数)
# 每个PE列每 16 个输出通道重复一次，每 4 个输入通道重复一次。

# 数量关系
# 某一层的 cycle_period_out 等于下一层的 cycle_period_in，以保证数据流的连续性和匹配。
# cycle_period * img_row * img_col / (STEP_ROW * STEP_COL) 是每层处理一帧图像的总周期数，决定了处理速度和吞吐量。
# 每一层的一帧图像的总周期数要完全匹配。
# 特殊情况：如果特定情况下不容易匹配，如第一层的计算量远小于其他层，可以让第一层的行间隔拉大，使得以行为单位的计算周期数匹配。
# 例如：layer1: cycle_period=16, img_row=128, img_col=128, step_row=2, step_col=2，则每帧图像的周期数为 65536 周期。
# layer2: cycle_period=64, img_row=64, img_col=64, step_row=2, step_col=2，则每帧图像的周期数也是 65536 周期。

# 某一层的 PE 列数等于下一层的 PE 页数，以保证权重和数据的匹配。
# 某一层的输出通道数＝PE列数 * cycle_period_out ，输入通道数＝PE页数 * cycle_period_in。


class CnnHardwareGenerator:
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
                 mat_file_dir="conv_data_yolov3"):
        """
        初始化硬件配置生成类
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
        # 默认有 relu，除第8、11层无 relu
        self.with_relu = with_relu # 1 if layer_num not in [8, 11] else 0
        # 默认上一层层号为该层 -1 ，除了第 9 层。 第 9 层的上一层与第 6 层的上一层同为 5.
        self.prev_layer_num = layer_num - 1 if layer_num != 9 else 5

        # 路径设置，对yolov3
        if(self.layer_num == 0):
            self.layer_name = "node_conv2d"
            self.relu_name = "node_relu"
        else:
            self.layer_name = f"node_conv2d_{self.layer_num}"
            if(self.layer_num == 8 or self.layer_num == 11):
                self.relu_name = None
            else:
                if(self.layer_num <= 7):
                    self.relu_name = f"node_relu_{self.layer_num}"
                else:
                    self.relu_name = f"node_relu_{self.layer_num - 1}"
        # 针对 lprnetv8 的结构
        if(self.layer_num == 20):
            self.layer_name = "node_conv2d"
            self.relu_name = "node_relu"
        elif(self.layer_num == 21):
            self.layer_name = f"node_max_pool2d"
            self.relu_name = None
        elif(self.layer_num == 22):
            self.layer_name = f"node_conv2d_1"
            self.relu_name = "node_relu_1"
        elif(self.layer_num == 23):
            self.layer_name = f"node_max_pool2d_1"
            self.relu_name = None
        elif(self.layer_num == 24):
            self.layer_name = f"node_conv2d_2"
            self.relu_name = "node_relu_2"
        elif(self.layer_num == 25):
            self.layer_name = f"node_max_pool2d_2"
            self.relu_name = None
        elif(self.layer_num == 26):
            self.layer_name = f"node_conv2d_3"
            self.relu_name = "node_relu_3"
        elif(self.layer_num == 27):
            self.layer_name = f"node_conv2d_4"
            self.relu_name = "node_relu_4"
        elif(self.layer_num == 28):
            self.layer_name = f"node_conv2d_5"
            self.relu_name = None
        
        self.layer_mat_file = mat_file_dir + f"/{self.layer_name}.mat"
        self.relu_mat_file = mat_file_dir + f"/{self.relu_name}.mat"
        print(f"for layer_num:{self.layer_num} reading: layer_mat_file={self.layer_mat_file}, relu_mat_file={self.relu_mat_file}")


        # 自动创建目录
        for d in [self.output_mem_dir, self.output_vh_dir]:
            if not os.path.exists(d):
                os.makedirs(d)

        # self.load_mat_data()
    def to_bin(self, val, width):
        """将数值转换为补码形式的二进制字符串"""
        val = int(val)
        if val < 0:
            val = (1 << width) + val
        val = val & ((1 << width) - 1)
        return f"{val:0{width}b}"

    def load_mat_data(self):
        """从 MAT 文件加载权重、偏置及位宽参数"""
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
                #  所有的位宽中，data位宽恒为8，weight位宽恒为9，bias位宽是self.bias的最大绝对值（正值须加1）的二进制位宽 + 1（符号位）。
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

            
            # 读取 shift_key 并取绝对值
            self.shift_key = abs(int(mat_data['shift_k'].item()))
            
            print(f"Parameters Loaded: BW={self.bit_widths}, Shift={self.shift_key}")
        except Exception as e:
            print(f"Error loading MAT file: {e}")
            raise

    def generate_mem_files(self):
        """生成权重和偏置的 .mem 文件"""
        # 1. 生成权重文件 (Per Page)
        for p in range(self.pe_page_num):
            filename = os.path.join(self.output_mem_dir, f"weight_layer{self.layer_num}_page{p}.mem")
            with open(filename, 'w') as f:
                for cin_step in range(self.cycle_period_cin):
                    for cout_step in range(self.cycle_period_cout):
                        t = cin_step * self.cycle_period_cout + cout_step
                        for c in range(self.pe_col_num):
                            line_bin = ""
                            for r in range(self.pe_row_num - 1, -1, -1):
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
                                    # print(f"indexError:[current_cout_idx:{current_cout_idx}][current_cin_idx{current_cin_idx}][mat_col_idx{mat_col_idx}][mat_row_idx{mat_row_idx}]")
                                    # 默认权重与偏置为负的最小值，使得无效输出通道尽可能不激活
                                    w_val = - ( 1 << (self.bit_widths['weight']-1) )
                                line_bin += self.to_bin(w_val, self.bit_widths['weight'])
                            f.write(line_bin + "\n")
        
        # 2. 生成偏置文件
        bias_filename = os.path.join(self.output_mem_dir, f"bias_layer{self.layer_num}.mem")
        with open(bias_filename, 'w') as f:
            for cout_step in range(self.cycle_period_cout):
                t = cout_step
                for c in range(self.pe_col_num):
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
        """生成 SystemVerilog 参数头文件 .vh"""
        vh_filename = os.path.join(self.output_vh_dir, f"layer{self.layer_num}.vh")
        n = self.layer_num
        
        # 预计算一些内部逻辑位宽 (参考 layer1.vh 公式)
        # $clog2 在 Python 中用 np.ceil(np.log2()) 模拟
        pe_page_out_bw = self.bit_widths['data'] + self.bit_widths['weight'] + int(np.ceil(np.log2(self.pe_row_num)))
        # print(self.layer_num, pe_page_out_bw, int(np.ceil(np.log2(self.pe_row_num))), self.bit_widths['data'], self.bit_widths['weight'])

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
    localparam INPUT_FILE_PATH_LAYER{n}       = "{os.getcwd().replace('\\', '/')}/conv_data_hex/layer{self.layer_num}_input_{self.bit_widths['data']}bit.hex";
    localparam OUTPUT_FILE_PATH_LAYER{n}      = "sim_out/layer{n}_output.hex";

`endif // LAYER{n}_VH
"""
        with open(vh_filename, 'w') as f:
            f.write(content)
        print(f"Header file generated: {vh_filename}")

    def generate_hex_files(self):
        """生成 HEX 文件"""
        # 生成路径为 conv_data_hex/{self.layer_name}_input_{self.bit_widths['data']}bit.hex 的hex文件
        # 将layer_mat_file的 "input" 字段转化为 hex 形式
        input_mat = scipy.io.loadmat(self.layer_mat_file)
        input_data = input_mat["input"]
        # 使用 for 循环遍历所有元素，构建十六进制字符串列表
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
        hex_file_name = f"conv_data_hex/layer{self.layer_num}_input_{self.bit_widths['data']}bit.hex"
        
        with open(hex_file_name, 'w') as f:
            f.write(content)
        print(f"HEX file generated: {hex_file_name}")

    def generate_layer(self):
        """执行全流程"""
        self.load_mat_data()
        self.generate_hex_files()
        self.generate_mem_files()
        self.generate_vh_file()

layer0 = CnnHardwareGenerator(
    layer_num=0,
    pe_page_num=3,
    pe_col_num=2,
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
    pe_col_num=2,
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
    pe_col_num=4,
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
    pe_col_num=2,
    cycle_period_cin=layer6.cycle_period_cout,
    cycle_period_cout=16,
    use_dsp=0,
    img_row=int(BASE_IMG_ROW/16),
    img_col=int(BASE_IMG_COL/16)
)

layer8 = CnnHardwareGenerator(
    layer_num=8,
    pe_page_num=layer7.pe_col_num,
    pe_col_num=1,
    cycle_period_cin=layer7.cycle_period_cout,
    cycle_period_cout=32,
    kernel_row=1,  # 1*1卷积
    kernel_col=1,  # 1*1卷积
    use_dsp=0,
    bit_width_out=9,
    with_relu=0, 
    img_row=int(BASE_IMG_ROW/16),
    img_col=int(BASE_IMG_COL/16)
)

layer9 = CnnHardwareGenerator(
    layer_num=9,
    pe_page_num=layer5.pe_col_num,
    pe_col_num=1,
    cycle_period_cin=layer5.cycle_period_cout,
    cycle_period_cout=32,
    use_dsp=0,
    img_row=int(BASE_IMG_ROW/16),
    img_col=int(BASE_IMG_COL/16)
)

layer10 = CnnHardwareGenerator(
    layer_num=10,
    pe_page_num=layer9.pe_col_num,
    pe_col_num=2,
    cycle_period_cin=layer9.cycle_period_cout,
    cycle_period_cout=16,
    use_dsp=0,
    img_row=int(BASE_IMG_ROW/16),
    img_col=int(BASE_IMG_COL/16)
)

layer11 = CnnHardwareGenerator(
    layer_num=11,
    pe_page_num=layer10.pe_col_num,
    pe_col_num=1,
    cycle_period_cin=layer10.cycle_period_cout,
    cycle_period_cout=32,
    kernel_row=1,  # 1*1卷积
    kernel_col=1,  # 1*1卷积
    use_dsp=0,
    with_relu=0, 
    bit_width_out=9,
    img_row=int(BASE_IMG_ROW/16),
    img_col=int(BASE_IMG_COL/16)
)
# 从 layer20 开始是 lpernetv8 的层结构
layer20 = CnnHardwareGenerator(
    mat_file_dir="conv_data_lprnetv8",
    layer_num=20,
    pe_page_num=3,
    pe_col_num=1,
    cycle_period_cin=1,
    cycle_period_cout=16,
    bit_width_out=9,
    img_row=int(BASE_IMG_ROW_LPERNET),
    img_col=int(BASE_IMG_COL_LPERNET)
)
layer21 = CnnHardwareGenerator(
    mat_file_dir="conv_data_lprnetv8",
    layer_num=21,
    pe_page_num=layer20.pe_col_num,
    pe_col_num=1,
    cycle_period_cin=layer20.cycle_period_cout,
    cycle_period_cout=layer20.cycle_period_cin,
    bit_width_data=9,
    bit_width_out=9,
    max_pool=1,
    with_relu=0,
    img_row=int(BASE_IMG_ROW_LPERNET),
    img_col=int(BASE_IMG_COL_LPERNET)
)
# 特殊情况，第20层和第21层的速度远快于第22层，我们增加第20层的行间隙并在22层输入前进行解耦
layer22 = CnnHardwareGenerator(
    mat_file_dir="conv_data_lprnetv8",
    layer_num=22,
    pe_page_num=layer21.pe_col_num,
    pe_col_num=1,
    cycle_period_cin=16,
    cycle_period_cout=32,
    bit_width_data=9,
    bit_width_out=9,
    step_row=1,
    step_col=2,
    img_row=int(BASE_IMG_ROW_LPERNET),
    img_col=int(BASE_IMG_COL_LPERNET)
)
layer23 = CnnHardwareGenerator(
    mat_file_dir="conv_data_lprnetv8",
    layer_num=23,
    pe_page_num=layer22.pe_col_num,
    pe_col_num=1,
    cycle_period_cin=layer22.cycle_period_cout,
    cycle_period_cout=layer22.cycle_period_cin*2,
    bit_width_data=9,
    bit_width_out=9,
    max_pool=1,
    with_relu=0,
    step_row=2,
    step_col=1,
    img_row=int(BASE_IMG_ROW_LPERNET),
    img_col=int(BASE_IMG_COL_LPERNET/2)
)
layer24 = CnnHardwareGenerator(
    mat_file_dir="conv_data_lprnetv8",
    layer_num=24,
    pe_page_num=layer23.pe_col_num,
    pe_col_num=1,
    cycle_period_cin=layer23.cycle_period_cout,
    cycle_period_cout=64,
    bit_width_data=9,
    bit_width_out=9,
    step_row=1,
    step_col=2,
    img_row=int(BASE_IMG_ROW_LPERNET/2),
    img_col=int(BASE_IMG_COL_LPERNET/2)
)
layer25 = CnnHardwareGenerator(
    mat_file_dir="conv_data_lprnetv8",
    layer_num=25,
    pe_page_num=layer24.pe_col_num,
    pe_col_num=1,
    cycle_period_cin=layer24.cycle_period_cout,
    cycle_period_cout=layer24.cycle_period_cin*2,
    bit_width_data=9,
    bit_width_out=9,
    max_pool=1,
    with_relu=0,
    step_row=2,
    step_col=1,
    img_row=int(BASE_IMG_ROW_LPERNET/2),
    img_col=int(BASE_IMG_COL_LPERNET/4)
)

layer26 = CnnHardwareGenerator(
    mat_file_dir="conv_data_lprnetv8",
    layer_num=26,
    pe_page_num=layer25.pe_col_num,
    pe_col_num=2,
    cycle_period_cin=layer25.cycle_period_cout,
    cycle_period_cout=64,
    bit_width_data=9,
    bit_width_out=9,
    step_row=1,
    step_col=1,
    img_row=int(BASE_IMG_ROW_LPERNET/4),
    img_col=int(BASE_IMG_COL_LPERNET/4)
)

layer27 = CnnHardwareGenerator(
    mat_file_dir="conv_data_lprnetv8",
    layer_num=27,
    pe_page_num=layer26.pe_col_num,
    pe_col_num=2,
    cycle_period_cin=layer26.cycle_period_cout,
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
layer28 = CnnHardwareGenerator(
    mat_file_dir="conv_data_lprnetv8",
    layer_num=28,
    pe_page_num=layer26.pe_col_num,
    pe_col_num=2,
    cycle_period_cin=layer25.cycle_period_cout,
    cycle_period_cout=64,
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

all_layers = [layer0, layer1, layer2, layer3, layer4, layer5, layer6, layer7, layer8, layer9, layer10, layer11, \
              layer20, layer21, layer22, layer23, layer24, layer25, layer26, layer27, layer28]

# ================= 使用示例 =================
if __name__ == "__main__":
    # 实例化 Layer n 的生成器
    for layer in all_layers:
        layer.generate_layer()