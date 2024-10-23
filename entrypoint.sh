#!/bin/bash

# Define the paths to the configuration files
CONFIG_DIR="/app/Data"
SERVER_CONFIG="$CONFIG_DIR/Server.xml"
ROOMS_CONFIG="$CONFIG_DIR/Rooms.xml"
ACCOUNTS_CONFIG="$CONFIG_DIR/Accounts.xml"
ADMIN_LOGIN_FILENAME="admin_login.txt"
ADMIN_LOGIN_FILE="$CONFIG_DIR/$ADMIN_LOGIN_FILENAME"

# Create named pipes for input and output
if [ ! -p /tmp/server_input ]; then
    mkfifo /tmp/server_input
fi
touch /tmp/server_output

# Function to generate a random password with special characters
generate_random_password() {
    # Use tr to remove characters that may cause issues in shell or file usage
    echo "$(openssl rand -base64 10 | tr -dc 'a-zA-Z0-9@#$%^&*()_+[]{}|;:,.<>?')"
}

# Function to start the EnhancedMap server
start_server() {
  # Start the EnhancedMap server with input from the named pipe and log output to /tmp/server_output
  tail -f /tmp/server_input | dotnet /app/EnhancedMapServer.dll > /tmp/server_output 2>&1 &
  
  # Check if configuration files exist, if not, run the /adduser and /save commands to set up the initial user and config
  if [ ! -f "$SERVER_CONFIG" ] || [ ! -f "$ROOMS_CONFIG" ] || [ ! -f "$ACCOUNTS_CONFIG" ]; then
      echo "Sleeping for 5 seconds to allow the server to start, then doing our initial setup..."

      sleep 5

      # Generate a random password
      RANDOM_PASSWORD=$(generate_random_password)
      
      # Store the login credentials in admin_login.txt
      echo "Username: uomap" > "$ADMIN_LOGIN_FILE"
      echo "Password: $RANDOM_PASSWORD" >> "$ADMIN_LOGIN_FILE"
      echo "Login details stored in your data directory as $ADMIN_LOGIN_FILENAME"
      
      # Send the /adduser command and provide the necessary input for username, password, room, and account level
      echo "/adduser" > /tmp/server_input
      sleep 1
      echo "uomap" > /tmp/server_input  # Username
      sleep 1
      echo "$RANDOM_PASSWORD" > /tmp/server_input  # Generated Password
      sleep 1
      echo "General" > /tmp/server_input  # Room
      sleep 1
      echo "2" > /tmp/server_input  # Server Admin level
      sleep 2
      
      # Save the configuration
      echo "/save" > /tmp/server_input
  else
      echo "Config files found, skipping initial setup."
  fi
}

# Check if arguments were passed to the script
if [ $# -gt 0 ]; then
    # If arguments are passed, assume it's a command to send to the running server
    echo "Sending command: $@"
    echo "$@" > /tmp/server_input

    # Wait a second to give the command time to be processed
    sleep 1
    
    # Output the latest server logs to see the result of the command
    tail -n 20 /tmp/server_output
else
    # If no arguments are passed, check if the server is running; if not, start the server
    if pgrep -f EnhancedMapServer.dll > /dev/null; then
        echo "Server is already running."
    else
        echo "Starting the EnhancedMap server..."
        start_server
    fi
    
    # Keep tailing the output so that it is always available
    tail -f /tmp/server_output
fi
