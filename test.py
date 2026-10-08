# test script just to make sure the osc msgs are sending

from pythonosc.dispatcher import Dispatcher
from pythonosc.osc_server import BlockingOSCUDPServer

def print_message(address, *args):
    print(f"Received OSC message: {address} {args}")

dispatcher = Dispatcher()
dispatcher.set_default_handler(print_message)

ip = "0.0.0.0"
port = 9005

print(f"Listening for OSC messages on port {port}...")

server = BlockingOSCUDPServer((ip, port), dispatcher)
server.serve_forever()