; solution to project euler #29
; https://projecteuler.net/problem=29
; algorithm: partition the bases into equivalence classes where bases that are
; powers are reduced to their actual base. then process each class separately.
; within each class, we generate all exponents from the actual base and count
; the unique exponents.
; after that, we cache the answer for each max power so we only have to
; calculate it once. in addition, for a>10 (that's not already a power of a
; smaller base) we know that the max power is 1 so we can just add 99 to the
; answer.
; runtime: 0.05 seconds

	CHROUT = $ffd2

	!to "029.prg",cbm
	* = $0801
	; sys start
	!byte $0b, $08, $0a, $00, $9e, 48+start/1000%10, 48+start/100%10, 48+start/10%10, 48+start%10, $00, $00, $00

; multiply two unsigned 8-bit integers and get 16-bit product
; inputs: mul1, mul2
; output: product
; clobbered: a,x,mul1
; shortened from http://codebase64.org/doku.php?id=base:16bit_multiplication_32-bit_product

mul1 = $fe ; 1 byte
mul2 = $ff ; 1 byte
product = $fc ; 2 bytes

mul8	lda #0
	ldx #8
-	lsr mul1
	bcc +
	clc
	adc mul2
+	ror
	ror product+0
	dex
	bne -
	sta product+1
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

	; program entry point

start	sei
	; initialize baseid
	ldx #0
	txa
-	sta baseid,x
	sta basepow,x
	inx
	cpx #101
	bne -
	; set cached answers to 0
	ldx #13
-	sta cachelo,x
	dex
	bpl -
	; loop a from 2 to 10 (inclusive) and generate all powers
	lda #2
	sta a
loop	ldx a
	stx product+0
	lda baseid,x
	bne nexta ; a is already power, skip
	ldy #1
loop2	ldx a
	stx mul1
	txa
	ldx product+0
	sta baseid,x
	tya
	sta basepow,x
	stx mul2
	jsr mul8
	iny
	; if product>100, stop
	lda product+1
	bne nexta
	lda product+0
	cmp #101
	bcc loop2
nexta	; try next a
	inc a
	lda a
	cmp #11
	bne loop
	; fill in remaining ids
	ldx a
loop3	lda baseid,x
	bne +
	txa
	sta baseid,x
	lda #1
	sta basepow,x
+	inx
	cpx #101
	bne loop3

	; loop through all equivalence classes from 2 to 100
	lda #2
	sta a
	lda #0
	sta answer+0
	sta answer+1
loopa	ldx a
	lda basepow,x ; only consider base that isn't a power
	cmp #1
	beq +
	jmp nexta2
+	cpx #11
	bcc recheck
	; base a>=11 that isn't a power: add 99
	lda answer+0
	clc
	adc #99
	sta answer+0
	bcc +
	inc answer+1
+	jmp nexta2
recheck	; find highest power
	ldx #2
-	lda baseid,x
	cmp a
	bne +
	; matching base, store max power in y
	ldy basepow,x
+	inx
	cpx #101
	bne -
	; is answer cached?
	lda cachelo,y
	ora cachehi,y
	beq nocache
	lda answer+0
	clc
	adc cachelo,y
	sta answer+0
	lda answer+1
	adc cachehi,y
	sta answer+1
	jmp nexta2
nocache	sty maxpow
	; answer for base a not cached, calculate it
	; initialize bitcount array to have entries 2-100 set to 1, the rest
	; to 0
	lda #$fc
	sta bitcount+0
	ldx #1
	lda #$ff
-	sta bitcount,x
	inx
	cpx #101/8
	bne -
	; set 96-100 to 1
	lda #$1f
	sta bitcount,x
	inx
	; set the rest to 0
	lda #0
-	sta bitcount,x
	inx
	cpx #608/8
	bne -
	; loop over powers from 2 to maxpow
	lda #2
	sta curpow
	ldx #0
	stx curans+0
	stx curans+1
powloop	; write 99 values
	lda #99
	sta cnt
	lda curpow ; start looping at curpow*2
	asl
	sta exp+0
	lda #0
	sta exp+1
powloop2 ; set bit in bitcount array for exponent
	jsr setbit
	lda exp+0
	clc
	adc curpow
	sta exp+0
	bcc +
	inc exp+1
+	dec cnt
	bne powloop2
	; next base power in equivalence class
	ldx curpow
	cpx maxpow
	beq powdone
	inc curpow
	jmp powloop
powdone	; count number of set bits, count each nybble simultaneously
	ldx #0
-	lda bitcount,x
	and #$0f
	tay
	clc
	lda curans+0
	adc bc,y
	sta curans+0
	bcc +
	inc curans+1
+	lda bitcount,x
	lsr
	lsr
	lsr
	lsr
	tay
	clc
	lda curans+0
	adc bc,y
	sta curans+0
	bcc +
	inc curans+1
+	inx
	cpx #608/8
	bne -
	ldx maxpow
	; add to answer
	clc
	lda answer+0
	adc curans+0
	sta answer+0
	lda answer+1
	adc curans+1
	sta answer+1
	; add to cache
	ldx curpow
	lda curans+0
	sta cachelo,x
	lda curans+1
	sta cachehi,x
nexta2	; next a
	inc a
	lda a
	cmp #101
	beq +
	jmp loopa
+	; we are done, print answer
	ldx answer+0
	ldy answer+1
	lda #0
	stx inbcd+0
	sty inbcd+1
	sta inbcd+2
	jsr int24tobcd
	ldx #<outbcd
	ldy #>outbcd
	lda #4
	jsr printbcd
	lda #$0d
	jmp CHROUT

	; set bit at index exp (2 bytes)
setbit	lda exp+0
	sta temp
	and #$07
	tax
	lda exp+1
	lsr
	ror temp
	lsr
	ror temp
	lsr
	ror temp
	ldy temp
	lda bitcount,y
	ora ortable,x
	sta bitcount,y
	rts
temp	!byte 0

curans	!byte 0,0 ; number of different exponent for equivalence class
ortable	!byte 1,2,4,8,16,32,64,128
exp	!byte 0,0 ; loop variable for exponent
cnt	!byte 0
curpow	!byte 0 ; loop variable for base power
maxpow	!byte 0 ; largest base power for equivalence class
answer	!byte 0,0
a	!byte 0
bc	!byte 0,1,1,2,1,2,2,3,1,2,2,3,2,3,3,4 ; number of bits in each nybble
cachelo	!byte 0,0,0,0,0,0,0 ; cached answers for each max power up to 6
cachehi	!byte 0,0,0,0,0,0,0 ; high byte of cached answers

	; table with equivalence classes, if a!=b and id[a]==id[b], a and b
	; belong to the same equivalence class
baseid = (*+255)/256*256 ; start on next page
	; the power of each base relative to the representant of the equivalence
	; class. example, pow[2]=1 and pow[8]=3 since 2^3=8.
basepow = baseid+101
bitpre = basepow+101 ; end of basepow
bitcount=(bitpre+255)/256*256 ; start on next page from bitpre
