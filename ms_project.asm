; Project #4
; author name: Martin Kotevski ; index: 151132
; author name: Tea Zdravkovska ; index: 151166
data segment
    command dw 50 dup(3)
    messages dw 240 dup(2)
    codes dw 'A','B','C','D','E ','F','G','H','I','J'
    msg dw 4 dup(3)
    POS dw ?
    tmp1 dw ?
    tmp2 dw ?
    no_msg db "Nema poraka$"
    enter_cmd db "Vnesi komanda:$"  
ends

stack segment
    dw   128  dup(0)
ends

code segment 
    
; prints the n-th message encrypted,
; where n is placed in the variable POS
read_msg proc
    call println 
    mov ax, POS
    mov bl, 8
    mul bl
    lea si, messages
    add si, ax   ; si = messages + 8 * n (each msg is 4 words long)
    mov cx, 4d ; string length
    next_char:
    mov bx, [si]
    cmp bx, 2 ; 2 is default value so it means there is no msg
    je print_no_msg
    push bx
    call is_letter
    cmp bx, 1 
    je prepare_print_letter
    mov bx, [si]
    sub bx, 30h 
    add bx, bx
    mov dx, codes[bx] 
    mov dh, 0
    ;mov [si], dx   
    jmp print
    prepare_print_letter:
    mov dx, [si]
    print:   
    mov ah, 2
    int 21h
    inc si 
    inc si
    loop next_char
    ret
    print_no_msg:
    lea dx, no_msg
    mov ah, 9
    int 21h
    ret
endp
     
; prints new line
println proc
    mov dl, 10
    mov ah, 2
    int 21h
    mov dl, 13
    mov ah, 2
    int 21h 
    ret
endp 
  
; checks if the argument passed with the stack is letter
is_letter proc
    pop dx ; address for the next instruction after the procedure call
    pop bx
    cmp bx, 41h
    jb is_not_letter
    cmp bx, 5Ah
    ja is_not_letter
    ; the character is letter
    mov bx, 1
    jmp return1 
    is_not_letter:
    mov bx, 0
    return1:   
    push dx ; put the addres for the next instruction back on the stack   
    ret
endp 
     
; checks if the argument passed with the stack is digit
is_digit proc
    pop dx ; address for the next instruction after the procedure call
    pop bx
    cmp bx, 30h
    jb is_not_digit
    cmp bx, 39h
    ja is_not_digit
    ; the character is digit
    mov bx, 1
    jmp return2 
    is_not_digit:
    mov bx, 0
    return2:   
    push dx ; put the addres for the next instruction back on the stack   
    ret
endp

; maps the given digit passed with the stack to the given letter also passed with the stack
update_F proc
    pop dx
    pop cx ; letter
    pop bx ; digit
    sub bx, 30h
    add bx, bx 
    mov codes[bx], cx 
    push dx
    ret       
endp  

; writes the message whose reference is is register SI,
; on position specified by the variable POS 
write_msg proc
   lea di, messages
   mov ax, POS
   mov bl, 8
   mul bl   
   add di, ax
   mov cx, 4d
   rep movsw 
   ret
endp 

; reads command from standard input and
; - puts it's reference in register DI  
; - puts it's length in register CX
read_command proc
    lea di, command
    mov cx, 0       
    read_char:
    mov ah, 1
    int 21h
    cmp al, 2Eh 
    je end_read_char
    mov ah, 0
    stosw
    add cx, 1
    jmp read_char
    end_read_char:
    stosw
    add cx, 1 
    lea di, command
    ret
endp

; clears (sets to default) the memory reserved
; for the command that is read from std input,
; so there are no collisions between previous commands.
clear_prev_cmd proc
    mov ax, cx
    mov bx, 2
    mul bx
    mov cx, 100
    sub cx, ax
    lea si, command
    add si, ax
    clear_command: 
    mov [si], 3 
    inc si
    loop clear_command:    
endp
  
