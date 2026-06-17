from ultralytics import YOLO
import os

def main():
    # Load YOLOv8 Medium (High Accuracy)
    print("Initializing YOLOv8 Medium model...")
    model = YOLO("yolov8m.pt")  

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

    print(f"Training YOLOv8 Medium using dataset: {data_yaml_path}")

    # Train for 50 epochs with imgsz=320
    results = model.train(data=data_yaml_path, epochs=50, imgsz=320, plots=True)
    
    # Export to TFLite format with INT8 quantization
    print("Exporting trained Medium model to INT8 TFLite...")
    success = model.export(format="tflite", int8=True, data=data_yaml_path, imgsz=320)
    print(f"Export Success: {success}")

if __name__ == '__main__':
    main()
