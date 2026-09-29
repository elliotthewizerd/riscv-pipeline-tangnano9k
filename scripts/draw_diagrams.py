"""Deterministic, editable SVG engineering drawings. Coordinates are laid out by hand."""
from pathlib import Path
from html import escape

OUT=Path(__file__).resolve().parents[1]/'docs'/'diagrams'
INK='#20252b'; BLUE='#245c89'; GREEN='#126b45'; GRAY='#c4c9ce'

class Drawing:
    def __init__(self,w,h,title,subtitle,active=None):
        self.w,self.h,self.active=w,h,active
        self.parts=[f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}"><title>{escape(title)}</title>',
          '<defs>'+''.join(f'<marker id="{n}" markerWidth="7" markerHeight="7" refX="6" refY="3.5" orient="auto"><path d="M0,0 L7,3.5 L0,7" fill="{c}"/></marker>' for n,c in [('ink',INK),('ctrl',BLUE),('active',GREEN),('muted',GRAY)])+'</defs>',
          '<rect width="100%" height="100%" fill="white"/>',
          '<style>text{font-family:Arial,Helvetica,sans-serif;font-size:15px} .sig{font-family:Consolas,monospace;font-size:13px} .small{font-size:12px} .title{font-size:27px;font-weight:bold} .stage{font-size:18px;font-weight:bold} path,rect,line,polygon{vector-effect:non-scaling-stroke}</style>']
        self.text(32,40,title,'title')
        self.text(32,68,subtitle,'',INK)
    def color(self,key,ctrl=False):
        if self.active is None: return BLUE if ctrl else INK
        return GREEN if key in self.active else GRAY
    def text(self,x,y,s,cls='sig',color=INK,anchor='start'):
        self.parts.append(f'<text x="{x}" y="{y}" class="{cls}" fill="{color}" text-anchor="{anchor}">{escape(s)}</text>')
    def wire(self,key,points,label='',at=None,ctrl=False,arrow=True):
        c=self.color(key,ctrl)
        marker={INK:'ink',BLUE:'ctrl',GREEN:'active',GRAY:'muted'}[c]
        d='M'+' L'.join(f'{x},{y}' for x,y in points)
        width=2.6 if c==GREEN else 1.3
        self.parts.append(f'<path d="{d}" fill="none" stroke="{c}" stroke-width="{width}"'+(f' marker-end="url(#{marker})"' if arrow else '')+'/>')
        if label:
            x,y=at or points[0]
            self.text(x,y-7,label,color=c)
    def box(self,key,x,y,w,h,name,ports=(),ctrl=False):
        c=self.color(key,ctrl)
        self.parts.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="white" stroke="{c}" stroke-width="1.5"/>')
        self.text(x+w/2,y+h/2+5,name,'',c,'middle')
        for px,py,label in ports: self.text(x+px,y+py,label,color=c)
    def mux(self,key,x,y,h=60,label='',three=False):
        c=self.color(key)
        self.parts.append(f'<polygon points="{x},{y} {x+25},{y+12} {x+25},{y+h-12} {x},{y+h}" fill="white" stroke="{c}" stroke-width="1.5"/>')
        if three:
            for dy,s in [(20,'00'),(h/2+5,'01'),(h-9,'10')]:self.text(x+2,y+dy,s,'small',c)
        else:
            if three:
            for dy,s in [(20,'00'),(h/2+5,'01'),(h-9,'10')]: self.text(x+2,y+dy,s,'small',c)
        else:
            self.text(x+5,y+20,'0','small',c); self.text(x+5,y+h-9,'1','small',c)
        if label:self.text(x+12,y+h+17,label,'sig',c,'middle')
    def dot(self,key,x,y):
        self.parts.append(f'<circle cx="{x}" cy="{y}" r="3" fill="{self.color(key)}"/>')
    def save(self,name):
        self.text(32,self.h-20,'RV32 / 5-stage pipeline     |     Signal names follow rtl/     |     '+name,'small','#58616b')
        self.parts.append('</svg>')
        (OUT/(name+'.svg')).write_text('\n'.join(self.parts),encoding='utf-8')

