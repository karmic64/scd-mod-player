*---------------------------------------------------------------*

RTE_CODE	equ	$4e73
JMP_CODE	equ	$4ef9

;  OS system RAM assignments
;  jump table
;  vector table is 6 bytes each, but an address only needs 4 bytes.
;  Each table entry contains 2 bytes of table data and 4 bytes of 
;  address.  In other code, when you see these vectors accessed, they
;  will always be accessed with a +2, and that is why.

os_sys_ram      equ     $fffd00
_reset          equ     os_sys_ram      ;fffd00 -reset jump table
_mlevel6        equ     _reset+6        ;fffd06 -V interrupt
_mlevel4        equ     _mlevel6+6      ;fffd0c -H interrupt
_mlevel2        equ     _mlevel4+6      ;fffd12 -external interrupt
_mtrap00        equ     _mlevel2+6      ;fffd18 -TRAP #00
_mtrap01        equ     _mtrap00+6      ;fffd1e
_mtrap02        equ     _mtrap01+6      ;fffd24
_mtrap03        equ     _mtrap02+6      ;fffd2a
_mtrap04        equ     _mtrap03+6      ;fffd30
_mtrap05        equ     _mtrap04+6      ;fffd36
_mtrap06        equ     _mtrap05+6      ;fffd3c
_mtrap07        equ     _mtrap06+6      ;fffd42
_mtrap08        equ     _mtrap07+6      ;fffd48
_mtrap09        equ     _mtrap08+6      ;fffd4e
_mtrap10        equ     _mtrap09+6      ;fffd54
_mtrap11        equ     _mtrap10+6      ;fffd5a
_mtrap12        equ     _mtrap11+6      ;fffd60
_mtrap13        equ     _mtrap12+6      ;fffd66
_mtrap14        equ     _mtrap13+6      ;fffd6c
_mtrap15        equ     _mtrap14+6      ;fffd72
_monkerr        equ     _mtrap15+6      ;fffd78 -onk
_madrerr        equ     _monkerr+6      ;fffd7e -address error
_mcoderr        equ     _monkerr+6      ;fffd7e -undefined code
_mdiverr        equ     _mcoderr+6      ;fffd84 -divide error
_mtrperr        equ     _mdiverr+6      ;fffd8e
_mnocod0        equ     _mtrperr+6      ;fffd90
_mnocod1        equ     _mnocod0+6      ;fffd96
_mspverr        equ     _mnocod1+6      ;fffd9c
_mtrace         equ     _mspverr+6      ;fffda2
_vint_ex        equ     _mtrace+6       ;fffda8