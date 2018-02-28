; solution to project euler #2
; https://projecteuler.net/problem=2
; algorithm: visit each fibonacci number up to 4000000, calculate the sum of
; all the even ones

	CHROUT = $ffd2

	MAX = 4000001
	f1 = $f7       ; 3 successive terms of the fibonacci sequence
	f2 = $fa       ; (3 bytes each)
	f3 = $fd
	ans = $03fd    ; sum (3 bytes is sufficient)

	!to "002.prg",cbm
	* = $0801
	; sys 2061
	!byte $0b, $08, $0a, $00, $9e, $32, $30, $36, $31, $00, $00, $00

	sei
	; set the 3 first terms to (undefined), 1, 2
	ldx #0
	stx f2+1
	stx f2+2
	stx f3+1
	stx f3+2
	stx ans+0
	stx ans+1
	stx ans+2
	inx
	stx f2+0
	stx f3+0

loop	; the number we want to check is f3, check if it's even
	lda f3
	and #1
	bne +
	; add it to answer
	clc
	lda ans+0
	adc f3+0
	sta ans+0
	lda ans+1
	adc f3+1
	sta ans+1
	lda ans+2
	adc f3+2
	sta ans+2
+	; calculate next fibonacci term: f1=f2, f2=f3, f3=f1+f2
	ldx #2
-	lda f2,x
	sta f1,x
	lda f3,x
	sta f2,x
	dex
	bpl -
	clc
	lda f1+0
	adc f2+0
	sta f3+0
	lda f1+1
	adc f2+1
	sta f3+1
	lda f1+2
	adc f2+2
	sta f3+2
	; are we over the limit?
	lda f3+0
	cmp #<MAX
	lda f3+1
	sbc #>MAX
	lda f3+2
	sbc #^MAX ; reminder to self: ^ is the "bank byte" of an int
	bcc loop
	; convert answer to bcd
	lda ans+0
	sta in24+0
	lda ans+1
	sta in24+1
	lda ans+2
	sta in24+2
	jsr int24tobcd
	; print answer
	ldx #<out32
	ldy #>out32
	lda #4
	jsr printbcd
	lda #$0d
	jmp CHROUT

	; convert unsigned 24-bit int to 32-bit (8-digit) bcd
	; input value: expected in in24
	; output value: written to out32
	; warning, don't run with an interrupt that doesn't preserve decimal
	; flag, such as the KERNAL
	; inspired by http://codebase64.org/doku.php?id=base:more_hexadecimal_to_decimal_conversion
int24tobcd ldx #0
	stx out32+0
	stx out32+1
	stx out32+2
	stx out32+3
	ldx #23
	sed
-	asl in24+0
	rol in24+1
	rol in24+2
	lda out32+0
	adc out32+0
	sta out32+0
	lda out32+1
	adc out32+1
	sta out32+1
	lda out32+2
	adc out32+2
	sta out32+2
	lda out32+3
	adc out32+3
	sta out32+3
	dex
	bpl -
	cld
	rts
in24	!byte 0,0,0
out32	!byte 0,0,0,0

	; print bcd number to CHROUT, don't output leading zeroes
	; x,y: pointer to number
	; a: length of number (in bytes)
printbcd 
	stx val+1
	sty val+2
	tax
	dex
	ldy #0 ; y=0: zeroes are still leading
-
val	lda $0000,x
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
