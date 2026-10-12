# Attendance Tracking and Management

This repository contains an attendance tracking and management project.

The main script is `deploy_agent.sh`.

The script handles environment preparation, which includes checking for Python 3 and ZIP dependencies, deploying a new application, running an already deployed application, and archiving attendance reports connected to a project.

## Requirements

The following are needed before running the application:

- Python 3 and ZIP installed
- The template files: `attendance_checker.py`, `config.json`, and `assets.csv`

## Running the Script

The script can be run from its own directory or from another directory using its path.

```bash
./deploy_agent.sh
```

When it starts running, it prompts the user to choose whether they want to deploy, run, archive, or exit the application.

### 1. Deploying

Prompts for a suffix for the project name. It copies the template files into the new project directory, configures the roster and thresholds, and then starts the Python application.

### 2. Running

Prompts for the name of an already existing project, updates the session number, and records attendance.

### 3. Archiving

Copies the existing `reports/attendance.log` and `reports/absent.log` files (when they exist) into their respective directories under `archives/attendance/` and `archives/absent/`, with timestamps indicating when they were archived.

The original report files remain in the `reports/` directory.

### 4. Exiting

Ends the selection menu.

The menu processes one selection per invocation. Run `./deploy_agent.sh` again to select another operation.

## Interruption and Recovery

When deployment is interrupted by signals sent through Ctrl+C or Ctrl+Z, a recovery function is invoked.

The unfinished project is saved into `attendance_tracker_NAME_archive.zip`. The ZIP contains all the folders and files that were generated before the interruption.

If archiving fails, the incomplete project folder is preserved. It is deleted only after archiving is successful.

Recovery also handles errors that occur during deployment setup.

## Roster Generation

*To be completed.*

## Git and Generated Files

Generated `attendance_tracker_*/` folders, ZIP files, and cache files are excluded using `.gitignore`.

The source `templates/` directory and `deploy_agent.sh` are kept in Git.
