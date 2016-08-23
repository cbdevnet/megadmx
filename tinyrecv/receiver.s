.include "../tn13def.inc"
.cseg
.org 0
rjmp setup

.EQU CHANNELS = 2
.EQU ADDRESS = 28
.EQU DMXPIN = 3
; 9.6 cycles / usec

setup:
		cli
		; Create stack
	        ldi r16, RAMEND
	        out SPL, r16

		; Set up PB
		ldi r16, 0b00010111
		out DDRB, r16
		ldi r16, 0b00101000
		out PORTB, r16
		
		; Set up PWM channels
		ldi r16, (1 << COM0A1 | 0 << COM0A0 | 1 << COM0B1 | 0 << COM0B0 | 1 << WGM00)
		out TCCR0A, r16
		; No clock prescaler
		ldi r16, (1 << CS00)
		out TCCR0B, r16
		sei

		ldi r16, 200
		out OCR0A, r16

		ldi r16, 100
		out OCR0B, r16

		ldi r16, (1 << DMXPIN)
		mov r14, r16

		ldi r16, 0b00101000
		mov r22, r16
		ldi r16, 0b00111000
		mov r23, r16


		; Run the main loop
		rjmp main

; 	Production main loop
main:
		ldi r16, 104		; ceil(88 usec * 9.6 cycles) / 8  +- 4
		rcall scan_break
main_reent:
		; TODO verify MARK
		; In MAB
		;sbi PORTB, 4
		;cbi PORTB, 4
		; Fall through
main_read_byte:
		; Wait for startbit
		sbic PINB, DMXPIN	; 1C false 2 true
		rjmp main_read_byte	; 2C
		; Now in startbit (min 2C max 4C)
		ldi r16, 0
		ldi r18, 0xFF
main_read_byte_sample_bit:
		in r17, PINB			; Sample pin
		andi r17, (1 << DMXPIN)		; Sanitize input
		ldi r20, 0			; Zero HI counter
		mov r15, r20
		cpse r17, r14			; Increase if 1
		inc r15
		nop
		nop
		inc r18
		nop
		in r17, PINB
		andi r17, (1 << DMXPIN)
		cpse r17, r14
		inc r15

		nop
		nop
		nop
		nop

		in r17, PINB
		andi r17, (1 << DMXPIN)
		cpse r17, r14
		inc r15
		nop

		lsl r16				; Shift the resulting byte
		sbrc r15, 1			; Set lower bit according to consensus
		ori r16, 1

		nop
		nop
		nop
		nop
		nop

		sbi PORTB, 4
		cbi PORTB, 4
		;nop
		;nop
		;nop
		;nop

		sbrs r18, 3
		rjmp main_read_byte_sample_bit
		; TODO sample stopbit 1, process
		sbi PORTB, 4
		nop
		nop
		nop
		nop
		cbi PORTB, 4
		sbis PINB, DMXPIN		; Assert stop bit 1 or scan for new break ; FIXME do RESCAN instead of SCAN
		rjmp main
		rjmp main_read_byte
		;rjmp main

scan_break:
		ldi r17, 0
scan_break_1:
		nop			; 1C
		nop			; 1C
		nop			; 1C
		nop			; 1C
		inc r17			; 1C
		sbis PINB, DMXPIN	; 1C false 2 true
		rjmp scan_break_1	; 2C
		cp r17, r16		; 1C
		brlo scan_break		; 1C false 2 true
		ret