; executes one command: finds the hidden instructions
; in it and executes them sepparately  
execute_command proc
    proccess_forward:
    cmp [di], 2Eh ; is it '.' ?
    je ex
    mov bx, di        
    cmp [di], 3Eh, ; is it '>' ?
    jne check_update_cmd 
    jmp check_write_cmd
    check_update_cmd:
    cmp [di], 2Dh ; is it '-' ?
    jne next
    add di, 2
    mov dx, [di]
    push dx
    call is_digit
    cmp bx, 0 
    je next
    ; the right char is digit, check if the left is letter
    sub di, 4
    mov dx, [di]
    push dx
    call is_letter
    cmp bx, 0
    je next
    ; the instruction is update
    add di, 4
    mov dx, [di]
    push dx
    sub di, 4
    mov dx, [di]
    push dx
    call update_F 
    inc di
    inc di
    jmp next
    check_write_cmd:
    add bx, 12
    cmp [bx], 2Bh ; is it '+' ?
    jne check_next_plus
    ; get the message 
    inc di
    inc di  
    mov tmp1, di
    lea si, msg
    mov di, si
    mov si, tmp1
    mov cx, 4
    rep movsw
    mov di, si                    
    lea si, msg
    mov ax, [di]
    sub ax, 48d
    mov POS, ax
    mov tmp1, di
    mov tmp2, bx 
    call write_msg
    mov di, tmp1
    mov bx, tmp2
    mov di, bx ; move di after instruction 
    jmp next                   
    check_next_plus:
    add bx, 2
    cmp [bx], 2Bh ; is it '+' ?
    jne check_read_cmd ; chech if it is read instruction                 
    ; get the message
    inc di
    inc di 
    mov tmp1, di
    lea si, msg
    mov di, si
    mov si, tmp1
    mov cx, 4
    rep movsw                    
    mov di, si                    
    lea si, msg
    mov ax, [di]
    sub ax, 48d
    inc di
    inc di
    mov dx, [di]
    sub dx, 48d
    mov dh, 10
    mul dh
    mov dh, 0
    add ax, dx
    mov POS, ax
    mov tmp1, di
    mov tmp2, bx
    call write_msg
    mov di, tmp1
    mov bx, tmp2
    mov di, bx ; set di after instruction 
    jmp next
    check_read_cmd:
    mov bx, di ; bx is at '>'
    add bx, 4  ; increment bx twice (word)
    cmp [bx], 2Dh  ; is it '-'
    jne check_next_minus
    inc di
    inc di
    mov ax, [di]
    sub ax, 48d
    mov POS, ax
    mov tmp1, bx ; save the value of bx
    call read_msg
    mov bx, tmp1
    mov di, bx ; move di after instruction
    jmp next
    check_next_minus:
    add bx, 2
    cmp [bx], 2Dh  ; is it '-'
    jne next
    inc di
    inc di
    mov ax, [di]
    push ax
    mov tmp1, bx ; save the value of bx
    call is_digit 
    cmp bx, 0
    je next
    mov bx, tmp1 
    sub ax, 48d
    inc di
    inc di
    mov dx, [di]
    sub dx, 48d
    mov dh, 10
    mul dh
    mov dh, 0
    add ax, dx
    mov POS, ax
    mov tmp1, bx ; save the value of bx
    call read_msg
    mov bx, tmp1                   
    mov di, bx ; move di after instruction                 
    next:
    inc di
    inc di
    jmp proccess_forward 
    ex:
    ret    
endp
    
    
start:
; set segment registers:
    mov ax, data
    mov ds, ax
    mov es, ax   
    
    ; Infinite loop that reads the instructions
    infinite:
    lea dx, enter_cmd
    mov ah, 9
    int 21h
    call println
    call read_command
    call clear_prev_cmd
    ; now the command's base address is in DI 
    call execute_command
    call println
    mov bx, 1
    cmp bx, 1
    je infinite

    mov ax, 4c00h ; exit to operating system.
    int 21h    
ends

end start ; set entry point and stop the assembler.