dmx_transmit_break:
	ldi r16, 8
	out UBRRL, r16
	ldi r16, 0
	out UDR, r16
	ldi r16, 1
dmx_transmit_break_1:
	sbis UCSRA, UDRE
	rjmp dmx_transmit_break_1
	out UBRRL, r16
	ret

dmx_transmit_byte:
	ldi r17, 128
dmx_transmit_byte_1:
	dec r17
	brne dmx_transmit_byte_1
	sbis UCSRA, UDRE
	rjmp dmx_transmit_byte
	out UDR, r16
	ret

dmx_transmit_packet:
	rcall dmx_transmit_break
	ldi r16, 0
	rcall dmx_transmit_byte
	ldi YL, low(SRAM_DATA_START)
        ldi YH, high(SRAM_DATA_START)
	ldi r18, low(SRAM_DATA_END)
	ldi r19, high(SRAM_DATA_END)
dmx_transmit_packet_1:
        ld r16, Y+
	rcall dmx_transmit_byte
	cp YL, r18
	cpc YH, r19
	brlt dmx_transmit_packet_1
	ret
