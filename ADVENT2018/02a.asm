; advent of code 2018 day 2, part 1
; https://adventofcode.com/2018/day/2
; algorithm: count letter frequencies and multiply two integers. there are fewer
; than 256 words and each word contribute with at most 1 to the multiplicator
; and multiplicand, so it's sufficient to multiply 8-bit ints

	CHROUT = $ffd2

	!to "02a.prg",cbm
	* = $0801
	; sys start
	!byte $0b, $08, $0a, $00, $9e, 48+start/1000%10, 48+start/100%10, 48+start/10%10, 48+start%10, $00, $00, $00

	zp = $fe
	twos = $f8
	threes = $f9

; some boilerplate code

; multiply two unsigned 8-bit integers and get 16-bit product
; inputs: mul1, mul2
; output: product
; clobbered: a,x,mul1
; shortened from http://codebase64.org/doku.php?id=base:16bit_multiplication_32-bit_product

mul1 = $fc ; 1 byte
mul2 = $fd ; 1 byte
product = $fa ; 2 bytes

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

; convert unsigned 16-bit int to 24-bit (6-digit) bcd
; input value: inbcd
; output value: outbcd
; clobbered: a,x
; warning, don't run with an interrupt that doesn't handle decimal flag
; properly, such as the KERNAL
; stolen from http://codebase64.org/doku.php?id=base:more_hexadecimal_to_decimal_conversion
int16tobcd ldx #0
	stx outbcd+0
	stx outbcd+1
	stx outbcd+2
	ldx #15
	sed
-	asl inbcd+0
	rol inbcd+1
	lda outbcd+0
	adc outbcd+0
	sta outbcd+0
	lda outbcd+1
	adc outbcd+1
	sta outbcd+1
	lda outbcd+2
	adc outbcd+2
	sta outbcd+2
	dex
	bpl -
	cld
	rts
inbcd	!byte 0,0
outbcd	!byte 0,0,0

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

; the actual program

start	lda #0
	sta twos
	sta threes
	ldx #<input
	ldy #>input
	stx zp+0
	sty zp+1
	; start of new word
loop	; reset letter frequency counters
	ldx #25
	lda #0
-	sta freq,x
	dex
	bpl -
	; read word, count the number of occurrences of each letter
	ldy #0
-	lda (zp),y
	beq done   ; found eof, jump to output
	cmp #13
	beq enter  ; found linebreak, process word
	sbc #$61   ; convert to 0-indexed. no sbc needed, carry is set here
	tax
	inc freq,x ; increase frequency
incptr	inc zp     ; increase pointer to next char
	bne -
	inc zp+1
	bne -
enter	; check if there are letters that occur twice
	ldx #25
-	lda freq,x
	cmp #2
	bne +
	inc twos ; found a letter with frequency 2, increase twos
	jmp check3
+	dex
	bpl -
check3	; check if there are letters that occur three times
	ldx #25
-	lda freq,x
	cmp #3
	bne +
	inc threes ; found a letter with frequency 3, increase threes
	jmp nextw
+	dex
	bpl -
	; done, process next word
nextw	inc zp     ; increase pointer to next char
	bne loop
	inc zp+1
	bne loop
done	; we checked all words, do the multiplication
	lda twos
	sta mul1
	lda threes
	sta mul2
	jsr mul8
	; convert answer to bcd
	lda product+0
	sta inbcd+0
	lda product+1
	sta inbcd+1
	jsr int16tobcd
	; output answer
	ldx #<outbcd
	ldy #>outbcd
	lda #3
	jsr printbcd
	lda #13
	jmp CHROUT

freq	!fill 26,0 

	; input! words separated by linebreak, list ends with 0
