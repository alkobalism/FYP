from ultralytics import YOLO
import os

def main():
    # Use script directory to locate weights
    # Assuming standard structure: runs/detect/train2/weights/best.pt relative to project root
    # But let's be robust
    
    base_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(base_dir) # up one level from model_training/
    
    # Explicitly define the absolute paths based on the recent training run
    weights_path = r"D:\save\Uni\FYP\model_training\runs\detect\train2\weights\best.pt"
    data_yaml_path = r"D:\save\Uni\FYP\model_training\dataset\pothole-18\data.yaml"
    
    if not os.path.exists(weights_path):
         print(f"Error: Weights not found at {weights_path}")
         return
         
    print(f"Exporting model from: {weights_path}")
    
    model = YOLO(weights_path)
    
    # TFLite export with INT8 quantization and smaller image size
    if os.path.exists(data_yaml_path):
        success = model.export(format="tflite", int8=True, data=data_yaml_path, imgsz=320)
    else:
        print(f"Warning: {data_yaml_path} not found. Exporting to standard Float32 TFLite without INT8.")
        success = model.export(format="tflite", imgsz=320)
    print(f"Export Success: {success}")

if __name__ == '__main__':
    main()
