; advent of code 2018 day 4, part 1
; https://adventofcode.com/2018/day/4
; algorithm: first, sort the input (actually very difficult). then loop
; through all sleep intervals and sum the number of minutes each guard sleeps.
; when we've found the guard who sleeps the most, loop through all sleep
; intervals again and count how many times he sleeps per minute. take the max
; to find this minute
; runtime: 9 seconds

	CHROUT = $ffd2

	!to "04a.prg",cbm
	* = $0801
	; sys start
	!byte $0b, $08, $0a, $00, $9e, 48+start/1000%10, 48+start/100%10, 48+start/10%10, 48+start%10, $00, $00, $00

	zp1 = $fe
	temp = $02

	zp2 = $fc      ; alias to the below name for easier coding
	inputend = zp2 ; address where the converted input ends

	guard = $57    ; page where guard minute sleep counter starts
	gptr1 = $58    ; pointer to low byte of guard sleep counter
	gptr2 = $5a    ; pointer to high byte
	best = $5c     ; best value so far (most sleep, minute most asleep)
	bestid = $5e   ; guard with best value
	bestm = $60    ; minute number with best value

	maxguard = 16  ; max guard id: this*256

; multiply two unsigned 16-bit integers and get 32-bit product
; input: mul1, mul2 (2 bytes each)
; output: product (4 bytes)
; clobbered: a,x,mul1
; better performance is achieved by ensuring that mul1 has fewer bits set than
; mul2
; taken from http://codebase64.org/doku.php?id=base:16bit_multiplication_32-bit_product

mul1z	!byte 0,0
mul2z	!byte 0,0
productz !byte 0,0

mul16	lda #0
	sta productz+2 ; clear upper bits of product
	sta productz+3
	ldx #16       ; set binary count to 16
-	lsr mul1z+1    ; divide multiplier by 2
	ror mul1z+0
	bcc +
	lda productz+2 ; get upper half of product and add multiplicand
	clc
	adc mul2z+0
	sta productz+2
	lda productz+3
	adc mul2z+1
+	ror           ; rotate partial product
	sta productz+3
	ror productz+2
	ror productz+1
	ror productz+0
	dex
	bne -
	rts

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

	; start of sort routine!

	; zeropage variables for sort
	wsize = $57  ; window size
	zp3 = $59    ; list 1 (to be read from)
	zp4 = $5b    ; list 2 (to be read from)
	zp3end = $5d ; end of zp3
	zp4end = $5f ; end of zp4
	size = $f7   ; size of a record (1 byte)
	sstart = $f8 ; start of data to be sorted
	send = $fa   ; end of data to be sorted
	zi = $61     ; loop variable
	zi2 = $69    ; backup of zi
	zt = $63     ; temp variables
	zt2 = $65
	zt3 = $67

	; compare 4-bit big endian (warning) ints at zp3 and zp4
	; (easy to change into little endian if needed)
	; returns C=1 if zp3 >= zp4
	; clobbers: a, y
