#!/bin/bash

# Variables
templates="./templates"

# Pre-flight Checks
if ! command -v python3 &> /dev/null; then
        echo  "Python is not installed"
	exit 1
fi

if ! command -v zip &> /dev/null; then
	echo  "Zip is not installed"
	exit 1
fi

# Checking if Python works (after verifying that it is installed
if ! python3 --version; then
    echo "Python3 was found, but could not run."
    exit 1
fi


# Reading the project name input and creating the directory
name_the_project() {
    while true; do
        read -r -p "Enter the last part of the project name (e.g. final): " name || exit 1

        if [[ "$name" =~ ^[a-zA-Z0-9_]+$ ]]; then
            project_dir="attendance_tracker_$name"
            break
        fi

        echo "Use letters, digits or underscores only."
    done
}

# Handling Signal interruptions during deployment
interrupted_deployment() {
    trap '' INT TSTP
    echo
    echo "Deployment interrupted. Saving the unfinished project."

    if [[ -d "$project_dir" ]]; then
        recovery_zip="${project_dir}_archive.zip"

        if [[ -e "$recovery_zip" ]]; then
            backup_zip="${project_dir}_archive_$(date +%Y%m%d_%H%M%S)_$$.zip"
            if ! mv -- "$recovery_zip" "$backup_zip"; then
                echo "Could not preserve the old archive. Keeping the project folder."
                exit 1
            fi
            echo "Previous archive kept at: $backup_zip"
        fi

        if zip -r "$recovery_zip" "$project_dir"; then
            echo "Saved: $recovery_zip"

            if ! rm -rf -- "$project_dir"; then
                echo "Archive saved, but the incomplete folder could not be removed."
                exit 1
            fi
            echo "Incomplete project folder removed."
        else
            echo "Archiving failed. Keeping the project folder so files are not lost."
        fi
    else
        echo "No project folder was created yet. Nothing to archive."
    fi

    exit 1  # Ends this script; it does not close your terminal.
}

# Deploying the application
run_application() {
for file in attendance_checker.py config.json assets.csv; do
if [[ ! -r "$project_dir/$file" ]]; then
echo "Missing or unreadable file: $project_dir/$file"
exit 1
fi
done

if [[ ! -d "$project_dir/reports" ]]; then
echo "Missing reports folder. Deploy the project first."
exit 1
fi

echo "Starting the attendance application"

if (cd -- "$project_dir" && python3 attendance_checker.py); then
echo "Application finished successfully."
else
echo "Application did not finish successfully. Project files have been kept."
exit 1
fi
}
