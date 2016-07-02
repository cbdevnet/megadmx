.equ ENC_RX_START = 0
.equ ENC_RX_END = (0x1FFF - 1501)
.equ ENC_TX_START = (0x1FFF - 1500)
.equ ENC_TX_END = 0x1FFF
.equ MAX_PKG_LEN = 1024

.equ FLAG_UCEN = 0b10000000
.equ FLAG_CRCEN = 0b00100000
.equ FLAG_BCEN = 0b00000001
.equ FLAG_MARXEN = 0b00000001
.equ FLAG_TXPAUS = 0b00001000
.equ FLAG_RXPAUS = 0b00000100
.equ FLAG_PADCFG0 = 0b00100000
.equ FLAG_TXCRCEN = 0b00010000
.equ FLAG_FRMLNEN = 0b00000010
.equ FLAG_FULDPX = 0b00000001
.equ FLAG_INTIE = 0b10000000
.equ FLAG_PKTIE = 0b01000000
.equ FLAG_RXEN = 0b00000100
.equ FLAG_TXRTS = 0b00001000
.equ FLAG_PKTIF = 0b01000000
.equ FLAG_RXERIF = 0b00000001
.equ FLAG_TXERIF = 0b00000010
.equ FLAG_PKTDEC = 0b01000000
.equ FLAG_TXRST = 0b10000000

; Bank 0
.equ REG_ERXST = 0x08
.equ REG_ERXRDPT = 0x0C
.equ REG_ERXND = 0x0A
.equ REG_ETXST = 0x04
.equ REG_ETXND = 0x06
.equ REG_EIE = 0x1B
.equ REG_ECON1 = 0x1F
.equ REG_ECON2 = 0x1E
.equ REG_EIR = 0x1C
.equ REG_EWRPT = 0x02

; Bank 2
.equ REG_MACON1 = 0x00
.equ REG_MACON2 = 0x01
.equ REG_MACON3 = 0x02
.equ REG_MAIPG = 0x06
.equ REG_MABBIPG = 0x04
.equ REG_MAMXFL = 0x0A

; Bank 3
.equ REG_MAADR5 = 0x00
.equ REG_MAADR6 = 0x01
.equ REG_MAADR3 = 0x02
.equ REG_MAADR4 = 0x03
.equ REG_MAADR1 = 0x04
.equ REG_MAADR2 = 0x05


;	Enable/Disable ENC Chip
enc_ena:
		cbi PORTD, PIN_CSEL
		ret

enc_disa:
		sbi PORTD, PIN_CSEL
		ret

;	Send arbitrary byte via SPI
;	Data in r16
spi_send:
		out SPDR, r16
spi_send_wait:
		sbis SPSR, SPIF
		rjmp spi_send_wait
		ret

;	Write ENC control register
;	Adress in r16
;	Data in r17
;	Clobbers r16 (is reusable though)
enc_writereg:
		rcall enc_ena
		andi r16, 0b00011111
		ori r16, 0b01000000
		rcall spi_send
		out SPDR, r17
enc_writereg_wait_2:
		sbis SPSR, SPIF
		rjmp enc_writereg_wait_2
		rcall enc_disa
		ret

;	Read ENC control register
;	Address in r16
;	Result in r16
enc_readreg:
		rcall enc_ena
		andi r16, 0b00011111
		rcall spi_send
		ldi r16, 0
		out SPDR, r16
enc_readreg_wait_2:
		sbis SPSR, SPIF
		rjmp enc_readreg_wait_2
		in r16, SPDR
		rcall enc_disa
		ret

;	Soft-reset the ENC
;	Clobbers: r16
enc_softreset:
		rcall enc_ena
		ldi r16, 0xFF
		rcall spi_send
		rcall enc_disa
		rcall longdelay
		ret

;	Write word register
;	Adress (low) in r16
;	Data low in r17
;	Data high in r18
;	Clobbers r16, r17
enc_writeword:
		rcall enc_writereg
		inc r16
		mov r17, r18
		rcall enc_writereg
		ret

;	Set/clear bits in register
;	Address in r16
;	Bitmask in r17
;	Clobbers r16
enc_regbits_set:
		rcall enc_ena
		andi r16, 0b00011111
		ori r16, 0b10000000
		rcall spi_send
		out SPDR, r17
enc_regbits_set_wait:
		sbis SPSR, SPIF
		rjmp enc_regbits_set_wait
		rcall enc_disa
		ret

enc_regbits_clear:
		rcall enc_ena
		andi r16, 0b00011111
		ori r16, 0b10100000
		rcall spi_send
		out SPDR, r17
enc_regbits_clear_wait:
		sbis SPSR, SPIF
		rjmp enc_regbits_clear_wait
		rcall enc_disa
		ret

;	Select ENC register bank
;	Bank no in r16
;	Clobbers: r16, r17
;	FIXME Do this with enc_regbits_set
enc_selbank:
		mov r17, r16
		ldi r16, REG_ECON1
		rcall enc_readreg
		; ECON0 now in r16, set bank
		andi r16, 0b11111100
		andi r17, 0b00000011
		or r17, r16
		ldi r16, REG_ECON1
		rcall enc_writereg
		ret

