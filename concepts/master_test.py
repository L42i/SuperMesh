from pythonosc import dispatcher, osc_server, udp_client
#First we have to setup the configuration/network - listen to incoming data
#Equivalent to old PureData 'netreceive -u -b 9005'
#Dispatcher --> routing incoming messages
#osc server is to set up a listener to receive data
#Udp_client is to ensure data carries out to SuperCollider

INCOMING_IP = "127.0.0.1"
INCOMING_PORT = 9005

SC_IP = "127.0.0.1" 
SC_PORT = 57120 #This is the supercollider default listening port
client = udp_client.SimpleUDPClient(SC_IP, SC_PORT)

#Using a dictionary to assign user IDs to sounds
#Similar to the voices dictionary [id] from the old supercollider script
active_voices = {}
MAX_VOICES = 8

def person_handler(address, *args): #Runs everytime a tracking message appears from a person
    #Addres could be like /person/1
    #args is the data (id, x coordinate, z coordinate) - unpacking this

    person_id = int(args[2])
    x = float(args[3])
    z = float(args[5])

    #Need to ensure that extreme values that come in are ignored

    if abs(x) > 100 or abs(z) > 100: #TODO: Change this based on what measurement unit we're using
        print(f"Rejected outlier point from id {person_id}: x={x}, z={z}")
        return

    #Voice allocation logic, same as supercollider logic
    if person_id not in active_voices:
        if len(active_voices) < MAX_VOICES:
            active_voices[person_id] = True
            print(f"Created a new voice for ID {person_id} at x={x}, z={z}")
            client.send_message("/person”, [“appeared”, person_id, x, z]") #Sending message to SuperCollider
        else:
            print(f"Maximum number of voices reached, ignoring ID {person_id}")
    else: #If there is already an active ID for the person then we just update the coordinates instead of creating a new id
        client.send_message("/person", ["person", person_id, x, z]) #TODO: Change Supercollider script to receive messages starting with this address - done
    

def people_handler(address, *args): #This is a function to see who is still in the room
    #Generates a list of currently active people. If someone isn't active we can save computer resources
    current_active_ids = set(int(i) for i in args) #Converting the IDs of the tracking system into a set of unique numbers
    tracked_ids = list(active_voices.keys()) #Looking at all the IDs

    for person_id in tracked_ids: #Going through the IDs to see if they are active
        if person_id not in current_active_ids:
            del active_voices[person_id]
            print(f"User left space so removing inactive ID {person_id}")

            client.send_message("/person", ["gone", person_id]) #Send the update to SuperCollider

# Don't know how to start the server - put thing into terminal 

    


