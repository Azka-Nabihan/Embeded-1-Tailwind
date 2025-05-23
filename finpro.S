#define __SFR_OFFSET 0
#include "avr/io.h"

.global setup
.global loop

.section .progmem.data          ; store strings in flash memory
string_temperature:
    .ascii "Temp: \0"
string_speed:
    .ascii "Speed: \0"
string_high:
    .ascii "HIGH\0"
string_medium:
    .ascii "MEDIUM\0"
string_low:
    .ascii "LOW\0"
string_manual:
    .ascii "MANUAL\0"

.text

setup:
    ldi R16, 0xFF
    out DDRD, R16   ; all PORTD as output
    out DDRB, R16   ; all PORTB as output
    ldi R16, 0xFC
    out DDRC, R16   ; all PORTC as output ecept PC0 & PC1
    ldi R26, 1

    ; configure ADC
    ldi R16, 0b11100000
    sts ADMUX, R16          ; configure ADC using PC0, 2.5V internal vref and left adjust
    ldi R16, 0b10000111
    sts ADCSRA, R16         ; enable ADC and use prescaler 128

    ; configure timer2
    clr R27
    sts TCNT2, R27          ; clear timer2 count register
    ldi R27, 0b00100011     
    sts TCCR2A, R27         ; fast pwm mode, non inverting
    ldi R27, 0b00011010     
    sts TCCR2B, R27         ; fast pwm mode, prescaler 8
    ldi R27, 255
    sts OCR2A, R27          ; maximum value per duty cycle
    
    ; configure PD2 for DHT11
    cbi DDRD, 2     ; Set PD2 as input initially
    cbi PORTD, 2    ; No pull-up initially

    call LCD_init
    call I2C_init
    call delay_2s   ; Wait for DHT11 to stabilize
    
loop:
    sbic PINC, 1
    rcall button_pressed
    call LCD_clear
    call display_temperature_text    ; Display "Temperature: " text
    call DHT11_read_data             ; Read temperature data from DHT11
    call display_speed_text          ; Display "Speed: " text
    call display_speed_value         ; Display "HIGH", "MEDIUM or "LOW" based on temperature
    call delay_2s                    ; Wait before next reading
    rjmp loop


;=========================================================================== button_pressed

button_pressed:
    cpi R26, 0
    breq isLow
    cpi R26, 1
    breq isHigh

isLow:
    ldi R26, 1
    cbi PORTD, 7
    RET

isHigh:
    ldi R26, 0
    sbi PORTD, 7
    RET

;=========================================================================== LCD_clear (use R16)
; call send_data (use R16 from here, R17, R18) & delay_ms (use R21)

LCD_clear:
    ldi R16, 0x01      ; Clear display command
    rcall send_command
    rcall delay_ms
    RET


;=========================================================================== display_temperature_text (use R16, R30, R31)
; call send_data (use R16 from here, R17, R18)

display_temperature_text:
    ldi R30, lo8(string_temperature)
    ldi R31, hi8(string_temperature)

temp_loop_send:
    lpm R16, Z+        ; load char from Flash and increment Z
    tst R16            ; test if zero (end of string)
    breq temp_done
    rcall send_data    ; Send character to LCD
    rjmp temp_loop_send

temp_done:
    RET


;=========================================================================== DHT11_read_data (use R16, R17, R18, R19, R20, R21, R22, R23, R24, R25, R28)
; call delay_20ms (use R20), delay_50us (use R20) , send_data (use R16 from here, R17, R18)

DHT11_read_data:
    ; Start signal to DHT11
    sbi DDRD, 2        ; Set PD2 as output
    sbi PORTD, 2
    cbi PORTD, 2       ; Set PD2 low
    rcall delay_20ms   ; Hold low for >18ms
    
    ; Release the line
    sbi PORTD, 2       ; Enable pull-up
    cbi DDRD, 2        ; Set PD2 as input
    
    ; Wait for DHT11 to pull the line low (response)
dht_wait_low:
    sbic PIND, 2
    rjmp dht_wait_low

; Wait for DHT11 to pull the line high
dht_wait_high:
    sbis PIND, 2
    rjmp dht_wait_high

; Wait for DHT11 to pull the line low again (start of data)
dht_wait_low_again:
    sbic PIND, 2
    rjmp dht_wait_low_again
    

    ; Read 5 bytes (humidity int, humidity dec, temp int, temp dec, checksum)