COMMON={'pc','pc4','fetch','instr','fd','de','em','mw'}
PATHS={
 'lw':({'rf','ext','cu','a','fa','aa','imm','ab','alu','alu_m','addr','dmem','read','wb','result','writeback'},'lw x5, 0(x1)','A = rs1 + Imm; RD -> ResultW -> rd. A dependent next instruction stalls once.'),
 'sw':({'rf','ext','cu','a','b','fa','fb','aa','imm','ab','alu','alu_m','addr','store','dmem'},'sw x5, 0(x1)','A = rs1 + Imm; forwarded rs2 -> WD. MemW=1; no register writeback.'),
 'j':({'ext','cu','imm','target','redirect','decision'},'j label   (= jal x0, label)','PC + Imm -> PCNext in EX. Flush IF/ID and ID/EX; rd=x0 discards PC+4.'),
 'branch':({'rf','ext','cu','a','b','fa','fb','cmp','decision','imm','target','redirect'},'beq x1, x2, label','Compare forwarded operands in EX. If taken: PC+Imm, FlushD=1, FlushE=1.'),
 'add':({'rf','cu','a','b','fa','fb','aa','ab','alu','alu_m','wb','result','writeback'},'add x5, x1, x2','Forwarded rs1 + forwarded rs2 -> ALUM -> ALUW -> ResultW -> rd.'),
 'addi':({'rf','ext','cu','a','fa','aa','imm','ab','alu','alu_m','wb','result','writeback'},'addi x5, x1, 7','Forwarded rs1 + sign-extended I immediate -> ALU -> ResultW -> rd.')}

