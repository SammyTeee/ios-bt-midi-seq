"""Generate the app's simple sequencer-grid icon; requires Pillow."""
import json
from pathlib import Path
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[1] / "Sources/App/Assets.xcassets"
folder = root / "AppIcon.appiconset"
folder.mkdir(parents=True, exist_ok=True)
(root / "Contents.json").write_text(json.dumps({"info": {"author": "xcode", "version": 1}}))
image = Image.new("RGB", (1024, 1024), (14, 18, 17))
draw = ImageDraw.Draw(image)
active = {(0, 2), (1, 1), (2, 3), (3, 0)}
for row in range(4):
    for col in range(4):
        x, y = 136 + col * 196, 136 + row * 196
        color = (188, 245, 89) if (col, row) in active else (40, 52, 45)
        draw.rounded_rectangle((x, y, x + 164, y + 164), radius=30, fill=color)
image.save(folder / "AppIcon.png")
(folder / "Contents.json").write_text(json.dumps({
    "images": [{"filename": "AppIcon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
    "info": {"author": "xcode", "version": 1}
}, indent=2))
