import subprocess
import time
import threading
from pathlib import Path
import tkinter as tk
from tkinter import messagebox


# =========================================================
# 설정
# =========================================================

# iPad Air 4 가로 비율
KINDLE_WIDTH = 1180
KINDLE_HEIGHT = 820

# Kindle 창 위치
KINDLE_X = 100
KINDLE_Y = 80

# macOS Kindle 제목 표시줄 높이
TITLE_BAR_HEIGHT = 28

# 페이지 넘긴 후 대기시간
PAGE_WAIT = 0.5

# Kindle 포커스 후 대기시간
FOCUS_WAIT = 0.3

# Kindle 창 설정 후 대기시간
SETUP_WAIT = 2.0


# =========================================================
# 저장 경로
# =========================================================

# 현재 Python 파일이 있는 폴더
SCRIPT_DIR = Path(__file__).resolve().parent

# Python 파일과 같은 위치의 kindle_captures 폴더
OUTPUT_DIR = SCRIPT_DIR / "kindle_captures"
OUTPUT_DIR.mkdir(exist_ok=True)


# =========================================================
# 전역 상태
# =========================================================

stop_event = threading.Event()
capture_thread = None
is_capturing = False


# =========================================================
# Kindle 창 설정
# =========================================================

def setup_kindle():
    script = f'''
    tell application "System Events"
        tell process "Kindle"
            set frontmost to true
            set position of front window to {{{KINDLE_X}, {KINDLE_Y}}}
            set size of front window to {{{KINDLE_WIDTH}, {KINDLE_HEIGHT}}}
        end tell
    end tell
    '''

    subprocess.run(
        ["osascript", "-e", script],
        check=True
    )

    time.sleep(SETUP_WAIT)


# =========================================================
# Kindle 포커스
# =========================================================

def focus_kindle():
    script = '''
    tell application "System Events"
        tell process "Kindle"
            set frontmost to true
        end tell
    end tell
    '''

    subprocess.run(
        ["osascript", "-e", script],
        check=True
    )

    time.sleep(FOCUS_WAIT)


# =========================================================
# 캡처
# =========================================================

def capture(page_number):
    """
    page_number를 그대로 파일명으로 사용한다.

    예:
    1   -> 001.png
    15  -> 015.png
    100 -> 100.png
    101 -> 101.png
    """

    output = OUTPUT_DIR / f"{page_number:03}.png"

    capture_x = KINDLE_X
    capture_y = KINDLE_Y + TITLE_BAR_HEIGHT

    capture_width = KINDLE_WIDTH
    capture_height = KINDLE_HEIGHT - TITLE_BAR_HEIGHT

    subprocess.run([
        "screencapture",
        "-x",
        "-R",
        f"{capture_x},{capture_y},{capture_width},{capture_height}",
        str(output)
    ], check=True)

    return output


# =========================================================
# 다음 페이지
# =========================================================

def next_page():
    # Kindle을 확실히 활성화
    focus_kindle()

    # 오른쪽 방향키
    script = '''
    tell application "System Events"
        key code 124
    end tell
    '''

    subprocess.run(
        ["osascript", "-e", script],
        check=True
    )

    # 페이지가 바뀔 때까지 대기
    interruptible_sleep(PAGE_WAIT)


# =========================================================
# 중지 가능한 sleep
# =========================================================

def interruptible_sleep(seconds):
    """
    기다리는 도중 중지 버튼이 눌리면
    가능한 빨리 빠져나온다.
    """

    end_time = time.time() + seconds

    while time.time() < end_time:

        if stop_event.is_set():
            return False

        time.sleep(0.05)

    return True


# =========================================================
# GUI 상태 업데이트
# =========================================================

def set_status(text):
    root.after(
        0,
        lambda: status_label.config(text=text)
    )


def set_progress(text):
    root.after(
        0,
        lambda: progress_label.config(text=text)
    )


# =========================================================
# 실제 캡처 작업
# =========================================================

