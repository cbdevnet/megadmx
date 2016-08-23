.PHONY: all clean

# Programmer options
PROGRAMMER=-c stk500v2 -P /dev/ttyACM0
#PROGRAMMER=-c usbasp 

# t13
PART=t13
LFUSE_1=0x6a
LFUSE_8=0x7a
HFUSE_1=0xff
HFUSE_8=0xff

all: receiver

install:
	avrdude -p $(PART) $(PROGRAMMER) -U receiver.s.hex

speed-8:
	avrdude -p $(PART) $(PROGRAMMER) -U lfuse:w:$(LFUSE_8):m -U hfuse:w:$(HFUSE_8):m

speed-1:
	avrdude -p $(PART) $(PROGRAMMER) -U lfuse:w:$(LFUSE_1):m -U hfuse:w:$(HFUSE_1):m

receiver:
	avra receiver.s

clean:
	$(RM) *.obj *.hex *.cof
