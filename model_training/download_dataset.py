from roboflow import Roboflow
import os

# Create dataset directory if it doesn't exist
os.makedirs('model_training/dataset', exist_ok=True)
os.chdir('model_training/dataset')

rf = Roboflow(api_key="B5hzyD1CNVaEDwu9FCZO")
project = rf.workspace("yeeun-kim-fyvoj").project("pothole-vhmow")
version = project.version(18)
dataset = version.download("yolov8")
