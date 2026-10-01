# Edit these instructions, then run:
# python scripts/test.py programs/my_program.S
    addi x1,x0,10
    addi x2,x0,20
    add x3,x1,x2
    sw x3,0(x0)
    lw x4,0(x0)
    addi x5,x4,1
halt:
    j halt
# Change the expectations yourself when changing the program.
# expect x3 = 30
# expect x4 = 30
# expect x5 = 31
# expect mem[0] = 30
