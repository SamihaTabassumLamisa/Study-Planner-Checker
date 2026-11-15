; ============================================================
;  STUDY PLANNER - 8086 Assembly for EMU8086  v3.1
; ============================================================
;  1. View all subjects (full table)
;  2. Add subject
;  3. Sort by name A-Z
;  4. Delete subject by name
;  5. Update start time by name
;  6. Update hours by name
;  7. View total study hours
;  8. Mark subject Completed/Pending  [NEW]
;  9. Reset all data                  [NEW]
;  E. Exit
;  Max 12 subjects. Names forced to CAPITALS.
; ============================================================
;
; STORAGE LAYOUT per entry (32 bytes):
;   byte  0    : hours per session (1-9)
;   byte  1    : start-hour  (0-23)
;   byte  2    : start-minute (0-59)
;   bytes 3-22 : name (null-terminated, max 20 chars)
;   byte  23   : status  0=PENDING  1=COMPLETED
;   bytes 24-31: padding (zeroed)
; ============================================================

.MODEL SMALL
.STACK 200H

.DATA

banner  DB 13,10
        DB '============================================',13,10
        DB '       8086 STUDY PLANNER  v3.1             ',13,10
        DB '       MAX 12 SUBJECTS  |  CAPS MODE         ',13,10
        DB '============================================',13,10,'$'

menu    DB 13,10
        DB '  [1] VIEW ALL SUBJECTS (FULL TABLE)',13,10
        DB '  [2] ADD SUBJECT',13,10
        DB '  [3] SORT BY NAME (A-Z)',13,10
        DB '  [4] DELETE SUBJECT BY NAME',13,10
        DB '  [5] UPDATE START TIME BY NAME',13,10
        DB '  [6] UPDATE HOURS BY NAME',13,10
        DB '  [7] VIEW TOTAL STUDY HOURS',13,10
        DB '  [8] MARK SUBJECT COMPLETED/PENDING',13,10
        DB '  [9] RESET ALL DATA',13,10
        DB '  [E] EXIT',13,10,13,10
        DB '  CHOOSE (1-9, E): $'

p_name  DB 13,10,'ENTER SUBJECT NAME (MAX 20 CHARS): $'
p_hour  DB 13,10,'ENTER START HOUR   (0-23): $'
p_min   DB 13,10,'ENTER START MINUTE (0-59): $'
p_hrs   DB 13,10,'ENTER HOURS/SESSION (1-9): $'
p_find  DB 13,10,'ENTER SUBJECT NAME TO FIND: $'

m_added DB 13,10,'>>> SUBJECT ADDED! $'
m_deld  DB 13,10,'>>> SUBJECT DELETED! $'
m_upd   DB 13,10,'>>> UPDATED! $'
m_sort  DB 13,10,'>>> SORTED A-Z! $'
m_full  DB 13,10,'>>> ERROR: MAX 12 SUBJECTS REACHED! $'
m_empty DB 13,10,'>>> NO SUBJECTS YET. $'
m_nf    DB 13,10,'>>> SUBJECT NOT FOUND! $'
m_inv   DB 13,10,'>>> INVALID INPUT. $'
m_dup   DB 13,10,'>>> ERROR: ANOTHER SUBJECT ALREADY AT THAT TIME or NAME! $'
m_tot   DB 13,10,'>>> TOTAL HOURS: $'
m_nl    DB 13,10,'$'
m_div   DB 13,10,'--------------------------------------------$'

m_hdr   DB 13,10
        DB '  #  | NAME                 | START | HRS | STATUS   ',13,10
        DB '-----+----------------------+-------+-----+----------',13,10,'$'
m_sep   DB ' | $'

; --- new strings ---
m_comp  DB 13,10,'>>> MARKED AS COMPLETED! $'
m_pend  DB 13,10,'>>> MARKED AS PENDING! $'
m_rst   DB 13,10,'>>> ALL DATA RESET! $'
s_comp  DB 'COMPLETED $'
s_pend  DB 'PENDING   $'
p_mark  DB 13,10,'ENTER NUMBER OF SUBJECT TO MARK: $'
p_mkst  DB 13,10,'ENTER 1=COMPLETED  0=PENDING: $'
p_rscon DB 13,10,'RESET ALL DATA? PRESS Y TO CONFIRM: $'

