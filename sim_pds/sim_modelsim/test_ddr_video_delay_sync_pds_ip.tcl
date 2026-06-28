transcript on

puts {}
puts {============================================================}
puts {[TB] PDS DDR IP co-sim smoke script started.}
puts {[TB] This mode checks compile/elaboration and runs a short interval.}
puts {[TB] Use test_ddr_video_delay_sync_pds_ip_full.tcl for full DDR init.}
puts {============================================================}

set DDR_IP_DIR "../../prj_pds/ipcore/ddr3_test"
set PDS_HOME "C:/pango/PDS_2022.2-SP6.4"
set PANGO_SIM_PRIM_DIR "$PDS_HOME/arch/vendor/pango/verilog/simulation"
set PANGO_MODELSIM_DIR "$PANGO_SIM_PRIM_DIR/modelsim10.2c"
set DDR_CTRL_FILE_LIST "$DDR_IP_DIR/pnr/ctrl_phy_ip_filelist.f"
set DDR_MEM_MODEL "$DDR_IP_DIR/example_design/bench/mem/ddr3.v"
set DDR_MEM_INC "$DDR_IP_DIR/example_design/bench/mem"
set DDR_SIM_INC "$DDR_IP_DIR/sim/modelsim"
set DDR_SLICE_TOP "$DDR_IP_DIR/sim_lib/ddrphy/ddr3_test_slice_top_v1_10.v"
set DDR_TOP "$DDR_IP_DIR/ddr3_test.v"
set DDR_PHY_TOP "$DDR_IP_DIR/ddr3_test_ddrphy_top.v"

if {![file exists $DDR_CTRL_FILE_LIST]} {
    puts {}
    puts {============================================================}
    puts {[TB] PDS DDR controller file list is not present yet.}
    puts {[TB] Generate/regenerate prj_pds/ipcore/ddr3_test with PDS ip_generate first.}
    puts {============================================================}
    quit -code 2
}

if {![file exists $DDR_MEM_MODEL]} {
    puts {}
    puts {============================================================}
    puts {[TB] PDS DDR3 memory model is not present yet.}
    puts {[TB] Generate/regenerate ipcore/ddr3_test in PDS so example_design/bench/mem/ddr3.v is created.}
    puts {============================================================}
    quit -code 2
}

if {![file exists $DDR_SLICE_TOP] || ![file exists $DDR_TOP] || ![file exists $DDR_PHY_TOP]} {
    puts {}
    puts {============================================================}
    puts {[TB] PDS DDR wrapper files are not complete.}
    puts {[TB] Generate/regenerate prj_pds/ipcore/ddr3_test with PDS ip_generate first.}
    puts {============================================================}
    quit -code 2
}

set WORK_LIB_DIR rtl_work_ddr_video_delay_sync_pds_ip

if {[file exists $WORK_LIB_DIR]} {
    vdel -lib $WORK_LIB_DIR -all
}
vlib $WORK_LIB_DIR
vmap work $WORK_LIB_DIR

set pango_prim_files [list \
    "$PANGO_SIM_PRIM_DIR/GTP_GRS.v" \
    "$PANGO_SIM_PRIM_DIR/GTP_CLKBUFM.v" \
    "$PANGO_SIM_PRIM_DIR/GTP_GPLL.v" \
    "$PANGO_SIM_PRIM_DIR/GTP_CLKBUFG.v" \
    "$PANGO_SIM_PRIM_DIR/GTP_CLKPD.v" \
    "$PANGO_SIM_PRIM_DIR/GTP_CLKBUFR.v" \
    "$PANGO_SIM_PRIM_DIR/GTP_PPLL.v" \
    "$PANGO_SIM_PRIM_DIR/GTP_IOCLKDIV_E3.v" \
    "$PANGO_SIM_PRIM_DIR/GTP_IOBUFCO.v" \
    "$PANGO_SIM_PRIM_DIR/GTP_DDC_E2.v" \
    "$PANGO_SIM_PRIM_DIR/GTP_DLL_E2.v" \
    "$PANGO_SIM_PRIM_DIR/GTP_OSERDES_E2.v" \
    "$PANGO_SIM_PRIM_DIR/GTP_IODELAY_E2.v" \
    "$PANGO_SIM_PRIM_DIR/GTP_ISERDES_E2.v" \
    "$PANGO_SIM_PRIM_DIR/GTP_IOBUF.v" \
    "$PANGO_SIM_PRIM_DIR/GTP_OUTBUFT.v" \
    "$PANGO_SIM_PRIM_DIR/GTP_OUTBUFTCO.v" \
]

