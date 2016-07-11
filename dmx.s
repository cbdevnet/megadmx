;	Transmit the DMX break marker
;	Clobbers: r16
dmx_transmit_break:
		; Step down UART speed
		ldi r16, 8
		out UBRRL, r16
		; Transmit zero for BREAK
		ldi r16, 0
		out UDR, r16
		ldi r16, 1
		; Wait until BREAK done
dmx_transmit_break_1:
		sbis UCSRA, UDRE
		rjmp dmx_transmit_break_1
		; Reset UART speed to 250kBit/s
		out UBRRL, r16
		ret

;	Transmit single byte via DMX
;	Value in r16
;	Clobbers: r17
dmx_transmit_byte:
		; Delay for Inter-Frame-Time
		ldi r17, 164
dmx_transmit_byte_1:
		dec r17
		brne dmx_transmit_byte_1
		sbis UCSRA, UDRE
		rjmp dmx_transmit_byte
		out UDR, r16
		ret

;	Transmit a complete DMX packet
;	Clobbers: r16, r17, r18, r19, YL, YH
dmx_transmit_packet:
		; BREAK / MAB
		rcall dmx_transmit_break
		ldi r16, 0
		rcall dmx_transmit_byte
		ldi YL, low(SRAM_DATA_START)
	        ldi YH, high(SRAM_DATA_START)
		ldi r18, low(SRAM_DATA_END)
		ldi r19, high(SRAM_DATA_END)
		; Iterate over channels
dmx_transmit_packet_1:
		ld r16, Y+
		rcall dmx_transmit_byte
		cp YL, r18
		cpc YH, r19
		brlt dmx_transmit_packet_1
		ret

;	Initialize data storage to all zeros
;	Clobbers: YL, YH, r16, r18, r19
dmx_init_storage:
		ldi YL, low(SRAM_DATA_START)
	        ldi YH, high(SRAM_DATA_START)
		ldi r18, low(SRAM_DATA_END)
		ldi r19, high(SRAM_DATA_END)
		ldi r16, 0
dmx_init_storage_1:
		st Y+, r16
		cp YL, r18
		cpc YH, r19
		brlt dmx_init_storage_1
		ret
