import usb.core
import os
import time
from datetime import datetime

# ================= 配置参数 =================
HEX_FILE_PATH = "conv_data/feature_Conv1_input_8bit.hex"
OUTPUT_DIR = "usb_data"

IMG_COL = 128         # 图像宽度
IMG_ROW = 128         # 假设图像高度为 128
CHANNELS = 3          # 通道数
SEND_FRAMES = 10      # [修改] 发送帧数

# 读取缓冲大小 (字节)
READ_BUFFER_SIZE = 1024 * 64 
USB_WRITE_TIMEOUT = 1000 # ms
USB_READ_TIMEOUT = 1    # ms

# ================= 1. 环境与文件准备 =================
if not os.path.exists(OUTPUT_DIR):
    os.makedirs(OUTPUT_DIR)

timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
output_filename = f"{timestamp}—{SEND_FRAMES}frames.hex"
output_filepath = os.path.join(OUTPUT_DIR, output_filename)

print(f"Output will be saved to: {output_filepath}")
out_file = open(output_filepath, 'w')

# 读取输入数据
raw_data = []
if not os.path.exists(HEX_FILE_PATH):
    raise FileNotFoundError(f"File not found: {HEX_FILE_PATH}")

print(f"Reading input file: {HEX_FILE_PATH}...")
with open(HEX_FILE_PATH, 'r') as f:
    for line in f:
        line = line.strip()
        if line:
            raw_data.append(int(line, 16))

total_values = len(raw_data)
total_pixels = total_values // CHANNELS
total_rows = total_pixels // IMG_COL
print(f"Total Rows per frame: {total_rows}")

# ================= 2. USB 初始化 =================
dev = usb.core.find(idVendor=0x04b4, idProduct=0x00f1)
if dev is None:
    raise ValueError('Device not found')

dev.set_configuration()

# 清空之前的残留数据
try:
    while True:
        dev.read(0x81, 1024, timeout=10)
except usb.core.USBError:
    pass

# ================= 3. 发送与读取循环 =================
start_time = time.time()
total_read_bytes = 0

print(f"Starting transmission of {SEND_FRAMES} frames...")

# [修改] 外层循环：发送 10 帧
for frame_idx in range(SEND_FRAMES):
    print(f"--- Sending Frame {frame_idx + 1} / {SEND_FRAMES} ---")
    
    # [修改] 每帧开始前重置数据指针，以发送相同的数据
    data_ptr = 0 
    
    for r in range(total_rows):
        # -------------------------------------------------
        # A. 构建当前行数据包
        # -------------------------------------------------
        row_payload = []
        # 行首标志 [0xFF, 0x00, 0x00, 0x00]
        row_payload.extend([0xFF, 0x00, 0x00, 0x00])
        
        # 拼接像素数据 [0x00, Ch2, Ch1, Ch0]
        for c in range(IMG_COL):
            if data_ptr + 2 < total_values:
                ch0 = raw_data[data_ptr]      # Low
                ch1 = raw_data[data_ptr + 1]
                ch2 = raw_data[data_ptr + 2]  # High
            else:
                ch0, ch1, ch2 = 0, 0, 0
            # ch2 = 0 if (r&0x01 == 0) else 1
            # ch1 = 0 if (r&0x01 == 0) else 1
            # ch0 = int(data_ptr/3) & 0xFF
            data_ptr += 3
            row_payload.extend([0x00, ch2, ch1, ch0])

        # -------------------------------------------------
        # B. 发送数据
        # -------------------------------------------------
        try:
            dev.write(0x01, row_payload, timeout=USB_WRITE_TIMEOUT)
        except usb.core.USBError as e:
            print(f"Error sending frame {frame_idx+1} row {r}: {e}")
            break

        # -------------------------------------------------
        # C. 尝试读取数据 (每行结束都读)
        # -------------------------------------------------
        if(r % 10 == 0):
            try:
            # 尝试读取数据
                raw_read = dev.read(0x81, READ_BUFFER_SIZE, timeout=USB_READ_TIMEOUT)
                
                # 去掉每次读取的最后四个值
                read_data = raw_read
                
                data_len = len(read_data)
                
                if data_len > 0:
                    total_read_bytes += data_len
                    
                    # 确保是 4 的倍数，如果不是，剩余部分可能需要特殊处理或忽略
                    # 这里简单处理，按 4 字节步长遍历
                    for i in range(0, data_len, 4):
                        if i + 3 < data_len:
                            b0 = read_data[i]
                            b1 = read_data[i+1]
                            b2 = read_data[i+2]
                            b3 = read_data[i+3]
                            # 对应 FPGA: layer_data[0] layer_data[1] layer_data[2] layer_data[3]
                            # [修正] 修正了原代码中格式化字符串的笔误 (01x -> 02x)
                            out_file.write(f"{b3:02x} {b2:02x} {b1:02x} {b0:02x}\n")
                            
            except usb.core.USBError as e:
                if e.errno == 110: # Operation timed out (正常现象，说明FPGA暂时没数据)
                    pass
                else:
                    print(f"[Frame {frame_idx+1} Row {r}] Read Error: {e} {e.errno}")

# ================= 4. 结束处理 =================
# 发送结束后，循环读取直到超时，确保取回所有残留数据
print("Transmission done. Draining remaining data...")
try:
    while True:
        raw_read = dev.read(0x81, READ_BUFFER_SIZE, timeout=100)
        
        # [修改] 同样去掉最后 4 个值
        read_data = raw_read[:-4]
        
        data_len = len(read_data)
        if data_len > 0:
            total_read_bytes += data_len
            for i in range(0, data_len, 4):
                if i + 3 < data_len:
                    b0 = read_data[i]
                    b1 = read_data[i+1]
                    b2 = read_data[i+2]
                    b3 = read_data[i+3]
                    out_file.write(f"{b3:02x} {b2:02x} {b1:02x} {b0:02x}\n")
        else:
            # 如果切片后没数据了，或者读取本身就空，继续读还是退出？
            # 这里假设如果原读取为空(Timeout)，则退出；
            # 如果原读取不为空但小于等于4字节，导致切片为空，则继续读下一包。
            if len(raw_read) == 0:
                break
            
except usb.core.USBError:
    pass

out_file.close()
end_time = time.time()

print("="*30)
print(f"Process finished in {end_time - start_time:.4f} seconds.")
print(f"Total bytes written to file: {total_read_bytes}")
print(f"Result saved to: {output_filepath}")