def datapath(kind=None):
    selected,title,note=PATHS[kind] if kind else (None,'Full datapath with hazard handling','Data: black   |   Control: blue   |   F / D / E / M / W = IF / ID / EX / MEM / WB')
    d=Drawing(2000,1200,title,note,None if kind is None else COMMON|selected)
    for x,t in [(150,'IF'),(555,'ID'),(1070,'EX'),(1510,'MEM'),(1840,'WB')]:d.text(x,110,t,'stage')
    # Register boundaries and short signal lanes.
    for key,x,label in [('fd',380,'IF/ID'),('de',810,'ID/EX'),('em',1340,'EX/MEM'),('mw',1710,'MEM/WB')]:
        d.box(key,x,150,28,655,'')
        d.text(x+14,135,label,'sig',d.color(key),'middle')
        d.text(x+14,826,'clk','sig',d.color(key),'middle')
    # Control travels across exactly the same pipeline boundaries as data.
    d.wire('instr',[(430,455),(430,200),(495,200)],'Op / F3 / F7',(432,185))
    d.dot('instr',430,455)
    for y,label in [(170,'RegW'),(200,'MemW'),(230,'ResSrc[1:0]'),(260,'ALUOp[3:0]'),(290,'ALUSrc / ASrc'),(320,'Br / Jmp / Jr')]:
        d.wire('cu',[(675,y),(810,y)],label,(684,y),True)
    for y,label in [(170,'RegW'),(200,'MemW'),(230,'ResSrc')]:
        d.wire('cu',[(838,y),(1340,y)],label,(1220,y),True)
    d.wire('cu',[(1368,170),(1710,170)],'RegWM',(1480,170),True)
    d.wire('cu',[(1368,230),(1710,230)],'ResSrcM',(1480,230),True)
    d.wire('cu',[(1738,230),(1883,230),(1883,465)],'ResSrcW',(1752,230),True)
    d.wire('cu',[(1368,200),(1565,200),(1565,425)],'MemWM',(1465,200),True)
    d.wire('cu',[(675,350),(700,350),(700,685),(665,685)],'ImmSrc',(693,370),True)
    # Fetch and instruction decoding.
    d.wire('pc',[(90,455),(130,455)])
    d.wire('fetch',[(175,455),(205,455)])
    d.wire('instr',[(335,455),(380,455)],'InstrF',(336,447))
    d.wire('instr',[(408,455),(500,455)],'Rs1/2',(414,442))
    d.dot('instr',430,455)
    d.wire('instr',[(450,455),(450,495),(500,495)])
    d.wire('instr',[(450,455),(450,495),(500,495)])
    d.wire('instr',[(450,455),(450,685),(525,685)],'InstrD',(454,652))
    d.dot('instr',450,455)
    d.wire('pc4',[(188,455),(188,615),(225,615)])
    d.wire('pc4',[(295,615),(330,615),(330,740),(380,740)],'PC4F',(307,727))
    d.wire('pc4',[(330,615),(345,615),(345,350),(45,350),(45,440),(65,440)])
    d.dot('pc4',330,615)
    d.wire('pc',[(188,590),(350,590),(350,775),(380,775)],'PCF',(311,767))
    d.dot('pc',188,590)
    # ID data lanes.
    d.wire('a',[(665,455),(810,455)],'RD1D',(721,455))
    d.wire('b',[(665,545),(810,545)],'RD2D',(721,545))
    d.wire('imm',[(665,685),(680,685),(680,705),(810,705)],'ImmD',(729,705))
    for y,key,label in [(740,'pc4','PC4D'),(775,'pc','PCD')]:d.wire(key,[(408,y),(810,y)],label,(726,y))
    d.wire('instr',[(450,640),(810,640)],'Rs1D / Rs2D / RdD / F3D',(555,637))
    d.dot('instr',450,640)
    # EX operand muxes and ALU.
    d.wire('a',[(838,455),(910,455)],'RD1E',(841,447))
    d.wire('b',[(838,545),(910,545)],'RD2E',(841,537))
    d.wire('fa',[(935,468),(975,468),(975,455),(1030,455)],'AE',(949,451))
    d.wire('fb',[(935,558),(1030,558)],'BE',(971,550))
    d.wire('aa',[(1055,468),(1135,468)],'SrcAE',(1062,456))
    d.wire('ab',[(1055,563),(1095,563),(1095,530),(1135,530)],'SrcBE',(1060,552))
    d.wire('imm',[(838,705),(1000,705),(1000,585),(1030,585)],'ImmE',(862,698))
    d.wire('pc',[(838,775),(990,775),(990,485),(1030,485)])
    d.wire('cu',[(838,260),(1200,260),(1200,425)],'ALUOpE',(1122,260),True)
    d.wire('cu',[(838,290),(1042,290),(1042,438)],'ASrcE',(913,290),True)
    d.wire('cu',[(1090,290),(1090,620),(1042,620),(1042,598)],'ALUSrcE',(1098,602),True)
    d.wire('cu',[(1042,290),(1090,290)],ctrl=True,arrow=False)
    d.wire('alu_m',[(1270,500),(1340,500)],'ALUE',(1278,492))
    d.wire('store',[(965,558),(965,650),(1340,650)],'WD = BE',(1200,646))
    d.dot('fb',965,558)
    # Branch compare uses AE/BE, never the immediate selected at SrcBE.
    d.wire('cmp',[(975,468),(975,375),(1100,375)])
    d.wire('cmp',[(950,558),(950,395),(1100,395)])
    d.wire('decision',[(1230,380),(1305,380),(1305,335)],'TakeE',(1234,371),True)
    d.wire('decision',[(838,320),(1250,320)],'BrE / JmpE',(1010,315),True)
    d.wire('decision',[(1320,320),(1328,320),(1328,125),(77,125),(77,422)],'PCSrcE',(140,125),True)
    # Target adder and jalr base selection/bit-zero clearing are combined here.
    d.wire('target',[(990,760),(1110,760)],'PCE',(1048,754))
    d.wire('target',[(1000,705),(1110,705)],'ImmE',(1030,698))
    d.wire('target',[(975,468),(980,468),(980,725),(1110,725)],'AE (jalr)',(1007,725))
    d.wire('redirect',[(1270,745),(1310,745),(1310,835),(30,835),(30,480),(65,480)],'TargetE',(1130,834))
    d.wire('pc4',[(838,740),(870,740),(870,790),(1340,790)],'PC4E',(900,785))
    d.wire('instr',[(838,640),(890,640),(890,810),(1330,810),(1330,700),(1340,700)],'RdE',(1265,806))
    # Memory and writeback.
    d.wire('addr',[(1368,500),(1470,500)],'ALUM / A',(1380,489))
    d.wire('store',[(1368,650),(1430,650),(1430,590),(1470,590)],'WDM / WD',(1377,638))
    d.wire('read',[(1630,505),(1710,505)],'RDM',(1650,498))
    d.wire('alu_m',[(1400,500),(1400,385),(1680,385),(1680,440),(1710,440)],'ALUM',(1530,382))
    d.dot('addr',1400,500)
    d.wire('pc4',[(1368,790),(1710,790)],'PC4M',(1560,782))
    d.wire('instr',[(1368,700),(1710,700)],'RdM',(1560,693))
    d.wire('wb',[(1738,440),(1810,440),(1810,485),(1870,485)],'ALUW',(1748,431))
    d.wire('read',[(1738,505),(1870,505)],'RDW',(1790,498))
    d.wire('pc4',[(1738,790),(1840,790),(1840,528),(1870,528)],'PC4W',(1760,782))
    d.wire('result',[(1895,505),(1955,505),(1955,925),(470,925),(470,570),(500,570)],'ResultW / WD',(1660,917))
    d.wire('writeback',[(1738,700),(1765,700),(1765,965),(485,965),(485,605),(500,605)],'RdW / A3',(1540,957))
    d.wire('writeback',[(1738,170),(1970,170),(1970,985),(455,985),(455,585),(500,585)],'RegWW / WE',(1700,978),True)
    # MEM forwarding includes link address, excludes load data.
    d.wire('fwd_m',[(1400,385),(1400,355),(1490,355)])
    d.wire('fwd_m',[(1450,790),(1450,400),(1502,400),(1502,380)])
    d.wire('fwd_m',[(1515,355),(1660,355),(1660,870),(885,870),(885,493),(910,493)],'FwdM = (ResSrcM==2) ? PC4M : ALUM',(1200,863))
    d.wire('fwd_m',[(885,575),(910,575)])
    d.dot('fwd_m',885,575)
    d.wire('fwd_w',[(1800,925),(900,925),(900,480),(910,480)])
    d.dot('result',1800,925)
    d.wire('fwd_w',[(900,563),(910,563)])
    d.dot('fwd_w',900,563)
    # Hazard wiring: input bundle is deliberate to avoid an unreadable wire forest.
    d.wire('hz',[(710,640),(710,1015)],'Rs1/2D, Use1/2D',(548,1000),True)
    d.wire('hz',[(855,810),(855,1015)],'Rs1/2E, RdE, LoadE, Use1/2E',(860,1000),True)
    d.wire('hz',[(1600,700),(1600,1015)],'RdM/W, RegWM/W, LoadM',(1420,1000),True)
    d.wire('hz',[(1328,320),(1332,320),(1332,1015)],'PCSrcE',(1340,965),True)
    d.wire('hz',[(500,1095),(155,1095),(155,500)],'StallF',(167,1078),True)
    d.wire('hz',[(620,1095),(394,1095),(394,805)],'StallD / FlushD',(405,1113),True)
    d.wire('hz',[(780,1095),(824,1095),(824,805)],'FlushE',(730,1132),True)
    d.wire('hz',[(930,1015),(930,945),(922,945),(922,585)],'FwdBE',(944,949),True)
    d.wire('hz',[(970,1015),(970,935),(940,935),(940,520),(922,520),(922,510)],'FwdAE',(978,967),True)
    # Blocks drawn over wires; interior pins remain short and legible.
    d.mux('pc',65,420,80)
    d.box('pc',130,420,45,80,'PC')
    d.box('fetch',205,385,130,135,'imem',[(8,73,'A'),(97,73,'RD')])
    d.box('pc4',225,585,70,60,'+ 4')
    d.box('cu',495,145,180,215,'control unit',ctrl=True)
    d.text(505,337,'Use1 / Use2 / Legal','sig',d.color('cu',True))
    d.box('rf',500,415,165,205,'regfile',[(8,42,'A1'),(8,82,'A2'),(125,42,'RD1'),(125,132,'RD2'),(8,154,'WD'),(8,173,'WE'),(8,192,'A3')])
    d.box('ext',525,660,140,50,'extend')
    d.mux('fa',910,435,75,three=True);d.mux('fb',910,525,75,three=True)
    d.mux('aa',1030,435,65); d.mux('ab',1030,540,65)
    d.box('alu',1135,425,135,150,'ALU',[(8,47,'A'),(8,107,'B'),(115,79,'Y')])
    d.box('cmp',1100,350,130,60,'branch unit')
    d.box('decision',1250,303,70,32,'OR/AND',ctrl=True)
    d.box('target',1110,680,160,95,'target +')
    d.text(1118,797,'JrE: AE+Imm, bit0=0','small',d.color('target'))
    d.box('dmem',1470,425,160,210,'dmem',[(8,77,'A'),(128,83,'RD'),(8,170,'WD'),(85,22,'WE')])
    d.mux('fwd_m',1490,330,50)
    d.mux('wb',1870,465,80,three=True)
    d.box('hz',500,1015,1210,80,'hazard unit',ctrl=True)
    d.text(520,1080,'M > W; x0 excluded; loads cannot forward from M; load-use inserts one bubble','small',d.color('hz',True))
    d.text(32,1150,'All pipeline registers: clk, rst. ce enables a CPU cycle. Valid bits gate writes and redirects. Lines crossing without a dot are not junctions.','small')
    d.save('path_'+kind if kind else 'pipeline_full')

