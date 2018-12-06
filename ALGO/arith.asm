; arithmetic subroutines
; warning, this file can't be assembled or included directly due to several
; identical identifiers.
; copy+paste the desired routines as needed instead
; for all routines: placing variables in zeropage is faster

	CHROUT = $ffd2

; compare 16-bit unsigned ints, a and b
; extends to more bytes by adding lda+sbc pairs for higher bytes
; to check for equality, compare all individual bytes instead

	lda a+0
	cmp b+0
	lda a+1
	sbc b+1
	bcc +
	; here a >= b
+	rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; multiply 16-bit integer in mul1 by 10, result in product
; this time, don't mess up endianness (should be little-endian)
; clobber: a, mul1
mul1	!byte 0,0
product	!byte 0,0

mul10	asl mul1+0
	rol mul1+1
	lda mul1+0
	sta product+0
	lda mul1+1
	sta product+1
	asl mul1+0
	rol mul1+1
	asl mul1+0
	rol mul1+1
	lda mul1+0
	clc
	adc product+0
	sta product+0
	lda mul1+1
	adc product+1
	sta product+1
	rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; multiply two unsigned 8-bit integers and get 16-bit product
; inputs: mul1, mul2
; output: product
; clobbered: a,x,mul1
; shortened from http://codebase64.org/doku.php?id=base:16bit_multiplication_32-bit_product

mul1 = $fe ; 1 byte
mul2 = $ff ; 1 byte
product = $fc ; 2 bytes

mul8	lda #0
	ldx #8
-	lsr mul1
	bcc +
	clc
	adc mul2
+	ror
	ror product+0
	dex
	bne -
	sta product+1
	rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; multiply two unsigned 16-bit integers and get 32-bit product
; input: mul1, mul2 (2 bytes each)
; output: product (4 bytes)
; clobbered: a,x,mul1
; better performance is achieved by ensuring that mul1 has fewer bits set than
; mul2
; taken from http://codebase64.org/doku.php?id=base:16bit_multiplication_32-bit_product

	mul1 = $f7    ; 2 bytes
	mul2 = $f9    ; 2 bytes
	product = $fb ; 4 bytes

mul16	lda #0
	sta product+2 ; clear upper bits of product
	sta product+3
	ldx #16       ; set binary count to 16
-	lsr mul1+1    ; divide multiplier by 2
	ror mul1+0
	bcc +
	lda product+2 ; get upper half of product and add multiplicand
	clc
	adc mul2+0
	sta product+2
	lda product+3
	adc mul2+1
+	ror           ; rotate partial product
	sta product+3
	ror product+2
	ror product+1
	ror product+0
	dex
	bne -
	rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; multiply two unsigned 32-bit integers and get 64-bit product
; input: mul1, mul2 (4 bytes each)
; output: product (8 bytes)
; clobbered: a,x,mul1
; based on http://codebase64.org/doku.php?id=base:16bit_multiplication_32-bit_product

mul1	!byte 0,0,0,0   ; 4 bytes
mul2	!byte 0,0,0,0   ; 4 bytes
product = $f8 ; 8 bytes

mul32	lda #0
	sta product+4 ; clear upper bits of product
	sta product+5
	sta product+6
	sta product+7
	ldx #32       ; set binary count to 24
-	lsr mul1+3    ; divide multiplier by 2
	ror mul1+2
	ror mul1+1
	ror mul1+0
	bcc +
	lda product+4 ; get upper half of product and add multiplicand
	clc
	adc mul2+0
	sta product+4
	lda product+5
	adc mul2+1
	sta product+5
	lda product+6
	adc mul2+2
	sta product+6
	lda product+7
	adc mul2+3
+	ror           ; rotate partial product
	sta product+7
	ror product+6
	ror product+5
	ror product+4
	ror product+3
	ror product+2
	ror product+1
	ror product+0
	dex
	bne -
	rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; calculate quotient and remainder of division for unsigned 24-bit ints
