transcript on

# 1. 清理并创建工作库
# if {[file exists rtl_work]} {
#     vdel -lib rtl_work -all
# }
vlib rtl_work
vmap work rtl_work

# 2. 定义路径变量
set INC_PATH "../../rtl/data_process/header"
set MEM_DATA_PATH "../../mem_data/"
file copy -force {*}[glob ../../rtl/data_process/mem_data/*.mem] .

# 3. 编译 RTL 模块
# 建议加上 +incdir+，防止 RTL 模块内部也有 `include
vlog -work rtl_work \
    +incdir+$INC_PATH \
    +define+DATA_PATH="$MEM_DATA_PATH" \
    ../../rtl/*.sv

# 4. 编译测试平台
# 确保这里包含了 incdir，否则找不到 .vh 文件
vlog -work rtl_work -sv \
     +incdir+$INC_PATH \
     +define+DATA_PATH="$MEM_DATA_PATH" \
     ../tb_my_fifo.sv

# 5. (可选) 物理拷贝 .mem 文件
# 如果你的 $readmemh("file.mem") 里面没写路径，就必须执行这一行
# file copy -force {*}[glob -nocomplain $MEM_DATA_PATH/*.mem] .

# 6. 设置仿真参数并启动
set rnd_seed [clock seconds]
vsim -t 1ns -L rtl_work -L work +SEED=$rnd_seed -voptargs="+acc" tb_my_fifo

# 7. 运行
do wave_my_fifo.do
run 300us