comp4	ldy #3
	lda (zp3),y
	cmp (zp4),y
	dey
	lda (zp3),y
	sbc (zp4),y
	dey
	lda (zp3),y
	sbc (zp4),y
	dey
	lda (zp3),y
	sbc (zp4),y
	rts

	; non-recursive merge sort (doesn't use stack)
	; it's not in-place, so temp memory of equal size to the data to be
	; sorted is needed! temp memory starts at the address send
	; input: sstart,send (start and end addresses for data to be sorted)
	;        a: record size
	; output: the list is sorted
	; sort chunks of 2, 4, 8, 16, ..., 2^n elements
	; sort of hard-coded to our data. the key is 4 bytes, the attached data
	; is 4 more bytes
sort	sta size
	sta wsize+0
	lda #0
	sta wsize+1
sinit	; do multiple passes until wsize >= size of list
	; init outer loop
	ldx sstart+0
	ldy sstart+1
	stx zi+0
	sty zi+1
sloop	; start of outer loop iteration
	; we're done if zi+wsize >= send
	lda zi+0
	clc
	adc wsize+0
	sta zt+0
	lda zi+1
	adc wsize+1
	sta zt+1
	lda zt+0
	cmp send+0
	lda zt+1
	sbc send+1
	bcc +
	jmp sloopend
+	; grab the next 2*wsize bytes from zi and make 2 lists of length wsize
	; (or less if end-of-data occurs)
	; store old zi
	ldx zi+0
	ldy zi+1
	stx zi2+0
	sty zi2+1
	; make list 1
	ldx send+0
	ldy send+1
	stx zt2+0
	sty zt2+1
	stx zp3+0
	sty zp3+1
	ldx wsize+0
	ldy wsize+1
	stx zt+0
	sty zt+1
	jsr copylist
	ldx zt2+0
	ldy zt2+1
	stx zp3end+0
	sty zp3end+1
	; make list 2
	; continue writing to zt2
	stx zp4+0
	sty zp4+1
	; reduce wsize if we would read past the end of the data
	; check if zi+wsize is larger than send
	; calculate zt = zi+wsize
	lda zi+0
	clc
	adc wsize+0
	sta zt+0
	lda zi+1
	adc wsize+1
	sta zt+1
	lda send+0
	cmp zt+0
	lda send+1
	sbc zt+1
	bcs +
	; zt2+wsize >= send, reduce zt
	; set zt (number of bytes to copy) to send - zi
	lda send+0
	sec
	sbc zi+0
	sta zt+0
	lda send+1
	sbc zi+1
	sta zt+1
	jmp ++
+	; we didn't reach end of data, use wsize
	ldx wsize+0
	ldy wsize+1
	stx zt+0
	sty zt+1
++	jsr copylist
	ldx zt2+0
	ldy zt2+1
	stx zp4end+0
	sty zp4end+1
	nop
	; merge step! we have two lists, going from (zp3, zp3end) and
	; (zp4, zp4end) respectively. merge these and make a sorted
	; sublist that starts at zi2
	; merge without sentinel (unfortunately) to make the routine as
	; general-purpose as possible, to allow the element ff ff ff ff
mloop	; merge loop! we're done when zi2 == zi
	lda wsize+0 ; start of unneeded code
	cmp #8
	beq +
	nop ; good place for breakpoint. end of unneeded code
+	lda zi2+0
	cmp zi+0
	bne +
	lda zi2+1
	cmp zi+1
	beq mdone ; merge done
	; take the smallest element from the lists
	; special cases first: if one of the lists are exhausted, copy from
	; the other list
	; check if list 1 is empty
+	lda zp3+0
	cmp zp3end+0
	bne +
	lda zp3+1
	cmp zp3end+1
	beq mcopy2 ; list 1 exhausted, copy from list 2
+	lda zp4+0
	cmp zp4end+0
	bne +
	lda zp4+1
	cmp zp4end+1
	beq mcopy1 ; list 2 exhausted, copy from list 1
	; compare and take the smallest
+	jsr comp4
	bcs mcopy2 ; C=1: element in list 2 is smalest

mcopy1	; copy from list 1
	ldy #0
-	lda (zp3),y
	sta (zi2),y
	iny
	cpy size
	bne -
	; advance zp3
	tya
	clc
	adc zp3+0
	sta zp3+0
	bcc +
	inc zp3+1
+	; advance zi2
madv	tya
	clc
	adc zi2+0
	sta zi2+0
	bcc mloop
	inc zi2+1
	bne mloop

mcopy2	; copy from list 2
	ldy #0
-	lda (zp4),y
	sta (zi2),y
	iny
	cpy size
	bne -
	; advance zp4
	tya
	clc
	adc zp4+0
	sta zp4+0
	bcc madv
	inc zp4+1
	bne madv

mdone	; merge step done, proceed to next chunk of elements
	jmp sloop

sloopend ; we merged all chunks of size wsize*2.
	; double wsize and do another iteration
	asl wsize+0
	rol wsize+1
	; if wsize >= send-sstart, we are done
	lda send+0
	sec
	sbc sstart+0
	sta zt+0
	lda send+1
	sbc sstart+1
	sta zt+1
	lda wsize+0
	cmp zt+0
	lda wsize+1
	sbc zt+1
	bcs sdone
	jmp sinit
sdone	rts

	; copy zt bytes from zi to zt2
	; clobbered: zt (destroyed)
	;            zi, zt2 (they are advanced by zt bytes)
copylist ldy #0
	lda zt+1
	beq +
-	lda (zi),y
	sta (zt2),y
	iny
	bne -
	inc zi+1
	inc zt2+1
	dec zt+1
	bne -
+	ldy #0
-	cpy zt+0
	beq +
	lda (zi),y
	sta (zt2),y
	iny
	jmp -
+	; advance zi by zt bytes
	lda zt+0
	clc
	adc zi+0
	sta zi+0
	lda zt+1
	adc zi+1
	sta zi+1
	; advance zt2 by zt bytes
	lda zt+0
	clc
	adc zt2+0
	sta zt2+0
	lda zt+1
	adc zt2+1
	sta zt2+1
	rts

	; mergesort routine ends here

start	sei
	lda #$35 ; we need ram
	sta $01
	jsr convert
	ldx #<input
	ldy #>input
	stx sstart+0
	sty sstart+1
	ldx inputend+0
	ldy inputend+1
	stx send+0
	sty send+1
	lda #8
	jsr sort ; we need to sort the input chronologically :(

	; find the guard with the most minutes
	lda inputend+1
	sta guard
	lda inputend+0
	beq +
	inc guard
+	; set counters to 0
	; assume max guard id is 4095
	lda #maxguard
	asl
	tax
	ldy #0
	sty gptr1+0
	lda guard
	sta gptr1+1
	tya
-	sta (gptr1),y
	iny
	bne -
	inc gptr1+1
	dex
	bne -

	; go through input, find out how many minutes each guard sleeps
	; and find the sum for each guard
	ldx #<input
	ldy #>input
	stx zp1+0
	sty zp1+1
gloop	; check if we're at the end of input
	jsr checkeof
	bcs phase2
+	; read new guard
	ldy #4
	lda (zp1),y
	beq +
sanity	dec $d020 ; sanity error
	inc $d021
	jmp sanity
+	; get guard id
	iny
	lda (zp1),y
	sta gptr1+0
	sta gptr2+0
	iny
	lda (zp1),y
	clc
	adc guard
	sta gptr1+1
	clc
	adc #maxguard
	sta gptr2+1
	jsr inczp1
	; end of input?
	jsr checkeof
	bcs phase2
	; new guard?
gloop2	ldy #4
	lda (zp1),y
	beq gloop
	; throw error if next 2 records are not fall asleep and wake up
	lda (zp1),y
	cmp #1
	bne sanity
	ldy #$c
	lda (zp1),y
	cmp #2
	bne sanity
	; add minutes
	ldy #$b
	lda (zp1),y
	ldy #3
	sec
	sbc (zp1),y
	ldy #0
	clc
	adc (gptr1),y
	sta (gptr1),y
	bcc +
	lda (gptr2),y
	adc #0
	sta (gptr2),y
+	jsr inczp1
	jsr inczp1
	jmp gloop2

	; all guards counted, find guard who slept the most minutes
phase2	ldy #0
	sty gptr1+0
	sty gptr2+0
	sty best+0
	sty best+1
	lda guard
	sta gptr1+1
	clc
	adc #maxguard
	sta gptr2+1
	ldx #maxguard
-	lda best+0
	cmp (gptr1),y
	lda best+1
	sbc (gptr2),y
	bcs +
	; new best
	lda (gptr1),y
	sta best+0
	lda (gptr2),y
	sta best+1
	sty bestid+0
	lda gptr1+1
	sta bestid+1
+	iny
	bne -
	inc gptr1+1
	inc gptr2+1
	dex
	bne -
	lda bestid+1
	sec
	sbc guard
	sta bestid+1
	; bestid, bestid+1 now holds 16-bit id of guard
	; now find the minute where he sleeps the most!
	; init counter for each minute to 0
	ldy #0
	sty gptr1+0
	sty gptr2+0
	ldx guard
	stx gptr1+1
	inx
	stx gptr2+1
	tya
-	sta (gptr1),y
	sta (gptr2),y
	iny
	cpy #60
	bne -
	; loop through input file (again), this time we only care
	; about the guard id we found
	ldx #<input
	ldy #>input
	stx zp1+0
	sty zp1+1
gloop3	jsr checkeof
	bcs done2
	ldy #4
	lda (zp1),y
	bne spool ; not guard command, skip this line
newg	iny
	lda (zp1),y
	cmp bestid+0
	bne spool
	iny
	lda (zp1),y
	cmp bestid+1
	bne spool ; wrong guard id, skip
	jsr inczp1
	; the correct guard is on shift, count his sleep
gloop4	jsr checkeof
	bcs done2
	ldy #4
	lda (zp1),y
	beq newg ; new guard command, jump to guard id check
	ldy #$b
	lda (zp1),y
	sta temp
	ldy #3
	lda (zp1),y
	tay
	; increase each minute in the interval by 1
-	lda (gptr1),y
	clc
	adc #1
	sta (gptr1),y
	lda (gptr2),y
	adc #0
	sta (gptr2),y
	iny
	cpy temp
	bne -
	jsr inczp1
	jsr inczp1
	jmp gloop4
spool	jsr inczp1
	jmp gloop3
done2	; we've increased all minutes
	; now find the minute where he's the most asleep
	lda #0
	sta best+0
	sta best+1
	ldy #59
-	lda best+0
	cmp (gptr1),y
	lda best+1
	sbc (gptr2),y
	bcs +
	; new best
	sty bestm
	lda (gptr1),y
	sta best+0
	lda (gptr2),y
	sta best+1
+	dey
	bpl -
	; our answer is bestid * bestm (multiply 16-bit by 8-bit)
	ldx bestid+0
	ldy bestid+1
	stx mul1z+0
	sty mul1z+1
	ldx bestm
	ldy #0
	stx mul2z+0
	sty mul2z+1
	jsr mul16
	lda #$37
	sta $01
	; answer is in productz, print it
	ldx #3
-	lda productz,x
	sta inbcd,x
	dex
	bpl -
	jsr int32tobcd
	lda #5
	ldx #<outbcd
	ldy #>outbcd
	jsr printbcd
	lda #$0d
	jmp CHROUT

	; return C=1 if we reached end of input
checkeof lda zp1+0
	cmp inputend+0
	lda zp1+1
	sbc inputend+1
	rts

	; advance zp1 by 1 record
inczp1	lda zp1+0
	clc
	adc #8
	sta zp1+0
	bcc +
	inc zp1+1
+	rts

	; convert 2-digit decimal starting at (zp1),y to 8-bit int
	; sort of clobbers y, it's increased once
conv10	lda (zp1),y
	and #$0f
	asl
	sta temp
	asl
	asl
	adc temp
	iny
	adc (zp1),y
	sec
	sbc #$30
done	rts

	; convert input from text to binary. throw away year, but keep month,
	; day, hour, minute and order:
	; format:
	; 0 month
	; 1 day
	; 2 hour
	; 3 minute
	; 4 order: 0=begins shift, 1=falls asleep, 2=wakes up
	; 5-6: 16-bit int with guard id
	; 7: empty, always 0 (kept for alignment to 8 bytes)
convert	ldx #<input
	ldy #>input
	stx zp1+0
	sty zp1+1
	stx zp2+0
	sty zp2+1
cloop	ldy #0
	lda (zp1),y
	beq done
	; month: starts at pos 6 (0-indexed)
	ldy #6
	jsr conv10
	ldy #0
	sta (zp2),y
	; day: starts at pos 9
	ldy #9
	jsr conv10
	ldy #1
	sta (zp2),y
	; hour: starts at pos 12
	ldy #12
	jsr conv10
	ldy #2
	sta (zp2),y
	; minute: starts at pos 15
	ldy #15
	jsr conv10
	ldy #3
	sta (zp2),y
	; now it's safe to clear bytes 4-7 of the record, no danger of
	; overwriting input file any more
	ldy #4
	lda #0
-	sta (zp2),y
	iny
	cpy #8
	bne -
	; read order: type can be determined from first char (w f or G)
	ldy #19
	lda (zp1),y
	ldy #4
	cmp #$77 ; w = wakes up
	bne +
	lda #2
	sta (zp2),y
	bne nextline
+	cmp #$66 ; f = falls asleep
	bne +
	lda #1
	sta (zp2),y
	bne nextline
+	; last case: guard wakes up
	; read guard id starting at pos 26
	lda #0
	sta mul1+1
	sta (zp2),y
	ldy #26
	lda (zp1),y
	and #$0f
	sta mul1+0
-	iny
	lda (zp1),y
	cmp #32 ; read space, abort
	beq +
	jsr mul10
	lda (zp1),y
	and #$0f
	clc
	adc product+0
	sta mul1+0
	lda product+1
	adc #0
	sta mul1+1
	bcc - ; save 1 byte by betting on this never overflowing
+	ldy #5
	lda mul1+0
	sta (zp2),y
	iny
	lda mul1+1
	sta (zp2),y
nextline ; find linebreak and go to next line
	ldy #0
-	lda (zp1),y
	iny
	cmp #13
	bne -
	tya
	clc
	adc zp1+0
	sta zp1+0
	bcc +
	inc zp1+1
+	lda zp2+0 ; advance pointer to converted list
	clc
	adc #8
	sta zp2+0
	bcc +
	inc zp2+1
+	jmp cloop

	; multiply 16-bit integer in mul1 by 10, result in product
	; this time, don't mess up endianness (should be little-endian)
	; clobber: a, mul1
mul1	!byte 0,0
product	!byte 0,0

mul10	asl mul1+0
	rol mul1+1
	lda mul1+0
	sta product+0
	lda mul1+1
	sta product+1
	asl mul1+0
	rol mul1+1
	asl mul1+0
	rol mul1+1
	lda mul1+0
	clc
	adc product+0
	sta product+0
	lda mul1+1
	adc product+1
	sta product+1
	rts

	; the following is a hex dump of the input text file. each line is of
	; the form: "[yyyy-mm-dd hh:mm] x" where x is the stuff that a specific
	; guard can do. x is one of the following:
	; "Guard #n begins shift", "falls asleep" or "wakes up".
	; unfortunately, the input is not sorted chronologically.
	; observations:
	; - the year is the same throughout the input
	; - guards can begin their shift before midnight
	; - guards can fall asleep and wake up multiple times in one shift
	; this is eventually overwritten with the converted list

	!align 7,0,0 ; align to 8 bytes
input	!hex 5b 31 35 31 38 2d 30 36 2d 30 33 20 30 30 3a 33 32 5d 20 77 61 6b
	!hex 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 37 2d 32 34 20 30 30 3a 34
	!hex 37 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 38 2d 31
	!hex 33 20 30 30 3a 35 36 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31
	!hex 38 2d 31 31 2d 30 32 20 30 30 3a 33 32 5d 20 66 61 6c 6c 73 20 61
	!hex 73 6c 65 65 70 0d 5b 31 35 31 38 2d 31 30 2d 32 33 20 30 30 3a 33
	!hex 32 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d
	!hex 30 39 2d 32 36 20 30 30 3a 34 31 5d 20 66 61 6c 6c 73 20 61 73 6c
	!hex 65 65 70 0d 5b 31 35 31 38 2d 30 32 2d 32 31 20 30 30 3a 30 37 5d
	!hex 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 36
	!hex 2d 32 37 20 30 30 3a 35 30 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31
	!hex 35 31 38 2d 30 39 2d 30 31 20 30 30 3a 30 33 5d 20 47 75 61 72 64
	!hex 20 23 31 36 30 31 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31
	!hex 35 31 38 2d 30 33 2d 31 31 20 30 30 3a 30 33 5d 20 47 75 61 72 64
	!hex 20 23 31 36 30 31 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31
	!hex 35 31 38 2d 31 30 2d 30 32 20 30 30 3a 32 34 5d 20 66 61 6c 6c 73
	!hex 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 34 2d 33 30 20 30 30
	!hex 3a 30 30 5d 20 47 75 61 72 64 20 23 32 38 38 37 20 62 65 67 69 6e
	!hex 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 31 31 2d 31 35 20 32 33
	!hex 3a 35 37 5d 20 47 75 61 72 64 20 23 31 30 39 37 20 62 65 67 69 6e
	!hex 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 31 31 2d 30 35 20 30 30
	!hex 3a 31 39 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31
	!hex 38 2d 30 37 2d 32 31 20 30 30 3a 30 33 5d 20 47 75 61 72 64 20 23
	!hex 31 32 34 39 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31
	!hex 38 2d 30 38 2d 32 39 20 30 30 3a 35 39 5d 20 77 61 6b 65 73 20 75
	!hex 70 0d 5b 31 35 31 38 2d 30 39 2d 31 33 20 30 30 3a 32 36 5d 20 77
	!hex 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 32 2d 30 39 20 30 30
	!hex 3a 33 30 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31
	!hex 38 2d 30 33 2d 31 31 20 30 30 3a 33 39 5d 20 66 61 6c 6c 73 20 61
	!hex 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 35 2d 31 32 20 30 30 3a 30
	!hex 30 5d 20 47 75 61 72 64 20 23 33 31 31 39 20 62 65 67 69 6e 73 20
	!hex 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 32 2d 30 33 20 30 30 3a 35
	!hex 35 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 39 2d 32
	!hex 36 20 32 33 3a 34 39 5d 20 47 75 61 72 64 20 23 31 36 30 31 20 62
	!hex 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 39 2d 33
	!hex 30 20 30 30 3a 35 35 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31
	!hex 38 2d 30 37 2d 31 33 20 30 30 3a 30 31 5d 20 47 75 61 72 64 20 23
	!hex 31 35 35 39 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31
	!hex 38 2d 30 38 2d 33 31 20 30 30 3a 35 34 5d 20 77 61 6b 65 73 20 75
	!hex 70 0d 5b 31 35 31 38 2d 30 33 2d 31 35 20 32 33 3a 35 39 5d 20 47
	!hex 75 61 72 64 20 23 31 32 34 39 20 62 65 67 69 6e 73 20 73 68 69 66
	!hex 74 0d 5b 31 35 31 38 2d 31 30 2d 32 34 20 30 30 3a 30 31 5d 20 47
	!hex 75 61 72 64 20 23 31 30 33 39 20 62 65 67 69 6e 73 20 73 68 69 66
	!hex 74 0d 5b 31 35 31 38 2d 30 33 2d 32 37 20 30 30 3a 30 38 5d 20 66
	!hex 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 38 2d 31
	!hex 34 20 30 30 3a 35 35 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31
	!hex 38 2d 30 36 2d 30 37 20 30 30 3a 34 37 5d 20 77 61 6b 65 73 20 75
	!hex 70 0d 5b 31 35 31 38 2d 30 37 2d 32 32 20 30 30 3a 34 36 5d 20 77
	!hex 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 34 2d 30 33 20 30 30
	!hex 3a 30 32 5d 20 47 75 61 72 64 20 23 33 31 33 37 20 62 65 67 69 6e
	!hex 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 37 2d 32 37 20 30 30
	!hex 3a 31 35 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31
	!hex 38 2d 30 32 2d 32 35 20 32 33 3a 35 38 5d 20 47 75 61 72 64 20 23
	!hex 31 30 33 39 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31
	!hex 38 2d 31 30 2d 30 34 20 30 30 3a 30 32 5d 20 47 75 61 72 64 20 23
	!hex 33 30 31 31 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31
	!hex 38 2d 30 39 2d 30 36 20 30 30 3a 32 38 5d 20 77 61 6b 65 73 20 75
	!hex 70 0d 5b 31 35 31 38 2d 30 37 2d 30 37 20 30 30 3a 34 39 5d 20 77
	!hex 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 31 30 2d 32 30 20 30 30
	!hex 3a 33 36 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 39
	!hex 2d 30 35 20 30 30 3a 35 37 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31
	!hex 35 31 38 2d 30 35 2d 32 38 20 30 30 3a 33 38 5d 20 77 61 6b 65 73
	!hex 20 75 70 0d 5b 31 35 31 38 2d 31 30 2d 31 31 20 30 30 3a 35 34 5d
	!hex 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 37
	!hex 2d 30 35 20 30 30 3a 31 39 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65
	!hex 70 0d 5b 31 35 31 38 2d 30 35 2d 31 31 20 30 30 3a 35 36 5d 20 77
	!hex 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 33 2d 31 35 20 30 30
	!hex 3a 35 36 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 37
	!hex 2d 32 38 20 30 30 3a 34 34 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65
	!hex 70 0d 5b 31 35 31 38 2d 31 31 2d 30 39 20 30 30 3a 30 30 5d 20 47
	!hex 75 61 72 64 20 23 33 33 31 20 62 65 67 69 6e 73 20 73 68 69 66 74
	!hex 0d 5b 31 35 31 38 2d 30 32 2d 32 35 20 30 30 3a 35 36 5d 20 77 61
	!hex 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 34 2d 30 32 20 30 30 3a
	!hex 34 31 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 39 2d
	!hex 30 35 20 32 33 3a 35 38 5d 20 47 75 61 72 64 20 23 31 30 39 37 20
	!hex 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 33 2d
	!hex 33 31 20 30 30 3a 30 37 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70
	!hex 0d 5b 31 35 31 38 2d 30 34 2d 31 37 20 30 30 3a 35 30 5d 20 77 61
	!hex 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 31 30 2d 31 31 20 30 30 3a
	!hex 34 38 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 32 2d
	!hex 30 35 20 30 30 3a 30 34 5d 20 47 75 61 72 64 20 23 33 33 31 20 62
	!hex 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 38 2d 30
	!hex 32 20 30 30 3a 33 39 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d
	!hex 5b 31 35 31 38 2d 30 32 2d 32 31 20 30 30 3a 33 32 5d 20 77 61 6b
	!hex 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 36 2d 31 34 20 30 30 3a 35
	!hex 39 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 31 31 2d 30
	!hex 33 20 32 33 3a 35 38 5d 20 47 75 61 72 64 20 23 31 32 34 39 20 62
	!hex 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 38 2d 31
	!hex 30 20 30 30 3a 31 32 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d
	!hex 5b 31 35 31 38 2d 31 31 2d 31 36 20 30 30 3a 31 31 5d 20 66 61 6c
	!hex 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 33 2d 31 34 20
	!hex 30 30 3a 30 30 5d 20 47 75 61 72 64 20 23 32 38 38 37 20 62 65 67
	!hex 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 35 2d 31 33 20
	!hex 30 30 3a 32 37 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d
	!hex 30 39 2d 31 33 20 30 30 3a 35 31 5d 20 77 61 6b 65 73 20 75 70 0d
	!hex 5b 31 35 31 38 2d 30 33 2d 31 36 20 32 33 3a 35 38 5d 20 47 75 61
	!hex 72 64 20 23 35 36 33 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b
	!hex 31 35 31 38 2d 30 33 2d 30 37 20 32 33 3a 35 37 5d 20 47 75 61 72
	!hex 64 20 23 33 37 33 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31
	!hex 35 31 38 2d 30 33 2d 31 31 20 32 33 3a 35 37 5d 20 47 75 61 72 64
	!hex 20 23 32 39 36 39 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31
	!hex 35 31 38 2d 31 31 2d 31 39 20 30 30 3a 30 30 5d 20 47 75 61 72 64
	!hex 20 23 33 31 31 39 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31
	!hex 35 31 38 2d 30 38 2d 32 30 20 30 30 3a 33 30 5d 20 77 61 6b 65 73
	!hex 20 75 70 0d 5b 31 35 31 38 2d 30 37 2d 31 38 20 30 30 3a 30 34 5d
	!hex 20 47 75 61 72 64 20 23 33 31 33 37 20 62 65 67 69 6e 73 20 73 68
	!hex 69 66 74 0d 5b 31 35 31 38 2d 31 30 2d 31 30 20 30 30 3a 33 32 5d
	!hex 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 32 2d 30 33 20
	!hex 30 30 3a 34 33 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31
	!hex 35 31 38 2d 30 33 2d 30 38 20 30 30 3a 33 31 5d 20 66 61 6c 6c 73
	!hex 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 38 2d 31 35 20 32 33
	!hex 3a 35 37 5d 20 47 75 61 72 64 20 23 34 33 31 20 62 65 67 69 6e 73
	!hex 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 38 2d 32 31 20 32 33 3a
	!hex 34 37 5d 20 47 75 61 72 64 20 23 33 30 38 39 20 62 65 67 69 6e 73
	!hex 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 35 2d 31 36 20 32 33 3a
	!hex 35 31 5d 20 47 75 61 72 64 20 23 31 30 39 37 20 62 65 67 69 6e 73
	!hex 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 36 2d 31 39 20 32 33 3a
	!hex 35 39 5d 20 47 75 61 72 64 20 23 31 30 39 37 20 62 65 67 69 6e 73
	!hex 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 36 2d 30 37 20 30 30 3a
	!hex 35 39 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 35 2d
	!hex 31 37 20 30 30 3a 34 36 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35
	!hex 31 38 2d 30 32 2d 30 35 20 32 33 3a 35 34 5d 20 47 75 61 72 64 20
	!hex 23 31 30 39 37 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35
	!hex 31 38 2d 31 30 2d 32 39 20 30 30 3a 30 38 5d 20 66 61 6c 6c 73 20
	!hex 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 38 2d 30 32 20 30 30 3a
	!hex 35 38 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 39 2d
	!hex 32 32 20 30 30 3a 33 30 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35
	!hex 31 38 2d 30 33 2d 33 31 20 32 33 3a 35 39 5d 20 47 75 61 72 64 20
	!hex 23 31 30 33 39 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35
	!hex 31 38 2d 30 36 2d 31 31 20 30 30 3a 31 34 5d 20 66 61 6c 6c 73 20
	!hex 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 31 30 2d 31 39 20 32 33 3a
	!hex 35 37 5d 20 47 75 61 72 64 20 23 33 31 33 37 20 62 65 67 69 6e 73
	!hex 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 34 2d 32 35 20 30 30 3a
	!hex 30 39 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38
	!hex 2d 31 31 2d 31 33 20 30 30 3a 30 30 5d 20 66 61 6c 6c 73 20 61 73
	!hex 6c 65 65 70 0d 5b 31 35 31 38 2d 30 32 2d 31 36 20 30 30 3a 30 35
	!hex 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30
	!hex 35 2d 31 34 20 30 30 3a 30 39 5d 20 66 61 6c 6c 73 20 61 73 6c 65
	!hex 65 70 0d 5b 31 35 31 38 2d 30 34 2d 32 36 20 30 30 3a 30 30 5d 20
	!hex 47 75 61 72 64 20 23 32 35 37 39 20 62 65 67 69 6e 73 20 73 68 69
	!hex 66 74 0d 5b 31 35 31 38 2d 30 36 2d 32 30 20 32 33 3a 35 38 5d 20
	!hex 47 75 61 72 64 20 23 34 33 31 20 62 65 67 69 6e 73 20 73 68 69 66
	!hex 74 0d 5b 31 35 31 38 2d 30 35 2d 31 37 20 32 33 3a 35 30 5d 20 47
	!hex 75 61 72 64 20 23 31 35 35 39 20 62 65 67 69 6e 73 20 73 68 69 66
	!hex 74 0d 5b 31 35 31 38 2d 30 34 2d 32 31 20 30 30 3a 35 33 5d 20 77
	!hex 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 34 2d 31 37 20 30 30
	!hex 3a 34 36 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31
	!hex 38 2d 30 35 2d 30 35 20 30 30 3a 35 32 5d 20 77 61 6b 65 73 20 75
	!hex 70 0d 5b 31 35 31 38 2d 30 34 2d 32 36 20 30 30 3a 34 31 5d 20 66
	!hex 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 36 2d 31
	!hex 30 20 30 30 3a 30 32 5d 20 47 75 61 72 64 20 23 31 32 34 39 20 62
	!hex 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 34 2d 30
	!hex 39 20 30 30 3a 35 39 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31
	!hex 38 2d 30 35 2d 31 39 20 30 30 3a 32 39 5d 20 77 61 6b 65 73 20 75
	!hex 70 0d 5b 31 35 31 38 2d 30 36 2d 31 30 20 30 30 3a 31 34 5d 20 66
	!hex 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 37 2d 31
	!hex 31 20 30 30 3a 33 33 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d
	!hex 5b 31 35 31 38 2d 30 37 2d 30 39 20 30 30 3a 30 38 5d 20 66 61 6c
	!hex 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 38 2d 30 32 20
	!hex 30 30 3a 30 39 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31
	!hex 35 31 38 2d 30 35 2d 30 36 20 30 30 3a 34 33 5d 20 77 61 6b 65 73
	!hex 20 75 70 0d 5b 31 35 31 38 2d 31 30 2d 33 31 20 30 30 3a 31 38 5d
	!hex 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 38 2d 31 39 20
	!hex 32 33 3a 35 37 5d 20 47 75 61 72 64 20 23 33 30 38 33 20 62 65 67
	!hex 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 31 31 2d 32 33 20
	!hex 30 30 3a 33 31 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31
	!hex 35 31 38 2d 31 31 2d 30 35 20 32 33 3a 35 39 5d 20 47 75 61 72 64
	!hex 20 23 32 35 37 39 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31
	!hex 35 31 38 2d 30 36 2d 32 32 20 30 30 3a 32 33 5d 20 66 61 6c 6c 73
	!hex 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 32 2d 31 38 20 30 30
	!hex 3a 32 38 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31
	!hex 38 2d 30 37 2d 32 30 20 30 30 3a 35 38 5d 20 77 61 6b 65 73 20 75
	!hex 70 0d 5b 31 35 31 38 2d 30 37 2d 32 39 20 32 33 3a 34 39 5d 20 47
	!hex 75 61 72 64 20 23 33 30 31 31 20 62 65 67 69 6e 73 20 73 68 69 66
	!hex 74 0d 5b 31 35 31 38 2d 30 39 2d 30 31 20 30 30 3a 31 31 5d 20 66
	!hex 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 38 2d 31
	!hex 30 20 30 30 3a 31 38 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31
	!hex 38 2d 30 32 2d 30 39 20 30 30 3a 30 31 5d 20 66 61 6c 6c 73 20 61
	!hex 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 33 2d 30 33 20 30 30 3a 33
	!hex 39 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 38 2d 31
	!hex 36 20 30 30 3a 33 32 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31
	!hex 38 2d 30 35 2d 30 34 20 30 30 3a 33 32 5d 20 66 61 6c 6c 73 20 61
	!hex 73 6c 65 65 70 0d 5b 31 35 31 38 2d 31 30 2d 31 34 20 30 30 3a 34
	!hex 34 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 36 2d 32
	!hex 37 20 32 33 3a 35 30 5d 20 47 75 61 72 64 20 23 33 30 38 33 20 62
	!hex 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 33 2d 30
	!hex 34 20 30 30 3a 34 35 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31
	!hex 38 2d 30 38 2d 31 38 20 30 30 3a 34 32 5d 20 77 61 6b 65 73 20 75
	!hex 70 0d 5b 31 35 31 38 2d 30 34 2d 32 39 20 30 30 3a 30 32 5d 20 66
	!hex 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 36 2d 31
	!hex 34 20 30 30 3a 34 39 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d
	!hex 5b 31 35 31 38 2d 30 35 2d 31 30 20 32 33 3a 35 38 5d 20 47 75 61
	!hex 72 64 20 23 34 33 31 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b
	!hex 31 35 31 38 2d 30 35 2d 32 33 20 30 30 3a 30 38 5d 20 77 61 6b 65
	!hex 73 20 75 70 0d 5b 31 35 31 38 2d 30 36 2d 31 32 20 30 30 3a 35 32
	!hex 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 35 2d 32 30
	!hex 20 30 30 3a 31 36 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b
	!hex 31 35 31 38 2d 30 33 2d 32 32 20 30 30 3a 30 32 5d 20 47 75 61 72
	!hex 64 20 23 33 30 38 39 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b
	!hex 31 35 31 38 2d 31 31 2d 30 32 20 30 30 3a 33 33 5d 20 77 61 6b 65
	!hex 73 20 75 70 0d 5b 31 35 31 38 2d 30 33 2d 31 39 20 30 30 3a 32 33
	!hex 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 33 2d 31 38
	!hex 20 30 30 3a 35 35 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38
	!hex 2d 30 35 2d 32 33 20 30 30 3a 32 38 5d 20 77 61 6b 65 73 20 75 70
	!hex 0d 5b 31 35 31 38 2d 30 33 2d 33 30 20 30 30 3a 30 34 5d 20 47 75
	!hex 61 72 64 20 23 33 30 38 39 20 62 65 67 69 6e 73 20 73 68 69 66 74
	!hex 0d 5b 31 35 31 38 2d 30 33 2d 32 30 20 30 30 3a 30 33 5d 20 47 75
	!hex 61 72 64 20 23 38 39 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b
	!hex 31 35 31 38 2d 30 39 2d 32 36 20 30 30 3a 30 35 5d 20 66 61 6c 6c
	!hex 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 36 2d 30 32 20 30
	!hex 30 3a 34 34 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 31
	!hex 30 2d 30 32 20 30 30 3a 33 34 5d 20 77 61 6b 65 73 20 75 70 0d 5b
	!hex 31 35 31 38 2d 30 39 2d 30 38 20 30 30 3a 35 34 5d 20 77 61 6b 65
	!hex 73 20 75 70 0d 5b 31 35 31 38 2d 30 39 2d 31 33 20 30 30 3a 30 33
	!hex 5d 20 47 75 61 72 64 20 23 31 30 39 37 20 62 65 67 69 6e 73 20 73
	!hex 68 69 66 74 0d 5b 31 35 31 38 2d 31 30 2d 30 32 20 30 30 3a 35 39
	!hex 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 35 2d 31 30
	!hex 20 30 30 3a 34 30 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b
	!hex 31 35 31 38 2d 30 39 2d 30 39 20 30 30 3a 30 37 5d 20 66 61 6c 6c
	!hex 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 39 2d 31 30 20 30
	!hex 30 3a 30 37 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35
	!hex 31 38 2d 30 37 2d 30 34 20 30 30 3a 35 37 5d 20 77 61 6b 65 73 20
	!hex 75 70 0d 5b 31 35 31 38 2d 30 32 2d 31 34 20 30 30 3a 30 39 5d 20
	!hex 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 37 2d
	!hex 31 31 20 32 33 3a 35 36 5d 20 47 75 61 72 64 20 23 33 30 38 39 20
	!hex 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 36 2d
	!hex 30 39 20 30 30 3a 33 35 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70
	!hex 0d 5b 31 35 31 38 2d 30 32 2d 31 36 20 30 30 3a 32 36 5d 20 77 61
	!hex 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 36 2d 31 30 20 30 30 3a
	!hex 33 39 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 31 30 2d
	!hex 30 33 20 30 30 3a 33 38 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35
	!hex 31 38 2d 31 31 2d 30 31 20 30 30 3a 32 38 5d 20 66 61 6c 6c 73 20
	!hex 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 32 2d 31 33 20 30 30 3a
	!hex 35 36 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 34 2d
	!hex 30 34 20 30 30 3a 34 35 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35
	!hex 31 38 2d 30 37 2d 32 39 20 30 30 3a 32 39 5d 20 66 61 6c 6c 73 20
	!hex 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 31 31 2d 31 30 20 30 30 3a
	!hex 31 39 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38
	!hex 2d 30 33 2d 32 34 20 30 30 3a 30 31 5d 20 47 75 61 72 64 20 23 33
	!hex 33 31 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d
	!hex 30 35 2d 32 35 20 30 30 3a 31 39 5d 20 66 61 6c 6c 73 20 61 73 6c
	!hex 65 65 70 0d 5b 31 35 31 38 2d 30 33 2d 30 34 20 30 30 3a 30 38 5d
	!hex 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 35
	!hex 2d 32 30 20 30 30 3a 30 32 5d 20 47 75 61 72 64 20 23 31 36 30 31
	!hex 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 31 30
	!hex 2d 32 35 20 30 30 3a 34 31 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31
	!hex 35 31 38 2d 31 30 2d 31 36 20 30 30 3a 35 30 5d 20 66 61 6c 6c 73
	!hex 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 33 2d 32 36 20 30 30
	!hex 3a 35 30 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 36
	!hex 2d 32 34 20 30 30 3a 30 30 5d 20 47 75 61 72 64 20 23 32 35 37 39
	!hex 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 34
	!hex 2d 30 34 20 32 33 3a 35 36 5d 20 47 75 61 72 64 20 23 31 36 30 31
	!hex 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 33
	!hex 2d 32 33 20 30 30 3a 33 39 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31
	!hex 35 31 38 2d 30 38 2d 30 35 20 32 33 3a 35 39 5d 20 47 75 61 72 64
	!hex 20 23 33 31 33 37 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31
	!hex 35 31 38 2d 30 39 2d 31 38 20 30 30 3a 31 34 5d 20 66 61 6c 6c 73
	!hex 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 34 2d 32 33 20 30 30
	!hex 3a 31 38 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31
	!hex 38 2d 30 38 2d 30 32 20 30 30 3a 30 30 5d 20 47 75 61 72 64 20 23
	!hex 31 32 34 39 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31
	!hex 38 2d 30 35 2d 31 35 20 30 30 3a 35 36 5d 20 77 61 6b 65 73 20 75
	!hex 70 0d 5b 31 35 31 38 2d 31 30 2d 30 35 20 30 30 3a 30 30 5d 20 47
	!hex 75 61 72 64 20 23 31 32 34 39 20 62 65 67 69 6e 73 20 73 68 69 66
	!hex 74 0d 5b 31 35 31 38 2d 31 30 2d 32 31 20 30 30 3a 32 32 5d 20 66
	!hex 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 31 31 2d 30
	!hex 31 20 30 30 3a 35 34 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d
	!hex 5b 31 35 31 38 2d 31 30 2d 30 38 20 30 30 3a 31 34 5d 20 66 61 6c
	!hex 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 35 2d 30 34 20
	!hex 30 30 3a 30 30 5d 20 47 75 61 72 64 20 23 33 37 33 20 62 65 67 69
	!hex 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 31 30 2d 30 36 20 30
	!hex 30 3a 35 32 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30
	!hex 33 2d 30 32 20 30 30 3a 31 31 5d 20 66 61 6c 6c 73 20 61 73 6c 65
	!hex 65 70 0d 5b 31 35 31 38 2d 30 34 2d 30 38 20 30 30 3a 34 33 5d 20
	!hex 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 36 2d 31 37 20 30
	!hex 30 3a 35 38 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30
	!hex 35 2d 31 31 20 30 30 3a 30 37 5d 20 66 61 6c 6c 73 20 61 73 6c 65
	!hex 65 70 0d 5b 31 35 31 38 2d 30 33 2d 32 36 20 30 30 3a 34 38 5d 20
	!hex 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 34 2d
	!hex 31 39 20 30 30 3a 31 33 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70
	!hex 0d 5b 31 35 31 38 2d 30 33 2d 30 33 20 30 30 3a 30 34 5d 20 47 75
	!hex 61 72 64 20 23 33 33 31 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d
	!hex 5b 31 35 31 38 2d 30 38 2d 30 31 20 30 30 3a 35 39 5d 20 77 61 6b
	!hex 65 73 20 75 70 0d 5b 31 35 31 38 2d 31 30 2d 32 39 20 32 33 3a 35
	!hex 30 5d 20 47 75 61 72 64 20 23 38 39 20 62 65 67 69 6e 73 20 73 68
	!hex 69 66 74 0d 5b 31 35 31 38 2d 30 39 2d 31 36 20 32 33 3a 35 36 5d
	!hex 20 47 75 61 72 64 20 23 31 36 30 31 20 62 65 67 69 6e 73 20 73 68
	!hex 69 66 74 0d 5b 31 35 31 38 2d 30 36 2d 31 33 20 32 33 3a 35 38 5d
	!hex 20 47 75 61 72 64 20 23 31 35 35 39 20 62 65 67 69 6e 73 20 73 68
	!hex 69 66 74 0d 5b 31 35 31 38 2d 30 32 2d 30 35 20 30 30 3a 31 38 5d
	!hex 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 38
	!hex 2d 32 32 20 30 30 3a 35 34 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65
	!hex 70 0d 5b 31 35 31 38 2d 30 34 2d 30 33 20 30 30 3a 32 35 5d 20 66
	!hex 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 33 2d 30
	!hex 39 20 30 30 3a 35 31 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31
	!hex 38 2d 30 39 2d 31 33 20 30 30 3a 33 38 5d 20 66 61 6c 6c 73 20 61
	!hex 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 32 2d 32 30 20 30 30 3a 34
	!hex 37 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 37 2d 32
	!hex 38 20 30 30 3a 35 33 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31
	!hex 38 2d 30 35 2d 32 37 20 30 30 3a 34 35 5d 20 66 61 6c 6c 73 20 61
	!hex 73 6c 65 65 70 0d 5b 31 35 31 38 2d 31 30 2d 31 32 20 30 30 3a 32
	!hex 35 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d
	!hex 30 36 2d 30 38 20 30 30 3a 31 35 5d 20 66 61 6c 6c 73 20 61 73 6c
	!hex 65 65 70 0d 5b 31 35 31 38 2d 30 33 2d 32 39 20 30 30 3a 35 37 5d
	!hex 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 38 2d 30 31 20
	!hex 30 30 3a 35 34 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d
	!hex 30 37 2d 31 31 20 30 30 3a 35 33 5d 20 77 61 6b 65 73 20 75 70 0d
	!hex 5b 31 35 31 38 2d 30 36 2d 31 33 20 30 30 3a 35 30 5d 20 77 61 6b
	!hex 65 73 20 75 70 0d 5b 31 35 31 38 2d 31 31 2d 31 34 20 30 30 3a 33
	!hex 37 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d
	!hex 30 35 2d 32 36 20 30 30 3a 30 34 5d 20 47 75 61 72 64 20 23 32 33
	!hex 38 31 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d
	!hex 30 34 2d 32 31 20 30 30 3a 34 33 5d 20 66 61 6c 6c 73 20 61 73 6c
	!hex 65 65 70 0d 5b 31 35 31 38 2d 31 30 2d 32 31 20 32 33 3a 35 39 5d
	!hex 20 47 75 61 72 64 20 23 38 39 20 62 65 67 69 6e 73 20 73 68 69 66
	!hex 74 0d 5b 31 35 31 38 2d 30 34 2d 30 39 20 30 30 3a 34 37 5d 20 66
	!hex 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 39 2d 31
	!hex 31 20 30 30 3a 35 35 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31
	!hex 38 2d 30 37 2d 30 38 20 30 30 3a 30 39 5d 20 66 61 6c 6c 73 20 61
	!hex 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 33 2d 30 33 20 32 33 3a 35
	!hex 37 5d 20 47 75 61 72 64 20 23 32 33 38 31 20 62 65 67 69 6e 73 20
	!hex 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 33 2d 30 32 20 30 30 3a 30
	!hex 33 5d 20 47 75 61 72 64 20 23 32 33 38 31 20 62 65 67 69 6e 73 20
	!hex 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 36 2d 32 32 20 30 30 3a 34
	!hex 34 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d
	!hex 30 33 2d 30 31 20 30 30 3a 35 36 5d 20 77 61 6b 65 73 20 75 70 0d
	!hex 5b 31 35 31 38 2d 31 30 2d 31 38 20 30 30 3a 34 33 5d 20 66 61 6c
	!hex 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 39 2d 32 35 20
	!hex 30 30 3a 30 30 5d 20 47 75 61 72 64 20 23 33 33 31 20 62 65 67 69
	!hex 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 37 2d 32 35 20 30
	!hex 30 3a 35 38 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30
	!hex 32 2d 30 36 20 30 30 3a 35 37 5d 20 77 61 6b 65 73 20 75 70 0d 5b
	!hex 31 35 31 38 2d 30 32 2d 32 33 20 30 30 3a 35 32 5d 20 77 61 6b 65
	!hex 73 20 75 70 0d 5b 31 35 31 38 2d 30 35 2d 31 30 20 30 30 3a 34 35
	!hex 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 32 2d 31 30
	!hex 20 30 30 3a 33 39 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b
	!hex 31 35 31 38 2d 30 39 2d 31 35 20 30 30 3a 34 38 5d 20 77 61 6b 65
	!hex 73 20 75 70 0d 5b 31 35 31 38 2d 30 35 2d 31 39 20 30 30 3a 32 35
	!hex 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30
	!hex 38 2d 31 31 20 32 33 3a 35 38 5d 20 47 75 61 72 64 20 23 32 38 37
	!hex 39 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30
	!hex 34 2d 32 32 20 30 30 3a 33 33 5d 20 77 61 6b 65 73 20 75 70 0d 5b
	!hex 31 35 31 38 2d 30 36 2d 31 38 20 30 30 3a 32 34 5d 20 66 61 6c 6c
	!hex 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 34 2d 30 37 20 30
	!hex 30 3a 34 35 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35
	!hex 31 38 2d 30 37 2d 32 37 20 30 30 3a 34 35 5d 20 77 61 6b 65 73 20
	!hex 75 70 0d 5b 31 35 31 38 2d 30 39 2d 31 30 20 32 33 3a 35 36 5d 20
	!hex 47 75 61 72 64 20 23 32 39 36 39 20 62 65 67 69 6e 73 20 73 68 69
	!hex 66 74 0d 5b 31 35 31 38 2d 30 37 2d 30 39 20 30 30 3a 31 34 5d 20
	!hex 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 33 2d 32 39 20 30
	!hex 30 3a 32 34 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 31
	!hex 30 2d 30 37 20 30 30 3a 33 35 5d 20 77 61 6b 65 73 20 75 70 0d 5b
	!hex 31 35 31 38 2d 30 35 2d 31 38 20 30 30 3a 34 38 5d 20 77 61 6b 65
	!hex 73 20 75 70 0d 5b 31 35 31 38 2d 31 31 2d 31 37 20 30 30 3a 30 34
	!hex 5d 20 47 75 61 72 64 20 23 33 37 33 20 62 65 67 69 6e 73 20 73 68
	!hex 69 66 74 0d 5b 31 35 31 38 2d 30 39 2d 30 33 20 30 30 3a 33 33 5d
	!hex 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 33
	!hex 2d 32 35 20 30 30 3a 30 31 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65
	!hex 70 0d 5b 31 35 31 38 2d 30 38 2d 32 35 20 30 30 3a 34 34 5d 20 66
	!hex 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 33 2d 30
	!hex 39 20 32 33 3a 34 37 5d 20 47 75 61 72 64 20 23 33 37 33 20 62 65
	!hex 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 31 31 2d 31 30
	!hex 20 30 30 3a 34 34 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38
	!hex 2d 30 34 2d 31 39 20 30 30 3a 34 36 5d 20 77 61 6b 65 73 20 75 70
	!hex 0d 5b 31 35 31 38 2d 30 38 2d 33 30 20 30 30 3a 30 32 5d 20 47 75
	!hex 61 72 64 20 23 32 31 33 37 20 62 65 67 69 6e 73 20 73 68 69 66 74
	!hex 0d 5b 31 35 31 38 2d 30 37 2d 30 37 20 30 30 3a 32 33 5d 20 66 61
	!hex 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 33 2d 30 36
	!hex 20 32 33 3a 35 39 5d 20 47 75 61 72 64 20 23 33 31 31 39 20 62 65
	!hex 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 31 30 2d 30 33
	!hex 20 30 30 3a 35 34 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38
	!hex 2d 30 32 2d 30 33 20 32 33 3a 35 38 5d 20 47 75 61 72 64 20 23 32
	!hex 35 37 39 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38
	!hex 2d 30 39 2d 32 38 20 30 30 3a 34 34 5d 20 77 61 6b 65 73 20 75 70
	!hex 0d 5b 31 35 31 38 2d 30 36 2d 31 38 20 30 30 3a 30 31 5d 20 47 75
	!hex 61 72 64 20 23 31 30 39 37 20 62 65 67 69 6e 73 20 73 68 69 66 74
	!hex 0d 5b 31 35 31 38 2d 30 34 2d 32 38 20 30 30 3a 34 33 5d 20 77 61
	!hex 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 35 2d 31 32 20 30 30 3a
	!hex 30 39 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38
	!hex 2d 30 33 2d 32 37 20 30 30 3a 35 33 5d 20 77 61 6b 65 73 20 75 70
	!hex 0d 5b 31 35 31 38 2d 30 37 2d 31 37 20 30 30 3a 33 36 5d 20 66 61
	!hex 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 31 30 2d 32 38
	!hex 20 30 30 3a 32 34 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b
	!hex 31 35 31 38 2d 30 39 2d 30 31 20 30 30 3a 35 36 5d 20 77 61 6b 65
	!hex 73 20 75 70 0d 5b 31 35 31 38 2d 30 37 2d 30 35 20 30 30 3a 35 36
	!hex 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 31 30 2d 31 38
	!hex 20 30 30 3a 35 31 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38
	!hex 2d 30 35 2d 32 37 20 30 30 3a 34 32 5d 20 77 61 6b 65 73 20 75 70
	!hex 0d 5b 31 35 31 38 2d 30 34 2d 32 38 20 30 30 3a 31 30 5d 20 66 61
	!hex 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 34 2d 30 32
	!hex 20 30 30 3a 35 36 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b
	!hex 31 35 31 38 2d 30 34 2d 30 34 20 30 30 3a 35 39 5d 20 77 61 6b 65
	!hex 73 20 75 70 0d 5b 31 35 31 38 2d 30 33 2d 32 33 20 30 30 3a 34 38
	!hex 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30
	!hex 38 2d 31 37 20 30 30 3a 35 33 5d 20 77 61 6b 65 73 20 75 70 0d 5b
	!hex 31 35 31 38 2d 30 34 2d 32 33 20 30 30 3a 34 33 5d 20 77 61 6b 65
	!hex 73 20 75 70 0d 5b 31 35 31 38 2d 30 32 2d 32 30 20 30 30 3a 35 31
	!hex 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30
	!hex 35 2d 32 38 20 30 30 3a 31 36 5d 20 66 61 6c 6c 73 20 61 73 6c 65
	!hex 65 70 0d 5b 31 35 31 38 2d 30 32 2d 32 36 20 30 30 3a 34 33 5d 20
	!hex 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 32 2d
	!hex 32 32 20 30 30 3a 34 36 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35
	!hex 31 38 2d 31 31 2d 31 33 20 30 30 3a 33 39 5d 20 77 61 6b 65 73 20
	!hex 75 70 0d 5b 31 35 31 38 2d 30 32 2d 31 37 20 30 30 3a 34 34 5d 20
	!hex 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 35 2d
	!hex 30 37 20 30 30 3a 34 35 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70
	!hex 0d 5b 31 35 31 38 2d 30 38 2d 32 35 20 30 30 3a 34 35 5d 20 77 61
	!hex 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 38 2d 32 38 20 30 30 3a
	!hex 35 32 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 34 2d
	!hex 31 38 20 30 30 3a 34 32 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35
	!hex 31 38 2d 30 39 2d 30 36 20 32 33 3a 35 37 5d 20 47 75 61 72 64 20
	!hex 23 33 30 38 33 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35
	!hex 31 38 2d 30 38 2d 30 35 20 30 30 3a 31 35 5d 20 66 61 6c 6c 73 20
	!hex 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 31 30 2d 32 31 20 30 30 3a
	!hex 35 38 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 37 2d
	!hex 32 34 20 30 30 3a 34 33 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70
	!hex 0d 5b 31 35 31 38 2d 30 37 2d 30 33 20 30 30 3a 35 37 5d 20 77 61
	!hex 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 31 30 2d 30 33 20 30 30 3a
	!hex 30 34 5d 20 47 75 61 72 64 20 23 33 30 38 39 20 62 65 67 69 6e 73
	!hex 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 36 2d 30 31 20 30 30 3a
	!hex 30 30 5d 20 47 75 61 72 64 20 23 37 39 37 20 62 65 67 69 6e 73 20
	!hex 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 32 2d 31 30 20 30 30 3a 34
	!hex 34 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 39 2d 32
	!hex 34 20 30 30 3a 34 34 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d
	!hex 5b 31 35 31 38 2d 31 31 2d 30 37 20 30 30 3a 30 30 5d 20 47 75 61
	!hex 72 64 20 23 33 30 31 31 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d
	!hex 5b 31 35 31 38 2d 30 39 2d 31 37 20 32 33 3a 35 36 5d 20 47 75 61
	!hex 72 64 20 23 31 32 34 39 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d
	!hex 5b 31 35 31 38 2d 30 36 2d 30 33 20 30 30 3a 33 36 5d 20 66 61 6c
	!hex 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 31 30 2d 31 33 20
	!hex 32 33 3a 34 38 5d 20 47 75 61 72 64 20 23 33 31 33 37 20 62 65 67
	!hex 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 38 2d 30 38 20
	!hex 30 30 3a 30 31 5d 20 47 75 61 72 64 20 23 33 30 38 33 20 62 65 67
	!hex 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 32 2d 31 31 20
	!hex 30 30 3a 32 36 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31
	!hex 35 31 38 2d 30 32 2d 30 39 20 30 30 3a 31 32 5d 20 77 61 6b 65 73
	!hex 20 75 70 0d 5b 31 35 31 38 2d 31 30 2d 32 34 20 30 30 3a 34 34 5d
	!hex 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 35 2d 31 35 20
	!hex 30 30 3a 31 36 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31
	!hex 35 31 38 2d 31 30 2d 32 39 20 30 30 3a 30 31 5d 20 47 75 61 72 64
	!hex 20 23 33 31 31 39 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31
	!hex 35 31 38 2d 30 33 2d 31 39 20 30 30 3a 34 32 5d 20 77 61 6b 65 73
	!hex 20 75 70 0d 5b 31 35 31 38 2d 31 31 2d 30 38 20 30 30 3a 33 32 5d
	!hex 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 38
	!hex 2d 31 34 20 30 30 3a 30 30 5d 20 47 75 61 72 64 20 23 32 33 38 31
	!hex 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 31 30
	!hex 2d 30 35 20 32 33 3a 35 36 5d 20 47 75 61 72 64 20 23 38 39 20 62
	!hex 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 36 2d 32
	!hex 39 20 30 30 3a 33 38 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d
	!hex 5b 31 35 31 38 2d 31 30 2d 30 37 20 30 30 3a 35 36 5d 20 77 61 6b
	!hex 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 34 2d 31 31 20 30 30 3a 35
	!hex 34 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 37 2d 30
	!hex 34 20 30 30 3a 30 36 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d
	!hex 5b 31 35 31 38 2d 30 35 2d 30 31 20 30 30 3a 32 33 5d 20 77 61 6b
	!hex 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 34 2d 30 38 20 32 33 3a 35
	!hex 39 5d 20 47 75 61 72 64 20 23 31 36 30 31 20 62 65 67 69 6e 73 20
	!hex 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 32 2d 32 30 20 30 30 3a 30
	!hex 32 5d 20 47 75 61 72 64 20 23 32 35 37 39 20 62 65 67 69 6e 73 20
	!hex 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 33 2d 32 32 20 32 33 3a 35
	!hex 39 5d 20 47 75 61 72 64 20 23 32 33 38 31 20 62 65 67 69 6e 73 20
	!hex 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 37 2d 30 33 20 30 30 3a 32
	!hex 32 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d
	!hex 30 38 2d 30 38 20 32 33 3a 35 38 5d 20 47 75 61 72 64 20 23 34 33
	!hex 31 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30
	!hex 37 2d 31 30 20 30 30 3a 35 30 5d 20 77 61 6b 65 73 20 75 70 0d 5b
	!hex 31 35 31 38 2d 30 34 2d 30 31 20 32 33 3a 35 34 5d 20 47 75 61 72
	!hex 64 20 23 36 39 31 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31
	!hex 35 31 38 2d 31 30 2d 32 39 20 30 30 3a 34 32 5d 20 66 61 6c 6c 73
	!hex 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 31 30 2d 30 36 20 30 30
	!hex 3a 30 37 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31
	!hex 38 2d 30 38 2d 31 32 20 32 33 3a 35 39 5d 20 47 75 61 72 64 20 23
	!hex 32 33 38 31 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31
	!hex 38 2d 30 36 2d 32 35 20 30 30 3a 30 33 5d 20 47 75 61 72 64 20 23
	!hex 32 35 37 39 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31
	!hex 38 2d 30 38 2d 31 35 20 30 30 3a 34 37 5d 20 77 61 6b 65 73 20 75
	!hex 70 0d 5b 31 35 31 38 2d 30 33 2d 30 38 20 32 33 3a 35 36 5d 20 47
	!hex 75 61 72 64 20 23 33 31 33 37 20 62 65 67 69 6e 73 20 73 68 69 66
	!hex 74 0d 5b 31 35 31 38 2d 30 35 2d 30 36 20 30 30 3a 30 30 5d 20 66
	!hex 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 37 2d 32
	!hex 34 20 30 30 3a 30 34 5d 20 47 75 61 72 64 20 23 31 32 34 39 20 62
	!hex 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 32 2d 32
	!hex 36 20 30 30 3a 34 35 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31
	!hex 38 2d 31 30 2d 31 35 20 30 30 3a 30 30 5d 20 47 75 61 72 64 20 23
	!hex 32 35 37 39 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31
	!hex 38 2d 30 39 2d 31 36 20 30 30 3a 34 39 5d 20 66 61 6c 6c 73 20 61
	!hex 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 38 2d 30 38 20 30 30 3a 30
	!hex 38 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d
	!hex 31 31 2d 31 30 20 32 33 3a 35 34 5d 20 47 75 61 72 64 20 23 31 30
	!hex 39 37 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d
	!hex 30 36 2d 31 39 20 30 30 3a 30 34 5d 20 47 75 61 72 64 20 23 38 39
	!hex 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 31 31
	!hex 2d 30 31 20 30 30 3a 30 33 5d 20 47 75 61 72 64 20 23 37 39 37 20
	!hex 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 37 2d
	!hex 32 30 20 30 30 3a 34 31 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70
	!hex 0d 5b 31 35 31 38 2d 30 34 2d 30 32 20 30 30 3a 30 35 5d 20 66 61
	!hex 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 39 2d 31 38
	!hex 20 30 30 3a 34 38 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38
	!hex 2d 30 35 2d 33 30 20 30 30 3a 31 38 5d 20 66 61 6c 6c 73 20 61 73
	!hex 6c 65 65 70 0d 5b 31 35 31 38 2d 30 36 2d 30 34 20 30 30 3a 30 33
	!hex 5d 20 47 75 61 72 64 20 23 33 30 38 39 20 62 65 67 69 6e 73 20 73
	!hex 68 69 66 74 0d 5b 31 35 31 38 2d 31 30 2d 32 32 20 30 30 3a 31 33
	!hex 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30
	!hex 35 2d 32 33 20 30 30 3a 32 32 5d 20 66 61 6c 6c 73 20 61 73 6c 65
	!hex 65 70 0d 5b 31 35 31 38 2d 30 38 2d 32 34 20 30 30 3a 31 36 5d 20
	!hex 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 39 2d
	!hex 30 36 20 30 30 3a 30 37 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70
	!hex 0d 5b 31 35 31 38 2d 30 38 2d 31 36 20 30 30 3a 31 37 5d 20 66 61
	!hex 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 31 31 2d 30 38
	!hex 20 30 30 3a 34 32 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38
	!hex 2d 30 37 2d 32 34 20 30 30 3a 33 37 5d 20 77 61 6b 65 73 20 75 70
	!hex 0d 5b 31 35 31 38 2d 31 31 2d 31 35 20 30 30 3a 34 38 5d 20 66 61
	!hex 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 38 2d 30 36
	!hex 20 30 30 3a 35 33 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38
	!hex 2d 30 38 2d 31 31 20 30 30 3a 33 39 5d 20 77 61 6b 65 73 20 75 70
	!hex 0d 5b 31 35 31 38 2d 30 37 2d 31 32 20 30 30 3a 33 37 5d 20 66 61
	!hex 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 32 2d 31 35
	!hex 20 32 33 3a 34 36 5d 20 47 75 61 72 64 20 23 33 30 31 31 20 62 65
	!hex 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 32 2d 31 31
	!hex 20 30 30 3a 33 34 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38
	!hex 2d 30 34 2d 30 32 20 30 30 3a 35 37 5d 20 77 61 6b 65 73 20 75 70
	!hex 0d 5b 31 35 31 38 2d 31 30 2d 31 32 20 30 30 3a 33 33 5d 20 77 61
	!hex 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 36 2d 31 33 20 30 30 3a
	!hex 32 30 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 35 2d
	!hex 31 33 20 30 30 3a 30 32 5d 20 47 75 61 72 64 20 23 31 36 30 31 20
	!hex 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 33 2d
	!hex 30 35 20 32 33 3a 35 36 5d 20 47 75 61 72 64 20 23 33 31 33 37 20
	!hex 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 36 2d
	!hex 30 33 20 30 30 3a 35 34 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35
	!hex 31 38 2d 30 36 2d 32 33 20 30 30 3a 30 34 5d 20 47 75 61 72 64 20
	!hex 23 33 37 33 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31
	!hex 38 2d 30 34 2d 31 33 20 32 33 3a 35 37 5d 20 47 75 61 72 64 20 23
	!hex 33 31 33 37 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31
	!hex 38 2d 31 30 2d 31 33 20 30 30 3a 32 37 5d 20 66 61 6c 6c 73 20 61
	!hex 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 35 2d 31 34 20 30 30 3a 34
	!hex 36 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 31 30 2d 33
	!hex 31 20 30 30 3a 33 33 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d
	!hex 5b 31 35 31 38 2d 30 39 2d 32 36 20 30 30 3a 34 34 5d 20 77 61 6b
	!hex 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 36 2d 31 35 20 30 30 3a 30
	!hex 35 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d
	!hex 30 35 2d 32 31 20 30 30 3a 32 38 5d 20 66 61 6c 6c 73 20 61 73 6c
	!hex 65 65 70 0d 5b 31 35 31 38 2d 30 39 2d 32 38 20 30 30 3a 32 39 5d
	!hex 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 31 30
	!hex 2d 30 32 20 30 30 3a 34 33 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65
	!hex 70 0d 5b 31 35 31 38 2d 31 31 2d 31 35 20 30 30 3a 32 30 5d 20 77
	!hex 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 38 2d 30 37 20 30 30
	!hex 3a 30 30 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31
	!hex 38 2d 30 36 2d 30 32 20 32 33 3a 35 38 5d 20 47 75 61 72 64 20 23
	!hex 31 32 34 39 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31
	!hex 38 2d 30 38 2d 30 37 20 30 30 3a 35 37 5d 20 77 61 6b 65 73 20 75
	!hex 70 0d 5b 31 35 31 38 2d 30 38 2d 31 37 20 32 33 3a 34 39 5d 20 47
	!hex 75 61 72 64 20 23 37 39 37 20 62 65 67 69 6e 73 20 73 68 69 66 74
	!hex 0d 5b 31 35 31 38 2d 31 30 2d 31 38 20 32 33 3a 35 38 5d 20 47 75
	!hex 61 72 64 20 23 32 39 36 39 20 62 65 67 69 6e 73 20 73 68 69 66 74
	!hex 0d 5b 31 35 31 38 2d 30 33 2d 32 39 20 30 30 3a 34 38 5d 20 66 61
	!hex 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 31 31 2d 31 35
	!hex 20 30 30 3a 31 37 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b
	!hex 31 35 31 38 2d 30 37 2d 32 32 20 30 30 3a 33 30 5d 20 66 61 6c 6c
	!hex 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 31 30 2d 30 31 20 30
	!hex 30 3a 35 31 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35
	!hex 31 38 2d 30 35 2d 32 30 20 30 30 3a 35 32 5d 20 77 61 6b 65 73 20
	!hex 75 70 0d 5b 31 35 31 38 2d 30 33 2d 32 30 20 30 30 3a 33 39 5d 20
	!hex 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 33 2d
	!hex 32 38 20 30 30 3a 32 34 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35
	!hex 31 38 2d 30 37 2d 31 32 20 30 30 3a 35 36 5d 20 77 61 6b 65 73 20
	!hex 75 70 0d 5b 31 35 31 38 2d 30 35 2d 31 32 20 30 30 3a 33 37 5d 20
	!hex 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 32 2d 32 35 20 30
	!hex 30 3a 35 34 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35
	!hex 31 38 2d 30 39 2d 32 30 20 32 33 3a 35 39 5d 20 47 75 61 72 64 20
	!hex 23 33 31 33 37 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35
	!hex 31 38 2d 30 33 2d 32 34 20 30 30 3a 35 38 5d 20 77 61 6b 65 73 20
	!hex 75 70 0d 5b 31 35 31 38 2d 30 36 2d 30 32 20 30 30 3a 30 30 5d 20
	!hex 47 75 61 72 64 20 23 32 38 38 37 20 62 65 67 69 6e 73 20 73 68 69
	!hex 66 74 0d 5b 31 35 31 38 2d 30 37 2d 30 34 20 32 33 3a 35 37 5d 20
	!hex 47 75 61 72 64 20 23 33 30 38 33 20 62 65 67 69 6e 73 20 73 68 69
	!hex 66 74 0d 5b 31 35 31 38 2d 30 38 2d 32 31 20 30 30 3a 35 33 5d 20
	!hex 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 31 30 2d 30 36 20 30
	!hex 30 3a 34 32 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35
	!hex 31 38 2d 30 36 2d 30 38 20 30 30 3a 30 33 5d 20 47 75 61 72 64 20
	!hex 23 33 30 38 33 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35
	!hex 31 38 2d 31 30 2d 32 34 20 30 30 3a 32 31 5d 20 66 61 6c 6c 73 20
	!hex 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 34 2d 31 35 20 30 30 3a
	!hex 32 39 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38
	!hex 2d 30 39 2d 32 30 20 30 30 3a 32 36 5d 20 66 61 6c 6c 73 20 61 73
	!hex 6c 65 65 70 0d 5b 31 35 31 38 2d 30 35 2d 33 30 20 30 30 3a 32 34
	!hex 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 34 2d 31 32
	!hex 20 30 30 3a 35 36 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38
	!hex 2d 30 37 2d 31 30 20 30 30 3a 30 32 5d 20 47 75 61 72 64 20 23 34
	!hex 33 31 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d
	!hex 30 38 2d 31 36 20 30 30 3a 35 35 5d 20 66 61 6c 6c 73 20 61 73 6c
	!hex 65 65 70 0d 5b 31 35 31 38 2d 30 37 2d 32 35 20 30 30 3a 34 31 5d
	!hex 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 34
	!hex 2d 31 33 20 30 30 3a 31 33 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65
	!hex 70 0d 5b 31 35 31 38 2d 30 38 2d 32 32 20 30 30 3a 32 36 5d 20 77
	!hex 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 38 2d 30 39 20 30 30
	!hex 3a 35 37 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 38
	!hex 2d 31 38 20 30 30 3a 30 31 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65
	!hex 70 0d 5b 31 35 31 38 2d 30 37 2d 31 30 20 30 30 3a 33 33 5d 20 66
	!hex 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 34 2d 32
	!hex 38 20 30 30 3a 35 36 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31
	!hex 38 2d 30 34 2d 31 36 20 30 30 3a 30 32 5d 20 47 75 61 72 64 20 23
	!hex 31 32 34 39 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31
	!hex 38 2d 30 32 2d 32 31 20 30 30 3a 30 32 5d 20 47 75 61 72 64 20 23
	!hex 37 39 37 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38
	!hex 2d 30 35 2d 31 30 20 30 30 3a 35 39 5d 20 77 61 6b 65 73 20 75 70
	!hex 0d 5b 31 35 31 38 2d 30 38 2d 30 34 20 32 33 3a 35 36 5d 20 47 75
	!hex 61 72 64 20 23 33 30 38 33 20 62 65 67 69 6e 73 20 73 68 69 66 74
	!hex 0d 5b 31 35 31 38 2d 30 38 2d 33 31 20 30 30 3a 34 34 5d 20 66 61
	!hex 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 32 2d 30 34
	!hex 20 30 30 3a 33 32 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b
	!hex 31 35 31 38 2d 30 34 2d 30 36 20 30 30 3a 30 36 5d 20 66 61 6c 6c
	!hex 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 38 2d 32 34 20 30
	!hex 30 3a 33 37 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30
	!hex 36 2d 31 38 20 30 30 3a 35 39 5d 20 77 61 6b 65 73 20 75 70 0d 5b
	!hex 31 35 31 38 2d 31 31 2d 31 31 20 30 30 3a 30 37 5d 20 77 61 6b 65
	!hex 73 20 75 70 0d 5b 31 35 31 38 2d 30 39 2d 30 33 20 32 33 3a 35 37
	!hex 5d 20 47 75 61 72 64 20 23 32 38 37 39 20 62 65 67 69 6e 73 20 73
	!hex 68 69 66 74 0d 5b 31 35 31 38 2d 30 32 2d 31 34 20 30 30 3a 30 33
	!hex 5d 20 47 75 61 72 64 20 23 36 39 31 20 62 65 67 69 6e 73 20 73 68
	!hex 69 66 74 0d 5b 31 35 31 38 2d 30 36 2d 31 36 20 30 30 3a 33 31 5d
	!hex 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 38
	!hex 2d 32 38 20 30 30 3a 30 33 5d 20 47 75 61 72 64 20 23 31 36 30 31
	!hex 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 36
	!hex 2d 30 36 20 30 30 3a 31 36 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65
	!hex 70 0d 5b 31 35 31 38 2d 30 37 2d 31 32 20 30 30 3a 35 35 5d 20 66
	!hex 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 34 2d 30
	!hex 36 20 30 30 3a 34 35 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31
	!hex 38 2d 30 33 2d 31 39 20 30 30 3a 31 32 5d 20 66 61 6c 6c 73 20 61
	!hex 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 33 2d 32 31 20 30 30 3a 31
	!hex 33 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d
	!hex 30 34 2d 31 35 20 30 30 3a 30 30 5d 20 47 75 61 72 64 20 23 31 30
	!hex 33 39 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d
	!hex 30 39 2d 30 37 20 30 30 3a 31 30 5d 20 66 61 6c 6c 73 20 61 73 6c
	!hex 65 65 70 0d 5b 31 35 31 38 2d 30 38 2d 32 36 20 30 30 3a 34 38 5d
	!hex 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 36 2d 32 35 20
	!hex 30 30 3a 35 30 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d
	!hex 30 38 2d 32 32 20 30 30 3a 30 31 5d 20 66 61 6c 6c 73 20 61 73 6c
	!hex 65 65 70 0d 5b 31 35 31 38 2d 30 32 2d 30 37 20 30 30 3a 33 31 5d
	!hex 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 39 2d 32 32 20
	!hex 30 30 3a 32 39 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31
	!hex 35 31 38 2d 30 32 2d 31 31 20 30 30 3a 30 30 5d 20 47 75 61 72 64
	!hex 20 23 34 33 31 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35
	!hex 31 38 2d 30 35 2d 31 39 20 30 30 3a 30 34 5d 20 47 75 61 72 64 20
	!hex 23 33 33 31 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31
	!hex 38 2d 31 30 2d 32 35 20 30 30 3a 34 39 5d 20 66 61 6c 6c 73 20 61
	!hex 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 32 2d 30 33 20 30 30 3a 30
	!hex 33 5d 20 47 75 61 72 64 20 23 36 39 31 20 62 65 67 69 6e 73 20 73
	!hex 68 69 66 74 0d 5b 31 35 31 38 2d 30 32 2d 30 33 20 30 30 3a 32 38
	!hex 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 33 2d 32 39
	!hex 20 30 30 3a 31 31 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b
	!hex 31 35 31 38 2d 30 34 2d 31 30 20 32 33 3a 35 36 5d 20 47 75 61 72
	!hex 64 20 23 38 39 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35
	!hex 31 38 2d 30 34 2d 30 37 20 30 30 3a 30 32 5d 20 47 75 61 72 64 20
	!hex 23 31 36 30 31 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35
	!hex 31 38 2d 30 38 2d 33 31 20 30 30 3a 30 30 5d 20 47 75 61 72 64 20
	!hex 23 31 30 33 39 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35
	!hex 31 38 2d 30 38 2d 31 37 20 30 30 3a 32 38 5d 20 66 61 6c 6c 73 20
	!hex 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 32 2d 30 38 20 30 30 3a
	!hex 34 34 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 31 30 2d
	!hex 32 30 20 30 30 3a 34 32 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70
	!hex 0d 5b 31 35 31 38 2d 30 36 2d 32 31 20 30 30 3a 35 35 5d 20 77 61
	!hex 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 39 2d 32 32 20 30 30 3a
	!hex 34 36 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 36 2d
	!hex 30 39 20 30 30 3a 30 33 5d 20 47 75 61 72 64 20 23 34 33 31 20 62
	!hex 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 34 2d 32
	!hex 31 20 32 33 3a 34 37 5d 20 47 75 61 72 64 20 23 31 32 34 39 20 62
	!hex 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 35 2d 31
	!hex 34 20 30 30 3a 30 34 5d 20 47 75 61 72 64 20 23 38 39 20 62 65 67
	!hex 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 31 31 2d 31 39 20
	!hex 30 30 3a 35 31 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31
	!hex 35 31 38 2d 30 37 2d 30 31 20 30 30 3a 30 34 5d 20 47 75 61 72 64
	!hex 20 23 32 38 37 39 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31
	!hex 35 31 38 2d 30 38 2d 32 32 20 30 30 3a 35 35 5d 20 77 61 6b 65 73
	!hex 20 75 70 0d 5b 31 35 31 38 2d 30 34 2d 30 35 20 30 30 3a 34 35 5d
	!hex 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 37
	!hex 2d 32 38 20 32 33 3a 35 37 5d 20 47 75 61 72 64 20 23 38 39 20 62
	!hex 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 38 2d 31
	!hex 35 20 30 30 3a 34 30 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d
	!hex 5b 31 35 31 38 2d 30 35 2d 30 31 20 30 30 3a 34 32 5d 20 77 61 6b
	!hex 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 32 2d 31 36 20 30 30 3a 34
	!hex 33 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d
	!hex 31 30 2d 32 39 20 30 30 3a 34 38 5d 20 77 61 6b 65 73 20 75 70 0d
	!hex 5b 31 35 31 38 2d 30 32 2d 32 30 20 30 30 3a 33 33 5d 20 66 61 6c
	!hex 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 32 2d 30 39 20
	!hex 32 33 3a 35 39 5d 20 47 75 61 72 64 20 23 33 31 33 37 20 62 65 67
	!hex 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 39 2d 32 37 20
	!hex 32 33 3a 35 39 5d 20 47 75 61 72 64 20 23 33 31 31 39 20 62 65 67
	!hex 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 33 2d 30 33 20
	!hex 30 30 3a 35 34 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31
	!hex 35 31 38 2d 30 35 2d 33 30 20 30 30 3a 32 37 5d 20 66 61 6c 6c 73
	!hex 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 31 30 2d 30 31 20 30 30
	!hex 3a 33 37 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31
	!hex 38 2d 30 35 2d 33 30 20 30 30 3a 33 33 5d 20 66 61 6c 6c 73 20 61
	!hex 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 38 2d 31 34 20 30 30 3a 33
	!hex 30 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d
	!hex 30 39 2d 30 38 20 30 30 3a 30 34 5d 20 47 75 61 72 64 20 23 32 35
	!hex 37 39 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d
	!hex 30 37 2d 30 38 20 30 30 3a 30 35 5d 20 77 61 6b 65 73 20 75 70 0d
	!hex 5b 31 35 31 38 2d 30 34 2d 31 33 20 30 30 3a 31 35 5d 20 77 61 6b
	!hex 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 35 2d 32 31 20 30 30 3a 30
	!hex 30 5d 20 47 75 61 72 64 20 23 32 38 38 37 20 62 65 67 69 6e 73 20
	!hex 73 68 69 66 74 0d 5b 31 35 31 38 2d 31 31 2d 30 33 20 30 30 3a 33
	!hex 32 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d
	!hex 30 39 2d 30 39 20 30 30 3a 35 36 5d 20 77 61 6b 65 73 20 75 70 0d
	!hex 5b 31 35 31 38 2d 30 34 2d 32 34 20 30 30 3a 32 31 5d 20 66 61 6c
	!hex 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 33 2d 31 34 20
	!hex 30 30 3a 35 38 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d
	!hex 31 31 2d 31 39 20 30 30 3a 35 33 5d 20 77 61 6b 65 73 20 75 70 0d
	!hex 5b 31 35 31 38 2d 30 35 2d 30 37 20 30 30 3a 34 38 5d 20 77 61 6b
	!hex 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 38 2d 30 34 20 30 30 3a 30
	!hex 30 5d 20 47 75 61 72 64 20 23 33 31 33 37 20 62 65 67 69 6e 73 20
	!hex 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 35 2d 32 35 20 30 30 3a 30
	!hex 34 5d 20 47 75 61 72 64 20 23 37 39 37 20 62 65 67 69 6e 73 20 73
	!hex 68 69 66 74 0d 5b 31 35 31 38 2d 31 30 2d 32 39 20 30 30 3a 33 32
	!hex 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 34 2d 32 30
	!hex 20 30 30 3a 30 30 5d 20 47 75 61 72 64 20 23 31 35 35 39 20 62 65
	!hex 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 34 2d 31 35
	!hex 20 30 30 3a 33 35 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38
	!hex 2d 30 37 2d 32 32 20 30 30 3a 33 38 5d 20 66 61 6c 6c 73 20 61 73
	!hex 6c 65 65 70 0d 5b 31 35 31 38 2d 30 37 2d 32 31 20 30 30 3a 34 32
	!hex 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 39 2d 32 37
	!hex 20 30 30 3a 33 39 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b
	!hex 31 35 31 38 2d 30 38 2d 32 39 20 30 30 3a 34 37 5d 20 66 61 6c 6c
	!hex 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 34 2d 31 33 20 30
	!hex 30 3a 34 31 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30
	!hex 33 2d 31 34 20 32 33 3a 35 39 5d 20 47 75 61 72 64 20 23 33 31 33
	!hex 37 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30
	!hex 36 2d 32 30 20 30 30 3a 32 31 5d 20 66 61 6c 6c 73 20 61 73 6c 65
	!hex 65 70 0d 5b 31 35 31 38 2d 30 34 2d 32 32 20 32 33 3a 35 36 5d 20
	!hex 47 75 61 72 64 20 23 33 30 31 31 20 62 65 67 69 6e 73 20 73 68 69
	!hex 66 74 0d 5b 31 35 31 38 2d 30 38 2d 31 31 20 30 30 3a 30 32 5d 20
	!hex 47 75 61 72 64 20 23 33 37 33 20 62 65 67 69 6e 73 20 73 68 69 66
	!hex 74 0d 5b 31 35 31 38 2d 30 33 2d 31 38 20 30 30 3a 34 38 5d 20 66
	!hex 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 35 2d 32
	!hex 32 20 30 30 3a 33 39 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31
	!hex 38 2d 30 32 2d 32 37 20 30 30 3a 35 32 5d 20 77 61 6b 65 73 20 75
	!hex 70 0d 5b 31 35 31 38 2d 30 39 2d 31 32 20 30 30 3a 30 30 5d 20 47
	!hex 75 61 72 64 20 23 33 31 31 39 20 62 65 67 69 6e 73 20 73 68 69 66
	!hex 74 0d 5b 31 35 31 38 2d 30 34 2d 32 37 20 30 30 3a 30 34 5d 20 47
	!hex 75 61 72 64 20 23 33 30 31 31 20 62 65 67 69 6e 73 20 73 68 69 66
	!hex 74 0d 5b 31 35 31 38 2d 30 33 2d 31 30 20 30 30 3a 33 34 5d 20 77
	!hex 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 35 2d 31 30 20 30 30
	!hex 3a 34 39 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31
	!hex 38 2d 30 34 2d 32 35 20 30 30 3a 35 35 5d 20 77 61 6b 65 73 20 75
	!hex 70 0d 5b 31 35 31 38 2d 30 35 2d 31 38 20 30 30 3a 30 30 5d 20 66
	!hex 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 38 2d 32
	!hex 30 20 32 33 3a 35 38 5d 20 47 75 61 72 64 20 23 33 37 33 20 62 65
	!hex 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 35 2d 32 39
	!hex 20 30 30 3a 31 32 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b
	!hex 31 35 31 38 2d 30 34 2d 32 31 20 30 30 3a 30 33 5d 20 66 61 6c 6c
	!hex 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 39 2d 30 35 20 30
	!hex 30 3a 32 37 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35
	!hex 31 38 2d 30 35 2d 31 36 20 30 30 3a 31 37 5d 20 77 61 6b 65 73 20
	!hex 75 70 0d 5b 31 35 31 38 2d 30 33 2d 32 30 20 30 30 3a 34 36 5d 20
	!hex 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 33 2d 30 36 20 30
	!hex 30 3a 32 39 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30
	!hex 37 2d 31 35 20 30 30 3a 33 35 5d 20 77 61 6b 65 73 20 75 70 0d 5b
	!hex 31 35 31 38 2d 30 34 2d 32 38 20 32 33 3a 35 31 5d 20 47 75 61 72
	!hex 64 20 23 31 36 30 31 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b
	!hex 31 35 31 38 2d 30 36 2d 31 37 20 30 30 3a 32 39 5d 20 66 61 6c 6c
	!hex 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 36 2d 32 37 20 30
	!hex 30 3a 30 38 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35
	!hex 31 38 2d 30 39 2d 32 39 20 30 30 3a 35 35 5d 20 77 61 6b 65 73 20
	!hex 75 70 0d 5b 31 35 31 38 2d 31 31 2d 32 32 20 32 33 3a 35 37 5d 20
	!hex 47 75 61 72 64 20 23 33 31 33 37 20 62 65 67 69 6e 73 20 73 68 69
	!hex 66 74 0d 5b 31 35 31 38 2d 30 32 2d 30 34 20 30 30 3a 34 36 5d 20
	!hex 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 35 2d 30 31 20 30
	!hex 30 3a 30 39 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35
	!hex 31 38 2d 30 32 2d 31 32 20 30 30 3a 32 33 5d 20 77 61 6b 65 73 20
	!hex 75 70 0d 5b 31 35 31 38 2d 30 38 2d 30 31 20 30 30 3a 30 32 5d 20
	!hex 47 75 61 72 64 20 23 31 30 39 37 20 62 65 67 69 6e 73 20 73 68 69
	!hex 66 74 0d 5b 31 35 31 38 2d 30 33 2d 30 36 20 30 30 3a 32 37 5d 20
	!hex 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 31 31 2d
	!hex 31 34 20 30 30 3a 35 30 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35
	!hex 31 38 2d 30 35 2d 31 35 20 30 30 3a 32 38 5d 20 77 61 6b 65 73 20
	!hex 75 70 0d 5b 31 35 31 38 2d 30 39 2d 31 34 20 30 30 3a 34 37 5d 20
	!hex 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 34 2d 30 36 20 30
	!hex 30 3a 33 36 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35
	!hex 31 38 2d 30 35 2d 31 37 20 30 30 3a 33 36 5d 20 66 61 6c 6c 73 20
	!hex 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 33 2d 31 30 20 30 30 3a
	!hex 34 38 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 34 2d
	!hex 30 39 20 30 30 3a 34 31 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35
	!hex 31 38 2d 31 31 2d 31 38 20 30 30 3a 33 34 5d 20 66 61 6c 6c 73 20
	!hex 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 32 2d 30 37 20 30 30 3a
	!hex 33 39 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38
	!hex 2d 30 32 2d 32 37 20 30 30 3a 30 33 5d 20 66 61 6c 6c 73 20 61 73
	!hex 6c 65 65 70 0d 5b 31 35 31 38 2d 30 38 2d 31 38 20 32 33 3a 35 39
	!hex 5d 20 47 75 61 72 64 20 23 33 33 31 20 62 65 67 69 6e 73 20 73 68
	!hex 69 66 74 0d 5b 31 35 31 38 2d 31 31 2d 32 33 20 30 30 3a 35 30 5d
	!hex 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 34 2d 31 37 20
	!hex 30 30 3a 30 30 5d 20 47 75 61 72 64 20 23 31 36 30 31 20 62 65 67
	!hex 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 32 2d 32 31 20
	!hex 30 30 3a 33 36 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31
	!hex 35 31 38 2d 31 30 2d 30 34 20 30 30 3a 35 34 5d 20 77 61 6b 65 73
	!hex 20 75 70 0d 5b 31 35 31 38 2d 30 33 2d 30 36 20 30 30 3a 33 39 5d
	!hex 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 39
	!hex 2d 30 37 20 30 30 3a 35 34 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31
	!hex 35 31 38 2d 30 37 2d 32 31 20 30 30 3a 31 35 5d 20 66 61 6c 6c 73
	!hex 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 34 2d 31 32 20 30 30
	!hex 3a 35 31 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31
	!hex 38 2d 31 31 2d 31 38 20 30 30 3a 33 30 5d 20 77 61 6b 65 73 20 75
	!hex 70 0d 5b 31 35 31 38 2d 30 37 2d 31 34 20 30 30 3a 34 33 5d 20 66
	!hex 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 37 2d 32
	!hex 32 20 32 33 3a 35 39 5d 20 47 75 61 72 64 20 23 31 36 30 31 20 62
	!hex 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 33 2d 31
	!hex 35 20 30 30 3a 32 34 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d
	!hex 5b 31 35 31 38 2d 30 32 2d 32 38 20 32 33 3a 35 37 5d 20 47 75 61
	!hex 72 64 20 23 32 33 38 31 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d
	!hex 5b 31 35 31 38 2d 30 37 2d 32 35 20 30 30 3a 30 30 5d 20 47 75 61
	!hex 72 64 20 23 32 39 36 39 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d
	!hex 5b 31 35 31 38 2d 31 30 2d 32 36 20 30 30 3a 30 33 5d 20 47 75 61
	!hex 72 64 20 23 31 35 35 39 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d
	!hex 5b 31 35 31 38 2d 31 30 2d 33 30 20 30 30 3a 34 37 5d 20 66 61 6c
	!hex 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 36 2d 30 33 20
	!hex 30 30 3a 31 33 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31
	!hex 35 31 38 2d 30 35 2d 32 37 20 30 30 3a 33 37 5d 20 66 61 6c 6c 73
	!hex 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 36 2d 31 33 20 30 30
	!hex 3a 33 33 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31
	!hex 38 2d 30 37 2d 31 38 20 30 30 3a 32 30 5d 20 66 61 6c 6c 73 20 61
	!hex 73 6c 65 65 70 0d 5b 31 35 31 38 2d 31 30 2d 31 33 20 30 30 3a 34
	!hex 39 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 36 2d 30
	!hex 35 20 30 30 3a 30 30 5d 20 47 75 61 72 64 20 23 32 35 37 39 20 62
	!hex 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 39 2d 30
	!hex 31 20 32 33 3a 35 36 5d 20 47 75 61 72 64 20 23 33 30 38 33 20 62
	!hex 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 35 2d 30
	!hex 37 20 30 30 3a 30 32 5d 20 47 75 61 72 64 20 23 33 30 38 39 20 62
	!hex 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 37 2d 32
	!hex 32 20 30 30 3a 35 39 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31
	!hex 38 2d 30 36 2d 31 38 20 30 30 3a 34 38 5d 20 77 61 6b 65 73 20 75
	!hex 70 0d 5b 31 35 31 38 2d 30 35 2d 32 33 20 30 30 3a 33 33 5d 20 66
	!hex 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 38 2d 30
	!hex 38 20 30 30 3a 31 32 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31
	!hex 38 2d 30 39 2d 30 38 20 30 30 3a 31 32 5d 20 66 61 6c 6c 73 20 61
	!hex 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 37 2d 31 35 20 30 30 3a 31
	!hex 36 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d
	!hex 31 30 2d 33 31 20 30 30 3a 30 31 5d 20 47 75 61 72 64 20 23 33 31
	!hex 31 39 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d
	!hex 30 38 2d 32 38 20 30 30 3a 32 35 5d 20 66 61 6c 6c 73 20 61 73 6c
	!hex 65 65 70 0d 5b 31 35 31 38 2d 31 30 2d 32 30 20 30 30 3a 34 36 5d
	!hex 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 37 2d 31 39 20
	!hex 30 30 3a 33 37 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d
	!hex 30 36 2d 31 36 20 30 30 3a 35 38 5d 20 77 61 6b 65 73 20 75 70 0d
	!hex 5b 31 35 31 38 2d 30 36 2d 31 31 20 32 33 3a 35 38 5d 20 47 75 61
	!hex 72 64 20 23 33 30 38 39 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d
	!hex 5b 31 35 31 38 2d 30 34 2d 30 37 20 30 30 3a 35 32 5d 20 77 61 6b
	!hex 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 39 2d 32 35 20 30 30 3a 35
	!hex 37 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d
	!hex 30 39 2d 30 34 20 32 33 3a 35 38 5d 20 47 75 61 72 64 20 23 36 39
	!hex 31 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30
	!hex 35 2d 31 31 20 30 30 3a 33 32 5d 20 66 61 6c 6c 73 20 61 73 6c 65
	!hex 65 70 0d 5b 31 35 31 38 2d 30 37 2d 30 36 20 30 30 3a 32 32 5d 20
	!hex 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 31 30 2d 30 34 20 30
	!hex 30 3a 33 38 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35
	!hex 31 38 2d 30 39 2d 31 36 20 30 30 3a 35 35 5d 20 77 61 6b 65 73 20
	!hex 75 70 0d 5b 31 35 31 38 2d 31 30 2d 32 34 20 32 33 3a 35 38 5d 20
	!hex 47 75 61 72 64 20 23 33 30 38 33 20 62 65 67 69 6e 73 20 73 68 69
	!hex 66 74 0d 5b 31 35 31 38 2d 30 33 2d 32 39 20 30 30 3a 33 32 5d 20
	!hex 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 32 2d 32 34 20 30
	!hex 30 3a 30 32 5d 20 47 75 61 72 64 20 23 32 33 38 31 20 62 65 67 69
	!hex 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 37 2d 30 38 20 32
	!hex 33 3a 35 36 5d 20 47 75 61 72 64 20 23 33 31 31 39 20 62 65 67 69
	!hex 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 38 2d 30 33 20 30
	!hex 30 3a 33 31 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35
	!hex 31 38 2d 31 31 2d 32 32 20 30 30 3a 30 39 5d 20 66 61 6c 6c 73 20
	!hex 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 32 2d 30 38 20 30 30 3a
	!hex 31 36 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38
	!hex 2d 30 38 2d 31 33 20 30 30 3a 32 33 5d 20 77 61 6b 65 73 20 75 70
	!hex 0d 5b 31 35 31 38 2d 30 37 2d 30 38 20 30 30 3a 35 38 5d 20 77 61
	!hex 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 39 2d 32 32 20 30 30 3a
	!hex 35 33 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38
	!hex 2d 30 32 2d 31 36 20 30 30 3a 35 32 5d 20 77 61 6b 65 73 20 75 70
	!hex 0d 5b 31 35 31 38 2d 30 35 2d 32 39 20 32 33 3a 35 36 5d 20 47 75
	!hex 61 72 64 20 23 38 39 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b
	!hex 31 35 31 38 2d 30 39 2d 32 35 20 30 30 3a 35 38 5d 20 77 61 6b 65
	!hex 73 20 75 70 0d 5b 31 35 31 38 2d 30 36 2d 31 35 20 30 30 3a 34 34
	!hex 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 31 30 2d 31 37
	!hex 20 30 30 3a 35 35 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38
	!hex 2d 30 33 2d 30 35 20 30 30 3a 30 35 5d 20 66 61 6c 6c 73 20 61 73
	!hex 6c 65 65 70 0d 5b 31 35 31 38 2d 30 37 2d 31 31 20 30 30 3a 31 30
	!hex 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30
	!hex 35 2d 30 32 20 30 30 3a 30 33 5d 20 47 75 61 72 64 20 23 31 36 30
	!hex 31 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30
	!hex 34 2d 30 39 20 30 30 3a 32 30 5d 20 66 61 6c 6c 73 20 61 73 6c 65
	!hex 65 70 0d 5b 31 35 31 38 2d 30 35 2d 30 34 20 30 30 3a 35 30 5d 20
	!hex 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 37 2d 32 38 20 30
	!hex 30 3a 30 36 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35
	!hex 31 38 2d 30 39 2d 30 39 20 32 33 3a 35 37 5d 20 47 75 61 72 64 20
	!hex 23 31 36 30 31 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35
	!hex 31 38 2d 30 39 2d 33 30 20 30 30 3a 31 38 5d 20 66 61 6c 6c 73 20
	!hex 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 31 30 2d 31 30 20 32 33 3a
	!hex 35 38 5d 20 47 75 61 72 64 20 23 32 38 38 37 20 62 65 67 69 6e 73
	!hex 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 31 31 2d 30 39 20 30 30 3a
	!hex 35 38 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 32 2d
	!hex 31 30 20 30 30 3a 35 30 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70
	!hex 0d 5b 31 35 31 38 2d 31 30 2d 33 30 20 30 30 3a 35 30 5d 20 77 61
	!hex 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 31 30 2d 32 31 20 30 30 3a
	!hex 30 31 5d 20 47 75 61 72 64 20 23 31 35 35 39 20 62 65 67 69 6e 73
	!hex 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 34 2d 32 36 20 30 30 3a
	!hex 35 38 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 31 31 2d
	!hex 31 39 20 32 33 3a 35 39 5d 20 47 75 61 72 64 20 23 32 33 38 31 20
	!hex 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 31 30 2d
	!hex 31 39 20 30 30 3a 35 39 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35
	!hex 31 38 2d 30 37 2d 31 36 20 30 30 3a 31 31 5d 20 66 61 6c 6c 73 20
	!hex 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 34 2d 31 34 20 30 30 3a
	!hex 34 36 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 37 2d
	!hex 31 35 20 30 30 3a 35 32 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70
	!hex 0d 5b 31 35 31 38 2d 30 37 2d 33 31 20 30 30 3a 31 38 5d 20 66 61
	!hex 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 37 2d 30 36
	!hex 20 32 33 3a 35 38 5d 20 47 75 61 72 64 20 23 33 37 33 20 62 65 67
	!hex 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 33 2d 31 30 20
	!hex 30 30 3a 31 35 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31
	!hex 35 31 38 2d 30 35 2d 32 32 20 30 30 3a 32 36 5d 20 66 61 6c 6c 73
	!hex 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 31 30 2d 32 30 20 30 30
	!hex 3a 32 34 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31
	!hex 38 2d 30 34 2d 31 30 20 30 30 3a 30 30 5d 20 47 75 61 72 64 20 23
	!hex 32 31 33 37 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31
	!hex 38 2d 30 35 2d 33 31 20 30 30 3a 32 37 5d 20 66 61 6c 6c 73 20 61
	!hex 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 33 2d 30 37 20 30 30 3a 30
	!hex 37 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d
	!hex 31 30 2d 32 37 20 30 30 3a 34 34 5d 20 77 61 6b 65 73 20 75 70 0d
	!hex 5b 31 35 31 38 2d 30 32 2d 32 31 20 30 30 3a 35 33 5d 20 77 61 6b
	!hex 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 33 2d 31 31 20 30 30 3a 34
	!hex 38 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 34 2d 31
	!hex 31 20 32 33 3a 35 38 5d 20 47 75 61 72 64 20 23 33 33 31 20 62 65
	!hex 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 33 2d 31 38
	!hex 20 30 30 3a 30 34 5d 20 47 75 61 72 64 20 23 33 30 38 33 20 62 65
	!hex 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 31 31 2d 30 32
	!hex 20 30 30 3a 30 33 5d 20 47 75 61 72 64 20 23 32 38 38 37 20 62 65
	!hex 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 31 30 2d 31 39
	!hex 20 30 30 3a 32 39 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38
	!hex 2d 31 31 2d 30 36 20 30 30 3a 35 33 5d 20 77 61 6b 65 73 20 75 70
	!hex 0d 5b 31 35 31 38 2d 30 32 2d 32 32 20 30 30 3a 33 39 5d 20 77 61
	!hex 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 31 30 2d 32 33 20 30 30 3a
	!hex 31 35 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38
	!hex 2d 30 32 2d 31 37 20 30 30 3a 35 30 5d 20 77 61 6b 65 73 20 75 70
	!hex 0d 5b 31 35 31 38 2d 30 32 2d 32 33 20 30 30 3a 34 34 5d 20 66 61
	!hex 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 34 2d 30 34
	!hex 20 30 30 3a 30 33 5d 20 47 75 61 72 64 20 23 38 39 20 62 65 67 69
	!hex 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 31 30 2d 31 37 20 32
	!hex 33 3a 35 39 5d 20 47 75 61 72 64 20 23 31 32 34 39 20 62 65 67 69
	!hex 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 32 2d 31 38 20 30
	!hex 30 3a 33 33 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30
	!hex 36 2d 30 34 20 30 30 3a 34 36 5d 20 66 61 6c 6c 73 20 61 73 6c 65
	!hex 65 70 0d 5b 31 35 31 38 2d 30 36 2d 31 32 20 30 30 3a 32 32 5d 20
	!hex 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 31 30 2d
	!hex 31 32 20 30 30 3a 30 31 5d 20 47 75 61 72 64 20 23 32 38 38 37 20
	!hex 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 35 2d
	!hex 30 31 20 30 30 3a 33 32 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70
	!hex 0d 5b 31 35 31 38 2d 30 33 2d 31 33 20 30 30 3a 30 31 5d 20 47 75
	!hex 61 72 64 20 23 33 37 33 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d
	!hex 5b 31 35 31 38 2d 31 31 2d 32 31 20 30 30 3a 33 31 5d 20 66 61 6c
	!hex 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 33 2d 32 38 20
	!hex 30 30 3a 30 34 5d 20 47 75 61 72 64 20 23 36 39 31 20 62 65 67 69
	!hex 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 31 30 2d 31 31 20 30
	!hex 30 3a 33 33 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35
	!hex 31 38 2d 30 34 2d 32 34 20 30 30 3a 35 35 5d 20 77 61 6b 65 73 20
	!hex 75 70 0d 5b 31 35 31 38 2d 30 35 2d 31 36 20 30 30 3a 31 34 5d 20
	!hex 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 36 2d
	!hex 32 35 20 30 30 3a 31 37 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70
	!hex 0d 5b 31 35 31 38 2d 31 30 2d 31 39 20 30 30 3a 32 36 5d 20 66 61
	!hex 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 36 2d 30 33
	!hex 20 30 30 3a 32 36 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b
	!hex 31 35 31 38 2d 30 36 2d 32 39 20 30 30 3a 34 33 5d 20 77 61 6b 65
	!hex 73 20 75 70 0d 5b 31 35 31 38 2d 30 37 2d 30 32 20 30 30 3a 30 32
	!hex 5d 20 47 75 61 72 64 20 23 32 38 37 39 20 62 65 67 69 6e 73 20 73
	!hex 68 69 66 74 0d 5b 31 35 31 38 2d 31 31 2d 30 37 20 30 30 3a 33 38
	!hex 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 39 2d 32 31
	!hex 20 30 30 3a 30 37 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b
	!hex 31 35 31 38 2d 30 35 2d 30 32 20 30 30 3a 33 32 5d 20 66 61 6c 6c
	!hex 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 39 2d 31 36 20 30
	!hex 30 3a 30 30 5d 20 47 75 61 72 64 20 23 32 35 37 39 20 62 65 67 69
	!hex 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 38 2d 31 30 20 30
	!hex 30 3a 30 34 5d 20 47 75 61 72 64 20 23 33 30 38 39 20 62 65 67 69
	!hex 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 31 30 2d 32 33 20 30
	!hex 30 3a 32 34 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30
	!hex 32 2d 32 31 20 32 33 3a 35 38 5d 20 47 75 61 72 64 20 23 31 30 39
	!hex 37 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30
	!hex 36 2d 32 37 20 30 30 3a 35 39 5d 20 77 61 6b 65 73 20 75 70 0d 5b
	!hex 31 35 31 38 2d 30 37 2d 31 30 20 32 33 3a 35 39 5d 20 47 75 61 72
	!hex 64 20 23 31 35 35 39 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b
	!hex 31 35 31 38 2d 30 38 2d 30 34 20 30 30 3a 34 37 5d 20 77 61 6b 65
	!hex 73 20 75 70 0d 5b 31 35 31 38 2d 30 36 2d 30 33 20 30 30 3a 31 39
	!hex 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 34 2d 30 32
	!hex 20 30 30 3a 34 38 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b
	!hex 31 35 31 38 2d 30 34 2d 31 32 20 30 30 3a 34 32 5d 20 77 61 6b 65
	!hex 73 20 75 70 0d 5b 31 35 31 38 2d 30 32 2d 32 38 20 30 30 3a 32 38
	!hex 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30
	!hex 38 2d 32 35 20 32 33 3a 35 32 5d 20 47 75 61 72 64 20 23 32 35 37
	!hex 39 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30
	!hex 35 2d 32 35 20 30 30 3a 35 36 5d 20 77 61 6b 65 73 20 75 70 0d 5b
	!hex 31 35 31 38 2d 30 36 2d 32 32 20 30 30 3a 35 35 5d 20 77 61 6b 65
	!hex 73 20 75 70 0d 5b 31 35 31 38 2d 30 32 2d 31 30 20 30 30 3a 35 35
	!hex 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30
	!hex 33 2d 32 34 20 32 33 3a 35 30 5d 20 47 75 61 72 64 20 23 33 37 33
	!hex 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 31 31
	!hex 2d 30 39 20 30 30 3a 32 35 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65
	!hex 70 0d 5b 31 35 31 38 2d 30 34 2d 32 39 20 30 30 3a 31 30 5d 20 77
	!hex 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 36 2d 32 39 20 32 33
	!hex 3a 35 36 5d 20 47 75 61 72 64 20 23 32 39 36 39 20 62 65 67 69 6e
	!hex 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 31 30 2d 32 32 20 30 30
	!hex 3a 34 37 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 37
	!hex 2d 30 33 20 32 33 3a 35 36 5d 20 47 75 61 72 64 20 23 34 33 31 20
	!hex 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 39 2d
	!hex 32 37 20 30 30 3a 30 33 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70
	!hex 0d 5b 31 35 31 38 2d 30 37 2d 31 33 20 30 30 3a 33 32 5d 20 66 61
	!hex 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 33 2d 32 32
	!hex 20 30 30 3a 35 36 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38
	!hex 2d 30 35 2d 31 37 20 30 30 3a 31 33 5d 20 66 61 6c 6c 73 20 61 73
	!hex 6c 65 65 70 0d 5b 31 35 31 38 2d 30 37 2d 32 37 20 32 33 3a 35 38
	!hex 5d 20 47 75 61 72 64 20 23 32 33 38 31 20 62 65 67 69 6e 73 20 73
	!hex 68 69 66 74 0d 5b 31 35 31 38 2d 30 34 2d 32 32 20 30 30 3a 33 36
	!hex 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30
	!hex 32 2d 30 38 20 32 33 3a 34 36 5d 20 47 75 61 72 64 20 23 33 30 38
	!hex 33 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30
	!hex 32 2d 31 33 20 30 30 3a 34 36 5d 20 66 61 6c 6c 73 20 61 73 6c 65
	!hex 65 70 0d 5b 31 35 31 38 2d 30 39 2d 30 37 20 30 30 3a 34 33 5d 20
	!hex 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 36 2d
	!hex 31 32 20 30 30 3a 34 32 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35
	!hex 31 38 2d 30 35 2d 31 37 20 30 30 3a 30 31 5d 20 77 61 6b 65 73 20
	!hex 75 70 0d 5b 31 35 31 38 2d 31 30 2d 30 35 20 30 30 3a 35 39 5d 20
	!hex 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 32 2d 31 37 20 30
	!hex 30 3a 33 30 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30
	!hex 38 2d 32 31 20 30 30 3a 34 35 5d 20 66 61 6c 6c 73 20 61 73 6c 65
	!hex 65 70 0d 5b 31 35 31 38 2d 30 33 2d 31 30 20 30 30 3a 30 39 5d 20
	!hex 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 39 2d 32 39 20 30
	!hex 30 3a 33 37 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35
	!hex 31 38 2d 30 36 2d 30 35 20 30 30 3a 31 33 5d 20 66 61 6c 6c 73 20
	!hex 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 36 2d 32 36 20 30 30 3a
	!hex 30 31 5d 20 47 75 61 72 64 20 23 35 36 33 20 62 65 67 69 6e 73 20
	!hex 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 35 2d 32 36 20 30 30 3a 31
	!hex 34 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d
	!hex 30 36 2d 31 36 20 30 30 3a 30 30 5d 20 47 75 61 72 64 20 23 33 37
	!hex 33 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30
	!hex 33 2d 33 30 20 30 30 3a 34 31 5d 20 66 61 6c 6c 73 20 61 73 6c 65
	!hex 65 70 0d 5b 31 35 31 38 2d 30 37 2d 32 32 20 30 30 3a 30 32 5d 20
	!hex 47 75 61 72 64 20 23 36 39 31 20 62 65 67 69 6e 73 20 73 68 69 66
	!hex 74 0d 5b 31 35 31 38 2d 30 32 2d 32 36 20 30 30 3a 35 36 5d 20 77
	!hex 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 32 2d 32 34 20 30 30
	!hex 3a 32 39 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31
	!hex 38 2d 31 31 2d 31 35 20 30 30 3a 33 33 5d 20 66 61 6c 6c 73 20 61
	!hex 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 39 2d 32 31 20 32 33 3a 35
	!hex 38 5d 20 47 75 61 72 64 20 23 32 33 38 31 20 62 65 67 69 6e 73 20
	!hex 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 32 2d 30 37 20 30 30 3a 32
	!hex 36 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d
	!hex 30 35 2d 32 36 20 30 30 3a 34 36 5d 20 77 61 6b 65 73 20 75 70 0d
	!hex 5b 31 35 31 38 2d 31 31 2d 32 31 20 30 30 3a 35 31 5d 20 77 61 6b
	!hex 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 34 2d 31 38 20 32 33 3a 35
	!hex 39 5d 20 47 75 61 72 64 20 23 31 32 34 39 20 62 65 67 69 6e 73 20
	!hex 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 38 2d 32 38 20 32 33 3a 35
	!hex 36 5d 20 47 75 61 72 64 20 23 31 35 35 39 20 62 65 67 69 6e 73 20
	!hex 73 68 69 66 74 0d 5b 31 35 31 38 2d 31 31 2d 30 35 20 30 30 3a 30
	!hex 33 5d 20 47 75 61 72 64 20 23 32 38 38 37 20 62 65 67 69 6e 73 20
	!hex 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 38 2d 30 31 20 30 30 3a 35
	!hex 37 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d
	!hex 31 30 2d 31 39 20 30 30 3a 34 31 5d 20 66 61 6c 6c 73 20 61 73 6c
	!hex 65 65 70 0d 5b 31 35 31 38 2d 30 35 2d 30 36 20 30 30 3a 32 32 5d
	!hex 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 32
	!hex 2d 31 37 20 30 30 3a 30 31 5d 20 47 75 61 72 64 20 23 34 33 31 20
	!hex 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 39 2d
	!hex 33 30 20 32 33 3a 35 37 5d 20 47 75 61 72 64 20 23 34 33 31 20 62
	!hex 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 31 31 2d 31
	!hex 37 20 30 30 3a 33 34 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d
	!hex 5b 31 35 31 38 2d 31 31 2d 30 33 20 30 30 3a 34 37 5d 20 77 61 6b
	!hex 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 39 2d 32 30 20 30 30 3a 30
	!hex 30 5d 20 47 75 61 72 64 20 23 31 30 33 39 20 62 65 67 69 6e 73 20
	!hex 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 37 2d 31 39 20 32 33 3a 34
	!hex 36 5d 20 47 75 61 72 64 20 23 33 31 33 37 20 62 65 67 69 6e 73 20
	!hex 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 33 2d 31 34 20 30 30 3a 31
	!hex 35 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d
	!hex 31 30 2d 30 38 20 30 30 3a 33 35 5d 20 77 61 6b 65 73 20 75 70 0d
	!hex 5b 31 35 31 38 2d 30 35 2d 33 30 20 30 30 3a 34 35 5d 20 77 61 6b
	!hex 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 36 2d 32 30 20 30 30 3a 35
	!hex 33 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 38 2d 30
	!hex 39 20 30 30 3a 35 32 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d
	!hex 5b 31 35 31 38 2d 30 35 2d 32 37 20 30 30 3a 35 38 5d 20 77 61 6b
	!hex 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 36 2d 31 39 20 30 30 3a 32
	!hex 33 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d
	!hex 30 37 2d 30 37 20 32 33 3a 35 31 5d 20 47 75 61 72 64 20 23 31 30
	!hex 39 37 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d
	!hex 31 30 2d 31 37 20 30 30 3a 35 33 5d 20 66 61 6c 6c 73 20 61 73 6c
	!hex 65 65 70 0d 5b 31 35 31 38 2d 30 38 2d 32 37 20 30 30 3a 33 39 5d
	!hex 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 36
	!hex 2d 31 36 20 30 30 3a 34 31 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31
	!hex 35 31 38 2d 30 34 2d 30 31 20 30 30 3a 35 32 5d 20 77 61 6b 65 73
	!hex 20 75 70 0d 5b 31 35 31 38 2d 30 37 2d 31 37 20 30 30 3a 34 36 5d
	!hex 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 31 30 2d 31 37 20
	!hex 30 30 3a 30 30 5d 20 47 75 61 72 64 20 23 33 30 31 31 20 62 65 67
	!hex 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 36 2d 30 32 20
	!hex 30 30 3a 32 37 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31
	!hex 35 31 38 2d 31 30 2d 31 36 20 30 30 3a 32 33 5d 20 77 61 6b 65 73
	!hex 20 75 70 0d 5b 31 35 31 38 2d 31 31 2d 31 32 20 30 30 3a 31 38 5d
	!hex 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 33 2d 30 39 20
	!hex 30 30 3a 34 31 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31
	!hex 35 31 38 2d 31 31 2d 31 31 20 30 30 3a 35 36 5d 20 77 61 6b 65 73
	!hex 20 75 70 0d 5b 31 35 31 38 2d 31 31 2d 31 38 20 30 30 3a 34 35 5d
	!hex 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 31 31 2d 30 31 20
	!hex 30 30 3a 35 39 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d
	!hex 30 34 2d 32 31 20 30 30 3a 33 33 5d 20 77 61 6b 65 73 20 75 70 0d
	!hex 5b 31 35 31 38 2d 31 30 2d 30 37 20 30 30 3a 32 38 5d 20 66 61 6c
	!hex 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 36 2d 32 32 20
	!hex 30 30 3a 30 34 5d 20 47 75 61 72 64 20 23 32 38 38 37 20 62 65 67
	!hex 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 36 2d 32 37 20
	!hex 30 30 3a 34 31 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d
	!hex 30 34 2d 30 35 20 30 30 3a 35 38 5d 20 77 61 6b 65 73 20 75 70 0d
	!hex 5b 31 35 31 38 2d 31 31 2d 32 30 20 30 30 3a 34 36 5d 20 77 61 6b
	!hex 65 73 20 75 70 0d 5b 31 35 31 38 2d 31 30 2d 30 35 20 30 30 3a 33
	!hex 31 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d
	!hex 30 37 2d 32 39 20 30 30 3a 35 30 5d 20 77 61 6b 65 73 20 75 70 0d
	!hex 5b 31 35 31 38 2d 30 35 2d 31 37 20 30 30 3a 30 30 5d 20 66 61 6c
	!hex 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 31 30 2d 33 30 20
	!hex 30 30 3a 30 35 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d
	!hex 31 30 2d 30 39 20 30 30 3a 35 39 5d 20 77 61 6b 65 73 20 75 70 0d
	!hex 5b 31 35 31 38 2d 30 37 2d 30 35 20 30 30 3a 35 35 5d 20 66 61 6c
	!hex 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 34 2d 31 36 20
	!hex 30 30 3a 35 39 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d
	!hex 30 36 2d 31 33 20 30 30 3a 31 31 5d 20 66 61 6c 6c 73 20 61 73 6c
	!hex 65 65 70 0d 5b 31 35 31 38 2d 30 34 2d 30 34 20 30 30 3a 34 38 5d
	!hex 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 37
	!hex 2d 31 35 20 30 30 3a 35 34 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31
	!hex 35 31 38 2d 30 36 2d 30 34 20 30 30 3a 31 35 5d 20 66 61 6c 6c 73
	!hex 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 31 31 2d 30 32 20 32 33
	!hex 3a 35 36 5d 20 47 75 61 72 64 20 23 32 38 38 37 20 62 65 67 69 6e
	!hex 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 37 2d 31 37 20 30 30
	!hex 3a 30 33 5d 20 47 75 61 72 64 20 23 32 33 38 31 20 62 65 67 69 6e
	!hex 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 37 2d 32 34 20 30 30
	!hex 3a 32 35 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31
	!hex 38 2d 30 32 2d 32 32 20 30 30 3a 33 33 5d 20 66 61 6c 6c 73 20 61
	!hex 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 36 2d 32 38 20 30 30 3a 35
	!hex 38 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 35 2d 32
	!hex 33 20 30 30 3a 34 30 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31
	!hex 38 2d 31 30 2d 31 31 20 30 30 3a 35 39 5d 20 77 61 6b 65 73 20 75
	!hex 70 0d 5b 31 35 31 38 2d 30 33 2d 30 38 20 30 30 3a 33 39 5d 20 77
	!hex 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 34 2d 30 38 20 30 30
	!hex 3a 32 38 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31
	!hex 38 2d 30 35 2d 31 33 20 30 30 3a 34 39 5d 20 66 61 6c 6c 73 20 61
	!hex 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 32 2d 31 38 20 30 30 3a 30
	!hex 32 5d 20 47 75 61 72 64 20 23 33 31 31 39 20 62 65 67 69 6e 73 20
	!hex 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 36 2d 32 33 20 30 30 3a 34
	!hex 38 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d
	!hex 30 37 2d 32 38 20 30 30 3a 34 31 5d 20 77 61 6b 65 73 20 75 70 0d
	!hex 5b 31 35 31 38 2d 30 37 2d 33 31 20 30 30 3a 30 32 5d 20 47 75 61
	!hex 72 64 20 23 37 39 37 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b
	!hex 31 35 31 38 2d 30 33 2d 33 30 20 30 30 3a 35 36 5d 20 77 61 6b 65
	!hex 73 20 75 70 0d 5b 31 35 31 38 2d 30 36 2d 31 37 20 30 30 3a 30 33
	!hex 5d 20 47 75 61 72 64 20 23 32 38 38 37 20 62 65 67 69 6e 73 20 73
	!hex 68 69 66 74 0d 5b 31 35 31 38 2d 30 39 2d 31 31 20 30 30 3a 35 34
	!hex 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 31
	!hex 31 2d 30 36 20 30 30 3a 33 33 5d 20 66 61 6c 6c 73 20 61 73 6c 65
	!hex 65 70 0d 5b 31 35 31 38 2d 30 32 2d 31 37 20 30 30 3a 30 38 5d 20
	!hex 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 37 2d
	!hex 32 35 20 32 33 3a 35 36 5d 20 47 75 61 72 64 20 23 33 31 31 39 20
	!hex 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 31 31 2d
	!hex 31 31 20 30 30 3a 33 37 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70
	!hex 0d 5b 31 35 31 38 2d 30 36 2d 31 39 20 30 30 3a 34 35 5d 20 66 61
	!hex 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 39 2d 32 33
	!hex 20 30 30 3a 34 31 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38
	!hex 2d 30 39 2d 31 32 20 30 30 3a 34 31 5d 20 77 61 6b 65 73 20 75 70
	!hex 0d 5b 31 35 31 38 2d 30 38 2d 30 36 20 32 33 3a 35 34 5d 20 47 75
	!hex 61 72 64 20 23 33 31 31 39 20 62 65 67 69 6e 73 20 73 68 69 66 74
	!hex 0d 5b 31 35 31 38 2d 30 39 2d 32 31 20 30 30 3a 33 36 5d 20 77 61
	!hex 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 34 2d 32 37 20 32 33 3a
	!hex 35 36 5d 20 47 75 61 72 64 20 23 31 32 34 39 20 62 65 67 69 6e 73
	!hex 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 39 2d 30 38 20 30 30 3a
	!hex 33 37 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38
	!hex 2d 31 30 2d 30 31 20 30 30 3a 35 34 5d 20 77 61 6b 65 73 20 75 70
	!hex 0d 5b 31 35 31 38 2d 30 37 2d 31 33 20 30 30 3a 34 35 5d 20 66 61
	!hex 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 33 2d 32 31
	!hex 20 30 30 3a 35 38 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38
	!hex 2d 30 36 2d 32 36 20 32 33 3a 35 38 5d 20 47 75 61 72 64 20 23 34
	!hex 33 31 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d
	!hex 31 30 2d 32 37 20 30 30 3a 30 34 5d 20 47 75 61 72 64 20 23 33 33
	!hex 31 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30
	!hex 33 2d 31 38 20 30 30 3a 31 30 5d 20 66 61 6c 6c 73 20 61 73 6c 65
	!hex 65 70 0d 5b 31 35 31 38 2d 30 34 2d 31 34 20 30 30 3a 34 31 5d 20
	!hex 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 31 31 2d
	!hex 32 32 20 30 30 3a 32 38 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35
	!hex 31 38 2d 30 38 2d 32 36 20 30 30 3a 35 36 5d 20 77 61 6b 65 73 20
	!hex 75 70 0d 5b 31 35 31 38 2d 30 36 2d 30 37 20 30 30 3a 35 37 5d 20
	!hex 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 31 30 2d
	!hex 31 35 20 30 30 3a 34 31 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35
	!hex 31 38 2d 31 31 2d 30 32 20 30 30 3a 35 31 5d 20 77 61 6b 65 73 20
	!hex 75 70 0d 5b 31 35 31 38 2d 31 31 2d 30 32 20 30 30 3a 34 36 5d 20
	!hex 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 35 2d
	!hex 30 39 20 30 30 3a 35 33 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35
	!hex 31 38 2d 30 34 2d 31 37 20 32 33 3a 35 39 5d 20 47 75 61 72 64 20
	!hex 23 32 39 36 39 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35
	!hex 31 38 2d 30 34 2d 32 37 20 30 30 3a 33 38 5d 20 66 61 6c 6c 73 20
	!hex 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 34 2d 32 30 20 32 33 3a
	!hex 34 38 5d 20 47 75 61 72 64 20 23 33 30 38 33 20 62 65 67 69 6e 73
	!hex 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 39 2d 32 33 20 30 30 3a
	!hex 33 37 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38
	!hex 2d 30 33 2d 30 33 20 30 30 3a 32 30 5d 20 66 61 6c 6c 73 20 61 73
	!hex 6c 65 65 70 0d 5b 31 35 31 38 2d 31 31 2d 32 31 20 30 30 3a 30 30
	!hex 5d 20 47 75 61 72 64 20 23 33 31 33 37 20 62 65 67 69 6e 73 20 73
	!hex 68 69 66 74 0d 5b 31 35 31 38 2d 30 37 2d 31 39 20 30 30 3a 34 31
	!hex 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30
	!hex 37 2d 31 33 20 30 30 3a 33 36 5d 20 77 61 6b 65 73 20 75 70 0d 5b
	!hex 31 35 31 38 2d 30 34 2d 32 32 20 30 30 3a 34 36 5d 20 77 61 6b 65
	!hex 73 20 75 70 0d 5b 31 35 31 38 2d 30 37 2d 31 35 20 30 30 3a 30 31
	!hex 5d 20 47 75 61 72 64 20 23 34 33 31 20 62 65 67 69 6e 73 20 73 68
	!hex 69 66 74 0d 5b 31 35 31 38 2d 30 33 2d 31 38 20 30 30 3a 32 36 5d
	!hex 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 39 2d 31 30 20
	!hex 30 30 3a 35 32 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d
	!hex 30 34 2d 31 33 20 30 30 3a 33 31 5d 20 66 61 6c 6c 73 20 61 73 6c
	!hex 65 65 70 0d 5b 31 35 31 38 2d 30 35 2d 32 36 20 32 33 3a 35 39 5d
	!hex 20 47 75 61 72 64 20 23 33 31 33 37 20 62 65 67 69 6e 73 20 73 68
	!hex 69 66 74 0d 5b 31 35 31 38 2d 31 31 2d 31 37 20 30 30 3a 34 34 5d
	!hex 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 36 2d 30 35 20
	!hex 30 30 3a 34 39 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d
	!hex 30 38 2d 30 38 20 30 30 3a 33 34 5d 20 66 61 6c 6c 73 20 61 73 6c
	!hex 65 65 70 0d 5b 31 35 31 38 2d 30 34 2d 30 31 20 30 30 3a 33 31 5d
	!hex 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 31 30
	!hex 2d 30 37 20 30 30 3a 34 37 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65
	!hex 70 0d 5b 31 35 31 38 2d 30 35 2d 31 31 20 30 30 3a 33 34 5d 20 77
	!hex 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 36 2d 30 31 20 30 30
	!hex 3a 35 38 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 32
	!hex 2d 32 34 20 30 30 3a 34 38 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31
	!hex 35 31 38 2d 30 39 2d 31 33 20 30 30 3a 31 36 5d 20 66 61 6c 6c 73
	!hex 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 35 2d 30 37 20 32 33
	!hex 3a 35 34 5d 20 47 75 61 72 64 20 23 31 30 39 37 20 62 65 67 69 6e
	!hex 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 32 2d 31 31 20 30 30
	!hex 3a 35 31 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31
	!hex 38 2d 30 34 2d 30 38 20 30 30 3a 35 36 5d 20 77 61 6b 65 73 20 75
	!hex 70 0d 5b 31 35 31 38 2d 31 30 2d 30 31 20 30 30 3a 34 35 5d 20 77
	!hex 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 39 2d 32 32 20 30 30
	!hex 3a 33 36 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31
	!hex 38 2d 30 36 2d 30 36 20 30 30 3a 30 34 5d 20 47 75 61 72 64 20 23
	!hex 38 39 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d
	!hex 30 39 2d 32 39 20 30 30 3a 30 30 5d 20 47 75 61 72 64 20 23 31 36
	!hex 30 31 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d
	!hex 31 30 2d 32 37 20 30 30 3a 32 31 5d 20 66 61 6c 6c 73 20 61 73 6c
	!hex 65 65 70 0d 5b 31 35 31 38 2d 30 38 2d 31 36 20 30 30 3a 35 36 5d
	!hex 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 37 2d 31 38 20
	!hex 32 33 3a 35 38 5d 20 47 75 61 72 64 20 23 33 31 33 37 20 62 65 67
	!hex 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 31 30 2d 30 36 20
	!hex 32 33 3a 35 36 5d 20 47 75 61 72 64 20 23 33 30 38 33 20 62 65 67
	!hex 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 38 2d 32 37 20
	!hex 30 30 3a 35 32 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d
	!hex 31 30 2d 31 36 20 30 30 3a 30 30 5d 20 47 75 61 72 64 20 23 37 39
	!hex 37 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30
	!hex 35 2d 30 38 20 32 33 3a 35 36 5d 20 47 75 61 72 64 20 23 31 32 34
	!hex 39 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30
	!hex 33 2d 31 32 20 30 30 3a 35 33 5d 20 66 61 6c 6c 73 20 61 73 6c 65
	!hex 65 70 0d 5b 31 35 31 38 2d 30 33 2d 32 38 20 30 30 3a 31 35 5d 20
	!hex 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 33 2d
	!hex 30 33 20 30 30 3a 35 35 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35
	!hex 31 38 2d 30 37 2d 32 30 20 30 30 3a 33 36 5d 20 77 61 6b 65 73 20
	!hex 75 70 0d 5b 31 35 31 38 2d 30 36 2d 31 38 20 30 30 3a 35 33 5d 20
	!hex 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 35 2d
	!hex 30 39 20 30 30 3a 34 36 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70
	!hex 0d 5b 31 35 31 38 2d 30 33 2d 30 31 20 30 30 3a 33 35 5d 20 66 61
	!hex 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 38 2d 30 33
	!hex 20 30 30 3a 33 37 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38
	!hex 2d 30 36 2d 30 36 20 30 30 3a 34 38 5d 20 77 61 6b 65 73 20 75 70
	!hex 0d 5b 31 35 31 38 2d 30 37 2d 31 33 20 30 30 3a 35 34 5d 20 77 61
	!hex 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 31 31 2d 31 32 20 30 30 3a
	!hex 35 31 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 33 2d
	!hex 32 34 20 30 30 3a 35 36 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70
	!hex 0d 5b 31 35 31 38 2d 30 38 2d 30 35 20 30 30 3a 34 37 5d 20 77 61
	!hex 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 38 2d 30 33 20 30 30 3a
	!hex 30 30 5d 20 47 75 61 72 64 20 23 32 33 38 31 20 62 65 67 69 6e 73
	!hex 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 38 2d 32 36 20 32 33 3a
	!hex 35 37 5d 20 47 75 61 72 64 20 23 33 31 33 37 20 62 65 67 69 6e 73
	!hex 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 35 2d 31 32 20 30 30 3a
	!hex 31 39 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 34 2d
	!hex 31 36 20 30 30 3a 32 38 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70
	!hex 0d 5b 31 35 31 38 2d 30 33 2d 32 36 20 30 30 3a 31 39 5d 20 66 61
	!hex 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 39 2d 32 37
	!hex 20 30 30 3a 33 32 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38
	!hex 2d 31 31 2d 30 34 20 30 30 3a 34 38 5d 20 77 61 6b 65 73 20 75 70
	!hex 0d 5b 31 35 31 38 2d 30 39 2d 32 39 20 32 33 3a 35 38 5d 20 47 75
	!hex 61 72 64 20 23 32 39 36 39 20 62 65 67 69 6e 73 20 73 68 69 66 74
	!hex 0d 5b 31 35 31 38 2d 30 34 2d 32 35 20 30 30 3a 30 30 5d 20 47 75
	!hex 61 72 64 20 23 33 33 31 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d
	!hex 5b 31 35 31 38 2d 30 38 2d 30 33 20 30 30 3a 35 39 5d 20 77 61 6b
	!hex 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 37 2d 31 39 20 30 30 3a 32
	!hex 34 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d
	!hex 31 30 2d 31 38 20 30 30 3a 31 38 5d 20 66 61 6c 6c 73 20 61 73 6c
	!hex 65 65 70 0d 5b 31 35 31 38 2d 30 34 2d 31 32 20 32 33 3a 35 39 5d
	!hex 20 47 75 61 72 64 20 23 38 39 20 62 65 67 69 6e 73 20 73 68 69 66
	!hex 74 0d 5b 31 35 31 38 2d 30 38 2d 32 33 20 30 30 3a 33 33 5d 20 66
	!hex 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 39 2d 30
	!hex 32 20 32 33 3a 35 37 5d 20 47 75 61 72 64 20 23 33 31 33 37 20 62
	!hex 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 35 2d 31
	!hex 36 20 30 30 3a 30 34 5d 20 47 75 61 72 64 20 23 32 35 37 39 20 62
	!hex 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 32 2d 31
	!hex 35 20 30 30 3a 30 31 5d 20 47 75 61 72 64 20 23 32 38 37 39 20 62
	!hex 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 31 31 2d 31
	!hex 34 20 30 30 3a 30 31 5d 20 47 75 61 72 64 20 23 33 30 38 33 20 62
	!hex 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 31 30 2d 30
	!hex 39 20 30 30 3a 30 33 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d
	!hex 5b 31 35 31 38 2d 30 38 2d 30 32 20 30 30 3a 32 36 5d 20 77 61 6b
	!hex 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 36 2d 32 34 20 30 30 3a 31
	!hex 31 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d
	!hex 30 39 2d 30 33 20 30 30 3a 34 32 5d 20 77 61 6b 65 73 20 75 70 0d
	!hex 5b 31 35 31 38 2d 30 36 2d 30 36 20 32 33 3a 35 37 5d 20 47 75 61
	!hex 72 64 20 23 33 33 31 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b
	!hex 31 35 31 38 2d 30 33 2d 32 35 20 30 30 3a 35 33 5d 20 77 61 6b 65
	!hex 73 20 75 70 0d 5b 31 35 31 38 2d 30 34 2d 30 33 20 30 30 3a 35 39
	!hex 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 36 2d 32 38
	!hex 20 30 30 3a 30 35 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b
	!hex 31 35 31 38 2d 30 35 2d 32 39 20 30 30 3a 35 32 5d 20 77 61 6b 65
	!hex 73 20 75 70 0d 5b 31 35 31 38 2d 30 35 2d 31 31 20 30 30 3a 32 39
	!hex 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 33 2d 32 36
	!hex 20 32 33 3a 35 36 5d 20 47 75 61 72 64 20 23 32 35 37 39 20 62 65
	!hex 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 31 30 2d 31 36
	!hex 20 30 30 3a 35 37 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38
	!hex 2d 30 36 2d 30 38 20 30 30 3a 34 39 5d 20 77 61 6b 65 73 20 75 70
	!hex 0d 5b 31 35 31 38 2d 30 34 2d 30 34 20 30 30 3a 32 31 5d 20 66 61
	!hex 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 38 2d 32 34
	!hex 20 30 30 3a 30 31 5d 20 47 75 61 72 64 20 23 33 31 31 39 20 62 65
	!hex 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 35 2d 30 38
	!hex 20 30 30 3a 34 31 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38
	!hex 2d 30 35 2d 30 35 20 30 30 3a 30 33 5d 20 66 61 6c 6c 73 20 61 73
	!hex 6c 65 65 70 0d 5b 31 35 31 38 2d 30 34 2d 32 30 20 30 30 3a 35 32
	!hex 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 31 31 2d 30 35
	!hex 20 30 30 3a 35 32 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38
	!hex 2d 31 31 2d 31 35 20 30 30 3a 35 37 5d 20 77 61 6b 65 73 20 75 70
	!hex 0d 5b 31 35 31 38 2d 30 32 2d 32 36 20 30 30 3a 31 37 5d 20 66 61
	!hex 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 34 2d 32 30
	!hex 20 30 30 3a 30 39 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b
	!hex 31 35 31 38 2d 30 39 2d 30 37 20 30 30 3a 33 32 5d 20 77 61 6b 65
	!hex 73 20 75 70 0d 5b 31 35 31 38 2d 30 37 2d 31 33 20 32 33 3a 35 39
	!hex 5d 20 47 75 61 72 64 20 23 31 36 30 31 20 62 65 67 69 6e 73 20 73
	!hex 68 69 66 74 0d 5b 31 35 31 38 2d 30 36 2d 31 39 20 30 30 3a 34 39
	!hex 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 33 2d 33 31
	!hex 20 30 30 3a 34 37 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38
	!hex 2d 30 36 2d 32 37 20 30 30 3a 34 37 5d 20 66 61 6c 6c 73 20 61 73
	!hex 6c 65 65 70 0d 5b 31 35 31 38 2d 30 34 2d 33 30 20 32 33 3a 35 38
	!hex 5d 20 47 75 61 72 64 20 23 31 32 34 39 20 62 65 67 69 6e 73 20 73
	!hex 68 69 66 74 0d 5b 31 35 31 38 2d 30 37 2d 31 34 20 30 30 3a 35 35
	!hex 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 36 2d 30 34
	!hex 20 30 30 3a 35 37 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38
	!hex 2d 30 32 2d 30 36 20 30 30 3a 30 33 5d 20 66 61 6c 6c 73 20 61 73
	!hex 6c 65 65 70 0d 5b 31 35 31 38 2d 30 38 2d 30 31 20 30 30 3a 32 35
	!hex 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 31
	!hex 30 2d 31 35 20 30 30 3a 31 38 5d 20 66 61 6c 6c 73 20 61 73 6c 65
	!hex 65 70 0d 5b 31 35 31 38 2d 30 39 2d 32 32 20 32 33 3a 35 39 5d 20
	!hex 47 75 61 72 64 20 23 31 30 39 37 20 62 65 67 69 6e 73 20 73 68 69
	!hex 66 74 0d 5b 31 35 31 38 2d 31 31 2d 31 35 20 30 30 3a 33 38 5d 20
	!hex 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 33 2d 31 39 20 30
	!hex 30 3a 33 37 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35
	!hex 31 38 2d 30 37 2d 30 39 20 30 30 3a 31 37 5d 20 66 61 6c 6c 73 20
	!hex 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 39 2d 30 38 20 32 33 3a
	!hex 35 37 5d 20 47 75 61 72 64 20 23 32 33 38 31 20 62 65 67 69 6e 73
	!hex 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 38 2d 31 31 20 30 30 3a
	!hex 33 33 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38
	!hex 2d 30 32 2d 32 36 20 30 30 3a 31 38 5d 20 77 61 6b 65 73 20 75 70
	!hex 0d 5b 31 35 31 38 2d 30 32 2d 30 33 20 30 30 3a 31 32 5d 20 66 61
	!hex 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 31 30 2d 30 37
	!hex 20 32 33 3a 35 39 5d 20 47 75 61 72 64 20 23 31 30 33 39 20 62 65
	!hex 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 31 30 2d 30 35
	!hex 20 30 30 3a 33 34 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38
	!hex 2d 30 32 2d 31 30 20 30 30 3a 35 32 5d 20 77 61 6b 65 73 20 75 70
	!hex 0d 5b 31 35 31 38 2d 30 36 2d 31 31 20 30 30 3a 33 31 5d 20 77 61
	!hex 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 33 2d 30 32 20 30 30 3a
	!hex 35 32 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 35 2d
	!hex 32 31 20 30 30 3a 35 37 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35
	!hex 31 38 2d 30 32 2d 32 34 20 32 33 3a 35 38 5d 20 47 75 61 72 64 20
	!hex 23 32 35 37 39 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35
	!hex 31 38 2d 30 37 2d 31 32 20 30 30 3a 35 32 5d 20 77 61 6b 65 73 20
	!hex 75 70 0d 5b 31 35 31 38 2d 30 35 2d 32 32 20 30 30 3a 35 37 5d 20
	!hex 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 31 30 2d 32 38 20 30
	!hex 30 3a 30 33 5d 20 47 75 61 72 64 20 23 33 30 31 31 20 62 65 67 69
	!hex 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 33 2d 32 31 20 30
	!hex 30 3a 34 37 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35
	!hex 31 38 2d 30 35 2d 30 32 20 30 30 3a 34 37 5d 20 77 61 6b 65 73 20
	!hex 75 70 0d 5b 31 35 31 38 2d 30 37 2d 32 36 20 30 30 3a 34 33 5d 20
	!hex 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 31 30 2d 32 35 20 30
	!hex 30 3a 32 37 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35
	!hex 31 38 2d 30 32 2d 32 36 20 30 30 3a 32 38 5d 20 66 61 6c 6c 73 20
	!hex 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 35 2d 31 31 20 30 30 3a
	!hex 35 32 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38
	!hex 2d 30 33 2d 31 32 20 30 30 3a 33 37 5d 20 66 61 6c 6c 73 20 61 73
	!hex 6c 65 65 70 0d 5b 31 35 31 38 2d 30 39 2d 32 34 20 30 30 3a 34 39
	!hex 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 37 2d 32 32
	!hex 20 30 30 3a 35 34 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b
	!hex 31 35 31 38 2d 30 36 2d 30 37 20 30 30 3a 34 34 5d 20 66 61 6c 6c
	!hex 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 32 2d 30 37 20 32
	!hex 33 3a 35 38 5d 20 47 75 61 72 64 20 23 33 31 31 39 20 62 65 67 69
	!hex 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 32 2d 30 37 20 30
	!hex 30 3a 34 38 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30
	!hex 37 2d 32 35 20 30 30 3a 31 39 5d 20 66 61 6c 6c 73 20 61 73 6c 65
	!hex 65 70 0d 5b 31 35 31 38 2d 30 37 2d 31 31 20 30 30 3a 31 31 5d 20
	!hex 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 36 2d 31 33 20 30
	!hex 30 3a 30 34 5d 20 47 75 61 72 64 20 23 31 32 34 39 20 62 65 67 69
	!hex 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 33 2d 32 39 20 30
	!hex 30 3a 32 39 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35
	!hex 31 38 2d 30 34 2d 30 35 20 32 33 3a 35 37 5d 20 47 75 61 72 64 20
	!hex 23 33 30 38 33 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35
	!hex 31 38 2d 30 36 2d 31 34 20 32 33 3a 35 31 5d 20 47 75 61 72 64 20
	!hex 23 33 30 38 33 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35
	!hex 31 38 2d 31 30 2d 33 31 20 30 30 3a 30 36 5d 20 66 61 6c 6c 73 20
	!hex 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 39 2d 31 34 20 30 30 3a
	!hex 30 30 5d 20 47 75 61 72 64 20 23 33 30 38 33 20 62 65 67 69 6e 73
	!hex 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 35 2d 31 33 20 30 30 3a
	!hex 31 38 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38
	!hex 2d 30 35 2d 32 38 20 32 33 3a 35 38 5d 20 47 75 61 72 64 20 23 33
	!hex 30 31 31 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38
	!hex 2d 30 32 2d 31 30 20 30 30 3a 35 39 5d 20 77 61 6b 65 73 20 75 70
	!hex 0d 5b 31 35 31 38 2d 30 39 2d 32 35 20 30 30 3a 35 32 5d 20 77 61
	!hex 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 32 2d 32 32 20 30 30 3a
	!hex 34 32 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38
	!hex 2d 31 31 2d 30 35 20 30 30 3a 32 35 5d 20 77 61 6b 65 73 20 75 70
	!hex 0d 5b 31 35 31 38 2d 30 36 2d 33 30 20 30 30 3a 35 39 5d 20 77 61
	!hex 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 35 2d 31 33 20 30 30 3a
	!hex 35 35 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 37 2d
	!hex 32 30 20 30 30 3a 30 32 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70
	!hex 0d 5b 31 35 31 38 2d 30 32 2d 31 32 20 30 30 3a 30 31 5d 20 66 61
	!hex 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 32 2d 32 30
	!hex 20 30 30 3a 35 36 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38
	!hex 2d 30 36 2d 30 31 20 30 30 3a 31 36 5d 20 66 61 6c 6c 73 20 61 73
	!hex 6c 65 65 70 0d 5b 31 35 31 38 2d 30 37 2d 30 35 20 30 30 3a 35 31
	!hex 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30
	!hex 37 2d 31 39 20 30 30 3a 35 31 5d 20 77 61 6b 65 73 20 75 70 0d 5b
	!hex 31 35 31 38 2d 30 33 2d 31 36 20 30 30 3a 35 35 5d 20 66 61 6c 6c
	!hex 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 37 2d 30 35 20 30
	!hex 30 3a 34 33 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30
	!hex 33 2d 31 33 20 30 30 3a 33 35 5d 20 77 61 6b 65 73 20 75 70 0d 5b
	!hex 31 35 31 38 2d 30 38 2d 30 36 20 30 30 3a 33 31 5d 20 66 61 6c 6c
	!hex 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 38 2d 31 30 20 30
	!hex 30 3a 33 38 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35
	!hex 31 38 2d 30 33 2d 31 32 20 30 30 3a 35 36 5d 20 77 61 6b 65 73 20
	!hex 75 70 0d 5b 31 35 31 38 2d 30 36 2d 32 37 20 30 30 3a 35 35 5d 20
	!hex 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 35 2d
	!hex 33 31 20 30 30 3a 34 30 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35
	!hex 31 38 2d 30 35 2d 32 32 20 30 30 3a 35 36 5d 20 66 61 6c 6c 73 20
	!hex 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 38 2d 32 36 20 30 30 3a
	!hex 30 32 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38
	!hex 2d 31 30 2d 32 36 20 30 30 3a 31 38 5d 20 66 61 6c 6c 73 20 61 73
	!hex 6c 65 65 70 0d 5b 31 35 31 38 2d 30 37 2d 30 35 20 30 30 3a 35 32
	!hex 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 38 2d 32 32
	!hex 20 30 30 3a 33 39 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b
	!hex 31 35 31 38 2d 30 39 2d 31 35 20 30 30 3a 30 30 5d 20 47 75 61 72
	!hex 64 20 23 36 39 31 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31
	!hex 35 31 38 2d 31 30 2d 30 33 20 30 30 3a 33 30 5d 20 66 61 6c 6c 73
	!hex 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 38 2d 31 30 20 30 30
	!hex 3a 35 31 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 39
	!hex 2d 32 37 20 30 30 3a 35 37 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31
	!hex 35 31 38 2d 30 38 2d 31 39 20 30 30 3a 35 34 5d 20 77 61 6b 65 73
	!hex 20 75 70 0d 5b 31 35 31 38 2d 30 36 2d 31 36 20 30 30 3a 35 34 5d
	!hex 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 31 30
	!hex 2d 30 35 20 30 30 3a 35 37 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65
	!hex 70 0d 5b 31 35 31 38 2d 30 33 2d 32 36 20 30 30 3a 30 31 5d 20 47
	!hex 75 61 72 64 20 23 34 33 31 20 62 65 67 69 6e 73 20 73 68 69 66 74
	!hex 0d 5b 31 35 31 38 2d 30 33 2d 32 38 20 32 33 3a 35 36 5d 20 47 75
	!hex 61 72 64 20 23 31 36 30 31 20 62 65 67 69 6e 73 20 73 68 69 66 74
	!hex 0d 5b 31 35 31 38 2d 31 30 2d 31 36 20 30 30 3a 31 34 5d 20 66 61
	!hex 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 37 2d 30 32
	!hex 20 32 33 3a 35 39 5d 20 47 75 61 72 64 20 23 33 37 33 20 62 65 67
	!hex 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 31 31 2d 31 32 20
	!hex 30 30 3a 32 36 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31
	!hex 35 31 38 2d 30 39 2d 32 34 20 30 30 3a 30 30 5d 20 47 75 61 72 64
	!hex 20 23 31 32 34 39 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31
	!hex 35 31 38 2d 30 34 2d 30 38 20 30 30 3a 35 32 5d 20 66 61 6c 6c 73
	!hex 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 39 2d 30 38 20 30 30
	!hex 3a 31 39 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 32
	!hex 2d 32 33 20 30 30 3a 30 34 5d 20 47 75 61 72 64 20 23 37 39 37 20
	!hex 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 37 2d
	!hex 32 36 20 30 30 3a 33 39 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70
	!hex 0d 5b 31 35 31 38 2d 30 35 2d 33 31 20 30 30 3a 30 30 5d 20 47 75
	!hex 61 72 64 20 23 33 37 33 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d
	!hex 5b 31 35 31 38 2d 30 36 2d 32 31 20 30 30 3a 33 38 5d 20 66 61 6c
	!hex 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 36 2d 32 33 20
	!hex 30 30 3a 35 36 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d
	!hex 30 32 2d 32 36 20 32 33 3a 35 33 5d 20 47 75 61 72 64 20 23 34 33
	!hex 31 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30
	!hex 35 2d 30 32 20 32 33 3a 35 36 5d 20 47 75 61 72 64 20 23 32 38 37
	!hex 39 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 31
	!hex 31 2d 31 32 20 30 30 3a 30 32 5d 20 66 61 6c 6c 73 20 61 73 6c 65
	!hex 65 70 0d 5b 31 35 31 38 2d 31 31 2d 32 32 20 30 30 3a 30 33 5d 20
	!hex 47 75 61 72 64 20 23 33 30 38 39 20 62 65 67 69 6e 73 20 73 68 69
	!hex 66 74 0d 5b 31 35 31 38 2d 30 38 2d 30 38 20 30 30 3a 35 35 5d 20
	!hex 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 35 2d 31 35 20 30
	!hex 30 3a 33 34 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35
	!hex 31 38 2d 30 33 2d 31 32 20 30 30 3a 34 33 5d 20 77 61 6b 65 73 20
	!hex 75 70 0d 5b 31 35 31 38 2d 30 38 2d 31 35 20 30 30 3a 30 32 5d 20
	!hex 47 75 61 72 64 20 23 34 33 31 20 62 65 67 69 6e 73 20 73 68 69 66
	!hex 74 0d 5b 31 35 31 38 2d 31 30 2d 31 38 20 30 30 3a 33 38 5d 20 77
	!hex 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 34 2d 33 30 20 30 30
	!hex 3a 34 39 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31
	!hex 38 2d 30 39 2d 30 32 20 30 30 3a 32 31 5d 20 66 61 6c 6c 73 20 61
	!hex 73 6c 65 65 70 0d 5b 31 35 31 38 2d 31 31 2d 31 32 20 32 33 3a 35
	!hex 32 5d 20 47 75 61 72 64 20 23 33 30 38 39 20 62 65 67 69 6e 73 20
	!hex 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 36 2d 30 34 20 30 30 3a 33
	!hex 39 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 31 30 2d 32
	!hex 35 20 30 30 3a 35 37 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31
	!hex 38 2d 30 32 2d 31 31 20 32 33 3a 35 30 5d 20 47 75 61 72 64 20 23
	!hex 32 35 37 39 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31
	!hex 38 2d 31 31 2d 30 34 20 30 30 3a 31 37 5d 20 66 61 6c 6c 73 20 61
	!hex 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 38 2d 30 34 20 30 30 3a 31
	!hex 31 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d
	!hex 30 38 2d 31 37 20 30 30 3a 30 30 5d 20 47 75 61 72 64 20 23 38 39
	!hex 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 33
	!hex 2d 30 37 20 30 30 3a 34 35 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31
	!hex 35 31 38 2d 30 33 2d 31 30 20 30 30 3a 34 36 5d 20 66 61 6c 6c 73
	!hex 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 35 2d 30 35 20 32 33
	!hex 3a 34 38 5d 20 47 75 61 72 64 20 23 33 37 33 20 62 65 67 69 6e 73
	!hex 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 36 2d 32 32 20 30 30 3a
	!hex 33 32 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 31 30 2d
	!hex 31 30 20 30 30 3a 30 33 5d 20 47 75 61 72 64 20 23 31 30 33 39 20
	!hex 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 37 2d
	!hex 33 30 20 30 30 3a 30 35 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70
	!hex 0d 5b 31 35 31 38 2d 31 31 2d 30 37 20 32 33 3a 35 39 5d 20 47 75
	!hex 61 72 64 20 23 33 30 38 39 20 62 65 67 69 6e 73 20 73 68 69 66 74
	!hex 0d 5b 31 35 31 38 2d 31 30 2d 31 30 20 30 30 3a 33 30 5d 20 66 61
	!hex 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 34 2d 30 32
	!hex 20 30 30 3a 34 39 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38
	!hex 2d 30 32 2d 31 38 20 32 33 3a 35 39 5d 20 47 75 61 72 64 20 23 32
	!hex 38 37 39 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38
	!hex 2d 30 34 2d 31 34 20 30 30 3a 35 33 5d 20 66 61 6c 6c 73 20 61 73
	!hex 6c 65 65 70 0d 5b 31 35 31 38 2d 30 39 2d 31 34 20 30 30 3a 31 32
	!hex 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 31
	!hex 30 2d 30 36 20 30 30 3a 32 38 5d 20 77 61 6b 65 73 20 75 70 0d 5b
	!hex 31 35 31 38 2d 30 37 2d 32 35 20 30 30 3a 32 35 5d 20 77 61 6b 65
	!hex 73 20 75 70 0d 5b 31 35 31 38 2d 30 39 2d 31 32 20 30 30 3a 31 33
	!hex 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 31
	!hex 31 2d 31 36 20 30 30 3a 35 30 5d 20 77 61 6b 65 73 20 75 70 0d 5b
	!hex 31 35 31 38 2d 30 37 2d 31 38 20 30 30 3a 34 36 5d 20 77 61 6b 65
	!hex 73 20 75 70 0d 5b 31 35 31 38 2d 30 35 2d 32 38 20 30 30 3a 30 30
	!hex 5d 20 47 75 61 72 64 20 23 33 37 33 20 62 65 67 69 6e 73 20 73 68
	!hex 69 66 74 0d 5b 31 35 31 38 2d 30 33 2d 30 35 20 30 30 3a 35 38 5d
	!hex 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 32 2d 30 37 20
	!hex 30 30 3a 30 30 5d 20 47 75 61 72 64 20 23 37 39 37 20 62 65 67 69
	!hex 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 32 2d 31 31 20 30
	!hex 30 3a 35 36 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30
	!hex 33 2d 30 36 20 30 30 3a 34 38 5d 20 77 61 6b 65 73 20 75 70 0d 5b
	!hex 31 35 31 38 2d 30 32 2d 31 34 20 30 30 3a 33 37 5d 20 77 61 6b 65
	!hex 73 20 75 70 0d 5b 31 35 31 38 2d 30 38 2d 31 33 20 30 30 3a 31 37
	!hex 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30
	!hex 34 2d 32 37 20 30 30 3a 34 38 5d 20 77 61 6b 65 73 20 75 70 0d 5b
	!hex 31 35 31 38 2d 30 35 2d 32 34 20 30 30 3a 30 32 5d 20 47 75 61 72
	!hex 64 20 23 32 38 37 39 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b
	!hex 31 35 31 38 2d 30 38 2d 32 32 20 30 30 3a 34 37 5d 20 77 61 6b 65
	!hex 73 20 75 70 0d 5b 31 35 31 38 2d 30 34 2d 32 32 20 30 30 3a 30 33
	!hex 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30
	!hex 33 2d 31 36 20 30 30 3a 35 38 5d 20 77 61 6b 65 73 20 75 70 0d 5b
	!hex 31 35 31 38 2d 30 39 2d 31 39 20 30 30 3a 30 33 5d 20 47 75 61 72
	!hex 64 20 23 32 31 33 37 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b
	!hex 31 35 31 38 2d 30 39 2d 31 37 20 30 30 3a 32 36 5d 20 66 61 6c 6c
	!hex 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 36 2d 31 39 20 30
	!hex 30 3a 33 37 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30
	!hex 33 2d 31 39 20 30 30 3a 30 32 5d 20 47 75 61 72 64 20 23 37 39 37
	!hex 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 32
	!hex 2d 32 38 20 30 30 3a 30 30 5d 20 47 75 61 72 64 20 23 32 35 37 39
	!hex 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 31 31
	!hex 2d 32 30 20 30 30 3a 33 35 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65
	!hex 70 0d 5b 31 35 31 38 2d 30 34 2d 32 38 20 30 30 3a 35 32 5d 20 66
	!hex 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 38 2d 32
	!hex 35 20 30 30 3a 30 32 5d 20 47 75 61 72 64 20 23 33 31 33 37 20 62
	!hex 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 33 2d 32
	!hex 31 20 30 30 3a 30 34 5d 20 47 75 61 72 64 20 23 31 36 30 31 20 62
	!hex 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 35 2d 32
	!hex 33 20 30 30 3a 30 35 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d
	!hex 5b 31 35 31 38 2d 30 33 2d 32 33 20 30 30 3a 32 39 5d 20 66 61 6c
	!hex 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 36 2d 31 30 20
	!hex 32 33 3a 35 38 5d 20 47 75 61 72 64 20 23 37 39 37 20 62 65 67 69
	!hex 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 34 2d 32 34 20 30
	!hex 30 3a 34 39 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35
	!hex 31 38 2d 30 38 2d 31 39 20 30 30 3a 33 39 5d 20 66 61 6c 6c 73 20
	!hex 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 31 30 2d 33 31 20 30 30 3a
	!hex 35 36 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 36 2d
	!hex 33 30 20 30 30 3a 32 37 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70
	!hex 0d 5b 31 35 31 38 2d 30 37 2d 30 35 20 32 33 3a 35 34 5d 20 47 75
	!hex 61 72 64 20 23 31 30 39 37 20 62 65 67 69 6e 73 20 73 68 69 66 74
	!hex 0d 5b 31 35 31 38 2d 30 34 2d 32 33 20 32 33 3a 35 38 5d 20 47 75
	!hex 61 72 64 20 23 31 35 35 39 20 62 65 67 69 6e 73 20 73 68 69 66 74
	!hex 0d 5b 31 35 31 38 2d 30 38 2d 32 32 20 32 33 3a 35 37 5d 20 47 75
	!hex 61 72 64 20 23 32 33 38 31 20 62 65 67 69 6e 73 20 73 68 69 66 74
	!hex 0d 5b 31 35 31 38 2d 30 35 2d 30 38 20 30 30 3a 30 30 5d 20 66 61
	!hex 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 39 2d 32 32
	!hex 20 30 30 3a 35 36 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38
	!hex 2d 30 36 2d 30 38 20 30 30 3a 33 32 5d 20 66 61 6c 6c 73 20 61 73
	!hex 6c 65 65 70 0d 5b 31 35 31 38 2d 30 33 2d 33 31 20 30 30 3a 30 32
	!hex 5d 20 47 75 61 72 64 20 23 32 35 37 39 20 62 65 67 69 6e 73 20 73
	!hex 68 69 66 74 0d 5b 31 35 31 38 2d 31 30 2d 32 36 20 30 30 3a 34 32
	!hex 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 36 2d 31 32
	!hex 20 30 30 3a 34 38 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b
	!hex 31 35 31 38 2d 30 33 2d 30 34 20 32 33 3a 35 30 5d 20 47 75 61 72
	!hex 64 20 23 32 33 38 31 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b
	!hex 31 35 31 38 2d 30 35 2d 31 35 20 30 30 3a 30 31 5d 20 47 75 61 72
	!hex 64 20 23 32 39 36 39 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b
	!hex 31 35 31 38 2d 30 38 2d 32 36 20 30 30 3a 35 34 5d 20 66 61 6c 6c
	!hex 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 39 2d 31 35 20 30
	!hex 30 3a 31 31 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35
	!hex 31 38 2d 30 35 2d 30 34 20 32 33 3a 34 36 5d 20 47 75 61 72 64 20
	!hex 23 33 30 38 39 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35
	!hex 31 38 2d 30 32 2d 31 33 20 30 30 3a 30 30 5d 20 47 75 61 72 64 20
	!hex 23 32 35 37 39 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35
	!hex 31 38 2d 30 34 2d 30 38 20 30 30 3a 30 32 5d 20 47 75 61 72 64 20
	!hex 23 31 35 35 39 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35
	!hex 31 38 2d 30 39 2d 30 32 20 30 30 3a 33 31 5d 20 77 61 6b 65 73 20
	!hex 75 70 0d 5b 31 35 31 38 2d 31 30 2d 33 30 20 30 30 3a 30 32 5d 20
	!hex 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 31 31 2d
	!hex 31 31 20 30 30 3a 30 32 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70
	!hex 0d 5b 31 35 31 38 2d 30 34 2d 31 34 20 30 30 3a 35 35 5d 20 77 61
	!hex 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 34 2d 31 31 20 30 30 3a
	!hex 34 31 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38
	!hex 2d 30 33 2d 32 31 20 30 30 3a 33 39 5d 20 77 61 6b 65 73 20 75 70
	!hex 0d 5b 31 35 31 38 2d 30 37 2d 30 39 20 30 30 3a 34 34 5d 20 77 61
	!hex 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 34 2d 32 34 20 30 30 3a
	!hex 33 30 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 33 2d
	!hex 32 32 20 30 30 3a 32 36 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70
	!hex 0d 5b 31 35 31 38 2d 31 31 2d 31 38 20 30 30 3a 30 34 5d 20 47 75
	!hex 61 72 64 20 23 31 36 30 31 20 62 65 67 69 6e 73 20 73 68 69 66 74
	!hex 0d 5b 31 35 31 38 2d 30 38 2d 32 30 20 30 30 3a 32 33 5d 20 66 61
	!hex 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 37 2d 32 33
	!hex 20 30 30 3a 35 32 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38
	!hex 2d 30 35 2d 32 31 20 32 33 3a 35 38 5d 20 47 75 61 72 64 20 23 36
	!hex 39 31 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d
	!hex 30 37 2d 32 32 20 30 30 3a 33 35 5d 20 77 61 6b 65 73 20 75 70 0d
	!hex 5b 31 35 31 38 2d 31 31 2d 31 35 20 30 30 3a 30 34 5d 20 47 75 61
	!hex 72 64 20 23 32 39 36 39 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d
	!hex 5b 31 35 31 38 2d 30 36 2d 30 39 20 30 30 3a 35 33 5d 20 77 61 6b
	!hex 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 38 2d 32 33 20 30 30 3a 34
	!hex 36 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 35 2d 31
	!hex 37 20 30 30 3a 32 36 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31
	!hex 38 2d 30 34 2d 31 38 20 30 30 3a 32 37 5d 20 66 61 6c 6c 73 20 61
	!hex 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 34 2d 30 36 20 30 30 3a 32
	!hex 39 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 39 2d 31
	!hex 37 20 30 30 3a 34 32 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31
	!hex 38 2d 31 31 2d 30 35 20 30 30 3a 34 38 5d 20 66 61 6c 6c 73 20 61
	!hex 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 35 2d 31 32 20 30 30 3a 32
	!hex 39 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d
	!hex 31 31 2d 31 30 20 30 30 3a 30 34 5d 20 47 75 61 72 64 20 23 38 39
	!hex 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 36
	!hex 2d 32 39 20 30 30 3a 30 30 5d 20 47 75 61 72 64 20 23 33 31 33 37
	!hex 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 37
	!hex 2d 30 36 20 30 30 3a 30 32 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65
	!hex 70 0d 5b 31 35 31 38 2d 31 31 2d 31 38 20 30 30 3a 32 36 5d 20 66
	!hex 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 31 30 2d 30
	!hex 33 20 30 30 3a 34 31 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d
	!hex 5b 31 35 31 38 2d 30 32 2d 30 39 20 30 30 3a 35 37 5d 20 77 61 6b
	!hex 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 37 2d 32 33 20 30 30 3a 31
	!hex 39 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d
	!hex 30 35 2d 30 36 20 30 30 3a 30 34 5d 20 77 61 6b 65 73 20 75 70 0d
	!hex 5b 31 35 31 38 2d 30 39 2d 32 36 20 30 30 3a 33 37 5d 20 77 61 6b
	!hex 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 32 2d 32 36 20 30 30 3a 33
	!hex 34 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 37 2d 33
	!hex 30 20 30 30 3a 34 31 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31
	!hex 38 2d 30 35 2d 31 30 20 30 30 3a 30 32 5d 20 47 75 61 72 64 20 23
	!hex 33 31 33 37 20 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31
	!hex 38 2d 30 32 2d 32 36 20 30 30 3a 35 35 5d 20 66 61 6c 6c 73 20 61
	!hex 73 6c 65 65 70 0d 5b 31 35 31 38 2d 31 30 2d 32 38 20 30 30 3a 34
	!hex 39 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 32 2d 31
	!hex 38 20 30 30 3a 33 37 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d
	!hex 5b 31 35 31 38 2d 30 36 2d 30 38 20 30 30 3a 32 31 5d 20 77 61 6b
	!hex 65 73 20 75 70 0d 5b 31 35 31 38 2d 31 30 2d 31 33 20 30 30 3a 30
	!hex 30 5d 20 47 75 61 72 64 20 23 31 36 30 31 20 62 65 67 69 6e 73 20
	!hex 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 38 2d 30 33 20 30 30 3a 34
	!hex 31 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d
	!hex 30 33 2d 31 33 20 30 30 3a 31 37 5d 20 66 61 6c 6c 73 20 61 73 6c
	!hex 65 65 70 0d 5b 31 35 31 38 2d 30 33 2d 32 36 20 30 30 3a 33 35 5d
	!hex 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 33 2d 32 33 20
	!hex 30 30 3a 35 35 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d
	!hex 30 39 2d 32 35 20 30 30 3a 33 32 5d 20 66 61 6c 6c 73 20 61 73 6c
	!hex 65 65 70 0d 5b 31 35 31 38 2d 31 30 2d 30 38 20 32 33 3a 35 30 5d
	!hex 20 47 75 61 72 64 20 23 31 30 39 37 20 62 65 67 69 6e 73 20 73 68
	!hex 69 66 74 0d 5b 31 35 31 38 2d 30 32 2d 32 38 20 30 30 3a 33 31 5d
	!hex 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 33 2d 31 30 20
	!hex 30 30 3a 30 33 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31
	!hex 35 31 38 2d 31 31 2d 30 31 20 30 30 3a 35 31 5d 20 77 61 6b 65 73
	!hex 20 75 70 0d 5b 31 35 31 38 2d 30 38 2d 31 33 20 30 30 3a 34 30 5d
	!hex 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 34
	!hex 2d 33 30 20 30 30 3a 35 35 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31
	!hex 35 31 38 2d 30 37 2d 33 31 20 30 30 3a 34 32 5d 20 77 61 6b 65 73
	!hex 20 75 70 0d 5b 31 35 31 38 2d 31 30 2d 32 33 20 30 30 3a 30 34 5d
	!hex 20 47 75 61 72 64 20 23 31 30 39 37 20 62 65 67 69 6e 73 20 73 68
	!hex 69 66 74 0d 5b 31 35 31 38 2d 30 39 2d 32 35 20 32 33 3a 35 30 5d
	!hex 20 47 75 61 72 64 20 23 33 31 33 37 20 62 65 67 69 6e 73 20 73 68
	!hex 69 66 74 0d 5b 31 35 31 38 2d 30 39 2d 32 30 20 30 30 3a 33 36 5d
	!hex 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 34 2d 31 32 20
	!hex 30 30 3a 31 31 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31
	!hex 35 31 38 2d 30 35 2d 33 30 20 30 30 3a 32 38 5d 20 77 61 6b 65 73
	!hex 20 75 70 0d 5b 31 35 31 38 2d 31 31 2d 30 37 20 30 30 3a 33 35 5d
	!hex 20 66 61 6c 6c 73 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 31 30
	!hex 2d 31 34 20 30 30 3a 30 34 5d 20 66 61 6c 6c 73 20 61 73 6c 65 65
	!hex 70 0d 5b 31 35 31 38 2d 30 32 2d 31 38 20 30 30 3a 34 34 5d 20 77
	!hex 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 31 30 2d 32 33 20 30 30
	!hex 3a 34 37 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 30 32
	!hex 2d 30 35 20 30 30 3a 35 35 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31
	!hex 35 31 38 2d 30 37 2d 30 38 20 30 30 3a 30 32 5d 20 66 61 6c 6c 73
	!hex 20 61 73 6c 65 65 70 0d 5b 31 35 31 38 2d 30 35 2d 32 32 20 32 33
	!hex 3a 35 30 5d 20 47 75 61 72 64 20 23 37 39 37 20 62 65 67 69 6e 73
	!hex 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 37 2d 32 37 20 30 30 3a
	!hex 30 32 5d 20 47 75 61 72 64 20 23 32 35 37 39 20 62 65 67 69 6e 73
	!hex 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 31 31 2d 31 31 20 32 33 3a
	!hex 34 39 5d 20 47 75 61 72 64 20 23 32 33 38 31 20 62 65 67 69 6e 73
	!hex 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 36 2d 32 34 20 30 30 3a
	!hex 34 34 5d 20 77 61 6b 65 73 20 75 70 0d 5b 31 35 31 38 2d 31 30 2d
	!hex 30 32 20 30 30 3a 30 30 5d 20 47 75 61 72 64 20 23 32 33 38 31 20
	!hex 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 37 2d
	!hex 31 35 20 32 33 3a 35 37 5d 20 47 75 61 72 64 20 23 32 33 38 31 20
	!hex 62 65 67 69 6e 73 20 73 68 69 66 74 0d 5b 31 35 31 38 2d 30 37 2d
	!hex 31 36 20 30 30 3a 35 30 5d 20 77 61 6b 65 73 20 75 70 0d 00
