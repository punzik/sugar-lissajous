VC  = iverilog
VI  = vvp

#SOURCES = ../source/lcd_320x240_spi.sv
SOURCES = $(wildcard ../source/*.sv)
SOURCES += ../../local/share/yosys/ice40/cells_sim.v

VFLAGS  = -g2012 -I../source
TBS = $(wildcard tb_*.sv)
DEFINES = -D TESTBENCH
VCDDEPS = $(TBS:.sv=.vcd)
BINDEPS = $(TBS:.sv=.bin)

all: $(VCDDEPS)

.SECONDARY:
#.SILENT: $(VCDDEPS) $(BINDEPS) clean

%.vcd: %.bin
	@echo "Simulate :" $(<:.bin=.sv)
	$(VI) $< #> $(<:.bin=.out)

%.bin: %.sv $(SOURCES)
	@echo "Compile  :" $(@:.bin=.sv)
	$(VC) $(VFLAGS) $(DEFINES) -D DUMPFILE=\"$(@:.bin=.vcd)\" -o $@ $< $(SOURCES)

clean:
	@echo "Remove *.bin, *.vcd, *.out"
	rm -rf *.bin
	rm -rf *.out
	rm -rf *.vcd
