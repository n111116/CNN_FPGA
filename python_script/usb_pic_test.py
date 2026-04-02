# 使用USB进行调试，读取真实图片写入FPGA并查看回写的数据
import usb.core
import os
import time
from datetime import datetime
import numpy as np
import cv2
import struct

# 如果您的硬件参数是从这个模块生成的，请保持导入
from CnnHardwareGenerator import layer0 as layer_to_test

# ================= 配置参数 =================
IMAGE_PATH = "data_pics/4.png"  # [修改这里] 替换为您要测试的图片路径
OUTPUT_DIR = "usb_data"
SEND_FRAMES = 10       # 发送帧数 (发送同一张图多次，模拟视频流测试稳定性)

# USB 传输参数
READ_BUFFER_SIZE = 1024 * 64 
USB_WRITE_TIMEOUT = 1000 # ms
USB_READ_TIMEOUT = 1    # ms

# 可视化配置
CONF_THRESHOLD = 1      # 置信度阈值 (根据硬件实际输出调整)
SHOW_SCALE = 1.0        # 显示缩放倍数
GRID_STRIDE = 16        # 网络下采样步长

# 数据包结构参数
# 假设硬件回传 1 Header + 4 个值(每个值4字节) = 20 Bytes
PACKET_SIZE = 4 + 4 * 4 

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
layer_to_test.load_mat_data() # 如果这里报错，您可以直接硬编码 IMG_COL 和 IMG_ROW

IMG_COL = layer_to_test.img_col
IMG_ROW = layer_to_test.img_row

# ================= 1. 环境与图像准备 =================
if not os.path.exists(OUTPUT_DIR):
    os.makedirs(OUTPUT_DIR)

timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
output_filename = f"{timestamp}_image_test.hex"
output_filepath = os.path.join(OUTPUT_DIR, output_filename)

# ---------------------------------------------------
# A. 使用 OpenCV 读取真实图片并预处理
# ---------------------------------------------------
print(f"Reading input image: {IMAGE_PATH}...")
if not os.path.exists(IMAGE_PATH):
    raise FileNotFoundError(f"Image file not found: {IMAGE_PATH}")

# 读取图片 (默认是 BGR 格式)
img_raw = cv2.imread(IMAGE_PATH)

# 缩放图片到 FPGA 期望的分辨率
img_resized = cv2.resize(img_raw, (IMG_COL, IMG_ROW))

# 转换颜色空间：BGR -> RGB (通常神经网络第一层输入是 RGB)
img_rgb = cv2.cvtColor(img_resized, cv2.COLOR_BGR2RGB)

# 用于显示的底图 (保持 BGR 用于 cv2.imshow)
img_bgr_display = img_resized.copy()

out_file = open(output_filepath, 'w')
print(f"Image resized to: {IMG_COL}x{IMG_ROW}")

# ================= 2. USB 初始化 =================
dev = usb.core.find(idVendor=0x04b4, idProduct=0x00f1)
if dev is None:
    raise ValueError('Device not found. 请检查USB连接或驱动程序。')

dev.set_configuration()

# 清空残留的接收缓冲区
print("Cleaning USB read buffer...")
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
    vis_img = img_bgr_display.copy()
    
    for r in range(IMG_ROW):
        # -------------------------------------------------
        # A. 构建当前行数据包 (使用 RGB 图片数据)
        # -------------------------------------------------
        row_payload = []
        # 行首 Header
        row_payload.extend([0xFF, 0x00, 0x00, 0x00])
        
        for c in range(IMG_COL):
            # 获取当前像素的 R, G, B 分量
            # 注意：OpenCV 的 shape 是 (H, W, Channels)，所以索引是 [r, c, channel]
            ch0 = img_rgb[r, c, 0] # R
            ch1 = img_rgb[r, c, 1] # G
            ch2 = img_rgb[r, c, 2] # B
            
            # 如果硬件 PE 分页数量为 4，通常第 4 个通道填充为 0
            if layer_to_test.pe_page_num == 4:
                ch3 = 0
            else:
                ch3 = 0
                
            # 按硬件预期顺序装入 payload (ch3, ch2, ch1, ch0)
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
                data_buffer.extend(raw_read)
                
                # 只要缓冲区够一个完整包的大小，就进行解析
                while len(data_buffer) >= PACKET_SIZE:
                    packet = data_buffer[:PACKET_SIZE]
                    del data_buffer[:PACKET_SIZE] 
                    
                    # --- 1. 解析 Header ---
                    header_bytes = packet[:4]
                    cls    = header_bytes[0]
                    x_grid = header_bytes[1]
                    y_grid = header_bytes[2]
                    conf   = header_bytes[3]
                    
                    out_file.write(f"{cls:02x} {x_grid:02x} {y_grid:02x} {conf:02x}\n")
                    
                    # --- 2. 坐标转换 ---
                    cx = x_grid * GRID_STRIDE + GRID_STRIDE // 2
                    cy = y_grid * GRID_STRIDE + GRID_STRIDE // 2
                    
                    # --- 3. 提取边界距离与画框 ---
                    if conf >= CONF_THRESHOLD:
                        body_bytes = packet[4:]
                        
                        val_l = parse_16bit_signed(body_bytes[0*4 + 2] * 255, body_bytes[0*4 + 3])
                        val_t = parse_16bit_signed(body_bytes[1*4 + 2] * 255, body_bytes[1*4 + 3])
                        val_r = parse_16bit_signed(body_bytes[2*4 + 2] * 255, body_bytes[2*4 + 3])
                        val_b = parse_16bit_signed(body_bytes[3*4 + 2] * 255, body_bytes[3*4 + 3])
                        
                        x1 = int(cx - val_l * 1)
                        y1 = int(cy - val_t * 1)
                        x2 = int(cx + val_r * 1)
                        y2 = int(cy + val_b * 1)
                        
                        x1 = max(0, x1); y1 = max(0, y1)
                        x2 = min(IMG_COL, x2); y2 = min(IMG_ROW, y2)
                        
                        if x2 > x1 and y2 > y1:
                            cv2.circle(vis_img, (cx, cy), 4, (0, 0, 255), -1)
                            cv2.rectangle(vis_img, (x1, y1), (x2, y2), (0, 255, 0), 2)
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