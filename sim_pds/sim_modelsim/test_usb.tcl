transcript on
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work
       

vlog     	../../rtl_pds/async_fifo.v
vlog     	../tb_USB3_rw_test.sv



set rnd_seed [clock seconds]

vsim -t 1ps -L rtl_work -L work +SEED=${rnd_seed} -voptargs="+acc" tb_USB3_rw_test

do wave.do

run -all
