;	Enable/Disable display SPI
disp_ena:
		cbi PORTC, PIN_DISP_SEL
		ret

disp_disa:
		sbi PORTC, PIN_DISP_SEL
		ret

;	Set display data mode
disp_data:
		sbi PORTC, PIN_DISP_MODE
		ret

disp_command:
		cbi PORTC, PIN_DISP_MODE
		ret

;	Clear display data ram
;	Clobbers r16, r17, r18
disp_clear:
		rcall disp_command
		rcall disp_ena
		; Columns 0 to 126
		ldi r16, 0x21
		rcall spi_send
		ldi r16, 0
		rcall spi_send
		ldi r16, 127
		rcall spi_send
		; Pages 0 to 7
		ldi r16, 0x22
		rcall spi_send
		ldi r16, 0
		rcall spi_send
		ldi r16, 7
		rcall spi_send
		rcall delay
		rcall disp_data
		ldi r16, 0
		ldi r18, 7
disp_clear_page:
		ldi r17, 127
disp_clear_col:
		rcall spi_send
		dec r17
		brne disp_clear_col
		dec r18
		brne disp_clear_page
		rcall delay
		rcall disp_disa
		ret

;	Display raster graphics
;	Address << 1 in ZL/ZH
;	Width (Cols) in r16
;	Height (Pages) in r17
;	Column offset in r18
;	Page offset in r19
;	Clobbers r16, r17, r18, r19, r20, r21
disp_gfx:
		rcall disp_command
		rcall disp_ena
		; Column scan width
		mov r20, r16
		ldi r16, 0x21
		rcall spi_send
		mov r16, r18
		rcall spi_send
		add r16, r20
		dec r16
		rcall spi_send
		; Page scan height
		ldi r16, 0x22
		rcall spi_send
		mov r16, r19
		rcall spi_send
		add r16, r17
		rcall spi_send
		mov r21, r17
		rcall delay
		mov r17, r21
		rcall disp_data
		inc r17
disp_gfx_page:
		mov r18, r20
disp_gfx_col:
		lpm r16, Z+
		rcall spi_send
		dec r18
		brne disp_gfx_col
		dec r17
		brne disp_gfx_page
		; Delay because we don't yet check for completed transactions
		rcall delay
		rcall disp_disa
		ret

;	Set up SSD1306 display
disp_setup:
		cbi PORTC, PIN_DISP_RESET
		rcall delay
		sbi PORTC, PIN_DISP_RESET
		rcall delay
		rcall disp_ena
		rcall disp_command
		; Charge pump on
		ldi r16, 0x8D
		rcall spi_send
		ldi r16, 0x14
		rcall spi_send
		; Horizontal addressing mode
		ldi r16, 0x20
		rcall spi_send
		ldi r16, 0
		rcall spi_send
		; Display RAM data
		ldi r16, 0xA4
		rcall spi_send
		; Reverse column layout
		ldi r16, 0xA1
		rcall spi_send
		; Display on
		ldi r16, 0xAF
		rcall spi_send
		; Clear data RAM
		rcall delay
		rcall disp_clear
		; disp_clear disables DISP_CSEL when done
		ret

test_img:
	;.DB	0xF0, 0xF0, 0xF0, 0xF0, 0x0F, 0x0F, 0x0F, 0x0F
	;.DB	0xFF, 0xFF, 0xFF, 0xFF, 0x0F, 0x0F, 0x0F, 0xF0
	.DB	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
	.DB	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
