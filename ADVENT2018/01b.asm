; advent of code 2018 day 1 part 2
; https://adventofcode.com/2018/day/1
; algorithm: generate numbers as described in the problem, use a huge bit array
; to mark seen numbers and detect the first duplicate and hope we have enough
; memory
; runtime: 1 minute 55 seconds

	CHROUT = $ffd2

	!to "01b.prg",cbm
	* = $0801
	; sys start
	!byte $0b, $08, $0a, $00, $9e, 48+start/1000%10, 48+start/100%10, 48+start/10%10, 48+start%10, $00, $00, $00

	; warning, we must adjust the number of bytes of mul1/product/sum
	; manually according to clen
	; also, the number of bits of the multiplicand and product of the mul10
	; routine is hardcoded
	clen = 3 ; number of bytes of integers in big-endian (unfortunately),
	         ; but too late to change now
	zp = $fe ; pointer into input file
	eos = $fd ; pointer to end of string
	zp2 = $fb ; pointer to list of values

start	sei
	lda #$34 ; we want access to as much memory as possible, so switch
	sta $01  ; out ROM
	; set storage to zero
	ldx #0
	ldy #>storage
	stx zp+0
	sty zp+1
	ldy #0
	tya
-	sta (zp),y
	iny
	bne -
	inc zp+1
	bne -
	; set current sum to 0
	ldx #clen-1
-	sta sum,x
	dex
	bpl -
	; process 0 before processing other values
	jsr process
eof	ldx #<input
	ldy #>input
	stx zp+0
	sty zp+1
	; main loop: read the next line of the "text file"
	; each line begins with + or -, followed by an integer
loop	ldy #0
	lda (zp),y
	beq eof
	cmp #'-'
	beq minus
	; read a positive integer
	; find linebreak, and read in reverse order
	jsr readint
	jmp common

minus	; read a negative integer
	jsr readint
	; negate term: perform not (aka xor $ff) and add 1
	ldx #clen-1
-	lda mul1,x
	eor #$ff
	sta mul1,x
	dex
	bpl -
	sec ; add 1
	ldx #clen-1
-	lda #0
	adc mul1,x
	sta mul1,x
	dex
	bpl -
common	jsr update
	jsr process

nextnum	lda eos
	sec ; add eos+1
	adc zp+0
	sta zp+0
	bcc loop
	inc zp+1
	bne loop

	; multiply 24-bit integer by 10
	; clobbers the x-register
mul1	!byte 0,0,0
product	!byte 0,0,0

mul10	asl mul1+2
	rol mul1+1
	rol mul1+0
	lda mul1+2
	sta product+2
	lda mul1+1
	sta product+1
	lda mul1+0
	sta product+0
	ldx #2
-	asl mul1+2
	rol mul1+1
	rol mul1+0
	dex
	bne -
	ldx #clen-1
	clc
-	lda mul1,x
	adc product,x
	sta product,x
	dex
	bpl -
	rts

	; read an integer from input and store it as 32-bit int
readint	ldx #clen-1
	lda #0
-	sta mul1,x
	dex
	bpl -
	ldy #1
rloop	lda (zp),y
	beq done
	cmp #$0d
	beq done
	; new digit, multiply what we already have by 10 and add the new digit
	pha
	jsr mul10
	pla
	and #$0f
	clc
	adc product+clen-1
	sta mul1+clen-1
	ldx #clen-2
-	lda #0
	adc product,x
	sta mul1,x
	dex
	bpl -
	iny
	bne rloop
done	sty eos
	rts

	; update sum
update	ldx #clen-1
	clc
-	lda mul1,x
	adc sum,x
	sta sum,x
	dex
	bpl -
	rts

temp	!byte 0,0,0,0
magic	!byte 2,0,0

error	lda #$36
	sta $01
-	dec $d021
	inc $d021
	jmp -

