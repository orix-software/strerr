;----------------------------------------------------------------------
;			includes cc65
;----------------------------------------------------------------------
.feature string_escapes

.include "telestrat.inc"
.include "errno.inc"

XMAINARGS = $2C
XGETARGV = $2E

;----------------------------------------------------------------------
;			includes SDK
;----------------------------------------------------------------------
.include "SDK.mac"
.include "types.mac"
.include "case.mac"

;----------------------------------------------------------------------
;			include application
;----------------------------------------------------------------------

;----------------------------------------------------------------------
;				imports
;----------------------------------------------------------------------
.import spar1
	spar := spar1
.import sopt1
	sopt := sopt1
.import StopOrCont

;----------------------------------------------------------------------
;				exports
;----------------------------------------------------------------------
.export _main

;----------------------------------------------------------------------
;				Segments vides
;----------------------------------------------------------------------
.segment "STARTUP"
.segment "INIT"
.segment "ONCE"

;----------------------------------------------------------------------
;				Page zéro
;----------------------------------------------------------------------
.pushseg
	.segment "ZEROPAGE"
		unsigned char errno
		unsigned char err_max

		unsigned char save_defaff
.popseg

;----------------------------------------------------------------------
;				Variables
;----------------------------------------------------------------------
.pushseg
	.segment "DATA"
		unsigned short _argv
		unsigned char  _argc

		unsigned char exit_code
		unsigned char opts
.popseg

;----------------------------------------------------------------------
;			Defines / Constantes
;----------------------------------------------------------------------
VERSION = $20224010
.define PROGNAME "strerr"

;----------------------------------------------------------------------
;			Chaînes statiques
;----------------------------------------------------------------------
.pushseg
	.segment "RODATA"
		version:
			.asciiz .sprintf("%s version %x.%x - %x.%x\r\n", PROGNAME, (::VERSION & $ff0)>>4, (::VERSION & $0f), ::VERSION >> 16, (::VERSION & $f000)>>12)
			.out   .sprintf("%s version %x.%x - %x.%x", PROGNAME, (::VERSION & $ff0)>>4, (::VERSION & $0f), ::VERSION >> 16, (::VERSION & $f000)>>12)
;			.asciiz .sprintf("%s version: %x.%x.%x", PROGNAME, SDK_VERSION >> 8, (SDK_VERSION & $ff)>>4 , (SDK_VERSION & $0f))


        helpmsg:
            .byte $0a, $0d
            .byte $1b,"C         strerr utility\r\n\n"
            .byte " \x1bTSyntax:\x1bP\r\n"
            .byte "   strerr\x1bA-h|-v|-a\x1bG\r\n"
            .byte "   strerr\x1bB[-q] start[,end]\r\n"
            .byte "   strerr\x1bB[-a[q]] [start]\r\n"
            .byte "\r\n"
            .byte $00

        longhelp_msg:
            .byte "\r\n"
            .byte " \x1bTOptions:\x1bP\r\n"
            .byte "  \x1bA-h   \x1bGdisplay command syntax\r\n"
            .byte "  \x1bA-v   \x1bGdisplay program version\r\n"
            .byte "  \x1bB-a   \x1bGdisplay all messages from\x1bBstart\r\n"
            .byte "  \x1bB-q   \x1bGquiet mode\r\n"
            .byte "  \x1bBstart\x1bGmessage number (def: 0)\r\n"
            .byte "  \x1bBend  \x1bGlast message number (def: 0)\r\n"
            .byte "\r\n"
            .byte " \x1bTExamples:\x1bP\r\n"
            .byte "   strerr 1 \r\n"
            .byte "   strerr 1,4\r\n"
            .byte "   strerr ,18\r\n"
            .byte "   strerr -a 3\r\n"
            .byte "\r\n"
            .byte $00
.popseg

;----------------------------------------------------------------------
;			Programme principal
;----------------------------------------------------------------------
.segment "CODE"

