from pathlib import Path
import shutil
import sys


# =========================================================
# 경로
# =========================================================

SCRIPT_DIR = Path(__file__).resolve().parent
TARGET_FILE = SCRIPT_DIR / "auto_capture_kindle_py" / "do.py"
BACKUP_FILE = SCRIPT_DIR / "auto_capture_kindle_py" / "do.py.backup"


# =========================================================
# 파일 확인
# =========================================================

if not TARGET_FILE.exists():
    print("❌ do.py를 찾을 수 없습니다.")
    print(f"찾은 경로: {TARGET_FILE}")
    sys.exit(1)


# =========================================================
# 백업
# =========================================================

shutil.copy2(
    TARGET_FILE,
    BACKUP_FILE,
)

print(f"✅ 백업 완료: {BACKUP_FILE}")


# =========================================================
# 읽기
# =========================================================

text = TARGET_FILE.read_text(
    encoding="utf-8"
)


# =========================================================
# 1. 고정 크기 → DEVICE_PRESETS
# =========================================================

old = '''# iPad Air 4 가로 비율
KINDLE_WIDTH = 1180
KINDLE_HEIGHT = 820
'''

new = '''# 기기별 Kindle 창 크기
#
# Kindle 제목 표시줄은 TITLE_BAR_HEIGHT 만큼
# 실제 캡처에서 제외된다.
DEVICE_PRESETS = {
    "iPad Air 4": {
        "width": 1180,
        "height": 820,
    },

    "iPhone 15": {
        "width": 1179,
        "height": 590,
    },
}

DEFAULT_DEVICE = "iPad Air 4"

KINDLE_WIDTH = DEVICE_PRESETS[DEFAULT_DEVICE]["width"]
KINDLE_HEIGHT = DEVICE_PRESETS[DEFAULT_DEVICE]["height"]
'''

if old not in text:
    print("❌ 기기 크기 설정 부분을 찾을 수 없습니다.")
    sys.exit(1)

text = text.replace(
    old,
    new,
    1,
)


# =========================================================
# 2. start_capture()에 기기 선택 적용
# =========================================================

old = '''def start_capture():
    global capture_thread
    global is_capturing

    if is_capturing:
        return
'''

new = '''def start_capture():
    global capture_thread
    global is_capturing
    global KINDLE_WIDTH
    global KINDLE_HEIGHT

    if is_capturing:
        return

    # -----------------------------------------------------
    # 선택한 기기 크기 적용
    # -----------------------------------------------------

    selected_device = device_var.get()

    preset = DEVICE_PRESETS[selected_device]

    KINDLE_WIDTH = preset["width"]
    KINDLE_HEIGHT = preset["height"]

    print(
        f"선택 기기: {selected_device} "
        f"({KINDLE_WIDTH} x {KINDLE_HEIGHT})"
    )
'''

if old not in text:
    print("❌ start_capture() 부분을 찾을 수 없습니다.")
    sys.exit(1)

text = text.replace(
    old,
    new,
    1,
)


# =========================================================
# 3. 캡처 시작 시 기기 선택 비활성화
# =========================================================

old = '''    # 입력란 잠금
    start_entry.config(state="disabled")
    end_entry.config(state="disabled")
'''

new = '''    # 입력란 잠금
    device_menu.config(state="disabled")
    start_entry.config(state="disabled")
    end_entry.config(state="disabled")
'''

if old not in text:
    print("❌ 입력란 잠금 부분을 찾을 수 없습니다.")
    sys.exit(1)

text = text.replace(
    old,
    new,
    1,
)


# =========================================================
# 4. reset_buttons()에서 기기 선택 다시 활성화
# =========================================================

old = '''def reset_buttons():

    start_button.config(
        state="normal"
    )

    start_entry.config(
        state="normal"
    )
'''

new = '''def reset_buttons():

    start_button.config(
        state="normal"
    )

    device_menu.config(
        state="normal"
    )

    start_entry.config(
        state="normal"
    )
'''

if old not in text:
    print("❌ reset_buttons() 부분을 찾을 수 없습니다.")
    sys.exit(1)

text = text.replace(
    old,
    new,
    1,
)


