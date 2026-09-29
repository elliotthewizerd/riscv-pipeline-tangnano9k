    addi x1,x0,7
    addi x2,x0,5
    add x3,x1,x2
    addi x3,x3,1
    add x4,x3,x3
    sw x4,0(x0)
    lw x5,0(x0)
    add x6,x5,x4
    sw x6,4(x0)
    lw x7,4(x0)
    sw x7,8(x0)
    lw x8,8(x0)
    beq x8,x6,equal
    sw x0,0(x0)
    addi x30,x0,99
equal:
    lw x9,0(x0)
    addi x10,x0,9       # immediate low bits look like rs2=x9: no false stall
    lw x0,0(x0)        # x0 is never a dependency
    add x11,x0,x0
    addi x12,x0,1
    addi x13,x0,2
    addi x14,x0,3
    add x15,x12,x0     # WB -> ID bypass
    jal x16,func
    sw x0,0(x0)
    addi x30,x0,88
func:
    add x17,x16,x0
    addi x18,x0,target
    jalr x19,0(x18)    # M -> EX target forwarding
    sw x0,4(x0)
    addi x30,x0,77
target:
    add x20,x19,x0
    addi x21,x0,-7
    addi x22,x0,3
    blt x21,x22,signed_ok
    sw x0,8(x0)
    j bad
signed_ok:
    bge x22,x21,unsigned_test
    j bad
    j bad
unsigned_test:
    bltu x22,x21,unsigned_ok
    j bad
    j bad
unsigned_ok:
    bgeu x21,x22,loop_setup
    j bad
    j bad
loop_setup:
    addi x23,x0,3
loop:
    addi x23,x23,-1
    bne x23,x0,loop
    sub x24,x22,x21
    sll x25,x22,x22
    srl x26,x21,x22
    sra x27,x21,x22
    slt x28,x21,x22
    sltu x29,x21,x22
    xor x24,x21,x22
    or x25,x21,x22
    and x26,x21,x22
    slli x27,x22,31
    srli x28,x21,31
    srai x29,x21,31
    slti x24,x21,-1
    sltiu x25,x21,-1
    xori x26,x21,-1
    ori x27,x22,16
    andi x28,x21,31
    lui x29,0xabcde
    auipc x30,1
    addi x18,x0,load_target
    sw x18,12(x0)
    lw x18,12(x0)
    jalr x0,0(x18)     # load -> jalr, one stall
    sw x0,0(x0)
    j bad
load_target:
    addi x18,x0,16
    sw x18,16(x0)
    lw x18,16(x0)
    lw x19,0(x18)      # load -> load address, one stall
    addi x18,x0,24
    sw x18,20(x0)
    lw x18,20(x0)
    sw x19,0(x18)      # load -> store address, one stall
    beq x1,x2,bad      # not taken
    bne x1,x1,bad      # not taken
    blt x2,x1,branch_ok
    j bad
branch_ok:
    bge x2,x1,bad
    bltu x1,x2,bad
    bgeu x2,x1,bad
    addi x0,x0,123
    .word 0xffffffff  # unsupported opcode, no side effects
    .word 0x020000b3  # mul encoding, unsupported, no write
    j halt
bad:
    addi x31,x0,-1
halt:
    j halt
