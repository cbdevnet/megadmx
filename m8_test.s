.include "m8def.inc"
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

		; LED Port
		ldi r16, 0xFF
		out DDRC, r16
		
		; Set up UART port
		ldi r16, 0b00000010
		out DDRD, r16
		
		; Set up SPI / ENC Port
		ldi r16, 0b00101101
		out DDRB, r16
		ldi r16, (1 << SPE) | (1 << MSTR) | (1 << SPR0)
		out SPCR, r16

		sei
		nop

	ldi r19, 0x01
testmain:
	out PORTC, r19
	rcall longdelay
	rol r19
	rjmp testmain

	ldi r16, 0x0
	out PORTC, r16
	rcall longdelay
	rjmp testmain

spi_send:
	out SPDR, r16
rr_wait: sbis SPSR, SPIF
	rjmp rr_wait
	ret

stop:
	rjmp stop

;	Delay functions
;	Clobbers r16, r17
longdelay:
		ldi r16, 0xFF
longdelay_inner:
		rcall delay
		dec r16
		brne longdelay_inner
		ret

delay:
	        ldi r17, 0xFF
delay_inner:
	        dec r17
	        brne delay_inner
	        ret
