.include "m8def.inc"
.cseg
.org 0
rjmp setup

; IO Pins
.equ PIN_LED1 = 5
.equ PIN_LED2 = 4
.equ PIN_ENC_SEL = 0
.equ PIN_ENC_INT = 1
.equ PIN_DISP_SEL = 3
.equ PIN_DISP_MODE = 2
.equ PIN_DISP_RESET = 1
.equ PIN_INPUT_ENTER = 0
.equ PIN_INPUT_UP = 2
.equ PIN_INPUT_DOWN = 3

; SRAM Locations
.equ SRAM_NEXTPACKET_LOW = (SRAM_START)
.equ SRAM_NEXTPACKET_HIGH = (SRAM_START + 1)
.equ SRAM_MENU_POSITION = (SRAM_START + 2)
.equ SRAM_DATA_START = (SRAM_START + 20)
.equ SRAM_DATA_END = (SRAM_DATA_START + 512)

.include "aux.s"
.include "enc.s"
.include "dmx.s"
.include "ssd1306.s"
.include "menu.s"

setup:
		cli
		; Create stack
	        ldi r16, low(RAMEND)
	        out SPL, r16
	        ldi r16, high(RAMEND)
	        out SPH, r16

		; Set up LED/display port (PC)
		ldi r16, 0xFF
		out DDRC, r16
		ldi r16, 0b00001110
		out PORTC, r16

		; Set up UART/INPUT port (PD)
		ldi r16, 0b00000010
		out DDRD, r16
		ldi r16, 0b00001101
		out PORTD, r16

		; Set up SPI/IO port (PB)
		ldi r16, 0b00101101
		out DDRB, r16
		ldi r16, 0b00000011
		out PORTB, r16

		; Set up UART
		ldi r16, 1
		out UBRRL, r16
		ldi r16, (1 << TXEN)
		out UCSRB, r16
		;ldi r16, (1 << URSEL) | (1 << UCSZ1)
		ldi r16, (1 << URSEL) | (1 << UCSZ0) | (1 << UCSZ1) | (1 << USBS)
		out UCSRC, r16
		
		; Set up SPI
		ldi r16, (1 << SPE) | (1 << MSTR) ; | (1 << SPR0) | (1 << SPR1)
		out SPCR, r16

		sei

		; Zero all channel data
		rcall dmx_init_storage

		; Start the display and draw initial menu
		ldi r16, 0
		sts SRAM_MENU_POSITION, r16
		rcall disp_setup
		rcall menu_draw

		; Set up the ENC
		rcall enc_setup

		;rjmp testmain

		; Run the main loop
		rjmp main

;	Test main loop
testmain:
		;rcall xmit_dummy_pkt
		ldi ZL, low(cblogo << 1)
		ldi ZH, high(cblogo << 1)
		ldi r16, 32
		ldi r17, 3
		ldi r18, 96
		ldi r19, 4
		rcall disp_gfx

		ldi ZL, low(bm_0_1 << 1)
		ldi ZH, high(bm_0_1 << 1)
		ldi r16, 4
		ldi r17, 7
		ldi r18, 0
		ldi r19, 0
		rcall disp_gfx

ctr_rst:
		ldi r16, low(bm_4 << 1)
		mov r1, r16
		ldi r16, high(bm_4 << 1)
		mov r2, r16
tmloop:
		mov ZL, r1
		mov ZH, r2
		lpm r16, Z+
		lpm r17, Z+
		mov r1, ZL
		mov r2, ZH
		tst r16
		breq ctr_rst

		mov ZL, r16
		mov ZH, r17
		ldi r16, 16
		ldi r17, 3
		ldi r18, 4
		ldi r19, 0
		rcall disp_gfx
		rcall longdelay
		rcall longdelay
		rcall longdelay
		rjmp tmloop
		rjmp testmain

; 	Production main loop
main:
		; Check for interrupt
		sbis PINB, PIN_ENC_INT
		rcall pkt_incoming

		; Check for key presses
		sbis PIND, PIN_INPUT_ENTER
		rcall debounce_enter

		sbis PIND, PIN_INPUT_UP
		rcall debounce_up

		sbis PIND, PIN_INPUT_DOWN
		rcall debounce_down

		; Transmit DMX packet
		rcall dmx_transmit_packet
		rjmp main

;	Handle incoming packet
pkt_incoming:
		rcall led2on
		rcall read_pkt
		rcall enc_packet_ack
		rcall enc_clearint
		rcall led2off
		ret

;	Transmit test UDP packet
;	Clobbers: r16
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

;	Read and process received packet
;	Clobbers r1, r2, r16, r17, r18, r19, r20, r21
read_pkt:
		; Write next packet pointer
		ldi r16, REG_ERDPT
		lds r17, SRAM_NEXTPACKET_LOW
		lds r18, SRAM_NEXTPACKET_HIGH
		rcall enc_writeword
		; Begin reading
		rcall enc_readbuffer_start
		; Read next packet pointer and store to SRAM
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
		; Assert a complete Art-Net header ( > 0x3B bytes)
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
		; Compare source/destination ports
		ldi ZL, low(artnet_hdr_1 << 1)
		ldi ZH, high(artnet_hdr_1 << 1)
		ldi r16, 4
		rcall spi_compare
		tst r16
		brne read_pkt_exit
		; Skip to Art-Net header
		ldi r16, 4
		rcall spi_skip
		; Compare Art-Net header
		ldi ZL, low(artnet_hdr_2 << 1)
		ldi ZH, high(artnet_hdr_2 << 1)
		ldi r16, 10
		rcall spi_compare
		tst r16
		brne read_pkt_exit
		; If Art-Net packet, turn on LED
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
		; Calculate odd next packet pointer (see ENC28J60 errata)
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

dummy_pkt:
	; MAC
	.DB 0xFF, 0xFF 			; Destination address
	.DB 0xFF, 0xFF
	.DB 0xFF, 0xFF
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
	.DB 10, 11, 12, 3		; Source address
	.DB 10, 11, 12, 1		; Destination address

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