read_data_start:
    ldi R25, 5         ; 5 bytes to read
    clr R19            ; Humidity int
    clr R20            ; Humidity dec
    clr R21            ; Temp int
    clr R22            ; Temp dec
    clr R23            ; Checksum
    
read_next_byte:
    ldi R17, 8         ; 8 bits per byte
    clr R18            ; Clear byte accumulator  
w4:
    sbis PIND, 2
    rjmp w4
    rcall delay_50us

    sbis PIND, 2
    rjmp skp
    sec
    rol R18
    rjmp w5
skp:
    lsl R18
w5:
    sbic PIND, 2
    rjmp w5
    dec R17
    brne w4
    
read_byte_complete:
    ; Store byte based on counter
    cpi R25, 5
    breq store_humidity_int
    cpi R25, 4
    breq store_humidity_dec
    cpi R25, 3
    breq store_temp_int
    cpi R25, 2
    breq store_temp_dec
    cpi R25, 1
    breq store_checksum
    
store_humidity_int:
    mov R19, R18
    dec R25
    rjmp read_next_byte
    
store_humidity_dec:
    mov R20, R18
    dec R25
    rjmp read_next_byte
    
store_temp_int:
    mov R21, R18
    dec R25
    rjmp read_next_byte
    
store_temp_dec:
    mov R22, R18
    dec R25
    rjmp read_next_byte
    
store_checksum:
    mov R23, R18
    
display_temperature:
    ; Convert temperature integer to ASCII and display it
    mov R17, R21      ; Get temperature integer part

    cpi R26, 1
    breq isManual
    call spin_motor
    rjmp continue
isManual:
    call spin_manual
continue:
    
    ; First convert to BCD
    clr R24           ; Tens digit
tens_loop:
    cpi R17, 10
    brlo display_temp
    subi R17, 10
    inc R24
    rjmp tens_loop
    
display_temp:
    ; Display tens digit
    ldi R28, '0'
    add R24, R28    ; Convert to ASCII
    mov R16, R24
    rcall send_data
    
    ; Display ones digit
    add R17, R28    ; Convert to ASCII
    mov R16, R17
    rcall send_data

    ; Display degree symbol
    ldi R16, 0xDF     ; Degree symbol in LCD
    rcall send_data
    
    ; Display 'C' for Celsius
    ldi R16, 'C'
    rcall send_data
    RET


;=========================================================================== display_speed_text (use R16, R30, R31)
; call send_command (use R16 from here, R17, R18), delay_ms (use R20)

display_speed_text:
    ; Move to second line of LCD
    ldi R16, 0xC0      ; Set cursor to second line
    rcall send_command
    rcall delay_ms
    
    ldi R30, lo8(string_speed)
    ldi R31, hi8(string_speed)

speed_loop_send:
    lpm R16, Z+        ; load char from Flash and increment Z
    tst R16            ; test if zero (end of string)
    breq speed_done
    rcall send_data    ; Send character to LCD
    rjmp speed_loop_send

speed_done:
    RET


;=========================================================================== display_speed_value (use R16, R21 from DHT11_read_data, R30, R31)
; call send_data (use R16 from here, R17, R18)

display_speed_value:
    cpi R26, 1
    breq display_manual

    ; Check temperature threshold (R21 contains temperature integer)
    cpi R21, 30
    brsh display_high       ; if temperature >= 30, display "HIGH"
    cpi R21, 20
    brsh display_medium     ; if temperature 20 <= x < 30, display "MEDIUM"
    brlo display_low        ; If temperature < 20, display "LOW"

display_manual:
    ldi R30, lo8(string_manual)
    ldi R31, hi8(string_manual)
    rjmp display_speed_string
    
display_high:
    ldi R30, lo8(string_high)
    ldi R31, hi8(string_high)
    rjmp display_speed_string

display_medium:
    ldi R30, lo8(string_medium)
    ldi R31, hi8(string_medium)
    rjmp display_speed_string

display_low:
    ldi R30, lo8(string_low)
    ldi R31, hi8(string_low)
    
display_speed_string:
    lpm R16, Z+        ; load char from Flash and increment Z
    tst R16            ; test if zero (end of string)
    breq display_speed_done
    rcall send_data    ; Send character to LCD
    rjmp display_speed_string

display_speed_done:
    RET


;=========================================================================== LCD_init

