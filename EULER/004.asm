; solution to project euler #4
; https://projecteuler.net/problem=4
; algorithm: try all possible 3-digit pairs and find largest palindrome product.
; start with the largest numbers and prune cases that can't result in a better
; answer

	CHROUT = $ffd2

	!to "004.prg",cbm
	* = $0801
	; sys start
	!byte $0b, $08, $0a, $00, $9e, 48+start/1000%10, 48+start/100%10, 48+start/10%10, 48+start%10, $00, $00, $00

; multiply two unsigned 16-bit integers and get 32-bit product
; input: mul1, mul2 (2 bytes each)
; output: product (4 bytes)
; clobbered: a,x,mul1
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

; convert unsigned 24-bit int to 32-bit (8-digit) bcd
; input value: in24
; output value: out32
; clobbered: a,x
; warning, don't run with an interrupt that doesn't preserve decimal flag,
; such as the KERNAL
; inspired by http://codebase64.org/doku.php?id=base:more_hexadecimal_to_decimal_conversion
int24tobcd ldx #0
	stx out32+0
	stx out32+1
	stx out32+2
	stx out32+3
	ldx #23
	sed
-	asl in24+0
	rol in24+1
	rol in24+2
	lda out32+0
	adc out32+0
	sta out32+0
	lda out32+1
	adc out32+1
	sta out32+1
	lda out32+2
	adc out32+2
	sta out32+2
	lda out32+3
	adc out32+3
	sta out32+3
	dex
	bpl -
	cld
	rts
in24	!byte 0,0,0
out32	!byte 0,0,0,0

start	sei
	; init
	lda #0
	sta maxpalin+0
	sta maxpalin+1
	sta maxpalin+2
	lda #$30
	ldx #5
-	sta best,x
	dex
	bpl -
	; idea: calculate mula*mulb and find largest palindrome product by
	; trying all possible 3-digit values of mula and mulb.
	; iterate through all mula downwards from 999 to 100
	ldx #<999
	ldy #>999
	stx mula+0
	sty mula+1
loop	; for each mula, iterate through all mulb from mula to 999
	; (for a<b, check a*b but not b*a to halve runtime)
	ldx mula+0
	ldy mula+1
	stx mulb+0
	sty mulb+1
	; terminate if maxpalin / mula >= 1000 since we can't possibly get
	; a better answer with a 3-digit multiplicand
	lda maxpalin
	ldx maxpalin+1
	ldy maxpalin+2
	sta dividend+0
	stx dividend+1
	sty dividend+2
	lda mula+0
	ldx mula+1
	ldy #0
	sta divisor+0
	stx divisor+1
	sty divisor+2
	jsr div24
	lda dividend+0
	cmp #<1000
	lda dividend+1
	sbc #>1000
	bcc loop2
	; terminate
	rts
loop2	; calculate mula*mulb
	ldx mula+0
	ldy mula+1
	stx mul1+0
	sty mul1+1
	ldx mulb+0
	ldy mulb+1
	stx mul2+0
	sty mul2+1
	jsr mul16
	; is the result palindrome? first, convert product to bcd
	ldx #2
-	lda product,x
	sta in24,x
	dex
	bpl -
	jsr int24tobcd
	; then convert bcd to string
	ldx #2
	ldy #0
-	lda out32,x
	lsr
	lsr
	lsr
	lsr
	ora #$30
	sta curpalin,y
	iny
	lda out32,x
	and #$0f
	ora #$30
	sta curpalin,y
	iny
	dex
	bpl -
	; check if it's a palindrome (hardcoded for 6 digits)
	lda curpalin+0
	cmp curpalin+5
	bne failed
	lda curpalin+1
	cmp curpalin+4
	bne failed
	lda curpalin+2
	cmp curpalin+3
	bne failed
	; it's a palindrome. check if it's the largest one so far
	ldx #2
-	lda product,x
	cmp maxpalin,x
	beq next   ; product = maxpalin (this digit), check next digit
	bcc failed ; product < maxpalin, skip
	bcs larger ; product > maxpalin, keep it as the new best
next	dex
	bpl -
	bmi failed ; product = maxpalin (entire number), not good enough
larger	ldx #5     ; store largest palindrome (as string)
-	lda curpalin,x
	sta best,x
	dex
	bpl -
	ldx #2     ; store largest palindrome (as binary)
-	lda product,x
	sta maxpalin,x
	dex
	bpl -
	ldx #0     ; print a blurb saying we found a larger one
-	lda found,x
	jsr CHROUT
	inx
	cpx #endtext-found
	bne -
	ldx #0
-	lda best,x
	jsr CHROUT
	inx
	cpx #6
	bne -
	lda #$0d
	jsr CHROUT
failed	; try next numbers to multiply, increase mulb by 1 until it's 1000
	inc mulb+0
	bne +
	inc mulb+1
+	lda mulb+0
	cmp #<1000
	lda mulb+1
	sbc #>1000
	bcs +
	jmp loop2
	; decrease mula by 1 and do outer loop again
+	lda mula+0
	bne +
	dec mula+1
+	dec mula+0
	; don't care to check if we're done looping,
	; rely on the other termination condition instead.
	; it only fails if there are no palindromes, which isn't the case
	jmp loop

mula	!byte 0,0
mulb	!byte 0,0

found	!text "FOUND "
endtext
maxpalin !byte 0,0,0   ; largest so far (in binary)
best	!text "000000" ; largest so far (as string)
curpalin !text "000000" ; current palindrome
