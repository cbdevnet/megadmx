.include "m32def.inc"
.cseg
.org 0
rjmp setup

.equ PIN_LED1 = 5
.equ PIN_LED2 = 7
.equ PIN_CSEL = 6
.equ PIN_CINT = 4

.equ SRAM_NEXTPACKET_LOW = (SRAM_START)
.equ SRAM_NEXTPACKET_HIGH = (SRAM_START + 1)
.equ SRAM_DATA_START = (SRAM_START + 20)

.include "enc.s"

setup:
		cli
		; Create stack
	        ldi r16, low(RAMEND)
	        out SPL, r16
	        ldi r16, high(RAMEND)
	        out SPH, r16

		; Set up I/O port
		ldi r16, 0b11100010
		out DDRD, r16
		ldi r16, 0b01010000
		out PORTD, r16

		; Set up UART
		ldi r16, 1
		out UBRRL, r16
		ldi r16, (1 << TXEN)
		out UCSRB, r16
		;ldi r16, (1 << URSEL) | (1 << UCSZ1)
		ldi r16, (1 << URSEL) | (1 << UCSZ0) | (1 << UCSZ1) | (1 << USBS)
		out UCSRC, r16
		
		; Set up SPI
		ldi r16, 0b10100000
		out DDRB, r16
		ldi r16, (1 << SPE) | (1 << MSTR) ; | (1 << SPR0) ; | (1 << SPR1)
		out SPCR, r16

		; Set up visualizer port
		ldi r16, 0xFF
		out DDRA, r16

		sei

		;rjmp testmain

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


testmain:
	rjmp stop

main:
	; Check for link
	; Set LED
	; Check for interrupt
	sbis PIND, PIN_CINT
	rcall detected
	;ldi YL, low(SRAM_DATA_START + 100)
	;ldi YH, high(SRAM_DATA_START + 100)
	;ld r8, Z
	;rcall xmit_dummy_pkt
	rjmp main

detected:
	rcall led2on
	;rcall xmit_dummy_pkt
	;rcall longdelay
	rcall read_pkt
	rcall enc_packet_ack
	rcall enc_clearint
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
	ldi ZH, high(dummy_pkt << 1)
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

read_pkt:
	ldi r16, REG_ERDPT
	lds r17, SRAM_NEXTPACKET_LOW
	lds r18, SRAM_NEXTPACKET_HIGH
	rcall enc_writeword

	rcall enc_readbuffer_start
	
	; Read next packet ptr
	ldi r16, 0
	rcall spi_send
	in r16, SPDR
	sts SRAM_NEXTPACKET_LOW, r16
	ldi r16, 0
	rcall spi_send
	in r16, SPDR
	sts SRAM_NEXTPACKET_HIGH, r16

	; Read packet data length (r20/r21)
	ldi r16, 0
	rcall spi_send
	in r20, SPDR
	rcall spi_send
	in r21, SPDR

	; Read status vector
	rcall spi_send
	in r16, SPDR
	andi r16, STATUS_RECV_OK
	breq read_pkt_exit
	ldi r16, 0
	rcall spi_send

	; Assert a complete Art-Net header
	ldi r16, 0x3B
	ldi r17, 0
	cp r20, r16
	cpc r21, r17
	brlt read_pkt_exit

	; TODO Calculate proper offset into packet for Art-Net header
	; instead of reading unnecessary data

	; TODO Make sure to not read over packet length

	; FIXME This could all be done better by interleaving SPI reads
	; with stores

	; Skip to port bytes
	ldi r16, 0x22
	rcall spi_skip

	ldi ZL, low(artnet_hdr_1 << 1)
	ldi ZH, high(artnet_hdr_1 << 1)
	ldi r16, 4
	rcall spi_compare

	tst r16
	brne read_pkt_exit

	ldi r16, 4
	rcall spi_skip

	ldi ZL, low(artnet_hdr_2 << 1)
	ldi ZH, high(artnet_hdr_2 << 1)
	ldi r16, 10
	rcall spi_compare

	tst r16
	brne read_pkt_exit

	rcall led1on

	ldi r16, 4
	rcall spi_skip

	ldi r16, 0
	; Read Universe to r1/r2 //TODO compare
	rcall spi_send
	in r1, SPDR
	rcall spi_send
	in r2, SPDR

	; Read number of channels to r17/r18
	rcall spi_send
	in r17, SPDR
	rcall spi_send
	in r18, SPDR

	; TODO Check for #channels <= 512

	; Read channel data
	ldi XL, low(SRAM_DATA_START)
	ldi XH, high(SRAM_DATA_START)
	ldi r19, 0
	ldi r20, 0
	
	out SPDR, r19
read_pkt_channel_wait:
	sbis SPSR, SPIF
	rjmp read_pkt_channel_wait
	in r16, SPDR
	out SPDR, r19
	st X+, r16
	subi r18, 1
	sbci r17, 0
	cp r18, r19
	cpc r17, r20
	brne read_pkt_channel_wait

	; FIXME This reads one byte after the packet

	rcall led1off

read_pkt_exit:
	; End buffer transfer
	rcall enc_disa

	; Update RX read pointer to free memory
	ldi r16, REG_ERXRDPT
	lds r17, SRAM_NEXTPACKET_LOW
	lds r18, SRAM_NEXTPACKET_HIGH
	cpi r17, low(ENC_RX_START)
	brne read_pkt_exit_calc
	cpi r18, high(ENC_RX_START)
	brne read_pkt_exit_calc
	ldi r17, low(ENC_RX_END)
	ldi r18, high(ENC_RX_END)
	rjmp read_pkt_exit_write
read_pkt_exit_calc:
	subi r17, 1
	sbci r18, 0
read_pkt_exit_write:
	rcall enc_writeword
	ret

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


str1:	.DB "Yay this seems to work!", 0x00

dummy_pkt:
	; MAC
	.DB 0x5C, 0xFF 			; Destination address
	.DB 0x35, 0x08
	.DB 0xA6, 0x88
	.DB 0x0E, 0xCB			; Source address
	.DB 0xCB, 0xCB
	.DB 0xCB, 0xCB
	.DB 0x08, 0x00 			; Type (IP)

	; IP
	.DB 0x45, 0x00 			; Type (IPv4), Header length (5 * DWORD) //TODO split second byte
	.DB 0x00, 20+12			; Data length (Header + Payload)
	.DW 0x0000			; Diffserv/ECN?
	.DW 0x0000			; CRC?
	.DB 42, 17			; TTL & Type (UDP)
	.DW 0x0000			; ?
	.DB 129, 13, 215, 90		; Source address
	.DB 129, 13, 215, 89		; Destination address

	; UDP
	.DB high(8080), low(8080)	; Source port
	.DB high(8080), low(8080)	; Destination port
	.DB 0, 12			; Data len
	.DW 0x0000			; CRC
	.DB "HELO"

artnet_hdr_1:
	.DB 0x19, 0x36, 0x19, 0x36

artnet_hdr_2:
	.DB "Art-Net", 0x00, 0x00, 0x50
