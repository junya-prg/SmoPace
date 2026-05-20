#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
from PIL import Image, ImageDraw, ImageFont

BASE_DIR = "/Users/hondajunya/00_work/94_自作/SmoPace"
IMG_DIR = os.path.join(BASE_DIR, "スクショ/20260412")
OUTPUT_PATH = os.path.join(BASE_DIR, "screenshots/grid_view.png")

def get_japanese_font(size):
    font_paths = [
        "/System/Library/Fonts/PingFang.ttc",
        "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc",
        "/Library/Fonts/Arial Unicode.ttf"
    ]
    for path in font_paths:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size, index=0)
            except IOError:
                try:
                    return ImageFont.truetype(path, size)
                except IOError:
                    continue
    return ImageFont.load_default()

def main():
    files = [f for f in os.listdir(IMG_DIR) if f.startswith("Simulator Screenshot - iPhone 17 Pro Max")]
    files.sort()
    
    # 3x3 grid
    thumb_w = 300
    thumb_h = 650
    gap = 20
    
    grid_w = thumb_w * 3 + gap * 4
    grid_h = thumb_h * 3 + gap * 4
    
    grid_img = Image.new("RGB", (grid_w, grid_h), (30, 30, 40))
    draw = ImageDraw.Draw(grid_img)
    font = get_japanese_font(28)
    
    for idx, filename in enumerate(files):
        row = idx // 3
        col = idx % 3
        
        x = gap + col * (thumb_w + gap)
        y = gap + row * (thumb_h + gap)
        
        img_path = os.path.join(IMG_DIR, filename)
        with Image.open(img_path) as img:
            thumb = img.resize((thumb_w, thumb_h), Image.Resampling.LANCZOS)
            grid_img.paste(thumb, (x, y))
            
            # Label
            label = f"Draft {idx+1:02d}"
            # Draw label box
            draw.rectangle([x, y, x + 120, y + 40], fill=(0, 0, 0, 180))
            draw.text((x + 10, y + 5), label, fill=(255, 255, 255), font=font)
            
    grid_img.save(OUTPUT_PATH)
    print(f"Grid view saved to {OUTPUT_PATH}")

if __name__ == "__main__":
    main()
