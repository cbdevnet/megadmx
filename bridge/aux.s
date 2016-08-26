;	Stop execution
stop:		rjmp stop

;	LED helpers
led1on:
		sbi PORTC, PIN_LED1
		ret

led2on:
		sbi PORTC, PIN_LED2
		ret

led1off:
		cbi PORTC, PIN_LED1
		ret

led2off:
		cbi PORTC, PIN_LED2
		ret
		
;	Send arbitrary byte via SPI
;	Data in r16
spi_send:
		out SPDR, r16
spi_send_wait:
		sbis SPSR, SPIF
		rjmp spi_send_wait
		ret

;	Skip SPI buffer bytes
;	Count in r16
;	Clobbers r16, r17
;	TODO Wait until ready, then send and return for faster handling
spi_skip:
		mov r17, r16
spi_skip_1:
		ldi r16, 0
		rcall spi_send
		dec r17
		breq spi_skip_done
		rjmp spi_skip_1
spi_skip_done:
		ret

;	Compare SPI buffer bytes
;	Data pointer << 1 in ZL/ZH
;	Length in r16
;	Clobbers r16, r17, r18
;	Reads length bytes from stream in any case
;	r16 = 0 if match
spi_compare:
		mov r18, r16
		ldi r16, 0
spi_compare_1:
		rcall spi_send
		lpm r17, Z+
		in r16, SPDR
		cp r16, r17
		brne spi_compare_skip
		ldi r16, 0
		dec r18
		breq spi_compare_done
		rjmp spi_compare_1
spi_compare_skip:
		ldi r16, 1
		dec r18
		breq spi_compare_done
		rcall spi_send
		rjmp spi_compare_skip
spi_compare_done:
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
