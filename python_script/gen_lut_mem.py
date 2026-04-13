import numpy as np
import os
import math

# ==============================================================================
# 导入 CnnHardwareGenerator 及配置实例
# (假设上面的类定义保存在 cnn_config_gen.py 中，如果不是，请将类定义直接粘贴在此处)
# ==============================================================================
try:
    from CnnHardwareGenerator import layer11 # 替换为实际文件名
except ImportError:
    print("Error: Could not import gen_layer11. Please ensure the configuration file is accessible.")
    # 为了演示，如果导入失败，这里使用硬编码的模拟对象
    class MockLayer:
        def __init__(self):
            self.bit_widths = {'out': 16} # 假设 layer11 输出为 16bit (作为 LUT 输入)
            self.shift_key = 0            # 假设小数位为 8bit
            self.output_mem_dir = "mem_data"
            self.layer_num = 11
    layer11 = MockLayer()
    print("Using Mock Layer Configuration for demonstration.")
# ==============================================================================
# 配置参数
# ==============================================================================
TARGET_LAYER = layer11
TARGET_LAYER.load_mat_data()
# 最终的激活函数须先*0.5再算
layer11.shift_key = 1
INPUT_WIDTH  = TARGET_LAYER.bit_widths['out']  # Layer33 的输出即为 LUT 的输入
OUTPUT_WIDTH = 8                               # LUT 输出位宽 (置信度，通常 8bit)
OUTPUT_DIR   = TARGET_LAYER.output_mem_dir

# 文件名
FILENAME = f"sigmoid_lut_{INPUT_WIDTH}bit_to_{OUTPUT_WIDTH}bit_h.mem"
FILEPATH = os.path.join(OUTPUT_DIR, FILENAME)

# ==============================================================================
# 核心转换函数
# ==============================================================================
def sigmoid(x):
    # 防止溢出
    if x > 20: return 1.0
    if x < -20: return 0.0
    return 1 / (1 + math.exp(-x))

def generate_lut():
    print(f"Generating Sigmoid LUT for Layer {TARGET_LAYER.layer_num}...")
    print(f"  Input Width:  {INPUT_WIDTH} bits")
    print(f"  Output Width: {OUTPUT_WIDTH} bits")
    print(f"  Shift Key:    {TARGET_LAYER.shift_key} (Fractional bits)")
    print(f"  Output File:  {FILEPATH}")

    # 计算地址空间大小
    num_entries = 1 << INPUT_WIDTH
    
    # 比例因子：将定点数转换为浮点数
    scale_factor = 1.0 / (1 << TARGET_LAYER.shift_key)
    
    # 输出最大值 (用于量化)
    max_out_val = (1 << OUTPUT_WIDTH) - 1

    with open(FILEPATH, 'w') as f:
        # 遍历所有可能的 16-bit 地址值 (0 ~ 65535)
        # 这些地址代表了补码形式的有符号输入
        for addr in range(num_entries):
            
            # 1. 将地址解释为有符号整数 (补码 -> 原码值)
            if addr < (1 << (INPUT_WIDTH - 1)):
                # 正数部分: 0 ~ 2^(N-1)-1
                signed_int = addr
            else:
                # 负数部分: -2^(N-1) ~ -1
                # 补码转数值：val = addr - 2^N
                signed_int = addr - (1 << INPUT_WIDTH)
            # 2. 定点数转浮点实数
            real_val = signed_int * scale_factor
            
            # 3. 计算 Sigmoid
            sig_val = sigmoid(real_val)
            
            # if (addr>=8190):
            #     print(signed_int, real_val, sig_val)
            # 4. 量化为输出整数 (0 ~ 255)
            # 使用 round 四舍五入
            quantized_val = int(round(sig_val * max_out_val))
            
            # 边界保护 (理论上 sigmoid 结果在 [0,1] 不会越界，但在定点运算中加上保护是个好习惯)
            if quantized_val < 0: quantized_val = 0
            if quantized_val > max_out_val: quantized_val = max_out_val
            
            # 5. 格式化为 16 进制字符串
            # hex_str = f"{quantized_val:0{math.ceil(OUTPUT_WIDTH/4)}x}" # 自动计算 hex 位宽
            # 这里固定 2 位 hex (对应 8bit)
            hex_str = f"{quantized_val:02x}"
            
            f.write(hex_str + "\n")
            
    print("Done.")

if __name__ == "__main__":
    # 确保输出目录存在
    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)
        
    generate_lut()