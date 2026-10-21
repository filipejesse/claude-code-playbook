"""Adds the title header to the demo GIF and draws the GitHub social preview (1280x640).

Run in the folder holding term.gif (see record-autopilot-demo.sh). Uses macOS fonts.
"""
from PIL import Image, ImageDraw, ImageFont, ImageSequence
SF = '/System/Library/Fonts/SFNS.ttf'; MONO = '/System/Library/Fonts/SFNSMono.ttf'
HN = '/System/Library/Fonts/HelveticaNeue.ttc'
FACE = {400: 0, 700: 1, 500: 10, 600: 10, 300: 7}
def font(path, size, weight=None):
    if path == SF: return ImageFont.truetype(HN, size, index=FACE.get(weight or 400, 0))
    return ImageFont.truetype(path, size)
BG = (22, 24, 29); TERM = (40, 42, 54); FG = (240, 240, 240); MUTED = (160, 166, 178); ACCENT = (217, 119, 87)

# 1. GIF with a title header
src = Image.open('term.gif'); W, H = src.size; HEAD = 118
frames, durs = [], []
for fr in ImageSequence.Iterator(src):
    durs.append(fr.info.get('duration', 100))
    c = Image.new('RGB', (W, H + HEAD), BG)
    d = ImageDraw.Draw(c)
    d.text((24, 20), 'Autopilot', font=font(SF, 44, 700), fill=FG)
    tw = d.textlength('Autopilot', font=font(SF, 44, 700))
    d.text((24 + tw + 14, 33), 'for Claude Code', font=font(SF, 30, 400), fill=MUTED)
    d.text((24, 76), 'Describe a project once. Get back a verified PR.', font=font(SF, 24, 500), fill=ACCENT)
    d.text((W - 24, 84), 'real run · sped up', font=font(MONO, 17), fill=MUTED, anchor='ra')
    c.paste(fr.convert('RGB'), (0, HEAD))
    frames.append(c.quantize(colors=128, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE))
frames[0].save('autopilot-demo.gif', save_all=True, append_images=frames[1:], duration=durs, loop=0, optimize=True, disposal=1)

# 2. Social preview 1280x640
S = Image.new('RGB', (1280, 640), BG); d = ImageDraw.Draw(S)
d.text((72, 70), 'Autopilot', font=font(SF, 92, 700), fill=FG)
d.text((76, 178), 'for Claude Code', font=font(SF, 46, 400), fill=MUTED)
d.text((76, 262), 'Describe a project once.', font=font(SF, 36, 600), fill=FG)
d.text((76, 308), 'Get back a verified PR.', font=font(SF, 36, 600), fill=ACCENT)
y = 392
for line in ['waits out usage limits, then resumes', 'never spends paid usage credits', 'hooks keep it off main, no merges']:
    d.ellipse((80, y + 12, 90, y + 22), fill=ACCENT)
    d.text((106, y), line, font=font(SF, 26, 400), fill=MUTED); y += 46
d.text((76, 560), 'claude-code-playbook', font=font(MONO, 24), fill=MUTED)
# terminal card on the right with the final frame
src.seek(16); shot = src.convert('RGB')
shot = shot.crop((0, 0, 820, shot.height)).resize((int(820 * 0.62), int(shot.height * 0.62)))
card = Image.new('RGB', (shot.width + 2, shot.height + 38), TERM)
cd = ImageDraw.Draw(card)
for i, col in enumerate([(255, 95, 86), (255, 189, 46), (39, 201, 63)]):
    cd.ellipse((14 + i * 22, 13, 26 + i * 22, 25), fill=col)
card.paste(shot, (1, 37))
x, yy = 1280 - card.width - 56, (640 - card.height) // 2
mask = Image.new('L', card.size, 0); ImageDraw.Draw(mask).rounded_rectangle((0, 0, card.width - 1, card.height - 1), 14, fill=255)
S.paste(card, (x, yy), mask)
S.save('social-preview.png')
print(Image.open('autopilot-demo.gif').size, S.size)
