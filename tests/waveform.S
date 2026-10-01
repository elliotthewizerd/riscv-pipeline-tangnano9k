# Fixed waveform exercise. Expected values are chosen before simulation.
# See waveform.expected.csv for the hand-derived cycle schedule.
    addi x1,x0,5
    addi x2,x0,7
    add x3,x1,x2
    sw x3,0(x0)
    lw x4,0(x0)
    add x5,x4,x1
    beq x5,x0,bad
    beq x5,x5,taken
    sw x0,0(x0)       # wrong path: must not overwrite 12
    addi x6,x0,99     # wrong path: must not retire
taken:
    addi x6,x0,42
    j done
bad:
    addi x6,x0,-1     # wrong path: must not retire
    sw x0,0(x0)       # wrong path: must not write
done:
    sw x6,4(x0)
halt:
    j halt
# expect x0 = 0
# expect x1 = 5
# expect x2 = 7
# expect x3 = 12
# expect x4 = 12
# expect x5 = 17
# expect x6 = 42
# expect mem[0] = 12
# expect mem[4] = 42
