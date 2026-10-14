# Attendance Tracking and Management

This repository contains an attendance tracking and management project.

The main script is `deploy_agent.sh`.

The script handles environment preparation, which includes checking for Python 3 and ZIP dependencies, deploying a new application, running an already deployed application, and archiving attendance reports connected to a project.

[Watch a live demo of the script running](https://youtu.be/sTSsDs0Ilsw?si=BDPnvlxTFh9UpGdc)

## Requirements

The following are needed before running the application:

- Linux with Bash, Python 3, ZIP, and standard Linux tools (`sed`, `awk`, and `stat`)
- The template files in `templates/`: `attendance_checker.py`, `config.json`, and `assets.csv`

The script checks for Python 3 and ZIP before displaying the menu and verifies that `python3 --version` works.

## Running the Script

From the repository directory, run:

```bash
./deploy_agent.sh
```

If execution permission is missing, use `bash deploy_agent.sh`. From another directory, use the script's path, for example `bash ~/deploy_agent_Umutoni-Rita/deploy_agent.sh`. Projects are created beside the script.

When it starts running, it prompts the user to choose whether they want to deploy, run, archive, or exit the application.

### 1. Deploying

Prompts for a suffix for the project name. It copies the template files into the new project directory, configures the roster and thresholds, and then starts the Python application.

For example, enter `demo` to create `attendance_tracker_demo/`. Names may contain letters, digits, and underscores. 

The initial structure is:

```text
attendance_tracker_demo/
|-- attendance_checker.py
|-- Helpers/
|   |-- assets.csv
|   `-- config.json
`-- reports/
```

`reports/` starts empty. Absence and attendance log files get created when you start marking. The deployed config is copied from its template, then its session number and any requested thresholds are updated. After these edits, `chmod 600` restricts the config to owner read/write access.

### 2. Running

Prompts for the suffix of an existing project: enter `demo`, not `attendance_tracker_demo`. It checks the required files, sets `total_sessions` to the roster's completed sessions plus one, and runs `python3 attendance_checker.py` from the project root.

Enter `P` for present or `A` for absent for each student. The app updates the roster and creates the session logs. If a previous marking session left students with different session counts, the script stops and asks you to review the roster before running again.

### 3. Archiving

Copies the existing `reports/attendance.log` and `reports/absent.log` files (when they exist) into their respective directories under `archives/attendance/` and `archives/absent/`, with timestamps indicating when they were archived.

The original report files remain in the `reports/` directory.

Names use `YYYYMMDD_HHMMSS` (year, month, day, hour, minute, second). If a name already exists, a numbered suffix such as `_1` prevents overwriting. Each copy contains the log's contents at archive time, including previous sessions.

### 4. Exiting

Ends the selection menu.

The menu processes one selection per invocation. Run `./deploy_agent.sh` again to select another operation.

## Interruption and Recovery

When deployment is interrupted by signals sent through Ctrl+C or Ctrl+Z, a recovery function is invoked.

The unfinished project is saved into `attendance_tracker_NAME_archive.zip`. The ZIP contains all the folders and files that were generated before the interruption.

If archiving fails, the incomplete project folder is preserved. It is deleted only after archiving is successful.

Recovery also handles errors that occur during deployment setup.

An existing recovery ZIP is renamed with a timestamp and process ID before a new one is created. Deployment recovery is disabled before Python starts, so interrupting a marking session keeps the deployed project and lets the application handle the interruption.

## Roster Generation

Choose `A` or `B`, then enter a student count from `1` to `10`:

- **A: Copy the template.** Copies the CSV header and the requested number of students. Each student has four prior sessions, so `total_sessions` starts at `5`.
- **B: Generate a roster.** Uses the script's sample name and email arrays. Attendance and absence counts start at `0`, so `total_sessions` starts at `1`.

Before each session, `total_sessions` must equal each student's Attendance Count plus Absence Count plus one. This includes the session about to be marked. The source templates are kept unchanged.

## Updating Thresholds

During deployment, answer `y` to the threshold prompt to set warning and failure percentages, or `n` to keep `75` and `50`.

Values must be whole numbers from `0` to `100`, and failure must not exceed warning. Press Enter to accept warning `75` and failure `50`. If you choose a warning below `50`, the default failure becomes that warning value.

The script uses `sed` to replace only the numbers on the deployed config's `"warning"` and `"failure"` lines, preserving the file's layout and key order. The app reports a warning below the warning threshold and an urgent alert below the failure threshold.

## Git and Generated Files

Generated `attendance_tracker_*/` folders, ZIP files, and cache files are excluded using `.gitignore`.

The source `templates/` directory and `deploy_agent.sh` are kept in Git.
