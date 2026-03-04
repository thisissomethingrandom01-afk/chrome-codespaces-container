#!/bin/bash

cleanup() {
    echo "Caught signal, shutting down..."
    kill -TERM "$VNC_PID"
    kill -TERM "$NOVNC_PID"
    wait
    echo "Shutdown complete."
}

trap cleanup SIGTERM SIGINT

PROFILE_PATH="/home/chromer/.config/google-chrome"
rm -f "$PROFILE_PATH/SingletonLock"
rm -f "$PROFILE_PATH/SingletonCookie"
rm -f "$PROFILE_PATH/SingletonSocket"

mkdir -p /home/chromer/.vnc
mkdir -p /home/chromer/.config/openbox

echo "extension XInputExtension" > /home/chromer/.vnc/config

echo '#!/bin/sh' > /home/chromer/.vnc/xstartup
echo 'unset SESSION_MANAGER' >> /home/chromer/.vnc/xstartup
echo 'unset DBUS_SESSION_BUS_ADDRESS' >> /home/chromer/.vnc/xstartup
echo '# Launch Openbox within a D-Bus session for app compatibility' >> /home/chromer/.vnc/xstartup
echo 'exec dbus-launch --exit-with-session openbox-session' >> /home/chromer/.vnc/xstartup
chmod +x /home/chromer/.vnc/xstartup

echo "chrome_codespace" | vncpasswd -f > /home/chromer/.vnc/passwd
chmod 600 /home/chromer/.vnc/passwd

rm -f ~/.vnc/*.log

echo "Starting VNC server..."
vncserver -localhost no -fg -rfbauth /home/chromer/.vnc/passwd -geometry 1920x1080 -depth 24 &
VNC_PID=$!

echo "Starting noVNC proxy..."
websockify --web=/usr/share/novnc/ 6901 localhost:5901 &
NOVNC_PID=$!

LOG_FILE="cf_tunnel.log"
cloudflared tunnel --url http://localhost:6901 > "$LOG_FILE" 2>&1 &

TUNNEL_PID=$!

echo "Starting Cloudflare Tunnel..."

TUNNEL_URL=""
while [ -z "$TUNNEL_URL" ]; do
    sleep 1
    TUNNEL_URL=$(grep -oE "https://[a-zA-Z0-9.-]+\.trycloudflare\.com" "$LOG_FILE")
done

for pts in /dev/pts/*; do [ -e \"$pts\" ] && sudo sh -c \"echo "$TUNNEL_URL/vnc.html" > $pts\" 2>/dev/null; done
wait -n

exit $?