array set seen_pango_prim {}
foreach file_list_name [list filelist_ddc_e2_gtp.f filelist_dll_e2_gtp.f filelist_iserdes_e2_gtp.f filelist_oserdes_e2_gtp.f filelist_iolhr_dft_gtp.f] {
    set file_list_path "$PANGO_MODELSIM_DIR/$file_list_name"
    if {![file exists $file_list_path]} {
        puts "[TB] Missing Pango primitive file list: $file_list_path"
        quit -code 2
    }
    set fl_fh [open $file_list_path r]
    while {[gets $fl_fh line] >= 0} {
        set line [string trim $line]
        if {$line eq "" || [string match "//*" $line]} {
            continue
        }
        foreach token [split $line] {
            set token [string trim $token]
            if {$token eq "" || [string match "//*" $token]} {
                continue
            }
            if {[string match "+*" $token]} {
                lappend pango_prim_files $token
            } elseif {[regexp {(\.v|\.vp|\.svp)$} $token]} {
                regsub {^\./} $token {} rel_token
                lappend pango_prim_files "$PANGO_MODELSIM_DIR/$rel_token"
            }
        }
    }
    close $fl_fh
}

set pango_prim_unique {}
foreach item $pango_prim_files {
    if {![info exists seen_pango_prim($item)]} {
        set seen_pango_prim($item) 1
        lappend pango_prim_unique $item
    }
}

set pango_prim_options {}
set pango_prim_sources {}
foreach item $pango_prim_unique {
    if {[string match "+*" $item]} {
        lappend pango_prim_options $item
    } else {
        lappend pango_prim_sources $item
    }
}
foreach src $pango_prim_sources {
    vlog -work work {*}$pango_prim_options $src
}
puts {[TB] Pango simulation primitives compiled.}

set ctrl_fh [open $DDR_CTRL_FILE_LIST r]
set sim_files {}
while {[gets $ctrl_fh line] >= 0} {
    set line [string trim $line]
    if {$line eq ""} {
        continue
    }
    regsub {^rtl/} $line {sim_lib/} line
    lappend sim_files "$DDR_IP_DIR/$line"
}
close $ctrl_fh
lappend sim_files $DDR_SLICE_TOP $DDR_PHY_TOP $DDR_TOP
vlog -work work {*}$sim_files
puts {[TB] PDS DDR IP simulation sources compiled.}

vlog -work work -sv +define+den4096Mb +incdir+$DDR_SIM_INC +incdir+$DDR_MEM_INC $DDR_MEM_MODEL
puts {[TB] DDR3 memory model compiled.}

vlog -work work -sv +define+USE_PDS_DDR3_MEMORY_MODEL \
    ../../rtl_pds/ddr/wr_cmd_trans.v \
    ../../rtl_pds/ddr/wr_ctrl.v \
    ../../rtl_pds/ddr/rd_ctrl.v \
    ../../rtl_pds/ddr/wr_rd_ctrl_top.v \
    ../../rtl_pds/ddr/ddr_wr_line_ram.sv \
    ../../rtl_pds/ddr/ddr_rd_line_ram.sv \
    ../../rtl_pds/ddr/ddr_video_delay_sync.sv \
    ../tb_ddr_video_delay_sync.sv
puts {[TB] DDR video delay RTL and testbench compiled.}

if {![info exists PDS_DDR_RUN_MODE]} {
    set PDS_DDR_RUN_MODE smoke
}

vsim -t 10fs -L work -voptargs="+acc" tb_ddr_video_delay_sync

if {$PDS_DDR_RUN_MODE eq "full"} {
    run -all
} else {
    puts {[TB] Running PDS DDR IP co-sim smoke interval: 2 us.}
    run 2 us
    puts {}
    puts {============================================================}
    puts {[TB] SMOKE PASS: PDS DDR IP co-sim compiled, elaborated, and ran 2 us.}
    puts {[TB] Note: smoke mode does not wait for DDR calibration or pixel comparison.}
    puts {[TB] Full functional pixel check uses the fast AXI memory model script.}
    puts {[TB] Full PDS DDR init uses test_ddr_video_delay_sync_pds_ip_full.tcl.}
    puts {============================================================}
    quit -code 0
}
