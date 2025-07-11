def follow_log_file(file_path):
    with open(file_path, 'r') as f:
        for line in f:
            if 'Exception' in line or 'SIGSEGV' in line or 'E/' in line:
                yield line.strip()
