import os
import shutil
import subprocess
import tempfile
import zipfile
import streamlit as st
from pathlib import Path

def apply_script(folder_path, recursive=False):
    script_path = os.path.join(os.getcwd(), 'timestamper.sh')
    cmd = f"bash {script_path} {'-r' if recursive else ''} {folder_path}"
    process = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    process.communicate()

def zip_directory(folder_path, zip_path):
    with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
        for root, _, files in os.walk(folder_path):
            for file in files:
                zipf.write(os.path.join(root, file), os.path.relpath(os.path.join(root, file), folder_path))

st.title('Timestamper')

uploaded_file = st.file_uploader("Upload a zip file", type=['zip'])

if uploaded_file:
    uploaded_file_name = uploaded_file.name
    recursive = st.checkbox("Enable recursive mode")

    if st.button("Process Zip File"):
        st.write("Processing uploaded file(s), please wait...")
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_folder = Path(temp_dir) / "uploaded"
            temp_folder.mkdir()

            # Save and extract the uploaded zip file
            uploaded_zip_path = temp_folder / f"ORIGINAL_{uploaded_file_name}.zip"
            with open(uploaded_zip_path, 'wb') as f:
                f.write(uploaded_file.getvalue())

            with zipfile.ZipFile(uploaded_zip_path, 'r') as zip_ref:
                zip_ref.extractall(temp_folder)

            apply_script(temp_folder, recursive)

            output_filename = f"TIMESTAMPED_{uploaded_file_name}.zip"
            zip_directory(temp_folder, output_filename)

            st.success("File(s) timestamped successfully")
            with open(output_filename, "rb") as f:
                st.download_button("Download timestamped folder", f.read(), file_name=output_filename)
else:
    st.info("Upload a zip file to process.")