def control():
    d=Drawing(1420,1020,'Control unit','Combinational decode in ID; control bits travel with their instruction.')
    d.box('op',60,155,175,110,'InstrD')
    d.box('decode',355,130,245,180,'opcode decode',ctrl=True)
    d.box('alu',355,365,245,130,'ALU decode',ctrl=True)
    d.box('guard',765,150,210,295,'legal guard',ctrl=True)
    d.box('de',1190,130,45,370,'')
    d.text(1212,116,'ID/EX','sig',INK,'middle')
    d.wire('a',[(235,185),(355,185)],'Op[6:0]',(255,177),True)
    d.wire('b',[(235,225),(280,225),(280,405),(355,405)],'F3, F7',(282,388),True)
    d.wire('b',[(280,245),(355,245)],'F3',(296,235),True)
    d.wire('a',[(320,185),(320,450),(355,450)],'Op',(322,435),True)
    d.wire('c',[(600,185),(765,185)],'main controls',(625,175),True)
    d.wire('d',[(600,415),(765,415)],'ALUOp, Legal',(619,405),True)
    for y,label in [(175,'RegW, MemW'),(220,'ResSrc[1:0]'),(265,'ALUOp[3:0]'),(310,'ALUSrc, ASrc'),(355,'Br, Jmp, Jr'),(400,'Use1, Use2')]:
        d.wire('c',[(975,y),(1190,y)],label,(995,y),True)
    d.wire('i',[(600,265),(650,265),(650,535),(1125,535)],'ImmSrc[2:0] -> extend (ID)',(700,527),True)
    d.text(785,477,'!Legal: disable writes, redirect and source-use flags','small')
    d.text(60,585,'Decode table (— = unused; values shown before the Legal guard)','stage')
    headers=['Instruction','RegW','MemW','ResSrc','ALUSrc','ASrc','ImmSrc','Br','Jmp','Jr','Use1/2']
    xs=[60,310,400,490,600,710,800,920,1000,1080,1170]
    rows=[['R-type','1','0','ALU','0','0','—','0','0','0','1 / 1'],
          ['I-type ALU','1','0','ALU','1','0','I','0','0','0','1 / 0'],
          ['lw','1','0','RD','1','0','I','0','0','0','1 / 0'],
          ['sw','0','1','—','1','0','S','0','0','0','1 / 1'],
          ['branch','0','0','—','0','0','B','1','0','0','1 / 1'],
          ['jal / j','1','0','PC4','0','0','J','0','1','0','0 / 0'],
          ['jalr','1','0','PC4','1','0','I','0','1','1','1 / 0'],
          ['lui','1','0','ALU','1','0','U','0','0','0','0 / 0'],
          ['auipc','1','0','ALU','1','1','U','0','0','0','0 / 0']]
    for x,s in zip(xs,headers):d.text(x,625,s,'sig',BLUE)
    for i,row in enumerate(rows):
        y=661+i*30
        d.wire('line',[(55,y+9),(1330,y+9)],arrow=False)
        for x,s in zip(xs,row):d.text(x,y,s)
    d.text(60,961,'ResSrc: 00=ALU, 01=RD, 10=PC4. ImmSrc: 000=I, 001=S, 010=B, 011=J, 100=U.','sig')
    d.save('control_unit')

