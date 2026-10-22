from pythonosc import dispatcher, osc_server, udp_client
import time
import threading


# --------------------------------------------------
# NETWORK CONFIGURATION
# --------------------------------------------------

INCOMING_IP = "0.0.0.0"
INCOMING_PORT = 9005

SC_IP = "127.0.0.1"
SC_PORT = 57120

client = udp_client.SimpleUDPClient(SC_IP, SC_PORT)


# --------------------------------------------------
# TRACK ACTIVE PEOPLE
# --------------------------------------------------

# ID -> last time we received that ID
last_seen = {}

# If we haven't received a person for this long,
# consider them gone
PERSON_TIMEOUT = 1.0

lock = threading.Lock()


# --------------------------------------------------
# RECEIVE /person FROM BEELINK
# --------------------------------------------------

def person_handler(address, *args):

    print(f"RECEIVED FROM BEELINK: {address} {args}")

    # Beelink sends:
    #
    # args[0] = device_ip
    # args[1] = person_id
    # args[2] = gx
    # args[3] = gz
    # args[4] = gy
    # args[5] = confidence

    device_ip = args[0]
    person_id = int(args[1])

    x = float(args[2])
    z = float(args[3])

    # Ignore bad coordinates
    if abs(x) > 100 or abs(z) > 100:
        print(
            f"Rejected outlier from ID {person_id}: "
            f"x={x}, z={z}"
        )
        return

    # Record that this person is still active
    with lock:
        last_seen[person_id] = time.time()

    # Send to SuperCollider:
    #
    # /person id x z
    client.send_message(
        "/person",
        [person_id, x, z]
    )

    print(
        f"SENT TO SC: /person "
        f"{person_id} {x} {z}"
    )


# --------------------------------------------------
# GENERATE /people
# --------------------------------------------------

def active_people_loop():

    while True:

        now = time.time()

        with lock:

            # Remove IDs that haven't appeared recently
            expired_ids = [
                person_id
                for person_id, last_time in last_seen.items()
                if now - last_time > PERSON_TIMEOUT
            ]

            for person_id in expired_ids:
                del last_seen[person_id]
                print(f"Person {person_id} timed out")

            active_ids = list(last_seen.keys())

        # Send to SuperCollider:
        #
        # /people 1 2 3
        client.send_message(
            "/people",
            active_ids
        )

        print(f"SENT TO SC: /people {active_ids}")

        time.sleep(0.25)


# --------------------------------------------------
# OSC SERVER
# --------------------------------------------------

disp = dispatcher.Dispatcher()

disp.map("/person", person_handler)

server = osc_server.ThreadingOSCUDPServer(
    (INCOMING_IP, INCOMING_PORT),
    disp
)

print(
    f"Listening for Beelink OSC on "
    f"{INCOMING_IP}:{INCOMING_PORT}"
)


# Start /people monitoring loop
threading.Thread(
    target=active_people_loop,
    daemon=True
).start()


# Start receiving OSC
server.serve_forever()


