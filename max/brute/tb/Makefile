# max/brute/tb/Makefile
# Sebastian Claudiusz Magierowski Nov 24 2025

SIM      ?= iverilog

TOP      ?= top # name of top-level module we want to simulate
EXE_DIR  ?= ../build
EXE      ?= $(EXE_DIR)/asic-exe

VC_DIR   := ../../../lib/vc
SM_DIR   := ../../../lib/sm
PROC_DIR := ../../../lib/proc

INCLUDES := -I $(VC_DIR) -I $(SM_DIR) -I $(PROC_DIR) -I ../rtl -I .
SRC_TOP  := asic.t.v

all: run

$(EXE_DIR):
	mkdir -p $(EXE_DIR)

build: $(EXE_DIR)
ifeq ($(SIM),iverilog)
	iverilog -g2012 \
	  -Wall -Wno-sensitivity-entire-vector -Wno-sensitivity-entire-array \
	  $(INCLUDES) \
	  -s $(TOP) \
	  -o $(EXE) \
	  $(SRC_TOP)
else
	@echo "SIM=$(SIM) not yet supported"
	exit 1
endif

run: build
	$(EXE) +verbose=1 +trace=1 +test-case=1

clean:
	rm -f $(EXE_DIR)/asic-exe $(EXE_DIR)/*.vcd