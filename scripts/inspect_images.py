#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
from PIL import Image

BASE_DIR = "/Users/hondajunya/00_work/94_自作/SmoPace"
IMG_DIR = os.path.join(BASE_DIR, "スクショ/20260412")

def inspect_image(filename):
    path = os.path.join(IMG_DIR, filename)
    try:
        with Image.open(path) as img:
            w, h = img.size
            # Get some key color spots to classify
            # We convert to RGB to analyze
            rgb_img = img.convert("RGB")
            
            # Sample center color
            center_color = rgb_img.getpixel((w // 2, h // 2))
            # Sample top color (header area)
            top_color = rgb_img.getpixel((w // 2, h // 10))
            # Sample bottom color (tabbar area)
            bottom_color = rgb_img.getpixel((w // 2, h - 50))
            
            print(f"File: {filename} ({w}x{h})")
            print(f"  Center color: {center_color}")
            print(f"  Top color: {top_color}")
            print(f"  Bottom color: {bottom_color}")
            
    except Exception as e:
        print(f"Error inspecting {filename}: {e}")

def main():
    files = [f for f in os.listdir(IMG_DIR) if f.startswith("Simulator Screenshot - iPhone 17 Pro Max")]
    files.sort()
    for f in files:
        inspect_image(f)

if __name__ == "__main__":
    main()
