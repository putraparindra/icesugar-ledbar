# =====================================================================
#  Makefile generik: FPGA iCE40 (iCESugar) + OSS CAD Suite
#  Linux, macOS, WSL, dan Windows (GNU make).
#
#  Tata letak mengikuti oss-cad-suite-tcl-template:
#      rtl/  tb/  constraints/  build/
#
#  Satu Makefile untuk semua project. Yang berbeda antar project cukup
#  ditulis di file  project.mk  (opsional, di sebelah Makefile ini),
#  atau di baris perintah. Contoh isi project.mk:
#      TOP_LEVEL = top_blinky
#
#  Target (nama sama dengan template):
#    make            sama dengan make all: syn + pnr + bit
#    make syn        sintesis Yosys      -> build/<top>_netlist.json
#    make pnr        place and route     -> build/<top>.asc
#    make bit        bitstream           -> build/<top>.bin
#    make compile    kompilasi iverilog  -> build/<top>_sim
#    make vvp        jalankan simulasi
#    make gtk        buka gelombang di GTKWave
#    make sim        compile + vvp + gtk
#    make test       compile + vvp (tanpa GUI)
#    make flash      salin .bin ke drive iCELink (atau pakai FLASH_CMD)
#    make clean      hapus folder build
#    make doctor     cek tool terpasang
#    make help       bantuan singkat
#
#  Variabel (di project.mk atau baris perintah, mis. make TOP_LEVEL=abc):
#    TOP_LEVEL    nama module teratas (juga dasar nama file pcf/tb)
#    DIR_RTL DIR_TB DIR_CONS DIR_BUILD   nama folder
#    RTL_FILES    daftar file Verilog (default: semua rtl/*.v)
#    PCF TB VCD   file constraint, testbench, dan dump gelombang
#    PARAMS       override parameter module, mis. "ACTIVE_LOW=0 STEP_HZ=4"
#    SYNTH_FLAGS  opsi synth_ice40 (default: Windows -noabc, lainnya -noabc9)
#    FREQ         frekuensi clock untuk nextpnr dalam MHz (default 12)
#    OSS_CAD      folder oss-cad-suite bila belum diaktifkan lewat
#                 environment / environment.bat (Windows: pakai C:/oss-cad-suite)
#    ICELINK      folder drive iCELink bila tidak terdeteksi otomatis
#    FLASH_CMD    program lain untuk upload, mis. FLASH_CMD=icesprog
# =====================================================================

-include project.mk

# ---------------------------- Pengaturan -----------------------------
TOP_LEVEL     ?= top

DIR_RTL       ?= rtl
DIR_TB        ?= tb
DIR_CONS      ?= constraints
DIR_BUILD     ?= build