LCD_init:
    ldi R16, 0x33       
    rcall send_command
    rcall delay_ms

    ldi R16, 0x32
    rcall send_command
    rcall delay_ms

    ldi R16, 0x28
    rcall send_command
    rcall delay_ms

    ldi R16, 0x0C
    rcall send_command
    ldi R16, 0x01
    rcall send_command
    rcall delay_ms
    
    ldi R16, 0x06
    rcall send_command

    RET


;=========================================================================== I2C_init

I2C_init:
    CLR R16
    STS TWSR, R16
    LDI R16, 12         ;division factor = 12
    STS TWBR, R16       ;SCK freq = 400kHz
    LDI R16, (1<<TWEN)
    STS TWCR, R16       ;enable TWI
    RET


;=========================================================================== I2C_start (use R19)

i2c_start:
    LDI R19, 0b10100100
    STS TWCR, R19        ; clear TWINT flag, TWSA (START condition) and TWEN (enable TWI)
    wait_start:
        LDS R19, TWCR
        sbrs R19, 7
        rjmp wait_start
    RET


;=========================================================================== I2C_write (use R18 from outside, R19)

i2c_write:
    STS TWDR, R18           ; Load data into register
    LDI R19, 0b10000100
    STS TWCR, R19           ; clear TWINT flag & set TWEN (enable TWI)        
    wait_data:
        LDS R19, TWCR
        sbrs R19, 7
        rjmp wait_data
    RET


;=========================================================================== I2C_stop (use R19)

i2c_stop:
    LDI R19, 0b10010100
    STS TWCR, R19           ; clear TWINT flag, TWSTO (STOP condition) and TWEN (enable TWI)
    RET


;=========================================================================== send_command (use R16 from outside, R17, R18)
; call i2c_start (use R19), i2c_write (use R18 from here, R19), i2c_stop (use R19)

send_command:
    push R17
    push R18

    ldi R17, 0x00       ; Assume no backlight (adjust if needed), RW = 0
    cbr  R17, 1         ; RW = 0 for write
    cbr  R17, 0         ; RS = 0 for command

    ; First nibble (upper 4 bits of command)
    mov R18, R16
    andi R18, 0xF0      ; Mask upper nibble
    or R18, R17         ; Combine with RS, RW, E=0

    rcall i2c_start
    ldi R18, 0x40       ; PCF8574 write address
    rcall i2c_write

    mov R18, R16
    andi R18, 0xF0      ; Upper nibble
    or R18, R17         ; Add RS, RW
    sbr R18, (1 << 2)   ; E = 1
    rcall i2c_write

    cbr R18, (1 << 2)   ; E = 0
    rcall i2c_write

    rcall delay_ms   ; ~1ms delay

    ; Second nibble (lower 4 bits of command)
    mov R18, R16
    swap R18            ; Bring lower nibble to upper
    andi R18, 0xF0      ; Mask again
    or R18, R17         ; Add RS, RW
    sbr R18, (1 << 2)   ; E = 1
    rcall i2c_write

    cbr R18, (1 << 2)   ; E = 0
    rcall i2c_write

    rcall delay_ms   ; ~1ms delay

    rcall i2c_stop

    pop R18
    pop R17
    RET


;=========================================================================== send_data (use R16 from outside, R17, R18)
; call i2c_start (use R19), i2c_write (use R18 from here, R19), i2c_stop (use R19)

send_data:
    push R17
    push R18

    ldi R17, 0x00       ; Assume no backlight (adjust if needed), RW = 0
    cbr  R17, (1 << 1)        ; RW = 0 for write
    sbr  R17, (1 << 0)         ; RS = 1 for data

    ; First nibble (upper 4 bits of command)
    mov R18, R16
    andi R18, 0xF0      ; Mask upper nibble
    or R18, R17         ; Combine with RS, RW, E=0

    rcall i2c_start
    ldi R18, 0x40       ; PCF8574 write address
    rcall i2c_write

    mov R18, R16
    andi R18, 0xF0      ; Upper nibble
    or R18, R17         ; Add RS, RW
    sbr R18, (1 << 2)   ; E = 1
    rcall i2c_write

    cbr R18, (1 << 2)   ; E = 0
    rcall i2c_write

    rcall delay_ms   ; ~1ms delay

    ; Second nibble (lower 4 bits of command)
    mov R18, R16
    swap R18            ; Bring lower nibble to upper
    andi R18, 0xF0      ; Mask again
    or R18, R17         ; Add RS, RW
    sbr R18, (1 << 2)   ; E = 1
    rcall i2c_write

    cbr R18, (1 << 2)   ; E = 0
    rcall i2c_write

    rcall delay_ms   ; ~1ms delay

    rcall i2c_stop

    pop R18
    pop R17
    RET


