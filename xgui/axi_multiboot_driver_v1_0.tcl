# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "C_S00_AXI_ADDR_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_S00_AXI_DATA_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "DEVICE_ID" -parent ${Page_0}
  ipgui::add_param $IPINST -name "ERASE_TIMEOUT_4K_CYCLES" -parent ${Page_0}
  ipgui::add_param $IPINST -name "ERASE_TIMEOUT_64K_CYCLES" -parent ${Page_0}
  ipgui::add_param $IPINST -name "FLASH_ADDR_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "FLASH_CLK_FREQ" -parent ${Page_0}
  ipgui::add_param $IPINST -name "FLASH_MODEL" -parent ${Page_0}
  ipgui::add_param $IPINST -name "FPGA_FAMILY" -parent ${Page_0}
  ipgui::add_param $IPINST -name "MULTIBOOT_ADDR_SHIFT" -parent ${Page_0}
  ipgui::add_param $IPINST -name "RD_DATA_MAX_LEN" -parent ${Page_0}
  ipgui::add_param $IPINST -name "S25_TBPARM_TOP" -parent ${Page_0}
  ipgui::add_param $IPINST -name "SYS_CLK_FREQ" -parent ${Page_0}
  ipgui::add_param $IPINST -name "UPDATE_BASE_ADDR" -parent ${Page_0}
  ipgui::add_param $IPINST -name "USE_STARTUP_FLASH_IO" -parent ${Page_0}
  ipgui::add_param $IPINST -name "WR_DATA_MAX_LEN" -parent ${Page_0}


}

proc update_PARAM_VALUE.C_S00_AXI_ADDR_WIDTH { PARAM_VALUE.C_S00_AXI_ADDR_WIDTH } {
	# Procedure called to update C_S00_AXI_ADDR_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_S00_AXI_ADDR_WIDTH { PARAM_VALUE.C_S00_AXI_ADDR_WIDTH } {
	# Procedure called to validate C_S00_AXI_ADDR_WIDTH
	return true
}

proc update_PARAM_VALUE.C_S00_AXI_DATA_WIDTH { PARAM_VALUE.C_S00_AXI_DATA_WIDTH } {
	# Procedure called to update C_S00_AXI_DATA_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_S00_AXI_DATA_WIDTH { PARAM_VALUE.C_S00_AXI_DATA_WIDTH } {
	# Procedure called to validate C_S00_AXI_DATA_WIDTH
	return true
}

proc update_PARAM_VALUE.DEVICE_ID { PARAM_VALUE.DEVICE_ID } {
	# Procedure called to update DEVICE_ID when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DEVICE_ID { PARAM_VALUE.DEVICE_ID } {
	# Procedure called to validate DEVICE_ID
	return true
}

proc update_PARAM_VALUE.ERASE_TIMEOUT_4K_CYCLES { PARAM_VALUE.ERASE_TIMEOUT_4K_CYCLES } {
	# Procedure called to update ERASE_TIMEOUT_4K_CYCLES when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.ERASE_TIMEOUT_4K_CYCLES { PARAM_VALUE.ERASE_TIMEOUT_4K_CYCLES } {
	# Procedure called to validate ERASE_TIMEOUT_4K_CYCLES
	return true
}

proc update_PARAM_VALUE.ERASE_TIMEOUT_64K_CYCLES { PARAM_VALUE.ERASE_TIMEOUT_64K_CYCLES } {
	# Procedure called to update ERASE_TIMEOUT_64K_CYCLES when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.ERASE_TIMEOUT_64K_CYCLES { PARAM_VALUE.ERASE_TIMEOUT_64K_CYCLES } {
	# Procedure called to validate ERASE_TIMEOUT_64K_CYCLES
	return true
}

proc update_PARAM_VALUE.FLASH_ADDR_WIDTH { PARAM_VALUE.FLASH_ADDR_WIDTH } {
	# Procedure called to update FLASH_ADDR_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.FLASH_ADDR_WIDTH { PARAM_VALUE.FLASH_ADDR_WIDTH } {
	# Procedure called to validate FLASH_ADDR_WIDTH
	return true
}

proc update_PARAM_VALUE.FLASH_CLK_FREQ { PARAM_VALUE.FLASH_CLK_FREQ } {
	# Procedure called to update FLASH_CLK_FREQ when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.FLASH_CLK_FREQ { PARAM_VALUE.FLASH_CLK_FREQ } {
	# Procedure called to validate FLASH_CLK_FREQ
	return true
}

