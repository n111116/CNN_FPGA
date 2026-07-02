transcript on

if {![info exists SCRIPT_DIR]} {
    set SCRIPT_DIR [file dirname [info script]]
}
if {![info exists ROOT_DIR]} {
    set ROOT_DIR [file join $SCRIPT_DIR ../..]
}
cd $SCRIPT_DIR

# 1. 清理并创建工作库
# if {[file exists rtl_work]} {
#     vdel -lib rtl_work -all
# }
vlib rtl_work
vmap work rtl_work

# 2. 定义路径变量
set INC_PATH [file join $ROOT_DIR rtl_pds data_process header]
set MEM_DATA_PATH "mem_data/"
set RTL_FILES [glob [file join $ROOT_DIR rtl_pds data_process *.sv]]

# 3. 编译 RTL 模块
# 建议加上 +incdir+，防止 RTL 模块内部也有 `include
vlog -work rtl_work \
    +incdir+$INC_PATH \
    +define+DATA_PATH="$MEM_DATA_PATH" \
    {*}$RTL_FILES

# 4. 编译测试平台
# 确保这里包含了 incdir，否则找不到 .vh 文件
vlog -work rtl_work -sv \
     +incdir+$INC_PATH \
     +define+DATA_PATH="$MEM_DATA_PATH" \
     [file join $ROOT_DIR sim_pds tb_lprnet.sv]

# 5. (可选) 物理拷贝 .mem 文件
# 如果你的 $readmemh("file.mem") 里面没写路径，就必须执行这一行
# file copy -force {*}[glob -nocomplain $MEM_DATA_PATH/*.mem] .

# 6. 设置仿真参数并启动
set rnd_seed [clock seconds]
set VSIM_ARGS [list +SEED=$rnd_seed]
if {[info exists INPUT_ROWS]} {
    lappend VSIM_ARGS +INPUT_ROWS=$INPUT_ROWS
}
vsim -t 1ns -L rtl_work -L work {*}$VSIM_ARGS -voptargs="+acc" tb_lprnet

# 7. 运行
# do wave_layer.do
run -all
