; Snake86
; @Author: iu_oi

; This program should run on 16bit DOS with intel 8086.
; @Volatile ax, cx, dx
; @Non-volatile bx, di, si
; @Return ax
; @Stack callee

ASSUME CS:CODE,DS:DATA,SS:STACK
DATA SEGMENT
    ; 320*200 = (80*4)*(50*4)
    ; We use an array of 'direction' to represent the snake.
    direction db 1
    head dw 81
    tail dw 81
    bodyLength dw 1
    sandbox db 80 dup(WALL)
    db 48 dup(WALL,78 dup(0),WALL)
    db 80 dup(WALL)
    lastKey db 'd'
    seed dw 0

    BLACK equ 0
    WHITE equ 15
    GREEN equ 2
    RED equ 4
    FOOD equ 0bh
    WALL equ 0ah
    TRACE equ 0ch ; trace of the tail
    UP equ 0b0h
    DOWN equ 50h
    LEFT equ 0ffh
    RIGHT equ 1h
DATA ENDS
STACK SEGMENT STACK
    db 256 dup(0)
STACK ENDS
CODE SEGMENT
; @dh: row(0~49) @dl: column(0~79) @cl: color
DrawBlock: ; 4*4
    push bx
    push di
    push si
    xor ax,ax
    mov al,dh
    shl ax,1
    shl ax,1
    xor bx,bx
    mov bl,dl
    shl bx,1
    shl bx,1
    xor dx,dx
    mov dl,20 ; segments per line(20=320/16)
    mul dl
    add ax,0a000h
    mov es,ax
    xor si,si
    _DrawBlock1:
        xor di,di
        _DrawBlock2:
            mov es:[bx+di],cl ; row first
            inc di
            cmp di,4
            jb _DrawBlock2
        add ax,20
        mov es,ax
        inc si
        cmp si,4
        jb _DrawBlock1
    pop si
    pop di
    pop bx
    ret
DrawFrame: ; 80*50
    push bx
    push si
    push di
    ; @si: row @di: column
    xor si,si
    _DrawFrame1:
        xor di,di
        _DrawFrame2:
            mov ax,80
            mul si
            mov bx,di
            add bx,ax
            mov cl,ds:sandbox[bx]
            test cl,cl
            jz _DrawNothing
            cmp cl,0bh
            jz _DrawRed
            cmp cl,0ah
            jz _DrawWhite
            cmp cl,0ch
            jz _DrawBlank
            jmp _DrawGreen
            _DrawWhite:
                mov cl,15
                jmp _DrawFrame3
            _DrawGreen:
                mov cl,2
                jmp _DrawFrame3
            _DrawRed:
                mov cl,4
                jmp _DrawFrame3
            _DrawBlank:
                xor cl,cl
                mov ds:sandbox[bx],cl
            _DrawFrame3:
                mov dx,si
                shl dx,1
                shl dx,1
                shl dx,1
                shl dx,1
                shl dx,1
                shl dx,1
                shl dx,1
                shl dx,1
                add dx,di
                call DrawBlock
            _DrawNothing:
            inc di
            cmp di,80
            jb _DrawFrame2
        inc si
        cmp si,50
        jb _DrawFrame1
    pop di
    pop si
    pop bx
    ret
Delay:
    push si
    ; @si: master counter @ax: slave counter
    xor si,si
    inc si
    xor ax,ax
    _Delay1:
        sub ax,1
        sbb si,0
        test ax,ax
        jnz _Delay1
        test si,si
        jnz _Delay1
    pop si
    ret
GetKey:
    mov ah,1
    int 16h ; quit if empty
    jz _GetKeyRet
    mov ds:lastKey,al
    xor ah,ah
    int 16h ; discard verbose keys
    jmp GetKey
    _GetKeyRet:
        ret
