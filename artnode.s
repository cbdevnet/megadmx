.include "m32def.inc"
.cseg
.org 0
rjmp setup

.include "enc.s"

.equ PIN_LED1 = 5
.equ PIN_LED2 = 7
.equ PIN_CSEL = 6
.equ PIN_CINT = 4

setup:
		cli
		; Create stack
	        ldi r16, low(RAMEND)
	        out SPL, r16
	        ldi r16, high(RAMEND)
	        out SPH, r16

		ldi r16, 0b11100000
		out DDRD, r16
		ldi r16, 0b01010000
		out PORTD, r16

		ldi r16, 25
		out UBRRL, r16
		ldi r16, (1 << TXEN)
		out UCSRB, r16
		;ldi r16, (1 << URSEL) | (1 << UCSZ1)
		ldi r16, (1 << URSEL) | (1 << UCSZ0) | (1 << UCSZ1)
		out UCSRC, r16
		
		; Set up SPI
		ldi r16, 0b10100000
		out DDRB, r16
		ldi r16, (1 << SPE) | (1 << MSTR) | (1 << SPR0) | (1 << SPR1)
		out SPCR, r16

		sei
		nop

		rjmp enc_main

stop:		rjmp stop

led1on:
		sbi PORTD, PIN_LED1
		ret

led2on:
		sbi PORTD, PIN_LED2
		ret

led1off:
		cbi PORTD, PIN_LED1
		ret

led2off:
		cbi PORTD, PIN_LED2
		ret

enc_main:
	rcall enc_setup

mloop:
	; Check for link
	; Set LED
	; Check for interrupt
	sbis PIND, PIN_CINT
	rcall detected
	rcall tx_demo
	rjmp mloop

detected:
	rcall led2on
	rcall enc_packet_ack
	rcall enc_clearint
	rcall longdelay
	rcall led2off
	ret

tx_demo:
	ldi r16, 46
	rcall enc_sendpkt_prepare
	rcall enc_writebuffer_start
	
	ldi r16, 0
	rcall spi_send

	; MAC
	ldi r16, 0xFF
	rcall spi_send
	rcall spi_send
	rcall spi_send
	rcall spi_send
	rcall spi_send
	rcall spi_send
	ldi r16, 0x5C
	rcall spi_send
	ldi r16, 0xFF
	rcall spi_send
	ldi r16, 0x35
	rcall spi_send
	ldi r16, 0xCB
	rcall spi_send
	ldi r16, 0xCB
	rcall spi_send
	ldi r16, 0xCB
	rcall spi_send
	ldi r16, 0x08
	rcall spi_send
	ldi r16, 0x00
	rcall spi_send

	; IP
	ldi r16, 0x45
	rcall spi_send
	ldi r16, 0
	rcall spi_send
	ldi r16, 0
	rcall spi_send
	ldi r16, 20+12
	rcall spi_send
	ldi r16, 0
	rcall spi_send
	ldi r16, 0
	rcall spi_send
	ldi r16, 0
	rcall spi_send
	ldi r16, 0
	rcall spi_send
	ldi r16, 42
	rcall spi_send
	ldi r16, 17
	rcall spi_send
	ldi r16, 0
	rcall spi_send
	ldi r16, 0
	rcall spi_send
	ldi r16, 129
	rcall spi_send
	ldi r16, 13
	rcall spi_send
	ldi r16, 215
	rcall spi_send
	ldi r16, 90
	rcall spi_send
	ldi r16, 255
	rcall spi_send
	ldi r16, 255
	rcall spi_send
	ldi r16, 255
	rcall spi_send
	ldi r16, 255
	rcall spi_send

	; UDP
	ldi r16, high(8080)
	rcall spi_send
	ldi r16, low(8080)
	rcall spi_send
	ldi r16, high(8080)
	rcall spi_send
	ldi r16, low(8080)
	rcall spi_send
	ldi r16, 0
	rcall spi_send
	ldi r16, 12
	rcall spi_send
	ldi r16, 0
	rcall spi_send
	ldi r16, 0
	rcall spi_send
	ldi r16, 'H'
	rcall spi_send
	ldi r16, 'E'
	rcall spi_send
	ldi r16, 'L'
	rcall spi_send
	ldi r16, 'O'
	rcall spi_send
	rcall enc_disa
	rcall enc_sendpkt_xmit
	ret


txloop:
		ldi r16, 'C'
		out UDR, r16
dotx:
		sbis UCSRA, UDRE
		rjmp dotx
		rjmp txloop


flashloop:
	ldi ZL, low(str1)
	ldi ZH, high(str1)
	rcall uart_txflash
	rjmp flashloop

;	Transmit string from flash via UART
;	String address in ZH/ZL hi/lo
;	Clobbers: r16
uart_txflash:
		; Load data from flash
		lpm r16, Z+
		; Test for string end
		tst r16
		breq uart_txflash_end
		; Wait until buffer ready
uart_txflash_wait:
		sbis UCSRA, UDRE
		rjmp uart_txflash_wait
		; Output byte
		out UDR, r16
		rjmp uart_txflash
uart_txflash_end:
		; Make sure transmission is done
		sbis UCSRA, UDRE
		rjmp uart_txflash_end
		ret

;	Delay functions
;	Clobber: r16, r17
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


str1:	.DB "Yay this seems to work! \0"
