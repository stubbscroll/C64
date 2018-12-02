; advent of code 2018 day 2, part 2
; https://adventofcode.com/2018/day/2
; algorithm: compare each pair of strings with a double loop
; runtime: 14 seconds

	CHROUT = $ffd2

	!to "02b.prg",cbm
	* = $0801
	; sys start
	!byte $0b, $08, $0a, $00, $9e, 48+start/1000%10, 48+start/100%10, 48+start/10%10, 48+start%10, $00, $00, $00

	zp1 = $fe ; index to string in outer loop
	zp2 = $fc ; inner loop

start	ldx #<input
	ldy #>input
	stx zp1+0
	sty zp1+1
loop1	; from zp1, find next word
	ldx zp1+0
	ldy zp1+1
	stx zp2+0
	sty zp2+1
	ldy #0
-	lda (zp2),y
	cmp #13
	beq +
	iny
	bne -
+	tya
	sec ; add y+1, set carry to avoid adding 1
	adc zp2+0
	sta zp2+0
	bne +
	inc zp2+1
+
loop2	; inner loop: try outer string with all strings following it in the list
	ldy #0
	ldx #0
	; count different letters (x holds the count)
-	lda (zp2),y
	beq next1
	cmp #13
	beq enter
	cmp (zp1),y
	beq +
	inx
+	iny
	bne -
enter	cpx #1
	beq won ; we found a pair with 1 different letter, go to output
	tya
	sec
	adc zp2+0
	sta zp2+0
	bcc loop2
	inc zp2+1
	bne loop2

next1	; inner loop done, find next outer loop string
	; here we assume that the problem has a solution, so we skip checking
	; if the loop terminates
	ldy #0
-	lda (zp1),y
	cmp #13
	beq +
	iny
	bne -
+	tya
	sec
	adc zp1+0
	sta zp1+0
	bcc loop1
	inc zp1+1
	bne loop1

won	; output common letters between the 2 words
	ldy #0
-	lda (zp1),y
	cmp #13
	beq ++
	cmp (zp2),y
	bne +
	and #$df
	jsr CHROUT
+	iny
	bne -
++	rts

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
