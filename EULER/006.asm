; solution to project euler #6
; https://projecteuler.net/problem=6
; algorithm: just calculate it

	CHROUT = $ffd2
	MAX = 100 ; less than 256

	!to "006.prg",cbm
	* = $0801
	; sys start
	!byte $0b, $08, $0a, $00, $9e, 48+start/1000%10, 48+start/100%10, 48+start/10%10, 48+start%10, $00, $00, $00

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

; print bcd number to CHROUT, don't output leading zeroes
; x,y: address of number
; a: length of number (in bytes)
; clobbered: a,x,y
printbcd stx bcdval+1
	sty bcdval+2
	tax
	dex
	ldy #0 ; y=0: zeroes are still leading
-
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

start	sei
	; init, set sums to 0
	ldx #0
	stx sumsq+0
	stx sumsq+1
	stx sumsq+2
	stx sumsq+3
	stx sum+0
	stx sum+1
	; loop y=1 to 100
	ldy #1
loop	; add y to sum (that is to be squared)
	clc
	tya
	adc sum+0
	sta sum+0
	bcc +
	inc sum+1
+	; calculate y*y
	ldx #0
	sty mul1+0
	stx mul1+1
	sty mul2+0
	stx mul2+1
	jsr mul16
	; add product to sum of squares
	clc
	lda sumsq+0
	adc product+0
	sta sumsq+0
	lda sumsq+1
	adc product+1
	sta sumsq+1
	; product is max 16 bits, take small shortcut
	bcc +
	inc sumsq+2
	bne +
	inc sumsq+3
+	iny
	cpy #MAX+1
	bne loop
	; square the other sum
	ldx sum+0
	ldy sum+1
	stx mul1+0
	sty mul1+1
	stx mul2+0
	sty mul2+1
	jsr mul16
	; calculate product - sumsq
	sec
	lda product+0
	sbc sumsq+0
	sta product+0
	lda product+1
	sbc sumsq+1
	sta product+1
	lda product+2
	sbc sumsq+2
	sta product+2
	lda product+3
	sbc sumsq+3
	sta product+3
	; print answer (which is in product)
	ldx #3
-	lda product,x
	sta inbcd,x
	dex
	bpl -
	jsr int32tobcd
	lda #5
	ldx #<outbcd
	ldy #>outbcd
	jsr printbcd
	lda #$0d
	jmp CHROUT

sumsq	!byte 0,0,0,0
sum	!byte 0,0