; @al: key
SetDirection:
    push bx
    mov bx,ds:head ; @bx: head
    xor dx,dx
    mov dl,ds:direction ; @dl: previous direction
    cmp al,'w'
    jz W
    cmp al,'a'
    jz A
    cmp al,'s'
    jz S
    cmp al,'d'
    jz D
    jmp _SetDirectionRet ; ignore if direction contradicts
    W:
        mov ax,0b0h
        add dl,al
        jz _SetDirectionRet
        mov ds:direction,al
        mov ds:sandbox[bx],al
        jmp _SetDirectionRet
    A:
        mov ax,0ffh
        add dl,al
        jz _SetDirectionRet
        mov ds:direction,al
        mov ds:sandbox[bx],al
        jmp _SetDirectionRet
    S:
        mov ax,50h
        add dl,al
        jz _SetDirectionRet
        mov ds:direction,al
        mov ds:sandbox[bx],al
        jmp _SetDirectionRet
    D:
        mov ax,1
        add dl,al
        jz _SetDirectionRet
        mov ds:direction,al
        mov ds:sandbox[bx],al
    _SetDirectionRet:
        pop bx
        ret
sRand:
    mov ah,2
    int 1ah ; current time
    add dx,cx
    mov ds:seed,dx
    ret
; @cx: n, multiplier: 13, increment: 1313, module number: n, maxsize: n-1
Rand:
    mov ax,ds:seed
    mov dx,13
    mul dx
    add ax,1313
    adc dx,0
    div cx
    mov ax,dx
    mov ds:seed,ax
    ret
GenFood:
    push bx
    push si
    call sRand
    mov cx,78*48
    mov ax,ds:bodyLength
    sub cx,ax
    call Rand
    ; @cx: counter @si: food index @bx: block index
    xor cx,cx
    mov si,ax
    mov bx,81
    _GenFood1:
        xor ax,ax
        mov al,ds:sandbox[bx]
        test ax,ax
        jnz _GenFood3 ; skip if it's not idle
        cmp cx,si
        jnz _GenFood2 ; idle, but not the block we want
        mov ax,bx
        jmp _GenFoodRet
        _GenFood2:
        inc cx
        _GenFood3:
        inc bx
        cmp bx,49*80
        jb _GenFood1
    _GenFoodRet:
    pop si
    pop bx
    ret
Detect:
    push bx
    mov al,ds:direction
    cbw
    mov bx,ds:head
    add bx,ax
    mov al,ds:sandbox[bx]
    pop bx
    ret
EatFood:
    push bx
    mov al,ds:direction
    cbw
    mov bx,ds:head
    add bx,ax
    mov ds:head,bx
    mov ds:sandbox[bx],al
    mov ax,ds:bodyLength
    inc ax
    mov ds:bodyLength,ax
    call GenFood
    mov bx,ax
    mov ax,0bh
    mov ds:sandbox[bx],al
    pop bx
    ret
MoveBody:
    push bx
    mov al,ds:direction
    cbw
    mov bx,ds:head
    add bx,ax
    mov ds:head,bx
    mov ds:sandbox[bx],al
    mov bx,ds:tail
    mov al,ds:sandbox[bx]
    cbw
    mov dx,bx
    add bx,ax
    mov ds:tail,bx
    mov bx,dx
    mov dx,0ch
    mov ds:sandbox[bx],dl
    pop bx
    ret

start:
    mov ax,data
    mov ds,ax
    mov ax,stack
    mov ss,ax
    mov sp,256
    mov ax,13h
    int 10h ; enable graphic mode
    mov bx,ds:head
    xor ax,ax
    mov al,ds:direction
    mov ds:sandbox[bx],al
    call GenFood
    mov bx,ax
    mov ax,0bh
    mov ds:sandbox[bx],al
    mainloop:
        call DrawFrame
        call Delay
        call GetKey
        mov al,ds:lastKey
        cmp al,'q'
        jz exit
        call SetDirection
        call Detect
        test al,al
        jz mainloop1
        cmp al,0bh
        jz mainloop2
        jmp exit
        mainloop1:
            call MoveBody
            jmp mainloop
        mainloop2:
            call EatFood
            jmp mainloop
    exit:
        xor ax,ax
        int 16h
        mov ax,03h
        int 10h ; exit the graphic mode
        mov ax,4c00h
        int 21h ; program exit
CODE ENDS
END start