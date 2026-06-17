import wave, struct, math
import os

sampleRate = 44100.0
duration = 0.5 # 0.5 seconds
frequency = 1500.0 # 1500Hz (High-pitched warning beep)

os.makedirs(r"d:\save\Uni\FYP\mobile_app\assets\audio", exist_ok=True)
wavef = wave.open(r"d:\save\Uni\FYP\mobile_app\assets\audio\beep.wav", 'w')
wavef.setnchannels(1) # mono
wavef.setsampwidth(2) 
wavef.setframerate(sampleRate)

for i in range(int(duration * sampleRate)):
    value = int(32767.0 * math.sin(frequency * 2.0 * math.pi * float(i) / float(sampleRate)))
    data = struct.pack('<h', value)
    wavef.writeframesraw(data)
wavef.close()
print("Beep generated successfully.")
