# build_all_pdfs.py
# Orchestrates HTML generation, Chrome headless compilation to PDF, and pypdf verification.
import os
import sys
import subprocess
import time
import pypdf

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE_DIR)

from build_master_guide import generate_master_guide_html
from build_presentation_guide import generate_presentation_guide_html
from build_speaker_script import generate_speaker_script_html
from build_qa_handbook import generate_qa_handbook_html
from build_demo_playbook import generate_demo_playbook_html
from build_team_handbook import generate_team_handbook_html

DELIVERABLES = [
    {
        "name": "SentinelX_Project_Master_Guide",
        "generator": generate_master_guide_html,
        "html_file": os.path.join(BASE_DIR, "SentinelX_Project_Master_Guide.html"),
        "pdf_file": os.path.join(BASE_DIR, "SentinelX_Project_Master_Guide.pdf"),
        "title": "SentinelX Project Master Guide"
    },
    {
        "name": "MERNOVA_7_Minute_Presentation_Guide",
        "generator": generate_presentation_guide_html,
        "html_file": os.path.join(BASE_DIR, "MERNOVA_7_Minute_Presentation_Guide.html"),
        "pdf_file": os.path.join(BASE_DIR, "MERNOVA_7_Minute_Presentation_Guide.pdf"),
        "title": "MERNOVA 7-Minute Presentation Guide"
    },
    {
        "name": "MERNOVA_Three_Presenter_Speaker_Script",
        "generator": generate_speaker_script_html,
        "html_file": os.path.join(BASE_DIR, "MERNOVA_Three_Presenter_Speaker_Script.html"),
        "pdf_file": os.path.join(BASE_DIR, "MERNOVA_Three_Presenter_Speaker_Script.pdf"),
        "title": "MERNOVA Three-Presenter Speaker Script"
    },
    {
        "name": "MERNOVA_Judges_QA_Handbook",
        "generator": generate_qa_handbook_html,
        "html_file": os.path.join(BASE_DIR, "MERNOVA_Judges_QA_Handbook.html"),
        "pdf_file": os.path.join(BASE_DIR, "MERNOVA_Judges_QA_Handbook.pdf"),
        "title": "MERNOVA Judges Q&A Handbook (105 Questions)"
    },
    {
        "name": "MERNOVA_Live_Demo_Playbook",
        "generator": generate_demo_playbook_html,
        "html_file": os.path.join(BASE_DIR, "MERNOVA_Live_Demo_Playbook.html"),
        "pdf_file": os.path.join(BASE_DIR, "MERNOVA_Live_Demo_Playbook.pdf"),
        "title": "MERNOVA Live Demo Playbook"
    },
    {
        "name": "MERNOVA_Team_Preparation_Handbook",
        "generator": generate_team_handbook_html,
        "html_file": os.path.join(BASE_DIR, "MERNOVA_Team_Preparation_Handbook.html"),
        "pdf_file": os.path.join(BASE_DIR, "MERNOVA_Team_Preparation_Handbook.pdf"),
        "title": "MERNOVA Team Preparation Handbook"
    }
]

CHROME_PATHS = [
    r"C:\Program Files\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
    r"C:\Program Files\Microsoft\Edge\Application\msedge.exe"
]

def find_chrome():
    for p in CHROME_PATHS:
        if os.path.exists(p):
            return p
    return None

def main():
    print("=" * 80)
    print("SENTINELX // MERNOVA PRESENTATION PACKAGE — PDF BUILD & VERIFICATION")
    print("=" * 80)

    chrome_bin = find_chrome()
    if not chrome_bin:
        print("[ERROR] Neither Google Chrome nor Microsoft Edge was found.")
        sys.exit(1)
    print(f"[INFO] Using browser engine: {chrome_bin}")

    user_data_dir = os.path.join(os.environ.get("TEMP", r"C:\Temp"), "chrome_pdf_builder")
    os.makedirs(user_data_dir, exist_ok=True)

    # 1. Generate HTML files
    print("\n[PHASE 1] Generating HTML Source Files...")
    for item in DELIVERABLES:
        html_content = item["generator"]()
        with open(item["html_file"], "w", encoding="utf-8") as f:
            f.write(html_content)
        size_kb = len(html_content.encode("utf-8")) / 1024
        print(f"  -> Generated {os.path.basename(item['html_file'])} ({size_kb:.1f} KB)")

    # 2. Compile to PDF using Chrome Headless
    print("\n[PHASE 2] Compiling HTML to Searchable PDF via Chrome Headless...")
    for item in DELIVERABLES:
        cmd = [
            chrome_bin,
            "--headless",
            "--disable-gpu",
            "--no-sandbox",
            f"--user-data-dir={user_data_dir}",
            f"--print-to-pdf={item['pdf_file']}",
            "--no-pdf-header-footer",
            item["html_file"]
        ]
        res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        time.sleep(1) # Ensure file lock release
        if os.path.exists(item["pdf_file"]):
            pdf_size_kb = os.path.getsize(item["pdf_file"]) / 1024
            print(f"  -> Compiled {os.path.basename(item['pdf_file'])} ({pdf_size_kb:.1f} KB)")
        else:
            print(f"  -> [FAILED] Could not compile {os.path.basename(item['pdf_file'])}")
            print(res.stderr)

    # 3. Independent pypdf Verification
    print("\n[PHASE 3] Independent PDF Structure & Text Extractability Audit...")
    results = []
    all_passed = True
    for item in DELIVERABLES:
        pdf_path = item["pdf_file"]
        if not os.path.exists(pdf_path):
            results.append((item["name"], 0, 0, False, "FILE NOT FOUND"))
            all_passed = False
            continue
        try:
            reader = pypdf.PdfReader(pdf_path)
            num_pages = len(reader.pages)
            total_chars = 0
            for page in reader.pages:
                total_chars += len(page.extract_text() or "")
            is_valid = (num_pages > 0) and (total_chars > 200)
            if not is_valid:
                all_passed = False
            results.append((item["name"], num_pages, total_chars, is_valid, "OK" if is_valid else "LOW TEXT"))
        except Exception as e:
            results.append((item["name"], 0, 0, False, str(e)))
            all_passed = False

    print("\n" + "=" * 80)
    print(f"{'DELIVERABLE NAME':<40} | {'PAGES':<6} | {'CHARS':<8} | {'STATUS'}")
    print("-" * 80)
    for name, pages, chars, valid, msg in results:
        status_str = "PASS [Searchable]" if valid else f"FAIL [{msg}]"
        print(f"{name:<40} | {pages:<6} | {chars:<8} | {status_str}")
    print("=" * 80)

    if all_passed:
        print("[SUCCESS] All 6 MERNOVA presentation PDFs generated and verified successfully!")
        sys.exit(0)
    else:
        print("[FAIL] One or more PDFs failed verification.")
        sys.exit(1)

if __name__ == "__main__":
    main()