def capture_worker(start_page, end_page):
    global is_capturing

    total_count = end_page - start_page + 1

    try:

        # -------------------------------------------------
        # Kindle 설정
        # -------------------------------------------------

        set_status("Kindle 창 설정 중...")
        set_progress("")

        setup_kindle()

        if stop_event.is_set():
            finish_stopped()
            return

        # -------------------------------------------------
        # 캡처 반복
        # -------------------------------------------------

        for current_index, page_number in enumerate(
            range(start_page, end_page + 1),
            start=1
        ):

            if stop_event.is_set():
                finish_stopped()
                return

            # 현재 상태 표시
            set_status("캡처중...")

            set_progress(
                f"{current_index} / {total_count}"
                f"    (파일: {page_number:03}.png)"
            )

            # Kindle 활성화
            focus_kindle()

            if stop_event.is_set():
                finish_stopped()
                return

            # 현재 페이지 캡처
            output = capture(page_number)

            print(
                f"[{current_index}/{total_count}] "
                f"{page_number:03}.png 캡처 완료"
            )

            print(f"저장 위치: {output}")

            # -------------------------------------------------
            # 마지막 페이지가 아니면 다음 페이지
            # -------------------------------------------------

            if page_number < end_page:

                if stop_event.is_set():
                    finish_stopped()
                    return

                set_status("다음 페이지로 이동 중...")

                set_progress(
                    f"{current_index} / {total_count}"
                    f"    (완료: {page_number:03}.png)"
                )

                next_page()

        # -------------------------------------------------
        # 정상 완료
        # -------------------------------------------------

        set_status("캡처 완료!")

        set_progress(
            f"{total_count} / {total_count}"
            f"    ({start_page:03}.png ~ {end_page:03}.png)"
        )

        root.after(
            0,
            lambda: capture_finished(
                start_page,
                end_page,
                total_count
            )
        )

    except Exception as e:

        print(e)

        error_message = str(e)

        root.after(
            0,
            lambda msg=error_message: capture_error(msg)
        )

    finally:
        is_capturing = False


# =========================================================
# 캡처 시작
# =========================================================

def start_capture():
    global capture_thread
    global is_capturing

    if is_capturing:
        return

    # -----------------------------------------------------
    # 시작/끝 페이지 읽기
    # -----------------------------------------------------

    start_value = start_entry.get().strip()
    end_value = end_entry.get().strip()

    try:
        start_page = int(start_value)
        end_page = int(end_value)

    except ValueError:

        messagebox.showerror(
            "입력 오류",
            "시작 페이지와 끝 페이지를 숫자로 입력해주세요."
        )

        return

    # -----------------------------------------------------
    # 값 검사
    # -----------------------------------------------------

    if start_page <= 0 or end_page <= 0:

        messagebox.showerror(
            "입력 오류",
            "페이지 번호는 1 이상이어야 합니다."
        )

        return

    if end_page < start_page:

        messagebox.showerror(
            "입력 오류",
            "끝 페이지는 시작 페이지보다 크거나 같아야 합니다."
        )

        return

    total_count = end_page - start_page + 1

    # -----------------------------------------------------
    # 너무 많은 장수 입력 실수 방지
    # -----------------------------------------------------

    if total_count > 5000:

        result = messagebox.askyesno(
            "확인",
            f"{total_count}장을 캡처합니다.\n\n"
            f"{start_page} ~ {end_page}\n\n"
            f"계속하시겠습니까?"
        )

        if not result:
            return

    # -----------------------------------------------------
    # 기존 파일 확인
    # -----------------------------------------------------

    existing_files = []

    for page_number in range(start_page, end_page + 1):

        file_path = OUTPUT_DIR / f"{page_number:03}.png"

        if file_path.exists():
            existing_files.append(file_path)

    # 기존 파일이 하나라도 있으면 확인
    if existing_files:

        # 표시할 파일 예시
        preview = "\n".join(
            file.name
            for file in existing_files[:5]
        )

        if len(existing_files) > 5:
            preview += f"\n... 외 {len(existing_files) - 5}개"

        result = messagebox.askyesno(
            "기존 파일 발견",
            f"해당 범위에 이미 존재하는 파일이 "
            f"{len(existing_files)}개 있습니다.\n\n"
            f"{preview}\n\n"
            f"기존 파일을 덮어쓰시겠습니까?"
        )

        if not result:
            return

    # -----------------------------------------------------
    # 캡처 시작
    # -----------------------------------------------------

    stop_event.clear()

    is_capturing = True

    # 입력란 잠금
    start_entry.config(state="disabled")
    end_entry.config(state="disabled")

    # 버튼 상태
    start_button.config(state="disabled")
    stop_button.config(state="normal")

    # 상태 표시
    status_label.config(
        text="준비 중..."
    )

    progress_label.config(
        text=f"0 / {total_count}"
    )

    # -----------------------------------------------------
    # 별도 Thread에서 실행
    # -----------------------------------------------------

    capture_thread = threading.Thread(
        target=capture_worker,
        args=(start_page, end_page),
        daemon=True
    )

    capture_thread.start()


# =========================================================
# 캡처 중지
# =========================================================

def stop_capture(event=None):

    if not is_capturing:
        return

    stop_event.set()

    status_label.config(
        text="중지 요청 중..."
    )

    stop_button.config(
        state="disabled"
    )


