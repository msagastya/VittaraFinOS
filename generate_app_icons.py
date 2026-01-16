import os
from PIL import Image, ImageDraw

def create_icon(size, output_path):
    # Professional Fintech Design
    # Background: Clean White
    bg_color = (255, 255, 255, 255)
    image = Image.new("RGBA", (size, size), bg_color)
    draw = ImageDraw.Draw(image)

    # Scale factors
    s = size / 100.0
    
    # Palette
    # Deep Blue (Trust/Finance): #1565C0
    # Vibrant Teal (Growth/Tech): #00BFA5
    color_left = "#1565C0"
    color_right = "#00BFA5"

    # Geometric "V" Logo Construction
    # We will draw two thick, angled rounded rectangles (capsules) that meet at the bottom.
    
    # Coordinates based on 100x100 grid
    # Center bottom point: 50, 85
    # Top left point: 25, 25
    # Top right point: 75, 25
    # Thickness: 18
    
    width = 18 * s
    
    # Left Wing (Blue) - Drawn first (behind)
    # Line from (30, 25) to (50, 75) roughly
    draw.line([(30 * s, 25 * s), (50 * s, 75 * s)], fill=color_left, width=int(width))
    # Round caps for Left Wing
    draw.ellipse([(30 * s - width/2, 25 * s - width/2), (30 * s + width/2, 25 * s + width/2)], fill=color_left)
    draw.ellipse([(50 * s - width/2, 75 * s - width/2), (50 * s + width/2, 75 * s + width/2)], fill=color_left)

    # Right Wing (Teal) - Drawn second (overlapping/front) to create depth
    # Line from (50, 75) to (70, 25)
    # Slight offset to make them look interlocked or just clean junction
    draw.line([(50 * s, 75 * s), (70 * s, 25 * s)], fill=color_right, width=int(width))
    # Round caps for Right Wing
    draw.ellipse([(70 * s - width/2, 25 * s - width/2), (70 * s + width/2, 25 * s + width/2)], fill=color_right)
    # Bottom cap (shared visual anchor, drawn in teal to merge)
    draw.ellipse([(50 * s - width/2, 75 * s - width/2), (50 * s + width/2, 75 * s + width/2)], fill=color_right)

    # Add a small "Profit Dot" or accent to balance it? 
    # Professional usually means minimal. Let's keep it just the strong V.
    # Maybe a subtle circle in the top right to imply "notification" or "status"?
    # No, keep it clean for the main icon.

    # Ensure directory exists
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    image.save(output_path)
    print(f"Generated {output_path}")

# Android Mipmap sizes
android_sizes = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192
}

base_dir = 'finance_app/android/app/src/main/res'

for folder, size in android_sizes.items():
    create_icon(size, f"{base_dir}/{folder}/ic_launcher.png")
    create_icon(size, f"{base_dir}/{folder}/ic_launcher_round.png")

print("Icon generation complete.")