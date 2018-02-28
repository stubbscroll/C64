; greatest common divisor (gcd) and lcm (least common multiple) for 32-bit ints.
; includes needed subroutes like mul and div

	CHROUT = $ffd2

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

; calculate gcd (greatest common divisor) of unsigned 32-bit ints
; using euclid's algorithm: gcd(a,b) = gcd(b, a mod b).
; preferably call with a>b (or else first the iteration is wasted),
; and don't call with a=b=0.
; inputs: gcda, gcdb (4 bytes each)
; output: gcda (4 bytes)
; clobbered: a,x,y,gcda,gcdb

gcd	; if b=0, terminate with result in a
	lda gcdb+0
	ora gcdb+1
	ora gcdb+2
	ora gcdb+3
	bne +
	rts
	; calculate a mod b
+	ldx #3
-	lda gcda,x
	sta dividend,x
	lda gcdb,x
	sta divisor,x
	dex
	bpl -
	jsr div32
	; set a=b, b=a mod b and repeat
	ldx #3
-	lda gcdb,x
	sta gcda,x
	dex
	bpl -
	ldx #3
-	lda remainder,x
	sta gcdb,x
	dex
	bpl -
	bmi gcd

gcda	!byte 0,0,0,0
gcdb	!byte 0,0,0,0

; calculate lcm(a,b) (least common multiple) of unsigned 32-bit ints
; method: a/gcd(a,b)*b
; please only call with a,b>0
; inputs: lcma, lcmb (4 bytes each)
; output: lcmres (8 bytes)
; clobbered: a,x,y

lcm	; calculate gcd(a,b)
	ldx #3
-	lda lcma,x
	sta gcda,x
	lda lcmb,x
	sta gcdb,x
	dex
	bpl -
	jsr gcd
	; calculate a/gcd(a,b)
	ldx #3
-	lda lcma,x
	sta dividend,x
	lda gcda,x
	sta divisor,x
	dex
	bpl -
	jsr div32
	; multiply result from last step by b
	; take care since mul and div uses overlapping zp variables
	ldx #3
-	lda dividend,x
	sta lcmtemp,x
	dex
	bpl -
	ldx #3
-	lda lcmtemp,x
	sta mul1,x
	lda lcmb,x
	sta mul2,x
	dex
	bpl -
	jsr mul32
	; copy final result
	ldx #7
-	lda product,x
	sta lcmres,x
	dex
	bpl -
	rts

lcmtemp	!byte 0,0,0,0
lcma	!byte 0,0,0,0
lcmb	!byte 0,0,0,0
lcmres	!byte 0,0,0,0,0,0,0,0
