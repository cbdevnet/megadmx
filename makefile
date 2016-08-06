.PHONY: all clean

# Programmer options
#PROGRAMMER=-c stk500v2 -P /dev/ttyACM0
PROGRAMMER=-c usbasp 

# Mega8
PART=m8
LFUSE_1=0xe1
LFUSE_8=0xe4
HFUSE_1=0xd9
HFUSE_8=0xd9

# Mega32
#PART=m32
#LFUSE_1=0xe4
#LFUSE_8=0xe1
#HFUSE_1=0x99
#HFUSE_8=0x99

all: megadmx

install:
	avrdude -p $(PART) $(PROGRAMMER) -U megadmx.s.hex

speed-8:
	avrdude -p $(PART) $(PROGRAMMER) -U lfuse:w:$(LFUSE_8):m -U hfuse:w:$(HFUSE_8):m

speed-1:
	avrdude -p $(PART) $(PROGRAMMER) -U lfuse:w:$(LFUSE_1):m -U hfuse:w:$(HFUSE_1):m

megadmx:
	avra megadmx.s

clean:
	$(RM) *.obj *.hex *.cof