; (divide "dividend" by "divisor")
; inputs: dividend, divisor (3 bytes)
; outputs: dividend (=quotient), remainder (3 bytes each)
; clobbered: a,x,y,dividend
; taken from http://codebase64.org/doku.php?id=base:24bit_division_24-bit_result

	dividend = $fd  ; 3 bytes
	divisor = $fa   ; 3 bytes
	remainder = $f7 ; 3 bytes
	pztemp = $02    ; 1 byte

div24	lda #0	        ;preset remainder to 0
	sta remainder
	sta remainder+1
	sta remainder+2
	ldx #24         ;repeat for each bit: ...
-	asl dividend    ;dividend lb & hb*2, msb -> Carry
	rol dividend+1	
	rol dividend+2
	rol remainder   ;remainder lb & hb * 2 + msb from carry
	rol remainder+1
	rol remainder+2
	lda remainder
	sec
	sbc divisor     ;substract divisor to see if it fits in
	tay             ;lb result -> Y, for we may need it later
	lda remainder+1
	sbc divisor+1
	sta pztemp
	lda remainder+2
	sbc divisor+2
	bcc +           ;if carry=0 then divisor didn't fit in yet
	sta remainder+2 ;else save substraction result as new remainder,
	lda pztemp
	sta remainder+1
	sty remainder	
	inc dividend    ;and INCrement result cause divisor fit in 1 times
+	dex
	bne -	
	rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; calculate quotient and remainder of division for unsigned 32-bit ints
; (divide "dividend" by "divisor")
; inputs: dividend, divisor (4 bytes)
; outputs: dividend (=quotient), remainder (4 bytes each)
; clobbered: a,x,y,dividend
; based on http://codebase64.org/doku.php?id=base:24bit_division_24-bit_result

dividend = $f8          ; 4 bytes
divisor	!byte 0,0,0,0   ; 4 bytes
remainder = $fc         ; 4 bytes
pztemp	!byte 0,0       ; 2 bytes

div32	lda #0	        ;preset remainder to 0
	sta remainder+0
	sta remainder+1
	sta remainder+2
	sta remainder+3
	ldx #32         ;repeat for each bit: ...
-	asl dividend+0  ;dividend*2, msb -> Carry
	rol dividend+1	
	rol dividend+2
	rol dividend+3
	rol remainder+0 ;remainder*2 + msb from carry
	rol remainder+1
	rol remainder+2
	rol remainder+3
	lda remainder+0
	sec
	sbc divisor+0   ;substract divisor to see if it fits in
	tay             ;lb result -> Y, for we may need it later
	lda remainder+1
	sbc divisor+1
	sta pztemp+0
	lda remainder+2
	sbc divisor+2
	sta pztemp+1
	lda remainder+3
	sbc divisor+3
	bcc +           ;if carry=0 then divisor didn't fit in yet
	sta remainder+3 ;else save substraction result as new remainder,
	lda pztemp+1
	sta remainder+2
	lda pztemp+0
	sta remainder+1
	sty remainder+0
	inc dividend    ;and INCrement result cause divisor fit in 1 times
+	dex
	bne -	
	rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; convert unsigned 16-bit int to 24-bit (6-digit) bcd
; input value: inbcd
; output value: outbcd
; clobbered: a,x
; warning, don't run with an interrupt that doesn't handle decimal flag
; properly, such as the KERNAL
; stolen from http://codebase64.org/doku.php?id=base:more_hexadecimal_to_decimal_conversion
int16tobcd ldx #0
	stx outbcd+0
	stx outbcd+1
	stx outbcd+2
	ldx #15
	sed
-	asl inbcd+0
	rol inbcd+1
	lda outbcd+0
	adc outbcd+0
	sta outbcd+0
	lda outbcd+1
	adc outbcd+1
	sta outbcd+1
	lda outbcd+2
	adc outbcd+2
	sta outbcd+2
	dex
	bpl -
	cld
	rts
