SOURCES = $(wildcard source/*.sv)
TOP = sugar_lissajous
PCF = icesugar.pcf

FAMILY = up5k
PACKAGE = sg48
FREQ = 30

#DOSVG = --placed-svg place.svg --routed-svg route.svg
# nextpnr --randomize-seed write_verilog $(TOP).v

BUILD_DIR ?= build

TOP_BIN = $(BUILD_DIR)/$(TOP).bin
TOP_ASC = $(BUILD_DIR)/$(TOP).asc
TOP_JSON = $(BUILD_DIR)/$(TOP).json

all: $(TOP_BIN)

# Make bitstream
$(TOP_BIN): $(TOP_ASC)
	icepack $(TOP_ASC) $(TOP_BIN)

# Place and rouite
$(TOP_ASC): $(TOP_JSON) $(PCF)
	nextpnr-ice40 -q -l $(BUILD_DIR)/nextpnr.log --$(FAMILY) --package $(PACKAGE) \
		--top $(TOP) --pcf $(PCF) --asc $(TOP_ASC) --json $(TOP_JSON) \
		$(DOSVG)

# Synthesys
$(TOP_JSON): $(SOURCES)
	mkdir -p $(BUILD_DIR)
	yosys -q -l $(BUILD_DIR)/yosys.log -p \
		"proc; alumacc; share -fast; opt -full; synth_ice40 -top $(TOP) -json $(TOP_JSON) -abc2" \
		$(SOURCES)

# Timing analysis
timing: $(TOP_ASC)
	icetime -d $(FAMILY) -t -c $(FREQ) -r $(BUILD_DIR)/timing.log $(TOP_ASC)

# Program
prog: $(TOP_BIN)
	icesprog -w $(TOP_BIN)

# Clean
clean:
	rm -rf $(BUILD_DIR)

# Convert SVG to PNG
png: route.png place.png

route.png: route.svg
	inkscape --export-type=png -o route.png -D -d 100 route.svg

place.png: place.svg
	inkscape --export-type=png -o place.png -D -d 150 place.svg