; ------ Storage ------
s_count DB  0
s_data  DB  12 * 32 DUP(0)   ; 384 bytes
t_hours DW  0

n_buf   DB  22, 0, 22 DUP(0)
f_buf   DB  22, 0, 22 DUP(0)

t_h     DB  0
t_m     DB  0
t_hr    DB  0
AH_T    DB  0
SI_SV   DW  0
pn_val  DW  0
pn_lz   DB  0

; scratch for option 8
mk_num  DB  0

.CODE

MAIN PROC
    MOV  AX, @DATA
    MOV  DS, AX
    MOV  ES, AX

MLOOP:
    LEA  DX, banner
    CALL PSTR
    LEA  DX, menu
    CALL PSTR
    CALL RCHAR
    MOV  BL, AL
    LEA  DX, m_nl
    CALL PSTR

    CMP  BL, '1'
    JE   DO_VIEW
    CMP  BL, '2'
    JE   DO_ADD
    CMP  BL, '3'
    JE   DO_SORT
    CMP  BL, '4'
    JE   DO_DEL
    CMP  BL, '5'
    JE   DO_UPT
    CMP  BL, '6'
    JE   DO_UPH
    CMP  BL, '7'
    JE   DO_TOT
    CMP  BL, '8'
    JE   DO_MARK
    CMP  BL, '9'
    JE   DO_RESET
    CMP  BL, 'E'
    JE   DO_EXIT
    CMP  BL, 'e'
    JE   DO_EXIT
    LEA  DX, m_inv
    CALL PSTR
    JMP  MLOOP

; ============================================================
; [1] VIEW ALL SUBJECTS  (STATUS column added)
; ============================================================
DO_VIEW:
    CMP  s_count, 0
    JNE  VW_GO
    LEA  DX, m_empty
    CALL PSTR
    JMP  MLOOP
VW_GO:
    LEA  DX, m_hdr
    CALL PSTR
    MOV  CL, s_count
    MOV  CH, 0
    MOV  SI, 0
    MOV  BH, 1
VW_ROW:
    JCXZ VW_END

    MOV  AL, BH
    CALL PB2
    MOV  DL, ' '
    MOV  AH, 02H
    INT  21H
    LEA  DX, m_sep
    CALL PSTR

    ; name padded to 20
    MOV  DI, SI
    ADD  DI, 3
    MOV  BL, 20
VW_NLP:
    CMP  BL, 0
    JE   VW_NEND
    MOV  AH_T, BL
    MOV  AL, s_data[DI]
    CMP  AL, 0
    JE   VW_NPAD
    MOV  DL, AL
    MOV  AH, 02H
    INT  21H
    INC  DI
    MOV  BL, AH_T
    DEC  BL
    JMP  VW_NLP
VW_NPAD:
    MOV  DL, ' '
    MOV  AH, 02H
    INT  21H
    MOV  BL, AH_T
    DEC  BL
    JMP  VW_NLP
VW_NEND:
    LEA  DX, m_sep
    CALL PSTR

    ; HH:MM
    MOV  DI, SI
    INC  DI
    MOV  AL, s_data[DI]
    CALL PB2
    MOV  DL, ':'
    MOV  AH, 02H
    INT  21H
    INC  DI
    MOV  AL, s_data[DI]
    CALL PB2
    LEA  DX, m_sep
    CALL PSTR

    ; hours
    MOV  AL, s_data[SI]
    ADD  AL, '0'
    MOV  DL, AL
    MOV  AH, 02H
    INT  21H
    MOV  DL, 'H'
    MOV  AH, 02H
    INT  21H
    LEA  DX, m_sep
    CALL PSTR

    ; status at byte 23 of entry
    MOV  DI, SI
    ADD  DI, 23
    MOV  AL, s_data[DI]
    CMP  AL, 1
    JE   VW_COMP
    LEA  DX, s_pend
    CALL PSTR
    JMP  VW_NEXT
VW_COMP:
    LEA  DX, s_comp
    CALL PSTR
VW_NEXT:
    LEA  DX, m_nl
    CALL PSTR
    ADD  SI, 32
    INC  BH
    DEC  CX
    JMP  VW_ROW
VW_END:
    LEA  DX, m_div
    CALL PSTR
    JMP  MLOOP

