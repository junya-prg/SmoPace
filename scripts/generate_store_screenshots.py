#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys

# Ensure Pillow is available
try:
    from PIL import Image, ImageDraw, ImageFont, ImageFilter
except ImportError:
    print("Pillow (PIL) is not installed. Installing it now...")
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "pillow"])
    from PIL import Image, ImageDraw, ImageFont, ImageFilter

# Define paths
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INPUT_DIR = os.path.join(BASE_DIR, "スクショ/20260412")
OUTPUT_DIR = os.path.join(BASE_DIR, "screenshots/processed")

# Base configurations common for both languages
BASE_CONFIGS = [
    {
        "id": "01_home",
        "input": "Simulator Screenshot - iPhone 17 Pro Max - 2026-04-12 at 22.12.22.png",
        "title_ja": "今日の喫煙をスマートに記録",
        "subtitle_ja": "ワンタップで記録し、喫煙ペースをリアルタイムで可視化",
        "title_en": "Track Smoking Smartly",
        "subtitle_en": "Log with a single tap and visualize\nyour smoking pace in real-time",
        "grad_start": (15, 23, 42),    # Midnight Indigo
        "grad_end": (49, 16, 66),      # Deep Violet
        "rotate": -5
    },
    {
        "id": "02_statistics",
        "input": "Simulator Screenshot - iPhone 17 Pro Max - 2026-04-12 at 22.12.53.png",
        "title_ja": "統計データで進捗を分析",
        "subtitle_ja": "日・週・月ごとの推移を美しいグラフと数値で把握",
        "title_en": "Analyze Your Progress",
        "subtitle_en": "Track daily, weekly, and monthly trends\nwith beautiful charts and analytics",
        "grad_start": (2, 44, 34),      # Deep Aurora Forest
        "grad_end": (15, 118, 110),    # Aurora Teal
        "rotate": 5
    },
    {
        "id": "03_heatmap",
        "input": "0x0ss.png",
        "title_ja": "カレンダーで傾向を可視化",
        "subtitle_ja": "日々の喫煙本数を色とサイズで直感的に把握",
        "title_en": "Visualize Daily Trends",
        "subtitle_en": "Grasp your smoking patterns at a glance\nwith calendar-based color mapping",
        "grad_start": (15, 15, 38),     # Midnight Sapphire
        "grad_end": (76, 29, 107),     # Plum Amethyst
        "rotate": -5
    },
    {
        "id": "04_ainews",
        "input": "Simulator Screenshot - iPhone 17 Pro Max - 2026-04-12 at 22.16.00.png",
        "title_ja": "AIが最新ニュースを収集・要約",
        "subtitle_ja": "クリアな呼吸に役立つニュースやAI豆知識、\n既読数で成長する「苗木」で楽しく健康管理",
        "title_en": "AI-Curated News & Tips",
        "subtitle_en": "Discover AI tips & personalized updates,\nand watch your Pace Sprout grow as you read",
        "grad_start": (15, 23, 42),    # Deep Sapphire
        "grad_end": (30, 27, 75),      # Indigo Night
        "rotate": 5
    },
    {
        "id": "05_relax",
        "input": "Simulator Screenshot - iPhone 17 Pro Max - 2026-04-12 at 22.13.12.png",
        "title_ja": "吸いたくなったらリラックス",
        "subtitle_ja": "たき火の炎と呼吸を合わせ\n喫煙欲求をスマートにコントロール",
        "title_en": "Relax When Cravings Hit",
        "subtitle_en": "Control your smoking urges by matching\nyour breathing with bonfire flames",
        "grad_start": (11, 11, 30),     # Starry Cosmic Navy
        "grad_end": (46, 16, 101),     # Purple Nebula
        "rotate": 0
    },
    {
        "id": "06_widget",
        "input": "Simulator Screenshot - iPhone 17 Pro Max - 2026-04-12 at 22.15.45.png",
        "title_ja": "ホーム画面からワンタップ記録",
        "subtitle_ja": "iOSウィジェットに対応し、今日の進捗を一目で確認",
        "title_en": "One-Tap Home Screen Log",
        "subtitle_en": "Easily record and check today's progress\nwith our iOS Home Screen Widget",
        "grad_start": (24, 8, 40),      # Deep Sunset Plum
        "grad_end": (131, 24, 67),     # Ember Ruby
        "rotate": 5
    }
]

