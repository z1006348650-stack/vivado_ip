set script_dir [file dirname [file normalize [info script]]]
set ip_root    [file normalize $script_dir]
set tmp_prj    [file join $ip_root "_pack_tmp_2019_1"]
set part_name  "xc7k325tffg900-2"

set top_name   "axi_multiboot_driver_v1_0"
set vendor     "uestc.com"
set library    "user"
set ip_name    "axi_multiboot_driver"
set ip_version "3.0"

proc add_source_files {pattern_list} {
    set file_list [list]
    foreach pattern $pattern_list {
        foreach file_name [lsort [glob -nocomplain $pattern]] {
            lappend file_list $file_name
        }
    }
    if {[llength $file_list] != 0} {
        add_files -norecurse $file_list
    }
}

proc require_busif {core preferred_name fallback_name} {
    set busif [ipx::get_bus_interfaces $preferred_name -of_objects $core]
    if {[llength $busif] == 0} {
        set busif [ipx::get_bus_interfaces $fallback_name -of_objects $core]
    }
    if {[llength $busif] == 0} {
        error "Bus interface '$preferred_name'/'$fallback_name' not found."
    }
    return [lindex $busif 0]
}

proc ensure_bus_parameter {busif param_name param_value {resolve_type "immediate"}} {
    set bus_param [ipx::get_bus_parameters $param_name -of_objects $busif]
    if {[llength $bus_param] == 0} {
        set bus_param [ipx::add_bus_parameter $param_name $busif]
    } else {
        set bus_param [lindex $bus_param 0]
    }
    set_property value              $param_value  $bus_param
    set_property value_resolve_type $resolve_type $bus_param
    return $bus_param
}

proc patch_supported_families {component_xml} {
    set fp_in [open $component_xml r]
    set comp_text [read $fp_in]
    close $fp_in

    set old_block "      <xilinx:supportedFamilies>\n        <xilinx:family xilinx:lifeCycle=\"Production\">kintex7</xilinx:family>\n      </xilinx:supportedFamilies>"
    set new_block "      <xilinx:supportedFamilies>\n        <xilinx:family xilinx:lifeCycle=\"Production\">virtex7</xilinx:family>\n        <xilinx:family xilinx:lifeCycle=\"Production\">kintex7</xilinx:family>\n        <xilinx:family xilinx:lifeCycle=\"Production\">artix7</xilinx:family>\n        <xilinx:family xilinx:lifeCycle=\"Production\">zynq</xilinx:family>\n        <xilinx:family xilinx:lifeCycle=\"Production\">spartan7</xilinx:family>\n      </xilinx:supportedFamilies>"

    set comp_text [string map [list $old_block $new_block] $comp_text]

    set fp_out [open $component_xml w]
    puts -nonewline $fp_out $comp_text
    close $fp_out
}

puts "INFO: Creating Vivado 2019.1 packaging project at '$tmp_prj'"
create_project -force ${ip_name}_pack $tmp_prj -part $part_name

add_source_files [list \
    [file join $ip_root "hdl" "*.v"] \
    [file join $ip_root "src" "*.v"] \
    [file join $ip_root "src" "axis_data_fifo_*" "*.xci"]]

set_property top $top_name [get_filesets sources_1]
update_compile_order -fileset sources_1

puts "INFO: Packaging IP in '$ip_root'"
ipx::package_project \
    -root_dir $ip_root \
    -vendor $vendor \
    -library $library \
    -taxonomy /UserIP \
    -import_files \
    -force

set core [ipx::current_core]

set_property vendor       $vendor $core
set_property library      $library $core
set_property name         $ip_name $core
set_property version      $ip_version $core
set_property display_name $ip_name $core
set_property taxonomy     "/UserIP" $core
set_property description  "AXI multiboot driver with FLASH_MODEL support for S25FL256S, MT25QL, and N25Q128A" $core

set s00_axi_busif  [require_busif $core "S00_AXI" "s00_axi"]
set s00_axi_clk    [require_busif $core "S00_AXI_CLK" "s00_axi_aclk"]
set s00_axi_rst    [require_busif $core "S00_AXI_RST" "s00_axi_aresetn"]
set s00_axis_busif [require_busif $core "S00_AXIS" "s_axis"]

set_property name "S00_AXI"     $s00_axi_busif
set_property name "S00_AXI_CLK" $s00_axi_clk
set_property name "S00_AXI_RST" $s00_axi_rst
set_property name "S00_AXIS"    $s00_axis_busif

ensure_bus_parameter $s00_axi_clk "ASSOCIATED_BUSIF" "S00_AXI:S00_AXIS"
ensure_bus_parameter $s00_axi_clk "ASSOCIATED_RESET" "s00_axi_aresetn"
ensure_bus_parameter $s00_axi_rst "POLARITY" "ACTIVE_LOW"

set user_param_names [lsort [get_property name [ipx::get_user_parameters -of_objects $core]]]
set busif_names      [lsort [get_property name [ipx::get_bus_interfaces -of_objects $core]]]

puts "INFO: User parameters: $user_param_names"
puts "INFO: Bus interfaces : $busif_names"

if {[lsearch -exact $user_param_names "FLASH_MODEL"] < 0} {
    error "FLASH_MODEL was not detected in packaged IP parameters."
}

if {[lsearch -exact $user_param_names "FLASH_TYPE"] >= 0} {
    error "Stale FLASH_TYPE parameter still exists after packaging."
}

foreach required_busif {S00_AXI S00_AXIS S00_AXI_CLK S00_AXI_RST} {
    if {[lsearch -exact $busif_names $required_busif] < 0} {
        error "Required bus interface '$required_busif' is missing after packaging."
    }
}

set flash_model_param [ipx::get_user_parameters FLASH_MODEL -of_objects $core]
if {[llength $flash_model_param] != 0} {
    set flash_model_param [lindex $flash_model_param 0]
    set_property display_name "FLASH_MODEL" $flash_model_param
    set_property description "0=S25FL256S, 1=MT25QL(256/512), 2=N25Q128A" $flash_model_param
}

set s25_tbparm_param [ipx::get_user_parameters S25_TBPARM_TOP -of_objects $core]
if {[llength $s25_tbparm_param] != 0} {
    set s25_tbparm_param [lindex $s25_tbparm_param 0]
    set_property description "Only used when FLASH_MODEL=0 (S25FL256S)." $s25_tbparm_param
}

ipx::create_xgui_files $core
ipx::update_checksums $core
ipx::check_integrity -quiet $core
ipx::save_core $core

set xgui_v3 [file join $ip_root "xgui" "axi_multiboot_driver_v3_0.tcl"]
set xgui_v1 [file join $ip_root "xgui" "axi_multiboot_driver_v1_0.tcl"]
if {[file exists $xgui_v3]} {
    file copy -force $xgui_v3 $xgui_v1
}

patch_supported_families [file join $ip_root "component.xml"]

close_project

puts "INFO: IP packaging finished successfully."
puts "INFO: component.xml -> [file join $ip_root component.xml]"