# =========================================================
# 중지 완료
# =========================================================

def finish_stopped():

    root.after(
        0,
        lambda: status_label.config(
            text="캡처가 중지되었습니다."
        )
    )

    root.after(
        0,
        reset_buttons
    )


# =========================================================
# 정상 완료
# =========================================================

def capture_finished(start_page, end_page, total_count):

    reset_buttons()

    messagebox.showinfo(
        "완료",
        f"캡처가 완료되었습니다.\n\n"
        f"캡처 수: {total_count}장\n"
        f"파일: {start_page:03}.png ~ {end_page:03}.png\n\n"
        f"저장 위치:\n{OUTPUT_DIR}"
    )


# =========================================================
# 오류
# =========================================================

def capture_error(error_message):

    reset_buttons()

    status_label.config(
        text="오류 발생"
    )

    messagebox.showerror(
        "오류",
        error_message
    )


# =========================================================
# 버튼 초기화
# =========================================================

def reset_buttons():

    start_button.config(
        state="normal"
    )

    start_entry.config(
        state="normal"
    )

    end_entry.config(
        state="normal"
    )

    stop_button.config(
        state="disabled"
    )


# =========================================================
# GUI
# =========================================================

root = tk.Tk()

root.title("Kindle Capture")

root.geometry("460x380")

root.resizable(False, False)


# ---------------------------------------------------------
# 제목
# ---------------------------------------------------------

title_label = tk.Label(
    root,
    text="Kindle 자동 캡처",
    font=("Arial", 20, "bold")
)

title_label.pack(
    pady=(25, 20)
)


# ---------------------------------------------------------
# 페이지 입력 영역
# ---------------------------------------------------------

input_frame = tk.Frame(root)

input_frame.pack()


# ---------------------------------------------------------
# 시작 페이지
# ---------------------------------------------------------

start_label = tk.Label(
    input_frame,
    text="시작 페이지:",
    font=("Arial", 13)
)

start_label.grid(
    row=0,
    column=0,
    padx=10,
    pady=7,
    sticky="e"
)


start_entry = tk.Entry(
    input_frame,
    width=10,
    font=("Arial", 14),
    justify="center"
)

start_entry.insert(
    0,
    "1"
)

start_entry.grid(
    row=0,
    column=1,
    padx=10,
    pady=7
)


# ---------------------------------------------------------
# 끝 페이지
# ---------------------------------------------------------

end_label = tk.Label(
    input_frame,
    text="끝 페이지:",
    font=("Arial", 13)
)

end_label.grid(
    row=1,
    column=0,
    padx=10,
    pady=7,
    sticky="e"
)


end_entry = tk.Entry(
    input_frame,
    width=10,
    font=("Arial", 14),
    justify="center"
)

end_entry.insert(
    0,
    "100"
)

end_entry.grid(
    row=1,
    column=1,
    padx=10,
    pady=7
)


# ---------------------------------------------------------
# 설명
# ---------------------------------------------------------

range_info_label = tk.Label(
    root,
    text="예: 101 ~ 200 → 101.png ~ 200.png",
    font=("Arial", 11)
)

range_info_label.pack(
    pady=(10, 0)
)


# ---------------------------------------------------------
# 상태
# ---------------------------------------------------------

status_label = tk.Label(
    root,
    text="대기 중",
    font=("Arial", 14)
)

status_label.pack(
    pady=(20, 5)
)


progress_label = tk.Label(
    root,
    text="",
    font=("Arial", 13)
)

progress_label.pack()


# ---------------------------------------------------------
# 버튼
# ---------------------------------------------------------

button_frame = tk.Frame(root)

button_frame.pack(
    pady=25
)


start_button = tk.Button(
    button_frame,
    text="캡처 시작",
    width=12,
    height=2,
    command=start_capture
)

start_button.pack(
    side="left",
    padx=10
)


stop_button = tk.Button(
    button_frame,
    text="중지",
    width=12,
    height=2,
    state="disabled",
    command=stop_capture
)

stop_button.pack(
    side="left",
    padx=10
)


# ---------------------------------------------------------
# 단축키 설명
# ---------------------------------------------------------

shortcut_label = tk.Label(
    root,
    text="중지 단축키: Control + X",
    font=("Arial", 11)
)

shortcut_label.pack()


# =========================================================
# 단축키
# =========================================================

root.bind_all(
    "<Control-x>",
    stop_capture
)

root.bind_all(
    "<Control-X>",
    stop_capture
)


# Enter로 캡처 시작
root.bind(
    "<Return>",
    lambda event: start_capture()
)


# =========================================================
# 실행
# =========================================================

root.mainloop()