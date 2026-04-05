# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "AXI_ADDR_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "AXI_TIMEOUT_CYCLES" -parent ${Page_0}
  ipgui::add_param $IPINST -name "MAX_FRAME_DATA_BYTES" -parent ${Page_0}
  ipgui::add_param $IPINST -name "SYS_CLK_FREQ_HZ" -parent ${Page_0}
  ipgui::add_param $IPINST -name "UART_BAUD_RATE" -parent ${Page_0}


}

proc update_PARAM_VALUE.AXI_ADDR_WIDTH { PARAM_VALUE.AXI_ADDR_WIDTH } {
	# Procedure called to update AXI_ADDR_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.AXI_ADDR_WIDTH { PARAM_VALUE.AXI_ADDR_WIDTH } {
	# Procedure called to validate AXI_ADDR_WIDTH
	return true
}

proc update_PARAM_VALUE.AXI_FULL_ARCACHE { PARAM_VALUE.AXI_FULL_ARCACHE } {
	# Procedure called to update AXI_FULL_ARCACHE when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.AXI_FULL_ARCACHE { PARAM_VALUE.AXI_FULL_ARCACHE } {
	# Procedure called to validate AXI_FULL_ARCACHE
	return true
}

proc update_PARAM_VALUE.AXI_FULL_ARPROT { PARAM_VALUE.AXI_FULL_ARPROT } {
	# Procedure called to update AXI_FULL_ARPROT when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.AXI_FULL_ARPROT { PARAM_VALUE.AXI_FULL_ARPROT } {
	# Procedure called to validate AXI_FULL_ARPROT
	return true
}

proc update_PARAM_VALUE.AXI_FULL_ARQOS { PARAM_VALUE.AXI_FULL_ARQOS } {
	# Procedure called to update AXI_FULL_ARQOS when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.AXI_FULL_ARQOS { PARAM_VALUE.AXI_FULL_ARQOS } {
	# Procedure called to validate AXI_FULL_ARQOS
	return true
}

proc update_PARAM_VALUE.AXI_FULL_AWCACHE { PARAM_VALUE.AXI_FULL_AWCACHE } {
	# Procedure called to update AXI_FULL_AWCACHE when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.AXI_FULL_AWCACHE { PARAM_VALUE.AXI_FULL_AWCACHE } {
	# Procedure called to validate AXI_FULL_AWCACHE
	return true
}

proc update_PARAM_VALUE.AXI_FULL_AWPROT { PARAM_VALUE.AXI_FULL_AWPROT } {
	# Procedure called to update AXI_FULL_AWPROT when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.AXI_FULL_AWPROT { PARAM_VALUE.AXI_FULL_AWPROT } {
	# Procedure called to validate AXI_FULL_AWPROT
	return true
}

proc update_PARAM_VALUE.AXI_FULL_AWQOS { PARAM_VALUE.AXI_FULL_AWQOS } {
	# Procedure called to update AXI_FULL_AWQOS when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.AXI_FULL_AWQOS { PARAM_VALUE.AXI_FULL_AWQOS } {
	# Procedure called to validate AXI_FULL_AWQOS
	return true
}

proc update_PARAM_VALUE.AXI_TIMEOUT_CYCLES { PARAM_VALUE.AXI_TIMEOUT_CYCLES } {
	# Procedure called to update AXI_TIMEOUT_CYCLES when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.AXI_TIMEOUT_CYCLES { PARAM_VALUE.AXI_TIMEOUT_CYCLES } {
	# Procedure called to validate AXI_TIMEOUT_CYCLES
	return true
}

proc update_PARAM_VALUE.MAX_FRAME_DATA_BYTES { PARAM_VALUE.MAX_FRAME_DATA_BYTES } {
	# Procedure called to update MAX_FRAME_DATA_BYTES when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.MAX_FRAME_DATA_BYTES { PARAM_VALUE.MAX_FRAME_DATA_BYTES } {
	# Procedure called to validate MAX_FRAME_DATA_BYTES
	return true
}

proc update_PARAM_VALUE.SYS_CLK_FREQ_HZ { PARAM_VALUE.SYS_CLK_FREQ_HZ } {
	# Procedure called to update SYS_CLK_FREQ_HZ when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.SYS_CLK_FREQ_HZ { PARAM_VALUE.SYS_CLK_FREQ_HZ } {
	# Procedure called to validate SYS_CLK_FREQ_HZ
	return true
}