process	; add a magic constant to force positive number
	; (sort of cheating as it assumes something about the input that's not
	; written in the problem statement)
	ldx #clen-1
	clc
-	lda sum,x
	adc magic,x
	sta temp,x
	dex
	bpl -
	lda temp+0
	bmi error ; number is negative, report error
	; divide by 8 to get memory address and bitmask
	ldx #3
	lda #0
-	lsr temp+0
	ror temp+1
	ror temp+2
	rol
	dex
	bne -
	sta temp+3
	lda temp+0
	bne error
	lda temp+1
	cmp #256->storage
	bcs error ; number is still too large, report error
	; value within ram bounds
	lda temp+1
	clc
	adc #>storage
	sta zp2+1
	lda temp+2
	sta zp2+0
	ldy #0
	lda (zp2),y
	ldx temp+3
	and ortable,x
	bne win
	lda (zp2),y
	ora ortable,x
	sta (zp2),y
	rts
win	; we won
	lda #$37
	sta $01
	; negative answer?
	lda sum+0
	bpl plus
	; print minus sign, negate and add 1, then output normally
	lda #'-'
	jsr CHROUT
	ldx #clen-1
-	lda sum,x
	eor #$ff
	sta sum,x
	dex
	bpl -
	ldx #clen-1
	sec ; add 1
-	lda sum,x
	adc #0
	sta sum,x
	dex
	bpl -
plus	ldx #clen-1
	ldy #0
-	lda sum,x ; we messed up endian, reverse before outputting
	sta inbcd,y
	iny
	dex
	bpl -
	jsr int24tobcd
	ldx #<outbcd
	ldy #>outbcd
	lda #4
	jsr printbcd
	cli
	pla
	pla
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

sum	!byte 0,0,0

ortable !byte 1,2,4,8,16,32,64,128
andtable !hex fe fd fb f7 ef df bf 7f

