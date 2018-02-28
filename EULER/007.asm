; solution to project euler #7
; https://projecteuler.net/problem=7
; algorithm: sieve of eratosthenes. by the prime number theorem, we have pi(n)
; approximately equal to N/log(N), which means that if we solve 10001=N/log(N)
; for N we get N approximately equal to 116684, so setting sieve size to 120000
; should be safe enough for finding the 10001th prime.
; this is a naive implementation which includes even numbers, but with some
; optimizations regarding where we (don't) loop.
; this one took 34 seconds, not very impressive

	CHROUT = $ffd2
	N = 10001
	LIM = 120832 ; divisible by 8*256 which is good

	!to "007.prg",cbm
	* = $0801
	; sys start
	!byte $0b, $08, $0a, $00, $9e, 48+start/1000%10, 48+start/100%10, 48+start/10%10, 48+start%10, $00, $00, $00

; multiply two unsigned 16-bit integers and get 32-bit product
; input: mul1, mul2 (2 bytes each)
; output: product (4 bytes)
; clobbered: a,x,mul1
; better performance is achieved by ensuring that mul1 has fewer bits set than
; mul2
; taken from http://codebase64.org/doku.php?id=base:16bit_multiplication_32-bit_product

	mul1 = $f7    ; 2 bytes
	mul2 = $f9    ; 2 bytes
	product = $fb ; 4 bytes

mul16	lda #0
	sta product+2 ; clear upper bits of product
	sta product+3
	ldx #16       ; set binary count to 16
-	lsr mul1+1    ; divide multiplier by 2
	ror mul1+0
	bcc +
	lda product+2 ; get upper half of product and add multiplicand
	clc
	adc mul2+0
	sta product+2
	lda product+3
	adc mul2+1
+	ror           ; rotate partial product
	sta product+3
	ror product+2
	ror product+1
	ror product+0
	dex
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
	rts
printchar cpy #0
	bne +
	cmp #0
	beq ++
	ldy #1 ; y=1: print all digits from here
+	ora #$30
	jmp CHROUT
++	rts

; end of generic routines, here come subroutines related to this task

; given an index a,x,y (=a+x*256+y*65536) which represents an integer,
; return 0 if the integer at this index is non-prime
; return non-zero of the integer at this index is prime

sievevar = $fd ; 3 bytes, only 2 used after dividing by 8
orvar = $fc
ortable	!byte $1,$2,$4,$8,$10,$20,$40,$80
andtable !byte $fe,$fd,$fb,$f7,$ef,$df,$bf,$7f

getsieve jsr findbit
	ldy #0
	lda (sievevar),y
	ldx orvar
	and ortable,x
	rts

; given an index a,x,y (=a+x*256+y*65536) which represents an integer,
; clear bit at this index, marking the integer as non-prime
clearsieve jsr findbit
	ldy #0
	lda (sievevar),y
	ldx orvar
	and andtable,x
	sta (sievevar),y
	rts

; find address of correct bit, set in sievevar+orvar
findbit sta sievevar+0
	stx sievevar+1
	sty sievevar+2
	and #$07
	sta orvar
	; divide by 8 to find correct byte
	ldx #2
	lda sievevar+1
-	lsr sievevar+2
	ror
	ror sievevar+0
	dex
	bpl -
	clc
	adc sieve+1
	sta sievevar+1
	; sievevar now holds pointer to byte,
	; and orvar is pointer to bitmask for the correct bit
	rts

i	!byte 0,0,0 ; sieve loop index
i2	!byte 0,0   ; step size in inner loop
j	!byte 0,0,0 ; index for inner loop when marking as non-prime in sieve

sieveptr = $fe ; pointer to stuff we do in sieve

sieve	!byte 0,0   ; pointer to start of sieve
size	!byte 0,0,0 ; size of sieve in bytes, 3rd byte only used in init

; start of main routine

start	sei
	; find first free address after the code that's page-aligned
	ldy #>end
	ldx #<end
	beq +
	ldx #0
	iny
+	stx sieve+0
	sty sieve+1
	; calculate sieve size in bytes
	lda #<LIM
	ldx #>LIM
	ldy #^LIM
	stx size+1
	sty size+2
	; divide LIM by 8 to find size
	lsr size+2
	ror size+1
	ror
	lsr size+2
	ror size+1
	ror
	lsr size+2
	ror size+1
	ror
	sta size+0

	; initialize sieve: set all numbers to prime except 0 and 1 and all
	; multiples of 2 larger than 2
	ldx #0
	ldy sieve+1
	stx sieveptr+0
	sty sieveptr+1
	ldx size+1
	ldy #0
	lda #$ac ; mark 2 3 5 7 as primes
	sta (sieveptr),y
	iny
	lda #$aa ; mark all remaining odd integers as prime for now
-	sta (sieveptr),y
	iny
	bne -
	inc sieveptr+1
	dex
	bne -

	; loop over all primes from i to i*i<LIM starting from i=3
	ldx #3
	ldy #0
	stx i+0
	sty i+1
	sty i+2
loop	lda i+0
	ldx i+1
	ldy i+2
	jsr getsieve
	bne prime
	; not prime, increase i
loopinc	inc i+0
	bne loop
	inc i+1
	bne loop
	inc i+2
	bne loop
prime	; we found a prime: now mark all multiples of this number as non-prime
	; start at i*i since all non-primes between i+1 and i*i-1 have smaller
	; factors than i and were already marked in previous iterations
	ldx i+0 ; we can safely ignore the third byte of i, since the loop
	ldy i+1 ; terminates long before overflow from multiplication can happen
	stx mul1+0
	sty mul1+1
	stx mul2+0
	sty mul2+1
	jsr mul16
	; check if i*i>=LIM, in which case we can terminate the sieving process
	lda product+0
	cmp #<LIM
	lda product+1
	sbc #>LIM
	lda product+2
	sbc #^LIM
	bcs answer  ; terminate, jump to answer routine
	; from here, mark all multiples of 2i starting with i*i. stepsize 2i
	; because the values stepped over are multiples of 2
	; store 2i for easier stepping later
	clc
	lda i+0
	adc i+0
	sta i2+0
	lda i+1
	adc i+1
	sta i2+1
	; set j=i*i (copy from multiplication we just did)
	lda product+0
	ldx product+1
	ldy product+2
	sta j+0
	stx j+1
	sty j+2
	; give lifesign after each iteration of outer loop
	lda #$2e
	jsr CHROUT

loop2	; clear j-th bit in sieve
	lda j+0
	ldx j+1
	ldy j+2
	jsr clearsieve
	; add 2i
	clc
	lda j+0
	adc i2+0
	sta j+0
	lda j+1
	adc i2+1
	sta j+1
	bcc +
	inc j+2
+	; stop inner loop if j>=LIM
	lda j+0
	cmp #<LIM
	lda j+1
	sbc #>LIM
	lda j+2
	sbc #^LIM
	bcc loop2
	jmp loopinc ; go back to outer loop

answer	; obtain answer: step through the sieve and find the 10001th prime.
	; here, i is the loop index and j is the prime counter
	lda #$0d
	jsr CHROUT
	lda #0
	sta i+0
	sta i+1
	sta i+2
	sta j+0
	sta j+1
	; loop over i until we found 10001 primes
loop3	lda i+0
	ldx i+1
	ldy i+2
	; we could get rid of the subroutine and only increase a regular pointer
	; and process/count entire bytes at once (for an expected speedup of
	; several seconds), but i'm lazy and use the machinery we already made
	; for random access
	jsr getsieve
	beq noprime
	; i is prime, increase j
	inc j+0
	bne +
	inc j+1
+	; if j=10001, we won
	lda j+0
	cmp #<N
	bne noprime
	lda j+1
	cmp #>N
	bne noprime
	; output the answer, which is i
	ldx #2
-	lda i,x
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
noprime	inc i+0
	bne loop3
	inc i+1
	bne loop3
	inc i+2
	bne loop3
	; execution never reaches here

end	; place sieve on start of next page from this address
