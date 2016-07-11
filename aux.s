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