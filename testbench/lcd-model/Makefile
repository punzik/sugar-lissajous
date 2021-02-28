SOURCE_DIR = ../../source

SOURCES = testbench_top.cpp			\
	  testbench_top.sv			\
	  lcd_ili9341_4spi.sv			\
	  $(SOURCE_DIR)/sugar_lissajous.sv	\
	  $(SOURCE_DIR)/pll_lock_reset.sv	\
	  $(SOURCE_DIR)/pll.sv			\
	  $(SOURCE_DIR)/mcp3201_ma.sv		\
	  $(SOURCE_DIR)/lfsr.sv			\
	  $(SOURCE_DIR)/lcd_top.sv		\
	  $(SOURCE_DIR)/lcd_spi.sv		\
	  $(SOURCE_DIR)/ice40_spram.sv		\
	  $(SOURCE_DIR)/ice40_mac16x16.sv

SOURCES += ../../../local/share/yosys/ice40/cells_sim.v

TOP_MODULE = testbench_top

FLAGS = -DTESTBENCH -Wno-WIDTH -cc -I$(SOURCE_DIR) --top-module $(TOP_MODULE) +1800-2017ext+sv -I$(SOURCE_DIR)
#FLAGS += --threads 8
FLAGS += --trace

all: $(SOURCES)
	verilator $(FLAGS) --exe --build -o $(TOP_MODULE) $(SOURCES)

pre:
	verilator $(FLAGS) -o $(TOP_MODULE) $(SOURCES)

clean:
	rm -rf obj_dir
