.equ MENU_MAX = 3

debounce_enter:
		rcall delay
		sbic PIND, PIN_INPUT_ENTER
		ret
		; Load menu position
		lds r16, SRAM_MENU_POSITION
		; Increase and check
		inc r16
		cpi r16, MENU_MAX
		brne debounce_enter_cont
		ldi r16, 0
debounce_enter_cont:
		; Store menu position
		sts SRAM_MENU_POSITION, r16
		; Update graphics
		rcall menu_draw
debounce_enter_out:
		sbis PIND, PIN_INPUT_ENTER
		rjmp debounce_enter_out
		rcall delay
		ret

debounce_up:
		ret

debounce_down:
		ret

; Clobbers: r4, r16, r17, r18, r19, r20, ZL, ZH
menu_draw:
		lds r16, SRAM_MENU_POSITION
		ldi ZL, low(menu_titles << 1)
		ldi ZH, high(menu_titles << 1)
menu_draw_select_title:
		tst r16
		breq menu_draw_title_gfx
		adiw ZH:ZL,2
		dec r16
		rjmp menu_draw_select_title
menu_draw_title_gfx:
		lpm r16, Z+
		lpm r17, Z
		mov ZL, r16
		mov ZH, r17
		; Load front offset (0)
		lpm r16, Z+
		; Load back offset
		lpm r17, Z+
		mov r4, r17
		; Calculate GFX length
		ldi r16, 96
		sub r16, r17
		; Fixed values
		ldi r17, 3
		ldi r18, 0
		ldi r19, 3
		rcall disp_gfx
		; Clear leftover area
		mov r16, r4
		ldi r17, 3
		ldi r18, 96
		sub r18, r16
		ldi r19, 3
		rcall disp_clear_rect
		ret

menu_titles:
	.DW bm_net << 1
	.DW bm_subuni << 1
	.DW bm_uni << 1
