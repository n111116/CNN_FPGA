transcript on

if {![info exists SCRIPT_DIR]} {
    set SCRIPT_DIR [file dirname [file normalize [info script]]]
}
if {![info exists ROOT_DIR]} {
    set ROOT_DIR [file normalize [file join $SCRIPT_DIR ../..]]
}
cd $SCRIPT_DIR

# 1. 清理并创建工作库
set WORK_LIB rtl_work_box_crop
if {[file exists $WORK_LIB]} {
    vdel -lib $WORK_LIB -all
}
vlib $WORK_LIB
vmap work $WORK_LIB

# 2. 定义路径变量
set INC_PATH [file join $ROOT_DIR rtl_pds data_process header]
set MEM_DATA_PATH "mem_data/"
file mkdir [file join $SCRIPT_DIR sim_out]

# 3. 编译 RTL 模块
# 建议加上 +incdir+，防止 RTL 模块内部也有 `include
vlog -work $WORK_LIB -sv \
    +incdir+$INC_PATH \
    +define+DATA_PATH="$MEM_DATA_PATH" \
    [file join $ROOT_DIR rtl_pds overlay box_overlay_sync.sv] \
    [file join $ROOT_DIR rtl_pds overlay crop_buffer_manager.sv]
vlog -work $WORK_LIB -sv \
    +incdir+$INC_PATH \
    +define+DATA_PATH="$MEM_DATA_PATH" \
    [file join $ROOT_DIR rtl_pds my_fifo.sv]

# 4. 编译测试平台
# 确保这里包含了 incdir，否则找不到 .vh 文件
vlog -work $WORK_LIB -sv \
     +incdir+$INC_PATH \
     +define+DATA_PATH="$MEM_DATA_PATH" \
     [file join $ROOT_DIR sim_pds tb_box_overlay_crop_buffer_manager.sv]

# 5. (可选) 物理拷贝 .mem 文件
# 如果你的 $readmemh("file.mem") 里面没写路径，就必须执行这一行
# file copy -force {*}[glob -nocomplain $MEM_DATA_PATH/*.mem] .

# 6. 设置仿真参数并启动
set rnd_seed [clock seconds]
vsim -t 1ns -L $WORK_LIB -L work +SEED=$rnd_seed -voptargs="+acc" tb_box_overlay_crop_buffer_manager

# 7. 运行全部
do wave_box_overlay_crop_buffer_manager.do
run -all