; ============================================================
; [2] ADD SUBJECT
; ============================================================
DO_ADD:
    MOV  AL, s_count
    CMP  AL, 12
    JL   DA_OK
    LEA  DX, m_full
    CALL PSTR
    JMP  MLOOP
DA_OK:
    LEA  DX, p_name
    CALL PSTR
    LEA  DX, n_buf
    MOV  AH, 0AH
    INT  21H
    CALL UC_NAME
    LEA  DX, m_nl
    CALL PSTR

    ; --- check duplicate name ---
    MOV  CL, s_count
    MOV  CH, 0
    MOV  SI, 0
DA_NCHK:
    JCXZ DA_NCHK_OK
    LEA  BX, n_buf
    MOV  DL, [BX+1]
    MOV  DH, 0
    ADD  BX, 2
    MOV  DI, SI
    ADD  DI, 3
DA_NCMP:
    MOV  AL, [BX]
    MOV  AH, s_data[DI]
    CMP  AL, AH
    JNE  DA_NNXT
    CMP  AL, 0
    JE   DA_NDUP
    INC  BX
    INC  DI
    DEC  DX
    JNZ  DA_NCMP
    CMP  s_data[DI], 0
    JE   DA_NDUP
DA_NNXT:
    ADD  SI, 32
    DEC  CX
    JMP  DA_NCHK
DA_NDUP:
    LEA  DX, m_dup
    CALL PSTR
    JMP  MLOOP
DA_NCHK_OK:

    LEA  DX, p_hour
    CALL PSTR
    CALL RD2
    MOV  t_h, AL
    LEA  DX, m_nl
    CALL PSTR

    LEA  DX, p_min
    CALL PSTR
    CALL RD2
    MOV  t_m, AL
    LEA  DX, m_nl
    CALL PSTR

    LEA  DX, p_hrs
    CALL PSTR
DA_HRS:
    CALL RCHAR
    SUB  AL, '0'
    CMP  AL, 1
    JB   DA_HRS
    CMP  AL, 9
    JA   DA_HRS
    MOV  t_hr, AL
    LEA  DX, m_nl
    CALL PSTR

    MOV  CL, s_count
    MOV  CH, 0
    MOV  SI, 0
DA_CHKLP:
    JCXZ DA_CHKOK
    MOV  DI, SI
    INC  DI
    MOV  AL, s_data[DI]
    CMP  AL, t_h
    JNE  DA_CHKNXT
    INC  DI
    MOV  AL, s_data[DI]
    CMP  AL, t_m
    JNE  DA_CHKNXT
    LEA  DX, m_dup
    CALL PSTR
    JMP  MLOOP
DA_CHKNXT:
    ADD  SI, 32
    DEC  CX
    JMP  DA_CHKLP
DA_CHKOK:
    MOV  AH, 0
    MOV  AL, s_count
    MOV  BX, 32
    MUL  BX
    MOV  SI, AX

    MOV  AL, t_hr
    MOV  s_data[SI], AL

    MOV  DI, SI
    INC  DI
    MOV  AL, t_h
    MOV  s_data[DI], AL

    INC  DI
    MOV  AL, t_m
    MOV  s_data[DI], AL

    INC  DI
    LEA  BX, n_buf
    MOV  CL, [BX+1]
    MOV  CH, 0
    ADD  BX, 2
DA_CNAME:
    JCXZ DA_CNEND
    MOV  AL, [BX]
    MOV  s_data[DI], AL
    INC  DI
    INC  BX
    DEC  CX
    JMP  DA_CNAME
DA_CNEND:
    MOV  s_data[DI], 0

    ; initialise status byte 23 = 0 (PENDING)
    MOV  DI, SI
    ADD  DI, 23
    MOV  BYTE PTR s_data[DI], 0

    INC  s_count
    MOV  AH, 0
    MOV  AL, t_hr
    ADD  t_hours, AX

    LEA  DX, m_added
    CALL PSTR
    JMP  MLOOP

; ============================================================
; [3] SORT A-Z (unchanged)
; ============================================================
DO_SORT:
    MOV  AL, s_count
    CMP  AL, 2
    JL   SORT_END
    MOV  CL, s_count
    DEC  CL
SOUT:
    CMP  CL, 0
    JE   SORT_END
    MOV  CH, 0