# Canvas properties (App Store 6.7" specifications)
CANVAS_WIDTH = 1290
CANVAS_HEIGHT = 2796

def get_system_font(size):
    """Finds a beautiful system font on macOS."""
    font_paths = [
        "/System/Library/Fonts/PingFang.ttc",  # standard macOS CJK font
        "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc",
        "/System/Library/Fonts/ヒラギノ角ゴシック W4.ttc",
        "/System/Library/Fonts/Hiragino Sans GB.ttc",
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
    """Creates a beautiful diagonal gradient."""
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
    """Draws a premium iPhone bezel frame and inserts the screenshot."""
    phone_w = 820
    phone_h = 1770
    
    phone = Image.new("RGBA", (phone_w, phone_h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(phone)
    
    # 1. Outer sleek metallic bezel (Titanium Gray)
    draw.rounded_rectangle([0, 0, phone_w, phone_h], radius=118, fill=(24, 28, 36))
    
    # 2. Inner screen frame bezel
    draw.rounded_rectangle([6, 6, phone_w - 6, phone_h - 6], radius=112, fill=(8, 10, 15))
    
    # 3. Process the app screenshot
    screen_w = 780
    screen_h = 1730
    screen_x = 20
    screen_y = 20
    
    screen_mask = Image.new("L", (screen_w, screen_h), 0)
    mask_draw = ImageDraw.Draw(screen_mask)
    mask_draw.rounded_rectangle([0, 0, screen_w, screen_h], radius=92, fill=255)
    
    try:
        screenshot = Image.open(screenshot_path).convert("RGBA")
        screenshot = screenshot.resize((screen_w, screen_h), Image.Resampling.LANCZOS)
        phone.paste(screenshot, (screen_x, screen_y), mask=screen_mask)
    except Exception as e:
        print(f"Error loading screenshot {screenshot_path}: {e}")
        draw.rounded_rectangle([screen_x, screen_y, screen_x + screen_w, screen_y + screen_h], radius=92, fill=(15, 23, 42))
        
    # 4. Draw Dynamic Island
    island_w = 280
    island_h = 76
    island_x = (phone_w - island_w) // 2
    island_y = 35
    draw.rounded_rectangle([island_x, island_y, island_x + island_w, island_y + island_h], radius=38, fill=(0, 0, 0))
    
    # Camera gloss
    lens_x = island_x + island_w - 50
    lens_y = island_y + 26
    draw.ellipse([lens_x, lens_y, lens_x + 24, lens_y + 24], fill=(10, 12, 18))
    draw.ellipse([lens_x + 6, lens_y + 6, lens_x + 14, lens_y + 14], fill=(15, 25, 45))

    return phone

def add_drop_shadow(rotated_img):
    """Generates a fluffy ambient drop shadow below the rotated iPhone."""
    w, h = rotated_img.size
    shadow_base = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    alpha = rotated_img.split()[3]
    
    shadow_base.paste((0, 0, 0, 200), (0, 0), mask=alpha)
    shadow = shadow_base.filter(ImageFilter.GaussianBlur(32))
    
    shadow_base_sharp = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    shadow_base_sharp.paste((0, 0, 0, 120), (0, 0), mask=alpha)
    shadow_sharp = shadow_base_sharp.filter(ImageFilter.GaussianBlur(10))
    
    return Image.alpha_composite(shadow, shadow_sharp)

def draw_centered_text_with_shadow(draw, text, x_center, y, font, fill_color=(255, 255, 255), shadow_color=(0, 0, 0, 120), shadow_offset=(2, 2)):
    """Helper to draw beautifully centered text with drop shadow."""
    bbox = draw.textbbox((0, 0), text, font=font)
    text_w = bbox[2] - bbox[0]
    x = x_center - (text_w // 2)
    
    if shadow_color:
        draw.text((x + shadow_offset[0], y + shadow_offset[1]), text, fill=shadow_color, font=font)
    draw.text((x, y), text, fill=fill_color, font=font)

def render_screenshot(config, lang):
    """Executes the full rendering pipeline for a single App Store screenshot in specified language."""
    title = config["title_ja"] if lang == "ja" else config["title_en"]
    subtitle = config["subtitle_ja"] if lang == "ja" else config["subtitle_en"]
    
    output_filename = f"processed_{config['id']}.png"
    lang_dir = os.path.join(OUTPUT_DIR, lang)
    os.makedirs(lang_dir, exist_ok=True)
    
    input_path = os.path.join(INPUT_DIR, config["input"])
    output_path = os.path.join(lang_dir, output_filename)
    
    if not os.path.exists(input_path):
        print(f"Error: Base screenshot '{config['input']}' not found in input directory: {INPUT_DIR}")
        return False
        
    # 1. Create Stunning Gradient Background
    bg = create_gradient_background(CANVAS_WIDTH, CANVAS_HEIGHT, config["grad_start"], config["grad_end"])
    
    # 2. Overlay Ambient App Blur Glow (Blur BG)
    try:
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
    except Exception as e:
        print(f"Warning: Could not create background blur effect: {e}")
        bg = bg.convert("RGBA")
        
    # 3. Create iPhone Mockup
    phone = create_iphone_mockup(input_path)
    
    # 4. Scale up the mockup slightly if it's a straight front-facing mock
    if config["rotate"] == 0:
        phone_w, phone_h = phone.size
        phone = phone.resize((int(phone_w * 1.05), int(phone_h * 1.05)), Image.Resampling.LANCZOS)
    
    # 5. Apply 3D-like Rotation and Multi-Stage Shadow
    rotated_phone = phone.rotate(config["rotate"], expand=True, resample=Image.Resampling.BICUBIC)
    shadow = add_drop_shadow(rotated_phone)
    
    # Calculate perfect positioning on Canvas (Shifted upwards to reduce text-to-device gap!)
    phone_w, phone_h = rotated_phone.size
    
    # SIGNIFICANTLY REDUCED SPACE: target_y shifted from 920/960 to 760/800
    target_y = 800 if config["rotate"] == 0 else 760
    target_x = (CANVAS_WIDTH - phone_w) // 2
    
    shadow_shift_x = int(-15 if config["rotate"] > 0 else (0 if config["rotate"] == 0 else 15))
    shadow_shift_y = 45
    
    bg.paste(shadow, (target_x + shadow_shift_x, target_y + shadow_shift_y), mask=shadow)
    bg.paste(rotated_phone, (target_x, target_y), mask=rotated_phone)
    
    # 6. Render Copy Typography (Title & Subtitle)
    draw = ImageDraw.Draw(bg)
    
    title_font = get_system_font(82)
    subtitle_font = get_system_font(42)
    
    text_y = 230
    
    # Draw Title
    draw_centered_text_with_shadow(draw, title, CANVAS_WIDTH // 2, text_y, title_font, fill_color=(255, 255, 255))
    
    # Draw Subtitle (Handles manual newline characters)
    subtitle_lines = subtitle.split("\n")
    sub_y = text_y + 130
    
    for idx, line in enumerate(subtitle_lines):
        line_offset_y = sub_y + (idx * 60)
        draw_centered_text_with_shadow(
            draw, 
            line, 
            CANVAS_WIDTH // 2, 
            line_offset_y, 
            subtitle_font, 
            fill_color=(226, 232, 240), 
            shadow_color=(0, 0, 0, 100),
            shadow_offset=(1, 1)
        )
    
    # 7. Save Completed App Store Screenshot
    bg = bg.convert("RGB")
    bg.save(output_path, "PNG", quality=100)
    print(f"[{lang.upper()}] Successfully generated: {output_path}")
    return True

def main():
    print("=" * 60)
    print("  SmoPace App Store Screenshot Suite - Auto Generator")
    print("  Languages: Japanese (ja) & English (en)")
    print("  Target: iPhone 17 Pro Max Resolution (1290x2796 px)")
    print("=" * 60)
    
    for lang in ["ja", "en"]:
        print(f"\n--- Starting generation for language: {lang.upper()} ---")
        success_count = 0
        for config in BASE_CONFIGS:
            if render_screenshot(config, lang):
                success_count += 1
        print(f"[{lang.upper()}] Complete! {success_count}/{len(BASE_CONFIGS)} screenshots created.")
        
    print("\n" + "=" * 60)
    print(f"  All generation tasks finished successfully!")
    print(f"  Saved in: {OUTPUT_DIR}")
    print("=" * 60)

if __name__ == "__main__":
    main()
