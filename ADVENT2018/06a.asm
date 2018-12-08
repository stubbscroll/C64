; advent of code 2018 day 6, part 1
; https://adventofcode.com/2018/day/6
; algorithm: to find letters with infinite area, test every point on the
; border of the bounding box of all letters. all letters with a shortest
; non-tied distance to any of these points have infinite area.
; then, for each point inside the bounding box, find the closest letter.
; keep count of the number of closest points for each letter, and output the
; lowest count.
; runtime: 25 minutes 25 seconds

	CHROUT = $ffd2

	!to "06a.prg",cbm
	* = $0801
	; sys start
	!byte $0b, $08, $0a, $00, $9e, 48+start/1000%10, 48+start/100%10, 48+start/10%10, 48+start%10, $00, $00, $00

	MAX = 50 ; number of letters, can be up to 63
	MAXC = 360 ; max coordinate

	x = $fc
	y = $fe

	t1 = $f8 ; temp variables
	t2 = $fa
	t3 = $58

	best = $5a   ; closest distance found so far (used by closest routine)
	bestid = $f7 ; id of best distance (1 byte)

start	sei
	; init variables
	ldx #MAX-1
	lda #0
-	sta inf,x
	sta countlo,x
	sta counthi,x
	sta counthj,x
	dex
	bpl -
	; find the letters with infinite area!
	; test a bunch of coordinates sufficiently far away, any letter that's
	; closest to one of them has infinite area.
	; all points have coordinates between 1 and 360, let the "sufficiently
	; "far way" coordinates be just outside that.
	; test all x from 1 to 360, lock y=0 and y=361
	ldx #1
	stx x+0
	dex
	stx x+1
-	lda #0
	sta y+0
	sta y+1
	jsr closest
	bmi +
	lda #1
	sta inf,x
+	lda #<MAXC+1
	sta y+0
	lda #>MAXC+1
	sta y+1
	jsr closest
	bmi +
	lda #1
	sta inf,x
+	inc x+0 ; increase x
	bne +
	inc x+1
+	lda x+0
	cmp #<MAXC+1
	lda x+1
	sbc #>MAXC+1
	bcc -
	; test all y from 1 to 360, lock x=0 and x=361
	ldx #1
	stx y+0
	dex
	stx y+1
-	lda #0
	sta x+0
	sta x+1
	jsr closest
	bmi +
	lda #1
	sta inf,x
+	lda #<MAXC+1
	sta x+0
	lda #>MAXC+1
	sta x+1
	jsr closest
	bmi +
	lda #1
	sta inf,x
+	inc y+0 ; increase y
	bne +
	inc y+1
+	lda y+0
	cmp #<MAXC+1
	lda y+1
	sbc #>MAXC+1
	bcc -
	; try every coordinate x=1..360, y=1..360
	ldx #1
	stx y+0
	dex
	stx y+1
loop	ldx #1
	stx x+0
	dex
	stx x+1
loop2	jsr closest
	bmi +
	; increase counter
	inc countlo,x
	bne +
	inc counthi,x
	bne +
	inc counthj,x
+	; increase x
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
	; we are done counting, now find largest area
	lda #0
	sta best+0
	sta best+1
	sta best+2
	ldx #MAX-1
-	lda inf,x ; ignore letter with infinite area
	bne +
	ldy countlo,x
	cpy best+0
	lda counthi,x
	sbc best+1
	lda counthj,x
	sbc best+2
	bcc +
	sty best+0
	lda counthi,x
	sta best+1
	lda counthj,x
	sta best+2
+	dex
	bpl -
	; print answer
	ldx #2
-	lda best,x
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

	; return in the x-register the index of the letter (0-indexed) that's
	; closest to (x,y), or $ff if there is a tie
closest	ldx #255
	stx best+0 ; set best distance so far to maxint
	stx best+1
	inx
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
	; check if it's smaller than the best distance found so far
	ldy t3+0
	cpy best+0
	bne +
	lda t3+1
	cmp best+1
	bne +
	; equal distance, mark bestid as 255
	lda #$ff
	sta bestid
	bne cinc
+	cpy best+0
	lda t3+1
	sbc best+1
	bcs cinc
	sty best+0
	lda t3+1
	sta best+1
	stx bestid
cinc	inx
	inx
	inx
	inx
	bne -
cdone	lda bestid ; return closest letter
	cmp #255
	beq +
	lsr
	lsr
+	tax
	rts

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

inf	; MAX (50) bytes (one for each letter), 1=letter has infinite area
countlo = inf+MAX ; number of cells that are closest to each letter
counthi = countlo+MAX ; allocate 24 bits to be safe
counthj = counthi+MAX
