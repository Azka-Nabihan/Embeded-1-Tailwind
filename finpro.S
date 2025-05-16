#define __SFR_OFFSET 0
#include "avr/io.h"

.global setup
.global loop

.section .progmem.data          ; store strings in flash memory
string_temperature:
    .ascii "Temperature: \0"
string_speed:
    .ascii "Speed: \0"
string_high:
    .ascii "HIGH\0"
string_low:
    .ascii "LOW\0"

.text

setup:
    ldi R16, 0xFF
    out DDRD, R16   ; all PORTD as output
    out DDRB, R16   ; all PORTB as output
    out DDRC, R16   ; all PORTC as output
    
    ; Configure PB5 for DHT11
    cbi DDRD, 2     ; Set PD2 as input initially
    cbi PORTD, 2    ; No pull-up initially
    
    cbi PORTB, 0    ; set E pin to 0

    call LCD_init
    call delay_2s   ; Wait for DHT11 to stabilize
    
loop:
    call LCD_clear
    call display_temperature_text    ; Display "Temperature: " text
    call DHT11_read_data             ; Read temperature data from DHT11
    call display_speed_text          ; Display "Speed: " text
    call display_speed_value         ; Display "HIGH" or "LOW" based on temperature
    call delay_2s                    ; Wait before next reading
    rjmp loop

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

;=========================================================================== LCD_clear

LCD_clear:
    ldi R16, 0x01      ; Clear display command
    rcall send_command
    rcall delay_ms
    RET

;=========================================================================== display_temperature_text

display_temperature_text:
    ldi R30, lo8(string_temperature)
    ldi R31, hi8(string_temperature)

temp_loop_send:
    lpm R16, Z+        ; load char from Flash and increment Z
    tst R16            ; test if zero (end of string)
    breq temp_done
    mov R17, R16       ; Move to R17 for send_data
    rcall send_data    ; Send character to LCD
    rjmp temp_loop_send

temp_done:
    RET

;=========================================================================== display_speed_text

display_speed_text:
    ; Move to second line of LCD
    ldi R16, 0xC0      ; Set cursor to second line
    rcall send_command
    rcall delay_us
    
    ldi R30, lo8(string_speed)
    ldi R31, hi8(string_speed)

speed_loop_send:
    lpm R16, Z+        ; load char from Flash and increment Z
    tst R16            ; test if zero (end of string)
    breq speed_done
    mov R17, R16       ; Move to R17 for send_data
    rcall send_data    ; Send character to LCD
    rjmp speed_loop_send

speed_done:
    RET

;=========================================================================== display_speed_value

display_speed_value:
    ; Check temperature threshold (R21 contains temperature integer)
    cpi R21, 25
    brlo display_low   ; If temperature < 25, display "LOW"
    
display_high:
    ldi R30, lo8(string_high)
    ldi R31, hi8(string_high)
    rjmp display_speed_string

display_low:
    ldi R30, lo8(string_low)
    ldi R31, hi8(string_low)
    
display_speed_string:
    lpm R16, Z+        ; load char from Flash and increment Z
    tst R16            ; test if zero (end of string)
    breq display_speed_done
    mov R17, R16       ; Move to R17 for send_data
    rcall send_data    ; Send character to LCD
    rjmp display_speed_string

display_speed_done:
    RET

;=========================================================================== DHT11_read_data
; register used : R16, R17, R18, R19, R20, R21, R22, R23, R24, R25, R28

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
    call spin_motor
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

;=========================================================================== send_command

send_command:
    mov R27, R16
    andi R27, 0xF0
    out PORTD, R27
    cbi PORTB, 1      ; RS = 0 for command
    sbi PORTB, 0      ; Set E high
    rcall delay_short

    cbi PORTB, 0      ; Set E low
    rcall delay_us

    mov R27, R16
    swap R27
    andi R27, 0xF0
    out PORTD, R27
    sbi PORTB, 0      ; Set E high
    rcall delay_short

    cbi PORTB, 0      ; Set E low
    rcall delay_us

    RET

;=========================================================================== send_data

send_data:
    mov R27, R16
    andi R27, 0xF0
    out PORTD, R27
    sbi PORTB, 1      ; RS = 1 for data
    sbi PORTB, 0      ; Set E high
    rcall delay_short

    cbi PORTB, 0      ; Set E low
    rcall delay_us

    mov R27, R16
    swap R27
    andi R27, 0xF0
    out PORTD, R27
    sbi PORTB, 1      ; RS = 1 for data
    sbi PORTB, 0      ; Set E high
    rcall delay_short

    cbi PORTB, 0      ; Set E low
    rcall delay_us
    RET

;=========================================================================== spin_motor

spin_motor:
    clr R28
    sts TCNT1H, R28
    sts TCNT1L, R28

    sbi DDRB, 2
    ldi R28, 0b00100011     
    sts TCCR1A, R28         ; fast pwm mode, non inverting
    ldi R28, 0b00011010     
    sts TCCR1B, R28         ; fast pwm mode, prescaler 8

    cpi R21, 25
    brsh full_speed
    brlo half_speed

full_speed:
    ldi R28, 255
    sbi PORTC, 1            ; turn on LED if full speed
    sts OCR1BL, R28
    RET

half_speed:
    ldi R28, 128
    cbi PORTC, 1            ; turn off LED if half speed
    sts OCR1BL, R28
    RET

;=========================================================================== delay routines

delay_short:
    nop
    nop
    RET

delay_us:
    ldi R20, 90
l1:
    rcall delay_short
    dec R20
    brne l1
    RET

delay_ms:
    ldi R21, 40
l2:
    rcall delay_us
    dec R21
    brne l2
    RET

delay_20ms:
    ldi R21, 255
l3: 
    ldi R22, 210
l4: 
    ldi R23, 2  
l5:
    dec R23
    brne l5
    dec R22
    brne l4
    dec R21
    brne l3
    RET

delay_50us:
    clr R20
    out TCNT0, R20          ; reset counter register
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
    ldi R21, 255
l8:    
    ldi R22, 255
l9:
    ldi R23, 164
l10:
    dec R23
    brne l10
    dec R22
    brne l9
    dec R21
    brne l8
    RET