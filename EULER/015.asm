; solution to project euler #15
; https://projecteuler.net/problem=15
; algorithm: dynamic programming with 21*21 states, the value at (x,y) is the
; number of paths from (0,0) to (x,y).
; upper bound on int size: path is always 40 steps long, and because there are
; 2 different moves there are at most 2^40 paths. not all these paths are legal
; (for example moving right 40 times). 5 bytes suffice for 2^40-1 paths

	CHROUT = $ffd2

	!to "015.prg",cbm
	* = $0801
	; sys start
	!byte $0b, $08, $0a, $00, $9e, 48+start/1000%10, 48+start/100%10, 48+start/10%10, 48+start%10, $00, $00, $00

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

ptr1 = $fe
ptr2 = $fc

start	sei
	; find start of dp array: start of next page after end of program
	ldx #>end
	lda #<end
	beq +
	inx
+	stx dppage
	; pre-store answer for subproblem (0,0):
	; there is 1 route from (0,0) to (0,0)
	ldx #0
	ldy dppage
	stx ptr1+0
	sty ptr1+1
	ldy #0
	lda #1
-	sta (ptr1),y
	lda #0
	iny
	cpy #5
	bne -
	; start looping at x=1, y=0
	ldx #1
	ldy #0
	stx x
	sty y
	lda #8
	sta ptr1+0
loop	; first, set current state variable to 0
	ldy #4
	lda #0
-	sta (ptr1),y
	dey
	bpl -
	; the number of paths to the current point (x,y) is the sum of the
	; number of paths to (x-1,y) and to (x,y-1)
	lda x
	beq nox ; we're on leftmost edge, can't come from left
	; add number of paths from (0,0) to (x-1,y)
	lda ptr1+0
	sec
	sbc #8
	sta ptr2+0
	lda ptr1+1
	sta ptr2+1
	jsr add
nox	lda y
	beq noy ; we're on upper edge, can't come from above
	; add number of paths from (0,0) to (x,y-1)
	ldx ptr1+0
	ldy ptr1+1
	dey
	stx ptr2+0
	sty ptr2+1
	jsr add
noy	; go to next point
	lda ptr1+0
	clc
	adc #8
	sta ptr1+0
	inc x
	lda x
	cmp #21
	bne loop
	; next row
	lda #0
	sta x
	sta ptr1+0
	inc ptr1+1
	inc y
	lda y
	cmp #21
	bne loop
	; we're done, answer is in the array entry for (20,20)
	lda #20*8
	sta ptr1+0
	lda dppage
	clc
	adc #20
	sta ptr1+1
	ldy #4
-	lda (ptr1),y
	sta inbcd,y
	dey
	bpl -
	jsr int40tobcd
	lda #7
	ldx #<outbcd
	ldy #>outbcd
	jsr printbcd
	lda #$0d
	jmp CHROUT
add	ldx #5
	ldy #0
	clc
-	lda (ptr1),y
	adc (ptr2),y
	sta (ptr1),y
	iny
	dex
	bne -
	rts

	; dp array has 21*21 ints of 5 bytes each. to make access easy,
	; let us instead use 21*32 with 8 bytes each.
	; the array is stored as row 0, row 1 etc up to row 20
dppage	!byte 0
x	!byte 0 ; loop variables over grid
y	!byte 0
end	; dp array starts on next page after this label