; input: hex dump of text file, 0d = linebreak, 0-terminated
; warning, the input reading routine is dumb, so the file must end with 00 00
; if there's no 0d after the last line
input	!hex 2d 31 0d 2d 37 0d 2d 35 0d 2d 31 36 0d 2d 32 0d 2d 31 31 0d 2d 31
	!hex 37 0d 2b 31 34 0d 2d 38 0d 2d 35 0d 2d 37 0d 2b 38 0d 2b 31 0d 2b
	!hex 31 33 0d 2b 36 0d 2b 37 0d 2b 31 35 0d 2d 35 0d 2b 31 35 0d 2d 31
	!hex 36 0d 2d 31 0d 2d 31 36 0d 2b 31 39 0d 2d 36 0d 2d 31 39 0d 2d 32
	!hex 0d 2b 36 0d 2b 31 36 0d 2d 31 31 0d 2d 31 39 0d 2d 31 37 0d 2d 38
	!hex 0d 2d 35 0d 2b 38 0d 2d 31 30 0d 2d 35 0d 2b 31 30 0d 2d 31 33 0d
	!hex 2d 34 0d 2b 35 0d 2b 31 38 0d 2b 38 0d 2d 31 38 0d 2d 34 0d 2d 36
	!hex 0d 2d 31 34 0d 2d 35 0d 2b 38 0d 2b 35 0d 2d 31 38 0d 2b 36 0d 2d
	!hex 37 0d 2d 31 32 0d 2d 35 0d 2d 31 0d 2b 31 36 0d 2d 31 39 0d 2d 32
	!hex 0d 2d 31 33 0d 2b 34 0d 2d 35 0d 2b 32 0d 2b 32 0d 2d 31 30 0d 2b
	!hex 31 37 0d 2d 31 0d 2b 31 37 0d 2d 35 0d 2b 39 0d 2d 31 30 0d 2b 31
	!hex 32 0d 2b 32 30 0d 2b 31 37 0d 2d 31 32 0d 2b 39 0d 2b 31 36 0d 2b
	!hex 31 34 0d 2d 32 30 0d 2b 33 0d 2b 31 35 0d 2d 32 0d 2b 31 32 0d 2b
	!hex 31 0d 2b 31 37 0d 2d 31 33 0d 2d 32 0d 2d 36 0d 2d 38 0d 2d 33 0d
	!hex 2b 31 38 0d 2b 32 31 0d 2b 31 31 0d 2d 32 30 0d 2b 31 38 0d 2b 37
	!hex 0d 2b 31 39 0d 2b 31 37 0d 2b 31 37 0d 2d 31 35 0d 2d 38 0d 2b 31
	!hex 39 0d 2b 31 0d 2b 39 0d 2b 31 31 0d 2d 31 35 0d 2b 31 39 0d 2d 31
	!hex 34 0d 2d 32 0d 2d 31 37 0d 2b 31 31 0d 2b 31 36 0d 2b 31 34 0d 2b
	!hex 31 36 0d 2d 33 0d 2b 31 34 0d 2b 31 35 0d 2b 32 0d 2d 31 39 0d 2b
	!hex 33 0d 2d 31 30 0d 2b 33 0d 2d 31 31 0d 2d 31 33 0d 2d 31 36 0d 2b
	!hex 31 30 0d 2d 37 0d 2d 31 32 0d 2d 36 0d 2b 33 0d 2b 31 33 0d 2b 37
	!hex 0d 2b 31 37 0d 2b 31 37 0d 2b 33 0d 2b 37 0d 2d 31 39 0d 2d 32 0d
	!hex 2d 31 30 0d 2d 33 0d 2d 39 0d 2d 31 31 0d 2b 31 36 0d 2b 36 0d 2b
	!hex 38 0d 2b 31 35 0d 2b 31 36 0d 2b 37 0d 2b 34 0d 2b 38 0d 2b 35 0d
	!hex 2d 31 32 0d 2d 36 0d 2b 38 0d 2b 31 32 0d 2b 35 0d 2d 31 31 0d 2b
	!hex 31 37 0d 2d 31 0d 2b 35 0d 2b 31 32 0d 2d 31 39 0d 2d 37 0d 2d 31
	!hex 31 0d 2b 39 0d 2d 31 32 0d 2b 35 0d 2d 33 0d 2b 38 0d 2d 31 33 0d
	!hex 2b 31 32 0d 2b 31 30 0d 2b 33 0d 2d 37 0d 2b 31 38 0d 2b 33 0d 2d
	!hex 31 31 0d 2b 36 0d 2d 32 0d 2b 31 34 0d 2d 34 0d 2b 31 36 0d 2b 31
	!hex 32 0d 2d 33 0d 2b 31 33 0d 2d 31 38 0d 2d 31 33 0d 2d 31 0d 2d 31
	!hex 30 0d 2b 31 35 0d 2d 33 0d 2b 36 0d 2b 31 39 0d 2d 31 30 0d 2d 31
	!hex 30 0d 2b 36 0d 2b 38 0d 2d 35 0d 2d 34 0d 2b 31 37 0d 2d 35 0d 2b
	!hex 31 38 0d 2d 32 0d 2d 39 0d 2b 37 0d 2b 38 0d 2d 37 0d 2b 34 0d 2b
	!hex 31 33 0d 2d 31 35 0d 2d 34 0d 2b 38 0d 2d 31 39 0d 2d 33 0d 2b 31
	!hex 33 0d 2b 31 33 0d 2b 36 0d 2b 33 0d 2d 37 0d 2b 31 34 0d 2b 36 0d
	!hex 2b 32 30 0d 2d 34 0d 2d 31 37 0d 2d 31 38 0d 2b 32 30 0d 2b 31 0d
	!hex 2b 31 39 0d 2b 31 34 0d 2b 31 30 0d 2b 31 30 0d 2d 35 0d 2b 37 0d
	!hex 2d 31 39 0d 2b 31 30 0d 2d 31 37 0d 2b 31 38 0d 2b 39 0d 2d 31 31
	!hex 0d 2d 31 31 0d 2b 31 38 0d 2b 31 38 0d 2b 31 35 0d 2d 31 31 0d 2b
	!hex 31 30 0d 2d 38 0d 2b 31 39 0d 2d 35 0d 2b 37 0d 2b 36 0d 2b 31 31
	!hex 0d 2b 31 38 0d 2b 34 0d 2d 31 37 0d 2d 31 38 0d 2b 38 0d 2b 31 35
	!hex 0d 2b 32 32 0d 2b 36 0d 2d 31 30 0d 2d 31 0d 2d 32 34 0d 2d 31 38
	!hex 0d 2b 31 33 0d 2b 39 0d 2b 31 0d 2d 31 35 0d 2d 31 0d 2b 32 31 0d
	!hex 2b 32 34 0d 2b 35 0d 2b 32 39 0d 2b 32 32 0d 2b 31 33 0d 2d 31 30
	!hex 0d 2d 31 32 0d 2d 31 35 0d 2b 33 32 0d 2b 31 35 0d 2b 31 37 0d 2d
	!hex 31 32 0d 2b 34 0d 2d 31 32 0d 2d 31 30 0d 2b 31 0d 2b 31 35 0d 2b
	!hex 31 35 0d 2d 31 31 0d 2d 39 0d 2b 31 38 0d 2b 36 0d 2b 36 0d 2b 31
	!hex 31 0d 2b 31 0d 2b 31 38 0d 2d 31 33 0d 2d 31 39 0d 2d 31 36 0d 2d
	!hex 31 35 0d 2d 33 0d 2b 31 34 0d 2b 35 0d 2b 31 38 0d 2d 36 0d 2d 39
	!hex 0d 2b 31 0d 2d 32 34 0d 2d 32 35 0d 2d 35 0d 2b 31 30 0d 2b 31 31
	!hex 0d 2b 33 30 0d 2b 31 35 0d 2d 31 39 0d 2d 34 0d 2d 33 0d 2d 31 37
	!hex 0d 2b 31 35 0d 2b 33 31 0d 2b 32 30 0d 2b 31 38 0d 2b 38 0d 2d 34
	!hex 0d 2b 31 30 0d 2b 31 35 0d 2b 31 36 0d 2b 39 0d 2d 31 36 0d 2b 38
	!hex 0d 2d 31 31 0d 2d 37 0d 2b 38 0d 2d 31 30 0d 2d 32 34 0d 2d 31 0d
	!hex 2b 31 36 0d 2b 31 36 0d 2d 31 0d 2d 31 36 0d 2b 31 31 0d 2b 34 0d
	!hex 2b 33 0d 2d 31 35 0d 2d 37 0d 2b 34 36 0d 2b 38 0d 2b 31 38 0d 2b
	!hex 31 34 0d 2d 31 30 0d 2d 31 31 0d 2b 31 34 0d 2d 32 31 0d 2b 32 34
	!hex 0d 2d 31 32 0d 2b 32 32 0d 2b 31 39 0d 2d 31 30 0d 2b 31 37 0d 2b
	!hex 31 35 0d 2b 39 0d 2b 39 0d 2d 32 30 0d 2b 31 39 0d 2d 31 33 0d 2b
	!hex 32 30 0d 2b 31 32 0d 2b 31 37 0d 2d 31 30 0d 2b 31 37 0d 2b 34 0d
	!hex 2d 31 34 0d 2b 31 37 0d 2d 31 32 0d 2d 31 36 0d 2b 31 39 0d 2b 31
	!hex 34 0d 2b 31 37 0d 2b 39 0d 2b 31 38 0d 2d 32 30 0d 2d 31 31 0d 2d
	!hex 35 0d 2d 37 0d 2b 38 0d 2b 35 0d 2b 31 39 0d 2d 33 0d 2d 31 34 0d
	!hex 2d 31 0d 2d 31 33 0d 2d 39 0d 2d 33 0d 2d 31 31 0d 2d 36 0d 2d 31
	!hex 39 0d 2b 34 0d 2d 31 0d 2d 32 0d 2b 31 37 0d 2d 31 39 0d 2b 38 0d
	!hex 2d 31 34 0d 2d 31 36 0d 2b 37 0d 2d 32 37 0d 2b 31 0d 2b 32 33 0d
	!hex 2b 35 0d 2b 34 0d 2d 33 0d 2d 32 0d 2b 32 33 0d 2d 32 30 0d 2d 32
	!hex 30 0d 2d 31 39 0d 2d 31 39 0d 2d 32 0d 2b 31 36 0d 2d 39 0d 2d 32
	!hex 36 0d 2b 37 0d 2b 32 33 0d 2d 31 38 0d 2d 31 36 0d 2d 39 0d 2d 32
	!hex 37 0d 2b 32 0d 2d 35 31 0d 2d 31 31 0d 2b 32 35 0d 2d 31 32 0d 2d
	!hex 39 0d 2d 33 32 0d 2d 35 38 0d 2d 31 38 0d 2d 31 31 0d 2d 38 0d 2d
	!hex 32 37 0d 2d 31 32 0d 2d 32 30 0d 2d 31 36 0d 2b 31 31 0d 2b 31 37
	!hex 0d 2b 35 0d 2b 34 31 0d 2b 37 32 0d 2b 32 39 0d 2d 32 31 35 0d 2d
	!hex 39 0d 2d 35 0d 2d 31 38 0d 2b 31 37 0d 2d 38 0d 2d 38 0d 2b 31 34
	!hex 0d 2b 31 35 0d 2b 32 31 0d 2d 35 0d 2d 33 30 0d 2d 31 39 0d 2b 37
	!hex 0d 2d 35 35 0d 2b 31 37 0d 2b 34 31 0d 2b 32 37 38 0d 2d 31 31 36
	!hex 35 0d 2d 36 31 35 33 30 0d 2b 31 36 0d 2b 37 0d 2b 31 34 0d 2d 36
	!hex 0d 2d 31 31 0d 2d 32 31 0d 2b 31 36 0d 2d 31 33 0d 2b 37 0d 2d 32
	!hex 34 0d 2b 31 30 0d 2b 32 0d 2d 31 38 0d 2d 31 31 0d 2d 37 0d 2b 31
	!hex 39 0d 2b 36 0d 2b 34 0d 2d 31 39 0d 2d 31 37 0d 2b 31 35 0d 2d 32
	!hex 31 0d 2b 31 37 0d 2d 31 0d 2d 34 0d 2d 31 35 0d 2b 34 0d 2b 31 33
	!hex 0d 2d 32 33 0d 2d 32 30 0d 2d 36 0d 2b 37 0d 2b 39 0d 2b 34 0d 2b
	!hex 31 31 0d 2d 39 0d 2b 31 31 0d 2b 31 33 0d 2d 36 0d 2b 32 31 0d 2d
	!hex 32 32 0d 2d 34 39 0d 2d 31 34 0d 2b 31 31 0d 2d 31 39 0d 2d 33 0d
	!hex 2d 32 32 0d 2b 32 36 0d 2d 35 0d 2b 37 0d 2b 32 31 0d 2d 31 34 0d
	!hex 2d 33 0d 2d 31 36 0d 2b 32 32 0d 2b 32 34 0d 2d 38 0d 2d 31 34 0d
	!hex 2b 34 36 0d 2d 34 0d 2b 31 33 0d 2d 34 0d 2b 36 30 0d 2b 31 0d 2b
	!hex 31 34 0d 2b 31 31 0d 2b 37 0d 2d 31 39 0d 2d 34 33 0d 2b 31 30 0d
	!hex 2b 35 0d 2b 33 31 0d 2b 32 37 0d 2d 31 38 35 0d 2d 33 38 0d 2d 37
	!hex 0d 2d 31 32 0d 2d 31 39 0d 2d 31 38 0d 2b 31 39 0d 2d 31 31 0d 2b
	!hex 31 32 0d 2b 33 0d 2d 31 0d 2b 31 30 0d 2b 32 0d 2d 32 31 0d 2b 32
	!hex 32 0d 2b 31 30 0d 2b 35 0d 2b 31 34 0d 2b 32 31 0d 2d 32 37 0d 2d
	!hex 31 31 0d 2b 36 0d 2d 39 0d 2d 31 34 0d 2b 31 36 0d 2b 35 0d 2b 31
	!hex 32 0d 2d 39 0d 2b 31 38 0d 2b 34 0d 2b 32 32 0d 2b 34 0d 2d 37 0d
	!hex 2d 37 0d 2d 33 36 0d 2d 34 33 0d 2d 31 34 0d 2d 31 39 0d 2b 34 0d
	!hex 2d 31 30 0d 2b 31 39 0d 2d 31 31 0d 2d 31 37 0d 2d 35 0d 2d 31 38
	!hex 0d 2d 36 0d 2d 31 31 0d 2d 39 0d 2b 32 32 0d 2b 31 39 0d 2d 31 38
	!hex 0d 2d 32 34 0d 2b 37 0d 2d 31 33 0d 2d 32 39 0d 2d 31 35 0d 2b 31
	!hex 34 0d 2d 31 0d 2d 32 36 0d 2b 38 0d 2d 32 30 0d 2d 32 31 0d 2b 31
	!hex 34 0d 2d 38 0d 2d 32 31 0d 2d 32 31 0d 2d 31 33 0d 2d 33 0d 2b 32
	!hex 0d 2b 32 0d 2b 37 0d 2d 36 0d 2d 31 37 0d 2d 36 0d 2b 38 0d 2d 34
	!hex 0d 2b 31 31 0d 2d 32 35 0d 2d 31 37 0d 2d 31 35 0d 2d 31 35 0d 2d
	!hex 34 0d 2d 31 31 0d 2d 34 0d 2b 31 37 0d 2d 38 0d 2b 31 0d 2d 31 33
	!hex 0d 2d 31 32 0d 2d 37 0d 2d 31 36 0d 2b 36 0d 2d 31 36 0d 2d 31 39
	!hex 0d 2b 32 0d 2b 35 0d 2d 31 0d 2d 31 34 0d 2d 31 0d 2b 33 0d 2b 35
	!hex 0d 2b 31 33 0d 2d 31 34 0d 2b 31 31 0d 2b 36 0d 2d 34 0d 2b 31 30
	!hex 0d 2d 32 30 0d 2d 31 34 0d 2d 31 34 0d 2d 31 34 0d 2d 36 0d 2b 38
	!hex 0d 2b 31 33 0d 2d 39 0d 2d 31 36 0d 2b 38 0d 2b 31 34 0d 2b 31 0d
	!hex 2d 31 36 0d 2d 31 34 0d 2d 38 0d 2b 34 0d 2d 31 35 0d 2b 31 34 0d
	!hex 2d 31 31 0d 2b 31 37 0d 2b 35 0d 2b 31 30 0d 2d 31 34 0d 2d 31 33
	!hex 0d 2d 31 0d 2d 32 0d 2d 31 33 0d 2b 31 38 0d 2d 31 31 0d 2d 35 0d
	!hex 2d 31 33 0d 2b 31 0d 2b 31 34 0d 2d 36 0d 2d 31 36 0d 2d 31 38 0d
	!hex 2b 31 32 0d 2b 37 0d 2b 31 0d 2d 37 0d 2d 38 0d 2b 32 0d 2d 34 0d
	!hex 2d 31 0d 2d 31 36 0d 2d 35 0d 2d 31 32 0d 2d 31 32 0d 2d 35 0d 2d
	!hex 31 32 0d 2d 35 0d 2d 31 37 0d 2b 32 30 0d 2b 36 0d 2b 31 31 0d 2d
	!hex 36 0d 2d 37 0d 2d 31 0d 2b 37 0d 2d 31 34 0d 2d 31 39 0d 2d 31 38
	!hex 0d 2b 31 36 0d 2d 37 0d 2d 38 0d 2b 31 0d 2b 34 0d 2d 31 30 0d 2b
	!hex 31 0d 2b 36 0d 2b 32 0d 2d 36 0d 2b 31 32 0d 2b 31 37 0d 2b 31 0d
	!hex 2b 35 0d 2b 31 39 0d 2d 31 31 0d 2b 31 32 0d 2d 36 0d 2d 32 0d 2d
	!hex 37 0d 2b 31 0d 2d 37 0d 2d 39 0d 2b 31 31 0d 2d 31 32 0d 2d 31 36
	!hex 0d 2b 37 0d 2b 38 0d 2d 31 32 0d 2d 31 32 0d 2d 35 0d 2b 31 0d 2d
	!hex 31 34 0d 2d 31 32 0d 2b 37 0d 2b 31 35 0d 2d 31 31 0d 2d 39 0d 2d
	!hex 39 0d 2d 31 31 0d 2b 31 37 0d 2d 31 0d 2d 31 39 0d 2b 31 35 0d 2d
	!hex 31 38 0d 2b 31 33 0d 2d 31 34 0d 2d 31 34 0d 2d 31 37 0d 2b 31 36
	!hex 0d 2b 31 37 0d 2d 31 33 0d 2b 33 31 0d 2b 31 33 0d 2d 31 36 0d 2b
	!hex 32 34 0d 2d 36 0d 2b 39 0d 2b 31 0d 2d 31 36 0d 2d 31 39 0d 2b 31
	!hex 32 0d 2d 31 39 0d 2b 31 38 0d 2b 31 37 0d 2b 32 37 0d 2b 31 31 0d
	!hex 2b 36 0d 2b 32 0d 2b 39 0d 2b 31 33 0d 2b 37 0d 2b 38 0d 2b 31 37
	!hex 0d 2b 31 37 0d 2b 33 0d 2b 31 30 0d 2b 37 0d 2b 32 30 0d 2b 31 30
	!hex 0d 2d 31 33 0d 2d 32 0d 2b 39 0d 2d 31 31 0d 2d 31 0d 2d 35 0d 2d
	!hex 31 31 0d 2b 31 30 0d 2b 32 39 0d 2d 39 0d 2d 31 37 0d 2d 37 0d 2d
	!hex 37 0d 2d 36 0d 2d 31 35 0d 2d 32 31 0d 2b 31 32 0d 2b 31 32 0d 2b
	!hex 32 0d 2b 32 0d 2d 31 37 0d 2d 36 0d 2b 39 0d 2d 31 32 0d 2b 31 34
	!hex 0d 2d 39 0d 2d 31 33 0d 2d 33 0d 2b 31 0d 2d 31 33 0d 2b 32 39 0d
	!hex 2b 37 0d 2d 31 31 0d 2b 35 0d 2b 31 36 0d 2d 32 37 0d 2b 32 34 0d
	!hex 2d 32 33 0d 2d 34 0d 2d 37 0d 2d 32 0d 2b 36 32 0d 2d 31 37 0d 2b
	!hex 33 38 0d 2b 39 0d 2b 31 30 0d 2b 34 0d 2b 32 31 0d 2b 32 39 0d 2d
	!hex 31 39 0d 2d 37 0d 2d 31 37 0d 2b 32 39 0d 2b 34 37 0d 2b 31 31 0d
	!hex 2d 32 0d 2d 31 37 0d 2b 34 0d 2b 32 35 0d 2b 31 38 0d 2b 31 34 0d
	!hex 2d 31 38 0d 2d 31 30 0d 2b 32 32 0d 2d 33 0d 2b 36 0d 2b 31 33 0d
	!hex 2b 31 31 0d 2b 32 31 0d 2b 31 39 0d 2d 36 0d 2d 33 0d 2b 31 37 0d
	!hex 2d 32 36 0d 2b 35 0d 2b 31 38 0d 2d 36 0d 2b 31 37 0d 2d 31 35 0d
	!hex 2d 31 31 0d 2d 31 31 0d 2d 35 0d 2d 31 39 0d 2d 33 0d 2b 31 32 0d
	!hex 2d 31 39 0d 2d 31 39 0d 2b 31 32 0d 2d 31 35 0d 2d 31 33 0d 2b 37
	!hex 0d 2b 35 0d 2d 31 38 0d 2d 31 0d 2d 31 31 0d 2d 33 31 0d 2b 38 0d
	!hex 2b 35 0d 2b 31 35 0d 2d 32 0d 2b 31 33 0d 2d 31 32 0d 2d 31 31 0d
	!hex 2b 33 37 0d 2b 33 33 0d 2b 39 0d 2b 31 31 0d 2d 36 0d 2d 31 30 0d
	!hex 2d 31 39 0d 2d 31 33 0d 2b 33 35 0d 2b 34 32 0d 2d 33 38 0d 2b 31
	!hex 32 31 0d 2b 39 0d 2d 35 31 0d 2d 33 31 0d 2b 31 34 0d 2b 36 39 0d
	!hex 2b 36 0d 2b 36 0d 2b 31 30 39 0d 2d 31 35 32 0d 2d 32 32 36 0d 2b
	!hex 32 35 0d 2d 34 36 0d 2d 31 31 0d 2b 34 34 0d 2d 32 31 38 0d 2d 31
	!hex 32 0d 2b 31 37 0d 2b 32 39 0d 2d 37 0d 2b 32 0d 2b 31 31 0d 2d 38
	!hex 39 0d 2b 32 39 30 0d 2d 31 32 37 0d 2d 31 35 32 0d 2b 31 31 0d 2d
	!hex 35 0d 2d 39 35 30 0d 2d 36 31 30 32 37 0d 2d 36 0d 2d 37 0d 2d 32
	!hex 0d 2d 31 33 0d 2b 31 34 0d 2d 38 0d 2b 31 38 0d 2b 31 38 0d 2d 33
	!hex 31 0d 2d 31 32 0d 2d 31 31 0d 2b 31 39 0d 2d 31 36 0d 2d 32 30 0d
	!hex 2d 32 0d 2b 31 30 0d 2b 31 39 0d 2d 31 32 0d 2d 32 31 0d 2d 31 33
	!hex 0d 2b 34 0d 2b 34 0d 2d 31 37 0d 2b 32 0d 2d 33 0d 2d 31 32 0d 2b
	!hex 32 30 0d 2b 31 0d 2b 31 31 0d 2b 38 0d 2b 32 30 0d 2d 31 33 0d 2d
	!hex 33 38 0d 2d 32 0d 2d 38 0d 2d 35 0d 2b 31 36 0d 2d 37 0d 2d 32 32
	!hex 0d 2d 37 0d 2b 36 0d 2d 31 34 0d 2d 39 0d 2d 31 34 0d 2d 34 0d 2d
	!hex 31 38 0d 2b 31 37 0d 2d 31 30 0d 2b 31 34 0d 2b 31 30 0d 2d 37 0d
	!hex 2b 31 30 0d 2d 36 0d 2b 31 32 35 36 34 38 0d 00
inputend
; storage is a bit array where 1 bit = 1 integer, a seen value has the
; corresponding bit set to 1
storage = (inputend+255)/256*256 ; start on first byte of next page