def hazard():
    d=Drawing(1500,1080,'Hazard unit','Combinational logic; source-use flags prevent false dependencies on immediate bits.')
    d.text(50,125,'1. Forwarding (each EX source, A and B)','stage')
    d.box('source',50,170,220,135,'RsE / UseE')
    d.box('m',375,160,325,100,'M match: RegWM & RdM=RsE')
    d.box('w',375,300,325,100,'W match: RegWW & RdW=RsE')
    d.box('priority',825,170,290,230,'M has priority over W')
    d.box('mux',1220,180,215,200,'FwdAE / FwdBE')
    d.wire('a',[(270,210),(375,210)])
    d.wire('b',[(300,210),(300,350),(375,350)])
    d.wire('m',[(700,210),(825,210)])
    d.wire('w',[(700,350),(825,350)])
    d.wire('o',[(1115,275),(1220,275)],ctrl=True)
    d.text(850,430,'UseE=0 or RsE=0: 00')
    d.text(1229,410,'00: RD1E / RD2E')
    d.text(1229,435,'01: ResultW')
    d.text(1229,460,'10: FwdM')
    d.text(50,445,'M match + LoadM: 00 (interlock prevents this consumer from reaching EX).')
    d.text(50,472,'FwdM selects ALUM or PC4M; a load address is never forwarded as loaded data.')
    d.text(50,535,'2. Load-use interlock','stage')
    d.box('d',50,575,290,140,'Decode sources')
    d.text(60,610,'Use1D & Rs1D=RdE')
    d.text(60,695,'Use2D & Rs2D=RdE')
    d.box('or',430,610,90,60,'OR')
    d.box('and',645,595,300,90,'AND')
    d.wire('a',[(340,610),(430,625)])
    d.wire('a',[(340,695),(390,695),(390,655),(430,655)])
    d.wire('a',[(520,640),(645,640)])
    d.wire('a',[(795,555),(795,595)],'LoadE & RdE!=0',(704,550))
    d.wire('a',[(945,640),(1230,640)],'lwStall',(1040,629),True)
    d.text(50,770,'3. Redirect and pipeline actions','stage')
    d.box('redirect',50,810,400,90,'PCSrcE = VE & (JmpE | BrE & TakeE)',ctrl=True)
    d.wire('a',[(450,855),(560,855)],ctrl=True)
    d.box('action',560,800,875,165,'',ctrl=True)
    for y,s in [(835,'StallF = StallD = lwStall & !PCSrcE'),(875,'FlushD = PCSrcE'),(915,'FlushE = lwStall | PCSrcE')]:d.text(590,y,s,'sig',BLUE)
    d.text(50,1007,'Load-use: hold PC and IF/ID, clear ID/EX. Taken redirect: load target PC, clear IF/ID and ID/EX.')
    d.save('hazard_unit')

if __name__=='__main__':
    OUT.mkdir(parents=True,exist_ok=True)
    datapath()
    for kind in PATHS:datapath(kind)
    control();hazard()
    print('Wrote 9 SVG drawings to docs/diagrams')
