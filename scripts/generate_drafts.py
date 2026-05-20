#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter

BASE_DIR = "/Users/hondajunya/00_work/94_自作/SmoPace"
IMG_DIR = os.path.join(BASE_DIR, "スクショ/20260412")
DRAFT_DIR = os.path.join(BASE_DIR, "screenshots/processed_draft")

os.makedirs(DRAFT_DIR, exist_ok=True)

CANVAS_WIDTH = 1290
CANVAS_HEIGHT = 2796

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

def create_gradient_background(width, height, color1, color2):
    small_w, small_h = 64, 128
    base = Image.new("RGB", (small_w, small_h))
    draw = ImageDraw.Draw(base)
    for y in range(small_h):
        for x in range(small_w):
            factor = (x / small_w + y / small_h) / 2.0
            r = int(color1[0] + (color2[0] - color1[0]) * factor)
            g = int(color1[1] + (color2[1] - color1[1]) * factor)
            b = int(color1[2] + (color2[2] - color1[2]) * factor)
            draw.point((x, y), fill=(r, g, b))
    return base.resize((width, height), Image.Resampling.BILINEAR)

def create_iphone_mockup(screenshot_path):
    phone_w = 820
    phone_h = 1770
    phone = Image.new("RGBA", (phone_w, phone_h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(phone)
    draw.rounded_rectangle([0, 0, phone_w, phone_h], radius=118, fill=(24, 28, 36))
    draw.rounded_rectangle([6, 6, phone_w - 6, phone_h - 6], radius=112, fill=(8, 10, 15))
    
    screen_w = 780
    screen_h = 1730
    screen_x = 20
    screen_y = 20
    
    screen_mask = Image.new("L", (screen_w, screen_h), 0)
    mask_draw = ImageDraw.Draw(screen_mask)
    mask_draw.rounded_rectangle([0, 0, screen_w, screen_h], radius=92, fill=255)
    
    screenshot = Image.open(screenshot_path).convert("RGBA")
    screenshot = screenshot.resize((screen_w, screen_h), Image.Resampling.LANCZOS)
    phone.paste(screenshot, (screen_x, screen_y), mask=screen_mask)
    
    island_w = 280
    island_h = 76
    island_x = (phone_w - island_w) // 2
    island_y = 35
    draw.rounded_rectangle([island_x, island_y, island_x + island_w, island_y + island_h], radius=38, fill=(0, 0, 0))
    return phone

def add_drop_shadow(rotated_img):
    w, h = rotated_img.size
    shadow_base = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    alpha = rotated_img.split()[3]
    shadow_base.paste((0, 0, 0, 200), (0, 0), mask=alpha)
    shadow = shadow_base.filter(ImageFilter.GaussianBlur(32))
    return shadow

def render_draft(filename, index):
    input_path = os.path.join(IMG_DIR, filename)
    output_path = os.path.join(DRAFT_DIR, f"draft_{index:02d}.png")
    
    # Simple default colors
    c1, c2 = (15, 23, 42), (49, 16, 66)
    bg = create_gradient_background(CANVAS_WIDTH, CANVAS_HEIGHT, c1, c2)
    
    # Overlay screenshot blur
    orig_img = Image.open(input_path).convert("RGBA")
    glow_size = int(CANVAS_WIDTH * 2.2)
    glow_img = orig_img.resize((glow_size, int(orig_img.height * (glow_size / orig_img.width))), Image.Resampling.BILINEAR)
    glow_img = glow_img.filter(ImageFilter.GaussianBlur(90))
    glow_crop = glow_img.crop((
        (glow_img.width - CANVAS_WIDTH) // 2,
        (glow_img.height - CANVAS_HEIGHT) // 2,
        (glow_img.width - CANVAS_WIDTH) // 2 + CANVAS_WIDTH,
        (glow_img.height - CANVAS_HEIGHT) // 2 + CANVAS_HEIGHT
    ))
    glow_layer = Image.new("RGBA", (CANVAS_WIDTH, CANVAS_HEIGHT))
    glow_layer.paste(glow_crop, (0, 0))
    glow_alpha = glow_layer.split()[3].point(lambda x: int(x * 0.35))
    glow_layer.putalpha(glow_alpha)
    bg = Image.alpha_composite(bg.convert("RGBA"), glow_layer)
    
    # Phone
    phone = create_iphone_mockup(input_path)
    rotated_phone = phone.rotate(-5, expand=True, resample=Image.Resampling.BICUBIC)
    shadow = add_drop_shadow(rotated_phone)
    
    phone_w, phone_h = rotated_phone.size
    target_y = 920
    target_x = (CANVAS_WIDTH - phone_w) // 2
    
    bg.paste(shadow, (target_x + 15, target_y + 45), mask=shadow)
    bg.paste(rotated_phone, (target_x, target_y), mask=rotated_phone)
    
    # Draw simple identifier text
    draw = ImageDraw.Draw(bg)
    font = get_japanese_font(120)
    title_text = f"Draft {index:02d}"
    bbox = draw.textbbox((0, 0), title_text, font=font)
    title_w = bbox[2] - bbox[0]
    draw.text(((CANVAS_WIDTH - title_w) // 2, 300), title_text, fill=(255, 255, 255), font=font)
    
    # Draw subtext with original filename for easy referencing
    sub_font = get_japanese_font(36)
    sub_text = filename[:50]
    sub_bbox = draw.textbbox((0, 0), sub_text, font=sub_font)
    sub_w = sub_bbox[2] - sub_bbox[0]
    draw.text(((CANVAS_WIDTH - sub_w) // 2, 450), sub_text, fill=(200, 200, 200), font=sub_font)
    
    bg.convert("RGB").save(output_path, "PNG")
    print(f"Generated: {output_path}")

def main():
    files = [f for f in os.listdir(IMG_DIR) if f.startswith("Simulator Screenshot - iPhone 17 Pro Max")]
    files.sort()
    for idx, f in enumerate(files, 1):
        render_draft(f, idx)

if __name__ == "__main__":
    main()
