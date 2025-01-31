#!/bin/sh

METHOD="$1"
MAC="$2"

case "$METHOD" in
  auth_client)
    USERNAME="$3"
    PASSWORD="$4"

    if grep -q "^$USERNAME:$PASSWORD$" /etc/nodogsplash/users.txt; then
        echo 36000 0 0  # 10 hours session, no limits
        exit 0
    else
        echo "$(date) - Failed login for user: $USERNAME from MAC: $MAC" >> /var/log/nodogsplash_auth.log
        exit 1
    fi
    ;;

  client_auth|client_deauth|idle_deauth|timeout_deauth|ndsctl_auth|ndsctl_deauth|shutdown_deauth)
    INGOING_BYTES="$3"
    OUTGOING_BYTES="$4"
    SESSION_START="$5"
    SESSION_END="$6"

    if [ "$METHOD" = "timeout_deauth" ]; then
        echo "$(date) - Session expired for MAC: $MAC" >> /var/log/nodogsplash_auth.log
    fi
    ;;
esac
