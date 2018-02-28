; solution to project euler #8
; https://projecteuler.net/problem=8
; algorithm: for each starting index, multiply the 13 next digits and
; take the maximum

	CHROUT = $ffd2

	!to "008.prg",cbm
	* = $0801
	; sys start
	!byte $0b, $08, $0a, $00, $9e, 48+start/1000%10, 48+start/100%10, 48+start/10%10, 48+start%10, $00, $00, $00

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


; multiply 48-bit integer by byte using repeated addition
; input: 48-bit number in mul1, byte in x
; output: product
; clobbered: a,x,y

mul1 !byte 0,0,0,0,0,0
product	!byte 0,0,0,0,0,0
mul2 = $02

slowmul	stx mul2
	ldy #5
	lda #0
-	sta product,y
	dey
	bpl -
	lda mul2
	beq muldone
--	ldy #0
	ldx #6
	clc
-	lda product,y
	adc mul1,y
	sta product,y
	iny
	dex
	bne -
	dec mul2
	bne --
muldone	rts

ptr = $f8
ycopy = $f7

start	sei
	ldx #5
	lda #0
-	sta max,x
	dex
	bpl -
	; set ptr to start of number
	ldx #<number
	ldy #>number
	stx ptr+0
	sty ptr+1
	; loop until we find 0-byte
loop	ldy #12
	lda (ptr),y
	beq answer ; found 0-byte, print answer
+	; if the next 13 bytes contains the digit 0, skip as product is 0
-	lda (ptr),y
	cmp #$30
	beq skip
	dey
	bpl -
	; no 0, perform multiplication
	ldy #0
	lda (ptr),y
	and #$0f
	sta mul1+0 ; start product with first number
	sty mul1+1
	sty mul1+2
	sty mul1+3
	sty mul1+4
	sty mul1+5
	ldy #12
	sty ycopy
-	ldy ycopy
	lda (ptr),y
	and #$0f
	tax
	jsr slowmul
	ldx #5
--	lda product,x
	sta mul1,x
	dex
	bpl --
	dec ycopy
	bne -
	; compare against max so far
	ldx #5
-	lda mul1,x
	cmp max,x
	beq equal  ; equal so far, check next byte
	bcc skip   ; less than max, try next index
	bcs newmax ; new max
equal	dex
	bpl -
	bmi skip
newmax	ldx #5
-	lda mul1,x
	sta max,x
	dex
	bpl -
skip	inc ptr+0
	bne loop
	inc ptr+1
	bne loop
answer	ldx #5
-	lda max,x
	sta inbcd,x
	dex
	bpl -
	ldx #6
	ldy #7 ; 7 bytes suffice for upper bound 9^13
	jsr int2bcd
	lda #7
	ldx #<outbcd
	ldy #>outbcd
	jsr printbcd
	lda #$0d
	jmp CHROUT

max	!byte 0,0,0,0,0,0 ; upper bound, 9^13, needs 42 bits => 6 bytes

number	!text "73167176531330624919225119674426574742355349194934"
	!text "96983520312774506326239578318016984801869478851843"
	!text "85861560789112949495459501737958331952853208805511"
	!text "12540698747158523863050715693290963295227443043557"
	!text "66896648950445244523161731856403098711121722383113"
	!text "62229893423380308135336276614282806444486645238749"
	!text "30358907296290491560440772390713810515859307960866"
	!text "70172427121883998797908792274921901699720888093776"
	!text "65727333001053367881220235421809751254540594752243"
	!text "52584907711670556013604839586446706324415722155397"
	!text "53697817977846174064955149290862569321978468622482"
	!text "83972241375657056057490261407972968652414535100474"
	!text "82166370484403199890008895243450658541227588666881"
	!text "16427171479924442928230863465674813919123162824586"
	!text "17866458359124566529476545682848912883142607690042"
	!text "24219022671055626321111109370544217506941658960408"
	!text "07198403850962455444362981230987879927244284909188"
	!text "84580156166097919133875499200524063689912560717606"
	!text "05886116467109405077541002256983155200055935729725"
	!text "71636269561882670428252483600823257530420752963450"
	!byte 0
