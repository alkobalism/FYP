import os
import requests

def download_background_images():
    # Target directory for training images
    script_dir = os.path.dirname(os.path.abspath(__file__))
    target_dir = os.path.join(script_dir, 'dataset', 'pothole-18', 'train', 'images')

    if not os.path.exists(target_dir):
        print(f"Error: Target directory does not exist: {target_dir}")
        return

    # High quality Unsplash images of non-potholes (handbags, backpacks, clean road, floor tiles, shoes, clothing)
    background_urls = [
        # Handbags, Purses, Leather Bags (20 images)
        "https://images.unsplash.com/photo-1584917865442-de89df76afd3?w=600&auto=format&fit=crop&q=80",
        "https://images.unsplash.com/photo-1590874103328-eac38a683ce7?w=600&auto=format&fit=crop&q=80",
        "https://images.unsplash.com/photo-1515562141207-7a88fb7ce338?w=600&auto=format&fit=crop&q=80",
        "https://images.unsplash.com/photo-1544816155-12df9643f363?w=600&auto=format&fit=crop&q=80",
        "https://images.unsplash.com/photo-1566150905458-1bf1fc113f0d?w=600&auto=format&fit=crop&q=80",
        "https://images.unsplash.com/photo-1594223274512-ad4803739b7c?w=600&auto=format&fit=crop&q=80",
        "https://images.unsplash.com/photo-1522335789203-aabd1fc54bc9?w=600&auto=format&fit=crop&q=80",
        "https://images.unsplash.com/photo-1600857544200-b2f666a9a2ec?w=600&auto=format&fit=crop&q=80",
        "https://images.unsplash.com/photo-1548036328-c9fa89d128fa?w=600&auto=format&fit=crop&q=80",
        "https://images.unsplash.com/photo-1575032617751-6dface00b8b2?w=600&auto=format&fit=crop&q=80",
        "https://images.unsplash.com/photo-1563903530908-afdd15a2f7e5?w=600&auto=format&fit=crop&q=80",
        "https://images.unsplash.com/photo-1591561954557-26941169b49e?w=600&auto=format&fit=crop&q=80",
        "https://images.unsplash.com/photo-1605100804763-247f67b3557e?w=600&auto=format&fit=crop&q=80",
        "https://images.unsplash.com/photo-1598532163257-ae3c6b2524b6?w=600&auto=format&fit=crop&q=80",

        # Backpacks & Luggage (10 images)
        "https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=600&auto=format&fit=crop&q=80",
        "https://images.unsplash.com/photo-1622560480605-d83c853bc5c3?w=600&auto=format&fit=crop&q=80",
        "https://images.unsplash.com/photo-1577733966973-d680bffd2e80?w=600&auto=format&fit=crop&q=80",
        "https://images.unsplash.com/photo-1581605405669-fcdf81165afa?w=600&auto=format&fit=crop&q=80",
        "https://images.unsplash.com/photo-1546938576-6e6a64f317cc?w=600&auto=format&fit=crop&q=80",

        # Clean Asphalt & Smooth Road Surfaces (10 images)
        "https://images.unsplash.com/photo-1519817650390-64a93db51149?w=600&auto=format&fit=crop&q=80",
        "https://images.unsplash.com/photo-1506521781263-d8422e82f27a?w=600&auto=format&fit=crop&q=80",
        "https://images.unsplash.com/photo-1494522855154-9297ac14b55f?w=600&auto=format&fit=crop&q=80",
        "https://images.unsplash.com/photo-1509316975850-ff9c5deb0cd9?w=600&auto=format&fit=crop&q=80",

        # Indoor Floor Tiles & Carpets (10 images)
        "https://images.unsplash.com/photo-1581858726788-75bc0f6a952d?w=600&auto=format&fit=crop&q=80",
        "https://images.unsplash.com/photo-1513694203232-719a280e022f?w=600&auto=format&fit=crop&q=80",
        "https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=600&auto=format&fit=crop&q=80",
        "https://images.unsplash.com/photo-1560185127-6ed189bf02f4?w=600&auto=format&fit=crop&q=80",
        "https://images.unsplash.com/photo-1618221195710-dd6b41faaea6?w=600&auto=format&fit=crop&q=80",

        # Shoes & Shadow Textures (10 images)
        "https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=600&auto=format&fit=crop&q=80",
        "https://images.unsplash.com/photo-1525966222134-fcfa99b8ae77?w=600&auto=format&fit=crop&q=80",
        "https://images.unsplash.com/photo-1608231387042-66d1773070a5?w=600&auto=format&fit=crop&q=80",
        "https://images.unsplash.com/photo-1595950653106-6c9ebd614d3a?w=600&auto=format&fit=crop&q=80",
        "https://images.unsplash.com/photo-1560769629-975ec94e6a86?w=600&auto=format&fit=crop&q=80",
    ]

    print(f"Downloading background negative sample images into dataset...")
    headers = {"User-Agent": "Mozilla/5.0"}
    success_count = 0

    for i, url in enumerate(background_urls):
        file_path = os.path.join(target_dir, f"bg_negative_{i+1:02d}.jpg")
        try:
            res = requests.get(url, headers=headers, timeout=10)
            if res.status_code == 200:
                with open(file_path, 'wb') as f:
                    f.write(res.content)
                success_count += 1
                print(f"  [OK] Downloaded: bg_negative_{i+1:02d}.jpg")
            else:
                print(f"  [x] Failed ({res.status_code}): {url}")
        except Exception as e:
            print(f"  [x] Error downloading image {i+1}: {e}")

    print(f"\nCompleted! Successfully saved {success_count} negative sample images into {target_dir}")

if __name__ == '__main__':
    download_background_images()
