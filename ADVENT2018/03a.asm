; advent of code 2018 day 3, part 1
; https://adventofcode.com/2018/day/3
; algorithm: for each tile on the map, keep a counter. for each claim,
; increase the counter for each tile it covers. if the count for a tile is
; larger than 1 after processing all claims, we count it in the final answer.
; however, we don't have enough memory to hold the entire map. do several
; passes where we process part of the map, and update for every claim that
; intersects with the part we're processing
; runtime: 1 minute 4 seconds

	CHROUT = $ffd2

	!to "03a.prg",cbm
	* = $0801
	; sys start
	!byte $0b, $08, $0a, $00, $9e, 48+start/1000%10, 48+start/100%10, 48+start/10%10, 48+start%10, $00, $00, $00
	height = 256->map ; height of the window

	answer = $f7 ; 3 bytes

	wy1 = $fc ; y-coordinate of top of current window (inclusive)
	wy2 = $fe ; y-coordinate of bottom of current window (exclusive)

	tzp = $fa ; temp zero-page pointer
	zp1 = $57 ; pointer into input list

	temp = $59 ; 2 bytes
	x1 = $5b  ; 8 bytes starting at 5b
	y1 = x1+2 ; for efficiency reasons these addresses
	x2 = y1+2 ; must be contiguous
	y2 = x2+2
	x = $63

start	sei
	lda #$34 ; switch out rom+i/o, we need as much memory as possible
	sta $01
	jsr initbc
	lda #height
	sta wy2+0
	lda #0
	sta wy1+0
	sta wy1+1
	sta wy2+1
	sta answer+0
	sta answer+1
	sta answer+2
loop	; start of main loop! map out the claims for the cells with
	; y-coordinate in [wy1, wy2)
	; clear map
	jsr clear
	; loop over each claim and mark on the map
	; init loop
	ldx #<input
	ldy #>input
	stx zp1+0
	sty zp1+1
loop2	; end of input?
	ldy #1
	lda (zp1),y
	bmi end
	; obtain x1 y1 x2 y2
	ldy #3
-	lda (zp1),y
	sta x1,y
	sta x2,y
	dey
	bpl -
	lda x2+0
	clc
	ldy #4
	adc (zp1),y
	sta x2+0
	bcc +
	inc x2+1
+	lda y2+0
	clc
	iny
	adc (zp1),y
	sta y2+0
	bcc +
	inc y2+1
+	; don't process claim if y2 <= wy1 or y1 >=wy2
	lda wy1+0
	cmp y2+0
	lda wy1+1
	sbc y2+1
	bcs next
	lda y1+0
	cmp wy2+0
	lda y1+1
	sbc wy2+1
	bcs next
	; clamp y1 and y2 to fit inside window
	; if y1 < wy1, then clamp (set y1 = wy1)
	lda y1+0
	cmp wy1+0
	lda y1+1
	sbc wy1+1
	bcs +
	lda wy1+0
	sta y1+0
	lda wy1+1
	sta y1+1
+	; if y2 > wy2, then clamp (set y2 = wy2)
	lda wy2+0
	cmp y2+0
	lda wy2+1
	sbc y2+1
	bcs +
	lda wy2+0
	sta y2+0
	lda wy2+1
	sta y2+1
+	; process claim
	jsr process
next	lda zp1+0
	clc
	adc #6
	sta zp1+0
	bcc +
	inc zp1+1
+	jmp loop2
end	; we looped over all claims!
	; count the number of cells that are claimed more than once
	jsr count
	; move window down height steps
	lda wy2+0
	sta wy1+0
	clc
	adc #height
	sta wy2+0
	lda wy2+1
	sta wy1+1
	adc #0
	sta wy2+1
	; have we tried all windows? we're done if wy1 >= 1000
	lda wy1+0
	cmp #<1000
	lda wy1+1
	sbc #>1000
	bcs done
	jmp loop ; not done, continue loop
done	lda #$37
	sta $01
	; print answer
	ldx #2
-	lda answer,x
	sta inbcd,x
	dex
	bpl -
	jsr int24tobcd
	lda #4
	ldx #<outbcd
	ldy #>outbcd
	jsr printbcd
	lda #13
	jmp CHROUT

	; process claim in x1,y1,x2,y2. for each cell covered by the claim,
	; increase the counter by 1 (capped at 2)
process	; adjust y-coordinates to point to pages
	; ignore high byte on y1 and y2 now
	lda y1+0
	sec
	sbc wy1+0
	clc
	adc #>map
	sta tzp+1
	lda y2+0
	sec
	sbc wy1+0
	clc
	adc #>map
	sta y2+0
	lda #0
	sta tzp+0

line	; start on a new row on the map
	lda x1+0
	sta x+0
	lda x1+1
	sta x+1

ploop	; increase counter at tzp,x
	lda x+0
	sta temp+0
	lda x+1
	sta temp+1
	lda #0
	lsr temp+1
	ror temp+0
	rol
	lsr temp+1
	ror temp+0
	ldy temp+0
	rol
	; temp+0 now holds x-index in row, a holds an int between 0 and 3
	; inefficient case-based update comes now
	bne p1
	; a=0
	lda (tzp),y
	and #3
	cmp #2
	beq pnext
	lda (tzp),y
	clc
	adc #1
	sta (tzp),y
	jmp pnext
p1	cmp #1
	bne p2
	lda (tzp),y
	and #$0c
	cmp #$08
	beq pnext
	lda (tzp),y
	clc
	adc #4
	sta (tzp),y
	jmp pnext
p2	cmp #2
	bne p3
	lda (tzp),y
	and #$30
	cmp #$20
	beq pnext
	lda (tzp),y
	clc
	adc #$10
	sta (tzp),y
	jmp pnext
p3	; a=3 here
	lda (tzp),y
	and #$c0
	cmp #$80
	beq pnext
	lda (tzp),y
	clc
	adc #$40
	sta (tzp),y
pnext	; go right to the next cell
	inc x+0
	bne +
	inc x+1
+	; have we reached the end?
	lda x+0
	cmp x2+0
	bne ploop
	lda x+1
	cmp x2+1
	bne ploop
	; next y-coordinate
	inc tzp+1
	lda tzp+1
	cmp y2
	beq +
	jmp line
+	rts

	; count the number of cells that are claimed more than once
count	lda #>map
	sta tzp+1
	ldy #0
	tya
	sta tzp+0
-	lda (tzp),y
	tax
	lda bc,x ; count faster with table
	clc      ; bc,x = number of cells in x claimed at least twice
	adc answer+0
	sta answer+0
	bcc +
	inc answer+1
	bne +
	inc answer+2
+	iny
	bne -
	inc tzp+1
	bne -
	rts

	; clear memory used for map
clear	lda #>map
	sta tzp+1
	ldy #0
	tya
	sta tzp+0
-	sta (tzp),y
	iny
	bne -
	inc tzp+1
	bne -
	rts

	; init bitcount array
	; bc[x] contains the number of 1-bits of x in odd positions
initbc	ldy #0
-	sty temp
	lda #0
	asl temp
	adc #0
	asl temp
	asl temp
	adc #0
	asl temp
	asl temp
	adc #0
	asl temp
	asl temp
	adc #0
	sta bc,y
	iny
	bne -
	rts

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
	ldy #1 ; y=1: print all digits from here
+	ora #$30
	jmp CHROUT

	; input file!
	; 0: x-coordinate of claim (2 bytes)
	; 2: y-coordinate of claim (2 bytes)
	; 4: width of claim (1 byte)
	; 5: height of claim (1 byte)
	; end of input is marked with x-coordinate ff ff
