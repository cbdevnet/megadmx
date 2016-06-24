;	Enable/Disable ENC Chip
enc_ena:
		cbi PORTD, 6
		ret

enc_disa:
		sbi PORTD, 6
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
;	Clobbers r16
enc_writereg:
		rcall enc_ena
		andi r16, 0b00011111
		ori r16, 0b01000000
		out SPDR, r16
enc_writereg_wait_1:
		sbis SPSR, SPIF
		rjmp enc_writereg_wait_1
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
		out SPDR, r16
enc_readreg_wait:
		sbis SPSR, SPIF
		rjmp enc_readreg_wait
		ldi r16, 0
		out SPDR, r16
enc_readreg_wait_2:
		sbis SPSR, SPIF
		rjmp enc_readreg_wait_2
		in r16, SPDR
		rcall enc_disa
		ret

;	Select ENC register bank
;	Bank no in r16
;	Clobbers: r17
enc_selbank:
		mov r17, r16
		; Read ECON1 (Addr 1F)
		ldi r16, 0b00011111
		rcall enc_readreg
		; ECON0 now in r16, set bank
		andi r16, 0b11111100
		andi r17, 0b00000011
		or r17, r16
		ldi r16, 0b00011111
		rcall enc_writereg
		ret