SINN:
    MOV  AH, 0
    MOV  AL, CH
    MOV  BX, 32
    MUL  BX
    MOV  SI, AX
    MOV  AL, CH
    INC  AL
    MUL  BX
    MOV  DI, AX
    PUSH SI
    PUSH DI
    PUSH CX
    ADD  SI, 3
    ADD  DI, 3
    CALL SCMP
    POP  CX
    POP  DI
    POP  SI
    JNC  SNO_SWAP
    MOV  AH, 32
SWLP:
    MOV  AL, s_data[SI]
    MOV  BL, s_data[DI]
    MOV  s_data[SI], BL
    MOV  s_data[DI], AL
    INC  SI
    INC  DI
    DEC  AH
    JNZ  SWLP
SNO_SWAP:
    INC  CH
    MOV  AL, s_count
    DEC  AL
    CMP  CH, AL
    JL   SINN
    DEC  CL
    JMP  SOUT
SORT_END:
    LEA  DX, m_sort
    CALL PSTR
    JMP  MLOOP

; ============================================================
; [4] DELETE BY NAME (unchanged)
; ============================================================
DO_DEL:
    CMP  s_count, 0
    JNE  DD_GO
    LEA  DX, m_empty
    CALL PSTR
    JMP  MLOOP
DD_GO:
    LEA  DX, p_find
    CALL PSTR
    LEA  DX, f_buf
    MOV  AH, 0AH
    INT  21H
    CALL UC_FIND
    LEA  DX, m_nl
    CALL PSTR
    CALL FSUB
    JC   DD_NF
    MOV  AL, s_count
    DEC  AL
    CMP  CL, AL
    JE   DD_ZERO
    MOV  AL, s_count
    SUB  AL, CL
    DEC  AL
    MOV  AH, 0
    MOV  BX, AX
    MOV  DI, SI
    MOV  SI_SV, SI
    ADD  SI, 32
DD_SHIFT:
    CMP  BX, 0
    JE   DD_ZERO
    PUSH BX
    MOV  BX, 32
DD_CPY:
    MOV  AL, s_data[SI]
    MOV  s_data[DI], AL
    INC  SI
    INC  DI
    DEC  BX
    JNZ  DD_CPY
    POP  BX
    DEC  BX
    JMP  DD_SHIFT
DD_ZERO:
    MOV  AL, s_count
    DEC  AL
    MOV  AH, 0
    MOV  BX, 32
    MUL  BX
    MOV  DI, AX
    MOV  BX, 32
DD_ZLP:
    MOV  BYTE PTR s_data[DI], 0
    INC  DI
    DEC  BX
    JNZ  DD_ZLP
    DEC  s_count
    LEA  DX, m_deld
    CALL PSTR
    JMP  MLOOP
DD_NF:
    LEA  DX, m_nf
    CALL PSTR
    JMP  MLOOP

; ============================================================
; [5] UPDATE START TIME (unchanged)
; ============================================================
DO_UPT:
    CMP  s_count, 0
    JNE  UPT_GO
    LEA  DX, m_empty
    CALL PSTR
    JMP  MLOOP
UPT_GO:
    LEA  DX, p_find
    CALL PSTR
    LEA  DX, f_buf
    MOV  AH, 0AH
    INT  21H
    CALL UC_FIND
    LEA  DX, m_nl
    CALL PSTR
    CALL FSUB
    JC   UPT_NF
    LEA  DX, p_hour
    CALL PSTR
    CALL RD2
    MOV  DI, SI
    INC  DI
    MOV  s_data[DI], AL
    LEA  DX, m_nl
    CALL PSTR
    LEA  DX, p_min
    CALL PSTR
    CALL RD2
    INC  DI
    MOV  s_data[DI], AL
    LEA  DX, m_nl
    CALL PSTR
    LEA  DX, m_upd
    CALL PSTR
    JMP  MLOOP
UPT_NF:
    LEA  DX, m_nf
    CALL PSTR
    JMP  MLOOP

; ============================================================
; [6] UPDATE HOURS (unchanged)
; ============================================================
DO_UPH:
    CMP  s_count, 0
    JNE  UPH_GO
    LEA  DX, m_empty
    CALL PSTR
    JMP  MLOOP