inbcd	!byte 0,0
outbcd	!byte 0,0,0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; convert unsigned 24-bit int to 32-bit (8-digit) bcd
; input value: inbcd
; output value: outbcd
; clobbered: a,x
; warning, don't run with an interrupt that doesn't handle decimal flag
; properly, such as the KERNAL
; inspired by http://codebase64.org/doku.php?id=base:more_hexadecimal_to_decimal_conversion
int24tobcd ldx #0
	stx outbcd+0
	stx outbcd+1
	stx outbcd+2
	stx outbcd+3
	ldx #23
	sed
-	asl inbcd+0
	rol inbcd+1
	rol inbcd+2
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
	dex
	bpl -
	cld
	rts
inbcd	!byte 0,0,0
outbcd	!byte 0,0,0,0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; convert unsigned 32-bit int to 40-bit (10-digit) bcd
; input value: inbcd
; output value: outbcd
; clobbered: a,x
; warning, don't run with an interrupt that doesn't handle decimal flag
; properly, such as the KERNAL
; inspired by http://codebase64.org/doku.php?id=base:more_hexadecimal_to_decimal_conversion
int32tobcd ldx #0
	stx outbcd+0
	stx outbcd+1
	stx outbcd+2
	stx outbcd+3
	stx outbcd+4
	ldx #31
	sed
-	asl inbcd+0
	rol inbcd+1
	rol inbcd+2
	rol inbcd+3
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
	dex
	bpl -
	cld
	rts
inbcd	!byte 0,0,0,0
outbcd	!byte 0,0,0,0,0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; convert unsigned 5-byte int to 7-byte (14-digit) bcd
; input value: inbcd
; output value: outbcd
; clobbered: a,x
; warning, don't run with an interrupt that doesn't handle decimal flag
; properly, such as the KERNAL
; inspired by http://codebase64.org/doku.php?id=base:more_hexadecimal_to_decimal_conversion
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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; convert unsigned x-byte int to y-byte bcd (max input length: 32 bytes)
; input value: inbcd
; input: x: length of input in bytes
; input: y: length of output in bytes
; output value: outbcd
; clobbered: a,x,y
; warning, don't run with an interrupt that doesn't handle decimal flag
; properly, such as the KERNAL
; inspired by http://codebase64.org/doku.php?id=base:more_hexadecimal_to_decimal_conversion

isize = $fe ; store input size
osize = $ff ; store output size
bcdi = $fd ; loop variable

int2bcd	txa
	dex
	stx isize
	sty osize
	asl
	asl
	asl
	sta bcdi
	; set output to 0
	ldx #0
	txa
-	sta outbcd,x
	inx
	cpx osize
	bne -
	sed
	; loop for each bit (isize*8 times), starting from the most significant
bcdloop	; rotate input number, get carry of successive lower bits
	asl inbcd
	ldx #1
	ldy isize
-	rol inbcd,x
	inx
	dey
	bne -
	; output = output*2 + carry
	ldx #0
	ldy osize
-	lda outbcd,x
	adc outbcd,x
	sta outbcd,x
	inx
	dey
	bne -
	dec bcdi
	bne bcdloop
	cld
	rts

inbcd	!byte 0,0,0,0,0,0,0,0,0,0,0,0
outbcd	!byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; print bcd number to CHROUT, don't output leading zeroes
; x,y: address of number
; a: length of number (in bytes)
; clobbered: a,x,y
printbcd stx bcdval+1
	sty bcdval+2
	tax
	dex
	ldy #0 ; y=0: zeroes are still leading
bcdval	lda $0000,x
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
	bpl bcdval
	cpy #0
	beq + ; y still 0: print 0
-	rts
printchar cpy #0
	bne +
	cmp #0
	beq -
	iny ; y=1: print all digits from here
+	ora #$30
	jmp CHROUT
