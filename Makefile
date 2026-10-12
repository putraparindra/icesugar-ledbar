# Build LED bar untuk iCESugar v1.5 (iCE40UP5K-SG48) dengan OSS CAD Suite
#
#   make              -> top.bin
#   make sim          -> simulasi (iverilog) + dump top.vcd
#   make ACTIVE_LOW=0 -> jika LED bar Anda menyala saat pin = HIGH
#   make flash        -> build lalu salin ke drive iCELink (/media/<user>/iCELink)
#   make clean

PROJ       = top
ACTIVE_LOW ?= 1

ICELINK ?= /media/$(shell whoami)/iCELink

all: $(PROJ).bin

$(PROJ).json: top.v
	yosys -q -p "read_verilog top.v; chparam -set ACTIVE_LOW $(ACTIVE_LOW) top; synth_ice40 -top top -json $@"

$(PROJ).asc: $(PROJ).json led_bar.pcf
	nextpnr-ice40 --up5k --package sg48 --freq 12 --json $< --pcf led_bar.pcf --asc $@

$(PROJ).bin: $(PROJ).asc
	icepack $< $@

sim: tb_top.v top.v
	iverilog -g2005 -o tb.vvp tb_top.v top.v
	vvp tb.vvp

flash: $(PROJ).bin
	@test -d "$(ICELINK)" || { echo "Drive iCELink tidak ditemukan di $(ICELINK)"; exit 1; }
	cp $(PROJ).bin "$(ICELINK)/"
	sync
	@echo "Selesai: board akan reset dan menjalankan program."

clean:
	rm -f $(PROJ).json $(PROJ).asc $(PROJ).bin tb.vvp top.vcd

.PHONY: all sim flash clean
