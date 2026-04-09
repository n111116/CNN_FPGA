import os
import scipy.io

# 这里选择要验证的仿真层
from CnnHardwareGenerator import layer6 as layer_to_test
# ================= 配置参数 =================
layer_to_test.load_mat_data()
# 1. 原始参考数据
if(layer_to_test.with_relu == 1):
    REF_FILE_PATH = layer_to_test.relu_mat_file
else:
    REF_FILE_PATH = layer_to_test.layer_mat_file

# REF_FILE_PATH = layer_to_test.layer_mat_file

# 2. ModelSim/USB 仿真输出数据 指定文件夹路径
# # 获取usb_data文件夹中最新的 .hex 文件
# folder_path = "usb_data"
# file_pattern = os.path.join(folder_path, "*.hex")
# files = glob.glob(file_pattern)
# 
# if files:
#     latest_file = max(files, key=os.path.getmtime)
#     SIM_FILE_PATH = latest_file
#     print(f"Found latest file: {SIM_FILE_PATH}")
# else:
#     SIM_FILE_PATH = None
#     print("Error: No hex files found in folder.")

SIM_FILE_PATH = f"sim_pds/sim_modelsim/sim_out/layer{layer_to_test.layer_num}_output.hex"

# 3. 硬件参数
IMG_ROW = layer_to_test.img_row // layer_to_test.step_row
IMG_COL = layer_to_test.img_col // layer_to_test.step_col

CHANNELS = layer_to_test.cycle_period_cout*layer_to_test.pe_col_num     # 总输出通道数
if layer_to_test.layer_num == 33:
    CHANNELS = 40
PE_COL_NUM = layer_to_test.pe_col_num                                   # 硬件 PE 列数 (并行度)
CYCLE_PERIOD_OUT = layer_to_test.cycle_period_cout                      # 输出复用周期
CYCLE_PERIOD_IN = layer_to_test.cycle_period_cin 
STEP_ROW = layer_to_test.step_row
STEP_COL = layer_to_test.step_col
# 4. 后处理参数
SHIFT_KEY = layer_to_test.shift_key
OUT_WIDTH = layer_to_test.bit_widths['out']
WITH_RELU = layer_to_test.with_relu
MAX_POOL = layer_to_test.max_pool
# ================= 自动模式检测 =================
if SIM_FILE_PATH:
    ENABLE_POST_PROCESS = "output" in os.path.basename(REF_FILE_PATH).lower()
    print(f"Reference File: '{os.path.basename(REF_FILE_PATH)}'")
    if ENABLE_POST_PROCESS:
        print("   -> Mode: OUTPUT (Applying Shift + ReLU + Clamp)")
    else:
        print("   -> Mode: INPUT (Direct Comparison)")

def load_ref_data(filepath):
    # data = []
    # if not os.path.exists(filepath):
    #     print(f"Error: Reference file not found: {filepath}")
    #     return None
    # with open(filepath, 'r') as f:
    #     for line_idx, line in enumerate(f):
    #         line = line.strip()
    #         if not line: continue
    #         try:
    #             val = int(line, 16)
    #             data.append(val)
    #         except ValueError:
    #             print(f"Warning: Invalid hex at line {line_idx+1}: {line}")
    data = scipy.io.loadmat(REF_FILE_PATH)
    return data["output"]

def load_sim_data(filepath):
    data = []
    if not os.path.exists(filepath):
        print(f"Error: Simulation file not found: {filepath}")
        return None
    with open(filepath, 'r') as f:
        for line in f:
            line = line.strip()
            if not line: continue
            parts = line.split()
            row_vals = [int(p, 16) for p in parts]
            data.append(row_vals)
    return data

