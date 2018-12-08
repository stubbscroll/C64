; advent of code 2018 day 6, part 2
; https://adventofcode.com/2018/day/6
; algorithm: for each point, calculate the sum of distances to all letters.
; count the number of points with sum of distances less than TOT.
; runtime: 25 minutes 30 seconds

	CHROUT = $ffd2

	!to "06b.prg",cbm
	* = $0801
	; sys start
	!byte $0b, $08, $0a, $00, $9e, 48+start/1000%10, 48+start/100%10, 48+start/10%10, 48+start%10, $00, $00, $00

	MAXC = 360 ; max coordinate

	TOT = 10000

	x = $fc
	y = $fe

	t1 = $f8 ; temp variables
	t2 = $fa
	t3 = $58

	bestc = $5a  ; number of coordinates with total dist <= TOT (3 bytes)
	dist = $5d

start	sei
	; check every coordinate x=1..360, y=1..360
	ldx #1
	stx y+0
	dex
	stx y+1
loop	ldx #1
	stx x+0
	dex
	stx x+1
loop2	jsr closest
	; check if total distance < TOT
	lda #<TOT-1
	cmp dist+0
	lda #>TOT-1
	sbc dist+1
	lda #0
	sbc dist+2
	bcc incx
	; increase size of region
	inc bestc+0
	bne incx
	inc bestc+1
	bne incx
	inc bestc+2
	bne incx
incx	; increase x
	inc x+0
	bne +
	inc x+1
+	; check if x>MAXC
	lda x+0
	cmp #<MAXC+1
	lda x+1
	sbc #>MAXC+1
	bcc loop2
	; increase y
	inc y+0
	bne +
	inc y+1
+	; check if y>MAXC
	lda y+0
	cmp #<MAXC+1
	lda y+1
	sbc #>MAXC+1
	bcc loop
	; print answer
	ldx #2
-	lda bestc,x
	sta inbcd,x
	dex
	bpl -
	jsr int24tobcd
	lda #4
	ldx #<outbcd
	ldy #>outbcd
	jsr printbcd
	lda #$0d
	jmp CHROUT

	; find sum of manhattan distances from (x,y) to each letter
closest	ldx #0 ; sum of distances for this coordinate, init to 0
	stx dist+0
	stx dist+1
	stx dist+2
-	lda input,x
	and input+1,x ; if inputx = 65535, we're done
	cmp #$ff
	beq cdone
	; find absolute value of x - inputx
	lda input,x
	sta t1+0
	lda input+1,x
	sta t1+1
	lda x+0
	sta t2+0
	lda x+1
	sta t2+1
	jsr abs
	lda t2+0
	sta t3+0
	lda t2+1
	sta t3+1
	; find absolute value of y - inputy
	lda input+2,x
	sta t1+0
	lda input+3,x
	sta t1+1
	lda y+0
	sta t2+0
	lda y+1
	sta t2+1
	jsr abs
	lda t2+0
	clc
	adc t3+0
	sta t3+0
	lda t2+1
	adc t3+1
	sta t3+1
	; t3 now holds the manhattan distance from x,y to current coordinate.
	; add it to sum
	lda dist+0
	clc
	adc t3+0
	sta dist+0
	lda dist+1
	adc t3+1
	sta dist+1
	bcc +
	inc dist+2
+	inx
	inx
	inx
	inx
	bne -
cdone	rts

	; find the absolute value of t1-t2
abs	lda t1+0
	sec
	sbc t2+0
	sta t2+0
	lda t1+1
	sbc t2+1
	sta t2+1
	bpl +
	; result is negative, negate it
	lda t2+0
	eor #$ff
	clc
	adc #1
	sta t2+0
	lda t2+1
	eor #$ff
	adc #0
	sta t2+1
+	rts

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

	!align 1,0,0 ; align to word
	; input! list of x,y coordinates (16 bits each), terminated by 65535,65535
input	!word 80, 357
	!word 252, 184
	!word 187, 139
	!word 101, 247
	!word 332, 328
	!word 302, 60
	!word 196, 113
	!word 271, 201
	!word 334, 89
	!word 85, 139
	!word 327, 161
	!word 316, 352
	!word 343, 208
	!word 303, 325
	!word 316, 149
	!word 270, 319
	!word 318, 153
	!word 257, 332
	!word 306, 348
	!word 299, 358
	!word 172, 289
	!word 303, 349
	!word 271, 205
	!word 347, 296
	!word 220, 276
	!word 235, 231
	!word 133, 201
	!word 262, 355
	!word 72, 71
	!word 73, 145
	!word 310, 298
	!word 138, 244
	!word 322, 334
	!word 278, 148
	!word 126, 135
	!word 340, 133
	!word 311, 118
	!word 193, 173
	!word 319, 99
	!word 50, 309
	!word 160, 356
	!word 155, 195
	!word 61, 319
	!word 80, 259
	!word 106, 318
	!word 49, 169
	!word 134, 61
	!word 74, 204
	!word 337, 174
	!word 108, 287
	!word 65535,65535
