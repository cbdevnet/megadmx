.include "../m8def.inc"
.cseg
.org 0
rjmp setup

.EQU CHANNELS = 3

setup:
		cli
		; Create stack
	        ldi r16, low(RAMEND)
	        out SPL, r16
	        ldi r16, high(RAMEND)
	        out SPH, r16

		; Set up PWM port (PB)
		ldi r16, 0b00001110
		out DDRB, r16
		ldi r16, 0x00
		out PORTB, r16

		; Set up UART/INPUT port (PD)
		ldi r16, 0b00000000
		out DDRD, r16
		ldi r16, 0b11100001
		out PORTD, r16

		; Set up INPUT port (PC)
		ldi r16, 0b00000000
		out DDRC, r16
		ldi r16, 0b00111111
		out PORTC, r16

		; Set up UART
		ldi r16, 1
		out UBRRL, r16
		ldi r16, (1 << RXEN)
		;out UCSRB, r16
		ldi r16, (1 << URSEL) | (1 << UCSZ0) | (1 << UCSZ1) | (1 << USBS)
		out UCSRC, r16
		
		; Set up PWM channels
		; A/B phase correct PWM
		ldi r16, (1 << COM1A1 | 0 << COM1A0 | 1 << COM1B1 | 0 << COM1B0 | 1 << WGM10)
		out TCCR1A, r16
		; No clock prescaler
		ldi r16, (1 << CS10)
		out TCCR1B, r16
		; Timer2 mode
		ldi r16, (0 << WGM21 | 1 << WGM20 | 1 << COM21 | 1 << CS20)
		out TCCR2, r16
		sei

		; Run the main loop
		rjmp main

; 	Production main loop
main:
		; Stop reception
		ldi r16, 0		; 1C
		out UCSRB, r16		; 1C

		; Read device address
		;rcall read_addr
		ldi r16, 0
		mov r1, r16
		ldi r16, 24
		mov r2, r16
		rcall read_addr_2

		; Wait for BREAK
		rcall scan_break
main_reent:
		; In MAB, enable RX
		; MAB is at minimum 4 usec -> 32 cycles
		ldi r16, (1 << RXEN)	; 1C
		out UCSRB, r16		; 1C

		; Channel counter
		ldi r24, 0
		ldi r25, 0

		; Start address
		mov r26, r2
		mov r27, r1

		; End address
		mov r28, r4
		mov r29, r3

main_read_byte:
		; Check for received byte
		sbis UCSRA, RXC
		rjmp main_read_byte	; 2C

main_byte:
		; One byte-time of processing time (44us)
		; -> 352
		in r16, UCSRA
		; Check for framing errors (end of packet)
		andi r16, (1 << FE)
		brne main_fe
		ldi r17, 0

		; Read data
		in r16, UDR

		; Check for startcode
		cpi r24, 0
		cpc r25, r17
		breq main_startcode

		; Check if over start address
		cp r24, r26
		cpc r25, r27
		brlo main_byte_done

		; Check if over end address
		cp r24, r28
		cpc r25, r29
		brsh main_byte_done
		
		; Calculate delta (address - start)
		mov r19, r25
		mov r18, r24

		sub r18, r2
		sbc r19, r1

		; Handle channel
		cpi r18, 0
		breq main_handle_c1
		cpi r18, 1
		breq main_handle_c2
		cpi r18, 2
		breq main_handle_c3
		rjmp main_byte_done

main_handle_c1:
		out OCR1AL, r16
		rjmp main_byte_done
main_handle_c2:
		out OCR1BL, r16
		rjmp main_byte_done
main_handle_c3:
		out OCR2, r16
		rjmp main_byte_done

main_byte_done:
		; Increase channel counter
		adiw r25:r24, 1		; 2C
		rjmp main_read_byte	; 2C

main_startcode:
		; Read startcode
		cpi r16, 0
		; If startcode not 0, rescan for BREAK
		brne main
		rjmp main_byte_done

main_fe:
		; Disengage RX
		ldi r16, 0		; 1C
		out UCSRB, r16		; 1C

		; Run rescan_break
		rcall rescan_break
		rjmp main_reent

scan_break:
		; 8 cycles per usec
		; 88 usec BREAK
		; => 704 cycles
		; -1 cycle setup
		ldi r17, 0		; 1C
scan_break_1:
		nop			; 1C
		nop			; 1C
		nop			; 1C
		nop			; 1C
		inc r17			; 1C
		sbis PIND, 0		; 1C (2C @ skip)
		rjmp scan_break_1	; 2C
		cpi r17, 88		; 1C
		; Test whether break condition met
		; else wait for next break and do it again
		brlo scan_break		; 1C if false, 2 if true
		; Return (at min) 10 cycles into MAB (16 at max)
		ret			; 4C

rescan_break:
		; Might instead just make scan_break interval programmable
		; First stop bit framing error, already 40 usec into BREAK
		; If any data in next 48 usec, run scan_break
		ldi r17, 0		; 1C
rescan_break_1:
		nop
		nop
		nop
		nop
		inc r17
		sbis PIND, 0
		rjmp rescan_break_1
		cpi r17, 48
		brlo scan_break
		ret

read_addr:
		; Clear address high byte
		ldi r16, 0
		mov r1, r16
		in r16, PINC
		in r17, PIND
		lsl r17
		brcc read_addr_1
		ldi r16, 1
		mov r1, r16
read_addr_1:
		andi r16, 0b00111111
		andi r17, 0b11000000
		or r16, r17
		mov r2, r16
read_addr_2:
		; Calculate end address
		mov r25, r1
		mov r24, r2
		adiw r25:r24, CHANNELS
		mov r3, r25
		mov r4, r24
		ret
