#!/bin/bash

script_location="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
templates="$script_location/templates"
project_dir=""
project_name=""

# Pre-flight checks
if ! command -v python3 &> /dev/null; then
    echo "Python3 is not installed."
    exit 1
fi

if ! command -v zip &> /dev/null; then
    echo "Zip is not installed. Please install zip before running this script."
    exit 1
fi

if ! python3 --version; then
    echo "Python3 was found, but could not run."
    exit 1
fi

# Ask for a safe project name.
name_the_project() {
    while true; do
        read -r -p "Enter the last part of the project name (e.g. final): " name || exit 1

        if [[ "$name" =~ ^[a-zA-Z0-9_]+$ ]]; then
            project_name="attendance_tracker_$name"
            project_dir="$script_location/$project_name"
            break
        fi

        echo "Use letters, digits or underscores only."
    done
}

# Save unfinished deployment on Ctrl+C, Ctrl+Z, or a setup error.
recover_deployment() {
    local reason="$1"
    trap - EXIT
    trap '' INT TSTP

    echo
    echo "Deployment $reason. Saving the unfinished project."

    if [[ -d "$project_dir" && ! -L "$project_dir" ]]; then
        recovery_zip="${project_dir}_archive.zip"

        if [[ -e "$recovery_zip" ]]; then
            backup_zip="${project_dir}_archive_$(date +%Y%m%d_%H%M%S)_$$.zip"
            if ! mv -- "$recovery_zip" "$backup_zip"; then
                echo "Could not preserve the old archive. Keeping the project folder."
                exit 1
            fi
            echo "Previous archive kept at: $backup_zip"
        fi

        # Run zip in the repository directory so the ZIP has a clean relative path.
        if (cd -- "$script_location" && zip -r "$recovery_zip" "$project_name"); then
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
        echo "No incomplete project folder to archive."
    fi

    exit 1
}

# Read the completed sessions in the roster and prepare exactly one new session.
prepare_next_session() {
    local roster="$project_dir/Helpers/assets.csv"
    local config="$project_dir/Helpers/config.json"
    local next_total

    next_total=$(awk -F, '
        NR == 1 { next }
        { sub(/\r$/, "", $4) }
        NF < 4 || $3 !~ /^[0-9]+$/ || $4 !~ /^[0-9]+$/ { invalid = 1; exit }
        NR == 2 { previous = $3 + $4 }
        ($3 + $4) != previous { invalid = 1; exit }
        END {
            if (invalid || NR < 2) exit 1
            print previous + 1
        }
    ' "$roster") || {
        echo "Roster contains inconsistent session counts (possibly an interrupted run)."
        echo "Review the roster before running another session; no data was changed."
        exit 1
    }

    if ! sed -i -E "s/(\"total_sessions\"[[:space:]]*:[[:space:]]*)[0-9]+/\1$next_total/" "$config"; then
        echo "Could not update total_sessions."
        exit 1
    fi
    echo "Session number: $next_total (previous completed sessions: $((next_total - 1)))."
}

# Run the Python application 
run_application() {
    if [[ ! -d "$project_dir" || -L "$project_dir" ]]; then
        echo "Project not found. Deploy it first."
        exit 1
    fi

    for file in attendance_checker.py Helpers/config.json Helpers/assets.csv; do
        if [[ ! -r "$project_dir/$file" ]]; then
            echo "Missing or unreadable file: $project_dir/$file"
            exit 1
        fi
    done

    if [[ ! -d "$project_dir/reports" ]]; then
        echo "Missing reports folder. Deploy the project first."
        exit 1
    fi

    # New deployments already set total_sessions. Existing projects need the next value.
    if [[ "${1:-}" == "existing" ]]; then
        prepare_next_session
    fi

    echo "Starting the attendance application."
    if (cd -- "$project_dir" && python3 attendance_checker.py); then
        echo "Application finished successfully."
    else
        echo "Application did not finish successfully. Project files have been kept."
        exit 1
    fi
}