UPH_GO:
    LEA  DX, p_find
    CALL PSTR
    LEA  DX, f_buf
    MOV  AH, 0AH
    INT  21H
    CALL UC_FIND
    LEA  DX, m_nl
    CALL PSTR
    CALL FSUB
    JC   UPH_NF
    MOV  AH, 0
    MOV  AL, s_data[SI]
    SUB  t_hours, AX
    LEA  DX, p_hrs
    CALL PSTR
UPH_LP:
    CALL RCHAR
    SUB  AL, '0'
    CMP  AL, 1
    JB   UPH_LP
    CMP  AL, 9
    JA   UPH_LP
    MOV  s_data[SI], AL
    MOV  AH, 0
    ADD  t_hours, AX
    LEA  DX, m_nl
    CALL PSTR
    LEA  DX, m_upd
    CALL PSTR
    JMP  MLOOP
UPH_NF:
    LEA  DX, m_nf
    CALL PSTR
    JMP  MLOOP

; ============================================================
; [7] TOTAL HOURS (unchanged)
; ============================================================
DO_TOT:
    ; recalculate t_hours from s_data so delete/update cant corrupt it
    MOV  WORD PTR t_hours, 0
    MOV  CL, s_count
    MOV  CH, 0
    MOV  SI, 0
TOT_LP:
    JCXZ TOT_DONE
    MOV  AH, 0
    MOV  AL, s_data[SI]
    ADD  t_hours, AX
    ADD  SI, 32
    DEC  CX
    JMP  TOT_LP
TOT_DONE:
    LEA  DX, m_tot
    CALL PSTR
    MOV  AX, t_hours
    MOV  BH, 0
    CALL PNUM
    LEA  DX, m_nl
    CALL PSTR
    JMP  MLOOP

; ============================================================
; [8] MARK SUBJECT COMPLETED / PENDING
; ============================================================
DO_MARK:
    CMP  s_count, 0
    JNE  MK_SHOW
    LEA  DX, m_empty
    CALL PSTR
    JMP  MLOOP

MK_SHOW:
    LEA  DX, m_hdr
    CALL PSTR
    MOV  CL, s_count
    MOV  CH, 0
    MOV  SI, 0
    MOV  BH, 1
MK_ROW:  
    CMP CX,0
    JE MK_ASK
    ;BH ROW NUMBER
    MOV  AL, BH
    CALL PB2
    MOV  DL, ' '
    MOV  AH, 02H
    INT  21H
    LEA  DX, m_sep
    CALL PSTR

    MOV  DI, SI
    ADD  DI, 3
    MOV  BL, 20
MK_NLP:
    CMP  BL, 0
    JE   MK_NEND
    MOV  AH_T, BL
    MOV  AL, s_data[DI]
    CMP  AL, 0
    JE   MK_NPAD
    MOV  DL, AL
    MOV  AH, 02H
    INT  21H
    INC  DI
    MOV  BL, AH_T
    DEC  BL
    JMP  MK_NLP
MK_NPAD:
    MOV  DL, ' '
    MOV  AH, 02H
    INT  21H
    MOV  BL, AH_T
    DEC  BL
    JMP  MK_NLP
MK_NEND:
    LEA  DX, m_sep
    CALL PSTR

    MOV  DI, SI
    INC  DI
    MOV  AL, s_data[DI]
    CALL PB2
    MOV  DL, ':'
    MOV  AH, 02H
    INT  21H
    INC  DI
    MOV  AL, s_data[DI]
    CALL PB2
    LEA  DX, m_sep
    CALL PSTR

    MOV  AL, s_data[SI]
    ADD  AL, '0'
    MOV  DL, AL
    MOV  AH, 02H
    INT  21H
    MOV  DL, 'H'
    MOV  AH, 02H
    INT  21H
    LEA  DX, m_sep
    CALL PSTR

    MOV  DI, SI
    ADD  DI, 23
    MOV  AL, s_data[DI]
    CMP  AL, 1
    JE   MK_RCOMP
    LEA  DX, s_pend
    CALL PSTR
    JMP  MK_RNEXT
MK_RCOMP:
    LEA  DX, s_comp
    CALL PSTR
MK_RNEXT:
    LEA  DX, m_nl
    CALL PSTR
    ADD  SI, 32 
    ;BH ROW NUMBER
    INC  BH
    DEC  CX
    JMP  MK_ROW

