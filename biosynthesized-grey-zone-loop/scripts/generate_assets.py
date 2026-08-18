import os
import struct
import zlib
import math
import random

def create_png(width, height, get_pixel_rgba):
    raw_data = bytearray()
    for y in range(height):
        raw_data.append(0)
        for x in range(width):
            r, g, b, a = get_pixel_rgba(x, y)
            raw_data.extend([max(0,min(255,int(r))),max(0,min(255,int(g))),max(0,min(255,int(b))),max(0,min(255,int(a)))])
    compressed = zlib.compress(bytes(raw_data), 9)
    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff)
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", compressed) + chunk(b"IEND", b"")

def blend(c1, c2, t):
    return tuple(int(c1[i]*(1-t)+c2[i]*t) for i in range(4))

def main():
    proj = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    assets = os.path.join(proj, "assets")
    os.makedirs(assets, exist_ok=True)
    W, H = 128, 128
    COLS = 4
    TRANS = (0,0,0,0)

    # Ally colors
    C_SKIN_LT=(218,222,228,255); C_SKIN_SH=(155,162,172,255); C_CRACK=(120,128,140,255)
    C_CERAMIC=(240,244,250,255); C_CERAMIC_SH=(180,188,200,255); C_FRAME=(40,50,65,255)
    C_NERVE=(0,200,185,255); C_NERVE_DK=(0,110,100,255); C_MUSCLE_SY=(28,55,80,255)
    C_CORE_GLOW=(180,255,248,255); C_CORE_MID=(60,220,200,255)
    C_TAG_Y=(255,210,30,255); C_TAG_BK=(20,20,25,255); C_CABLE=(15,18,22,255); C_RUST=(90,75,60,255)

    def ally(px, py):
        frame = px // W; x = px % W; y = py
        breathe = [0,-1,-2,-1][frame]; y2 = y - breathe
        def d2(cx,cy): return math.sqrt((x-cx)**2+(y2-cy)**2)
        def ir(x0,y0,x1,y1): return x0<=x<=x1 and y0<=y2<=y1
        def ie(cx,cy,rx,ry): return ((x-cx)/rx)**2+((y2-cy)/ry)**2<=1.0
        # Head
        if ie(62,28,20,22):
            if ir(38,28,46,34):
                if x==38 or x==46 or y2==28 or y2==34: return C_FRAME
                return C_TAG_Y
            if x<=52 and abs(x-48-(y2-30)*0.4)<1.5: return C_CRACK
            if ir(60,30,78,35):
                if abs(y2-32)<=1: return C_NERVE
                if abs(y2-32)<=2: return C_NERVE_DK
            if y2<=18: return C_CERAMIC
            if y2<=22: return C_CERAMIC_SH if x>60 else C_SKIN_SH
            return C_SKIN_LT if x>52 else C_SKIN_SH
        # Neck
        if ir(52,49,74,57):
            if y2 in (49,57) or x in (52,74): return C_FRAME
            if x>=68 and x%3==0: return C_CABLE
            return C_SKIN_SH
        # Torso
        if ir(34,57,96,102):
            d_core=d2(60,76)
            if d_core<=5: return C_CORE_GLOW
            if d_core<=9: return C_CORE_MID
            if d_core<=13: return C_NERVE_DK
            if x>=72:
                if (x-72)%5<=1: return C_MUSCLE_SY
                if (x-72)%5==2: return C_NERVE_DK
                return C_MUSCLE_SY
            if x<=54:
                return C_CERAMIC_SH if y2%8<=1 else C_CERAMIC
            if x<=63: return C_SKIN_SH
            return C_SKIN_LT
        # Waist
        if ir(40,102,88,110):
            return (C_CERAMIC if y2<=106 else C_FRAME) if x<=58 else C_MUSCLE_SY
        # Left leg (exo)
        if ir(38,110,62,128):
            if x<=44 or x>=60: return C_FRAME
            if y2<=118: return C_CERAMIC
            if y2>=123: return C_RUST if x%4==0 else C_FRAME
            return C_CERAMIC_SH
        # Right leg (organic)
        if ir(65,110,90,128):
            if x>=88: return C_FRAME
            if y2<=118: return C_MUSCLE_SY if (y2-110)%4<=1 else C_SKIN_SH
            if y2<=122: return C_CERAMIC_SH
            return C_FRAME
        # Left arm (exo)
        if ir(18,60,38,100):
            if x<=20 or x>=36: return C_FRAME
            return C_CERAMIC if y2<=72 else C_CERAMIC_SH
        # Right arm (nerve discharge)
        if ir(92,58,124,98):
            if x>=122: return TRANS
            if x<=106:
                if (x-92)%5==0: return C_CABLE
                if (x-92)%5<=2: return C_MUSCLE_SY
                return C_SKIN_SH
            blade_y=int(76-(x-106)*0.3)
            if abs(y2-blade_y)<=1: return C_CORE_GLOW if abs(y2-blade_y)==0 else C_NERVE
            if abs(y2-blade_y)<=3: return C_NERVE_DK
            if x in (108,114,120) and y2 in (68,69,70): return C_FRAME
            return C_SKIN_SH
        return TRANS

    with open(os.path.join(assets,"ally_bioroid.png"),"wb") as f:
        f.write(create_png(W*COLS,H,ally))

    # Enemy colors
    C_FLESH_DK=(105,18,30,255); C_FLESH_MD=(175,38,52,255); C_FLESH_LT=(230,65,75,255)
    C_RAW_MEAT=(195,55,45,255); C_VEIN=(80,10,20,255)
    C_CORE_R=(255,30,20,255); C_CORE_WHT=(255,225,200,255)
    C_BONE=(240,228,205,255); C_BONE_SH=(190,175,150,255); C_EXOSKEL=(130,110,85,255)
    C_SHACKLE=(55,48,58,255); C_SHACKLE_R=(180,35,30,255)
    C_EYE_COMP=(255,120,30,255); C_EYE_CORE=(255,240,200,255); C_CRYSTAL=(200,180,230,255)
    rng2=random.Random(0xAF09)

    def enemy(px,py):
        frame=px//W; x=px%W; y=py
        growl=[0,2,-1,1][frame]; y2=y-growl
        def d2(cx,cy): return math.sqrt((x-cx)**2+(y2-cy)**2)
        def ir(x0,y0,x1,y1): return x0<=x<=x1 and y0<=y2<=y1
        def ie(cx,cy,rx,ry): return ((x-cx)/rx)**2+((y2-cy)/ry)**2<=1.0
        # Bone spines (right back)
        for sx,sy,angle in [(92,20,-0.3),(102,28,-0.1),(110,18,-0.5),(96,12,-0.4),(106,38,0.0),(115,46,0.2)]:
            for t in range(22):
                tx=int(sx+t*math.sin(angle)); ty=int(sy-t*math.cos(angle))
                if abs(x-tx)<=2 and abs(y2-ty)<=2:
                    dist=math.sqrt((x-sx)**2+(y2-sy)**2)
                    return C_BONE_SH if dist<3 else (C_BONE if (x+y2)%2==0 else C_BONE_SH)
        # Crystal growths
        for cx,cy in [(98,55),(108,62),(118,50),(104,48)]:
            if d2(cx,cy)<=4: return C_CRYSTAL if d2(cx,cy)<=2 else C_BONE_SH
        # Head (asymmetric)
        if ie(58,26,22,22):
            if x>=66:
                if y2<=18: return C_BONE
                return C_BONE_SH if (x+y2)%5<=1 else C_EXOSKEL
            for ex,ey in [(62,24),(70,20),(66,30)]:
                if d2(ex,ey)<=3: return C_EYE_CORE if d2(ex,ey)<=1 else C_EYE_COMP
            if y2>=30:
                return C_BONE if x<=48 and y2>=36 else C_FLESH_MD
            return C_FLESH_DK
        # Neck with broken shackle
        if ir(46,47,72,55):
            if y2 in (47,55) or x in (46,72): return C_SHACKLE
            if x>=62 and y2==51: return C_SHACKLE_R
            return C_FLESH_DK
        # Torso (strongly asymmetric)
        if ir(24,55,120,102):
            d_core=d2(62,76)
            if d_core<=6: return C_CORE_WHT
            if d_core<=10: return C_CORE_R
            if d_core<=15: return C_FLESH_LT
            if x>=68:
                if (x-68)%6<=1: return C_VEIN
                return C_FLESH_LT if (x+y2)%4==0 else (C_FLESH_MD if y2<=80 else C_RAW_MEAT)
            if x<=42:
                if y2 in (62,72,82) and x>=36: return C_SHACKLE
                return C_FLESH_DK
            if y2>=88: return C_EXOSKEL if (x+y2)%3==0 else C_FLESH_MD
            return C_FLESH_DK
        # Waist
        if ir(30,102,90,112):
            return (C_BONE_SH if x<=35 else C_EXOSKEL) if x<=50 else C_FLESH_MD
        # Left leg
        if ir(30,112,56,128):
            if y2>=122:
                if x in (32,33,34): return C_SHACKLE
                if (x+y2)%6==0: return C_SHACKLE_R
            if x<=32 or x>=54: return C_FLESH_DK
            return C_FLESH_MD if y2<=118 else C_FLESH_DK
        # Right leg (overdeveloped)
        if ir(65,108,100,128):
            if ir(85,108,92,120): return C_BONE if y2<=114 else C_BONE_SH
            if x>=95: return C_FLESH_DK
            if y2>=120: return C_BONE_SH if (x+y2)%3==0 else C_FLESH_DK
            return C_RAW_MEAT if (x-65)%5<=1 else C_FLESH_MD
        # Left arm (atrophied)
        if ir(8,60,30,95):
            if x<=10 or x>=28: return C_FLESH_DK
            if y2 in (68,80): return C_SHACKLE
            return C_FLESH_MD
        # Right arm upper (hypertrophied)
        if ir(98,60,128,90):
            if x>=126: return TRANS
            d_arm=d2(112,74)
            if d_arm<=12: return C_VEIN if (x+y2)%5==0 else (C_FLESH_MD if d_arm<=8 else C_FLESH_DK)
        # Claws
        for ci,(csx,csy) in enumerate([(118,90),(112,92),(105,88)]):
            for t in range(16):
                angle=-0.3+ci*0.3
                tx=int(csx+t*math.cos(angle)); ty=int(csy+t*math.sin(angle)*1.5+t*0.5)
                if abs(x-tx)<=2 and abs(y2-ty)<=2:
                    return C_BONE if abs(x-tx)<=1 else C_BONE_SH
        return TRANS

    with open(os.path.join(assets,"enemy_bioroid.png"),"wb") as f:
        f.write(create_png(W*COLS,H,enemy))

    # Floor texture
    def floor_sector04(x,y):
        C_CON_D=(18,22,26,255); C_CON_M=(26,32,38,255); C_GROOVE=(10,12,16,255)
        C_HAZ_Y=(215,172,15,255); C_HAZ_BK=(18,18,22,255)
        C_DRAIN=(12,14,16,255); C_DRAIN_SLT=(8,10,12,255)
        C_BIO1=(45,12,18,255); C_BIO2=(30,8,14,255)
        if x==0 or y==0 or x==63 or y==63: return C_GROOVE
        if 2<=y<=10: return C_HAZ_Y if (x+y)%14<7 else C_HAZ_BK
        if 27<=x<=36 and 24<=y<=40:
            if x in (27,36) or y in (24,40): return C_DRAIN
            if x%3==0 or y%4==0: return C_DRAIN_SLT
            return C_DRAIN
        for stx,sty,sr in [(48,45,6),(52,52,4),(44,55,5),(55,40,3),(12,50,4),(8,40,3)]:
            d=math.sqrt((x-stx)**2+(y-sty)**2)
            if d<=sr: return blend(C_BIO1,C_BIO2,d/sr)
        if x%16==0 or y%16==0: return C_GROOVE
        return C_CON_M if (x//16+y//16)%2==0 else C_CON_D

    with open(os.path.join(assets,"arena_floor.png"),"wb") as f:
        f.write(create_png(64,64,floor_sector04))

    # Facility wall texture
    def facility_wall(x,y):
        C_WD=(22,28,34,255); C_WM=(32,40,48,255); C_WL=(42,52,62,255)
        C_BOLT=(55,62,70,255); C_VENT=(12,16,20,255); C_HY=(215,172,15,255); C_WR=(180,30,20,255)
        if y<=4: return C_HY if (x//8)%2==0 else (20,20,24,255)
        if y>=60: return C_WR if (x//6)%3==0 else C_WD
        if x%32==0 or x%32==1: return C_BOLT
        for bx,by in [(8,10),(24,10),(8,54),(24,54),(40,10),(56,10),(40,54),(56,54)]:
            if abs(x-bx)<=2 and abs(y-by)<=2:
                d=math.sqrt((x-bx)**2+(y-by)**2)
                return C_WL if d<=1.5 else C_BOLT
        if 28<=y<=36 and x%6<=1: return C_VENT
        return C_WM if (x//32+y//32)%2==0 else C_WD

    with open(os.path.join(assets,"facility_wall.png"),"wb") as f:
        f.write(create_png(64,64,facility_wall))

    print("[Aether Fountain] Asset generation complete.")
    print("  ally_bioroid.png  - BIO-ALD-DEF001, 4-frame 128x128, asymmetric bio-synthetic")
    print("  enemy_bioroid.png - SUBJECT AF-09,   4-frame 128x128, heavily mutated lambda anomaly")
    print("  arena_floor.png   - Containment floor with bio-stains and hazard markings")
    print("  facility_wall.png - Facility wall panel with security markings")

if __name__ == "__main__":
    main()
