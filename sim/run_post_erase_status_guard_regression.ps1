$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoDir   = Split-Path -Parent $scriptDir
$srcDir    = Join-Path $repoDir 'src'
$hdlDir    = Join-Path $repoDir 'hdl'
$vivadoBin = 'D:\software_work\vivado2019\Vivado\2019.1\bin'
$vivadoData = 'D:\software_work\vivado2019\Vivado\2019.1\data\verilog\src'
$xvlog     = Join-Path $vivadoBin 'xvlog.bat'
$xelab     = Join-Path $vivadoBin 'xelab.bat'
$xsim      = Join-Path $vivadoBin 'xsim.bat'
$incDir    = Join-Path $srcDir 'axis_data_fifo_4bytes\hdl'
$glblFile  = Join-Path $vivadoData 'glbl.v'

$sourceFiles = @(
    (Join-Path $hdlDir 'axi_multiboot_driver_v1_0_S00_AXI.v'),
    (Join-Path $hdlDir 'axi_multiboot_driver_v1_0.v'),
    (Join-Path $srcDir 'cmd_decoder.v'),
    (Join-Path $srcDir 'flash_ctrl.v'),
    (Join-Path $srcDir 'flash_driver.v'),
    (Join-Path $srcDir 'flash_top.v'),
    (Join-Path $srcDir 'icap_jump.v'),
    (Join-Path $srcDir 'startup_bridge.v'),
    (Join-Path $srcDir 'axis_data_fifo_4bytes\hdl\axis_infrastructure_v1_1_vl_rfs.v'),
    (Join-Path $srcDir 'axis_data_fifo_4bytes\hdl\axis_data_fifo_v2_0_vl_rfs.v'),
    (Join-Path $srcDir 'axis_data_fifo_4bytes\sim\axis_data_fifo_4bytes.v'),
    $glblFile,
    (Join-Path $scriptDir 'tb_spi_flash_model.v'),
    (Join-Path $scriptDir 'tb_axi_multiboot_driver.v')
)

$tops = @(
    'tb_axi_multiboot_driver_s25_post_erase_guard_fail',
    'tb_axi_multiboot_driver_s25_post_erase_guard_pass'
)

Push-Location $scriptDir
try {
    & $xvlog '-i' $incDir @sourceFiles
    if ($LASTEXITCODE -ne 0) {
        throw 'xvlog failed'
    }

    foreach ($top in $tops) {
        $snapshot = "${top}_snap"
        & $xelab '-debug' 'typical' '-L' 'xpm' '-L' 'unisims_ver' $top 'glbl' '-s' $snapshot
        if ($LASTEXITCODE -ne 0) {
            throw "xelab failed for $top"
        }
        $xsimOutput = & $xsim $snapshot '-runall' 2>&1 | Out-String
        Write-Host $xsimOutput -NoNewline
        if ($LASTEXITCODE -ne 0) {
            throw "xsim failed for $top"
        }
        if ($xsimOutput -match '\[TB\]\[FAIL\]') {
            throw "testbench failed for $top"
        }
    }
}
finally {
    Pop-Location
}
