import streamlit as st
from ultralytics import YOLO
from PIL import Image
import numpy as np

# Page configuration
st.set_page_config(
    page_title="Pothole Detection AI",
    page_icon="🛴",
    layout="wide"
)

# Custom CSS for modern styling
st.markdown("""
<style>
    .main-header {
        font-size: 3rem;
        color: #ff4b4b;
        text-align: center;
        font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
        font-weight: 800;
        margin-bottom: 0px;
    }
    .sub-header {
        text-align: center;
        font-size: 1.2rem;
        color: #666;
        margin-bottom: 2rem;
    }
    .stImage {
        border-radius: 10px;
        box-shadow: 0 4px 8px rgba(0,0,0,0.1);
    }
</style>
""", unsafe_allow_html=True)

# Application Header
st.markdown('<p class="main-header">Micro-Mobility Pothole Detection</p>', unsafe_allow_html=True)
st.markdown('<p class="sub-header">Upload an image</p>', unsafe_allow_html=True)

import os

@st.cache_resource
def load_model():
    # Dynamically resolve the path of best.pt relative to this script's directory
    script_dir = os.path.dirname(os.path.abspath(__file__))
    model_path = os.path.join(script_dir, "best.pt")
    return YOLO(model_path)

try:
    model = load_model()
    st.sidebar.success("✅ AI Model Loaded Successfully")
    st.sidebar.info("Model: YOLOv8 Small\n\nResolution: 320x320")
except Exception as e:
    st.sidebar.error("❌ Failed to load model. Check file path.")
    st.error(f"Error details: {e}")
    st.stop()

# --- File Uploader ---
st.markdown("### 1. Upload Test Image")
uploaded_file = st.file_uploader("Choose an image (JPG, PNG)", type=['jpg', 'jpeg', 'png'])

if uploaded_file is not None:
    # Read the image
    image = Image.open(uploaded_file).convert('RGB')
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.markdown("#### Original Image")
        st.image(image, use_container_width=True)
        
    with col2:
        st.markdown("#### AI Detection Results")
        
        # Add a spinner while computing
        with st.spinner("Analyzing road surface..."):
            # Run YOLO inference
            # We set imgsz=320 to match our training configuration
            results = model.predict(image, imgsz=320, conf=0.40)
            
            # Extract the annotated image (numpy array)
            annotated_img_array = results[0].plot()
            
            # Render the annotated image
            st.image(annotated_img_array, channels="BGR", use_container_width=True)
            
            # Count the potholes found
            pothole_count = len(results[0].boxes)
            
        # Display summary
        if pothole_count > 0:
            st.error(f"⚠️ {pothole_count} Pothole(s) Detected! High Risk for scooters.")
        else:
            st.success("✅ Clear road. No potholes detected.")
            
else:
    st.info("Please upload an image to begin the demonstration.")