# Deploy a new project.
deploy() {
    # Check templates before replacing any existing project.
    for file in attendance_checker.py config.json assets.csv; do
        if [[ ! -r "$templates/$file" ]]; then
            echo "Missing or unreadable template: $templates/$file"
            exit 1
        fi
    done

    name_the_project

    if [[ -L "$project_dir" ]]; then
        echo "That project path is a symbolic link. Choose another name."
        exit 1
    fi

    if [[ -e "$project_dir" ]]; then
        while true; do
            read -r -p "Project already exists. Overwrite? [y/n]: " answer || exit 1
            answer="${answer,,}"
            if [[ "$answer" == "y" || "$answer" == "n" ]]; then
                break
            fi
            echo "Please enter y or n."
        done

        if [[ "$answer" == "y" ]]; then
            # Overwrite deletes the contents of the existing project.
            if ! rm -rf -- "$project_dir"; then
                echo "Could not remove the existing project. Check permissions."
                exit 1
            fi
        else
            echo "Deployment aborted. Existing project kept."
            return 0
        fi
    fi

    # Only incomplete *deployment* needs automatic archiving and removal.
    trap 'recover_deployment "interrupted"' INT TSTP
    trap 'recover_deployment "failed"' EXIT

    if ! mkdir -p -- "$project_dir/Helpers" "$project_dir/reports"; then
        echo "Could not create the project folders. Check permissions."
        exit 1
    fi

    if ! cp -- "$templates/attendance_checker.py" "$project_dir/attendance_checker.py"; then
        echo "Could not copy attendance_checker.py."
        exit 1
    fi

    if ! cp -- "$templates/config.json" "$project_dir/Helpers/config.json"; then
        echo "Could not copy config.json."
        exit 1
    fi

    while true; do
        read -r -p "Roster: A = copy template, B = generate new students: " roster_option || exit 1
        roster_option="${roster_option^^}"
        if [[ "$roster_option" == "A" || "$roster_option" == "B" ]]; then
            break
        fi
        echo "Enter A or B."
    done

    while true; do
        read -r -p "How many students (1-10)? " student_count || exit 1
        if [[ "$student_count" =~ ^([1-9]|10)$ ]]; then
            break
        fi
        echo "Enter a whole number from 1 to 10."
    done

    if [[ "$roster_option" == "A" ]]; then
        # Count includes the CSV header.
        lines=$((student_count + 1))
        if ! head -n "$lines" "$templates/assets.csv" > "$project_dir/Helpers/assets.csv"; then
            echo "Could not copy the roster."
            exit 1
        fi
        total_sessions=5 
    else
        names=("Alice Johnson" "Bob Smith" "Carol Jones" "David Brown" "Eva Green"
               "Frank Wilson" "Grace Martin" "Henry Clark" "Irene Adams" "Jack Lewis")
        emails=("alice@example.com" "bob@example.com" "carol@example.com"
                "david@example.com" "eva@example.com" "frank@example.com"
                "grace@example.com" "henry@example.com" "irene@example.com" "jack@example.com")

        if ! printf 'Email,Names,Attendance Count,Absence Count\n' > "$project_dir/Helpers/assets.csv"; then
            echo "Could not write the roster header."
            exit 1
        fi
        for ((i=0; i<student_count; i++)); do
            if ! printf '%s,%s,0,0\n' "${emails[i]}" "${names[i]}" >> "$project_dir/Helpers/assets.csv"; then
                echo "Could not write a student row."
                exit 1
            fi
        done
        total_sessions=1
    fi

    config="$project_dir/Helpers/config.json"
    if ! sed -i -E "s/(\"total_sessions\"[[:space:]]*:[[:space:]]*)[0-9]+/\1$total_sessions/" "$config"; then
        echo "Could not update total_sessions."
        exit 1
    fi

    if ! chmod +x -- "$project_dir/attendance_checker.py"; then
        echo "Could not make the Python file executable."
        exit 1
    fi

    while true; do
        read -r -p "Update thresholds? (Default: 75%-Warning, 50%-Failure) [y/n]: " answer || exit 1
        answer="${answer,,}"
        if [[ "$answer" == "y" || "$answer" == "n" ]]; then
            break
        fi
        echo "Enter y or n."
    done

    if [[ "$answer" == "y" ]]; then
        while true; do
            read -r -p "Warning percentage (Enter for 75): " warning || exit 1
            [[ -n "$warning" ]] || warning=75
            if [[ "$warning" =~ ^([0-9]|[1-9][0-9]|100)$ ]]; then
                break
            fi
            echo "Enter a whole number from 0 to 100."
        done

        # A default of 50 is invalid if the warning threshold is below 50.
        default_failure=$((warning < 50 ? warning : 50))
        while true; do
            read -r -p "Failure percentage (Enter for $default_failure): " failure || exit 1
            [[ -n "$failure" ]] || failure=$default_failure
            if [[ "$failure" =~ ^([0-9]|[1-9][0-9]|100)$ ]] && (( failure <= warning )); then
                break
            fi
            echo "Enter a whole number from 0 to $warning (failure must not exceed warning)."
        done

        if ! sed -i -E "s/(\"warning\"[[:space:]]*:[[:space:]]*)[0-9]+/\1$warning/" "$config"; then
            echo "Could not update warning."
            exit 1
        fi
        if ! sed -i -E "s/(\"failure\"[[:space:]]*:[[:space:]]*)[0-9]+/\1$failure/" "$config"; then
            echo "Could not update failure."
            exit 1
        fi
        echo "Thresholds updated: warning=$warning, failure=$failure."
    fi

    # Set and confirm permissions after all config edits.
    if ! chmod 600 -- "$config"; then
        echo "Could not set config permissions."
        exit 1
    fi
    mode=$(stat -c '%a' -- "$config") || exit 1
    echo "Config permissions: $mode (expected 600)."
    if [[ "$mode" != "600" ]]; then
        echo "Incorrect permissions. Use the Linux filesystem, not /mnt/c or /mnt/d."
        exit 1
    fi

    echo "Deployment setup complete: $project_name"

    # Finished deployment: errors in the Python app must NOT remove the project.
    trap - EXIT INT TSTP
    run_application
}

# Archiving the logs into separate folders
archive_logs() {
    if [[ ! -d "$project_dir" || -L "$project_dir" ]]; then
        echo "Project folder not found, or it is a symbolic link."
        exit 1
    fi

    timestamp=$(date +%Y%m%d_%H%M%S)
    for log in attendance absent; do
        source_log="$project_dir/reports/$log.log"
        archive_folder="$project_dir/archives/$log"

        if [[ -f "$source_log" ]]; then
            if ! mkdir -p -- "$archive_folder"; then
                echo "Could not create $archive_folder."
                exit 1
            fi
            archived_log="$archive_folder/${log}_${timestamp}.log"

            # Avoiding overwriting if you archive twice within the same second.
            number=1
            while [[ -e "$archived_log" ]]; do
                archived_log="$archive_folder/${log}_${timestamp}_${number}.log"
                number=$((number + 1))
            done

            if ! cp -- "$source_log" "$archived_log"; then
                echo "Could not archive $source_log."
                exit 1
            fi
            echo "Archived: $archived_log"
        else
            echo "No $log.log found. Skipping it."
        fi
    done
}
