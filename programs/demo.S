# On-board self-check, then show a six-bit binary counter.
# LED register: 0x10000000, bit 1 means illuminated.
    lui x20, 0x10000
    addi x1, x0, 7
    addi x2, x0, 5
    add x3, x1, x2       # M->EX and W->EX forwarding, result 12
    sw x3, 0(x0)        # forward store data
    lw x4, 0(x0)
    add x5, x4, x3       # load-use stall, result 24
    addi x6, x0, 24
    bne x5, x6, fail
    beq x5, x6, passed   # taken branch flushes both wrong-path instructions
    sw x0, 0(x20)
    j fail
passed:
    addi x7, x0, 1
show:
    sw x7, 0(x20)
    lui x8, 0x100        # delay: 1,048,576 iterations, approx 0.155 s @27MHz
delay:
    addi x8, x8, -1
    bne x8, x0, delay
    addi x7, x7, 1
    j show
fail:
    addi x7, x0, 63
    sw x7, 0(x20)
    j fail
