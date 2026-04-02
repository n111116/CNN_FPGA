# 使用USB进行调试，写入数据并查看FPGA回写的数据
import usb.core
import os
import time
from datetime import datetime
import numpy as np
import scipy.io
import cv2
import struct
from CnnHardwareGenerator import layer0 as layer_to_test

# ================= 配置参数 =================
OUTPUT_DIR = "usb_data"
SEND_FRAMES = 10       # 发送帧数

# USB 传输参数
READ_BUFFER_SIZE = 1024 * 64 
USB_WRITE_TIMEOUT = 1000 # ms
USB_READ_TIMEOUT = 1    # ms

# 可视化配置
CONF_THRESHOLD = 1      # 置信度阈值 (根据硬件实际输出调整)
SHOW_SCALE = 1.0        # 显示缩放倍数
GRID_STRIDE = 16        # 网络下采样步长

# [关键修改] 数据包结构参数
# 假设硬件回传 1 Header + 4 个值(每个值4字节) = 68 Bytes
PACKET_SIZE = 4 + 32 * 4 

# ================= 辅助函数 =================
def parse_16bit_signed(byte1, byte0):
    """
    解析大端序 16位 有符号整数
    b1: 高8位, b0: 低8位
    """
    raw_val = (byte1 << 8) | byte0
    # 16位符号扩展
    if raw_val & 0x8000:
        val = raw_val - 0x10000
    else:
        val = raw_val
    return val

# ================= 0. 从脚本提取硬件参数 =================
layer_to_test.load_mat_data()

IMG_COL = layer_to_test.img_col
IMG_ROW = layer_to_test.img_row
CHANNELS = layer_to_test.cycle_period_cin * layer_to_test.pe_page_num

# ================= 1. 环境与文件准备 =================
if not os.path.exists(OUTPUT_DIR):
    os.makedirs(OUTPUT_DIR)

timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
output_filename = f"{timestamp}—{SEND_FRAMES}frames.hex"
output_filepath = os.path.join(OUTPUT_DIR, output_filename)

# ---------------------------------------------------
# A. 读取 MAT 文件构建发送数据
# ---------------------------------------------------
raw_data = []
MAT_FILE_PATH = layer_to_test.layer_mat_file

print(f"Reading input data from MAT file: {MAT_FILE_PATH}...")
if not os.path.exists(MAT_FILE_PATH):
    raise FileNotFoundError(f"File not found: {MAT_FILE_PATH}")

mat_data = scipy.io.loadmat(MAT_FILE_PATH)
input_data = mat_data["input"]  
shape = input_data.shape        
total_rows = shape[2]

# ---------------------------------------------------
# B. 从 MAT 数据中还原底图用于 OpenCV 可视化
# ---------------------------------------------------
img_array = input_data[0, :3, :, :]
if img_array.shape[0] == 1:
    img_array = np.repeat(img_array, 3, axis=0) # 单通道复制为三通道
img_array = np.transpose(img_array, (1, 2, 0))  # (Channels, H, W) -> (H, W, Channels)
img_rgb = np.clip(img_array, 0, 255).astype(np.uint8)
# OpenCV 默认使用 BGR 色彩空间进行 imshow
img_bgr = cv2.cvtColor(img_rgb, cv2.COLOR_RGB2BGR)

print(f"Total Rows per frame: {total_rows}")
out_file = open(output_filepath, 'w')

# ================= 2. USB 初始化 =================
dev = usb.core.find(idVendor=0x04b4, idProduct=0x00f1)
if dev is None:
    raise ValueError('Device not found')

dev.set_configuration()

try:
    while True:
        dev.read(0x81, 1024, timeout=10)
except usb.core.USBError:
    pass

# ================= 3. 发送与读取循环 =================
start_time = time.time()
total_read_bytes = 0
data_buffer = bytearray() # 用于暂存接收到的碎片数据

print(f"Starting transmission of {SEND_FRAMES} frames...")