proc update_PARAM_VALUE.UART_BAUD_RATE { PARAM_VALUE.UART_BAUD_RATE } {
	# Procedure called to update UART_BAUD_RATE when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.UART_BAUD_RATE { PARAM_VALUE.UART_BAUD_RATE } {
	# Procedure called to validate UART_BAUD_RATE
	return true
}


proc update_MODELPARAM_VALUE.SYS_CLK_FREQ_HZ { MODELPARAM_VALUE.SYS_CLK_FREQ_HZ PARAM_VALUE.SYS_CLK_FREQ_HZ } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.SYS_CLK_FREQ_HZ}] ${MODELPARAM_VALUE.SYS_CLK_FREQ_HZ}
}

proc update_MODELPARAM_VALUE.UART_BAUD_RATE { MODELPARAM_VALUE.UART_BAUD_RATE PARAM_VALUE.UART_BAUD_RATE } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.UART_BAUD_RATE}] ${MODELPARAM_VALUE.UART_BAUD_RATE}
}

proc update_MODELPARAM_VALUE.AXI_ADDR_WIDTH { MODELPARAM_VALUE.AXI_ADDR_WIDTH PARAM_VALUE.AXI_ADDR_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.AXI_ADDR_WIDTH}] ${MODELPARAM_VALUE.AXI_ADDR_WIDTH}
}

proc update_MODELPARAM_VALUE.AXI_TIMEOUT_CYCLES { MODELPARAM_VALUE.AXI_TIMEOUT_CYCLES PARAM_VALUE.AXI_TIMEOUT_CYCLES } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.AXI_TIMEOUT_CYCLES}] ${MODELPARAM_VALUE.AXI_TIMEOUT_CYCLES}
}

proc update_MODELPARAM_VALUE.MAX_FRAME_DATA_BYTES { MODELPARAM_VALUE.MAX_FRAME_DATA_BYTES PARAM_VALUE.MAX_FRAME_DATA_BYTES } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.MAX_FRAME_DATA_BYTES}] ${MODELPARAM_VALUE.MAX_FRAME_DATA_BYTES}
}

proc update_MODELPARAM_VALUE.AXI_FULL_AWCACHE { MODELPARAM_VALUE.AXI_FULL_AWCACHE PARAM_VALUE.AXI_FULL_AWCACHE } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.AXI_FULL_AWCACHE}] ${MODELPARAM_VALUE.AXI_FULL_AWCACHE}
}

proc update_MODELPARAM_VALUE.AXI_FULL_ARCACHE { MODELPARAM_VALUE.AXI_FULL_ARCACHE PARAM_VALUE.AXI_FULL_ARCACHE } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.AXI_FULL_ARCACHE}] ${MODELPARAM_VALUE.AXI_FULL_ARCACHE}
}

proc update_MODELPARAM_VALUE.AXI_FULL_AWPROT { MODELPARAM_VALUE.AXI_FULL_AWPROT PARAM_VALUE.AXI_FULL_AWPROT } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.AXI_FULL_AWPROT}] ${MODELPARAM_VALUE.AXI_FULL_AWPROT}
}

proc update_MODELPARAM_VALUE.AXI_FULL_ARPROT { MODELPARAM_VALUE.AXI_FULL_ARPROT PARAM_VALUE.AXI_FULL_ARPROT } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.AXI_FULL_ARPROT}] ${MODELPARAM_VALUE.AXI_FULL_ARPROT}
}

proc update_MODELPARAM_VALUE.AXI_FULL_AWQOS { MODELPARAM_VALUE.AXI_FULL_AWQOS PARAM_VALUE.AXI_FULL_AWQOS } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.AXI_FULL_AWQOS}] ${MODELPARAM_VALUE.AXI_FULL_AWQOS}
}

proc update_MODELPARAM_VALUE.AXI_FULL_ARQOS { MODELPARAM_VALUE.AXI_FULL_ARQOS PARAM_VALUE.AXI_FULL_ARQOS } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.AXI_FULL_ARQOS}] ${MODELPARAM_VALUE.AXI_FULL_ARQOS}
}

