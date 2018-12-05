; non-recursive mergesort!
; it's not in-place, so it uses temp memory of the same size as the array to
; be sorted, which is allocated right after the array.
; the record size is given as input.
; comp4 is the comparison routine, change it as fit.
; there can be additional data that's not part of the key
; (see advent of code day 4 for an example)
; this code could use some cleanup, it does some comparisons inefficiently
; (i was more concerned getting this to work at all)

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