RTL_FILES     ?= $(wildcard $(DIR_RTL)/*.v)
PCF           ?= $(DIR_CONS)/$(TOP_LEVEL).pcf
TB            ?= $(DIR_TB)/$(TOP_LEVEL)_tb.v
VCD           ?= $(DIR_BUILD)/$(TOP_LEVEL)_tb.vcd
PARAMS        ?=

FREQ          ?= 12
NEXTPNR_FLAGS ?= --up5k --package sg48
IVERILOG_FLAGS ?= -g2005

# Catatan SYNTH_FLAGS (hasil uji nyata, OSS CAD Suite 2026-07-27):
#  - Windows: abc9 crash dengan pesan
#        Assert `data_start == f->tellp()' failed in aiger2/aiger.cc
#    walau memakai -noabc9. Yang terbukti jalan adalah -noabc (pemetaan
#    LUT bawaan Yosys, tanpa ABC; hasilnya lebih besar, 213 LC).
#  - Linux: -noabc9 mematikan abc9 dan hasilnya paling kecil (170 LC).
#    -noabc SENDIRIAN malah error ("-abc9 is incompatible with -noabc");
#    kalau mau tanpa ABC di Linux pakai: make "SYNTH_FLAGS=-noabc9 -noabc"
#  - Mau abc9 penuh di Linux (174 LC): make SYNTH_FLAGS=
ifeq ($(OS),Windows_NT)
  SYNTH_FLAGS ?= -noabc
else
  SYNTH_FLAGS ?= -noabc9
endif

FLASH_CMD     ?=
OSS_CAD       ?=
ICELINK       ?=

NETLIST := $(DIR_BUILD)/$(TOP_LEVEL)_netlist.json
ASC     := $(DIR_BUILD)/$(TOP_LEVEL).asc
BIN     := $(DIR_BUILD)/$(TOP_LEVEL).bin
SIMEXE  := $(DIR_BUILD)/$(TOP_LEVEL)_sim

# PARAMS="A=1 B=2" -> "chparam -set A 1 top; chparam -set B 2 top;"
CHPARAM = $(foreach p,$(PARAMS),chparam -set $(firstword $(subst =, ,$(p))) $(lastword $(subst =, ,$(p))) $(TOP_LEVEL);)

# ------------------------ Perbedaan antar OS --------------------------
ifeq ($(OS),Windows_NT)
  # Windows biasanya tidak punya mkdir -p/rm/cp, jadi dipakai python3 bawaan
  # OSS CAD Suite (aktif setelah environment.bat).
  PY    ?= python3
  MKDIR  = $(PY) -c "import os,sys; os.makedirs(sys.argv[1], exist_ok=True)"
  RM_RF  = $(PY) -c "import os,shutil,sys; [shutil.rmtree(p) if os.path.isdir(p) else os.remove(p) for p in sys.argv[1:] if os.path.exists(p)]"
  CP     = $(PY) -c "import shutil,sys; shutil.copy(sys.argv[1], sys.argv[2])"
  SYNC   =
  IV_VER = iverilog -V | $(PY) -c "import sys; print(next((l.strip() for l in sys.stdin if 'Icarus Verilog version' in l),''))"
  # Cari drive iCELink lewat icelink.py (huruf drive beda-beda di tiap komputer).
  # Baru dijalankan saat "make flash", jadi tidak memperlambat target lain.
  ICELINK_AUTO = $(shell $(PY) icelink.py)
  ifneq ($(strip $(OSS_CAD)),)
    OSS_WIN := $(subst /,\,$(strip $(OSS_CAD)))
    export PATH := $(OSS_WIN)\bin;$(OSS_WIN)\lib;$(PATH)
  endif
else
  MKDIR  = mkdir -p
  RM_RF  = rm -rf
  CP     = cp
  SYNC   = sync
  IV_VER = iverilog -V | grep -m1 "Icarus Verilog version"
  ifneq ($(strip $(OSS_CAD)),)
    export PATH := $(strip $(OSS_CAD))/bin:$(PATH)
  endif
endif

# Lokasi drive iCELink (Linux/macOS), kecuali sudah diberikan lewat ICELINK=
ifeq ($(strip $(ICELINK)),)
  USER_NAME := $(or $(USER),$(USERNAME),$(shell whoami))
  ICELINK   := $(firstword $(wildcard /media/$(USER_NAME)/iCELink /run/media/$(USER_NAME)/iCELink /Volumes/iCELink))
endif

# Folder tujuan flash: ICELINK= dari pengguna, kalau kosong pakai deteksi otomatis
FLASH_DIR = $(or $(strip $(ICELINK)),$(strip $(ICELINK_AUTO)))

# ------------- Deteksi perubahan opsi (PARAMS, SYNTH_FLAGS) -----------
# Tanpa ini, "make PARAMS=ACTIVE_LOW=0" setelah "make" tidak membangun
# ulang apa pun karena file sumbernya tidak berubah. Perlu GNU make 4.2+.
# Di make yang lebih lama (mis. 3.81) bagian ini dilewati, jadi jalankan
# "make clean" setiap kali mengubah opsi.
STAMP :=
ifeq ($(filter 3.% 4.0% 4.1%,$(MAKE_VERSION)),)
  STAMP      := .build_config
  CONFIG_NOW := TOP=$(TOP_LEVEL);RTL=$(RTL_FILES);PCF=$(PCF);PARAMS=$(PARAMS);SYNTH=$(SYNTH_FLAGS);PNR=$(NEXTPNR_FLAGS) $(FREQ)
  ifneq ($(file <$(STAMP)),$(CONFIG_NOW))
    $(file >$(STAMP),$(CONFIG_NOW))
  endif
endif

# ------------------------------ Build --------------------------------
.DELETE_ON_ERROR:

all: $(BIN)
syn: $(NETLIST)
pnr: $(ASC)
bit: $(BIN)

$(DIR_BUILD):
	$(MKDIR) $(DIR_BUILD)

$(NETLIST): $(RTL_FILES) $(STAMP) | $(DIR_BUILD)
	$(if $(RTL_FILES),,$(error Tidak ada file Verilog. Cek DIR_RTL atau RTL_FILES))
	yosys -q -p "read_verilog $(RTL_FILES); $(CHPARAM) synth_ice40 $(SYNTH_FLAGS) -top $(TOP_LEVEL) -json $@"

$(ASC): $(NETLIST) $(PCF) | $(DIR_BUILD)
	nextpnr-ice40 $(NEXTPNR_FLAGS) --freq $(FREQ) --json $(NETLIST) --pcf $(PCF) --asc $@

$(BIN): $(ASC)
	icepack $< $@

# ---------------------------- Simulasi -------------------------------
compile: $(SIMEXE)

$(SIMEXE): $(TB) $(RTL_FILES) | $(DIR_BUILD)
	iverilog $(IVERILOG_FLAGS) -o $@ $(TB) $(RTL_FILES)

vvp: compile
	vvp $(SIMEXE)

gtk:
	gtkwave $(VCD)

sim: vvp
	gtkwave $(VCD)

test: vvp

# ------------------------------ Upload -------------------------------
flash: $(BIN)
ifneq ($(strip $(FLASH_CMD)),)
	$(FLASH_CMD) $(BIN)
else
	$(if $(FLASH_DIR),,$(error Drive iCELink tidak ditemukan. Colok board, lalu jalankan: make flash ICELINK=lokasi-drive))
	$(CP) $(BIN) "$(FLASH_DIR)"
	$(SYNC)
	@echo Selesai: board akan reset dan menjalankan program.
endif

# ------------------------------ Lainnya ------------------------------
drives:
	$(PY) icelink.py --list

doctor:
	-yosys -V
	-nextpnr-ice40 --version
	-$(IV_VER)

clean:
	$(if $(filter-out . .. ./ ../ /,$(strip $(DIR_BUILD))),,$(error DIR_BUILD tidak aman untuk clean: "$(DIR_BUILD)"))
	$(RM_RF) $(DIR_BUILD) $(STAMP) $(VCD)

help:
	$(info make          build bitstream ($(BIN)))
	$(info make syn      sintesis saja)
	$(info make pnr      sintesis + place and route)
	$(info make bit      bitstream)
	$(info make compile  kompilasi simulasi)
	$(info make vvp      jalankan simulasi)
	$(info make gtk      buka gelombang)
	$(info make sim      compile + vvp + gtk)
	$(info make test     compile + vvp tanpa GUI)
	$(info make flash    salin ke drive iCELink)
	$(info make clean    hapus folder build)
	$(info make doctor   cek tool terpasang)
	$(info make drives   daftar drive Windows (cari iCELink))
	$(info Variabel: TOP_LEVEL PARAMS SYNTH_FLAGS OSS_CAD ICELINK FLASH_CMD ...)
	@:

.PHONY: drives all syn pnr bit compile vvp gtk sim test flash doctor clean help
