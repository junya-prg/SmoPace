#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
from PIL import Image, ImageDraw, ImageFont

BASE_DIR = "/Users/hondajunya/00_work/94_自作/SmoPace"
PROCESSED_DIR = os.path.join(BASE_DIR, "screenshots/processed")
OUTPUT_PATH = os.path.join(BASE_DIR, "screenshots/processed_grid_view.png")

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
    files = [
        "processed_01_home.png",
        "processed_02_statistics.png",
        "processed_03_heatmap.png",
        "processed_04_ainews.png",
        "processed_05_relax.png",
        "processed_06_widget.png"
    ]
    
    thumb_w = 220
    thumb_h = 476
    gap = 15
    
    # 2 rows (Row 1: JA, Row 2: EN)
    grid_w = thumb_w * 6 + gap * 7
    grid_h = thumb_h * 2 + gap * 3
    
    grid_img = Image.new("RGB", (grid_w, grid_h), (20, 20, 25))
    draw = ImageDraw.Draw(grid_img)
    font = get_japanese_font(18)
    
    for row_idx, lang in enumerate(["ja", "en"]):
        lang_dir = os.path.join(PROCESSED_DIR, lang)
        for col_idx, filename in enumerate(files):
            x = gap + col_idx * (thumb_w + gap)
            y = gap + row_idx * (thumb_h + gap)
            
            img_path = os.path.join(lang_dir, filename)
            if os.path.exists(img_path):
                with Image.open(img_path) as img:
                    thumb = img.resize((thumb_w, thumb_h), Image.Resampling.LANCZOS)
                    grid_img.paste(thumb, (x, y))
                    
                    # Label
                    label = f"{lang.upper()} - P{col_idx+1:02d}"
                    draw.rectangle([x, y, x + 90, y + 25], fill=(0, 0, 0, 180))
                    draw.text((x + 8, y + 3), label, fill=(255, 255, 255), font=font)
            else:
                print(f"File not found: {img_path}")
                
    grid_img.save(OUTPUT_PATH)
    print(f"Multi-language grid view saved to {OUTPUT_PATH}")

if __name__ == "__main__":
    main()
