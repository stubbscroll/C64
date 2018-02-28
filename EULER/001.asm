; solution to project euler #1
; https://projecteuler.net/problem=1
; algorithm: loop from 1 to 999, keep two counters of size 3 and 5 to keep
; track of multiples. the counter variables count downwards, and when they are
; 0 we have a multiple of the respective number

	CHROUT = $ffd2

	MAX = 999    ; check up to (and including) this number

	count3 = $fe ; counters for multiples
	count5 = $ff
	n = $fc      ; loop variable (2 bytes)
	ans = $f9    ; answer (3 bytes)

	!to "001.prg",cbm
	* = $0801
	; sys 2061
	!byte $0b, $08, $0a, $00, $9e, $32, $30, $36, $31, $00, $00, $00

	sei
	ldx #0       ; initialize variables: n=1, ans=0,
	stx ans+0    ; count3=2, count5=4
	stx ans+1
	stx ans+2
	stx n+1
	inx
	stx n+0
	inx
	stx count3
	lda #4
	sta count5
loop	; check if n is a multiple of 3 or 5
	lda count3
	beq ismul
	lda count5
	bne notmul
ismul	; n is a multiple of 3 or 5, add it to answer
	lda ans+0
	clc
	adc n+0
	sta ans+0
	lda ans+1
	adc n+1
	sta ans+1
	bcc +
	inc ans+2
+
notmul	; decrease counters, and wrap around if negative
	dec count3
	bpl +
	lda #2
	sta count3
+	dec count5
	bpl +
	lda #4
	sta count5
+	; increase n
	inc n+0
	bne +
	inc n+1
+	; loop while n<=MAX
	lda n
	cmp #<MAX+1
	lda n+1
	sbc #>MAX+1
	bcc loop
	; convert answer to decimal and print it
	lda ans+0
	sta in24+0
	lda ans+1
	sta in24+1
	lda ans+2
	sta in24+2
	jsr int24tobcd
	cli
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
