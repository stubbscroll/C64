; solution to project euler #28
; https://projecteuler.net/problem=28
; algorithm: start at 1, add 2, 2, 2, 2, add 4, 4, 4, 4, ...,
; add 1000 1000 1000 1000. after each addition add to sum.
; runtime: 0.033 seconds

	CHROUT = $ffd2

	!to "028.prg",cbm
	* = $0801
	; sys start
	!byte $0b, $08, $0a, $00, $9e, 48+start/1000%10, 48+start/100%10, 48+start/10%10, 48+start%10, $00, $00, $00

; convert unsigned 32-bit int to 40-bit (10-digit) bcd
; input value: inbcd
; output value: outbcd
; clobbered: a,x
; warning, don't run with an interrupt that doesn't handle decimal flag
; properly, such as the KERNAL
; inspired by http://codebase64.org/doku.php?id=base:more_hexadecimal_to_decimal_conversion
int32tobcd ldx #0
	stx outbcd+0
	stx outbcd+1
	stx outbcd+2
	stx outbcd+3
	stx outbcd+4
	ldx #31
	sed
-	asl inbcd+0
	rol inbcd+1
	rol inbcd+2
	rol inbcd+3
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
	dex
	bpl -
	cld
	rts
inbcd	!byte 0,0,0,0
outbcd	!byte 0,0,0,0,0

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

start	sei
	; reset answer
	ldx #8
	lda #0
-	sta add,x
	dex
	bpl -
	; loop
	lda #1
	sta term
	sta answer
	lda #2
	sta add
loop	; add "add" to term 4 times
	jsr addterm
	jsr addterm
	jsr addterm
	jsr addterm
	; add 2 to add
	inc add+0
	inc add+0
	bne +
	inc add+1
+	; stop if add>1000
	lda add+0
	cmp #<1001
	lda add+1
	sbc #>1001
	bcc loop
;	done, print answer
	ldx #3
-	lda answer,x
	sta inbcd,x
	dex
	bpl -
	jsr int32tobcd
	ldx #<outbcd
	ldy #>outbcd
	lda #5
	jsr printbcd
	lda #$0d
	jmp CHROUT

addterm	clc
	lda term+0
	adc add+0
	sta term+0
	lda term+1
	adc add+1
	sta term+1
	bcc +
	inc term+2
+	; add term to answer
	clc
	lda answer+0
	adc term+0
	sta answer+0
	lda answer+1
	adc term+1
	sta answer+1
	lda answer+2
	adc term+2
	sta answer+2
	bcc +
	inc answer+3
+	rts

add	!byte 0,0
term	!byte 0,0,0 ; 1001*1001 spiral reaches a bit over 1 million
answer	!byte 0,0,0,0 ; upper bound: 4*500*1001*1001 fits in 4 bytes