;----------------------------------------------------------------------
;
; Entrée:
;	A: errno
; Sortie:
;
; Variables:
;	Modifiées:
;		-
;	Utilisées:
;		-
; Sous-routines:
;	- prints
;----------------------------------------------------------------------
.proc _main
		lda	#00
		sta	errno
		lda	#EMAX
		sta	err_max

		lda	#EOK
		sta	exit_code

		ldy     #<(BUFEDT+.strlen(PROGNAME))
		lda     #>(BUFEDT+.strlen(PROGNAME))
		jsr	sopt
		.asciiz	"QAHV"
		bcs	err_param
		stx	opts

	get_errval:
		ldx	#%10100000
		jsr	spar
		.byte	errno, err_max, $00
		bcs	error

		; -H
		lda	opts
		and	#%00100000
		bne	help

		; -V
		and	#%00010000
		bne	version

		; -A
		bit	opts
		bvc	set_limits

		lda	#EMAX
		sta	err_max
		bne	loop

	set_limits:
		; Pas de limites?
		cpx	#$00
		beq	version

		; Limite supérieure uniquement ou 2 limites?
		cpx	#$80
		bne	cmnd_err

		; Limite inférieure uniquement
		lda	errno
		sta	err_max

	cmnd_err:
		lda	#EMAX
		cmp	err_max
		bcs	loop
		sta	err_max

	loop:
		jsr	StopOrCont
		bcs	end
		lda	errno
		jsr	strerror
		inc	errno
		beq	end
		lda	errno
		cmp	err_max
		bcc	loop
		beq	loop

	end:
		crlf
		lda	exit_code
		ldx	#$00
		rts

	error:
		bit	opts
		bmi	error_exit
		prints	"Invalid error code"
		crlf

	error_exit:
		lda	#ERANGE
		ldx	#$00
		rts

	err_param:
		bit	opts
		bmi	err_param_exit
		prints	"Invalid parameter"
		crlf

	err_param_exit:
		lda	#EINVAL
		ldx	#$00
		rts

	help:
		jmp	cmnd_help

	version:
		jmp	cmnd_version
.endproc

;----------------------------------------------------------------------
;
; Entrée:
;	A: errno
; Sortie:
;
; Variables:
;	Modifiées:
;		-
;	Utilisées:
;		-
; Sous-routines:
;	- prints
;----------------------------------------------------------------------
.proc strerror
		sta	errno

		bit	opts
		bmi	print_errstr

		lda	DEFAFF
		sta	save_defaff
		lda	#' '
		sta	DEFAFF

		lda	errno
		ldy	#$00
		ldx	#$01
		.byte	$00, XDECIM

		prints	": "

	print_errstr:
		do_case	errno
			case_of EOK		; No error
				prints	"No error"

			case_of ENOENT
				prints	"No such file or directory"

			case_of ENOMEM
				prints	"Out of memory"

			case_of EACCES
				prints	"Permission denied"

			case_of ENODEV
				prints	"No such device"

			case_of EMFILE
				prints	"Too many open files"

			case_of EBUSY
				prints	"Device or resource busy"

			case_of EINVAL
				prints	"Invalid argument"

			case_of ENOSPC
				prints	"No space left on device"

			case_of EEXIST
				prints	"File exists"

			case_of EAGAIN
				prints	"Try again"

			case_of EIO
				prints	"I/O error"

			case_of EINTR
				prints	"Interrupted system call"

			case_of ENOSYS
				prints	"Function not implemented"

			case_of ESPIPE
				prints	"Illegal seek"

			case_of ERANGE
				prints	"Range error"

			case_of EBADF
				prints	"Bad file number"

			case_of ENOEXEC
				prints	"Exec format error"

			case_of EUNKNOWN
				; Unknown OS specific error - must be last!
				prints	"Unknown OS specific error"
			otherwise
				prints	"???"
				lda	#ERANGE
				sta	exit_code
		end_case

		lda	save_defaff
		sta	DEFAFF

		crlf
		rts
.endproc

;----------------------------------------------------------------------
;
; Entrée:
;	-
; Sortie:
;	A: EOK
;	X: $00
;
; Variables:
;	Modifiées:
;		-
;	Utilisées:
;		-
; Sous-routines:
;	- print
;----------------------------------------------------------------------
.proc cmnd_version
		print	version
		crlf

		lda	#EOK
		ldx	#$00

		rts
.endproc

;----------------------------------------------------------------------
;
; Entrée:
;	-
; Sortie:
;	-
;
; Variables:
;	Modifiées:
;		-
;	Utilisées:
;		-
; Sous-routines:
;	- print
;----------------------------------------------------------------------
.proc cmnd_help
		print	helpmsg

		lda	#EOK
		ldx	#$00
		rts
.endproc

;----------------------------------------------------------------------
;
; Entrée:
;	-
; Sortie:
;	-
;
; Variables:
;	Modifiées:
;		-
;	Utilisées:
;		-
; Sous-routines:
;	- print
;----------------------------------------------------------------------
.proc cmnd_longhelp
		jsr	cmnd_help
		print	longhelp_msg

		lda	#EOK
		ldx	#$00
		rts
.endproc