for frame_idx in range(SEND_FRAMES):
    print(f"--- Sending Frame {frame_idx + 1} / {SEND_FRAMES} ---")
    
    # 获取干净的底图用于本帧可视化
    vis_img = img_bgr.copy()
    
    data_ptr = 0 
    for r in range(total_rows):
        # -------------------------------------------------
        # A. 构建当前行数据包 (使用 MAT 数据)
        # -------------------------------------------------
        row_payload = []
        row_payload.extend([0xFF, 0x00, 0x00, 0x00])
        
        for c in range(IMG_COL):
            for data_ptr in range(shape[1] // layer_to_test.pe_page_num):
                ch0 = input_data[0][data_ptr+0*layer_to_test.cycle_period_cin][r][c]      
                ch1 = input_data[0][data_ptr+1*layer_to_test.cycle_period_cin][r][c]      
                ch2 = input_data[0][data_ptr+2*layer_to_test.cycle_period_cin][r][c]      
                if layer_to_test.pe_page_num == 4:
                    ch3 = input_data[0][data_ptr+3*layer_to_test.cycle_period_cin][r][c]  
                    if ch3 >= 255:
                        ch3 = 254
                else: 
                    ch3 = 0
                row_payload.extend([ch3, ch2, ch1, ch0])

        # -------------------------------------------------
        # B. 发送数据
        # -------------------------------------------------
        try:
            dev.write(0x01, row_payload, timeout=USB_WRITE_TIMEOUT)
        except usb.core.USBError as e:
            print(f"Error sending frame {frame_idx+1} row {r}: {e}")
            break

        # -------------------------------------------------
        # C. 读取并解析返回的检测数据
        # -------------------------------------------------
        if r % 10 == 0:
            try:
                raw_read = dev.read(0x81, READ_BUFFER_SIZE, timeout=USB_READ_TIMEOUT)
                
                if len(raw_read) > 4:
                    raw_read = raw_read[:-4]

                total_read_bytes += len(raw_read)
                # 将新读到的数据追加到缓冲区
                data_buffer.extend(raw_read)
                
                # 只要缓冲区够一个完整包的大小，就进行解析
                while len(data_buffer) >= PACKET_SIZE:
                    # 取出一个完整包 (例如 68 Bytes)
                    packet = data_buffer[:PACKET_SIZE]
                    del data_buffer[:PACKET_SIZE] # 从缓冲区移除
                    
                    # --- 1. 解析 Header (前4字节) ---
                    header_bytes = packet[:4]
                    print(header_bytes)
                    cls    = header_bytes[0]   # b3
                    x_grid = header_bytes[1]   # b2
                    y_grid = header_bytes[2]   # b1
                    conf   = header_bytes[3]   # b0
                    
                    out_file.write(f"{cls:02x} {x_grid:02x} {y_grid:02x} {conf:02x}\n")
                    
                    # --- 2. 坐标转换 ---
                    cx = x_grid * GRID_STRIDE + GRID_STRIDE // 2
                    cy = y_grid * GRID_STRIDE + GRID_STRIDE // 2
                    # --- 3. 提取直接偏移值 ---
                    if conf >= CONF_THRESHOLD:
                        body_bytes = packet[4:]
                        
                        # 字节偏移 = 索引 * 4。b1在高位(偏移+2)，b0在低位(偏移+3)
                        
                        # 1st: 偏移 0
                        val_l = parse_16bit_signed(body_bytes[0*4 + 2] * 255, body_bytes[0*4 + 3])
                        # 5th: 偏移 4*4=16
                        val_t = parse_16bit_signed(body_bytes[1*4 + 2] * 255, body_bytes[1*4 + 3])
                        # 9th: 偏移 8*4=32
                        val_r = parse_16bit_signed(body_bytes[2*4 + 2] * 255, body_bytes[2*4 + 3])
                        # 13th: 偏移 12*4=48
                        val_b = parse_16bit_signed(body_bytes[3*4 + 2] * 255, body_bytes[3*4 + 3])
                        
                        # 除以移位基数恢复真实小数距离
                        dist_t = val_t
                        dist_b = val_b
                        dist_l = val_l
                        dist_r = val_r
                        # print(body_bytes)
                        print(val_l, val_b, val_t, val_r)
                        # 计算真实坐标 (乘以下采样步长)
                        x1 = int(cx - dist_l * 1)
                        y1 = int(cy - dist_t * 1)
                        x2 = int(cx + dist_r * 1)
                        y2 = int(cy + dist_b * 1)
                        
                        # 边界安全检查
                        x1 = max(0, x1); y1 = max(0, y1)
                        x2 = min(IMG_COL, x2); y2 = min(IMG_ROW, y2)
                        
                        if x2 > x1 and y2 > y1:
                            # 画中心点
                            cv2.circle(vis_img, (cx, cy), 4, (0, 0, 255), -1)
                            # 画矩形框
                            cv2.rectangle(vis_img, (x1, y1), (x2, y2), (0, 255, 0), 2)
                            # 画标签
                            label = f"C:{cls} {conf/255:.2f}"
                            cv2.putText(vis_img, label, (x1, y1 - 5), 
                                        cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 255), 1)

            except usb.core.USBError:
                pass

        # 实时刷新显示
        if r % 20 == 0:
            display_img = cv2.resize(vis_img, (0,0), fx=SHOW_SCALE, fy=SHOW_SCALE, interpolation=cv2.INTER_LINEAR)
            cv2.imshow('FPGA Detection Real-time', display_img)
            if cv2.waitKey(1) & 0xFF == ord('q'):
                frame_idx = SEND_FRAMES
                break
    
    if frame_idx == SEND_FRAMES: 
        break

# ================= 4. 结束处理 =================
out_file.close()
cv2.destroyAllWindows()
end_time = time.time()

print("="*30)
print(f"Process finished. Duration: {end_time - start_time:.2f}s")
print(f"Total read bytes: {total_read_bytes}")