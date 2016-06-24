.include "m32def.inc"
.cseg
.org 0
rjmp setup

setup:
		cli
		; Create stack
	        ldi r16, low(RAMEND)
	        out SPL, r16
	        ldi r16, high(RAMEND)
	        out SPH, r16

		ldi r16, 0b11000000
		out DDRD, r16
		ldi r16, 0b01000000
		out PORTD, r16
		
		; Set up SPI
		ldi r16, 0b10100000
		out DDRB, r16
		ldi r16, (1 << SPE) | (1 << MSTR) | (1 << SPR0)
		out SPCR, r16

		sei
		nop

testmain:
	ldi r16, 0b10000000
	out PORTD, r16

	rcall delay
	rcall delay
	rcall delay
	rcall delay
	rcall delay
	rcall delay
	rcall delay
	rcall delay
	rcall delay
	rcall delay
	rcall delay
	rcall delay

	ldi r16, 0xFF
	rcall spi_send

	rcall delay
	rcall delay
	rcall delay
	rcall delay
	rcall delay
	rcall delay
	rcall delay
	rcall delay
	rcall delay
	rcall delay
	rcall delay
	ldi r16, 0b0100000
	out PORTD, r16

spi_send:
	out SPDR, r16
rr_wait: sbis SPSR, SPIF
	rjmp rr_wait
	ret

stop:
	rjmp stop

;	Read ENC control register
;	Address in r16
;	Result in r16
enc_readreg:
		andi r16, 0b00011111
		out SPDR, r16
enc_readreg_wait:
		sbis SPSR, SPIF
		rjmp enc_readreg_wait
		ldi r16, 0xFF
		out SPDR, r16
enc_readreg_wait_2:
		sbis SPSR, SPIF
		rjmp enc_readreg_wait_2
		in r16, SPDR
		ret


delay:
        ldi r17, 0xFF
delay_inner:
        dec r17
        brne delay_inner
        ret