;=========================================================================== spin_motor

spin_motor:
    cpi R21, 30
    brsh full_speed
    cpi R21, 20
    brsh medium_speed
    brlo low_speed

full_speed:
    ldi R27, 255
    sts OCR2B, R27         ; fan at 100% speed
    RET

medium_speed:
    ldi R27, 128
    sts OCR2B, R27         ; fan at 50% speed
    RET

low_speed:
    ldi R27, 64
    sts OCR2B, R27         ; fan at 25% speed
    RET


;=========================================================================== spin_manual

spin_manual:
    ldi R27, 0b11000111
    sts ADCSRA, R27
wait_adc:
    lds R27, ADCSRA
    sbrs R27, ADIF
    rjmp wait_adc

    ldi R27, 0b11010111
    sts ADCSRA, R27

    lds R28, ADCL           ; store low byte of ADC result
    lds R29, ADCH           ; store high byte of ADC result

    sts OCR2B, R29
    RET

;=========================================================================== delay routines

delay_ms:
    clr R20
    out TCNT0, R20          ; clear timer0 count register
    ldi R20, 250        
    out OCR0A, R20          ; stop the timer at TCNT0 = 250 to get 1 ms delay at prescaler 64
    ldi R20, 0b00001011
    out TCCR0B, R20         ; configure TCCR0B with prescaler 64 and ctc mode
delay_ms_loop:
    in R20, TIFR0
    sbrs R20, OCF0A         ; repeat the loop if OCF0A isnt high
    rjmp delay_ms_loop

    clr R20
    out TCCR0B, R20         ; stop timer by clearing TCCR0B

    ldi R20, (1<<OCF0A)
    out TIFR0, R20          ; reset OCF0A flag
    RET


delay_20ms:
    clr R20
    sts TCNT1H, R20          ; clear timer0 count register
    sts TCNT1L, R20
    sts TCCR1A, R20

    ldi R20, hi8(1250)        
    sts OCR1AH, R20          ; stop the timer at TCNT1 = 1250 to get 20 ms delay at prescaler 256
    ldi R20, lo8(1250)
    sts OCR1AL, R20
    ldi R20, 0b00001100
    sts TCCR1B, R20         ; configure TCCR1B with prescaler 256 and ctc mode
delay_20ms_loop:
    in R20, TIFR1
    sbrs R20, OCF1A         ; repeat the loop if OCF1A isnt high
    rjmp delay_20ms_loop

    clr R20
    sts TCCR1B, R20         ; stop timer by clearing TCCR0B

    ldi R20, (1<<OCF1A)
    out TIFR1, R20          ; reset OCF0A flag
    RET


delay_50us:
    clr R20
    out TCNT0, R20          ; clear timer0 count register
    out TCCR0A, R20

    ldi R20, 100        
    out OCR0A, R20          ; stop the timer at TCNT0 = 100 to get 50 us delay
    ldi R20, 0b00001010
    out TCCR0B, R20         ; configure TCCR0B with prescaler 8 and ctc mode
delay_50us_loop:
    in R20, TIFR0
    sbrs R20, OCF0A         ; repeat the loop if OCF0A isnt high
    rjmp delay_50us_loop

    clr R20
    out TCCR0B, R20         ; stop timer by clearing TCCR0B

    ldi R20, (1<<OCF0A)
    out TIFR0, R20          ; reset OCF0A flag
    RET


delay_2s:
    clr R20
    sts TCNT1H, R20         ; clear timer1 count registers
    sts TCNT1L, R20
    sts TCCR1A, R20

    ldi R20, hi8(31250)
    sts OCR1AH, R20         ; insert high byte of 31250 (2 seconds delay)
    ldi R20, lo8(31250)
    sts OCR1AL, R20         ; insert low byte of 31250 

    ldi R20, 0b00001101
    sts TCCR1B, R20         ; use prescaler 1024 & ctc mode
delay_2s_loop:
    in R20, TIFR1
    sbrs R20, OCF1A         ; check if timer1 count = OCR1A
    rjmp delay_2s_loop

    clr R20
    sts TCCR1B, R20         ; stop timer 
    ldi R20, (1<<OCF1A)
    out TIFR1, R20 
    RET
