; solution to project euler #3
; https://projecteuler.net/problem=3
; algorithm: test odd divisors 3, 5, 7, 9 etc (so not necessarily prime) and
; cast out the factors from the input number until current divisor*divisor
; exceeds remaining input. whatever remains is the largest prime factor

	CHROUT = $ffd2

	!to "003.prg",cbm
	* = $0801
	; sys 2071
	!byte $0b, $08, $0a, $00, $9e, $32, $30, $37, $31, $00, $00, $00

	; the number we want to factor is 600851475143, but ACME doesn't support
	; ints larger than 32 bits. the actual input is translated to hex and
	; placed at address n. also, the program assumes it's odd.
	; program is not guaranteed to handle square factor of largest prime
	; factor
n	!byte $c7, $ea, $89, $e5, $8b
ntemp	!byte 0,0,0,0,0

	sei
	ldx #4
-	lda n,x
	sta ntemp,x
	dex
	bpl -
	; start by printing out the number we want to factor
	ldx #0
-	lda factor,x
	jsr CHROUT
	inx
	cpx #found-factor
	bne -
	ldx #<ntemp
	ldy #>ntemp
	jsr printnumber
	lda #$0d
	jsr CHROUT
	; init
	ldx #3
	stx divisor
	ldx #0
	stx divisor+1
	stx divisor+2
	stx divisor+3
	stx divisor+4
	; loop through factors
loop	ldx #4
-	lda ntemp,x
	sta dividend,x
	dex
	bpl -
	jsr div40 ; inefficient since we do full 40-bit division always...
	; check if quotient < divisor, then we are done
	lda divisor+0
	cmp dividend+0
	lda divisor+1
	sbc dividend+1
	lda divisor+2
	sbc dividend+2
	lda divisor+3
	sbc dividend+3
	lda divisor+4
	sbc dividend+4
	bcc + ; carry set: quotient (dividend) >= divisor, continue
	jmp done
+	; check remainder
	lda #$00
	ldx #4
--	ora remainder,x
	dex
	bpl --
	cmp #0
	bne +
	; remainder=0: we found a factor. set n to quotient and divide again
	ldx #4
-	lda dividend,x
	sta ntemp,x
	dex
	bpl -
	ldx #0
-	lda found,x
	jsr CHROUT
	inx
	cpx #answer-found
	bne -
	ldx #<divisor
	ldy #>divisor
	jsr printnumber
	lda #$0d
	jsr CHROUT
	jmp loop
+	; try next divisor: add 2 to divisor and go back
	lda divisor+0
	clc
	adc #2
	sta divisor+0
	bcc +
	inc divisor+1
	bne +
	inc divisor+2
	bne +
	inc divisor+3
	bne +
	inc divisor+4
+	jmp loop
done	; we are done, output answer
	ldx #0
-	lda answer,x
	jsr CHROUT
	inx
	cpx #endtext-answer
	bne -
	ldx #<ntemp
	ldy #>ntemp
	jsr printnumber
	lda #$0d
	jmp CHROUT

factor	!text "FACTOR "
found	!text "FOUND DIVISOR: "
answer	!text "ANSWER: "
endtext

printnumber stx valz+1
	sty valz+2
	ldx #4
valz	lda $ffff,x
	sta inbcd,x
	dex
	bpl valz
	jsr int40tobcd
	ldx #<outbcd
	ldy #>outbcd
	lda #7
	jmp printbcd

; calculate quotient and remainder of division for unsigned 40-bit ints
; (divide "dividend" by "divisor")
; inputs: dividend, divisor (5 bytes)
; outputs: dividend (=quotient), remainder (5 bytes each)
; clobbered: a,x,y,dividend
; based on http://codebase64.org/doku.php?id=base:24bit_division_24-bit_result
div40	lda #0
	sta remainder+0
	sta remainder+1
	sta remainder+2
	sta remainder+3
	sta remainder+4
	ldx #40
divloop	asl dividend+0
	rol dividend+1
	rol dividend+2
	rol dividend+3
	rol dividend+4
	rol remainder+0
	rol remainder+1
	rol remainder+2
	rol remainder+3
	rol remainder+4
	; check if remainder >= divisor
	lda remainder+0
	sec
	sbc divisor+0
	tay
	lda remainder+1
	sbc divisor+1
	sta divtemp+0
	lda remainder+2
	sbc divisor+2
	sta divtemp+1
	lda remainder+3
	sbc divisor+3
	sta divtemp+2
	lda remainder+4
	sbc divisor+4
	bcc +
	sta remainder+4
	lda divtemp+2
	sta remainder+3
	lda divtemp+1
	sta remainder+2
	lda divtemp+0
	sta remainder+1
	sty remainder+0
	inc dividend
+	dex
	bne divloop
	rts
divtemp !byte 0,0,0
dividend !byte 0,0,0,0,0
remainder !byte 0,0,0,0,0
divisor	!byte 0,0,0,0,0

; convert unsigned 5-byte int to 7-byte (14-digit) bcd
; input value: expected in inbcd
; output value: written to outbcd
; clobbered: a,x
; warning, don't run with an interrupt that doesn't preserve decimal
; flag, such as the KERNAL
; inspired by http://codebase64.org/doku.php?id=base:more_hexadecimal_to_decimal_conversion
; (too lazy to make a general routine right now. also, preserving carry in loops
; can get ugly. a general routine would be fine since div is the hotspot)
int40tobcd ldx #0
	stx outbcd+0
	stx outbcd+1
	stx outbcd+2
	stx outbcd+3
	stx outbcd+4
	stx outbcd+5
	stx outbcd+6
	ldx #40
	sed
-	asl inbcd+0
	rol inbcd+1
	rol inbcd+2
	rol inbcd+3
	rol inbcd+4
	lda outbcd+0
	adc outbcd+0
	sta outbcd+0
	lda outbcd+1
	adc outbcd+1
	sta outbcd+1
	lda outbcd+2
	adc outbcd+2
	sta outbcd+2
	lda outbcd+3
	adc outbcd+3
	sta outbcd+3
	lda outbcd+4
	adc outbcd+4
	sta outbcd+4
	lda outbcd+5
	adc outbcd+5
	sta outbcd+5
	lda outbcd+6
	adc outbcd+6
	sta outbcd+6
	dex
	bne -
	cld
	rts
inbcd	!byte 0,0,0,0,0
outbcd	!byte 0,0,0,0,0,0,0

; print bcd number to CHROUT, don't output leading zeroes
; x,y: pointer to number
; a: length of number (in bytes)
; clobbered: a,x,y
printbcd stx val+1
	sty val+2
	tax
	dex
	ldy #0 ; y=0: zeroes are still leading
-
val	lda $0000,x
	pha
	lsr
	lsr
	lsr
	lsr
	jsr printchar
	pla
	and #$0f
	jsr printchar
	dex
	bpl -
	cpy #0
	beq + ; y still 0: print 0
	rts
printchar cpy #0
	bne +
	cmp #0
	beq ++
	ldy #1 ; y=1: print all digits from here
+	ora #$30
	jmp CHROUT
++	rts
