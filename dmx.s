;	Transmit the DMX break marker
;	Clobbers: r16, r17
dmx_transmit_break:
		; Wait for finished TX
		sbis UCSRA, UDRE
		rjmp dmx_transmit_break
		; Pull TX low for BREAK
		cbi UCSRB, TXEN
		; BREAK
		rcall delay
		sbi UCSRB, TXEN
		; Transmit MAB
		ldi r16, 15
dmx_transmit_break_mab:
		dec r16
		brne dmx_transmit_break_mab
		ret

;	Transmit single byte via DMX
;	Value in r16
;	Clobbers: r17
dmx_transmit_byte:
		; Delay for Inter-Frame-Time
		ldi r17, 130
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
		; Send start code
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
		; Last channel
		;ld r16, Y
		;rcall dmx_transmit_byte
		; Interpacket
		ldi r16, 200
dmx_transmit_packet_ipt:
		dec r16
		brne dmx_transmit_packet_ipt
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
