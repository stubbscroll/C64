; advent of code 2018 day 1
; https://adventofcode.com/2018/day/1
; find the sum of a list of integers
; lazy solution, each digit is a byte

	CHROUT = $ffd2

	!to "01a.prg",cbm
	* = $0801
	; sys start
	!byte $0b, $08, $0a, $00, $9e, 48+start/1000%10, 48+start/100%10, 48+start/10%10, 48+start%10, $00, $00, $00

	len = 8 ; number of digits
	zp = $fe
	eos = $fd ; pointer to end of string

start	ldx #len-1
	lda #0
-	sta answer,x
	sta term,x
	dex
	bpl -
	ldx #<input
	ldy #>input
	stx zp+0
	sty zp+1
	; main loop: read the next line of the "text file"
	; each line begins with + or -, followed by an integer
loop	ldy #0
	lda (zp),y
	beq printanswer
	cmp #'-'
	beq minus
	; read a positive integer
	; find linebreak, and read in reverse order
	jsr readint
	; add term to answer
	ldx #len-1
-	clc
	lda answer,x
	adc term,x
	sta answer,x
	dex
	bpl -
	; fix overflow
	ldx #len-1
-	lda answer,x
	cmp #10
	bcc +
	sbc #10
	sta answer,x
	inc answer-1,x
+	dex
	bpl -
	bmi nextnum

minus	; read a negative integer
	jsr readint
	; subtract term from answer
	ldx #len-1
-	sec
	lda answer,x
	sbc term,x
	sta answer,x
	dex
	bpl -
	; fix underflow
	ldx #len-1
-	lda answer,x
	bpl +
	clc
	adc #10
	sta answer,x
	dec answer-1,x
+	dex
	bpl -

nextnum	lda eos
	sec ; add eos+1
	adc zp+0
	sta zp+0
	bcc loop
	inc zp+1
	bne loop

printanswer	; check sign of answer
	lda answer
	cmp #5
	bcs minus2
	; remove leading zeroes
	ldx #0
-	lda answer,x
	bne plus
	inx
	cpx #len-1
	bne -
plus
-	lda answer,x
	ora #$30
	jsr CHROUT
	inx
	cpx #len
	bne -
	lda #$0d
	jmp CHROUT
minus2	; negative answer
	lda #'-'
	jsr CHROUT
	; answer = 999...9 - answer
	ldx #7
-	lda #9
	sec
	sbc answer,x
	sta answer,x
	dex
	bpl -
	; add 1
	inc answer+len-1
	ldx #len-1
-	lda answer,x
	cmp #10
	bne printanswer
	lda #0
	sta answer,x
	inc answer-1,x
	dex
	bne -
	beq printanswer

readint	ldy #0
-	lda (zp),y
	beq found
	cmp #$0d
	beq found
	iny
	sty eos ; store y for later, it's where the string ends
	bne -
found	ldx #len-1
-	dey
	lda (zp),y
	cmp #$30
	bcc +
	and #$0f
	sta term,x
	dex
	bcs -
+	lda #0
-	sta term,x
	dex
	bpl -
	rts

	!byte 0 ;dummy byte to catch carry adjustments for most significant digit
answer	!byte 0,0,0,0,0,0,0,0
term	!byte 0,0,0,0,0,0,0,0

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
