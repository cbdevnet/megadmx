.include "../tn13def.inc"
.cseg
.org 0
rjmp setup

.EQU ADDRESS1 = 301
.EQU ADDRESS2 = 512
.EQU DMXPIN = 3
; 9.6 cycles / usec
; TODO simple address setting (press button, set channel)

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

		; Initial PWM values
		ldi r16, 0
		out OCR0A, r16
		ldi r16, 0
		out OCR0B, r16

		; Initialize register constants
		ldi r16, (1 << DMXPIN)
		mov r14, r16

		; Load local addresses
		ldi r26, low(ADDRESS1)
		ldi r27, high(ADDRESS1)
		ldi r28, low(ADDRESS2)
		ldi r29, high(ADDRESS2)

		; Run the main loop
		rjmp main

; 	Production main loop
main:
		ldi r16, 104			; ceil(88 usec * 9.6 cycles) / 8  +- 4
main_rescan:
		rcall scan_break
main_reent:
		; TODO verify MARK
		; In MAB
		; Load current address
		ldi r25, 0
		ldi r24, 0
		; Fall through
main_read_byte:
		; Wait for startbit
		sbic PINB, DMXPIN		; 1C false 2 true
		rjmp main_read_byte		; 2C
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

		;sbi PORTB, 4
		;cbi PORTB, 4
		nop
		nop
		nop
		nop

		sbrs r18, 3
		rjmp main_read_byte_sample_bit
main_byte:
		com r16				; Somehow the data byte is inverted
		; Check if startcode
		ldi r18, 0
		cpi r24, 0
		cpc r25, r18
		breq main_byte_startcode

		; Decode data
		ror r16
		rol r17
		ror r16
		rol r17
		ror r16
		rol r17
		ror r16
		rol r17
		ror r16
		rol r17
		ror r16
		rol r17
		ror r16
		rol r17
		ror r16
		rol r17

		; Check local addresses for match
		cp r24, r26
		cpc r25, r27
		breq main_byte_a1
		cp r24, r28
		cpc r25, r29
		breq main_byte_a2


		; Do nothing
		rjmp main_byte_done

main_byte_startcode:
		; If startcode 0, handle
		cpi r16, 0
		breq main_byte_done
		; Rescan for break
		rjmp main

main_byte_a1:
		;sbi PORTB, 4
		;cbi PORTB, 4
		out OCR0A, r17
		rjmp main_byte_done

main_byte_a2:
		;sbi PORTB, 4
		;cbi PORTB, 4
		out OCR0B, r17
		rjmp main_byte_done

main_byte_done:
		; Increase channel
		adiw r25:r24, 1

		;sbi PORTB, 4
		;nop
		;nop
		;nop
		;nop
		;cbi PORTB, 4

		; Assert stop bit or scan for new BREAK
		sbic PINB, DMXPIN
		rjmp main_read_byte
		ldi r16, 60
		rjmp main_rescan

; FIXME in rescan, if nothing found default to full scan
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
