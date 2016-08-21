.include "../m8def.inc"
.cseg
.org 0
rjmp setup

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
		;ldi r16, (1 << URSEL) | (1 << UCSZ1)
		ldi r16, (1 << URSEL) | (1 << UCSZ0) | (1 << UCSZ1) | (1 << USBS)
		out UCSRC, r16
		
		; Set up PWM channels

		sei

		; Run the main loop
		rjmp main

; 	Production main loop
main:
		rcall read_addr
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

main_read_byte:
		; Check for received byte
		sbis UCSRA, RXC
		rjmp main_read_byte

main_byte:
		in r16, UCSRA
		; Check for framing errors (end of packet)
		andi r16, (1 << FE)
		brne main_fe

		; Read startcode
		; Check if match for address
		; Increase channel counter
		sbi PORTB, 2
		cbi PORTB, 2
		in r16, UDR
		rjmp main_read_byte

main_fe:
		sbi PORTB, 1

		; Disengage RX
		ldi r16, 0		; 1C
		out UCSRB, r16		; 1C

		cbi PORTB, 1

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
		ret