input	!text "ohvflkatysoimjxbunazgwcdpr",13
	!text "ohoflkctysmiqjxbufezgwcdpr",13
	!text "ohvflkatysciqwxfunezgwcdpr",13
	!text "fhvflyatysmiqjxbunazgwcdpr",13
	!text "ohvhlkatysmiqjxbunhzgwcdxr",13
	!text "ohvflbatykmiqjxbunezgscdpr",13
	!text "ohvflkatasaiqjxbbnezgwcdpr",13
	!text "ohvflkatyymiqjxrunetgwcdpr",13
	!text "ohvflkatbsmiqhxbunezgwcdpw",13
	!text "oheflkytysmiqjxbuntzgwcdpr",13
	!text "ohvflkatrsmiqjibunezgwcupr",13
	!text "ohvflkaiysmiqjxbunkzgwkdpr",13
	!text "ohvilkutysmiqjxbuoezgwcdpr",13
	!text "phvflkatysmkqjxbulezgwcdpr",13
	!text "ohvflkatnsmiqjxbznezgpcdpr",13
	!text "ohvylkatysriqjobunezgwcdpr",13
	!text "ohvflkatytmiqjxbunezrwcypr",13
	!text "ohvonkatysmiqjxbunezgwxdpr",13
	!text "ohvflkatgsmoqjxyunezgwcdpr",13
	!text "ohvflkbtqsmicjxbunezgwcdpr",13
	!text "ohvflkatysmgqjqbunezgwcdvr",13
	!text "ohvtlkatyrmiqjxbunezgwcdpi",13
	!text "ohvflkatyskovjxbunezgwcdpr",13
	!text "ohvflkayysmipjxbunezgwcdpu",13
	!text "ohvalkltysmiqjxbunezgecdpr",13
	!text "ohvflkatysmiqjxiunezgnndpr",13
	!text "ohvflkatyomiqjxbbnezgwcdpp",13
	!text "ohvflkatysmiqjxbuoezgncdpy",13
	!text "omvflkvtysmiqjxwunezgwcdpr",13
	!text "ohvflkatynmicjxbunezgwpdpr",13
	!text "ohvflkatyqmaqjxbunezvwcdpr",13
	!text "ohbfhkatysmiqjxbunezgwcdqr",13
	!text "ohvflkatesmiqjvbunezpwcdpr",13
	!text "ohvflkatysmsqjxiunezgwcdhr",13
	!text "ohvfjkatysmwqjxbunezgwcddr",13
	!text "ohvflkanysmiqjxbunwkgwcdpr",13
	!text "ohqflkatysmiqjxbuuezgwcddr",13
	!text "ohvflkatysmvqjxbznlzgwcdpr",13
	!text "ohvflkatysmiqjxbunjzwwqdpr",13
	!text "ohvfjkatysmiqxxbunezgwcupr",13
	!text "chvfxkatysmiqjxxunezgwcdpr",13
	!text "uhvflkatitmiqjxbunezgwcdpr",13
	!text "ohvflbatysmiqjxbuntzgwcdor",13
	!text "ohvflkmtysmmqjxbunexgwcdpr",13
	!text "ohvflsatysmyqjxjunezgwcdpr",13
	!text "ohvfskatysmiqjjbunezgwcdpg",13
	!text "ohvflkatysniqjxbunexgwcrpr",13
	!text "ohvfekatysmiqjxbunedswcdpr",13
	!text "ohvfltatysmjqjxbunezghcdpr",13
	!text "ohvflkatydmiqjxvunezggcdpr",13
	!text "oavflkatysmiqjxtunazgwcdpr",13
	!text "ohvflkltysmiqjxbuzeugwcdpr",13
	!text "ohbflkatysmiqjybuuezgwcdpr",13
	!text "ehvfzkatysmiqjxbuhezgwcdpr",13
	!text "odvflkatssmiqjxbunezgwcdpj",13
	!text "ohvflkatysmiqjzbufezgwbdpr",13
	!text "jhvflkdtysmiqqxbunezgwcdpr",13
	!text "ohvflkatysmiqjwbunengwcnpr",13
	!text "ohvfskatysmiqjxbxuezgwcdpr",13
	!text "ohvflkatysmiqjobvnezgwcrpr",13
	!text "ohvrlkatysmiqjxbwnezgrcdpr",13
	!text "ofvflkatysmiqjxbunezpwcdwr",13
	!text "ohvfxdatyomiqjxbunezgwcdpr",13
	!text "yhvflkatydmiqjxbubezgwcdpr",13
	!text "ohvflkatysdiqjxbuneztwcspr",13
	!text "ohvflkatydmiquxbunezgwcbpr",13
	!text "ohvflkatysmiqcxbukezgwcdwr",13
	!text "ohvflkntasmiqjxbunezghcdpr",13
	!text "lhvflkatysmiqjxbunezqwckpr",13
	!text "ehifikatysmiqjxbunezgwcdpr",13
	!text "ohvflkatysmiqjcbutezgwcdpm",13
	!text "ohvflkatjssiqrxbunezgwcdpr",13
	!text "oyvflkavysmiqjxlunezgwcdpr",13
	!text "orvflkgtysmiqjxbukezgwcdpr",13
	!text "ihvflkatysmiqaxbunpzgwcdpr",13
	!text "ohvflkatusmiqjxbbnezgwchpr",13
	!text "ohvflkatysbiqjxvuneugwcdpr",13
	!text "ohvflkatysmiqjcbungzgwcwpr",13
	!text "ovvflkatysmidjxbunezgscdpr",13
	!text "ohvflqatysmiljxbunfzgwcdpr",13
	!text "ghvfokatysmiqjxbunqzgwcdpr",13
	!text "nxvflkatysmxqjxbunezgwcdpr",13
	!text "ohvflkatysmiqjxbexezgwrdpr",13
	!text "ohvfrkatysmhqjxbuntzgwcdpr",13
	!text "ohvflkvtysmiqjxocnezgwcdpr",13
	!text "ohvglkgtysmiqjxnunezgwcdpr",13
	!text "ohvflkatysmnqjxbunecgwqdpr",13
	!text "oyvflkatysgiqjxbcnezgwcdpr",13
	!text "ofvflkatysmiqjxbunfzgwcdpg",13
	!text "otvflkttysmiqjxbunezgwmdpr",13
	!text "ohvflkvtysmiqjbbunezgzcdpr",13
	!text "ahvflkatysyiqjxbunezvwcdpr",13
	!text "ohiflkatysmydjxbunezgwcdpr",13
	!text "ohvfwkatysmvqjxbunezwwcdpr",13
	!text "ohvflkatysbiqjxbunergwodpr",13
	!text "hhvsdkatysmiqjxbunezgwcdpr",13
	!text "ihvflkwtysmiqjxbunezgacdpr",13
	!text "ohvfljatysmiqcxbunuzgwcdpr",13
	!text "ohvflkatysqiqlwbunezgwcdpr",13
	!text "ohvflkauysmkqjxwunezgwcdpr",13
	!text "ohvflkatysmoqjqbunezgwodpr",13
	!text "ohvslkvtysmipjxbunezgwcdpr",13
	!text "olvflkatysmiujxbunezgwctpr",13
	!text "osvflxatysmiqjxbenezgwcdpr",13
	!text "orvflkhtysmiqjxbinezgwcdpr",13
	!text "ohcflkatystiqjxbunezbwcdpr",13
	!text "ohcflkatyfmifjxbunezgwcdpr",13
	!text "ohvflkatdsmiqjxbrnezgwcdpt",13
	!text "ohvflkatysmiqjxbwnqzawcdpr",13
	!text "oevflkakysmiqjxbunezgwcdpt",13
	!text "ofvflkatysmiqjxbunbqgwcdpr",13
	!text "ohvflkatysmdqjxbunefqwcdpr",13
	!text "ohvklkalysmiqjxbunezgwcepr",13
	!text "ocvflhatysmiqjxbunezzwcdpr",13
	!text "uhvflkatysmiqmxbunezgwcxpr",13
	!text "ohvflkatyshikjhbunezgwcdpr",13
	!text "lbvflkatysmoqjxbunezgwcdpr",13
	!text "ohvflkatssmuqjxbunezgscdpr",13
	!text "ohvflkatysmifyxbuvezgwcdpr",13
	!text "ohvfikatysmiqjxbunezgwfupr",13
	!text "ohvmlkaiysmiqjxqunezgwcdpr",13
	!text "ohvflkatysmiqjxiunpzgwcdpo",13
	!text "lhvflkatysmpqjxbenezgwcdpr",13
	!text "ohvflkatysmiqjobunengwczpr",13
	!text "ohoflkatysniqjxbunezgccdpr",13
	!text "ohvfxkatysmiqjgbunyzgwcdpr",13
	!text "ohvflkytysmiljxbubezgwcdpr",13
	!text "hhvsdkatysmiqjxjunezgwcdpr",13
	!text "ohvflkatysmiqjtuunezgwcdpt",13
	!text "ohvfdkxtysmiqjubunezgwcdpr",13
	!text "ohxflkatysmiyjxbunezgwcdhr",13
	!text "ohvflkatysmiqjibunezgwcppd",13
	!text "ohvflkatysmihjxbunezgwcdhj",13
	!text "ohvflkatysmiqjxronezgwcdvr",13
	!text "ofrflxatysmiqjxbunezgwcdpr",13
	!text "ohvwlkatysmiqjxounezgscdpr",13
	!text "ohvflkatcodiqjxbunezgwcdpr",13
	!text "oqvflkatysmiqjxbunebgwmdpr",13
	!text "ohvflmatysmisjxbunezqwcdpr",13
	!text "ovvflkatysmiqjxbuxezgwcdpe",13
	!text "ohvflkatysmdejxbuneztwcdpr",13
	!text "hhvflkathsmiqjxbwnezgwcdpr",13
	!text "ohkflkatlsmsqjxbunezgwcdpr",13
	!text "ohvflkktysmizjxhunezgwcdpr",13
	!text "ohzflkatysmiqjrbunezgwcdpj",13
	!text "ohuflwatysmiqjxbunezgwcdgr",13
	!text "ohvflkatysmiqvxmunpzgwcdpr",13
	!text "xhvflkwtysmiqjxbunezgwjdpr",13
	!text "whvflkatysmiqjxbunezgzcopr",13
	!text "ohvflkayysmiqjxuznezgwcdpr",13
	!text "khvflkasysmiqjxbunezgwcdpv",13
	!text "ohvflkatylmiqjxbpnozgwcdpr",13
	!text "ohvflkgtysziqjxbunezgwgdpr",13
	!text "ohvfljaiysmiqjxbuvezgwcdpr",13
	!text "ohvflkxtyslizjxbunezgwcdpr",13
	!text "ohzflkatysmiqjxbcnezgwcdar",13
	!text "ohvflkatysmiqjxbisecgwcdpr",13
	!text "shvflkatyjmiqjkbunezgwcdpr",13
	!text "mhvflkatysmiqjxvunezgwcdpk",13
	!text "ohfflkatysmiqjxbunczgwcppr",13
	!text "ohvflkatysmiqjkzunezgwcdpc",13
	!text "ohvflkatysmifjxbuneygwctpr",13
	!text "ohvflkatysmimjbbunezgwcdpe",13
	!text "ohvflkatjsciqjxbunezgwcdpa",13
	!text "ohvxlkatysmitjxbunezswcdpr",13
	!text "ohvslkatfsmiqjxbunezgwudpr",13
	!text "ohvflkatysmiqexbugezgwcdnr",13
	!text "onvflkatysmiqjxkunezgtcdpr",13
	!text "fhsflkalysmiqjxbunezgwcdpr",13
	!text "oyvflkatysmiqjobxnezgwcdpr",13
	!text "ohvflkatysmiqjxbunezswgdvr",13
	!text "phvflkatyymiqjxvunezgwcdpr",13
	!text "oivflzutysmiqjxbunezgwcdpr",13
	!text "ohvflkftysmiqjxbunezkwcopr",13
	!text "ohvflkatysmwnjxbunezgwcdpp",13
	!text "ohvflkatysmiqkxcunezgwndpr",13
	!text "phvklkatysmiqjhbunezgwcdpr",13
	!text "ohvflrawysmiqjxbunhzgwcdpr",13
	!text "ohvflkatysmiqjxbunecgwcdig",13
	!text "ohvflpakysmiqjxbunezgwrdpr",13
	!text "odvflkatykmiqjxbunezglcdpr",13
	!text "ohtflkatysiiqjxblnezgwcdpr",13
	!text "lhvfpkatysmiqjxbupezgwcdpr",13
	!text "ohvflkatdsmiqjpbunezgwcdps",13
	!text "ohvflkztysmiqjxvunezgwjdpr",13
	!text "ohvflbatysmxqoxbunezgwcdpr",13
	!text "ohvklkaigsmiqjxbunezgwcdpr",13
	!text "ohvfgkawysmiqjxbunezgwcdur",13
	!text "ohvflkatyskpqjlbunezgwcdpr",13
	!text "ohvflkatyqmiqjhbupezgwcdpr",13
	!text "ohqflkatysmiqjxzonezgwcdpr",13
	!text "ohxfnkatyymiqjxbunezgwcdpr",13
	!text "ohmflkatpsmiqjxbunezgwcdpw",13
	!text "ohvflkatysmiqjibnnewgwcdpr",13
	!text "vevflkatysmiqjxbunezgwcypr",13
	!text "ohvflkatydmiqwxbungzgwcdpr",13
	!text "ohsrlkatysmiqjxbcnezgwcdpr",13
	!text "ohvflkptyvmiqexbunezgwcdpr",13
	!text "opzflkatysmiqjxrunezgwcdpr",13
	!text "ohvflkitysmiqjxcunezgwcmpr",13
	!text "ohvflkatysmhhjxblnezgwcdpr",13
	!text "ohvflkatysfiqjxbunrzgwmdpr",13
	!text "ohvflkatyamibjxbunezgwcdpf",13
	!text "ohvflkalysmigjxbunezggcdpr",13
	!text "ohvflkatwsmisjxbunezgdcdpr",13
	!text "dhvflkatysmlqjxbunszgwcdpr",13
	!text "ohvflkatysmiqjxbueeygwcbpr",13
	!text "ohvflkatgsmiqjnbunezhwcdpr",13
	!text "svvflkatysmiqjxbunezgwckpr",13
	!text "opvflkatysmiqpxbufezgwcdpr",13
	!text "ohnvlkatysmiqjxbunezglcdpr",13
	!text "phvflkutysjiqjxbunezgwcdpr",13
	!text "ohvflabtysmiqjjbunezgwcdpr",13
	!text "ouvflkatysmiqjsbunezgwcdpk",13
	!text "osvflkatysmijjxbunezgwcypr",13
	!text "owvflkatysmiqjxbukxzgwcdpr",13
	!text "ohvfliatvsmiljxbunezgwcdpr",13
	!text "ohvflkatysmiqjxbumezbwtdpr",13
	!text "ohvflkatyfcicjxbunezgwcdpr",13
	!text "ohvflkatysmiqldbunezgfcdpr",13
	!text "oqvflkatysmiqixkunezgwcdpr",13
	!text "ohvflkatysmiqjxbulezgicdpe",13
	!text "ohvflkatysmiqjxbuniegwcdpl",13
	!text "ohvflkatysmiqjwbunbzgwcdhr",13
	!text "ohvflkatysmiqjdbunezgwwdkr",13
	!text "ohqflkytysmiqjxbunezgwcdpc",13
	!text "ohvflkatysmigjxbunezqwwdpr",13
	!text "ohvfloatysmiqjpbumezgwcdpr",13
	!text "ohvklkathkmiqjxbunezgwcdpr",13
	!text "ohvflkstjsmiqjxbunezgwctpr",13
	!text "ohvvlkatysmiqjxbunewgwcdir",13
	!text "ohnflkatysmiqjxbunszgwcdlr",13
	!text "ohvflkatysmnqjxbunezgxcdlr",13
	!text "ohvfrkatysmiqjxbonezgwcdor",13
	!text "ihvflkatysmiqjxbuneogwcxpr",13
	!text "ohvflkatysmiqjxbunecgwcccr",13
	!text "owvflkatysmivjxbunezgwjdpr",13
	!text "ohvflkgtysmiqjxbunczhwcdpr",13
	!text "ohyqlkatysmiqjxbunezgwcypr",13
	!text "ohvflkatysmiqjvbunezuwcdpw",13
	!text "ohvflkathsmiqmxbuoezgwcdpr",13
	!text "ehvjlkajysmiqjxbunezgwcdpr",13
	!text "ohvflkltysmiqjxblnezgwjdpr",13
	!text "oovflkvtfsmiqjxbunezgwcdpr",13
	!text "olvfzkatysmiqjxyunezgwcdpr",13
	!text "ohvflkatysqitjxbunezgncdpr",13
	!text "yhvflkatysmkqjxbunazgwcdpr",13
	!text "zlvolkatysmiqjxbunezgwcdpr",13
	!text "ohvflpatysmiqjxbunezgwcapb",13
	!text "ohvflkatysmuqjxbunezgfcdur",13,0