MK_ASK:
    LEA  DX, m_div
    CALL PSTR
    LEA  DX, p_mark
    CALL PSTR

MK_RNUM:
    CALL RCHAR
    SUB  AL, '0'
    CMP  AL, 1
    JL   MK_RNUM
    MOV  AH, 0
    MOV  BL, s_count
    MOV  BH, 0
    CMP  AX, BX
    JG   MK_RNUM
    MOV  mk_num, AL

    LEA  DX, m_nl
    CALL PSTR

    ; walk to entry: SI = 0, skip (mk_num-1) entries
    MOV  SI, 0
    MOV  BL, mk_num
    DEC  BL
MK_WALK:
    CMP  BL, 0
    JE   MK_FOUND
    ADD  SI, 32
    DEC  BL
    JMP  MK_WALK

MK_FOUND:
    LEA  DX, p_mkst
    CALL PSTR

MK_RDST:
    CALL RCHAR
    CMP  AL, '0'
    JE   MK_SET0
    CMP  AL, '1'
    JE   MK_SET1
    JMP  MK_RDST

MK_SET1:
    MOV  DI, SI
    ADD  DI, 23
    MOV  BYTE PTR s_data[DI], 1
    LEA  DX, m_nl
    CALL PSTR
    LEA  DX, m_comp
    CALL PSTR
    JMP  MLOOP

MK_SET0:
    MOV  DI, SI
    ADD  DI, 23
    MOV  BYTE PTR s_data[DI], 0
    LEA  DX, m_nl
    CALL PSTR
    LEA  DX, m_pend
    CALL PSTR
    JMP  MLOOP

; ============================================================
; [9] RESET ALL DATA
; ============================================================

DO_RESET:
    LEA DX, p_rscon
    CALL PSTR

RST_WAIT:
    CALL RCHAR

    ; ignore leftover Enter / newline
    CMP AL, 13
    JE  RST_WAIT
    CMP AL, 10
    JE  RST_WAIT

    CMP AL, 'Y'
    JE  RST_GO
    CMP AL, 'y'
    JE  RST_GO
    JMP MLOOP

RST_GO:
    ; zero all 384 bytes of s_data
    LEA BX, s_data
    MOV CX, 384

RST_LOOP:
    MOV BYTE PTR [BX], 0
    INC BX
    LOOP RST_LOOP

    ; zero s_count
    MOV s_count, 0

    ; zero t_hours
    MOV WORD PTR t_hours, 0

    LEA DX, m_rst
    CALL PSTR
    JMP MLOOP

; ============================================================
DO_EXIT:
    MOV  AH, 4CH
    INT  21H

MAIN ENDP

; ============================================================
;  FSUB - find subject by f_buf in s_data
;  Returns: SI=entry base, CL=index, CF=0 found / CF=1 not found
; ============================================================
FSUB PROC
    MOV  CL, 0
    MOV  SI, 0
FSUB_LP:
    CMP  CL, s_count
    JAE  FSUB_FAIL
    LEA  BX, f_buf
    MOV  DL, [BX+1]
    MOV  DH, 0
    ADD  BX, 2
    MOV  DI, SI
    ADD  DI, 3
FSUB_CMP:
    MOV  AL, [BX]
    MOV  AH, s_data[DI]
    CMP  AL, AH
    JNE  FSUB_NEXT
    CMP  AL, 0
    JE   FSUB_HIT
    INC  BX
    INC  DI
    DEC  DX
    JNZ  FSUB_CMP
    CMP  s_data[DI], 0
    JE   FSUB_HIT
FSUB_NEXT:
    ADD  SI, 32
    INC  CL
    JMP  FSUB_LP
FSUB_HIT:
    CLC
    RET
FSUB_FAIL:
    STC
    RET
FSUB ENDP

; ============================================================
;  SCMP - compare s_data[SI] vs s_data[DI], CF=1 if SI > DI
; ============================================================
SCMP PROC
SCMP_LP:
    MOV  AL, s_data[SI]
    MOV  AH, s_data[DI]
    CMP  AL, AH
    JA   SCMP_GT
    JB   SCMP_LT
    CMP  AL, 0
    JE   SCMP_LT
    INC  SI
    INC  DI
    JMP  SCMP_LP
