set script_dir [file dirname [file normalize [info script]]]
set root_dir   [file normalize [file join $script_dir ".."]]
set ip_dir     [file join $root_dir "ip"]
set ip_name    "uart_axi_bridge"
set fpga_part  "xc7k325tffg900-2"
set tmp_prj_dir [file join $root_dir "prj" "_ip_pack_tmp_2019_1"]

proc ensure_port_map {busif map_name logical_name physical_name} {
    set port_map [ipx::get_port_maps $map_name -of_objects $busif]
    if {[llength $port_map] == 0} {
        set port_map [ipx::add_port_map $map_name $busif]
    } else {
        set port_map [lindex $port_map 0]
    }
    set_property logical_name  $logical_name  $port_map
    set_property physical_name $physical_name $port_map
    return $port_map
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

proc ensure_address_space {core space_name space_width space_range} {
    set addr_space [ipx::get_address_spaces $space_name -of_objects $core]
    if {[llength $addr_space] == 0} {
        set addr_space [ipx::add_address_space $space_name $core]
    } else {
        set addr_space [lindex $addr_space 0]
    }
    set_property width $space_width $addr_space
    set_property range $space_range $addr_space
    return $addr_space
}

proc ensure_signal_busif {core busif_name type physical_port} {
    if {$type eq "clock"} {
        set bus_vlnv "xilinx.com:signal:clock:1.0"
        set abs_vlnv "xilinx.com:signal:clock_rtl:1.0"
        set map_name "CLK"
        set mode "slave"
    } elseif {$type eq "reset"} {
        set bus_vlnv "xilinx.com:signal:reset:1.0"
        set abs_vlnv "xilinx.com:signal:reset_rtl:1.0"
        set map_name "RST"
        set mode "slave"
    } else {
        error "Unsupported signal interface type: $type"
    }

    set busif [ipx::get_bus_interfaces $busif_name -of_objects $core]
    if {[llength $busif] == 0} {
        set busif [ipx::add_bus_interface $busif_name $core]
    } else {
        set busif [lindex $busif 0]
    }

    set_property bus_type_vlnv         $bus_vlnv $busif
    set_property abstraction_type_vlnv $abs_vlnv $busif
    set_property interface_mode        $mode $busif
    ensure_port_map $busif $map_name $map_name $physical_port
    return $busif
}

proc ensure_aximm_master_busif {core busif_name protocol addr_width data_width max_burst_len addr_space_name port_maps} {
    set busif [ipx::get_bus_interfaces $busif_name -of_objects $core]
    if {[llength $busif] == 0} {
        set busif [ipx::add_bus_interface $busif_name $core]
    } else {
        set busif [lindex $busif 0]
    }

    set addr_space [ensure_address_space $core $addr_space_name $addr_width 1099511627776]

    set_property bus_type_vlnv            "xilinx.com:interface:aximm:1.0"     $busif
    set_property abstraction_type_vlnv    "xilinx.com:interface:aximm_rtl:1.0" $busif
    set_property interface_mode           "master"                              $busif
    set_property endianness               "little"                              $busif
    set_property master_address_space_ref [get_property name $addr_space]        $busif

    ensure_bus_parameter $busif "ADDR_WIDTH"      $addr_width
    ensure_bus_parameter $busif "DATA_WIDTH"      $data_width
    ensure_bus_parameter $busif "PROTOCOL"        $protocol
    ensure_bus_parameter $busif "READ_WRITE_MODE" "READ_WRITE"

    if {$protocol eq "AXI4"} {
        ensure_bus_parameter $busif "HAS_BURST"              1
        ensure_bus_parameter $busif "SUPPORTS_NARROW_BURST"  0
        ensure_bus_parameter $busif "MAX_BURST_LENGTH"       $max_burst_len
        ensure_bus_parameter $busif "MAX_READ_BURST_LENGTH"  $max_burst_len
        ensure_bus_parameter $busif "MAX_WRITE_BURST_LENGTH" $max_burst_len
        ensure_bus_parameter $busif "NUM_READ_OUTSTANDING"   1
        ensure_bus_parameter $busif "NUM_WRITE_OUTSTANDING"  1
    }

    foreach port_map_item $port_maps {
        lassign $port_map_item logical_name physical_name
        ensure_port_map $busif $logical_name $logical_name $physical_name
    }

    return $busif
}

puts "INFO: Creating temporary Vivado 2019.1 project in '$tmp_prj_dir'"

file mkdir $ip_dir
create_project -force ${ip_name}_ip_pack $tmp_prj_dir -part $fpga_part

set rtl_files [lsort [glob -nocomplain [file join $root_dir "src" "rtl" "*.v"]]]
if {[llength $rtl_files] == 0} {
    error "No RTL files found under [file join $root_dir src rtl]"
}

add_files -norecurse $rtl_files
set_property top uart_axi_bridge [get_filesets sources_1]
update_compile_order -fileset sources_1

puts "INFO: Packaging IP into '$ip_dir'"
ipx::package_project \
    -root_dir $ip_dir \
    -vendor user.org \
    -library user \
    -taxonomy /UserIP \
    -import_files \
    -force

set core [ipx::current_core]

set_property name         $ip_name                $core
set_property display_name $ip_name                $core
set_property vendor       "user.org"              $core
set_property library      "user"                  $core
set_property taxonomy     "/UserIP"               $core
set_property description  "UART to AXI bridge IP" $core

foreach stale_busif_name {clk rst_n o_m_axil o_m_axi i_m_axi} {
    set stale_busif [ipx::get_bus_interfaces $stale_busif_name -of_objects $core]
    if {[llength $stale_busif] != 0} {
        ipx::remove_bus_interface [lindex $stale_busif 0]
    }
}

set clk_busif [ensure_signal_busif $core "i_clk" "clock" "i_clk"]
ensure_bus_parameter $clk_busif "ASSOCIATED_BUSIF" "M_AXIL:M_AXI"
ensure_bus_parameter $clk_busif "ASSOCIATED_RESET" "i_rst_n"

set rst_busif [ensure_signal_busif $core "i_rst_n" "reset" "i_rst_n"]
ensure_bus_parameter $rst_busif "POLARITY" "ACTIVE_LOW"

set m_axil_port_maps [list \
    [list "AWADDR"  "o_m_axil_awaddr"]  \
    [list "AWPROT"  "o_m_axil_awprot"]  \
    [list "AWVALID" "o_m_axil_awvalid"] \
    [list "AWREADY" "i_m_axil_awready"] \
    [list "WDATA"   "o_m_axil_wdata"]   \
    [list "WSTRB"   "o_m_axil_wstrb"]   \
    [list "WVALID"  "o_m_axil_wvalid"]  \
    [list "WREADY"  "i_m_axil_wready"]  \
    [list "BRESP"   "i_m_axil_bresp"]   \
    [list "BVALID"  "i_m_axil_bvalid"]  \
    [list "BREADY"  "o_m_axil_bready"]  \
    [list "ARADDR"  "o_m_axil_araddr"]  \
    [list "ARPROT"  "o_m_axil_arprot"]  \
    [list "ARVALID" "o_m_axil_arvalid"] \
    [list "ARREADY" "i_m_axil_arready"] \
    [list "RDATA"   "i_m_axil_rdata"]   \
    [list "RRESP"   "i_m_axil_rresp"]   \
    [list "RVALID"  "i_m_axil_rvalid"]  \
    [list "RREADY"  "o_m_axil_rready"]]

set m_axi_port_maps [list \
    [list "AWADDR"  "o_m_axi_awaddr"]  \
    [list "AWLEN"   "o_m_axi_awlen"]   \
    [list "AWSIZE"  "o_m_axi_awsize"]  \
    [list "AWBURST" "o_m_axi_awburst"] \
    [list "AWLOCK"  "o_m_axi_awlock"]  \
    [list "AWCACHE" "o_m_axi_awcache"] \
    [list "AWPROT"  "o_m_axi_awprot"]  \
    [list "AWQOS"   "o_m_axi_awqos"]   \
    [list "AWVALID" "o_m_axi_awvalid"] \
    [list "AWREADY" "i_m_axi_awready"] \
    [list "WDATA"   "o_m_axi_wdata"]   \
    [list "WSTRB"   "o_m_axi_wstrb"]   \
    [list "WLAST"   "o_m_axi_wlast"]   \
    [list "WVALID"  "o_m_axi_wvalid"]  \
    [list "WREADY"  "i_m_axi_wready"]  \
    [list "BRESP"   "i_m_axi_bresp"]   \
    [list "BVALID"  "i_m_axi_bvalid"]  \
    [list "BREADY"  "o_m_axi_bready"]  \
    [list "ARADDR"  "o_m_axi_araddr"]  \
    [list "ARLEN"   "o_m_axi_arlen"]   \
    [list "ARSIZE"  "o_m_axi_arsize"]  \
    [list "ARBURST" "o_m_axi_arburst"] \
    [list "ARLOCK"  "o_m_axi_arlock"]  \
    [list "ARCACHE" "o_m_axi_arcache"] \
    [list "ARPROT"  "o_m_axi_arprot"]  \
    [list "ARQOS"   "o_m_axi_arqos"]   \
    [list "ARVALID" "o_m_axi_arvalid"] \
    [list "ARREADY" "i_m_axi_arready"] \
    [list "RDATA"   "i_m_axi_rdata"]   \
    [list "RRESP"   "i_m_axi_rresp"]   \
    [list "RLAST"   "i_m_axi_rlast"]   \
    [list "RVALID"  "i_m_axi_rvalid"]  \
    [list "RREADY"  "o_m_axi_rready"]]

ensure_aximm_master_busif $core "M_AXIL" "AXI4LITE" 40 32 1   "Data_M_AXIL" $m_axil_port_maps
ensure_aximm_master_busif $core "M_AXI"  "AXI4"     40 32 256 "Data_M_AXI"  $m_axi_port_maps

ipx::create_xgui_files $core
ipx::update_checksums $core
ipx::check_integrity -quiet $core
ipx::save_core $core

close_project

puts "INFO: IP packaging completed: [file join $ip_dir component.xml]"