proc update_PARAM_VALUE.FLASH_MODEL { PARAM_VALUE.FLASH_MODEL } {
	# Procedure called to update FLASH_MODEL when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.FLASH_MODEL { PARAM_VALUE.FLASH_MODEL } {
	# Procedure called to validate FLASH_MODEL
	return true
}

proc update_PARAM_VALUE.FPGA_FAMILY { PARAM_VALUE.FPGA_FAMILY } {
	# Procedure called to update FPGA_FAMILY when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.FPGA_FAMILY { PARAM_VALUE.FPGA_FAMILY } {
	# Procedure called to validate FPGA_FAMILY
	return true
}

proc update_PARAM_VALUE.MULTIBOOT_ADDR_SHIFT { PARAM_VALUE.MULTIBOOT_ADDR_SHIFT } {
	# Procedure called to update MULTIBOOT_ADDR_SHIFT when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.MULTIBOOT_ADDR_SHIFT { PARAM_VALUE.MULTIBOOT_ADDR_SHIFT } {
	# Procedure called to validate MULTIBOOT_ADDR_SHIFT
	return true
}

proc update_PARAM_VALUE.RD_DATA_MAX_LEN { PARAM_VALUE.RD_DATA_MAX_LEN } {
	# Procedure called to update RD_DATA_MAX_LEN when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.RD_DATA_MAX_LEN { PARAM_VALUE.RD_DATA_MAX_LEN } {
	# Procedure called to validate RD_DATA_MAX_LEN
	return true
}

proc update_PARAM_VALUE.S25_TBPARM_TOP { PARAM_VALUE.S25_TBPARM_TOP } {
	# Procedure called to update S25_TBPARM_TOP when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.S25_TBPARM_TOP { PARAM_VALUE.S25_TBPARM_TOP } {
	# Procedure called to validate S25_TBPARM_TOP
	return true
}

proc update_PARAM_VALUE.SYS_CLK_FREQ { PARAM_VALUE.SYS_CLK_FREQ } {
	# Procedure called to update SYS_CLK_FREQ when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.SYS_CLK_FREQ { PARAM_VALUE.SYS_CLK_FREQ } {
	# Procedure called to validate SYS_CLK_FREQ
	return true
}

proc update_PARAM_VALUE.UPDATE_BASE_ADDR { PARAM_VALUE.UPDATE_BASE_ADDR } {
	# Procedure called to update UPDATE_BASE_ADDR when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.UPDATE_BASE_ADDR { PARAM_VALUE.UPDATE_BASE_ADDR } {
	# Procedure called to validate UPDATE_BASE_ADDR
	return true
}

proc update_PARAM_VALUE.USE_STARTUP_FLASH_IO { PARAM_VALUE.USE_STARTUP_FLASH_IO } {
	# Procedure called to update USE_STARTUP_FLASH_IO when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.USE_STARTUP_FLASH_IO { PARAM_VALUE.USE_STARTUP_FLASH_IO } {
	# Procedure called to validate USE_STARTUP_FLASH_IO
	return true
}

proc update_PARAM_VALUE.WR_DATA_MAX_LEN { PARAM_VALUE.WR_DATA_MAX_LEN } {
	# Procedure called to update WR_DATA_MAX_LEN when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.WR_DATA_MAX_LEN { PARAM_VALUE.WR_DATA_MAX_LEN } {
	# Procedure called to validate WR_DATA_MAX_LEN
	return true
}


proc update_MODELPARAM_VALUE.C_S00_AXI_DATA_WIDTH { MODELPARAM_VALUE.C_S00_AXI_DATA_WIDTH PARAM_VALUE.C_S00_AXI_DATA_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_S00_AXI_DATA_WIDTH}] ${MODELPARAM_VALUE.C_S00_AXI_DATA_WIDTH}
}

proc update_MODELPARAM_VALUE.C_S00_AXI_ADDR_WIDTH { MODELPARAM_VALUE.C_S00_AXI_ADDR_WIDTH PARAM_VALUE.C_S00_AXI_ADDR_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_S00_AXI_ADDR_WIDTH}] ${MODELPARAM_VALUE.C_S00_AXI_ADDR_WIDTH}
}

proc update_MODELPARAM_VALUE.SYS_CLK_FREQ { MODELPARAM_VALUE.SYS_CLK_FREQ PARAM_VALUE.SYS_CLK_FREQ } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.SYS_CLK_FREQ}] ${MODELPARAM_VALUE.SYS_CLK_FREQ}
}

