.include "../tn13def.inc"
.cseg
.org 0
rjmp setup

.EQU DMXPIN = 3
.EQU SWITCHPIN = 2
; 9.6 cycles / usec

setup:
		cli
		; Create stack
	        ldi r16, RAMEND
	        out SPL, r16

		; Set up PB
		ldi r16, 0b00010011
		out DDRB, r16
		ldi r16, 0b00101100
		out PORTB, r16
		
		; Set up PWM channels
		ldi r16, (1 << COM0A1 | 0 << COM0A0 | 1 << COM0B1 | 0 << COM0B0 | 1 << WGM00)
		out TCCR0A, r16
		; No clock prescaler
		ldi r16, (1 << CS00)
		out TCCR0B, r16

		; Initial PWM values
		ldi r16, 0
		out OCR0A, r16
		ldi r16, 0
		out OCR0B, r16

		; Initialize register constants
		ldi r16, (1 << DMXPIN)
		mov r14, r16
		clr r0

		; Load local addresses from EEPROM 0-4 (hi/lo/hi/lo)
		clr r16
		out EEARL, r16		; EEPROM address 0
		sbi EECR, EERE
		in r27, EEDR

		inc r16
		out EEARL, r16
		sbi EECR, EERE
		in r26, EEDR

		inc r16
		out EEARL, r16
		sbi EECR, EERE
		in r29, EEDR

		inc r16
		out EEARL, r16
		sbi EECR, EERE
		in r28, EEDR

		sei

		; Run the main loop
		rjmp main

; 	Production main loop
main:
		ldi r16, 104			; ceil(88 usec * 9.6 cycles) / 8  +- 4
main_rescan:
		rcall scan_break
main_reent:
		; TODO verify MARK
		; In MAB, check if address to be set
		; If address selection, write addresses and wait
		sbrc r0, 0
		rjmp write_addrs
		; Test if address set run requested
		sbis PINB, SWITCHPIN
		inc r0
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
		clr r15				; Zero HI counter
		cpse r17, r14			; Increase if 1
		inc r15
		inc r18				; Increase bit counter
		nop
		nop
		nop
		nop

		in r17, PINB			; Second sample
		andi r17, (1 << DMXPIN)
		cpse r17, r14
		inc r15
		nop
		nop
		nop
		nop

		in r17, PINB			; Third sample
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

		sbrs r18, 3			; Sample 9 bits (counting from 0xFF), then handle byte
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

		; Check if address to be set
		tst r0
		brne main_byte_set_addr

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

main_byte_set_addr:
		; Only react to channels with value > 127
		sbrs r17, 7
		rjmp main_byte_done

		; If addr0 not set, do it
		sbrs r0, 1
		rjmp main_byte_set_addr0

		; If addr1 not set, do it
		sbrs r0, 2
		rjmp main_byte_set_addr1

		; Done
		rjmp main_byte_done

main_byte_set_addr0:
		mov r26, r24
		mov r27, r25
		ldi r16, 0b00000010
		or r0, r16
		rjmp main_byte_done

main_byte_set_addr1:
		mov r28, r24
		mov r29, r25
		ldi r16, 0b00000100
		or r0, r16
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

scan_break_full:
		; If rescan failed, scan for full break
		ldi r16, 104			; ceil(88 usec * 9.6 cycles) / 8  +- 4
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
		brlo scan_break_full	; 1C false 2 true
		ret

write_addrs:
		; Wait until button released
		sbis PINB, SWITCHPIN
		rjmp write_addrs

		; Disable interrupts for EEPROM write
		cli
		clr r16			; EEPROM 0: A0 HI
		mov r17, r27
		rcall eeprom_write

		inc r16
		mov r17, r26
		rcall eeprom_write

		inc r16
		mov r17, r29
		rcall eeprom_write

		inc r16
		mov r17, r28
		rcall eeprom_write
		sei
		; Done setting addresses
		clr r0
		rjmp main

eeprom_write:
		ldi r18, 0
		out EECR, r18		; Atomic write mode
		out EEARL, r16		; Address
		out EEDR, r17		; Data
		sbi EECR, EEMPE		; Enable EEPROM
		sbi EECR, EEPE		; Write
eeprom_write_1:
		sbic EECR, EEPE		; Wait for completion
		rjmp eeprom_write_1
		ret
