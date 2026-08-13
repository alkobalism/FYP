from ultralytics import YOLO
import os

def main():
    # Load YOLOv8 Nano (Lightweight)
    print("Initializing YOLOv8 Nano model...")
    model = YOLO("yolov8n.pt")  

    # Locate dataset config
    script_dir = os.path.dirname(os.path.abspath(__file__))
    dataset_dir = os.path.join(script_dir, 'dataset')
    
    data_yaml_path = None
    for root, dirs, files in os.walk(dataset_dir):
        if 'data.yaml' in files:
            data_yaml_path = os.path.join(root, 'data.yaml')
            break
            
    if not data_yaml_path:
        print("Error: data.yaml not found in dataset directory!")
        return

    print(f"Training YOLOv8 Nano using dataset: {data_yaml_path}")

    # Train for 60 epochs with imgsz=416 and augmentations
    results = model.train(
        data=data_yaml_path,
        epochs=60,
        imgsz=416,
        batch=16,
        hsv_h=0.015,
        hsv_s=0.7,
        hsv_v=0.4,
        degrees=10.0,
        translate=0.1,
        scale=0.5,
        shear=2.0,
        perspective=0.0005,
        mosaic=1.0,
        plots=True
    )
    
    # Export to TFLite format with INT8 quantization
    print("Exporting trained Nano model to INT8 TFLite...")
    success = model.export(format="tflite", int8=True, data=data_yaml_path, imgsz=416)
    print(f"Export Success: {success}")

if __name__ == '__main__':
    main()