;	Prepare sending packet
;	Data length in r16
;	Clobbers r16, r17, r18, r19, r20
enc_sendpkt_prepare:
		mov r19, r16
		ldi r20, 0
		ldi r16, REG_ECON1
		rcall enc_readreg
		andi r16, FLAG_TXRTS
		breq enc_sendpkt_prepare_1
		ldi r16, REG_EIR
		rcall enc_readreg
		andi r16, FLAG_TXERIF
		breq enc_sendpkt_prepare
		ldi r16, REG_ECON1
		ldi r17, FLAG_TXRST
		rcall enc_regbits_set
		ldi r16, REG_ECON1
		ldi r17, FLAG_TXRST
		rcall enc_regbits_clear
		rjmp enc_sendpkt_prepare
enc_sendpkt_prepare_1:
		ldi r16, REG_EWRPT
		ldi r17, low(ENC_TX_START)
		ldi r18, high(ENC_TX_START)
		rcall enc_writeword

		ldi r16, REG_ETXND
		ldi r17, low(ENC_TX_START)
		ldi r18, high(ENC_TX_START)
		add r17, r19
		adc r18, r20
		rcall enc_writeword
		ret

enc_sendpkt_xmit:
		ldi r16, REG_ECON1
		ldi r17, FLAG_TXRTS
		rcall enc_regbits_set
		ret

;	Acknowledge received packet
;	Clobbers r16, r17
enc_packet_ack:
		ldi r16, REG_ECON2
		ldi r17, FLAG_PKTDEC
		rcall enc_regbits_set
		ret

;	Clear interrupts
;	Clobbers r16, r17
enc_clearint:
		ldi r16, REG_EIE
		ldi r17, FLAG_INTIE
		rcall enc_regbits_clear

		ldi r16, REG_EIR
		rcall enc_readreg

		ldi r16, REG_EIR
		ldi r17, FLAG_PKTIF | FLAG_RXERIF | FLAG_TXERIF
		rcall enc_regbits_clear

		ldi r16, REG_EIE
		ldi r17, FLAG_INTIE
		rcall enc_regbits_set
		ret

;	Write buffer memory
;	Data in r16
;	Clobbers r17
enc_writebuffer_single:
		mov r17, r16
		rcall enc_writebuffer_start
		mov r16, r17
		rcall spi_send
		rcall enc_disa
		ret

enc_writebuffer_start:
		rcall enc_ena
		ldi r16, 0b01111010
		rcall spi_send
		ret

;	Set up the ENC chip for operation
;	Clobbers r16, r17, r18
;	Contains hardcoded MAC address
enc_setup:
		rcall led1on
		rcall led2on
		rcall longdelay
		rcall enc_softreset
		rcall led1off

		ldi r16, REG_ERXST
		ldi r17, low(ENC_RX_START)
		ldi r18, high(ENC_RX_START)
		rcall enc_writeword

		ldi r16, REG_ERXRDPT
		ldi r17, low(ENC_RX_START)
		ldi r18, high(ENC_RX_START)
		rcall enc_writeword

		ldi r16, REG_ERXND
		ldi r17, low(ENC_RX_END)
		ldi r18, high(ENC_RX_END)
		rcall enc_writeword

		ldi r16, REG_ETXST
		ldi r17, low(ENC_TX_START)
		ldi r18, high(ENC_TX_START)
		rcall enc_writeword

		ldi r16, REG_ETXND
		ldi r17, low(ENC_TX_END)
		ldi r18, high(ENC_TX_END)
		rcall enc_writeword

		rcall delay

		ldi r16, 0b00000010
		rcall enc_selbank
		
		ldi r16, REG_MACON1
		ldi r17, FLAG_TXPAUS | FLAG_RXPAUS | FLAG_MARXEN
		rcall enc_writereg

		ldi r16, REG_MACON2
		ldi r17, 0
		rcall enc_writereg

		ldi r16, REG_MACON3
		ldi r17, FLAG_PADCFG0 | FLAG_TXCRCEN | FLAG_FRMLNEN | FLAG_FULDPX
		rcall enc_regbits_set

		ldi r16, REG_MAIPG
		ldi r17, 0x12
		ldi r18, 0x0C
		rcall enc_writeword

		ldi r16, REG_MABBIPG
		ldi r17, 0x15
		rcall enc_writereg

		ldi r16, REG_MAMXFL
		ldi r17, low(MAX_PKG_LEN)
		ldi r18, high(MAX_PKG_LEN)
		rcall enc_writeword

		rcall delay

		ldi r16, 0b00000011
		rcall enc_selbank

		ldi r16, REG_MAADR6
		ldi r17, 0x5C
		rcall enc_writereg

		ldi r16, REG_MAADR5
		ldi r17, 0xFF
		rcall enc_writereg

		ldi r16, REG_MAADR4
		ldi r17, 0x35
		rcall enc_writereg

		ldi r16, REG_MAADR3
		ldi r17, 0xCB
		rcall enc_writereg

		ldi r16, REG_MAADR2
		ldi r17, 0xCB
		rcall enc_writereg

		ldi r16, REG_MAADR1
		ldi r17, 0xCB
		rcall enc_writereg

		rcall delay

		ldi r16, 0x00
		rcall enc_selbank

		ldi r16, REG_EIE
		ldi r17, FLAG_INTIE | FLAG_PKTIE
		rcall enc_regbits_set

		ldi r16, REG_ECON1
		ldi r17, FLAG_RXEN
		rcall enc_regbits_set

		rcall led2off
		ret
