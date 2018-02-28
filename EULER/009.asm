; solution to project euler #9
; https://projecteuler.net/problem=9
; algorithm: try all a between 1 and 332, do binary search on b to find the least
; value that satisfies a^2+b^2>=(1000-a-b)^2.
; i assume a<b<c, so a higher than 332 results in a+b+c>1000, so 332 is
; sufficient.
; runtime: 7 seconds

	CHROUT = $ffd2

	!to "009.prg",cbm
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

mul1	!byte 0,0,0,0   ; 4 bytes
mul2	!byte 0,0,0,0   ; 4 bytes
product = $f8 ; 8 bytes

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

; multiply two unsigned 32-bit integers and get 64-bit product
; input: mul1, mul2 (4 bytes each)
; output: product (8 bytes)
; clobbered: a,x,mul1
; based on http://codebase64.org/doku.php?id=base:16bit_multiplication_32-bit_product

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
-	rts
printchar cpy #0
	bne +
	cmp #0
	beq -
	ldy #1 ; y=1: print all digits from here
+	ora #$30
	jmp CHROUT

a	!byte 0,0
b	!byte 0,0
lo	!byte 0,0 ; binary search bounds
hi	!byte 0,0
c	!byte 0,0
aa	!byte 0,0,0 ; triangle sides squared
bb	!byte 0,0,0
cc	!byte 0,0,0
aabb	!byte 0,0,0 ; aa+bb

start	sei
	ldx #1
	stx a+0
	dex
	stx a+1
	; try all a from 1 to 332
loop	; set up binary search on b
	; we'll use a^2 several times, pre-calculate lit
	ldx a+0
	ldy a+1
	stx mul1+0
	sty mul1+1
	stx mul2+0
	sty mul2+1
	jsr mul16
	; need only lower 3 bytes of result
	lda product+0
	ldx product+1
	ldy product+2
	sta aa+0
	stx aa+1
	sty aa+2
	; lower bound: a+1
	lda a+0
	clc
	adc #1
	sta lo+0
	lda a+1
	adc #0
	sta lo+1
	; upper bound: we have a+b+(b+1)=1000 =>
	; 2b = 1000-1-a =>
	; b = (999-a)/2
	; since upper bound is exclusive, set hi=(999-a)/2+1
	lda #<999
	sec
	sbc a+0
	sta hi+0
	lda #>999
	sbc a+1
	lsr
	sta hi+1
	ror hi+0
	inc hi+0
	bne +
	inc hi+1
+
bloop	; binary search loop: find midpoint b=(lo+hi)/2
	lda lo+0
	clc
	adc hi+0
	sta b+0
	lda lo+1
	adc hi+1
	lsr
	sta b+1
	ror b+0
	; let c=1000-a-b
	lda #<1000
	sec
	sbc a+0
	sta c+0
	lda #>1000
	sbc a+1
	sta c+1
	lda c+0
	sec
	sbc b+0
	sta c+0
	lda c+1
	sbc b+1
	sta c+1
	; calculate b*b
	ldx b+0
	ldy b+1
	stx mul1+0
	sty mul1+1
	stx mul2+0
	sty mul2+1
	jsr mul16
	lda product+0
	ldx product+1
	ldy product+2
	sta bb+0
	stx bb+1
	sty bb+2
	; calculate c*c
	ldx c+0
	ldy c+1
	stx mul1+0
	sty mul1+1
	stx mul2+0
	sty mul2+1
	jsr mul16
	lda product+0
	ldx product+1
	ldy product+2
	sta cc+0
	stx cc+1
	sty cc+2
	; calculate a*a+b*b
	lda aa+0
	clc
	adc bb+0
	sta aabb+0
	lda aa+1
	adc bb+1
	sta aabb+1
	lda aa+2
	adc bb+2
	sta aabb+2
	; check if a*a+b*b=c*c. if we have that, we won
	lda aabb+0
	cmp cc+0
	bne bcheck
	lda aabb+1
	cmp cc+1
	bne bcheck
	lda aabb+2
	cmp cc+2
	bne bcheck
	jmp answer ; we won, output answer
bcheck	; check if a*a+b*b>=c*c
	lda aabb+0
	cmp cc+0
	lda aabb+1
	sbc cc+1
	lda aabb+2
	sbc cc+2
	bcc +
	; try lower b
	ldx b+0
	ldy b+1
	stx hi+0
	sty hi+1
	jmp binc
+	; try higher b
	lda b+0
	clc
	adc #1
	sta lo+0
	lda b+1
	adc #0
	sta lo+1
binc	; if lo=hi we finished the search
	lda lo+0
	cmp hi+0
	bne bloopz
	lda lo+1
	cmp hi+1
	beq bend
bloopz	jmp bloop
bend	; try next a
	inc a+0
	bne +
	inc a+1
	; don't bother with terminate condition since we are supposed
	; to find a solution with a<333
+	jmp loop
answer	; we have the correct values of a,b,c, output answer a*b*c
	; calculate a*b
	ldx a+0
	ldy a+1
	lda #0
	stx mul1+0
	sty mul1+1
	sta mul1+2
	sta mul1+3
	ldx b+0
	ldy b+1
	stx mul2+0
	sty mul2+1
	sta mul2+2
	sta mul2+3
	jsr mul32
	; multiply product from last step with c
	lda product+0
	ldx product+1
	ldy product+2
	sta mul1+0
	stx mul1+1
	sty mul1+2
	lda #0
	sta mul1+3
	ldx c+0
	ldy c+1
	stx mul2+0
	sty mul2+1
	sta mul2+2
	sta mul2+3
	jsr mul32
	; output answer
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

ans	!byte 0,0,0,0
