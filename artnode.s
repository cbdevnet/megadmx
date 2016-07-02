.include "m32def.inc"
.cseg
.org 0
rjmp setup

.equ PIN_LED1 = 5
.equ PIN_LED2 = 7
.equ PIN_CSEL = 6
.equ PIN_CINT = 4

.include "enc.s"

setup:
		cli
		; Create stack
	        ldi r16, low(RAMEND)
	        out SPL, r16
	        ldi r16, high(RAMEND)
	        out SPH, r16

		; Set up I/O port
		ldi r16, 0b11100000
		out DDRD, r16
		ldi r16, 0b01010000
		out PORTD, r16

		; Set up UART
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

		; Set up the ENC
		rcall enc_setup

		; Run the main loop
		rjmp main

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

main:
	; Check for link
	; Set LED
	; Check for interrupt
	sbis PIND, PIN_CINT
	rcall detected
	rcall xmit_dummy_pkt
	rjmp main

detected:
	rcall led2on
	rcall enc_packet_ack
	rcall enc_clearint
	rcall longdelay
	rcall led2off
	ret

xmit_dummy_pkt:
	ldi r16, 46
	rcall enc_sendpkt_prepare
	rcall enc_writebuffer_start

	; Control byte
	ldi r16, 0
	rcall spi_send

	; Packet contents
	ldi ZL, low(dummy_pkt << 1)
	ldi ZL, high(dummy_pkt << 1)
	ldi r16, 46
	rcall spi_flash_xmit

	rcall enc_disa
	rcall enc_sendpkt_xmit
	ret

flashloop:
	ldi ZL, low(str1 << 1)
	ldi ZH, high(str1 << 1)
	rcall uart_txflash
	rjmp flashloop



;	Transmit string from flash via UART
;	String address << 1 in ZH/ZL hi/lo
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

;	Transmit flash data to SPI
;	Address << 1 in ZH/ZL
;	Length in r16
;	Clobbers r16, r17
spi_flash_xmit:
		mov r17, r16
spi_flash_xmit_1:
		tst r17
		breq spi_flash_xmit_end
		lpm r16, Z+
		rcall spi_send
		dec r17
		rjmp spi_flash_xmit_1
spi_flash_xmit_end:
		ret

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


str1:	.DB "Yay this seems to work! \0"

dummy_pkt:
	; MAC
	.DW 0xFFFF 			; Destination address
	.DW 0xFFFF
	.DW 0xFFFF
	.DB 0x5C, 0xFF			; Source address
	.DB 0x35, 0xCB
	.DB 0xCB, 0xCB
	.DB 0x08, 0x00 			; Type (IP)

	; IP
	.DB 0x45, 0x00 			; Type (IPv4), Header length (5 * DWORD) //TODO split second byte
	.DB 0x00, 20+12			; Data length (Header + Payload)
	.DW 0x0000			; Diffserv/ECN?
	.DW 0x0000			; CRC?
	.DB 0x42, 0x17			; TTL & Type (UDP)
	.DW 0x0000			; ?
	.DB 129, 13, 215, 90		; Source address
	.DB 255, 255, 255, 255		; Destination address

	; UDP
	.DW 8080			; Source port // FIXME LE
	.DW 8080			; Destination port
	.DB 0, 12			; Data len
	.DW 0x0000			; CRC
	.DB "HELO"