SCMP_GT:
    STC
    RET
SCMP_LT:
    CLC
    RET
SCMP ENDP

; ============================================================
;  UC_NAME - uppercase n_buf
; ============================================================
UC_NAME PROC
    LEA  BX, n_buf
    MOV  CL, [BX+1]
    MOV  CH, 0
    ADD  BX, 2
UCN_LP:
    JCXZ UCN_END
    MOV  AL, [BX]
    CALL TOUPP
    MOV  [BX], AL
    INC  BX
    DEC  CX
    JMP  UCN_LP
UCN_END:
    RET
UC_NAME ENDP

; ============================================================
;  UC_FIND - uppercase f_buf
; ============================================================
UC_FIND PROC
    LEA  BX, f_buf
    MOV  CL, [BX+1]
    MOV  CH, 0
    ADD  BX, 2
UCF_LP:
    JCXZ UCF_END
    MOV  AL, [BX]
    CALL TOUPP
    MOV  [BX], AL
    INC  BX
    DEC  CX
    JMP  UCF_LP
UCF_END:
    RET
UC_FIND ENDP

; ============================================================
;  TOUPP - AL lowercase -> uppercase
; ============================================================
TOUPP PROC
    CMP  AL, 'a'
    JB   TOUPP_END
    CMP  AL, 'z'
    JA   TOUPP_END
    SUB  AL, 20H
TOUPP_END:
    RET
TOUPP ENDP

; ============================================================
;  RD2 - read 1 or 2 digit number -> AL
; ============================================================
RD2 PROC
    CALL RCHAR
    SUB  AL, '0'
    MOV  BH, AL
    CALL RCHAR
    CMP  AL, 13
    JE   RD2_ONE
    CMP  AL, ' '
    JE   RD2_ONE
    SUB  AL, '0'
    MOV  BL, AL
    MOV  AL, BH
    MOV  AH, 10
    MUL  AH
    ADD  AL, BL
    RET
RD2_ONE:
    MOV  AL, BH
    RET
RD2 ENDP

; ============================================================
;  PB2 - print AL as 2-digit zero-padded decimal
; ============================================================
PB2 PROC
    MOV  AH, 0
    MOV  BL, 10
    DIV  BL
    PUSH AX
    ADD  AL, '0'
    MOV  DL, AL
    MOV  AH, 02H
    INT  21H
    POP  AX
    ADD  AH, '0'
    MOV  DL, AH
    MOV  AH, 02H
    INT  21H
    RET
PB2 ENDP

; ============================================================
;  PNUM - print word AX as decimal (BH=0 on entry)
; ============================================================
PNUM PROC
    MOV  pn_val, AX
    MOV  AX, pn_val
    MOV  BX, 10000
    MOV  DX, 0
    DIV  BX
    MOV  pn_val, DX
    CALL PNDIG
    MOV  AX, pn_val
    MOV  BX, 1000
    MOV  DX, 0
    DIV  BX
    MOV  pn_val, DX
    CALL PNDIG
    MOV  AX, pn_val
    MOV  BX, 100
    MOV  DX, 0
    DIV  BX
    MOV  pn_val, DX
    CALL PNDIG
    MOV  AX, pn_val
    MOV  BX, 10
    MOV  DX, 0
    DIV  BX
    MOV  pn_val, DX
    CALL PNDIG
    MOV  AX, pn_val
    ADD  AL, '0'
    MOV  DL, AL
    MOV  AH, 02H
    INT  21H
    RET
PNUM ENDP

PNDIG PROC
    CMP  AL, 0
    JNE  PNDIG_PR
    CMP  BH, 0
    JE   PNDIG_SK
PNDIG_PR:
    MOV  BH, 1
    ADD  AL, '0'
    MOV  DL, AL
    MOV  AH, 02H
    INT  21H
PNDIG_SK:
    RET
PNDIG ENDP

; ============================================================
;  PSTR - print '$'-terminated string DS:DX
; ============================================================
PSTR PROC
    MOV  AH, 09H
    INT  21H
    RET
PSTR ENDP

; ============================================================
;  RCHAR - read one char, echo, return in AL
; ============================================================
RCHAR PROC
    MOV  AH, 01H
    INT  21H
    RET
RCHAR ENDP

END MAIN