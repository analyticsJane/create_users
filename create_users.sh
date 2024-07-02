#!/bin/bash

# Variables
LOG_FILE="/var/log/user_management.log"
PASSWORD_FILE="/var/secure/user_passwords.csv"

# Create necessary files and directories if they don't exist
mkdir -p /var/secure
touch $LOG_FILE
touch $PASSWORD_FILE

# Ensure only the owner can read/write the password file
chmod 600 $PASSWORD_FILE

# Function to log actions
log_action() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOG_FILE
}

# Function to generate random password
generate_password() {
    echo $(openssl rand -base64 12)
}

# Read the input file line by line
while IFS= read -r line; do
    # Ignore empty lines
    [[ -z "$line" ]] && continue

    # Ignore lines that start with #
    [[ "$line" =~ ^#.*$ ]] && continue

    # Remove any leading or trailing whitespace
    line=$(echo $line | xargs)

    # Split the line into username and groups
    IFS=';' read -r username groups <<< "$line"

    # Trim whitespace
    username=$(echo $username | xargs)
    groups=$(echo $groups | xargs)

    # Create the user group with the same name as the username
    if ! getent group "$username" > /dev/null 2>&1; then
        groupadd "$username"
        log_action "Group $username created."
    else
        log_action "Group $username already exists."
    fi

    # Create the user if it doesn't exist
    if ! id -u "$username" > /dev/null 2>&1; then
        useradd -m -g "$username" -s /bin/bash "$username"
        log_action "User $username created with group $username."
    else
        log_action "User $username already exists."
    fi

    # Add user to additional groups
    IFS=',' read -ra group_list <<< "$groups"
    for group in "${group_list[@]}"; do
        group=$(echo $group | xargs)  # Trim whitespace
        if ! getent group "$group" > /dev/null 2>&1; then
            groupadd "$group"
            log_action "Group $group created."
        fi
        usermod -aG "$group" "$username"
        log_action "User $username added to group $group."
    done

    # Generate and set a random password for the user
    password=$(generate_password)
    echo "$username:$password" | chpasswd
    log_action "Password set for user $username."

    # Store the password in the password file
    echo "$username,$password" >> $PASSWORD_FILE

done < "$1"

log_action "User creation script completed."

exit 0
