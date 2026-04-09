transcript on

# 清理旧的工作库
if {[file exists rtl_work]} {
    vdel -lib rtl_work -all
}

# 创建新工作库
vlib rtl_work
vmap work rtl_work

# 编译所有RTL模块（在rtl/data_process目录下）
vlog -work rtl_work ../../rtl_pds/data_process/pe.sv
vlog -work rtl_work ../../rtl_pds/data_process/pe_col.sv
vlog -work rtl_work ../../rtl_pds/data_process/d_manager.sv
vlog -work rtl_work ../../rtl_pds/data_process/pe_page.sv

# 编译测试平台
vlog -work rtl_work ../tb_pe_page.sv

# 设置随机种子
set rnd_seed [clock seconds]

# 启动仿真
vsim -t 1ns -L rtl_work -L work +SEED=$rnd_seed -voptargs="+acc" tb_pe_page

# 加载波形配置
do wave_pe_page.do

# 运行仿真
run -all