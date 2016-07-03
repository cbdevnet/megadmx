.PHONY: all clean

all: artnode

install:
	avrdude -p m32 -c stk500v2 -P /dev/ttyACM0 -U artnode.s.hex

install-8:
	avrdude -p m32 -c stk500v2 -P /dev/ttyACM0 -U artnode.s.hex -U lfuse:w:0xe4:m -U hfuse:w:0x99:m

install-1:
	avrdude -p m32 -c stk500v2 -P /dev/ttyACM0 -U artnode.s.hex -U lfuse:w:0xe1:m -U hfuse:w:0x99:m

artnode:
	avra artnode.s

clean:
	$(RM) *.obj *.hex *.cof