input
	!hex 52 03 2d 01 17 0c
	!hex 82 03 f5 00 0f 0a
	!hex 08 00 98 01 0c 1b
	!hex 14 02 b8 00 10 0d
	!hex 26 02 3d 03 0b 0a
	!hex 90 02 8a 03 0d 0c
	!hex e9 01 65 01 18 17
	!hex 11 02 82 03 0c 13
	!hex 94 02 c9 00 13 1c
	!hex 0c 02 0e 00 15 1b
	!hex d3 00 ce 00 0d 17
	!hex 3b 02 47 00 12 0c
	!hex a6 03 bf 01 1a 0b
	!hex 53 03 88 02 0d 0f
	!hex cb 01 7b 00 12 1b
	!hex 3c 02 65 02 0b 16
	!hex 91 03 f6 01 1d 14
	!hex a3 01 b3 02 0e 1a
	!hex 2d 03 93 00 0a 0d
	!hex b3 01 1e 01 13 14
	!hex 94 02 a6 02 11 0d
	!hex 26 03 3f 02 10 18
	!hex f7 00 00 02 13 15
	!hex 70 00 59 01 1c 19
	!hex 61 03 a8 03 0d 0f
	!hex 06 00 d5 02 17 0a
	!hex 13 02 20 02 1c 11
	!hex 15 02 89 01 0a 0d
	!hex 11 00 9e 03 17 0b
	!hex c2 03 7d 02 1d 16
	!hex a6 03 4c 00 0b 0c
	!hex 5f 02 16 01 0a 0b
	!hex e2 01 90 00 1c 13
	!hex ff 02 d1 02 0c 17
	!hex 1d 03 61 02 0c 0c
	!hex 86 00 af 02 18 1a
	!hex 6a 00 66 00 13 19
	!hex 2f 01 81 01 0b 10
	!hex 72 02 19 00 0c 1d
	!hex 71 01 7f 03 0b 1b
	!hex 90 02 e4 02 0c 16
	!hex b5 03 52 01 0c 15
	!hex 75 02 68 01 15 12
	!hex a0 01 84 01 0a 11
	!hex 46 00 18 02 10 0c
	!hex 36 00 f6 02 1b 12
	!hex b9 01 f4 02 0d 18
	!hex 07 03 31 00 0d 19
	!hex 91 00 0b 03 1a 19
	!hex 59 03 ca 00 0a 18
	!hex 43 03 db 02 14 0e
	!hex 2b 03 82 00 12 15
	!hex 49 02 3e 00 1a 1d
	!hex 15 01 d0 03 12 10
	!hex 41 02 0b 02 18 19
	!hex 18 00 91 01 12 0f
	!hex 0c 02 a2 02 19 15
	!hex 8e 02 ed 00 1a 13
	!hex 39 03 1f 00 11 1d
	!hex c4 01 10 02 18 0b
	!hex 7b 00 a1 00 0e 0b
	!hex 99 03 6e 01 1b 0c
	!hex 2c 01 38 01 0f 16
	!hex 14 01 93 01 12 17
	!hex 1b 00 94 02 10 1c
	!hex e5 00 de 00 10 1d
	!hex 0e 02 d4 02 18 17
	!hex 9e 01 16 01 14 16
	!hex 4b 00 7a 02 0b 13
	!hex 28 02 86 02 19 15
	!hex 6e 03 96 01 1c 17
	!hex 86 00 ec 01 0f 1c
	!hex 98 00 0c 00 0b 14
	!hex 9e 00 c7 03 0b 16
	!hex 66 00 1b 03 18 1d
	!hex e9 02 c2 03 0c 10
	!hex 44 01 b2 03 0b 0e
	!hex 94 03 3d 01 1c 1c
	!hex 9b 02 e2 00 12 1b
	!hex a8 00 1e 01 0b 1a
	!hex 93 01 9a 02 14 1c
	!hex 8d 02 f5 00 17 0a
	!hex ee 00 df 01 17 0e
	!hex 15 03 93 03 0e 03
	!hex 94 01 f9 02 10 16
	!hex a2 01 9d 03 0c 0c
	!hex ce 00 d1 03 16 13
	!hex 86 00 98 00 1d 17
	!hex f2 02 a1 01 0c 11
	!hex 55 01 a2 02 11 12
	!hex 1e 02 91 00 0c 19
	!hex 63 01 f6 02 11 15
	!hex 7d 01 b1 00 1d 0b
	!hex b0 03 23 03 1a 12
	!hex cb 01 23 00 07 06
	!hex 66 03 4d 03 18 1a
	!hex 55 00 e8 02 0a 0d
	!hex 0e 01 e5 01 0a 17
	!hex 76 00 4d 02 0a 1a
	!hex b6 02 cc 02 0a 15
	!hex 96 02 92 03 1a 11
	!hex 8e 03 2e 00 0e 18
	!hex 34 03 14 03 12 0b
	!hex e5 00 71 01 16 1a
	!hex 1c 00 98 03 0e 12
	!hex 85 03 d5 01 0f 0d
	!hex 5f 02 a1 03 0c 1a
	!hex 11 00 f3 02 12 1d
	!hex 00 02 b4 02 14 0e
	!hex a8 01 77 01 1b 1c
	!hex 3f 00 81 02 1a 1c
	!hex fd 00 db 01 18 1b
	!hex 59 00 2b 00 15 10
	!hex 17 00 70 00 18 12
	!hex 7d 03 cf 00 18 0b
	!hex 54 03 dd 00 0f 1c
	!hex ae 00 37 00 0d 16
	!hex 09 00 1c 03 0d 1a
	!hex 34 02 78 00 15 0c
	!hex 4d 01 ce 03 1d 10
	!hex 61 01 2f 02 0f 1b
	!hex 8d 01 ba 03 0a 0e
	!hex 14 00 7b 03 13 1c
	!hex a7 03 1a 00 0b 1c
	!hex 5d 03 76 00 18 1b
	!hex 9b 02 60 03 0a 1c
	!hex 01 01 d9 00 19 1d
	!hex e1 02 b1 03 15 1d
	!hex 43 02 28 02 0a 1b
	!hex 86 01 18 01 14 10
	!hex 55 02 25 01 10 0d
	!hex 98 02 ea 00 18 12
	!hex 07 03 2c 00 1d 0e
	!hex 2f 02 7a 03 18 13
	!hex ea 00 ef 02 0a 17
	!hex 08 01 22 00 1c 1d
	!hex 17 01 76 00 13 13
	!hex c5 01 1b 01 14 13
	!hex ab 02 2d 00 17 1b
	!hex 06 03 f7 01 17 0a
	!hex dc 02 32 00 16 18
	!hex ec 01 58 02 14 0e
	!hex 12 02 8f 03 0a 1b
	!hex 3d 03 8e 02 1d 17
	!hex 37 01 64 02 1d 0b
	!hex 22 03 3a 00 17 12
	!hex 3a 02 b0 02 1b 19
	!hex 8d 02 8f 00 19 0c
	!hex a9 01 dd 00 0a 0b
	!hex 9e 00 c7 02 14 0d
	!hex 16 01 63 02 03 0b
	!hex 31 02 35 01 0a 14
	!hex 73 03 31 00 15 0d
	!hex c4 03 b6 02 13 16
	!hex 01 03 a0 03 0c 16
	!hex ed 00 48 02 10 1b
	!hex 4d 03 7a 01 1d 0c
	!hex f8 00 be 03 16 0a
	!hex 48 03 24 02 14 15
	!hex 0d 00 86 02 10 0a
	!hex eb 02 bd 03 15 1d
	!hex e3 00 11 03 18 14
	!hex b7 03 57 00 1d 0c
	!hex 8b 02 44 03 0a 18
	!hex 0b 03 a0 02 0f 17
	!hex 78 03 7b 01 1a 11
	!hex 58 01 40 00 0e 16
	!hex 77 01 8d 01 0a 06
	!hex 5b 03 67 00 14 0e
	!hex a5 02 04 00 17 1b
	!hex 43 03 cd 00 1c 10
	!hex f5 00 07 03 0a 14
	!hex 90 01 66 01 1b 1a
	!hex 1d 00 e6 00 0b 18
	!hex 5d 03 ca 00 14 0f
	!hex 3f 03 f6 02 15 0c
	!hex 5f 01 64 02 15 1d
	!hex 5b 02 6f 01 17 15
	!hex 5b 02 51 01 14 1c
	!hex b8 01 ee 01 0e 1a
	!hex 6e 01 42 03 11 0b
	!hex 11 00 36 01 0f 10
	!hex 47 03 3f 01 15 19
	!hex 69 01 b8 02 16 0a
	!hex 36 03 c9 01 18 12
	!hex 98 03 7f 02 13 1d
	!hex 99 03 a1 02 1d 18
	!hex 46 00 c1 02 17 0d
	!hex 64 02 96 00 1a 13
	!hex ce 00 db 00 19 15
	!hex e9 01 8b 00 11 0c
	!hex bb 00 09 03 18 16
	!hex a8 00 2f 00 1c 15
	!hex 7d 02 e7 02 0c 18
	!hex 18 02 df 02 11 1d
	!hex 6c 00 48 02 0a 1d
	!hex 95 02 72 03 0e 0c
	!hex eb 02 3d 00 0b 0a
	!hex 0c 01 2c 00 11 0d
	!hex 3f 01 2b 01 19 13
	!hex a4 02 58 02 13 0a
	!hex d6 02 57 03 10 0e
	!hex 6d 01 3e 01 0b 16
	!hex 5f 03 5f 00 0a 1d
	!hex 83 00 0e 03 0b 19
	!hex e1 02 7e 02 17 0c
	!hex c4 02 44 02 12 0c
	!hex 47 00 c6 03 19 0f
	!hex a0 02 d2 00 12 1a
	!hex ce 00 91 02 0e 1a
	!hex cd 03 c5 00 0a 0b
	!hex 53 00 70 03 0e 13
	!hex 45 00 01 03 16 10
	!hex 88 00 5e 02 1c 17
	!hex 7b 02 49 02 10 0e
	!hex 84 03 e7 00 0d 1c
	!hex b4 00 6c 02 0b 1c
	!hex 44 03 c9 01 0c 1c
	!hex 47 00 53 02 0c 0b
	!hex 0e 01 5d 02 11 1a
	!hex 20 00 85 03 1d 0d
	!hex 99 00 8f 03 1d 11
	!hex 06 00 75 02 19 16
	!hex 15 00 75 02 16 1d
	!hex 18 01 8b 01 1d 11
	!hex e3 01 2e 01 1b 0f
	!hex 56 03 84 01 0f 15
	!hex 69 03 79 01 18 0b
	!hex 95 01 3f 03 18 10
	!hex dc 00 e9 01 0f 17
	!hex 73 00 0b 01 16 13
	!hex 43 01 90 01 1a 11
	!hex e4 02 bd 02 1d 0b
	!hex e6 01 1f 02 15 17
	!hex 52 02 bb 03 13 13
	!hex bf 01 da 01 1b 18
	!hex 77 00 e2 02 1c 1d
	!hex 20 00 9d 03 12 18
	!hex 89 01 2e 02 1d 0f
	!hex d2 01 4e 01 16 19
	!hex 0c 03 43 03 15 1a
	!hex 14 01 1f 00 0f 12
	!hex 64 01 4c 02 14 0b
	!hex e9 02 81 02 04 03
	!hex f4 01 92 03 1c 0b
	!hex c2 03 0c 01 16 1d
	!hex 9f 02 a0 03 0c 18
	!hex 8f 02 e7 02 12 12
	!hex bd 03 a7 03 1c 16
	!hex 8b 03 25 00 15 0a
	!hex 5d 03 17 01 13 18
	!hex 7a 02 4f 02 14 16
	!hex 6c 01 8a 01 1d 15
	!hex 61 02 1c 01 16 14
	!hex 8b 01 b1 00 0f 0d
	!hex c9 00 1a 00 0e 0f
	!hex 8e 02 44 02 19 0d
	!hex 98 00 2d 01 0b 19
	!hex f5 01 06 03 12 0c
	!hex 58 00 a8 03 19 1a
	!hex 9b 03 0d 03 0e 13
	!hex 38 02 75 02 0f 11
	!hex a2 01 cc 03 1a 0c
	!hex 85 02 59 01 14 10
	!hex 29 00 da 00 0c 18
	!hex 55 02 54 01 1b 1a
	!hex c8 00 28 03 19 0d
	!hex 1c 00 02 00 0d 10
	!hex 87 00 da 01 1b 16
	!hex 22 00 b9 03 15 17
	!hex 8f 01 8f 00 0c 1a
	!hex de 01 57 02 15 15
	!hex 8e 01 ad 03 0d 13
	!hex 14 02 69 00 07 0a
	!hex 9e 01 d3 03 0b 0a
	!hex 09 02 f4 02 0e 0f
	!hex 28 02 8c 00 12 10
	!hex 18 02 1d 01 12 0f
	!hex 2c 01 3b 01 1c 16
	!hex 7f 00 81 00 12 04
	!hex 16 00 69 00 0a 17
	!hex 31 03 31 00 15 13
	!hex 02 00 00 00 1d 17
	!hex 4e 03 65 02 19 19
	!hex ab 02 0d 03 1c 0d
	!hex 1a 01 93 01 1d 16
	!hex 51 01 98 00 0f 13
	!hex 45 02 f7 02 18 14
	!hex b4 00 19 03 0f 0e
	!hex 3a 00 ca 02 11 1d
	!hex cc 01 7c 03 19 14
	!hex 07 01 68 00 1b 19
	!hex 08 03 75 03 11 0e
	!hex 5d 02 f2 02 12 18
	!hex 14 00 8d 02 0c 1d
	!hex d1 01 cf 03 0d 0c
	!hex 93 01 e2 00 19 10
	!hex 6a 01 47 01 11 14
	!hex d1 03 62 02 15 0e
	!hex a5 03 90 02 1a 12
	!hex 33 03 0e 03 10 12
	!hex 7e 00 7b 00 0b 0f
	!hex 30 00 cd 00 0d 0b
	!hex 38 02 34 02 12 17
	!hex a6 03 d2 00 0b 0b
	!hex 0c 03 91 01 0c 18
	!hex 11 00 03 02 10 0f
	!hex 62 03 0e 00 17 0b
	!hex 17 01 f7 01 11 0b
	!hex 3e 02 d1 00 1b 13
	!hex 3f 03 d7 00 1a 1b
	!hex 5b 01 af 01 15 1c
	!hex fc 02 a3 01 18 19
	!hex 6d 03 36 00 1c 0d
	!hex 01 01 c4 03 0a 16
	!hex 6b 02 94 00 10 0c
	!hex 83 02 d3 02 19 10
	!hex 4c 03 b6 00 16 16
	!hex 1d 03 77 00 1d 13
	!hex ed 00 ff 02 19 12
	!hex 30 01 43 02 0c 0c
	!hex 9e 00 65 00 12 16
	!hex be 03 69 03 0f 0b
	!hex 33 02 6d 02 03 0e
	!hex 0b 00 94 01 0a 13
	!hex cf 02 fc 01 0c 13
	!hex 5b 02 50 00 12 1d
	!hex c9 00 20 02 1c 15
	!hex 24 02 77 00 13 0c
	!hex 86 02 fb 00 19 1b
	!hex be 02 ad 02 16 0e
	!hex 61 02 59 02 0e 18
	!hex b0 01 2a 01 16 1c
	!hex ba 03 b6 00 1b 0b
	!hex ab 00 bf 01 0d 1a
	!hex 34 02 27 03 0c 13
	!hex 1e 02 62 03 10 18
	!hex dd 02 b1 03 18 1d
	!hex 3c 00 b1 00 15 1b
	!hex 83 02 dc 02 0a 11
	!hex d6 01 58 01 0c 19
	!hex 17 03 6c 01 0a 1b
	!hex 62 02 dc 01 0b 19
	!hex 33 01 cb 00 0a 18
	!hex 74 02 4f 03 14 0f
	!hex b9 01 64 03 17 19
	!hex 6b 03 c3 00 10 1b
	!hex 83 02 97 00 0e 1c
	!hex 20 02 ee 02 1d 1d
	!hex ce 01 33 02 13 14
	!hex 61 00 60 03 0f 1c
	!hex 3b 00 9c 02 19 0d
	!hex 19 02 e9 01 1d 18
	!hex 74 00 46 02 18 0d
	!hex 4f 02 f3 00 12 1a
	!hex 30 01 82 02 0b 0f
	!hex d6 00 2e 02 0e 19
	!hex 85 00 30 02 16 1a
	!hex 30 01 60 02 1c 0b
	!hex 6a 01 60 03 10 17
	!hex 66 01 b5 02 0f 1b
	!hex 5b 03 fe 00 1c 1c
	!hex 37 01 bd 01 0b 08
	!hex 23 02 21 01 1b 1c
	!hex 86 00 a1 03 0f 0f
	!hex 65 02 32 03 15 0d
	!hex b4 03 58 00 1c 13
	!hex 2f 01 f1 00 0b 0b
	!hex 4e 02 2b 00 14 19
	!hex cf 03 75 02 17 11
	!hex 83 00 43 02 1c 0a
	!hex a3 00 0c 03 18 16
	!hex 46 01 13 02 1b 1b
	!hex 48 01 b5 01 0e 17
	!hex 12 03 46 03 11 11
	!hex b0 02 68 00 19 14
	!hex f5 00 e3 02 1c 0a
	!hex a9 01 c5 00 14 0c
	!hex 85 00 62 02 0e 0a
	!hex 4d 03 03 00 0f 1d
	!hex b7 02 70 01 0a 19
	!hex 64 02 2f 03 18 15
	!hex ca 03 53 00 14 1b
	!hex 73 03 3d 03 12 1c
	!hex db 00 b0 03 03 09
	!hex 65 00 f4 01 0c 16
	!hex 63 01 d5 03 10 0d
	!hex e4 00 b8 03 11 17
	!hex ee 02 c9 03 0a 17
	!hex db 01 bd 02 1d 0c
	!hex 9d 03 5f 01 17 1b
	!hex de 02 57 00 0a 1d
	!hex 03 02 b0 02 0e 18
	!hex b8 02 99 02 15 0b
	!hex 12 00 73 00 0f 1d
	!hex 25 00 5b 01 0e 17
	!hex 22 01 b8 00 10 17
	!hex 7e 03 28 00 15 1b
	!hex 26 01 25 01 1d 1c
	!hex ea 01 88 02 0a 15
	!hex 22 01 63 02 17 17
	!hex 55 02 81 02 0d 18
	!hex 61 01 b4 03 19 13
	!hex 71 01 a7 00 17 18
	!hex 41 00 84 01 0a 15
	!hex ce 02 83 01 09 08
	!hex 55 03 88 02 1c 0d
	!hex 56 02 4d 00 0e 1b
	!hex 13 00 d9 00 19 0e
	!hex c7 01 51 01 17 0e
	!hex ab 03 61 01 0b 18
	!hex 9f 00 08 01 0b 1c
	!hex 2f 00 6a 02 0c 0c
	!hex 90 02 89 01 1c 14
	!hex 5d 02 18 02 1c 1a
	!hex d7 00 25 02 16 18
	!hex 99 01 92 01 0a 0f
	!hex c3 02 0d 03 0d 0b
	!hex 39 02 84 01 17 12
	!hex ea 00 8a 01 10 1a
	!hex 2a 00 98 02 1a 0a
	!hex 7e 01 18 02 16 1a
	!hex 43 03 02 02 0a 16
	!hex 6d 00 37 02 13 1a
	!hex bc 01 ba 00 14 1d
	!hex c3 02 ff 02 0d 1a
	!hex 9f 01 9c 00 1a 1d
	!hex ad 00 4b 00 18 18
	!hex c4 01 79 03 1b 13
	!hex 86 00 60 01 1c 0f
	!hex a8 03 6f 03 1a 1a
	!hex bf 00 0b 00 0b 11
	!hex 39 02 b4 02 19 17
	!hex 73 00 76 00 12 1d
	!hex 52 00 4e 03 13 0e
	!hex 0d 00 1b 01 15 1d
	!hex 66 03 df 02 1b 13
	!hex 28 00 d6 01 0a 11
	!hex ae 02 11 00 15 1a
	!hex cd 01 2b 02 0d 18
	!hex 46 02 7f 03 1c 1d
	!hex 9f 00 0a 00 0f 13
	!hex 4e 00 c5 02 16 11
	!hex 3b 02 ab 03 0a 1a
	!hex cb 03 41 03 16 16
	!hex 34 03 27 00 1a 0e
	!hex 5b 00 68 00 0e 13
	!hex e4 01 f5 00 1b 13
	!hex 02 03 96 01 13 1b
	!hex e9 00 3d 02 14 0f
	!hex e0 01 62 03 18 0c
	!hex 43 01 ad 03 18 13
	!hex 4f 01 7c 03 0d 15
	!hex 3c 02 36 03 16 15
	!hex d9 02 9a 03 1d 0f
	!hex 07 00 95 02 1c 0a
	!hex 91 01 55 02 15 13
	!hex d3 00 ee 02 19 18
	!hex 75 00 75 02 17 11
	!hex 75 00 74 00 19 16
	!hex 42 03 90 02 0a 0c
	!hex 6f 01 b7 00 0e 11
	!hex a3 02 7b 02 17 15
	!hex e5 00 3c 03 18 19
	!hex 1b 02 f0 01 15 09
	!hex dd 00 59 00 18 18
	!hex ed 00 66 00 18 1a
	!hex d1 02 85 03 0d 1b
	!hex b9 01 51 03 19 19
	!hex fe 00 d7 01 11 0d
	!hex ff 02 90 03 17 15
	!hex 1a 02 a7 00 0f 12
	!hex 97 02 b3 03 14 11
	!hex 5d 02 7a 02 13 0c
	!hex 40 01 58 02 1b 0a
	!hex 2e 03 8d 00 0a 19
	!hex 3d 02 ca 02 15 1a
	!hex 4f 02 28 02 16 10
	!hex bf 03 4c 00 0c 15
	!hex e1 02 b6 03 0a 0d
	!hex 4b 02 d1 01 1a 15
	!hex 19 00 02 03 14 0c
	!hex 1e 02 d2 00 0d 1c
	!hex 43 01 fc 01 0f 12
	!hex 3d 00 08 03 14 14
	!hex 11 00 8a 01 16 0b
	!hex 8c 02 69 03 0b 1a
	!hex 25 01 ab 03 0a 18
	!hex 25 02 ca 00 11 0f
	!hex cd 03 60 00 14 1b
	!hex b6 03 3d 03 17 1b
	!hex d8 01 1a 02 0b 0e
	!hex d0 01 4d 01 12 19
	!hex 0c 00 66 00 12 1d
	!hex 2c 03 66 02 1b 1d
	!hex e5 00 1d 01 12 0b
	!hex d1 01 bc 01 0e 13
	!hex 83 02 bc 00 18 0b
	!hex 2b 02 02 01 11 14
	!hex 0f 02 af 01 14 11
	!hex c4 03 96 00 14 15
	!hex 3c 02 37 02 0b 11
	!hex 30 02 d4 01 0a 08
	!hex cf 00 29 02 16 11
	!hex 82 03 8f 00 0b 18
	!hex b6 01 3e 00 0a 10
	!hex 43 02 73 01 0d 16
	!hex c5 03 6a 02 0e 19
	!hex 30 03 87 01 13 17
	!hex d3 01 49 01 15 13
	!hex b3 00 06 03 1a 14
	!hex 47 02 f6 01 19 0e
	!hex 86 03 26 01 13 19
	!hex 7a 02 96 01 1d 0d
	!hex de 01 b8 02 0b 19
	!hex b2 01 39 00 13 1b
	!hex d9 01 43 03 0b 0f
	!hex ee 02 27 00 0e 19
	!hex 32 02 13 01 0c 11
	!hex b8 03 9f 01 19 1a
	!hex 6d 02 9f 01 0a 15
	!hex e6 02 8d 01 17 0f
	!hex a9 00 20 01 0a 16
	!hex d2 01 b4 01 17 0e
	!hex 14 02 f5 02 0b 16
	!hex 51 00 98 03 0d 15
	!hex 58 02 9a 03 0c 1a
	!hex c1 02 d8 02 12 0c
	!hex 3c 03 38 02 11 09
	!hex 0b 01 4f 01 1b 0b
	!hex 09 01 45 02 0e 17
	!hex 0b 03 6d 00 0d 0c
	!hex 5a 03 57 02 1c 10
	!hex 86 02 a8 00 18 15
	!hex 87 02 87 03 11 11
	!hex 95 00 12 02 1a 0f
	!hex ad 03 c9 01 12 12
	!hex 77 02 7e 02 1a 0e
	!hex 0f 00 a4 02 14 17
	!hex b0 01 56 02 0c 1a
	!hex af 02 23 01 12 0b
	!hex 08 01 14 03 17 10
	!hex 0b 03 24 00 0d 12
	!hex 16 01 12 00 10 0b
	!hex 9e 00 3c 01 14 0e
	!hex 28 03 d3 01 14 1c
	!hex 96 01 8a 03 15 19
	!hex 98 00 6f 00 14 10
	!hex a7 00 c5 01 16 0b
	!hex dd 01 7b 03 0d 1a
	!hex 14 03 67 03 1d 0b
	!hex 3e 01 e5 01 15 12
	!hex 3a 03 73 02 19 0c
	!hex a0 00 a0 00 0a 1d
	!hex 14 02 e5 02 13 0e
	!hex 5b 00 3b 02 1a 15
	!hex bd 00 6f 02 11 10
	!hex ab 01 fe 02 1a 1d
	!hex 4e 01 32 00 0d 11
	!hex b1 03 09 00 18 1b
	!hex 11 02 cd 03 1c 0a
	!hex 80 01 63 02 18 0e
	!hex bc 01 e6 01 0c 0b
	!hex ec 02 87 03 19 0c
	!hex 93 02 81 01 1a 1a
	!hex 18 02 59 03 17 0b
	!hex a3 03 c2 01 0d 18
	!hex 97 02 75 01 17 1c
	!hex 87 03 c1 01 15 0d
	!hex 23 00 0b 00 11 0b
	!hex 10 03 ca 02 1c 14
	!hex 98 02 4d 02 19 16
	!hex 64 03 6f 03 1a 14
	!hex b5 03 70 02 1d 10
	!hex e1 01 df 00 0d 1b
	!hex 24 01 81 02 12 0a
	!hex b1 00 fb 02 0f 10
	!hex 4a 00 aa 02 0b 14
	!hex 04 02 be 00 1c 18
	!hex 62 00 da 00 1d 19
	!hex c3 02 52 01 16 10
	!hex 35 01 b8 01 12 11
	!hex 6c 01 3e 02 1a 1c
	!hex 7f 00 d7 02 11 17
	!hex 96 03 35 03 0b 11
	!hex b8 00 01 00 14 1c
	!hex 85 02 79 01 16 0e
	!hex 12 01 78 02 1c 0e
	!hex f5 02 70 02 16 0a
	!hex 05 02 0e 00 16 16
	!hex 46 01 16 01 13 0d
	!hex f0 02 d5 01 0c 1b
	!hex 8c 01 1b 02 0d 15
	!hex 39 01 43 01 1c 1b
	!hex 1f 03 15 00 10 13
	!hex 7b 02 55 00 1d 13
	!hex f5 01 54 02 10 15
	!hex 5a 01 4b 03 0b 15
	!hex 4a 01 ad 03 1c 1a
	!hex 52 01 5f 00 11 16
	!hex 0f 03 75 01 18 0c
	!hex 74 03 93 03 17 0b
	!hex eb 00 aa 01 1d 16
	!hex 6c 00 af 02 15 1b
	!hex 43 00 40 02 17 1a
	!hex 2a 00 da 01 03 06
	!hex 4c 01 91 00 1a 0e
	!hex eb 00 96 03 10 19
	!hex 7c 00 ad 03 15 0e
	!hex 92 02 b0 02 19 0e
	!hex 31 03 92 00 0a 12
	!hex 15 02 ef 01 1b 16
	!hex 8e 02 b2 03 13 1c
	!hex fd 00 02 01 0a 17
	!hex 03 03 bf 02 0b 18
	!hex 11 00 c0 03 14 0e
	!hex bb 00 1b 00 12 15
	!hex b3 00 bf 01 13 1a
	!hex a1 00 96 00 18 14
	!hex 7e 03 cb 01 19 18
	!hex d7 03 89 02 0e 0f
	!hex c5 01 23 01 1c 19
	!hex 14 00 21 02 1d 0d
	!hex e6 01 b7 01 15 0d
	!hex 57 01 60 01 13 12
	!hex 50 03 90 03 1a 0b
	!hex 17 02 d0 02 0b 13
	!hex 87 00 a8 00 0f 1a
	!hex c1 01 6f 02 12 0c
	!hex 54 02 20 01 18 14
	!hex 89 03 3d 03 12 1c
	!hex b9 03 ad 03 0e 0b
	!hex b7 03 67 03 1c 0b
	!hex 2f 02 7b 01 0a 17
	!hex f5 02 d4 01 0a 0f
	!hex 84 00 48 02 12 17
	!hex 4f 02 51 00 1a 10
	!hex 1f 00 6f 02 1d 0f
	!hex bb 02 4f 01 0f 0f
	!hex eb 02 20 00 19 16
	!hex 30 02 c2 01 11 0f
	!hex 66 03 25 01 0e 10
	!hex 6a 00 5c 00 12 0f
	!hex ad 00 3b 01 0c 1d
	!hex 01 03 66 00 17 0f
	!hex 4a 03 90 03 1b 14
	!hex cb 02 4f 01 17 0b
	!hex e8 02 c7 01 0d 0b
	!hex 42 01 65 00 0f 0e
	!hex 69 02 47 02 18 19
	!hex f0 02 5e 01 0c 13
	!hex 1d 02 71 03 0b 17
	!hex 69 03 31 03 18 16
	!hex d7 00 3e 01 0f 1c
	!hex 88 03 e9 00 13 12
	!hex 01 03 73 00 17 16
	!hex f3 01 a9 00 19 1a
	!hex 4c 01 6e 02 14 13
	!hex 56 00 fe 02 0a 13
	!hex 43 00 68 02 1c 17
	!hex 52 01 ba 00 17 12
	!hex fd 02 32 01 0f 1a
	!hex 18 02 c3 03 0b 14
	!hex a1 00 a0 00 0a 10
	!hex b9 00 94 00 1a 0d
	!hex d8 01 d4 00 0a 19
	!hex 7e 02 fd 01 0d 11
	!hex a4 03 9f 01 15 0e
	!hex f0 00 bc 03 12 1d
	!hex c1 02 02 00 1b 0b
	!hex 71 00 d2 02 15 11
	!hex 1f 02 7b 01 13 14
	!hex b8 02 38 01 0f 1a
	!hex ba 03 66 00 10 10
	!hex 0e 02 0d 03 18 18
	!hex c9 03 d9 02 18 0f
	!hex bb 00 81 00 11 1c
	!hex cc 00 f4 00 19 0a
	!hex 5d 00 e9 02 0a 0f
	!hex 10 00 a2 03 1b 11
	!hex 32 00 cd 00 1d 1d
	!hex 17 00 be 03 19 1c
	!hex d7 02 49 03 0a 14
	!hex 8c 02 92 03 11 16
	!hex 7d 00 78 00 17 15
	!hex 95 03 fa 02 15 1a
	!hex dc 00 14 00 1d 10
	!hex 8d 02 73 03 12 0c
	!hex ab 01 c2 03 13 0f
	!hex c0 00 2f 02 17 0a
	!hex 79 03 5d 00 11 19
	!hex af 03 19 00 16 19
	!hex 0e 03 56 03 15 10
	!hex c2 00 2d 02 12 10
	!hex a3 03 a0 03 15 17
	!hex 5b 01 57 03 0f 13
	!hex 4a 00 2a 02 14 0a
	!hex e7 01 c7 00 0d 1b
	!hex 09 03 2f 03 0b 12
	!hex c6 02 3b 02 14 18
	!hex 25 03 1c 00 0d 14
	!hex 6a 01 43 02 18 16
	!hex 63 00 50 03 15 13
	!hex c2 02 02 00 17 0f
	!hex 5d 01 80 03 1d 0d
	!hex 1b 03 41 01 18 0c
	!hex 00 00 d2 03 0c 11
	!hex ff 02 8c 00 0c 0b
	!hex 5e 01 0a 01 13 1c
	!hex d1 02 4a 02 0c 16
	!hex 23 02 88 01 1b 0a
	!hex 66 03 d1 01 19 12
	!hex 2c 02 29 03 0f 10
	!hex 54 00 df 00 11 12
	!hex c0 02 9c 00 0c 17
	!hex 19 03 64 01 0e 17
	!hex b9 00 a0 02 1a 18
	!hex fa 00 96 01 1c 13
	!hex 2d 01 d2 00 0c 0f
	!hex 48 00 a0 00 16 16
	!hex b4 00 55 03 0b 1b
	!hex 1a 03 60 02 15 15
	!hex 52 03 88 01 1a 17
	!hex 5f 01 98 00 15 14
	!hex b9 02 60 02 0e 0c
	!hex dd 01 f2 00 13 17
	!hex d0 00 d1 02 1c 1b
	!hex 53 00 fe 01 18 1a
	!hex 72 02 42 03 0f 0e
	!hex 0c 00 87 02 1b 18
	!hex b7 02 01 00 0b 0d
	!hex d2 01 b3 02 10 0d
	!hex 94 03 fa 00 1b 13
	!hex 98 00 cd 01 1d 0a
	!hex ab 02 40 03 0b 0f
	!hex f7 01 91 03 1b 1b
	!hex e6 00 54 00 14 19
	!hex c1 02 3d 02 18 0a
	!hex 81 02 9c 02 0d 1d
	!hex 52 02 fd 01 0a 0f
	!hex 12 01 cc 03 1b 19
	!hex 3b 02 3d 00 1b 14
	!hex 18 01 37 01 10 19
	!hex 2f 02 0a 01 1b 0e
	!hex da 01 aa 02 16 17
	!hex 9c 02 6d 01 1d 15
	!hex c2 01 59 01 12 1a
	!hex 0a 03 59 02 1d 0a
	!hex 61 01 97 00 11 10
	!hex 45 01 1b 02 05 07
	!hex fa 00 e9 00 19 19
	!hex a4 01 5d 01 1d 11
	!hex 05 00 da 00 1d 1d
	!hex 8b 02 e7 02 13 0d
	!hex 95 01 4b 01 0d 16
	!hex 5a 03 86 01 15 0e
	!hex 1c 01 a8 01 16 19
	!hex f5 02 95 03 13 16
	!hex da 02 8f 03 10 18
	!hex b0 02 6b 01 0a 0f
	!hex d1 02 49 02 1d 0b
	!hex 0e 00 27 01 11 17
	!hex d0 02 4c 02 0d 0e
	!hex d5 00 62 02 1d 0f
	!hex 30 03 1b 00 0b 1b
	!hex 60 03 02 00 16 0d
	!hex 76 02 9a 02 17 14
	!hex 48 01 6a 00 0c 1d
	!hex 53 02 9f 00 0a 11
	!hex a9 03 78 03 1b 0a
	!hex 89 02 79 01 1d 18
	!hex c7 00 53 00 1c 1b
	!hex f2 00 c2 03 14 16
	!hex c9 02 38 02 0b 19
	!hex 2f 01 bc 00 19 14
	!hex 02 00 9e 00 10 1d
	!hex a8 00 86 03 15 14
	!hex 8a 00 f1 00 19 0b
	!hex a8 03 4e 00 06 03
	!hex 1e 03 0e 02 0a 10
	!hex 9f 00 9a 00 0c 18
	!hex a9 01 0b 01 0d 19
	!hex ae 02 9d 00 15 1a
	!hex 3e 00 40 01 15 1b
	!hex 88 01 cd 03 11 1a
	!hex f6 01 5a 01 11 0d
	!hex fb 02 3e 00 1a 1c
	!hex 82 00 fb 00 18 0e
	!hex a2 03 c9 00 0c 1c
	!hex d8 01 65 02 0e 1d
	!hex 0d 02 f0 01 11 0b
	!hex 83 00 ab 03 0c 15
	!hex c0 02 28 01 0e 0e
	!hex a1 01 67 02 14 0d
	!hex 54 01 8b 00 0a 11
	!hex 9f 01 68 02 0a 14
	!hex 0a 01 21 00 1d 18
	!hex d3 03 64 02 10 08
	!hex e6 01 67 03 1d 18
	!hex 35 01 ec 01 0d 0f
	!hex 2a 02 03 03 1a 0d
	!hex 21 02 27 02 07 04
	!hex 3a 01 41 02 13 1d
	!hex 2b 00 df 00 0a 15
	!hex d9 01 61 02 13 17
	!hex eb 02 b6 02 17 1c
	!hex 71 01 ff 02 15 1c
	!hex 70 01 e0 02 1b 0f
	!hex c3 00 5a 02 0a 19
	!hex 09 00 84 02 17 0d
	!hex 56 01 36 01 0b 11
	!hex c7 03 24 03 13 1a
	!hex b4 02 6e 00 1d 19
	!hex 5e 01 1a 02 16 0b
	!hex 28 02 8a 01 0e 03
	!hex 81 03 86 03 12 17
	!hex 75 03 50 02 15 0f
	!hex a3 02 04 00 18 13
	!hex c9 03 cd 02 0d 13
	!hex 7b 02 82 00 1b 1d
	!hex 57 01 a6 02 0c 07
	!hex 4c 02 a1 03 16 1b
	!hex ec 02 35 02 19 12
	!hex cc 01 6d 02 0d 10
	!hex b1 02 17 02 17 1b
	!hex 45 01 6a 03 14 1b
	!hex 3a 01 20 02 13 1b
	!hex 26 02 84 02 0c 0c
	!hex 9f 01 04 01 1d 10
	!hex e4 00 b3 01 19 0c
	!hex 7b 01 38 02 11 0f
	!hex 7e 02 82 01 1b 0c
	!hex 4f 01 25 01 19 13
	!hex bb 02 58 02 1b 15
	!hex 16 02 a3 02 14 0a
	!hex 06 03 a0 00 14 1d
	!hex 19 00 d0 00 0c 17
	!hex 2a 01 79 02 1d 19
	!hex 25 01 b9 00 0b 0e
	!hex 86 02 b8 03 13 1a
	!hex f9 01 90 03 14 14
	!hex d8 00 b3 01 14 1c
	!hex 38 03 34 02 1b 15
	!hex db 02 9e 01 1b 0b
	!hex 83 00 cc 02 0e 19
	!hex 91 02 5c 01 13 16
	!hex 73 00 f1 02 0b 10
	!hex 81 03 66 01 16 19
	!hex e5 00 44 02 1a 13
	!hex 85 01 97 00 1b 18
	!hex a8 00 2d 01 1c 11
	!hex ab 01 af 00 1c 0c
	!hex ce 00 3f 01 0d 1b
	!hex 6d 00 74 01 1c 1b
	!hex 51 03 97 01 1b 0c
	!hex d3 01 d3 00 15 18
	!hex 0e 03 0a 02 18 0b
	!hex c2 01 b7 01 16 0a
	!hex f6 01 0d 03 15 18
	!hex 11 02 67 00 0e 18
	!hex 02 00 cf 03 1c 0c
	!hex 99 03 07 02 10 15
	!hex e2 02 73 02 16 15
	!hex 5e 02 26 00 0c 15
	!hex 54 03 50 01 10 0f
	!hex 02 03 2c 02 14 0a
	!hex 3d 01 38 00 0b 1a
	!hex 27 01 51 01 0c 19
	!hex 8b 00 9d 03 18 16
	!hex 39 03 37 03 0f 18
	!hex 2e 01 c6 00 11 0a
	!hex ce 01 2b 01 17 1d
	!hex 49 01 c4 01 18 0f
	!hex 89 02 41 03 13 0c
	!hex 03 00 e6 00 0c 1c
	!hex 46 03 81 00 1b 0e
	!hex 69 01 9f 00 1c 1c
	!hex 46 00 17 02 16 0c
	!hex 63 02 12 03 12 0f
	!hex ab 02 30 00 19 1a
	!hex be 03 8d 00 13 0a
	!hex 8f 02 ce 02 1a 16
	!hex ba 01 9f 00 0a 0a
	!hex 37 02 cc 02 1c 0c
	!hex c7 03 ae 00 1d 0d
	!hex cc 02 00 03 17 18
	!hex 62 03 3b 00 0c 10
	!hex c2 01 07 03 0d 17
	!hex ef 00 5d 02 0b 1d
	!hex 84 03 22 00 12 16
	!hex d8 01 15 01 0f 19
	!hex 7f 03 61 03 14 1b
	!hex d4 03 9e 03 13 1b
	!hex d7 02 65 02 19 1d
	!hex 07 00 8e 01 18 0c
	!hex d1 01 68 02 12 1a
	!hex 4a 01 fe 01 1b 10
	!hex 02 01 50 02 0d 10
	!hex a1 01 91 01 1c 10
	!hex 0e 03 87 01 1b 0d
	!hex 9c 01 c3 03 12 0f
	!hex bc 01 57 02 0a 12
	!hex 37 00 cb 02 0d 0b
	!hex c4 01 b9 01 0f 05
	!hex 20 02 26 01 1b 0f
	!hex 74 03 09 02 12 1d
	!hex 6f 02 d0 01 11 0b
	!hex 72 01 9c 00 1d 10
	!hex 03 00 4e 03 18 10
	!hex be 00 7a 03 13 0d
	!hex 28 02 3f 03 05 04
	!hex 4f 02 55 02 19 13
	!hex 8d 02 52 01 10 19
	!hex a0 01 08 01 0b 1d
	!hex 11 01 84 01 0c 1a
	!hex 8c 03 08 02 14 1b
	!hex 90 00 0b 02 0c 1a
	!hex ad 01 67 02 12 13
	!hex 67 02 0b 02 10 0e
	!hex f5 02 cc 03 18 14
	!hex 06 00 de 00 0a 13
	!hex 17 00 cc 03 0a 10
	!hex c2 02 47 02 15 1a
	!hex 49 00 f7 00 19 0a
	!hex f0 01 fa 02 1a 1d
	!hex 61 03 ec 02 13 0d
	!hex 93 02 97 03 0c 11
	!hex 16 03 7a 01 1b 1c
	!hex eb 02 ba 01 12 18
	!hex c5 02 01 03 08 14
	!hex b8 00 7d 03 0f 1c
	!hex c8 01 21 00 1c 0b
	!hex 72 03 0f 01 0a 12
	!hex 4b 02 aa 00 14 11
	!hex 63 03 62 03 0a 11
	!hex c9 03 b9 03 0e 12
	!hex cc 02 80 01 0e 13
	!hex 43 01 04 01 0a 17
	!hex e0 00 32 02 14 13
	!hex c0 00 f9 00 19 0b
	!hex 57 00 07 03 1a 18
	!hex fe 02 92 00 14 11
	!hex db 00 c2 02 17 10
	!hex 45 02 8d 01 10 1d
	!hex dd 02 be 03 12 1c
	!hex bb 03 cf 00 1d 0f
	!hex 8a 03 57 03 13 11
	!hex 39 02 c1 02 1b 0c
	!hex 69 01 4c 02 0b 0d
	!hex 95 00 c7 02 14 14
	!hex 49 00 2e 02 0c 17
	!hex 1d 02 cd 02 1b 0a
	!hex 2f 01 3a 02 0f 0b
	!hex 9a 02 9b 03 1a 1b
	!hex 19 00 57 01 11 1c
	!hex be 00 66 03 1a 18
	!hex ed 02 63 00 0d 18
	!hex 75 03 4c 03 13 1a
	!hex 73 01 63 02 0d 12
	!hex aa 03 dc 01 17 1b
	!hex f7 00 f9 02 14 17
	!hex 87 00 60 02 18 13
	!hex 2e 02 c2 01 1b 0f
	!hex 49 03 84 01 16 0a
	!hex f2 02 da 01 1c 13
	!hex 88 01 c5 03 17 1c
	!hex 18 00 0a 00 1c 0d
	!hex 2f 02 6b 02 0b 14
	!hex 03 01 c7 01 0e 17
	!hex 41 03 dd 01 0e 0c
	!hex 9b 02 67 03 14 19
	!hex 69 01 f1 02 1b 0e
	!hex e1 01 57 02 0d 14
	!hex c0 02 60 00 12 19
	!hex 30 00 ac 03 19 1d
	!hex 71 02 1b 03 0a 0b
	!hex 9b 02 40 02 0e 0f
	!hex a0 00 c7 03 14 17
	!hex a8 00 9b 00 0c 09
	!hex b6 00 a5 00 1a 15
	!hex 4b 02 94 03 0f 0a
	!hex 4d 02 28 00 0b 16
	!hex a4 02 eb 00 0f 12
	!hex cd 02 7e 00 0d 0d
	!hex e1 01 42 03 16 16
	!hex 2a 03 89 02 1a 0d
	!hex 92 02 e6 02 07 11
	!hex 29 02 c6 01 18 1b
	!hex 8c 03 a6 01 11 10
	!hex 36 03 14 02 15 11
	!hex 6c 01 7f 00 0d 11
	!hex 56 02 ce 01 1b 0b
	!hex b6 01 ed 02 11 1d
	!hex 18 02 8a 01 10 19
	!hex ce 02 91 03 0e 16
	!hex ec 02 4b 01 0e 1b
	!hex 84 01 e9 02 1d 0a
	!hex 08 02 9b 03 16 0d
	!hex 93 03 ba 00 10 03
	!hex 25 01 52 02 1b 19
	!hex 56 01 8e 00 17 1b
	!hex 5b 03 c5 00 10 18
	!hex e3 01 4b 01 1d 15
	!hex 30 03 5d 03 0a 17
	!hex 98 02 91 03 11 15
	!hex e2 01 3a 01 0f 0d
	!hex 5b 01 54 00 0a 1a
	!hex 8c 00 fe 02 17 0f
	!hex 00 03 ae 02 1a 15
	!hex 4c 02 20 00 1a 11
	!hex 91 03 84 03 14 13
	!hex 45 02 d3 00 10 0a
	!hex 82 02 f2 02 12 0c
	!hex a6 02 9b 00 0b 0d
	!hex 24 03 66 02 0c 0b
	!hex e9 00 52 02 12 15
	!hex 53 00 21 03 14 16
	!hex 88 00 d8 02 1b 13
	!hex 75 00 75 02 0d 0a
	!hex a7 00 ad 00 0d 0b
	!hex f4 00 d3 02 0d 0d
	!hex 7a 03 73 01 13 16
	!hex e5 02 c8 03 0d 1c
	!hex e5 01 d2 00 1a 0f
	!hex 3c 01 19 02 16 0d
	!hex d3 00 08 00 0c 17
	!hex 75 03 61 00 12 1d
	!hex f0 00 f5 00 10 12
	!hex 92 03 37 03 10 14
	!hex c0 02 8e 03 12 0c
	!hex f7 00 e5 02 10 04
	!hex 83 00 ec 02 15 10
	!hex 51 02 96 03 0d 0a
	!hex 31 01 5f 02 0b 10
	!hex 86 02 5c 02 13 13
	!hex 18 03 33 00 0f 0b
	!hex 84 03 a9 01 19 0c
	!hex 74 03 0c 00 0b 0c
	!hex f6 01 f3 02 1b 18
	!hex b2 01 02 03 0f 0b
	!hex 81 03 b9 01 16 14
	!hex 4f 03 47 01 0c 13
	!hex 89 00 67 00 15 1a
	!hex c1 03 ae 02 0a 1d
	!hex 6e 01 8d 00 1d 15
	!hex 60 00 58 02 0e 0b
	!hex b8 02 ac 02 0c 17
	!hex 6e 00 59 00 13 17
	!hex e2 01 c6 01 15 14
	!hex 1e 02 72 03 15 0b
	!hex ed 00 43 02 0d 0e
	!hex 90 03 9e 00 0c 0e
	!hex 95 03 6e 01 1a 15
	!hex 77 03 c6 00 0e 0b
	!hex c4 02 50 01 0e 0b
	!hex be 02 20 01 19 1d
	!hex f4 02 85 01 0c 14
	!hex a0 03 f7 01 0e 0a
	!hex 53 03 cb 01 16 0e
	!hex d1 02 04 02 07 07
	!hex e8 00 3c 02 0c 13
	!hex 9e 02 af 03 1d 0f
	!hex ff 02 86 03 14 16
	!hex ae 02 a3 02 10 17
	!hex 52 03 84 02 12 10
	!hex 89 03 93 01 17 1d
	!hex ed 00 be 03 10 0a
	!hex c9 01 b6 02 1b 19
	!hex 12 00 8c 01 13 14
	!hex 63 01 18 02 16 0d
	!hex 2f 00 27 02 1d 10
	!hex e5 00 7d 00 0e 0a
	!hex be 02 6d 00 0a 1c
	!hex 8d 02 8a 03 07 10
	!hex 79 03 0c 02 09 13
	!hex 31 03 e0 02 18 1a
	!hex 79 00 0e 01 0d 14
	!hex c2 02 9d 00 14 13
	!hex cd 00 c3 03 0c 12
	!hex da 01 69 02 0b 1d
	!hex 86 02 81 03 1c 16
	!hex 34 01 6a 02 16 13
	!hex 0d 03 9d 00 0a 11
	!hex ef 02 cf 03 0f 12
	!hex b5 00 74 02 18 12
	!hex c6 02 c7 02 0f 16
	!hex 73 00 95 00 19 13
	!hex 96 01 fd 02 0b 04
	!hex 9b 03 cc 01 0c 0e
	!hex 97 01 47 03 13 04
	!hex 25 02 21 03 19 0d
	!hex 0a 03 dc 01 13 0a
	!hex ea 00 ad 00 17 19
	!hex 6e 00 67 03 0b 17
	!hex 92 03 86 03 16 0c
	!hex b9 03 20 00 11 0f
	!hex 18 03 7c 03 0d 17
	!hex 89 00 24 01 18 11
	!hex cb 01 3b 01 0a 15
	!hex 91 03 b5 00 17 10
	!hex 40 03 2f 02 15 10
	!hex d3 03 4f 02 14 16
	!hex fb 02 72 01 0e 1a
	!hex 1f 03 5b 02 18 1a
	!hex 07 01 6e 00 11 19
	!hex 93 02 46 02 14 13
	!hex 1f 03 6f 01 03 08
	!hex 21 02 68 03 1a 19
	!hex 49 01 57 00 0f 14
	!hex 8c 03 da 00 1a 0f
	!hex 24 03 56 02 1c 1b
	!hex 4b 00 2c 00 18 1d
	!hex 38 02 43 03 10 16
	!hex 7c 02 e2 01 18 1a
	!hex 2c 01 52 01 18 0a
	!hex 74 03 ba 00 11 1d
	!hex 13 03 85 03 13 16
	!hex a8 01 01 01 0a 1c
	!hex 0c 01 3b 00 0e 0b
	!hex 7e 01 47 01 1d 0e
	!hex bd 01 54 03 0f 07
	!hex fd 02 35 03 19 17
	!hex 0c 03 93 03 16 10
	!hex 80 00 c5 02 0a 0d
	!hex 74 01 55 03 1c 0c
	!hex f7 02 6a 00 12 1b
	!hex ca 02 d5 01 0d 1c
	!hex 1a 00 3e 03 10 1b
	!hex 1a 01 be 03 1c 0d
	!hex 96 02 a8 03 14 18
	!hex 72 00 7d 01 08 0a
	!hex 3f 01 66 00 18 19
	!hex 69 01 57 02 1b 1b
	!hex 42 01 f5 01 0e 0d
	!hex 69 02 a4 01 0b 0a
	!hex a3 03 98 03 19 17
	!hex b9 00 0b 03 10 1c
	!hex dc 02 45 02 17 10
	!hex c4 00 1a 03 0f 0b
	!hex 09 00 04 02 15 19
	!hex e9 00 09 02 1c 14
	!hex 8b 02 81 03 0c 1d
	!hex a6 00 7a 00 19 14
	!hex f3 02 84 01 04 0a
	!hex de 00 71 03 1b 1d
	!hex 12 03 53 03 0b 0b
	!hex d7 03 1d 02 10 1c
	!hex 66 00 76 00 0e 0b
	!hex ca 00 f7 01 13 15
	!hex 4a 00 2c 03 0f 12
	!hex 21 02 5e 00 19 1c
	!hex 86 03 4f 01 13 19
	!hex 23 03 5a 02 0b 0b
	!hex 89 00 70 00 0e 11
	!hex ca 01 d4 01 0b 17
	!hex 54 01 43 01 15 1d
	!hex 54 01 63 02 16 1c
	!hex 41 03 3f 03 0d 0c
	!hex 01 01 68 00 0c 0f
	!hex 3c 03 57 02 15 13
	!hex 17 01 7b 01 18 0e
	!hex 10 02 ef 02 0e 0e
	!hex a0 03 cf 00 0b 17
	!hex ec 00 bb 03 14 0e
	!hex 70 01 37 03 14 1a
	!hex 49 01 9b 01 1a 0f
	!hex a0 00 eb 02 14 19
	!hex f1 02 81 01 0a 11
	!hex dd 03 3e 02 0b 1d
	!hex 84 02 04 02 1a 0c
	!hex c0 02 ef 02 0d 18
	!hex 88 01 1a 01 0e 0a
	!hex 27 01 9f 03 16 1d
	!hex 5e 03 bf 00 18 1a
	!hex 79 03 26 00 12 0e
	!hex 4c 03 55 01 11 15
	!hex 97 03 95 02 11 18
	!hex 21 01 a0 03 17 10
	!hex 45 01 b8 01 0a 0b
	!hex 45 02 3e 02 15 1c
	!hex 29 00 d4 00 17 0b
	!hex eb 00 39 03 19 0e
	!hex e2 01 b0 01 13 16
	!hex ba 03 e8 01 1c 0b
	!hex ba 01 94 00 19 12
	!hex ac 01 49 02 10 14
	!hex c2 02 eb 01 13 1a
	!hex 7d 02 2c 00 0f 0b
	!hex da 01 bd 03 13 18
	!hex b8 00 4e 03 12 1b
	!hex 79 03 10 00 15 1c
	!hex 61 03 d6 02 10 18
	!hex 41 01 43 02 1b 0e
	!hex 52 00 13 02 16 1b
	!hex c1 03 dd 02 11 15
	!hex 70 01 89 00 0a 14
	!hex ee 01 b9 01 19 16
	!hex 5b 03 37 01 14 11
	!hex d5 01 c3 02 18 1c
	!hex a1 00 94 01 10 1d
	!hex 1e 03 33 01 11 10
	!hex 98 01 89 00 0a 0a
	!hex 13 00 31 03 0e 16
	!hex ea 01 7e 02 12 11
	!hex 8b 02 60 00 17 19
	!hex 45 00 b6 02 14 18
	!hex 0e 01 69 02 0d 14
	!hex ef 00 6e 03 1d 0a
	!hex c1 03 38 02 19 0c
	!hex 4b 00 22 00 12 17
	!hex c1 03 c3 02 1c 1c
	!hex c9 03 ab 03 10 1b
	!hex 18 01 23 00 18 15
	!hex c6 02 93 03 0b 14
	!hex 9e 02 71 02 1c 1b
	!hex 6d 00 68 03 15 0f
	!hex 4c 02 df 02 0d 1d
	!hex af 00 b2 00 14 0c
	!hex b3 02 ce 02 19 0f
	!hex 02 00 9d 00 0b 0a
	!hex 5b 02 11 02 0a 1c
	!hex 00 00 28 01 13 0f
	!hex 40 02 c2 03 0a 0f
	!hex 80 02 8d 00 18 15
	!hex f8 02 27 01 12 15
	!hex bb 02 a0 01 18 15
	!hex 39 01 08 02 0b 0a
	!hex e0 02 17 03 15 15
	!hex cd 03 e7 01 0e 1c
	!hex d9 01 67 01 18 0e
	!hex e6 00 44 00 0b 16
	!hex 74 00 61 03 1c 19
	!hex 88 00 38 02 19 1b
	!hex 22 02 65 00 1b 18
	!hex 71 02 98 02 0a 1b
	!hex 79 01 70 00 0b 1d
	!hex 02 03 c3 02 12 0c
	!hex 58 03 91 03 1b 18
	!hex d0 03 88 02 10 1c
	!hex 43 02 f5 02 0a 16
	!hex d3 02 34 02 13 17
	!hex d9 02 43 00 19 1b
	!hex b4 01 12 01 10 15
	!hex 3f 03 02 00 1c 14
	!hex 25 01 0e 00 1a 0a
	!hex 4d 00 82 03 13 1d
	!hex 93 00 9b 02 0a 1d
	!hex 49 02 f8 02 10 1a
	!hex 6e 00 b7 02 11 16
	!hex a7 03 57 01 13 17
	!hex e6 02 84 03 19 14
	!hex 83 02 a9 02 0a 12
	!hex 7a 02 8f 02 0b 17
	!hex 67 00 01 02 0b 16
	!hex 3b 03 e7 02 0e 0e
	!hex 7e 01 06 03 17 0e
	!hex e2 02 19 03 0d 05
	!hex cc 03 0c 01 1a 16
	!hex ed 00 f2 00 0c 1b
	!hex 09 02 bd 02 0b 14
	!hex a8 03 82 02 0d 19
	!hex 44 00 3a 01 0b 0d
	!hex 56 01 f0 02 17 15
	!hex 4e 02 a1 03 14 19
	!hex 03 00 bf 02 12 1d
	!hex 8e 02 6d 03 1d 10
	!hex b6 03 d6 01 1a 0c
	!hex b3 00 33 00 0d 18
	!hex 9c 02 3d 03 17 18
	!hex 0e 01 14 03 14 0b
	!hex 54 02 1a 02 0f 0c
	!hex ef 00 95 03 14 17
	!hex f0 00 1b 01 0f 0d
	!hex 4c 00 32 01 11 15
	!hex 5c 02 ef 00 11 0a
	!hex dd 02 85 01 0a 0d
	!hex a9 03 66 01 0c 0b
	!hex b6 01 76 03 13 1b
	!hex 79 00 10 03 12 17
	!hex 3f 02 a6 01 14 10
	!hex 09 02 c0 02 12 11
	!hex b3 02 a3 01 15 0b
	!hex 42 00 d4 01 16 16
	!hex 12 02 67 00 0c 17
	!hex f0 02 68 00 19 1d
	!hex 83 03 3e 00 1a 0d
	!hex 20 01 f8 00 17 19
	!hex 61 01 c4 00 10 10
	!hex 98 03 c2 00 0b 17
	!hex 4c 00 15 00 16 19
	!hex 62 03 38 00 11 0c
	!hex 42 01 51 01 18 11
	!hex 7c 03 7c 01 0f 18
	!hex b1 03 63 01 14 0e
	!hex 19 00 7a 02 12 14
	!hex 44 00 12 03 10 12
	!hex e7 00 b4 03 0a 13
	!hex 51 01 36 01 19 0e
	!hex d9 01 8b 03 16 0e
	!hex ca 02 76 00 13 1a
	!hex 84 00 4f 02 0b 14
	!hex 51 03 77 01 0e 10
	!hex d4 00 ae 03 16 0f
	!hex a8 00 1b 02 15 19
	!hex 57 02 70 01 1b 1a
	!hex 3c 01 4a 00 0e 19
	!hex 7c 02 81 02 0e 03
	!hex c7 03 c1 03 1c 0c
	!hex 98 02 ca 00 15 17
	!hex 60 03 dc 02 14 0e
	!hex 0d 02 e7 02 15 1b
	!hex 91 03 aa 00 0d 0f
	!hex c4 00 2a 03 0d 1b
	!hex 79 00 1b 02 1a 11
	!hex 2d 01 4a 02 16 0f
	!hex 83 01 08 03 07 09
	!hex 78 03 94 00 14 10
	!hex 44 00 3a 01 10 0d
	!hex 73 02 8a 02 0a 15
	!hex e1 01 6d 01 16 0b
	!hex fd 02 a0 03 0a 0d
	!hex 95 00 cb 02 10 0e
	!hex 27 03 8d 00 19 1b
	!hex 1a 00 fb 00 0e 12
	!hex df 02 5d 02 0f 0c
	!hex 4a 01 9a 00 1a 0c
	!hex f9 01 0a 03 15 12
	!hex 3b 00 80 01 13 18
	!hex 3e 01 60 02 0a 16
	!hex 91 01 50 02 13 16
	!hex 95 02 da 02 0b 12
	!hex 98 02 f2 00 15 1b
	!hex 54 00 ee 00 17 1b
	!hex 28 02 0e 01 0a 0e
	!hex c4 00 84 03 14 0d
	!hex 94 03 c1 00 16 1b
	!hex 1d 02 9b 00 14 15
	!hex 9d 03 34 03 13 13
	!hex 92 01 63 02 0b 19
	!hex 63 02 e0 02 16 18
	!hex f9 01 59 00 1b 19
	!hex f6 00 dc 02 0a 0b
	!hex da 00 6e 02 0c 13
	!hex c9 01 93 00 0f 19
	!hex 11 03 f9 01 19 11
	!hex d6 01 35 02 1d 1c
	!hex e3 00 af 00 19 1b
	!hex 75 00 59 00 0c 0b
	!hex 5c 03 cb 01 16 0f
	!hex e3 00 be 01 13 0d
	!hex a1 00 a5 01 11 13
	!hex 47 00 e0 01 1b 0c
	!hex 75 00 1c 03 0e 0a
	!hex 0b 02 b2 01 0a 0f
	!hex 4b 02 bb 02 0c 10
	!hex 83 02 59 02 10 1c
	!hex 49 00 5f 02 18 17
	!hex 8c 03 1c 01 1d 10
	!hex a3 03 8d 02 15 1b
	!hex f4 01 9e 00 19 18
	!hex 82 00 c8 02 05 05
	!hex fa 01 07 01 14 16
	!hex 77 02 db 01 1d 13
	!hex b2 01 00 03 15 0e
	!hex 38 03 ca 01 1c 11
	!hex ff ff
theend
bc = (theend+255)/256*256  ; bitcount (start on new page)
map = bc+256 ; map (start on new page). each byte holds 4 2-bit ints holding
             ; the number of claims for that cell (capped upwards at 3)