def hardware_process(val, shift, bit_width):
    if WITH_RELU == 0:
        return val
    if shift > 0:
        # 四舍五入右移
        offset = 1 << (shift - 1)  # 用于四舍五入的偏移量
        # 判断是否需要向上取整
        if val >= 0:
            shifted = (val + offset) // (1 << shift)
        else:
            # 负数时的四舍五入处理
            shifted = (val - offset + 1) // (1 << shift)
    else:
        shifted = val
    
    if shifted < 0:
        out_val = 0
    else:
        out_val = shifted
        
    max_val = (1 << bit_width) - 1
    if out_val > max_val:
        final_val = max_val
    else:
        final_val = out_val
    return final_val

def compare_data():
    if SIM_FILE_PATH is None: return

    print("Loading data...")
    ref_raw = load_ref_data(REF_FILE_PATH)
    sim_rows = load_sim_data(SIM_FILE_PATH)

    if ref_raw is None or sim_rows is None: return
    
    if len(sim_rows) < 2:
        print(f"Error: Not enough data in Sim file ({len(sim_rows)} lines).")
        return

    # 计算一帧数据在 Sim 文件中占多少行
    # 一行 Sim 数据包含 PE_COL_NUM 个数据点
    # 每一帧的总行数 = (行 * 列 * 输出周期)
    # 注意：这里的逻辑是基于 TB 生成逻辑：循环 r -> c -> t，每次 t 输出一行(包含PE个数据)
    exp_lines_per_frame = IMG_ROW * IMG_COL * CYCLE_PERIOD_OUT
    
    
    print(f"Sim data total lines: {len(sim_rows)}")
    print(f"Exp lines per frame:  {exp_lines_per_frame}")


    print("Starting comparison...")
    
    # 错误统计容器
    error_log = [] # 存储字典 {'frame':, 'r':, 'c':, 'ch':, 'exp':, 'act':, 'diff':}
    total_checks = 0
    
    sim_line_idx = 0
    frame_idx = 0
    
    # ================= 多帧循环 =================
    while sim_line_idx < len(sim_rows):
        print(f"Checking Frame {frame_idx} (Start Line: {sim_line_idx})...")
        
        # 标记当前帧是否有数据不足的情况
        frame_incomplete = False
        
        # 单帧遍历
        for r in range(0, IMG_ROW):
            for c in range(0, IMG_COL):
                RANGE_T = CYCLE_PERIOD_OUT if MAX_POOL != 1 else CYCLE_PERIOD_IN
                for t in range(RANGE_T):
                    
                    # 检查仿真数据是否耗尽
                    if sim_line_idx >= len(sim_rows):
                        frame_incomplete = True
                        break
                    
                    sim_vals = sim_rows[sim_line_idx]
                    sim_line_idx += 1

                    # 遍历 所有 个 PE
                    for pe_idx in range(PE_COL_NUM):
                        channel_idx = pe_idx * CYCLE_PERIOD_OUT + t
                        # ref_flat_idx = (r * IMG_COL + c) * CHANNELS + channel_idx
                        # layer8实际上只有4个输出通道
                        if layer_to_test.layer_num == 8 and channel_idx >= 4:
                            pass
                        # layer11实际上只有5个输出通道
                        elif layer_to_test.layer_num == 11 and channel_idx >= 5:
                            pass
                            # print(channel_idx)
                        # layer28实际上只有76个输出通道
                        elif layer_to_test.layer_num == 28 and channel_idx >= 76:
                            pass
                            # print(channel_idx)
                        else:
                            # 获取参考值 (Input 模式直接取, Output 模式做处理)
                            expected_val = ref_raw[0][channel_idx][r][c]
                            if(expected_val < 0 and WITH_RELU):
                                expected_val = 0
                            try:
                                # 获取仿真值
                                if WITH_RELU == 0 and MAX_POOL == 0:
                                    if sim_vals[pe_idx] & (1 << (OUT_WIDTH - 1)):  # 负值
                                        actual_val = sim_vals[pe_idx] - (1 << (OUT_WIDTH))
                                    else:
                                        actual_val = sim_vals[pe_idx]
                                else:
                                    actual_val = sim_vals[pe_idx]
                            except IndexError:
                                print(f"IndexError:'frame': {frame_idx},'r': {r}, 'c': {c}, 'ch': {channel_idx},'exp': {expected_val}")
                                continue
                            
                            # 比对
                            total_checks += 1
                            diff = actual_val - expected_val
                            if diff != 0:
                                error_info = {
                                    'frame': frame_idx,
                                    'r': r, 'c': c, 'ch': channel_idx,
                                    'exp': expected_val,
                                    'act': actual_val,
                                    'diff': diff,
                                    'rate': diff/(expected_val+0.1)
                                }
                                # 记录错误详情
                                error_log.append(error_info)
                                
                                # 仅打印特定范围错误
                                if len(error_log) >= 0 and len(error_log) <= 20:
                                    print(f"[FAIL] Frame:{frame_idx}, Pos(R:{r}, C:{c}, Ch:{channel_idx}, sim_line_idx:{sim_line_idx})")
                                    print(f"Exp: {expected_val} (0x{expected_val:02x}) | Act: {actual_val} (0x{sim_vals[pe_idx]:02x}) | Diff: {diff}")

                if frame_incomplete: break
            if frame_incomplete: break
        
        if frame_incomplete:
            print(f"Warning: Frame {frame_idx} is incomplete (Sim file ended).")
            break
            
        frame_idx += 1

    # ================= 统计分析结果 =================
    print("=" * 60)
    print("STATISTICAL ANALYSIS")
    print("=" * 60)
    print(f"Total Values Checked: {total_checks}")
    print(f"Total Frames Checked: {frame_idx + (1 if frame_incomplete else 0)}")
    print(f"Total Errors Found:   {len(error_log)}")
    
    if len(error_log) == 0:
        print("\nRESULT: PASS - All frames match perfectly!")
    else:
        print(f"\nRESULT: FAIL - Found {len(error_log)} mismatches.")
        
        # 1. 按帧统计
        frames_with_errors = {}
        for err in error_log:
            f = err['frame']
            frames_with_errors[f] = frames_with_errors.get(f, 0) + 1
            
        print("\n--- Errors per Frame ---")
        for f in sorted(frames_with_errors.keys()):
            print(f"Frame {f}: {frames_with_errors[f]} errors")

        diffs = []
        diffs_rate = []   
        abs_diffs = []
        abs_diffs_rate = []    
        # 2. 误差数值分析
        for e in error_log:
            diffs.append(e['diff'])
            diffs_rate.append(e['rate'])
            abs_diffs.append(abs(e['diff']))
            abs_diffs_rate.append(abs(e['rate']))
        
        max_diff = max(abs_diffs)
        min_diff = min(abs_diffs)
        avg_diff = sum(abs_diffs) / len(abs_diffs)
        max_diff_rate = max(abs_diffs_rate)
        min_diff_rate = min(abs_diffs_rate)
        avg_diff_rate = sum(abs_diffs_rate) / len(abs_diffs_rate)
        
        print("\n--- Error Magnitude Analysis ---")
        print(f"Max Absolute Error: {max_diff}")
        print(f"Min Absolute Error: {min_diff}")
        print(f"Avg Absolute Error: {avg_diff:.4f}")
        print(f"Max Absolute Error Rate: {max_diff_rate}")
        print(f"Min Absolute Error Rate: {min_diff_rate}")
        print(f"Avg Absolute Error Rate: {avg_diff_rate:.4f}")
        
        # 3. 查找最大误差出现的位置 (打印第一个最大值)
        max_err_item = next(e for e in error_log if abs(e['diff']) == max_diff)
        print(f"\n--- Worst Case Example ---")
        print(f"Frame: {max_err_item['frame']}, Pos(R:{max_err_item['r']}, C:{max_err_item['c']}, Ch:{max_err_item['ch']})")
        print(f"Expected: {max_err_item['exp']}, Actual: {max_err_item['act']}, Diff: {max_err_item['diff']}")

        
if __name__ == "__main__":
    compare_data()