import usb.core
import usb.util
import time
import sys

# ================= 1. 字符映射表配置 =================
CHARS = [
    '京', '沪', '津', '渝', '冀', '晋', '蒙', '辽', '吉', '黑',
    '苏', '浙', '皖', '闽', '赣', '鲁', '豫', '鄂', '湘', '粤',
    '桂', '琼', '川', '贵', '云', '藏', '陕', '甘', '青', '宁',
    '新', '学', '港', '澳', '警', '使', '领', '应', '急', '挂',
    '临',
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'J', 'K',
    'L', 'M', 'N', 'P', 'Q', 'R', 'S', 'T', 'U', 'V',
    'W', 'X', 'Y', 'Z', '-'
]

BLANK_CHAR_IDX = 75  # 硬件中的空白符索引定义

# ================= 2. USB 参数配置 =================
VENDOR_ID = 0x04b4
PRODUCT_ID = 0x00f1
EP_IN = 0x81
READ_BUFFER_SIZE = 1024 * 64 
USB_READ_TIMEOUT = 1000  # ms

# ================= 3. 辅助解析函数 =================
def get_char(idx):
    """将索引映射为字符，包括空白符和越界异常值"""
    if idx < len(CHARS):
        return CHARS[idx]
    elif idx == BLANK_CHAR_IDX:
        return "[BLANK]"  # 显式显示空白符
    else:
        return f"[UNK:{idx}]" # 捕获异常脏数据

# ================= 4. 主程序 =================
def main():
    # 寻找设备
    dev = usb.core.find(idVendor=VENDOR_ID, idProduct=PRODUCT_ID)
    if dev is None:
        print("❌ 未找到USB设备，请检查物理连接或驱动！")
        sys.exit(1)

    dev.set_configuration()

    print("\n=======================================")
    print("✅ 初始化完成！直接开始监听车牌字符数据...")
    print("   (按 Ctrl+C 退出程序)")
    print("=======================================\n")

    try:
        while True:
            try:
                # 阻塞读取数据
                raw_read = dev.read(EP_IN, READ_BUFFER_SIZE, timeout=USB_READ_TIMEOUT)

                if len(raw_read) > 0:
                    decoded_chars = []
                    valid_indices = []

                    # 确保数据长度可以被 4 整除，防止切片越界
                    valid_len = len(raw_read) - (len(raw_read) % 4)
                    
                    # 每次步进 4 个字节，严格提取每组的第 4 个 Byte (即偏移量 +3 的位置)
                    for i in range(0, valid_len, 4):
                        idx = raw_read[i + 3]
                        
                        valid_indices.append(idx)
                        decoded_chars.append(get_char(idx))
                            
                    if valid_indices:
                        result_str = "".join(decoded_chars)
                        print(f"📦 收到数据包 ({raw_read})")
                        print(f"🔢 提取索引: {valid_indices}")
                        print(f"🚗 解码结果: 【 {result_str} 】")
                        print("-" * 45)

            except usb.core.USBError as e:
                # 超时是正常现象，代表此时 FPGA 还没发来新数据
                if e.errno == 110 or e.errno == 10060 or 'timeout' in str(e).lower():
                    continue
                else:
                    print(f"❌ USB 读取发生异常: {e}")
                    break

            # 极短的休眠防止 CPU 空转跑满 100%
            time.sleep(0.005)

    except KeyboardInterrupt:
        print("\n🛑 用户手动终止读取。")

if __name__ == "__main__":
    main()