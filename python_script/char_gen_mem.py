import os
from PIL import Image, ImageDraw, ImageFont

# ================= 配置参数 =================
# 字符表
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

FONT_SIZE = 16        # 字模尺寸 16x16
IMG_SIZE = 16
OUTPUT_FILE = "rtl/data_process/mem_data/chars_16x16.mem"

# 推荐使用宋体(simsun.ttc)或黑体(simhei.ttf)，在16x16下显示效果较好
# 如果是 Windows 系统，通常可以直接在 C:\Windows\Fonts 下找到
FONT_PATH = "simsun.ttc" 

def generate_mem():
    # 1. 加载字体
    try:
        # 尝试加载指定字体，如果找不到会抛出异常
        font = ImageFont.truetype(FONT_PATH, FONT_SIZE)
    except IOError:
        print(f"❌ 找不到字体文件: {FONT_PATH}")
        print("请将 simsun.ttc 或 simhei.ttf 放在脚本同级目录，或修改 FONT_PATH 为系统绝对路径。")
        return

    print(f"✅ 成功加载字体: {FONT_PATH}")
    print(f"⏳ 开始生成字模，共 {len(CHARS)} 个字符...")

    with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
        # 添加头部注释
        f.write(f"// 16x16 Font ROM Data\n")
        f.write(f"// Total Characters: {len(CHARS)}\n")
        f.write(f"// Data Format: 16-bit Binary\n\n")

        for idx, char in enumerate(CHARS):
            # 创建 16x16 的全黑二值图像 (mode '1' 代表 1-bit 像素)
            img = Image.new('1', (IMG_SIZE, IMG_SIZE), color=0)
            draw = ImageDraw.Draw(img)

            # ---------------------------------------------------------
            # 绘制字符 (坐标微调)
            # 中文字体在特定字号下可能存在内部基线偏移，(0,-2) 对宋体/黑体比较合适
            # 你可以根据实际导出的字模效果微调 offset_x 和 offset_y
            # ---------------------------------------------------------
            offset_x = 0
            offset_y = 0 if char > 'Z' else -1 # 汉字通常比英文字母要往上偏一点
            
            # 英文字母和数字居中处理 (如果希望英文等宽居中，可以修改此处 offset_x)
            if len(char.encode('utf-8')) == 1:
                offset_x = 4 # 英文字符比较窄，往右挪一点让它居中

            draw.text((offset_x, offset_y), char, font=font, fill=1)

            # 获取图像的所有像素数据
            pixels = list(img.getdata())

            # 写入注释，方便在 mem 文件中查看对应哪个字符
            f.write(f"// --- Index {idx}: '{char}' ---\n")

            # 将 16x16 的像素转换为 16 行，每行 16 个二进制数字
            for row in range(IMG_SIZE):
                row_binary = ""
                for col in range(IMG_SIZE):
                    # 获取当前像素点，如果不为 0 则视为 1 (白点/笔画)
                    pixel_val = pixels[row * IMG_SIZE + col]
                    row_binary += "1" if pixel_val > 0 else "0"
                
                # 写入该行二进制数据
                f.write(row_binary + "\n")
            
            f.write("\n") # 字符与字符之间空一行，更美观

    print(f"🎉 字模生成完毕！已保存至 -> {OUTPUT_FILE}")

if __name__ == "__main__":
    generate_mem()