# Makefile
# See https://docs.cocotb.org/en/stable/quickstart.html for more info

# defaults
SIM ?= icarus
TOPLEVEL_LANG ?= verilog

ifneq ($(GATES),yes)
# normal simulation
VERILOG_SOURCES += $(PWD)/tb.v $(PWD)/hovalaag_wrapper.v $(PWD)/hovalaag_tiny_tapeout.v $(PWD)/decoder.v $(PWD)/ring_oscillator.v $(PWD)/HovalaagCPU/Hovalaag.v
COMPILE_ARGS += -I$(PWD)/HovalaagCPU
COMPILE_ARGS    += -DSIM
else
# copy the gatelevel verilog from /runs/wokwi/results/final/verilog/gl/ and commit to this directory
VERILOG_SOURCES := $(PWD)/tb.v gate_level_netlist.v inv_with_delay.v

# gate level simulation requires some extra setup
COMPILE_ARGS    += -DGL_TEST
COMPILE_ARGS    += -DFUNCTIONAL
COMPILE_ARGS    += -DUSE_POWER_PINS
COMPILE_ARGS    += -DSIM
COMPILE_ARGS    += -DUNIT_DELAY=#1
VERILOG_SOURCES += $(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/verilog/primitives.v
VERILOG_SOURCES += $(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/verilog/sky130_fd_sc_hd.v
endif

# TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
TOPLEVEL = tb

# MODULE is the basename of the Python test file
MODULE = test

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim

gate_level_netlist.v: ../runs/wokwi/results/final/verilog/gl/*.v
	rm -f ../runs/wokwi/results/final/verilog/gl/*.nl.v
	cp ../runs/wokwi/results/final/verilog/gl/*.v gate_level_netlist.v
	sed -i '/sky130_fd_sc_hd__inv_[12] \\wrapper\.rosc\..*\.inv/s/sky130_fd_sc_hd__inv_[12]/inv_with_delay/' gate_level_netlist.v

clean::
	rm -f gate_level_netlist.v