	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; system id
	dc.b "SEGADISCSYSTEM  "
	dc.b "SEGAIPSAMP ",0
	dc.w $0100,$0001
	dc.b "SONICCD    ",0
	dc.w $0000,$0000
	dc.l $0800,initial_end-$0800,0,0
	dc.l system,system_end-system,0,0
	dc.b "08061993        "
	dc.b "                "
	dc.b "                "
	dc.b "                "
	dc.b "                "
	dc.b "                "
	dc.b "                "
	dc.b "                "
	dc.b "                "
	dc.b "                "
	dc.b "                "
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; disc id
	dc.b "SEGA MEGA DRIVE "
	dc.b "(C)SEGA 1993.AUG"
	dc.b "SONIC THE HEDGEHOG-CD                           "
	dc.b "SONIC THE HEDGEHOG-CD                           "
	dc.b "GM G-6021  -00  "
	dc.b "J               "
	dc.b "                "
	dc.b "                "
	dc.b "                "
	dc.b "                "
	dc.b "                "
	dc.b "J               "
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; initial program
initial
	incbin main.bin
	align 11
initial_end
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; system program
system
	incbin sub.bin
	align 11
system_end
	
	