# =========================================================
# 5. GUI 높이 증가
# =========================================================

old = '''root.geometry("460x380")'''

new = '''root.geometry("460x430")'''

if old not in text:
    print("❌ root.geometry 부분을 찾을 수 없습니다.")
    sys.exit(1)

text = text.replace(
    old,
    new,
    1,
)


# =========================================================
# 6. input_frame 아래에 기기 선택 추가
# =========================================================

old = '''input_frame.pack()


# ---------------------------------------------------------
# 시작 페이지
# ---------------------------------------------------------
'''

new = '''input_frame.pack()


# ---------------------------------------------------------
# 기기 선택
# ---------------------------------------------------------

device_label = tk.Label(
    input_frame,
    text="기기:",
    font=("Arial", 13)
)

device_label.grid(
    row=0,
    column=0,
    padx=10,
    pady=7,
    sticky="e"
)


device_var = tk.StringVar(
    value=DEFAULT_DEVICE
)


device_menu = tk.OptionMenu(
    input_frame,
    device_var,
    *DEVICE_PRESETS.keys()
)

device_menu.config(
    width=14,
    font=("Arial", 13)
)

device_menu.grid(
    row=0,
    column=1,
    padx=10,
    pady=7
)


# ---------------------------------------------------------
# 시작 페이지
# ---------------------------------------------------------
'''

if old not in text:
    print("❌ input_frame 부분을 찾을 수 없습니다.")
    sys.exit(1)

text = text.replace(
    old,
    new,
    1,
)


# =========================================================
# 7. 시작 페이지 row 0 → 1
# =========================================================

old = '''start_label.grid(
    row=0,
    column=0,
    padx=10,
    pady=7,
    sticky="e"
)'''

new = '''start_label.grid(
    row=1,
    column=0,
    padx=10,
    pady=7,
    sticky="e"
)'''

if old not in text:
    print("❌ start_label.grid 부분을 찾을 수 없습니다.")
    sys.exit(1)

text = text.replace(
    old,
    new,
    1,
)


old = '''start_entry.grid(
    row=0,
    column=1,
    padx=10,
    pady=7
)'''

new = '''start_entry.grid(
    row=1,
    column=1,
    padx=10,
    pady=7
)'''

if old not in text:
    print("❌ start_entry.grid 부분을 찾을 수 없습니다.")
    sys.exit(1)

text = text.replace(
    old,
    new,
    1,
)


# =========================================================
# 8. 끝 페이지 row 1 → 2
# =========================================================

old = '''end_label.grid(
    row=1,
    column=0,
    padx=10,
    pady=7,
    sticky="e"
)'''

new = '''end_label.grid(
    row=2,
    column=0,
    padx=10,
    pady=7,
    sticky="e"
)'''

if old not in text:
    print("❌ end_label.grid 부분을 찾을 수 없습니다.")
    sys.exit(1)

text = text.replace(
    old,
    new,
    1,
)


old = '''end_entry.grid(
    row=1,
    column=1,
    padx=10,
    pady=7
)'''

new = '''end_entry.grid(
    row=2,
    column=1,
    padx=10,
    pady=7
)'''

if old not in text:
    print("❌ end_entry.grid 부분을 찾을 수 없습니다.")
    sys.exit(1)

text = text.replace(
    old,
    new,
    1,
)


# =========================================================
# 저장
# =========================================================

TARGET_FILE.write_text(
    text,
    encoding="utf-8"
)


print()
print("========================================")
print("✅ do.py 수정 완료")
print("========================================")
print()
print("추가된 기기:")
print("  - iPad Air 4")
print("  - iPhone 15")
print()
print(f"수정 파일: {TARGET_FILE}")
print(f"백업 파일: {BACKUP_FILE}")
print()
print("이제 do.py를 실행하면 기기를 선택할 수 있습니다.")

# /Users/jongseowon/Desktop/MY/project/202609/flutter_pdf_leader/auto_capture_kindle_py/do.py
# /Users/jongseowon/Desktop/MY/project/202609/flutter_pdf_leader/auto_capture_kindle_py/auto_capture_kindle_py/do.py