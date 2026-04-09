transcript on

# 1. 清理旧的工作库
if {[file exists rtl_work]} {
    vdel -lib rtl_work -all
}

# 2. 创建新工作库
vlib rtl_work
vmap work rtl_work

# 3. 编译 RTL 模块
# 注意编译顺序：底层模块 -> 顶层模块
vlog -work rtl_work ../../rtl_pds/data_process/pe.sv
vlog -work rtl_work ../../rtl_pds/data_process/pe_col.sv
vlog -work rtl_work ../../rtl_pds/data_process/d_manager.sv
vlog -work rtl_work ../../rtl_pds/data_process/w_manager.sv
vlog -work rtl_work ../../rtl_pds/data_process/pe_page.sv
vlog -work rtl_work ../../rtl_pds/data_process/sdp_ram.sv
vlog -work rtl_work ../../rtl_pds/data_process/input_layer.sv
vlog -work rtl_work ../../rtl_pds/data_process/output_layer.sv
# 编译 layer1 (之前生成的顶层模块)
vlog -work rtl_work ../../rtl_pds/data_process/layer1.sv

# 4. 编译测试平台
# 假设 tb 文件放在仿真脚本同级目录或上级目录，这里假设在上一级
vlog -work rtl_work ../tb_layer1.sv

# 5. 设置仿真参数
set rnd_seed [clock seconds]

# 6. 启动仿真
# 确保仿真目录下有 mem_data 文件夹和权重文件，或者在此处拷贝
file copy -force ../../mem_data/weights_layer1_page0.mem .
file copy -force ../../mem_data/weights_layer1_page1.mem .
file copy -force ../../mem_data/weights_layer1_page2.mem .
file copy -force ../../mem_data/biases_layer1.mem .

vsim -t 1ns -L rtl_work -L work +SEED=$rnd_seed -voptargs="+acc" tb_layer1

# 7. 添加波形 (可选，建议保存为 wave_output.do)
do wave_output.do

# 8. 运行
run 25us