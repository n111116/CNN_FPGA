# 功能 ：生成与层例化相关的代码片段，以便复制到顶层模块中
import os

from CnnHardwareGenerator import all_layers 

# ================= 配置区 =================
# 是否添加 (* mark_debug = "true" *) 属性
ADD_MARK_DEBUG = True
# ==========================================

def generate_sv_instantiations(layers):
    debug_str = '(* mark_debug = "true" *) ' if ADD_MARK_DEBUG else ''
    
    includes_str = "// =========================================================\n"
    includes_str += "// 头文件 Include\n"
    includes_str += "// =========================================================\n"
    
    logic_def_str = "// =========================================================\n"
    logic_def_str += "// 各层连线定义\n"
    logic_def_str += "// =========================================================\n"
    
    inst_str = "// =========================================================\n"
    inst_str += "// CNN 层级例化\n"
    inst_str += "// =========================================================\n"

    for layer in layers:
        n = layer.layer_num
        prev = layer.prev_layer_num
        
        # 1. 生成 Include
        includes_str += f'`include "layer{n}.vh"\n'
        
        # 2. 生成连线定义
        if n not in [5,8,11]:
            logic_def_str += f"    // Layer {n} -> Layer {n+1}\n"
        elif n == 5:
            logic_def_str += f"    // Layer {n} -> Layer 6 & Layer 9\n"
        elif n == 8:
            logic_def_str += f"    // Layer {n} -> cv3 post_conv_2d\n"
        elif n == 11:
            logic_def_str += f"    // Layer {n} -> Adatper\n"

        logic_def_str += f"    {debug_str}logic [OUT_WIDTH_LAYER{n}-1:0] layer_y_out_layer{n} [PE_COL_NUM_LAYER{n}-1:0];\n"
        logic_def_str += f"    {debug_str}logic out_valid_layer{n};\n"
        logic_def_str += f"    {debug_str}logic new_line_out_1_layer{n};\n\n"
        
        # 3. 确定输入端口连接
        if prev == -1:
            # 顶层输入连接 (通常是 Layer 0 或 Layer 1)
            in_new_line = "new_line_1"
            in_valid = "adapter_valid"
            in_data = "data_to_layer"
        else:
            # 内部层级联连接
            in_new_line = f"new_line_out_1_layer{prev}"
            in_valid = f"out_valid_layer{prev}"
            in_data = f"layer_y_out_layer{prev}"
            
        out_new_line = f"new_line_out_1_layer{n}"
        out_valid = f"out_valid_layer{n}"
        out_data = f"layer_y_out_layer{n}"

        # 4. 生成例化代码
        inst_str += f"    // Layer {n}\n"
        inst_str += f"    layer #(\n"
        inst_str += f"        .LAYER_NUM(LAYER_NUM_LAYER{n}),\n"
        inst_str += f"        .PE_PAGE_NUM(PE_PAGE_NUM_LAYER{n}),\n"
        inst_str += f"        .PE_ROW_NUM(PE_ROW_NUM_LAYER{n}),\n"
        inst_str += f"        .PE_COL_NUM(PE_COL_NUM_LAYER{n}),\n"
        inst_str += f"        .KERNEL_COL(KERNEL_COL_LAYER{n}),\n"
        inst_str += f"        .KERNEL_ROW(KERNEL_ROW_LAYER{n}),\n"
        inst_str += f"        .WITH_RELU(WITH_RELU_LAYER{n}),\n"
        inst_str += f"        .MAX_POOL(MAX_POOL_LAYER{n}),\n"
        inst_str += f"        .DATA_WIDTH(DATA_WIDTH_LAYER{n}),\n"
        inst_str += f"        .WEIGHT_WIDTH(WEIGHT_WIDTH_LAYER{n}),\n"
        inst_str += f"        .USE_DSP_PE(USE_DSP_PE_LAYER{n}),\n"
        inst_str += f"        .CYCLE_PERIOD_IN(CYCLE_PERIOD_IN_LAYER{n}),\n"
        inst_str += f"        .CYCLE_PERIOD_OUT(CYCLE_PERIOD_OUT_LAYER{n}),\n"
        inst_str += f"        .IMG_COL(IMG_COL_LAYER{n}),\n"
        inst_str += f"        .IMG_ROW(IMG_ROW_LAYER{n}),\n"
        inst_str += f"        .STEP_COL(STEP_COL_LAYER{n}),\n"
        inst_str += f"        .STEP_ROW(STEP_ROW_LAYER{n}),\n"
        inst_str += f"        .SHIFT_KEY(SHIFT_KEY_LAYER{n}),\n"
        inst_str += f"        .BIAS_WIDTH(BIAS_WIDTH_LAYER{n}),\n"
        inst_str += f"        .OUT_WIDTH(OUT_WIDTH_LAYER{n}),\n"
        inst_str += f"        .PE_PAGE_OUTPUT_WIDTH(PE_PAGE_OUTPUT_WIDTH_LAYER{n}),\n"
        inst_str += f"        .ACC_WIDTH(ACC_WIDTH_LAYER{n})\n"
        inst_str += f"    ) u_layer{n} (\n"
        inst_str += f"        .clk(clk_pe),\n"
        inst_str += f"        .clk_en(usb_clk_locked),\n"
        inst_str += f"        .rst_n(rst_n),\n"
        inst_str += f"        .new_line_input_1({in_new_line}),\n"
        inst_str += f"        .data_input_valid({in_valid}),\n"
        inst_str += f"        .data_input({in_data}),\n"
        inst_str += f"        .y_out({out_data}),\n"
        inst_str += f"        .new_line_out_1({out_new_line}),\n"
        inst_str += f"        .output_valid({out_valid})\n"
        inst_str += f"    );\n\n"

    # 将所有部分拼接并打印/写入文件
    final_code = f"{includes_str}\n{logic_def_str}\n{inst_str}"
    
    # 打印到控制台
    print(final_code)
    
    # 也保存到文本文件方便复制
    with open("sv_layer_instantiations.txt", "w", encoding="utf-8") as f:
        f.write(final_code)
    print("-> 成功生成 SystemVerilog 代码，已保存至 sv_layer_instantiations.txt")

if __name__ == "__main__":
    generate_sv_instantiations(all_layers)