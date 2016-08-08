# megadmx
ArtNet to DMX bridge using an ATmega8 and an ENC28J60

Documentation TBD

## Hardware Setup

### ATmega8
	MAX485 DI	<->	PD1 (UART TX)
	MAX485 DE/RE	<->	HIGH
	LED1		<->	PC5
	LED2		<->	PC4
	ENC CS		<->	PB0
	ENC INT		<->	PB1
	ENC SPI		<->	ATmega SPI
	ATmega SS	<->	HIGH
	ENC RST		<->	HIGH
	ENTER button	<->	PD0
	UP button	<->	PD2
	DOWN button	<->	PD3
	SSD1306 SPI	<->	ATmega SPI
	SSD1306 CS	<->	PC3
	SSD1306 DC	<->	PC2
	SSD1306 RES	<->	PC1
