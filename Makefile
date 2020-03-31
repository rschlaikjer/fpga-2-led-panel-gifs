PROJ := top
PIN_DEF := hx4k_pmod.pcf
DEVICE := hx8k
PACKAGE := tq144:4k
ARGS := -dsp
FREQ := 48
ADD_SRC := ice_pll.v pixel_ram.v pixel_ram_block.v panel_driver.v

all: $(PROJ).rpt $(PROJ).bin

%.json: %.v $(ADD_SRC) $(ADD_DEPS)
	yosys -l $*.log -p 'synth_ice40 $(ARGS) -top $(PROJ) -json $@' $< $(ADD_SRC)

%.asc: $(PIN_DEF) %.json
	nextpnr-ice40 --$(DEVICE) \
		$(if $(PACKAGE),--package $(PACKAGE)) \
		$(if $(FREQ),--freq $(FREQ)) \
		--json $(filter-out $<,$^) \
		--pcf $< \
		--asc $@

%.bin: %.asc
	icepack $< $@

%.rpt: %.asc
	icetime $(if $(FREQ),-c $(FREQ)) -d $(DEVICE) -mtr $@ $<

prog: $(PROJ).bin
	faff -f $<

clean:
	rm -f $(PROJ).blif $(PROJ).asc $(PROJ).rpt $(PROJ).bin $(PROJ).json $(PROJ).log $(ADD_CLEAN)

.SECONDARY:
.PHONY: all prog clean
