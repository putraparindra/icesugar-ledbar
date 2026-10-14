# project.mk - pengaturan khusus project icesugar-ledbar (tata letak datar:
# semua file di satu folder). Letakkan di sebelah Makefile.
TOP_LEVEL = top
RTL_FILES = top.v
TB        = tb_top.v
PCF       = led_bar.pcf
VCD       = top.vcd
PARAMS    = ACTIVE_LOW=1