proc update_MODELPARAM_VALUE.FLASH_CLK_FREQ { MODELPARAM_VALUE.FLASH_CLK_FREQ PARAM_VALUE.FLASH_CLK_FREQ } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.FLASH_CLK_FREQ}] ${MODELPARAM_VALUE.FLASH_CLK_FREQ}
}

proc update_MODELPARAM_VALUE.RD_DATA_MAX_LEN { MODELPARAM_VALUE.RD_DATA_MAX_LEN PARAM_VALUE.RD_DATA_MAX_LEN } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.RD_DATA_MAX_LEN}] ${MODELPARAM_VALUE.RD_DATA_MAX_LEN}
}

proc update_MODELPARAM_VALUE.WR_DATA_MAX_LEN { MODELPARAM_VALUE.WR_DATA_MAX_LEN PARAM_VALUE.WR_DATA_MAX_LEN } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.WR_DATA_MAX_LEN}] ${MODELPARAM_VALUE.WR_DATA_MAX_LEN}
}

proc update_MODELPARAM_VALUE.FLASH_ADDR_WIDTH { MODELPARAM_VALUE.FLASH_ADDR_WIDTH PARAM_VALUE.FLASH_ADDR_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.FLASH_ADDR_WIDTH}] ${MODELPARAM_VALUE.FLASH_ADDR_WIDTH}
}

proc update_MODELPARAM_VALUE.UPDATE_BASE_ADDR { MODELPARAM_VALUE.UPDATE_BASE_ADDR PARAM_VALUE.UPDATE_BASE_ADDR } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.UPDATE_BASE_ADDR}] ${MODELPARAM_VALUE.UPDATE_BASE_ADDR}
}

proc update_MODELPARAM_VALUE.DEVICE_ID { MODELPARAM_VALUE.DEVICE_ID PARAM_VALUE.DEVICE_ID } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DEVICE_ID}] ${MODELPARAM_VALUE.DEVICE_ID}
}

proc update_MODELPARAM_VALUE.FPGA_FAMILY { MODELPARAM_VALUE.FPGA_FAMILY PARAM_VALUE.FPGA_FAMILY } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.FPGA_FAMILY}] ${MODELPARAM_VALUE.FPGA_FAMILY}
}

proc update_MODELPARAM_VALUE.MULTIBOOT_ADDR_SHIFT { MODELPARAM_VALUE.MULTIBOOT_ADDR_SHIFT PARAM_VALUE.MULTIBOOT_ADDR_SHIFT } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.MULTIBOOT_ADDR_SHIFT}] ${MODELPARAM_VALUE.MULTIBOOT_ADDR_SHIFT}
}

proc update_MODELPARAM_VALUE.USE_STARTUP_FLASH_IO { MODELPARAM_VALUE.USE_STARTUP_FLASH_IO PARAM_VALUE.USE_STARTUP_FLASH_IO } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.USE_STARTUP_FLASH_IO}] ${MODELPARAM_VALUE.USE_STARTUP_FLASH_IO}
}

proc update_MODELPARAM_VALUE.FLASH_MODEL { MODELPARAM_VALUE.FLASH_MODEL PARAM_VALUE.FLASH_MODEL } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.FLASH_MODEL}] ${MODELPARAM_VALUE.FLASH_MODEL}
}

proc update_MODELPARAM_VALUE.S25_TBPARM_TOP { MODELPARAM_VALUE.S25_TBPARM_TOP PARAM_VALUE.S25_TBPARM_TOP } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.S25_TBPARM_TOP}] ${MODELPARAM_VALUE.S25_TBPARM_TOP}
}

proc update_MODELPARAM_VALUE.ERASE_TIMEOUT_4K_CYCLES { MODELPARAM_VALUE.ERASE_TIMEOUT_4K_CYCLES PARAM_VALUE.ERASE_TIMEOUT_4K_CYCLES } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.ERASE_TIMEOUT_4K_CYCLES}] ${MODELPARAM_VALUE.ERASE_TIMEOUT_4K_CYCLES}
}

proc update_MODELPARAM_VALUE.ERASE_TIMEOUT_64K_CYCLES { MODELPARAM_VALUE.ERASE_TIMEOUT_64K_CYCLES PARAM_VALUE.ERASE_TIMEOUT_64K_CYCLES } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.ERASE_TIMEOUT_64K_CYCLES}] ${MODELPARAM_VALUE.ERASE_TIMEOUT_64K_CYCLES}
}

