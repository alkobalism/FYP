from ultralytics import YOLO
import os

def main():
    # Load a model
    model = YOLO("yolov8n.pt")  

    # Use script directory to locate dataset
    script_dir = os.path.dirname(os.path.abspath(__file__))
    dataset_dir = os.path.join(script_dir, 'dataset')
    
    # Roboflow downloads to a subdirectory, let's find it
    data_yaml_path = None
    for root, dirs, files in os.walk(dataset_dir):
        if 'data.yaml' in files:
            data_yaml_path = os.path.join(root, 'data.yaml')
            break
            
    if not data_yaml_path:
        print("Error: data.yaml not found in dataset directory!")
        return

    print(f"Training using dataset config: {data_yaml_path}")

    # Train the model with a smaller image size (320x320 instead of 640x640)
    # This means the model processes 4x fewer pixels, massively speeding up your mobile app.
    results = model.train(data=data_yaml_path, epochs=50, imgsz=320, plots=True)
    
    # Export the model to TFLite format with INT8 Quantization
    # INT8 shrinks the model size by ~4x, lowers RAM usage, and drastically speeds up CPU execution.
    success = model.export(format="tflite", int8=True, data=data_yaml_path, imgsz=320)
    print(f"Model exported: {success}")

if __name__ == '__main__':
    main()
